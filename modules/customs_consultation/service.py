"""
Customs Consultation & Broker Price Lists Service Engine (BP-009)
"""

import logging
from dataclasses import dataclass
from datetime import date
from decimal import Decimal
from typing import Any, Dict, List, Optional

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.common import enum_codes
from modules.common.errors import CodedHTTPException, best_effort
from modules.common.validators import get_or_404
from modules.import_files.model import ImportFile
from modules.customs_consultation.model import (
    BrokerPriceList,
    BrokerPriceListItem,
    ClearanceExpenseType,
    CustomsBrokerQuoteItem,
    CustomsChecklistItem,
    CustomsConsultationSession,
)
from modules.customs_consultation.repository import (
    BrokerPriceListRepository,
    ClearanceExpenseTypeRepository,
    CustomsConsultationRepository,
)
from modules.customs_consultation.schemas import (
    BrokerPriceListCreate,
    BrokerPriceListResponse,
    BrokerPriceListUpdate,
    ClearanceExpenseTypeCreate,
    ClearanceExpenseTypeResponse,
    ClearanceExpenseTypeUpdate,
    CloneBrokerPriceListRequest,
    CloneConsultationRequest,
    CustomsConsultationCreate,
    CustomsConsultationResponse,
    CustomsConsultationUpdate,
    CustomsRecalculationResponse,
    LineVarianceComparison,
)
from modules.import_files.repository import codes_by_ids
from modules.customs_consultation.validators import (
    validate_broker_exists,
    validate_checklist_items,
    validate_expense_code_unique,
)

logger = logging.getLogger(__name__)

# Recalculation line status codes (lines[].status).
LINE_STATUS_OK = "OK"
LINE_STATUS_TARIFF_MISSING = "TARIFF_MISSING"

# Error codes (HTTPException detail["code"]).
CUSTOMS_FX_RATE_MISSING = "CUSTOMS_FX_RATE_MISSING"
CONSULTATION_EXISTS = "CONSULTATION_EXISTS"
CUSTOMS_MIXED_CURRENCY = "CUSTOMS_MIXED_CURRENCY"


# ==============================================================================
# Clearance Expense Types Service
# ==============================================================================

def _normalize_expense_type(schema):
    """Tier-3: expense type category / default unit -> enum codes (unknown values unchanged)."""
    changes = {}
    if getattr(schema, "category", None) is not None:
        changes["category"] = enum_codes.normalize(enum_codes.BROKER_EXPENSE_CATEGORY, schema.category)
    if getattr(schema, "default_unit", None) is not None:
        changes["default_unit"] = enum_codes.normalize(enum_codes.PRICING_UNIT, schema.default_unit)
    return schema.model_copy(update=changes) if changes else schema


def _normalize_price_list(schema):
    """Tier-3: broker price list item category / unit -> enum codes (unknown values unchanged)."""
    items = getattr(schema, "items", None)
    if not items:
        return schema
    normalized = [
        item.model_copy(
            update={
                "category": enum_codes.normalize(enum_codes.BROKER_EXPENSE_CATEGORY, item.category),
                "unit_type": enum_codes.normalize(enum_codes.PRICING_UNIT, item.unit_type),
            }
        )
        for item in items
    ]
    return schema.model_copy(update={"items": normalized})


class ClearanceExpenseTypeService:

    @staticmethod
    def create_expense_type(db: Session, schema: ClearanceExpenseTypeCreate) -> ClearanceExpenseTypeResponse:
        validate_expense_code_unique(db, schema.expense_code)
        obj = ClearanceExpenseTypeRepository.create(db, _normalize_expense_type(schema))
        return ClearanceExpenseTypeResponse.model_validate(obj)

    @staticmethod
    def get_expense_type(db: Session, expense_id: int) -> ClearanceExpenseTypeResponse:
        return ClearanceExpenseTypeResponse.model_validate(get_or_404(db, ClearanceExpenseType, expense_id, "نوع المصروف"))

    @staticmethod
    def list_expense_types(
        db: Session,
        include_inactive: bool = False,
        category: Optional[str] = None,
        search: Optional[str] = None,
    ) -> List[ClearanceExpenseTypeResponse]:
        categories: Optional[List[str]] = None
        if category:
            code = enum_codes.normalize(enum_codes.BROKER_EXPENSE_CATEGORY, category)
            # Seeds only insert missing rows: existing rows keep legacy labels, so a code matches them too.
            categories = (
                enum_codes.legacy_values(enum_codes.BROKER_EXPENSE_CATEGORY, code)
                if enum_codes.is_code(enum_codes.BROKER_EXPENSE_CATEGORY, code)
                else [category]
            )
        items = ClearanceExpenseTypeRepository.get_all(
            db, include_inactive=include_inactive, categories=categories, search=search
        )
        return [ClearanceExpenseTypeResponse.model_validate(i) for i in items]

    @staticmethod
    def update_expense_type(
        db: Session, expense_id: int, schema: ClearanceExpenseTypeUpdate
    ) -> ClearanceExpenseTypeResponse:
        obj = get_or_404(db, ClearanceExpenseType, expense_id, "نوع المصروف")
        if schema.expense_code and schema.expense_code != obj.expense_code:
            validate_expense_code_unique(db, schema.expense_code, current_id=expense_id)
        updated = ClearanceExpenseTypeRepository.update(db, obj, _normalize_expense_type(schema))
        return ClearanceExpenseTypeResponse.model_validate(updated)

    @staticmethod
    def delete_expense_type(db: Session, expense_id: int) -> ClearanceExpenseTypeResponse:
        obj = get_or_404(db, ClearanceExpenseType, expense_id, "نوع المصروف")
        deleted = ClearanceExpenseTypeRepository.delete(db, obj)
        return ClearanceExpenseTypeResponse.model_validate(deleted)


# ==============================================================================
# Broker Price Lists Service
# ==============================================================================

class BrokerPriceListService:

    @staticmethod
    def create_price_list(db: Session, schema: BrokerPriceListCreate) -> BrokerPriceListResponse:
        validate_broker_exists(db, schema.broker_id)
        pl = BrokerPriceListRepository.create(db, _normalize_price_list(schema))
        return BrokerPriceListResponse.model_validate(pl)

    @staticmethod
    def get_price_list(db: Session, price_list_id: int) -> BrokerPriceListResponse:
        return BrokerPriceListResponse.model_validate(get_or_404(db, BrokerPriceList, price_list_id, "قائمة أسعار المخلص"))

    @staticmethod
    def list_price_lists(
        db: Session,
        include_inactive: bool = False,
        broker_id: Optional[int] = None,
        search: Optional[str] = None,
    ) -> List[BrokerPriceListResponse]:
        lists = BrokerPriceListRepository.get_all(
            db, include_inactive=include_inactive, broker_id=broker_id, search=search
        )
        return [BrokerPriceListResponse.model_validate(pl) for pl in lists]

    @staticmethod
    def get_active_price_list_for_broker(
        db: Session, broker_id: int, target_date: Optional[date] = None
    ) -> Optional[BrokerPriceListResponse]:
        validate_broker_exists(db, broker_id)
        pl = BrokerPriceListRepository.get_active_by_broker(db, broker_id, target_date)
        if not pl:
            return None
        return BrokerPriceListResponse.model_validate(pl)

    @staticmethod
    def update_price_list(
        db: Session, price_list_id: int, schema: BrokerPriceListUpdate
    ) -> BrokerPriceListResponse:
        pl = get_or_404(db, BrokerPriceList, price_list_id, "قائمة أسعار المخلص")
        if schema.broker_id:
            validate_broker_exists(db, schema.broker_id)
        updated = BrokerPriceListRepository.update(db, pl, _normalize_price_list(schema))
        return BrokerPriceListResponse.model_validate(updated)

    @staticmethod
    def soft_delete_price_list(db: Session, price_list_id: int) -> BrokerPriceListResponse:
        pl = get_or_404(db, BrokerPriceList, price_list_id, "قائمة أسعار المخلص")
        deleted = BrokerPriceListRepository.soft_delete(db, pl)
        return BrokerPriceListResponse.model_validate(deleted)

    @staticmethod
    def clone_price_list(
        db: Session, price_list_id: int, schema: CloneBrokerPriceListRequest
    ) -> BrokerPriceListResponse:
        original = get_or_404(db, BrokerPriceList, price_list_id, "قائمة أسعار المخلص")

        target_code = schema.new_price_list_code
        if not target_code:
            target_code = f"{original.price_list_code}-COPY"
            idx = 2
            while db.query(BrokerPriceList).filter(BrokerPriceList.price_list_code == target_code).first():
                target_code = f"{original.price_list_code}-COPY{idx}"
                idx += 1
        else:
            existing = db.query(BrokerPriceList).filter(BrokerPriceList.price_list_code == target_code).first()
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"كود قائمة الأسعار '{target_code}' مستخدم بالفعل.",
                )

        new_pl = BrokerPriceList(
            price_list_code=target_code,
            title=schema.new_title,
            broker_id=original.broker_id,
            broker_name=original.broker_name,
            port_name=original.port_name,
            effective_from=schema.effective_from or date.today(),
            effective_to=schema.effective_to,
            version=original.version + 1,
            is_active=True,
            notes=schema.notes or f"Cloned from: {original.price_list_code}",
            cloned_from_id=original.price_list_id,
            cloned_from_code=original.price_list_code,
        )
        db.add(new_pl)
        db.flush()

        for itm in original.items:
            db.add(
                BrokerPriceListItem(
                    price_list_id=new_pl.price_list_id,
                    expense_type_id=itm.expense_type_id,
                    expense_name=itm.expense_name,
                    category=itm.category,
                    unit_type=itm.unit_type,
                    standard_price=itm.standard_price,
                    currency=itm.currency,
                    min_price=itm.min_price,
                    max_price=itm.max_price,
                    notes=itm.notes,
                    is_active=itm.is_active,
                )
            )

        db.commit()
        db.refresh(new_pl)
        return BrokerPriceListResponse.model_validate(new_pl)


# ==============================================================================
# Customs Consultation Session Service
# ==============================================================================

@dataclass(frozen=True)
class _ChecklistCounts:
    total: int
    approved: int
    rejected: int
    blocking: int
    verified_any: bool


def _checklist_counts(items: List[CustomsChecklistItem]) -> _ChecklistCounts:
    return _ChecklistCounts(
        total=len(items),
        approved=sum(1 for i in items if i.status == "Approved"),
        rejected=sum(1 for i in items if i.status == "Rejected"),
        blocking=sum(1 for i in items if i.is_blocking_shipment and i.status == "Rejected"),
        verified_any=any(i.status == "Verified" for i in items),
    )


def _recompute_metrics(db_session: CustomsConsultationSession) -> None:
    """Derive readiness %, blocking flag, overall status and broker fee total from the child rows.
    Called on writes only (create / update / clone): reads never mutate the entity."""
    c = _checklist_counts(db_session.checklist_items or [])
    has_blocking = c.blocking > 0
    readiness_pct = round((c.approved / c.total * 100.0) if c.total > 0 else 0.0, 1)

    overall_status = db_session.overall_status
    if has_blocking:
        overall_status = "Blocked"
    elif readiness_pct == 100.0 and c.total > 0:
        overall_status = "Clearance Ready"
    elif c.rejected > 0:
        overall_status = "Action Required"
    elif c.approved > 0 or c.verified_any:
        overall_status = "In Progress"

    db_session.readiness_percentage = readiness_pct
    db_session.has_blocking_issues = has_blocking
    db_session.overall_status = overall_status
    db_session.total_broker_fees_egp = sum(
        q.total_amount for q in (db_session.broker_quote_items or []) if q.is_applicable
    )


def _to_response(
    db_session: CustomsConsultationSession, import_file_code: Optional[str]
) -> CustomsConsultationResponse:
    """Pure response builder: stored values plus counts derived from the child rows."""
    c = _checklist_counts(db_session.checklist_items or [])
    res = CustomsConsultationResponse.model_validate(db_session)
    res.total_documents_count = c.total
    res.approved_documents_count = c.approved
    res.blocking_issues_count = c.blocking
    res.applied_broker_items_count = sum(1 for q in (db_session.broker_quote_items or []) if q.is_applicable)
    res.import_file_code = import_file_code
    return res


def _import_file_code(db: Session, import_file_id: Optional[int]) -> Optional[str]:
    return codes_by_ids(db, [import_file_id]).get(import_file_id)


def _check_one_per_file(db: Session, import_file_id: int, consultation_id: Optional[int] = None) -> None:
    """One active consultation per import file: another one is a coded 409."""
    other = next(
        (c for c in CustomsConsultationRepository.get_all(db, import_file_id=import_file_id)
         if c.consultation_id != consultation_id),
        None,
    )
    if other is not None:
        raise CodedHTTPException(
            status.HTTP_409_CONFLICT,
            CONSULTATION_EXISTS,
            "يوجد بالفعل دراسة استشارة جمركية محفوظة لهذا الملف. يرجى الذهاب لتعديل الدراسة الحالية بدلاً من إنشاء دراسة جديدة.",
            consultation_code=other.consultation_code,
            consultation_id=other.consultation_id,
        )


def _sync_file_side_effects(db: Session, import_file_id: Optional[int], modified_by: str) -> None:
    """Lifecycle stage + budget variance follow-ups. Failures are logged and never undo the saved study."""
    if not import_file_id:
        return
    from modules.financial_approval.service import evaluate_and_record_budget_variance_service
    from modules.lifecycle_board.service import sync_consultation_lifecycle_stage

    best_effort(db, sync_consultation_lifecycle_stage, f"Lifecycle stage sync for import file {import_file_id}",
                db, import_file_id)
    best_effort(db, evaluate_and_record_budget_variance_service,
                f"Budget variance evaluation for import file {import_file_id}", db, import_file_id,
                modified_by=modified_by)


class CustomsConsultationService:

    @staticmethod
    def _commit_and_respond(db: Session, db_session: CustomsConsultationSession) -> CustomsConsultationResponse:
        db.commit()
        db.refresh(db_session)
        return _to_response(db_session, _import_file_code(db, db_session.import_file_id))

    @staticmethod
    def create_consultation(
        db: Session, session_in: CustomsConsultationCreate, modified_by: str = "System"
    ) -> CustomsConsultationResponse:
        if session_in.broker_id is not None:
            validate_broker_exists(db, session_in.broker_id)
        validate_checklist_items(session_in.checklist_items)

        if session_in.import_file_id:
            _check_one_per_file(db, session_in.import_file_id)

        db_session = CustomsConsultationRepository.create(db, session_in)
        db_session.created_by = db_session.updated_by = modified_by
        _recompute_metrics(db_session)
        response = CustomsConsultationService._commit_and_respond(db, db_session)
        _sync_file_side_effects(db, db_session.import_file_id, modified_by)
        return response

    @staticmethod
    def get_consultation(db: Session, consultation_id: int) -> CustomsConsultationResponse:
        db_session = get_or_404(db, CustomsConsultationSession, consultation_id, "دراسة الاستشارة الجمركية")
        return _to_response(db_session, _import_file_code(db, db_session.import_file_id))

    @staticmethod
    def list_consultations(
        db: Session,
        include_inactive: bool = False,
        search: Optional[str] = None,
        broker_id: Optional[int] = None,
        import_file_id: Optional[int] = None,
        po_id: Optional[int] = None,
        project_id: Optional[int] = None,
        status: Optional[str] = None,
    ) -> List[CustomsConsultationResponse]:
        sessions = CustomsConsultationRepository.get_all(
            db,
            include_inactive=include_inactive,
            search=search,
            broker_id=broker_id,
            import_file_id=import_file_id,
            po_id=po_id,
            project_id=project_id,
            status=status,
        )
        codes = codes_by_ids(db, [s.import_file_id for s in sessions])
        return [_to_response(s, codes.get(s.import_file_id)) for s in sessions]

    @staticmethod
    def update_consultation(
        db: Session,
        consultation_id: int,
        update_in: CustomsConsultationUpdate,
        modified_by: str = "System",
    ) -> CustomsConsultationResponse:
        db_session = get_or_404(db, CustomsConsultationSession, consultation_id, "دراسة الاستشارة الجمركية")

        if update_in.broker_id is not None:
            validate_broker_exists(db, update_in.broker_id)
        if update_in.checklist_items is not None:
            validate_checklist_items(update_in.checklist_items)
        if update_in.import_file_id and update_in.import_file_id != db_session.import_file_id and db_session.is_active:
            _check_one_per_file(db, update_in.import_file_id, consultation_id)

        updated_session = CustomsConsultationRepository.update(db, db_session, update_in)
        updated_session.updated_by = modified_by
        _recompute_metrics(updated_session)
        response = CustomsConsultationService._commit_and_respond(db, updated_session)
        _sync_file_side_effects(db, updated_session.import_file_id, modified_by)
        return response

    @staticmethod
    def soft_delete_consultation(
        db: Session, consultation_id: int, modified_by: Optional[str] = None
    ) -> CustomsConsultationResponse:
        db_session = get_or_404(db, CustomsConsultationSession, consultation_id, "دراسة الاستشارة الجمركية")
        db_session.updated_by = modified_by
        CustomsConsultationRepository.soft_delete(db, db_session)
        return CustomsConsultationService._commit_and_respond(db, db_session)

    @staticmethod
    def restore_consultation(
        db: Session, consultation_id: int, modified_by: Optional[str] = None
    ) -> CustomsConsultationResponse:
        db_session = get_or_404(db, CustomsConsultationSession, consultation_id, "دراسة الاستشارة الجمركية")
        if db_session.import_file_id and not db_session.is_active:
            _check_one_per_file(db, db_session.import_file_id, consultation_id)
        db_session.updated_by = modified_by
        CustomsConsultationRepository.restore(db, db_session)
        return CustomsConsultationService._commit_and_respond(db, db_session)

    @staticmethod
    def clone_consultation(
        db: Session, consultation_id: int, schema: CloneConsultationRequest, modified_by: Optional[str] = None
    ) -> CustomsConsultationResponse:
        original = get_or_404(db, CustomsConsultationSession, consultation_id, "دراسة الاستشارة الجمركية")

        target_code = schema.new_consultation_code
        if not target_code:
            target_code = f"{original.consultation_code}-COPY"
            idx = 2
            while db.query(CustomsConsultationSession).filter(CustomsConsultationSession.consultation_code == target_code).first():
                target_code = f"{original.consultation_code}-COPY{idx}"
                idx += 1
        else:
            existing = db.query(CustomsConsultationSession).filter(CustomsConsultationSession.consultation_code == target_code).first()
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"كود الاستشارة الجمركية '{target_code}' مستخدم بالفعل.",
                )

        new_sess = CustomsConsultationSession(
            consultation_code=target_code,
            title=schema.new_title,
            broker_id=original.broker_id,
            broker_name=original.broker_name,
            broker_contact_person=original.broker_contact_person,
            broker_price_list_id=original.broker_price_list_id,
            import_file_id=schema.target_import_file_id or original.import_file_id,
            po_id=None,
            project_id=original.project_id,
            overall_status="Draft",
            has_blocking_issues=False,
            readiness_percentage=0.0,
            estimated_duties_egp=original.estimated_duties_egp,
            total_broker_fees_egp=original.total_broker_fees_egp,
            notes=schema.notes or f"Cloned from: {original.consultation_code}",
            is_active=True,
            cloned_from_id=original.consultation_id,
            cloned_from_code=original.consultation_code,
            created_by=modified_by,
            updated_by=modified_by,
        )
        db.add(new_sess)
        db.flush()

        if schema.copy_checklist_items:
            for chk in original.checklist_items:
                db.add(
                    CustomsChecklistItem(
                        consultation_id=new_sess.consultation_id,
                        document_type=chk.document_type,
                        hs_code=chk.hs_code,
                        is_required=chk.is_required,
                        required_text=chk.required_text,
                        responsible_party=chk.responsible_party,
                        is_blocking_shipment=chk.is_blocking_shipment,
                        status="Pending",
                        remarks=chk.remarks,
                        regulatory_agency=chk.regulatory_agency,
                        corrective_action_required=chk.corrective_action_required,
                    )
                )

        if schema.copy_broker_quote_items:
            for quote_item in original.broker_quote_items:
                db.add(
                    CustomsBrokerQuoteItem(
                        consultation_id=new_sess.consultation_id,
                        expense_type_id=quote_item.expense_type_id,
                        expense_name=quote_item.expense_name,
                        category=quote_item.category,
                        unit_type=quote_item.unit_type,
                        unit_price=quote_item.unit_price,
                        currency=quote_item.currency,
                        qty=quote_item.qty,
                        is_applicable=quote_item.is_applicable,
                        total_amount=quote_item.total_amount,
                        notes=quote_item.notes,
                    )
                )

        db.flush()
        db.expire(new_sess, ["checklist_items", "broker_quote_items"])
        _recompute_metrics(new_sess)
        return CustomsConsultationService._commit_and_respond(db, new_sess)

    @staticmethod
    def recalculate_from_reconciliation_service(
        db: Session,
        import_file_id: int,
        exchange_rate: Optional[float] = None,
        freight_egp: Optional[float] = 0.0,
        insurance_egp: Optional[float] = 0.0,
        estimate_date: Optional[date] = None,
        preliminary_exchange_rate: Optional[float] = None,
    ) -> CustomsRecalculationResponse:
        """Customs duties/taxes of the final reconciled invoice vs the preliminary PO lines (BP-009).

        Every rate comes from the HS tariff record valid on the estimate date, through the shared
        multi-item engine (``customs_tariff.service.estimate_multi_item_customs_duty_service``). A line
        without an HS code or without a tariff valid on that date gets ``status=TARIFF_MISSING``, zero
        taxes, and is excluded from every total: no fallback rate is ever used.
        """
        from modules.customs_tariff import repository as tariff_repository

        imp_file = get_or_404(db, ImportFile, import_file_id, "ملف الشحنة")

        calc_date = estimate_date or date.today()
        freight_val = _num(freight_egp)
        ins_val = _num(insurance_egp)

        reconciliation = CustomsConsultationRepository.latest_reconciliation(db, import_file_id)
        final_items = [
            i for i in ((reconciliation.reconciled_invoice_items or []) if reconciliation else []) if isinstance(i, dict)
        ]
        is_reconciled = bool(
            reconciliation and final_items and (
                reconciliation.is_safe_for_certification
                or reconciliation.overall_status in ("FULLY_MATCHED", "RECONCILED", "APPROVED")
            )
        )
        po_lines = CustomsConsultationRepository.active_po_line_items(db, import_file_id)
        lines = _build_lines(final_items, [_po_side(line) for line in po_lines])

        # One tariff lookup per distinct HS code (the engine re-reads the same rows for the rates).
        tariff_found: Dict[str, bool] = {}
        for line in lines:
            if line.hs_code and line.hs_code not in tariff_found:
                tariff_found[line.hs_code] = (
                    tariff_repository.get_active_tariff_on_date(db, line.hs_code, calc_date, strict=True) is not None
                )
            if not line.hs_code or not tariff_found[line.hs_code]:
                line.status = LINE_STATUS_TARIFF_MISSING

        # Each side in its own currency: preliminary = PO currency, final = reconciled invoice currency.
        prelim_currency = _po_currency(po_lines) or imp_file.estimated_cost_currency or None
        final_currency = (reconciliation.currency if final_items else None) or prelim_currency
        if not lines:  # nothing to price: no PO lines and no invoice rows
            p_rate = f_rate = 0.0
            p_source = f_source = "table"
        else:
            f_manual = float(exchange_rate) if exchange_rate and exchange_rate > 0 else None
            p_manual = float(preliminary_exchange_rate) if preliminary_exchange_rate and preliminary_exchange_rate > 0 else None
            if final_currency == prelim_currency and p_manual is None:
                p_manual = f_manual  # one currency: the manual rate covers both sides
            f_rate = f_manual or _resolve_customs_rate(db, final_currency, calc_date)
            p_rate = p_manual or (
                f_rate if final_currency == prelim_currency and f_manual is None
                else _resolve_customs_rate(db, prelim_currency, calc_date)
            )
            p_source = "manual" if p_manual else "table"
            f_source = "manual" if f_manual else "table"

        # Two engine runs: freight / insurance are allocated by value share within each side.
        prelim = _engine_taxes(db, lines, "prelim", prelim_currency, p_rate, freight_val, ins_val, calc_date)
        final = _engine_taxes(db, lines, "final", final_currency, f_rate, freight_val, ins_val, calc_date)

        total_p, total_f = _Side(), _Side()
        comparison: List[LineVarianceComparison] = []
        for idx, line in enumerate(lines):
            p = _Side.of(line.prelim.value_fc * p_rate, prelim.get(idx))
            f = _Side.of(line.final.value_fc * f_rate, final.get(idx))
            rate_src = final.get(idx) or prelim.get(idx)
            if line.status == LINE_STATUS_OK:
                total_p.add(p)
                total_f.add(f)
            comparison.append(
                LineVarianceComparison(
                    item_name=line.item_name,
                    hs_code=line.hs_code or "",
                    country_of_origin=line.origin,
                    status=line.status,
                    preliminary_qty=line.prelim.qty,
                    final_qty=line.final.qty,
                    qty_variance=round(line.final.qty - line.prelim.qty, 2),
                    preliminary_unit_price=line.prelim.price,
                    final_unit_price=line.final.price,
                    unit_price_variance=round(line.final.price - line.prelim.price, 2),
                    duty_rate_pct=float(rate_src.customs_duty_rate) if rate_src else 0.0,
                    vat_rate_pct=float(rate_src.vat_rate) if rate_src else 0.0,
                    **_side_fields(p, f, rounded_taxes=False),
                )
            )

        taxes_variance = round(total_f.taxes - total_p.taxes, 2)
        pct_change = round((taxes_variance / total_p.taxes * 100.0), 2) if total_p.taxes > 0 else 0.0
        forecast_status = "Exact Match"
        if taxes_variance > 0:
            forecast_status = "Increased Cost"
        elif taxes_variance < 0:
            forecast_status = "Reduced Cost"

        return CustomsRecalculationResponse(
            import_file_id=import_file_id,
            import_file_code=imp_file.import_file_code or f"IMP-{import_file_id:04d}",
            final_invoice_number=(reconciliation.final_invoice_number if final_items else None) or imp_file.pi_number,
            reconciliation_session_id=reconciliation.session_id if final_items else None,
            is_reconciled=is_reconciled,
            source_description="الفاتورة وقائمة التعبئة النهائية المعتمدة" if is_reconciled else "أمر الشراء التقديري (مبدئي)",
            exchange_rate=round(f_rate, 4),
            preliminary_exchange_rate=round(p_rate, 4),
            preliminary_currency=prelim_currency,
            final_currency=final_currency,
            exchange_rate_source=f_source,
            preliminary_exchange_rate_source=p_source,
            estimate_date=calc_date,
            **_side_fields(total_p, total_f, rounded_taxes=True),
            variance_percentage=pct_change,
            forecast_status=forecast_status,
            tariff_missing_lines_count=sum(1 for line in lines if line.status == LINE_STATUS_TARIFF_MISSING),
            comparison_lines=comparison,
        )


# ==============================================================================
# Customs re-estimation helpers (CC-01)
# ==============================================================================

@dataclass
class _Values:
    """Quantity / unit price / foreign-currency value of one side of a line."""
    qty: float
    price: float
    value_fc: float


@dataclass
class _PoLine:
    item_id: int
    item_code: Optional[str]
    name: str
    hs_code: Optional[str]
    origin: Optional[str]
    values: _Values


@dataclass
class _RecalcLine:
    item_name: str
    hs_code: Optional[str]
    origin: Optional[str]
    prelim: _Values
    final: _Values
    status: str = LINE_STATUS_OK


@dataclass
class _Side:
    """EGP amounts of one side (preliminary or final) of a line or of the totals."""
    fob: float = 0.0
    cif: float = 0.0
    duty: float = 0.0
    vat: float = 0.0
    taxes: float = 0.0

    @classmethod
    def of(cls, fob: float, breakdown: Any) -> "_Side":
        if breakdown is None:
            return cls(fob=fob)
        return cls(
            fob=fob,
            cif=float(breakdown.cif_value_egp),
            duty=float(breakdown.duty_egp),
            vat=float(breakdown.vat_egp),
            taxes=round(_line_total(breakdown), 2),
        )

    def add(self, other: "_Side") -> None:
        self.fob += other.fob
        self.cif += other.cif
        self.duty += other.duty
        self.vat += other.vat
        self.taxes += other.taxes


def _side_fields(p: _Side, f: _Side, rounded_taxes: bool) -> Dict[str, float]:
    """preliminary_* / final_* / *_variance_egp fields shared by a line and the response totals."""
    r = (lambda x: round(x, 2)) if rounded_taxes else (lambda x: x)
    return {
        "preliminary_fob_egp": round(p.fob, 2),
        "final_fob_egp": round(f.fob, 2),
        "fob_variance_egp": round(f.fob - p.fob, 2),
        "preliminary_cif_egp": round(p.cif, 2),
        "final_cif_egp": round(f.cif, 2),
        "cif_variance_egp": round(f.cif - p.cif, 2),
        "preliminary_duty_egp": r(p.duty),
        "final_duty_egp": r(f.duty),
        "duty_variance_egp": round(f.duty - p.duty, 2),
        "preliminary_vat_egp": r(p.vat),
        "final_vat_egp": r(f.vat),
        "vat_variance_egp": round(f.vat - p.vat, 2),
        "preliminary_total_taxes_egp": r(p.taxes),
        "final_total_taxes_egp": r(f.taxes),
        "total_taxes_variance_egp": round(f.taxes - p.taxes, 2),
    }


def _clean_hs(hs: Optional[str]) -> str:
    return (hs or "").replace(".", "").strip()


def _num(value: Any) -> float:
    try:
        return float(value or 0.0)
    except (TypeError, ValueError):
        return 0.0


def _po_side(line: Any) -> _PoLine:
    qty = _num(line.quantity)
    price = _num(line.unit_price)
    po = line.purchase_order
    return _PoLine(
        item_id=line.item_id,
        item_code=(line.item_code or "").strip() or None,
        name=line.description_ar or line.description_en or line.item_code or "",
        hs_code=line.tariff.hs_code if line.tariff else None,
        origin=line.country_of_origin or (po.country_of_origin if po else None),
        values=_Values(qty=qty, price=price, value_fc=_num(line.total_price) or qty * price),
    )


class _PoLineIndex:
    """PO lines indexed once by item id, item code and HS code. A line not matched yet wins over one
    already used by an earlier invoice row."""

    def __init__(self, po_lines: List[_PoLine]):
        self.by_id: Dict[int, List[_PoLine]] = {}
        self.by_code: Dict[str, List[_PoLine]] = {}
        self.by_hs: Dict[str, List[_PoLine]] = {}
        for p in po_lines:
            self.by_id.setdefault(p.item_id, []).append(p)
            if p.item_code:
                self.by_code.setdefault(p.item_code, []).append(p)
            if _clean_hs(p.hs_code):
                self.by_hs.setdefault(_clean_hs(p.hs_code), []).append(p)
        self.used: set = set()

    def match(self, final_item: Dict[str, Any]) -> Optional[_PoLine]:
        po_item_id = final_item.get("po_item_id")
        item_code = str(final_item.get("item_code") or "").strip()
        hs = _clean_hs(str(final_item.get("hs_code") or ""))
        for candidates in (
            self.by_id.get(po_item_id, []) if isinstance(po_item_id, int) else [],
            self.by_code.get(item_code, []) if item_code else [],
            # HS fallback never pairs two different item codes (a new item that shares an HS code).
            [p for p in self.by_hs.get(hs, []) if not (item_code and p.item_code and p.item_code != item_code)] if hs else [],
        ):
            if not candidates:
                continue
            # The most specific key that finds PO lines decides: if they are all used already (a split
            # invoice row), the row has no preliminary counterpart; it never falls back to a looser key.
            chosen = next((p for p in candidates if p.item_id not in self.used), None)
            if chosen is not None:
                self.used.add(chosen.item_id)
            return chosen
        return None


_NOTHING = _Values(qty=0.0, price=0.0, value_fc=0.0)


def _build_lines(final_items: List[Dict[str, Any]], po_lines: List[_PoLine]) -> List[_RecalcLine]:
    """One line per invoice row (preliminary side = its matched PO line, or nothing for a new / split-off
    row), then one preliminary-only line per PO line no invoice row matched (dropped item), so each side's
    total is complete. Without a reconciled invoice the PO lines are both sides."""
    if not final_items:
        return [
            _RecalcLine(item_name=p.name, hs_code=p.hs_code, origin=p.origin, prelim=p.values, final=p.values)
            for p in po_lines
        ]

    index = _PoLineIndex(po_lines)
    lines = []
    for item in final_items:
        qty = _num(item.get("final_quantity", item.get("quantity")))
        price = _num(item.get("final_unit_price") or item.get("unit_price"))
        final = _Values(qty=qty, price=price, value_fc=_num(item.get("total_price") or item.get("total_amount")) or qty * price)
        matched = index.match(item)
        lines.append(
            _RecalcLine(
                item_name=str(item.get("item_name") or item.get("description") or item.get("item_code") or ""),
                hs_code=str(item.get("hs_code") or "").strip() or (matched.hs_code if matched else None),
                origin=item.get("country_of_origin") or item.get("origin_country") or (matched.origin if matched else None),
                prelim=matched.values if matched else _NOTHING,
                final=final,
            )
        )
    for p in po_lines:
        if p.item_id not in index.used:
            lines.append(_RecalcLine(item_name=p.name, hs_code=p.hs_code, origin=p.origin, prelim=p.values, final=_NOTHING))
    return lines


def _po_currency(po_lines: List[Any]) -> Optional[str]:
    """The single currency of the preliminary PO lines; several currencies -> coded 409 (no silent mix)."""
    found = sorted({line.purchase_order.currency.currency_code for line in po_lines
                    if line.purchase_order is not None and line.purchase_order.currency is not None})
    if len(found) > 1:
        raise CodedHTTPException(
            status.HTTP_409_CONFLICT,
            CUSTOMS_MIXED_CURRENCY,
            f"أوامر الشراء المرتبطة بالملف بعملات مختلفة ({', '.join(found)}). لا يمكن إعادة الاحتساب بعملة واحدة.",
            currencies=", ".join(found),
        )
    return found[0] if found else None


def _resolve_customs_rate(db: Session, currency: Optional[str], on_date: date) -> float:
    """Customs exchange rate (EGP per unit) from the currency rate table, valid on ``on_date``.
    CurrencyService answers a built-in fallback (no rate row, ``rate_id`` None) when no rate is
    configured: that is a hard-coded number, so it is refused here with 409."""
    from modules.currencies.service import CurrencyService

    code = enum_codes.normalize_currency(currency) if currency else None
    if code == "EGP":
        return 1.0
    rate_id = None
    rate = 0.0
    if code:
        try:
            rate, _, rate_id = CurrencyService(db)._get_rate_to_egp(code, rate_type="customs", as_of_date=on_date)
        except HTTPException as exc:
            if exc.status_code not in (status.HTTP_404_NOT_FOUND, status.HTTP_409_CONFLICT):  # unregistered currency / missing rate -> coded 409 below
                raise
    if rate_id is None or not rate or rate <= 0:
        raise CodedHTTPException(
            status.HTTP_409_CONFLICT,
            CUSTOMS_FX_RATE_MISSING,
            (
                f"لا يوجد سعر صرف جمركي مسجل للعملة {code or '-'} بتاريخ {on_date.isoformat()}. "
                "يرجى تسجيل سعر الصرف الجمركي أو إدخاله يدوياً في الطلب."
            ),
            currency=code,
            on_date=on_date.isoformat(),
        )
    return float(rate)


def _engine_taxes(
    db: Session,
    lines: List[_RecalcLine],
    side: str,
    currency: Optional[str],
    fx_rate: float,
    freight_egp: float,
    insurance_egp: float,
    on_date: date,
) -> Dict[int, Any]:
    """Run the shared customs engine for one side ("prelim" / "final") over the lines that have a tariff
    and a positive value. Returns line index -> MultiItemCustomsLineBreakdown.

    Freight and insurance are the amounts the user entered (EGP), allocated by value share; no statutory
    deemed percentage is added (deemed rates 0), which keeps CIF = FOB + entered freight + insurance.
    Lines left out (TARIFF_MISSING) keep their own value share: the engine only receives the part of the
    freight / insurance that belongs to the lines it prices."""
    from modules.customs_tariff.schemas import MultiItemCustomsEstimateLine, MultiItemCustomsEstimateRequest
    from modules.customs_tariff.service import estimate_multi_item_customs_duty_service

    engine_lines = []
    all_value = 0.0
    priced_value = 0.0
    for idx, line in enumerate(lines):
        value = (line.prelim if side == "prelim" else line.final).value_fc
        if value > 0:
            all_value += value
        if line.status != LINE_STATUS_OK or value <= 0:
            continue
        priced_value += value
        engine_lines.append(
            MultiItemCustomsEstimateLine(
                line_no=idx,
                hs_code=line.hs_code,
                value_fc=Decimal(str(value)),
                origin_country=line.origin,
            )
        )
    if not engine_lines:
        return {}
    share = priced_value / all_value if priced_value != all_value else 1.0

    request = MultiItemCustomsEstimateRequest(
        currency=currency or "EGP",
        exchange_rate=Decimal(str(fx_rate)),
        freight_egp=Decimal(str(freight_egp * share)),
        insurance_egp=Decimal(str(insurance_egp * share)),
        has_freight_document=True,
        has_insurance_document=True,
        deemed_freight_rate=Decimal("0"),
        deemed_insurance_rate=Decimal("0"),
        estimate_date=on_date,
        lines=engine_lines,
    )
    breakdown = estimate_multi_item_customs_duty_service(db, request)
    return {b.line_no: b for b in breakdown.lines}


def _line_total(b: Any) -> float:
    return float(
        b.duty_egp + b.schedule_tax_egp + b.customs_service_fee_egp + b.vat_egp
        + b.development_fee_egp + b.import_fee_egp
    )
