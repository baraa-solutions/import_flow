"""
Centralized Recalculation Engine — Service Layer (CRE-001)

This is the SINGLE place that:
1. Reads dependency relationships from recalculation_dependency_map.
2. Fetches live values from source entities dynamically.
3. Computes variance and determines action type.
4. Applies changes respecting immutability rules and permissions.
5. Writes unified audit logs to recalculation_logs.

ARCHITECTURAL RULE:
  No page, screen, or router may implement their own "sync" or "compare" logic.
  All pages call preview() then apply() from this service exclusively.

Transactions: the repository only flushes; every public call commits once (RC-04). A refused apply (permission,
SoD, hard block) commits its audit log row and then raises.
"""

from datetime import datetime, date, timezone
from typing import List, Optional, Any, Dict, Tuple
from sqlalchemy import inspect as sa_inspect
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from modules.recalculation.model import RecalculationDependencyMap, RecalculationLog
import modules.recalculation.repository as repo
from modules.recalculation.schemas import (
    DependencyMapResponse,
    RecalculationPreviewItem,
    RecalculationPreviewResponse,
    RecalculationApplyRequest,
    RecalculationApplyResult,
)
from modules.users.model import User
from modules.auth.permissions import has_user_permission, is_admin_user


# Language-neutral message codes (plain {code, params} until registered in the shared catalog).
RECALC_NO_VARIANCE = "RECALC_NO_VARIANCE"
RECALC_SOFT_VARIANCE = "RECALC_SOFT_VARIANCE"
RECALC_HARD_BLOCK = "RECALC_HARD_BLOCK"
RECALC_APPLIED = "RECALC_APPLIED"
RECALC_SOURCE_RATE_MISSING = "RATE_MISSING"
RECALC_RATE_MISSING = "RECALC_RATE_MISSING"

# View permission per target entity type (RC-05).
TARGET_VIEW_PERMISSIONS: Dict[str, str] = {
    "import_budget": "financial_approval.view",
    "financial_settlement": "financial_settlement.view",
}


class SourceRateMissing(Exception):
    """A source value is in a foreign currency with no exchange rate on its date: that dependency is skipped."""

    def __init__(self, currency: Optional[str], on_date: Optional[str]):
        super().__init__(f"No exchange rate for {currency} on {on_date}")
        self.currency = currency
        self.on_date = on_date


def _rate_to_egp(fx: Any, currency: Optional[str], on_date: Optional[date]) -> float:
    """Commercial rate to EGP (Q2); a missing rate becomes ``SourceRateMissing`` instead of a fake 1.0 (RC-03)."""
    from modules.financial_settlement.validators import SETTLEMENT_FX_RATE_MISSING
    try:
        return fx.rate(currency, on_date)
    except HTTPException as exc:
        if isinstance(exc.detail, dict) and exc.detail.get("code") == SETTLEMENT_FX_RATE_MISSING:
            raise SourceRateMissing(exc.detail.get("currency"), exc.detail.get("on_date")) from exc
        raise


# ──────────────────────────────────────────────────────────────────────────────
# Source Fetching Registry
# ──────────────────────────────────────────────────────────────────────────────
# Maps source_entity_type → callable(db, join_key_value, source_field, aggregation) → float (EGP)
# Every new source entity type needs ONE entry here and ONE seed row in the DB table.
# Nothing else changes.

def _fetch_from_customs_consultation(
    db: Session, join_key_value: Any, source_field: str, aggregation: str
) -> float:
    """Fetches live value from CustomsConsultationSession (EGP fields), oldest first so 'latest' is the newest."""
    from modules.customs_consultation.model import CustomsConsultationSession
    pk = sa_inspect(CustomsConsultationSession).primary_key[0]
    sessions = (
        db.query(CustomsConsultationSession)
        .filter(
            CustomsConsultationSession.import_file_id == join_key_value,
            CustomsConsultationSession.is_active == True,
        )
        .order_by(pk)
        .all()
    )
    if not sessions:
        return 0.0

    values = [float(getattr(s, source_field, 0.0) or 0.0) for s in sessions]
    return _aggregate(values, aggregation)


def _is_scenario_money_field(source_field: str) -> bool:
    return source_field == "total_quotation_amount" or source_field.endswith("_price")


def _fetch_from_shipping_scenarios(
    db: Session, join_key_value: Any, source_field: str, aggregation: str
) -> float:
    """
    Fetches live value from ShippingEvaluationSession + ShippingScenarioItem.
    For total_quotation_amount: uses the RECOMMENDED item (is_recommended=True),
    falling back to the item with the highest is_selected flag, then max.
    Money fields are in ``quotation_currency``: converted to EGP at the commercial rate of the session date (RC-03).
    """
    from modules.financial_settlement.service import SettlementFx, cairo_date
    from modules.shipping_scenarios.model import ShippingEvaluationSession, ShippingScenarioItem
    sessions = (
        db.query(ShippingEvaluationSession)
        .filter(
            ShippingEvaluationSession.import_file_id == join_key_value,
            ShippingEvaluationSession.is_active == True,
        )
        .order_by(ShippingEvaluationSession.session_id)
        .all()
    )
    if not sessions:
        return 0.0

    # One query for every item of every session (RC-07)
    session_ids = [s.session_id for s in sessions]
    items_by_session: Dict[int, List[Any]] = {sid: [] for sid in session_ids}
    for item in (
        db.query(ShippingScenarioItem)
        .filter(ShippingScenarioItem.session_id.in_(session_ids))
        .order_by(ShippingScenarioItem.item_id)
        .all()
    ):
        items_by_session[item.session_id].append(item)

    fx = SettlementFx(db, "commercial")
    convert = _is_scenario_money_field(source_field)

    values = []
    for session in sessions:
        items = items_by_session.get(session.session_id) or []
        if not items:
            continue
        on_date = cairo_date(session.created_at) if session.created_at else None

        def _value(item: Any) -> float:
            raw = float(getattr(item, source_field, 0.0) or 0.0)
            if not convert or raw == 0.0:
                return raw
            return raw * _rate_to_egp(fx, item.quotation_currency or "USD", on_date)

        # Priority: recommended → selected → aggregate
        preferred = next((i for i in items if i.is_recommended), None)
        if preferred is None:
            preferred = next((i for i in items if i.is_selected), None)

        if preferred:
            values.append(_value(preferred))
        else:
            # No recommendation: use the aggregation function across items
            values.append(_aggregate([_value(i) for i in items], aggregation))

    return _aggregate(values, aggregation)


def _fetch_from_purchase_orders(
    db: Session, join_key_value: Any, source_field: str, aggregation: str
) -> float:
    """
    Fetches live value from PurchaseOrder.
    total_amount_fob is in the PO currency → converted to EGP at the PO rate (EGP = 1, the stored rate when set,
    else the commercial rate on the order date; a missing rate skips the dependency, RC-03).
    For total_amount_fob, partial PO shipments use file_po_line_shares (ACC2-T01).
    The budgeted field is invoice_amount_egp.
    """
    from modules.financial_settlement.service import SettlementFx, purchase_order_rate_to_egp
    from modules.financial_settlement.validators import SETTLEMENT_FX_RATE_MISSING
    from modules.purchase_orders.model import PurchaseOrder
    from modules.financial_settlement.service import _purchase_orders_of_file
    from modules.import_files.model import ImportFile
    imp = db.query(ImportFile).filter(ImportFile.import_file_id == join_key_value).first()
    if imp is not None:  # same PO set as the settlement (import_file_id or po_ids, review 2 #14)
        pos = _purchase_orders_of_file(db, imp)
    else:
        pos = (
            db.query(PurchaseOrder)
            .filter(PurchaseOrder.import_file_id == join_key_value, PurchaseOrder.is_active == True)
            .order_by(PurchaseOrder.po_id)
            .all()
        )
    if not pos:
        return 0.0

    fx = SettlementFx(db, "commercial")

    if source_field == "total_amount_fob" and imp is not None:
        from modules.financial_settlement.service import file_po_line_shares
        from modules.purchase_orders.model import POShipmentAllocation

        line_shares = file_po_line_shares(db, imp)
        po_lines_map: Dict[int, List[Tuple[Any, float, float]]] = {}
        for li, share_qty, ratio in line_shares:
            po_lines_map.setdefault(li.po_id, []).append((li, share_qty, ratio))

        values = []
        for po in pos:
            try:
                rate = purchase_order_rate_to_egp(po, fx)
            except HTTPException as exc:
                if isinstance(exc.detail, dict) and exc.detail.get("code") == SETTLEMENT_FX_RATE_MISSING:
                    raise SourceRateMissing(exc.detail.get("currency"), exc.detail.get("on_date")) from exc
                raise

            if po.po_id in po_lines_map:
                po_fob_foreign = sum(
                    float(li.unit_price or 0.0) * share_qty
                    for li, share_qty, _ in po_lines_map[po.po_id]
                )
                values.append(round(po_fob_foreign * rate, 2))
            else:
                has_allocs = (
                    db.query(POShipmentAllocation.allocation_id)
                    .filter(POShipmentAllocation.po_id == po.po_id)
                    .first()
                    is not None
                )
                if not has_allocs:
                    header_fob = float(getattr(po, "total_amount_fob", 0.0) or 0.0)
                    values.append(round(header_fob * rate, 2))

        return _aggregate(values, aggregation) if values else 0.0

    values = []
    for po in pos:
        raw = float(getattr(po, source_field, 0.0) or 0.0)
        try:
            rate = purchase_order_rate_to_egp(po, fx)
        except HTTPException as exc:
            if isinstance(exc.detail, dict) and exc.detail.get("code") == SETTLEMENT_FX_RATE_MISSING:
                raise SourceRateMissing(exc.detail.get("currency"), exc.detail.get("on_date")) from exc
            raise
        values.append(raw * rate)

    return _aggregate(values, aggregation)


# Registry mapping source_entity_type → fetcher function
_SOURCE_FETCHERS: Dict[str, Any] = {
    "customs_consultation": _fetch_from_customs_consultation,
    "shipping_scenarios": _fetch_from_shipping_scenarios,
    "purchase_orders": _fetch_from_purchase_orders,
}


def _aggregate(values: List[float], func_name: str) -> float:
    """Applies the aggregation function to a list of float values."""
    if not values:
        return 0.0
    func_map = {
        "max": max,
        "min": min,
        "sum": sum,
        "latest": lambda v: v[-1],  # callers pass rows ordered by primary key
    }
    fn = func_map.get(func_name, max)
    return round(fn(values), 4)


# ──────────────────────────────────────────────────────────────────────────────
# Target Entity Registry
# ──────────────────────────────────────────────────────────────────────────────

def ensure_can_view(db: Session, current_user: User, target_entity_type: str) -> None:
    """View permission of the target entity type (RC-05)."""
    perm = TARGET_VIEW_PERMISSIONS.get(target_entity_type)
    if perm is None:
        raise HTTPException(status_code=400, detail=f"نوع الكيان المستهدف '{target_entity_type}' غير معروف.")
    if not has_user_permission(db, current_user, perm):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"ليس لديك صلاحية '{perm}' لعرض بيانات إعادة الاحتساب.",
        )


def _load_target_entity(db: Session, target_entity_type: str, entity_id: int) -> Any:
    """Resolves and returns the target entity from the DB."""
    if target_entity_type == "import_budget":
        from modules.financial_approval.model import ImportBudgetApproval
        entity = db.query(ImportBudgetApproval).filter(
            ImportBudgetApproval.budget_id == entity_id,
            ImportBudgetApproval.is_active == True,
        ).first()
        if not entity:
            raise HTTPException(status_code=404, detail=f"موازنة الاستيراد رقم {entity_id} غير موجودة.")
        return entity
    elif target_entity_type == "financial_settlement":
        from modules.financial_settlement.model import LandedCostSettlementRecord
        entity = db.query(LandedCostSettlementRecord).filter(
            LandedCostSettlementRecord.settlement_id == entity_id,
            LandedCostSettlementRecord.is_active == True,
        ).first()
        if not entity:
            raise HTTPException(status_code=404, detail=f"التسوية المالية رقم {entity_id} غير موجودة.")
        return entity
    # Future entity types: add here
    raise HTTPException(status_code=400, detail=f"نوع الكيان المستهدف '{target_entity_type}' غير معروف.")


def _get_entity_status(entity: Any, target_entity_type: str) -> str:
    """Returns the current status string of the entity."""
    if target_entity_type == "import_budget":
        return entity.budget_status
    elif target_entity_type == "financial_settlement":
        return entity.status
    return "Unknown"


def _get_entity_join_key_value(entity: Any, target_entity_type: str, join_key: str) -> Any:
    """Extracts the join key value from the entity."""
    val = getattr(entity, join_key, None)
    if val is None:
        raise HTTPException(
            status_code=422,
            detail=f"الكيان ({target_entity_type}) لا يحتوي على قيمة لمفتاح الربط '{join_key}'.",
        )
    return val


def _is_settlement(entity: Any, target_entity_type: str) -> bool:
    return target_entity_type == "financial_settlement" or hasattr(entity, "expense_invoices")


def _get_entity_field_value(entity: Any, field_name: str, target_entity_type: str = "") -> float:
    """Gets the current float value of a field from the entity."""
    if _is_settlement(entity, target_entity_type):
        from modules.financial_settlement.service import SETTLEMENT_RECALC_FIELDS, settlement_field_total
        if field_name == "total_fob_egp":
            return float(getattr(entity, "total_fob_egp", 0.0) or 0.0)
        # Virtual expense field: the rows the settlement classifier puts in that field (RC-01)
        if field_name in SETTLEMENT_RECALC_FIELDS:
            return settlement_field_total(getattr(entity, "expense_invoices", []) or [], field_name)

    return float(getattr(entity, field_name, 0.0) or 0.0)


def _apply_field_to_entity(entity: Any, field_name: str, new_value: float, target_entity_type: str):
    """Sets a field on the entity in memory. Does NOT commit."""
    if _is_settlement(entity, target_entity_type):
        from modules.financial_settlement.service import SETTLEMENT_RECALC_FIELDS, apply_settlement_field_total
        if field_name == "total_fob_egp":
            entity.total_fob_egp = new_value
            items = [dict(i) for i in (entity.item_landed_costs or [])]
            old_fob = sum(i.get("fob_total_egp", 0.0) for i in items)
            if old_fob > 0 and new_value > 0:
                ratio = new_value / old_fob
                for itm in items:
                    # Unrounded: the engine recomputes fob_total = qty * fob_unit, so a rounded unit drifted
                    # (1000.00 -> 1000.02) and a second apply saw a fake variance (review 2 #4).
                    qty = float(itm.get("qty", 1) or 0.0)
                    if qty <= 0:
                        continue
                    itm["fob_total_egp"] = itm.get("fob_total_egp", 0.0) * ratio
                    itm["fob_unit_egp"] = itm["fob_total_egp"] / qty
                entity.item_landed_costs = items
            return

        if field_name in SETTLEMENT_RECALC_FIELDS:
            # One adjustment row per field: user invoices untouched, repeated applies idempotent (RC-01)
            entity.expense_invoices = apply_settlement_field_total(entity.expense_invoices or [], field_name, new_value)
            return

    setattr(entity, field_name, new_value)


def _get_entity_code(entity: Any, target_entity_type: str) -> Optional[str]:
    if target_entity_type == "import_budget":
        return getattr(entity, "budget_code", None)
    elif target_entity_type == "financial_settlement":
        return getattr(entity, "settlement_code", None)
    return None



def _create_revision_for_approved_budget(
    db: Session, entity: Any, applied_changes: list, performed_by: str, justification: Optional[str]
) -> Any:
    """
    Creates a Revision for an Approved budget. The original becomes 'Superseded'.
    Returns the new revision entity.
    """
    from modules.financial_approval.model import ImportBudgetApproval
    from modules.common.sequence_generator import generate_reference_code

    now = datetime.now(timezone.utc)
    rev_num = (entity.revision_number or 1) + 1

    new_code = generate_reference_code(db, ImportBudgetApproval, prefix="BDG", id_field="budget_id")
    # Build the new revision with updated field values

    new_budget = ImportBudgetApproval(
        budget_code=new_code,
        title=f"{entity.title} (Rev {rev_num})",
        import_file_id=entity.import_file_id,
        po_id=entity.po_id,
        project_id=entity.project_id,
        invoice_amount_egp=entity.invoice_amount_egp,
        invoice_amount_foreign=entity.invoice_amount_foreign,
        invoice_currency=entity.invoice_currency,
        freight_cost_egp=entity.freight_cost_egp,
        freight_cost_foreign=entity.freight_cost_foreign,
        freight_currency=entity.freight_currency,
        customs_duties_egp=entity.customs_duties_egp,
        clearance_inland_egp=entity.clearance_inland_egp,
        exchange_rate=entity.exchange_rate,
        total_budget_egp=entity.total_budget_egp,
        budget_status="Pending Review",
        parent_budget_id=entity.budget_id,
        revision_number=rev_num,
        notes=(entity.notes or ""),
        has_unresolved_variance=False,
        last_variance_check=now,
        upstream_modified_by=performed_by,
        variance_override_reason=justification,
        variance_overridden_by=performed_by if justification else None,
    )

    # Apply the new field values to the revision
    for change in applied_changes:
        _apply_field_to_entity(new_budget, change["field_name"], change["new_value"], "import_budget")

    # Recalculate total
    new_budget.total_budget_egp = (
        new_budget.invoice_amount_egp
        + new_budget.freight_cost_egp
        + new_budget.customs_duties_egp
        + new_budget.clearance_inland_egp
    )

    # Supersede the original
    entity.budget_status = "Superseded"
    entity.is_active = False

    db.add(new_budget)
    db.flush()
    return new_budget


def _apply_in_place_to_entity(
    db: Session,
    entity: Any,
    applied_changes: list,
    target_entity_type: str,
    performed_by: str,
    justification: Optional[str],
) -> str:
    """
    Applies changes directly to the entity (for Draft / Pending Review status).
    Returns action_taken string.
    """
    now = datetime.now(timezone.utc)

    for change in applied_changes:
        _apply_field_to_entity(entity, change["field_name"], change["new_value"], target_entity_type)

    # Post-apply for import_budget
    if target_entity_type == "import_budget":
        entity.total_budget_egp = (
            entity.invoice_amount_egp
            + entity.freight_cost_egp
            + entity.customs_duties_egp
            + entity.clearance_inland_egp
        )
        entity.has_unresolved_variance = False
        entity.last_variance_check = now
        entity.upstream_modified_by = performed_by
        if justification:
            entity.variance_override_reason = justification
            entity.variance_overridden_by = performed_by

        current_status = entity.budget_status
        if current_status == "Draft":
            action_taken = "auto_updated"
        else:
            # Needs Revalidation or Pending Review: keep in revalidation
            entity.budget_status = "Pending Review"
            action_taken = "revalidation_required"

    elif target_entity_type == "financial_settlement":
        from modules.financial_settlement.service import calculate_landed_cost_engine
        incoterm = getattr(entity, "incoterm_code", "FOB") or "FOB"
        calc_res = calculate_landed_cost_engine(
            [dict(e) for e in (entity.expense_invoices or [])],
            [dict(i) for i in (entity.item_landed_costs or [])],
            incoterm=incoterm,
        )
        entity.total_fob_egp = calc_res["total_fob_egp"]
        entity.total_expenses_egp = calc_res["total_expenses_egp"]
        entity.total_landed_cost_egp = calc_res["total_landed_cost_egp"]
        entity.average_markup_factor = calc_res["average_markup_factor"]
        entity.item_landed_costs = calc_res["item_landed_costs"]
        entity.status = "Calculated"
        entity.updated_by = performed_by
        entity.updated_at = now
        action_taken = "recalculated"

    return action_taken if target_entity_type in ("import_budget", "financial_settlement") else "auto_updated"


def _variance(old_value: float, new_value: float, threshold_pct: float) -> Dict[str, Any]:
    variance_amount = new_value - old_value
    if old_value == 0.0:
        variance_pct = 100.0 if abs(variance_amount) > 0.01 else 0.0
    else:
        variance_pct = round((abs(variance_amount) / old_value) * 100.0, 4)
    return {
        "variance_amount": variance_amount,
        "variance_pct": variance_pct,
        "is_hard": variance_pct > threshold_pct and abs(variance_amount) > 1.0,
    }


def _evaluate_dependencies(db: Session, entity: Any, target_entity_type: str, dependencies: list, threshold_pct: float) -> List[RecalculationPreviewItem]:
    """One preview item per dependency with a known fetcher. A source value without an exchange rate gives an
    item with status RATE_MISSING and no variance: that field is never applied (RC-03)."""
    items: List[RecalculationPreviewItem] = []
    for dep in dependencies:
        fetcher = _SOURCE_FETCHERS.get(dep.source_entity_type)
        if fetcher is None:
            # Unknown source type — skip gracefully
            continue
        join_key_value = _get_entity_join_key_value(entity, target_entity_type, dep.join_key)
        old_value = _get_entity_field_value(entity, dep.target_field, target_entity_type)
        common = dict(
            field_name=dep.target_field,
            label_ar=dep.label_ar or dep.target_field,
            label_en=dep.label_en or dep.target_field,
            old_value=old_value,
            threshold_percentage=threshold_pct,
            source_entity_type=dep.source_entity_type,
            dependency_id=dep.id,
        )
        try:
            new_value = fetcher(db, join_key_value, dep.source_field, dep.aggregation_function)
        except SourceRateMissing as missing:
            items.append(RecalculationPreviewItem(
                **common,
                new_value=old_value,
                variance_amount=0.0,
                variance_percentage=0.0,
                is_hard_block=False,
                status=RECALC_SOURCE_RATE_MISSING,
                message_code="SETTLEMENT_FX_RATE_MISSING",
                params={"currency": missing.currency, "on_date": missing.on_date},
            ))
            continue
        v = _variance(old_value, new_value, threshold_pct)
        items.append(RecalculationPreviewItem(
            **common,
            new_value=new_value,
            variance_amount=round(v["variance_amount"], 4),
            variance_percentage=v["variance_pct"],
            is_hard_block=v["is_hard"],
        ))
    return items


# ──────────────────────────────────────────────────────────────────────────────
# Core Engine: preview()
# ──────────────────────────────────────────────────────────────────────────────

def preview(
    db: Session,
    target_entity_type: str,
    target_entity_id: int,
    source_page: str,
    performed_by: Optional[str] = "System",
    current_user: Optional[User] = None,
) -> RecalculationPreviewResponse:
    """
    Compares current stored values in the target entity against live upstream values.
    Logs the preview action (the log row is the only write). ``current_user`` (router calls) must hold the
    view permission of the target type.
    """
    if current_user is not None:
        ensure_can_view(db, current_user, target_entity_type)

    # 1. Load entity and get its dependencies
    entity = _load_target_entity(db, target_entity_type, target_entity_id)
    current_status = _get_entity_status(entity, target_entity_type)
    dependencies = repo.get_active_dependencies_for_target(db, target_entity_type)

    # 2. Load variance threshold (if relevant to entity type)
    threshold_pct = _get_variance_threshold(db, target_entity_type)

    # 3. Check if entity status blocks apply
    blocked_by_status = False
    can_apply = True

    # Collect all blocked_statuses across all deps
    all_blocked_statuses: set = set()
    for dep in dependencies:
        for s in dep.blocked_statuses_list:
            all_blocked_statuses.add(s)

    if current_status in all_blocked_statuses:
        blocked_by_status = True
        can_apply = False  # Will only be True if Revision engine is enabled

    # For Approved budgets: apply() creates Revision, so can_apply = True
    if target_entity_type == "import_budget" and current_status == "Budget Approved":
        blocked_by_status = True
        can_apply = True  # Revision creation is always allowed with permission

    # For Approved financial settlements: apply() recalculates and resets to Calculated (Q1), so can_apply = True
    if target_entity_type == "financial_settlement" and current_status == "Approved":
        blocked_by_status = True
        can_apply = True
    if target_entity_type == "financial_settlement" and current_status == "Closed":
        blocked_by_status = True
        can_apply = False

    # 4. Fetch live values and compute variances
    items = _evaluate_dependencies(db, entity, target_entity_type, dependencies, threshold_pct)
    has_hard_block = any(i.is_hard_block for i in items)
    max_variance_pct = max([i.variance_percentage for i in items] or [0.0])
    has_any_variance = any(abs(i.variance_amount) > 0.01 for i in items)

    # 5. Build message
    missing = [i.field_name for i in items if i.status == RECALC_SOURCE_RATE_MISSING]
    if not has_any_variance and missing:
        message_code, params = RECALC_RATE_MISSING, {"fields": ",".join(missing)}
        message_ar = "تعذر مقارنة بعض البنود لعدم وجود سعر صرف مسجل للعملة. يرجى تسجيل سعر الصرف."
    elif not has_any_variance:
        message_code, params = RECALC_NO_VARIANCE, {}
        message_ar = "لا توجد فوارق — جميع التكاليف متطابقة مع المصادر الحية."
    elif has_hard_block:
        message_code, params = RECALC_HARD_BLOCK, {"threshold": threshold_pct}
        message_ar = f"تحذير: تم رصد فارق يتجاوز الحد المسموح ({threshold_pct}%). مطلوب مبرر كتابي قبل التحديث."
    else:
        message_code, params = RECALC_SOFT_VARIANCE, {"threshold": threshold_pct}
        message_ar = f"تم رصد فوارق في التكاليف (أقل من {threshold_pct}%). يمكنك المزامنة مع تحذير."

    # 6. Log the preview action
    preview_data_for_log = [
        {
            "field_name": i.field_name,
            "old_value": i.old_value,
            "new_value": i.new_value,
            "variance_amount": i.variance_amount,
            "variance_pct": i.variance_percentage,
            "is_hard_block": i.is_hard_block,
            "status": i.status,
        }
        for i in items
    ]
    repo.create_log(
        db=db,
        target_entity_type=target_entity_type,
        target_entity_id=target_entity_id,
        action="preview",
        performed_by=performed_by,
        source_page=source_page,
        preview_data=preview_data_for_log,
        result_status="has_variance" if has_any_variance else "no_changes",
    )
    db.commit()

    return RecalculationPreviewResponse(
        target_entity_type=target_entity_type,
        target_entity_id=target_entity_id,
        items=items,
        has_any_variance=has_any_variance,
        has_hard_block=has_hard_block,
        max_variance_pct=round(max_variance_pct, 2),
        blocked_by_status=blocked_by_status,
        current_entity_status=current_status,
        can_apply=can_apply,
        message_ar=message_ar,
        message_code=message_code,
        params=params,
    )


# ──────────────────────────────────────────────────────────────────────────────
# Core Engine: apply()
# ──────────────────────────────────────────────────────────────────────────────

def _refresh_file_landed_cost(db: Session, settlement: Any) -> None:
    """The import file KPIs written at approval follow a recalculated approved settlement (review 2 #3)."""
    from modules.import_files.model import ImportFile
    imp = db.query(ImportFile).filter(ImportFile.import_file_id == settlement.import_file_id).first()
    if imp is None:
        return
    imp.actual_landed_cost_total_egp = settlement.total_landed_cost_egp
    imp.actual_landed_cost_markup_factor = settlement.average_markup_factor
    imp.actual_landed_cost_calculated_at = datetime.now(timezone.utc)


def _log_refusal_and_raise(db: Session, exc: HTTPException, **log_fields: Any) -> None:
    """The refused attempt keeps its audit row (committed) before the error reaches the client."""
    repo.create_log(db=db, action="apply", **log_fields)
    db.commit()
    raise exc


def apply(
    db: Session,
    request: RecalculationApplyRequest,
    current_user: User,
) -> RecalculationApplyResult:
    """
    Applies live upstream values to the target entity.

    Rules (enforced centrally, NOT in pages):
    1. Permission check: user must have required_permission from dependency map.
    2. Segregation of Duties (SoD): user who modified upstream CANNOT sync if entity is Approved/Superseded.
    3. Hard Block: if variance > threshold AND no justification → HTTP 400.
    4. Immutability: if entity status is Approved → create Revision, mark original Superseded.
       An Approved financial settlement is recalculated in place with justification rules (Q1); the log records
       ``recalculated_approved``.
    5. Draft / Pending: update in-place.
    6. Unified audit log entry created for every apply, in the same transaction as the change.
    """
    target_entity_type = request.target_entity_type
    target_entity_id = request.target_entity_id
    justification = request.justification
    source_page = request.source_page
    performed_by = current_user.username
    log_base = dict(
        target_entity_type=target_entity_type,
        target_entity_id=target_entity_id,
        performed_by=performed_by,
        source_page=source_page,
    )

    # 1. Load entity
    entity = _load_target_entity(db, target_entity_type, target_entity_id)
    current_status = _get_entity_status(entity, target_entity_type)
    dependencies = repo.get_active_dependencies_for_target(db, target_entity_type)
    threshold_pct = _get_variance_threshold(db, target_entity_type)

    # 2. Permission check (uses most restrictive permission found in dependency map)
    required_perms = sorted(set(dep.required_permission for dep in dependencies if dep.required_permission))
    for perm in required_perms:
        if not has_user_permission(db, current_user, perm):
            _log_refusal_and_raise(
                db,
                HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"ليس لديك صلاحية '{perm}' لتنفيذ المزامنة. يُرجى التواصل مع مدير النظام.",
                ),
                **log_base, result_status="blocked_permission", justification=justification,
            )

    # 3. Segregation of Duties check (for import_budget)
    if target_entity_type == "import_budget":
        upstream_mod = getattr(entity, "upstream_modified_by", None)
        is_admin = is_admin_user(current_user)
        if (
            upstream_mod
            and upstream_mod.lower() == performed_by.lower()
            and not is_admin
            and current_status in ("Budget Approved", "Superseded")
        ):
            _log_refusal_and_raise(
                db,
                HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="فصل المهام (SoD): المستخدم الذي عدّل التكاليف الأصلية لا يمكنه مزامنة الميزانية المعتمدة. يرجى تعيين مستخدم آخر.",
                ),
                **log_base, result_status="blocked_sod", justification=justification,
            )

    # 4. Fetch live values and build applied_changes (RATE_MISSING dependencies are skipped)
    evaluated = _evaluate_dependencies(db, entity, target_entity_type, dependencies, threshold_pct)
    changed_items = [i for i in evaluated if i.status == "OK" and abs(i.variance_amount) > 0.01]
    has_hard_block = any(i.is_hard_block for i in evaluated)
    applied_changes = [
        {
            "field_name": i.field_name,
            "old_value": i.old_value,
            "new_value": i.new_value,
            "variance_amount": i.variance_amount,
            "variance_pct": i.variance_percentage,
            "is_hard_block": i.is_hard_block,
        }
        for i in changed_items
    ]

    # 4b. Settlements: Closed is final; an Approved one changes only with a written justification (review 2 #3)
    if target_entity_type == "financial_settlement" and current_status == "Closed":
        _log_refusal_and_raise(
            db,
            HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "code": "SETTLEMENT_NOT_EDITABLE",
                    "message": f"لا يمكن إعادة احتساب التسوية {entity.settlement_code} لأنها مغلقة (Closed).",
                    "status": current_status,
                    "settlement_code": entity.settlement_code,
                },
            ),
            **log_base, preview_data=applied_changes, result_status="blocked_status", justification=justification,
        )
    if (
        target_entity_type == "financial_settlement"
        and current_status == "Approved"
        and applied_changes
        and not (justification or "").strip()
    ):
        _log_refusal_and_raise(
            db,
            HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="التسوية معتمدة (Approved): يجب تقديم مبرر كتابي لإعادة احتسابها بالتكاليف الحية.",
            ),
            **log_base, preview_data=applied_changes, result_status="approved_no_justification", justification=None,
        )

    # 5. Hard Block check
    if has_hard_block and not justification:
        _log_refusal_and_raise(
            db,
            HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"تجاوز الفارق الحد المسموح ({threshold_pct}%). "
                    "يجب تقديم مبرر كتابي لإتمام المزامنة."
                ),
            ),
            **log_base, preview_data=applied_changes, result_status="hard_block_no_justification", justification=None,
        )

    # 6. No actual changes?
    missing = [i.field_name for i in evaluated if i.status == RECALC_SOURCE_RATE_MISSING]
    if not applied_changes:
        log = repo.create_log(
            db=db,
            action="apply",
            **log_base,
            result_status="no_changes",
            action_taken="no_op",
        )
        db.commit()
        return RecalculationApplyResult(
            target_entity_type=target_entity_type,
            target_entity_id=target_entity_id,
            action_taken="no_op",
            revision_created=False,
            applied_changes=[],
            log_id=log.id,
            message_ar=(
                "تعذر تطبيق بعض البنود لعدم وجود سعر صرف مسجل." if missing
                else "لا توجد تغييرات — التكاليف مطابقة للمصادر الحية."
            ),
            message_code=RECALC_RATE_MISSING if missing else RECALC_NO_VARIANCE,
            params={"fields": ",".join(missing)} if missing else {},
        )

    # 7. Apply based on entity status
    revision_created = False
    new_entity_id = None
    new_entity_code = None
    log_action_taken = None

    if target_entity_type == "import_budget" and current_status == "Budget Approved":
        # STRICT: create Revision, mark original Superseded
        new_entity = _create_revision_for_approved_budget(
            db, entity, applied_changes, performed_by, justification
        )
        revision_created = True
        new_entity_id = new_entity.budget_id
        new_entity_code = new_entity.budget_code
        action_taken = "revision_created"
        message_ar = f"تم إنشاء مراجعة جديدة ({new_entity_code}) بالتكاليف المحدّثة. الميزانية الأصلية أصبحت 'Superseded'."
    else:
        # Draft / Pending / Needs Revalidation: update in-place
        action_taken = _apply_in_place_to_entity(
            db, entity, applied_changes, target_entity_type, performed_by, justification
        )
        if target_entity_type == "financial_settlement":
            if current_status == "Approved":
                log_action_taken = "recalculated_approved"  # RC-02 / Q1: kept, but visible in the audit trail
                _refresh_file_landed_cost(db, entity)
            message_ar = "تمت إعادة احتساب التسوية وتكلفة الوصول بنجاح استناداً إلى التكاليف الحية."
        elif action_taken == "auto_updated":
            message_ar = "تم تحديث الميزانية بالتكاليف الحية تلقائياً."
        else:
            message_ar = "تم تحديث التكاليف. الميزانية في حالة 'Pending Review' للاعتماد."

    # 8. Unified audit log, committed together with the change
    log = repo.create_log(
        db=db,
        action="apply",
        **log_base,
        preview_data=applied_changes,
        changes_applied=applied_changes,
        justification=justification,
        result_status="success",
        action_taken=log_action_taken or action_taken,
        new_entity_id=new_entity_id,
    )
    db.commit()

    return RecalculationApplyResult(
        target_entity_type=target_entity_type,
        target_entity_id=target_entity_id,
        action_taken=action_taken,
        revision_created=revision_created,
        new_entity_id=new_entity_id,
        new_entity_code=new_entity_code,
        applied_changes=changed_items,
        log_id=log.id,
        message_ar=message_ar,
        message_code=RECALC_APPLIED,
        params={"action_taken": log_action_taken or action_taken, "new_entity_code": new_entity_code},
    )


# ──────────────────────────────────────────────────────────────────────────────
# Convenience: recalculate() = preview() + apply() in one call
# ──────────────────────────────────────────────────────────────────────────────

def recalculate(
    db: Session,
    target_entity_type: str,
    target_entity_id: int,
    current_user: User,
    source_page: str,
    justification: Optional[str] = None,
) -> RecalculationApplyResult:
    """
    Convenience wrapper: runs preview (for audit) then apply immediately.
    Used for automated/system-triggered recalculations (e.g. Draft auto-update on upstream save).
    """
    preview(db, target_entity_type, target_entity_id, source_page, current_user.username)
    return apply(
        db=db,
        request=RecalculationApplyRequest(
            target_entity_type=target_entity_type,
            target_entity_id=target_entity_id,
            source_page=source_page,
            justification=justification,
        ),
        current_user=current_user,
    )


# ──────────────────────────────────────────────────────────────────────────────
# Read endpoints (RC-05): logs and dependency map
# ──────────────────────────────────────────────────────────────────────────────

def list_logs(
    db: Session, current_user: User, target_entity_type: str, target_entity_id: int, limit: int = 50
) -> List[RecalculationLog]:
    ensure_can_view(db, current_user, target_entity_type)
    return repo.get_logs_for_entity(db, target_entity_type, target_entity_id, limit)


def list_dependencies(
    db: Session, current_user: User, target_entity_type: Optional[str] = None
) -> List[DependencyMapResponse]:
    """Active dependency rows. Filtering by a target type requires that type's view permission; the unfiltered
    list is configuration metadata (login only)."""
    if target_entity_type:
        ensure_can_view(db, current_user, target_entity_type)
    deps = repo.get_all_dependencies(db, include_inactive=False)
    if target_entity_type:
        deps = [d for d in deps if d.target_entity_type == target_entity_type]
    return [
        DependencyMapResponse(
            id=d.id,
            target_entity_type=d.target_entity_type,
            target_field=d.target_field,
            source_entity_type=d.source_entity_type,
            source_field=d.source_field,
            join_key=d.join_key,
            aggregation_function=d.aggregation_function,
            blocked_statuses=d.blocked_statuses_list,
            required_permission=d.required_permission,
            label_ar=d.label_ar,
            label_en=d.label_en,
            is_active=d.is_active,
        )
        for d in deps
    ]


# ──────────────────────────────────────────────────────────────────────────────
# Helper: Variance threshold retrieval
# ──────────────────────────────────────────────────────────────────────────────

def _get_variance_threshold(db: Session, target_entity_type: str) -> float:
    """
    Returns the configured variance threshold for the entity type.
    Currently reads from budget_variance_settings for import_budget,
    defaults to 5.0% for all others.
    """
    if target_entity_type in ("import_budget", "financial_settlement"):
        from modules.financial_approval.model import BudgetVarianceSetting
        setting = db.query(BudgetVarianceSetting).filter(
            BudgetVarianceSetting.setting_key == "variance_threshold_percentage"
        ).first()

        if setting and setting.setting_value:
            try:
                return float(setting.setting_value)
            except ValueError:
                return 5.0
    return 5.0
