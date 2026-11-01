import logging
import math
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from typing import List, Optional, Dict, Any, Tuple
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from .model import LandedCostSettlementRecord
from .schemas import (
    FinancialSettlementCreate,
    FinancialSettlementUpdate,
    ExpenseInvoiceSchema,
    ItemLandedCostSchema,
    AggregatedInvoiceItemSchema,
    InvoicesPartySummary,
    InvoicesAggregationResponse,
    ConfirmInvoicesSettlementRequest,
    ConfirmInvoicesSettlementResponse,
    ActualLandedCostCategoryBreakdown,
    ActualLandedCostItemLine,
    ActualLandedCostCalculationRequest,
    ActualLandedCostCalculationResponse,
    ApproveActualLandedCostRequest,
    ApproveActualLandedCostResponse,
    EstimatedLandedCostSimulationRequest,
    EstimatedLandedCostSimulationResponse,
    EstimatedLandedCostItemBreakdown,
    EstimatedLandedCostExpenseItem,
    SettlementMessage,
    RECALC_ADJUSTMENT_PREFIX,
    CustomsDutyComponentSchema,
)
from .repository import (
    add_with_new_code,
    apply_settlement_update,
    build_settlement,
    get_settlement_by_id,
    get_settlement_by_import_file_id,
    list_settlements,
    soft_delete_settlement,
    restore_settlement,
    get_effective_tax_rate,
)
from .model import (
    WHT_CLEARANCE_SERVICES,
    WHT_TRANSPORT_SERVICES,
    CLEARANCE_CATEGORY_BUCKET,
)
from .validators import (
    SETTLEMENT_ACTUAL_FOB_MISSING,
    SETTLEMENT_DUPLICATE_ACTIVE,
    SETTLEMENT_FX_RATE_MISSING,
    coded_error,
    ensure_cost_not_approved,
    ensure_file_open,
    ensure_invoices_not_settled,
    ensure_invoices_settlement_ready,
    ensure_invoices_settled,
    ensure_no_manual_rows,
    ensure_no_other_active_settlement,
    ensure_no_client_adjustment_rows,
    ensure_settlement_editable,
    fx_rate_missing_error,
    currency_missing_error,
    validate_expense_invoice,
    validate_items_allocation_readiness,
)
from modules.import_files.model import ImportFile
from modules.common import enum_codes
from modules.common.errors import best_effort
from modules.common.system_messages import msg, render_en
from modules.common.system_parameters import get_float_parameter
from modules.common.validators import require_active
from modules.common.file_tracking import set_file_tracking

logger = logging.getLogger(__name__)

IMPORT_FILE_LABEL_AR = "ملف الشحنة"

# Message codes emitted in ``messages[]`` (plain {code, params} until registered in the shared catalog).
SETTLEMENT_LINE_NO_HS = "SETTLEMENT_LINE_NO_HS"
SETTLEMENT_LINE_ZERO_VALUE = "SETTLEMENT_LINE_ZERO_VALUE"
PAYMENT_STATUS_UNKNOWN = "PAYMENT_STATUS_UNKNOWN"
ESTIMATE_UNAVAILABLE = "ESTIMATE_UNAVAILABLE"
SETTLEMENT_UNPAID_INVOICE = "SETTLEMENT_UNPAID_INVOICE"
WHT_RATE_MISSING_WARNING = "WHT_RATE_MISSING_WARNING"
ALLOCATION_BASIS_INCOMPLETE = "ALLOCATION_BASIS_INCOMPLETE"
ACTUAL_SOURCE_MISSING = "ACTUAL_SOURCE_MISSING"

# PL-08 estimate constants, configurable through system_parameters (FS-07). The defaults are the former literals,
# so the estimate is unchanged while no parameter row exists.
PARAM_DEEMED_FREIGHT_PCT = "settlement.deemed_freight_pct"
PARAM_DEEMED_INSURANCE_PCT = "settlement.deemed_insurance_pct"
PARAM_DEFAULT_CLEARANCE_EGP = "settlement.default_clearance_egp"
PARAM_DEFAULT_PORT_HANDLING_EGP = "settlement.default_port_handling_egp"
PARAM_DEFAULT_INLAND_TRANSPORT_EGP = "settlement.default_inland_transport_egp"
PARAM_DEFAULT_BANK_FEES_EGP = "settlement.default_bank_fees_egp"
PARAM_DEFAULT_OTHER_EXPENSES_EGP = "settlement.default_other_expenses_egp"
PARAM_VARIANCE_UNIT_TOLERANCE_EGP = "settlement.variance_unit_tolerance_egp"
PARAM_VARIANCE_FILE_TOLERANCE_EGP = "settlement.variance_file_tolerance_egp"
DEFAULT_VARIANCE_UNIT_TOLERANCE_EGP: float = 0.05
DEFAULT_VARIANCE_FILE_TOLERANCE_EGP: float = 100.0

ESTIMATE_PARAMETER_DEFAULTS: Dict[str, float] = {
    PARAM_DEEMED_FREIGHT_PCT: 2.0,
    PARAM_DEEMED_INSURANCE_PCT: 2.5,
    PARAM_DEFAULT_CLEARANCE_EGP: 4500.0,
    PARAM_DEFAULT_PORT_HANDLING_EGP: 5000.0,
    PARAM_DEFAULT_INLAND_TRANSPORT_EGP: 7500.0,
    PARAM_DEFAULT_BANK_FEES_EGP: 2500.0,
    PARAM_DEFAULT_OTHER_EXPENSES_EGP: 2000.0,
}



def _message(code: str, severity: str = "warning", **params: Any) -> SettlementMessage:
    return SettlementMessage(code=code, params=params, severity=severity)


def actual_expense_bucket(category: Optional[str], party_type: Optional[str] = None) -> str:
    """Actual landed-cost bucket of an aggregated expense invoice. Code-first classification (ACC2-T02):
    CLEARANCE_EXPENSE_CATEGORY codes or labels map directly to Clearance & Port / Demurrage & Storage.
    Keywords are used only for other free text."""
    raw = (category or "").strip()
    if raw.startswith("Clearance / "):
        raw = raw[len("Clearance / "):].strip()

    norm = enum_codes.normalize(enum_codes.CLEARANCE_EXPENSE_CATEGORY, raw)
    if enum_codes.is_code(enum_codes.CLEARANCE_EXPENSE_CATEGORY, norm):
        return CLEARANCE_CATEGORY_BUCKET[norm]

    if (party_type or "").upper() == "BROKER":
        leg = enum_codes.legacy_text(enum_codes.CLEARANCE_EXPENSE_CATEGORY, raw)
        leg_norm = enum_codes.normalize(enum_codes.CLEARANCE_EXPENSE_CATEGORY, leg)
        if enum_codes.is_code(enum_codes.CLEARANCE_EXPENSE_CATEGORY, leg_norm):
            return CLEARANCE_CATEGORY_BUCKET[leg_norm]

    cat_lower = raw.lower()
    if any(w in cat_lower for w in ["freight", "ocean", "air", "نولون", "شحن"]):
        return "Freight"
    if any(w in cat_lower for w in ["insurance", "تأمين"]):
        return "Insurance"
    if any(w in cat_lower for w in ["duty", "duties", "46", "وارد", "جمرك"]) and "vat" not in cat_lower and "قيمة مضافة" not in cat_lower and "broker" not in cat_lower and "clearance" not in cat_lower:
        return "Customs Duty"
    if any(w in cat_lower for w in ["vat", "قيمة مضافة", "جدول", "schedule", "خدمات جمركية"]):
        return "VAT & Taxes"
    if any(w in cat_lower for w in ["clearance", "broker", "delivery order", "d/o", "تخليص", "إذن تسليم"]):
        return "Clearance & Port"
    if any(w in cat_lower for w in ["transport", "truck", "inland", "نقل"]):
        return "Inland Transport"
    if any(w in cat_lower for w in ["demurrage", "detention", "storage", "أرضيات", "غرامات", "eir"]):
        return "Demurrage & Storage"
    return "Other & Admin"


# Engine category labels (exact matches in ``calculate_landed_cost_engine``), per settlement expense field of the
# recalculation engine. A stored row belongs to a field when its category is one of these labels, otherwise when
# ``actual_expense_bucket`` puts it in one of the field's buckets. One classifier for read and write (RC-01).
ENGINE_FREIGHT_CATEGORIES = ("Freight", "Shipping", "Ocean Freight", "Air Freight")
ENGINE_CUSTOMS_CATEGORIES = ("Customs Duty", "Customs", "Taxes", "VAT", "Import Duty")
ENGINE_CLEARANCE_CATEGORIES = ("Brokerage", "Clearance", "Brokerage Fees", "Customs Clearance")
ENGINE_TRANSPORT_CATEGORIES = ("Local Transport", "Transport", "Trucking", "Inland Transport")

SETTLEMENT_RECALC_FIELDS: Dict[str, Dict[str, Any]] = {
    "freight_cost_egp": {
        "engine_categories": ENGINE_FREIGHT_CATEGORIES,
        "buckets": ("Freight",),
        "category": "Freight",
        "allocation_rule": "Volume-Based",
    },
    "customs_duties_egp": {
        "engine_categories": ENGINE_CUSTOMS_CATEGORIES,
        "buckets": ("Customs Duty", "VAT & Taxes"),
        "category": "Customs Duty",
        "allocation_rule": "Value-Based",
    },
    "clearance_fees_egp": {
        "engine_categories": ENGINE_CLEARANCE_CATEGORIES,
        "buckets": ("Clearance & Port",),
        "category": "Brokerage",
        "allocation_rule": "Equal",
    },
}


def settlement_expense_field(expense: Dict[str, Any]) -> Optional[str]:
    """Recalculation field (``SETTLEMENT_RECALC_FIELDS`` key) a stored settlement expense row belongs to, or None."""
    category = expense.get("category") or ""
    for field, spec in SETTLEMENT_RECALC_FIELDS.items():
        if category in spec["engine_categories"]:
            return field
    if category in ENGINE_TRANSPORT_CATEGORIES:
        return None
    bucket = expense.get("bucket") or actual_expense_bucket(category, expense.get("party_type"))
    for field, spec in SETTLEMENT_RECALC_FIELDS.items():
        if bucket in spec["buckets"]:
            return field
    return None


def recalc_adjustment_invoice_no(field_name: str) -> str:
    return f"{RECALC_ADJUSTMENT_PREFIX}{field_name}"


def _counts_for_field(expense: Dict[str, Any], field_name: str) -> bool:
    """Importer rows of ``field_name``: seller-paid rows are not landed cost, so they never count (review 3 #2)."""
    return settlement_expense_field(expense) == field_name and not is_seller_paid_expense(expense)


def settlement_field_total(expenses: List[Dict[str, Any]], field_name: str) -> float:
    """Sum of the stored importer rows (adjustment row included) that belong to ``field_name``."""
    return round(sum(float(e.get("amount_egp", 0.0) or 0.0) for e in expenses if _counts_for_field(e, field_name)), 4)


def apply_settlement_field_total(expenses: List[Dict[str, Any]], field_name: str, new_total: float) -> List[Dict[str, Any]]:
    """Bring the rows of ``field_name`` to ``new_total`` through ONE adjustment row ``RECALC-ADJ-<field>`` worth
    ``new_total - sum(other rows)``. User invoices are never changed and a repeated apply is idempotent."""
    spec = SETTLEMENT_RECALC_FIELDS[field_name]
    adj_no = recalc_adjustment_invoice_no(field_name)
    rows = [dict(e) for e in expenses if e.get("invoice_no") != adj_no]
    others = sum(float(e.get("amount_egp", 0.0) or 0.0) for e in rows if _counts_for_field(e, field_name))
    adjustment = round(new_total - others, 2)
    if abs(adjustment) >= 0.005:
        rows.append({
            "invoice_no": adj_no,
            "category": spec["category"],
            "provider_name": "Upstream Sync",
            "currency": "EGP",
            "amount_fx": adjustment,
            "exchange_rate": 1.0,
            "amount_egp": adjustment,
            "allocation_rule": spec["allocation_rule"],
            "is_recalc_adjustment": True,
        })
    return rows


def allocation_ratios(items: List[Dict[str, Any]], rule: str) -> Tuple[List[float], str, List[str]]:
    """
    Computes allocation ratios per item with BP-038 completeness rule.
    Weight / Volume used only when EVERY item value > 0;
    else falls back to Value-Based (or Equal if total FOB is 0) and returns the missing item codes.
    Returns: (ratios, rule_actually_used, missing_item_codes)
    """
    num_items = len(items)
    if num_items == 0:
        return [], rule, []

    def _item_fob(i: Dict[str, Any]) -> float:
        if "fob_total_egp" in i:
            return float(i.get("fob_total_egp") or 0.0)
        if "fob_total_fc" in i:
            return float(i.get("fob_total_fc") or 0.0)
        return float(i.get("qty", 1.0) or 1.0) * float(i.get("fob_unit_egp", 0.0) or 0.0)

    def _item_weight(i: Dict[str, Any]) -> float:
        return float(i.get("gross_weight_kg") or i.get("weight_kg") or 0.0)

    def _item_cbm(i: Dict[str, Any]) -> float:
        return float(i.get("cbm") or 0.0)

    total_fob = sum(_item_fob(i) for i in items)

    def _val_ratios() -> List[float]:
        if total_fob > 0:
            return [_item_fob(i) / total_fob for i in items]
        return [1.0 / num_items] * num_items

    if rule == "Weight-Based":
        missing = [i.get("item_code") or f"ITM-{idx+1}" for idx, i in enumerate(items) if _item_weight(i) <= 0.0]
        tot_weight = sum(_item_weight(i) for i in items)
        if not missing and tot_weight > 0:
            return [_item_weight(i) / tot_weight for i in items], "Weight-Based", []
        return _val_ratios(), "Value-Based", missing

    elif rule == "Volume-Based":
        missing = [i.get("item_code") or f"ITM-{idx+1}" for idx, i in enumerate(items) if _item_cbm(i) <= 0.0]
        tot_cbm = sum(_item_cbm(i) for i in items)
        if not missing and tot_cbm > 0:
            return [_item_cbm(i) / tot_cbm for i in items], "Volume-Based", []
        return _val_ratios(), "Value-Based", missing

    elif rule == "Value-Based":
        if total_fob > 0:
            return _val_ratios(), "Value-Based", []
        return [1.0 / num_items] * num_items, "Equal", []

    elif rule == "Equal":
        return [1.0 / num_items] * num_items, "Equal", []

    return _val_ratios(), "Value-Based", []


def row_amount_egp(exp: Dict[str, Any]) -> float:
    """Returns the EGP amount for an expense row (ACC2-T15, F19):
    uses amount_egp when not None and != 0.0, else amount_fx * (exchange_rate or 1.0 if EGP else 0.0),
    rounded to 2 decimal places."""
    amt = exp.get("amount_egp")
    if amt is not None and float(amt) != 0.0:
        return round(float(amt), 2)
    fx = float(exp.get("amount_fx") or 0.0)
    ccy = (exp.get("currency") or "EGP").upper().strip()
    rate = exp.get("exchange_rate")
    if rate is None or float(rate) <= 0.0:
        rate = 1.0 if ccy == "EGP" else 0.0
    else:
        rate = float(rate)
    return round(fx * rate, 2)


def calculate_landed_cost_engine(
    expenses: List[Dict[str, Any]],
    items: List[Dict[str, Any]],
    incoterm: str = "FOB",
) -> Dict[str, Any]:
    """
    Core Landed Cost & Cost Allocation Calculation Engine (BP-038 & BP-039).
    Allocates freight, customs duties, brokerage, local transport, and storage expenses
    across items based on Value, Weight, Volume (CBM), or Equal distribution rules.

    Incoterm: the code is only normalised and echoed back. There is no Incoterm-aware exclusion (Q11 backlog):
    a row is left out only when it is flagged ``is_seller_paid`` or ``payer == "seller"``. Categories outside
    the freight / customs / clearance / transport label sets (e.g. "Insurance", "VAT & Taxes") are allocated
    to ``allocated_other_egp``.
    """
    incoterm_normalized = (incoterm or "FOB").upper().strip()

    if not items or len(items) == 0:
        # Seller-paid rows are never the importer's cost, with or without items (review 2 #10).
        importer_total = round(sum(row_amount_egp(e) for e in expenses if not is_seller_paid_expense(e)), 2)
        return {
            "incoterm_code": incoterm_normalized,
            "total_fob_egp": 0.0,
            "total_expenses_egp": importer_total,
            "total_landed_cost_egp": importer_total,
            "average_markup_factor": 1.0,
            "item_landed_costs": [],
        }

    # Reset allocation buckets on items
    for item in items:
        qty = item.get("qty")
        if qty is None:
            qty = item.get("quantity", 1)
        fob_unit = item.get("fob_unit_egp", 0.0)
        item["fob_total_egp"] = qty * fob_unit
        item["allocated_freight_egp"] = 0.0
        item["allocated_customs_egp"] = 0.0
        item["allocated_clearance_egp"] = 0.0
        item["allocated_transport_egp"] = 0.0
        item["allocated_other_egp"] = 0.0

    total_fob_egp = sum(i["fob_total_egp"] for i in items)
    total_expenses_egp = 0.0

    for exp in expenses:
        # If marked as seller-paid under CIF/CFR/DDP, do not double-add to importer's expense total
        if is_seller_paid_expense(exp):
            continue

        amount_egp = row_amount_egp(exp)
        exp["amount_egp"] = amount_egp

        total_expenses_egp += amount_egp
        category = exp.get("category", "Other")
        rule = exp.get("allocation_rule", "Value-Based")

        ratios, actual_rule, _ = allocation_ratios(items, rule)
        for idx, item in enumerate(items):
            allocated_share = amount_egp * ratios[idx]

            if category in ENGINE_FREIGHT_CATEGORIES:
                item["allocated_freight_egp"] += allocated_share
            elif category in ENGINE_CUSTOMS_CATEGORIES:
                item["allocated_customs_egp"] += allocated_share
            elif category in ENGINE_CLEARANCE_CATEGORIES:
                item["allocated_clearance_egp"] += allocated_share
            elif category in ENGINE_TRANSPORT_CATEGORIES:
                item["allocated_transport_egp"] += allocated_share
            else:
                item["allocated_other_egp"] += allocated_share

    # Compute final landed cost per item
    for item in items:
        qty = _unit_qty(item.get("qty", 1))
        tot_alloc = (
            item["allocated_freight_egp"] +
            item["allocated_customs_egp"] +
            item["allocated_clearance_egp"] +
            item["allocated_transport_egp"] +
            item["allocated_other_egp"]
        )
        item["total_landed_cost_egp"] = item["fob_total_egp"] + tot_alloc
        item["unit_landed_cost_egp"] = item["total_landed_cost_egp"] / qty
        item["markup_factor"] = (
            item["unit_landed_cost_egp"] / item["fob_unit_egp"]
            if item["fob_unit_egp"] > 0
            else 1.0
        )

    total_landed_cost_egp = total_fob_egp + total_expenses_egp
    average_markup_factor = (
        total_landed_cost_egp / total_fob_egp if total_fob_egp > 0 else 1.0
    )

    return {
        "incoterm_code": incoterm_normalized,
        "total_fob_egp": round(total_fob_egp, 2),
        "total_expenses_egp": round(total_expenses_egp, 2),
        "total_landed_cost_egp": round(total_landed_cost_egp, 2),
        "average_markup_factor": round(average_markup_factor, 4),
        "item_landed_costs": items,
    }


def _unit_qty(qty: Any) -> float:
    """Quantity used for unit costs: the real quantity when positive (0.5 kg is 0.5, review 2 #7), 1 otherwise."""
    value = float(qty or 0.0)
    return value if value > 0 else 1.0


def is_seller_paid_expense(exp: Dict[str, Any]) -> bool:
    """Rows the engine leaves out of the importer's cost (and the Odoo journal leaves out of the credits)."""
    return bool(exp.get("is_seller_paid", False)) or (exp.get("payer") or "").lower() == "seller"


# ==============================================================================
# Exchange rates (FS-02): no literal rate anywhere in this module
# ==============================================================================

class SettlementFx:
    """Exchange rates to EGP for one request, read once per (currency, rate type, date) from the currency rate
    table. ``CurrencyService`` answers a built-in fallback (``rate_id`` None) when no rate row exists: that is a
    hard-coded number, so it is refused with 409 ``SETTLEMENT_FX_RATE_MISSING`` (currency, on_date).
    Rate type (Q2): commercial for actual invoices, customs for the customs estimate."""

    def __init__(self, db: Session, rate_type: str = "commercial"):
        self.db = db
        self.rate_type = rate_type
        self._cache: Dict[Tuple[str, str, date], float] = {}

    def rate(self, currency: Optional[str], on_date: Optional[date] = None, rate_type: Optional[str] = None) -> float:
        from modules.currencies.service import CurrencyService

        code = (currency or "").upper().strip()
        day = on_date or cairo_today()
        if code == "EGP":
            return 1.0
        rtype = rate_type or self.rate_type
        key = (code, rtype, day)
        if key in self._cache:
            return self._cache[key]
        rate_val, rate_id = 0.0, None
        if code:
            try:
                rate_val, _, rate_id = CurrencyService(self.db)._get_rate_to_egp(code, rate_type=rtype, as_of_date=day)
            except HTTPException as exc:
                if exc.status_code not in (404, 409):  # unregistered currency or missing rate -> coded 409 below
                    raise
        if rate_id is None or not rate_val or float(rate_val) <= 0:
            raise fx_rate_missing_error(code or None, day)
        self._cache[key] = float(rate_val)
        return float(rate_val)

    def rate_or_none(self, currency: Optional[str], on_date: Optional[date] = None) -> Optional[float]:
        """``rate`` for display-only values: a missing rate gives None instead of the 409."""
        try:
            return self.rate(currency, on_date)
        except HTTPException as exc:
            if isinstance(exc.detail, dict) and exc.detail.get("code") == SETTLEMENT_FX_RATE_MISSING:
                return None
            raise


def _as_date(value: Any) -> Optional[date]:
    """Business date of a stored value: datetimes are converted to Cairo, ISO strings are parsed."""
    if value is None or value == "":
        return None
    if isinstance(value, datetime):
        return cairo_date(value)
    if isinstance(value, date):
        return value
    try:
        return date.fromisoformat(str(value).strip()[:10])
    except ValueError:
        return None


def purchase_order_rate_to_egp(po: Any, fx: SettlementFx) -> float:
    """EGP rate of a purchase order: 1 for EGP, the stored rate when set, else the commercial rate on the order
    date. ``exchange_rate`` defaults to 1.0 in the table, so 1.0 on a foreign-currency PO means "not set"."""
    code = (getattr(po.currency, "currency_code", None) or "").upper() if getattr(po, "currency", None) else ""
    if code == "EGP":
        return 1.0
    stored = float(po.exchange_rate or 0.0)
    if stored > 0 and stored != 1.0:
        return stored
    return fx.rate(code or None, cairo_date(po.order_date))


def _purchase_orders_of_file(db: Session, imp_file: ImportFile) -> List[Any]:
    """Active purchase orders of an import file: linked by ``import_file_id`` or listed in ``po_ids``."""
    import json as _json
    from sqlalchemy import or_
    from modules.purchase_orders.model import PurchaseOrder

    po_ids = imp_file.po_ids or []
    if isinstance(po_ids, str):
        po_ids = _json.loads(po_ids) if po_ids.strip() else []
    conditions = [PurchaseOrder.import_file_id == imp_file.import_file_id]
    if po_ids:
        conditions.append(PurchaseOrder.po_id.in_(po_ids))
    return (
        db.query(PurchaseOrder)
        .filter(PurchaseOrder.is_active == True, or_(*conditions))
        .order_by(PurchaseOrder.po_id)
        .all()
    )


def _line_item_name(line: Any, fallback: str) -> str:
    return line.description_en or line.main_description or line.description_ar or fallback


def file_po_line_shares(
    db: Session,
    imp_file: ImportFile,
    messages: Optional[List[SettlementMessage]] = None,
) -> List[Tuple[Any, float, float]]:
    """
    Computes per-line shares for the import file across its purchase orders (ACC2-T01 / FS-05).
    Returns a list of tuples: (line, qty_share, ratio) where:
      - line: POLineItem instance
      - qty_share: quantity allocated to this import file
      - ratio: fraction of the line quantity (qty_share / line.quantity), or PO-level ratio.

    Rules:
      1. For each active PO of the file:
         - Load POShipmentAllocation rows for the PO.
         - If NO allocation rows exist for the PO:
           every line gets (line, float(line.quantity or 0.0), 1.0).
         - If allocation rows exist for the PO across any file:
           - If NO allocation rows exist for THIS file:
             skip the PO entirely, and if messages is provided, add SETTLEMENT_PO_NOT_ALLOCATED.
           - If allocation rows exist for THIS file:
             * Item-level allocations (po_item_id is not None and import_file_id == imp_file.import_file_id):
               qty_share = sum(shipped_quantity), ratio = qty_share / line.quantity (0 if line.quantity == 0).
             * PO-level allocations (po_item_id is None and import_file_id == imp_file.import_file_id):
               po_ratio = sum(shipped_amount_fob) / po.total_amount_fob (0 if total_amount_fob == 0).
               For any line not covered by item-level allocations, qty_share = round(line.quantity * po_ratio, 4), ratio = po_ratio.
             * Only lines with qty_share > 0 are included.
    """
    from modules.purchase_orders.model import POShipmentAllocation

    shares: List[Tuple[Any, float, float]] = []
    for po in _purchase_orders_of_file(db, imp_file):
        allocs = (
            db.query(POShipmentAllocation)
            .filter(POShipmentAllocation.po_id == po.po_id)
            .all()
        )
        lines = sorted(po.line_items or [], key=lambda li: li.item_id or 0)
        if not lines:
            continue

        if not allocs:
            # Case 1: No allocation rows exist for the PO at all
            for line in lines:
                shares.append((line, float(line.quantity or 0.0), 1.0))
            continue

        file_allocs = [a for a in allocs if a.import_file_id == imp_file.import_file_id]
        other_allocs = [a for a in allocs if a.import_file_id is not None and a.import_file_id != imp_file.import_file_id]
        if not file_allocs:
            if other_allocs:
                # Case 2: Allocation rows exist for other import files
                if messages is not None:
                    po_num = po.po_number or f"PO-{po.po_id}"
                    messages.append(_message("SETTLEMENT_PO_NOT_ALLOCATED", po_number=po_num))
                continue
            else:
                # Only unlinked rows (import_file_id is None) exist -> keep full-PO behavior
                for line in lines:
                    shares.append((line, float(line.quantity or 0.0), 1.0))
                continue

        # Case 3: Allocation rows exist for this file
        item_allocs = [a for a in file_allocs if a.po_item_id is not None]
        po_allocs = [a for a in file_allocs if a.po_item_id is None]

        po_ratio = 0.0
        if po_allocs:
            po_total_fob = float(po.total_amount_fob or 0.0)
            if po_total_fob <= 0.0:
                po_total_fob = sum(
                    float(li.total_price or (float(li.quantity or 0.0) * float(li.unit_price or 0.0)))
                    for li in lines
                )
            value_known = all(float(a.shipped_amount_fob or 0.0) > 0.0 for a in po_allocs)
            shipped_fob = sum(float(a.shipped_amount_fob or 0.0) for a in po_allocs)
            if value_known and shipped_fob > 0.0 and po_total_fob > 0.0:
                po_ratio = shipped_fob / po_total_fob
            else:
                # Fallback when any shipped_amount_fob is <= 0: use quantity ratio
                total_ord_qty = sum(float(li.quantity or 0.0) for li in lines)
                shipped_qty = sum(float(a.shipped_quantity or 0.0) for a in po_allocs)
                po_ratio = (shipped_qty / total_ord_qty) if total_ord_qty > 0.0 else 0.0

        for line in lines:
            line_item_allocs = [a for a in item_allocs if a.po_item_id == line.item_id]
            if line_item_allocs:
                shipped_qty = sum(float(a.shipped_quantity or 0.0) for a in line_item_allocs)
                line_qty = float(line.quantity or 0.0)
                ratio = (shipped_qty / line_qty) if line_qty > 0.0 else 0.0
                if shipped_qty > 0.0:
                    shares.append((line, shipped_qty, ratio))
            elif po_allocs:
                line_qty = float(line.quantity or 0.0)
                shipped_qty = round(line_qty * po_ratio, 4)
                if shipped_qty > 0.0:
                    shares.append((line, shipped_qty, po_ratio))

    return shares


def _items_from_purchase_orders(
    db: Session,
    imp_file: ImportFile,
    fx: SettlementFx,
    messages: Optional[List[SettlementMessage]] = None,
) -> List[Dict[str, Any]]:
    """Settlement items from the PO lines of the file (FS-05): FOB unit in EGP at the PO rate, real weight / CBM /
    HS code (missing values stay 0 / empty). Uses file_po_line_shares for partial shipments (ACC2-T01)."""
    items: List[Dict[str, Any]] = []
    line_shares = file_po_line_shares(db, imp_file, messages=messages)
    po_rates: Dict[int, float] = {}
    for li, share_qty, ratio in line_shares:
        if li.po_id not in po_rates:
            po_rates[li.po_id] = purchase_order_rate_to_egp(li.purchase_order, fx)
        rate = po_rates[li.po_id]
        code = li.item_code or f"ITEM-{li.item_id}"
        items.append({
            "item_code": code,
            "item_name": _line_item_name(li, code),
            # A missing / zero quantity stays 0 on purpose: FOB 0, never an invented 1 (review 3 #8).
            "qty": share_qty,
            "fob_unit_egp": float(li.unit_price or 0.0) * rate,
            "gross_weight_kg": round(float(li.gross_weight_kg or 0.0) * ratio, 4),
            "cbm": round(float(li.total_cbm or 0.0) * ratio, 4),
            "hs_code": (li.tariff.hs_code if li.tariff else "") or "",
            "note": "Auto-fetched from the purchase order lines",
        })
    return items


def _resolve_client_expense_rates(expenses: List[Dict[str, Any]], fx: "SettlementFx") -> None:
    """Fill a missing ``exchange_rate`` on client rows: 1.0 for EGP, else the commercial rate on the invoice date
    (else Cairo today); a missing rate is 409 SETTLEMENT_FX_RATE_MISSING. A stored rate always wins."""
    for e in expenses:
        currency = (e.get("currency") or "EGP").upper()
        stored = float(e.get("exchange_rate") or 0.0)
        if stored > 0 and (currency == "EGP" or stored != 1.0):  # 1.0 on a foreign row = not set (review 2 #5)
            continue
        e["exchange_rate"] = 1.0 if currency == "EGP" else fx.rate(currency, _as_date(e.get("invoice_date")))


def _derive_expense_egp(expenses: List[Dict[str, Any]]) -> None:
    """Server-derived EGP amounts on settlement expense rows (ACC2-T05, F07).
    - EGP -> exchange_rate = 1.0, amount_egp = round(amount_fx, 2) if amount_fx > 0 else round(amount_egp, 2)
    - foreign -> amount_egp = round(amount_fx * exchange_rate, 2) (require amount_fx > 0, 400 otherwise)
    - RECALC-ADJ-* rows only rounded.
    """
    for e in expenses:
        inv_no = str(e.get("invoice_no") or "")
        if inv_no.startswith(RECALC_ADJUSTMENT_PREFIX):
            e["amount_egp"] = round(float(e.get("amount_egp") or 0.0), 2)
            continue
        currency = (e.get("currency") or "EGP").strip().upper()
        amount_fx = float(e.get("amount_fx") or 0.0)
        amount_egp = float(e.get("amount_egp") or 0.0)
        rate = float(e.get("exchange_rate") or 0.0)
        if currency == "EGP":
            e["exchange_rate"] = 1.0
            e["amount_egp"] = round(amount_fx, 2) if amount_fx > 0 else round(amount_egp, 2)
            if amount_fx > 0:
                e["amount_fx"] = round(amount_fx, 2)
        else:
            if amount_fx <= 0:
                raise HTTPException(status_code=400, detail="amount_fx must be > 0 for foreign currency expense row")
            e["amount_egp"] = round(amount_fx * rate, 2)
            e["amount_fx"] = round(amount_fx, 2)


def _validate_client_expenses(expenses: List[Dict[str, Any]]) -> None:
    """Run after ``_resolve_client_expense_rates``: every row then has a positive rate."""
    for e in expenses:
        if (e.get("invoice_no") or "").startswith(RECALC_ADJUSTMENT_PREFIX):
            continue
        amount = max(float(e.get("amount_fx") or 0.0), float(e.get("amount_egp") or 0.0))
        validate_expense_invoice(e.get("invoice_no") or "", amount, float(e.get("exchange_rate") or 0.0))


# Duty component columns of CustomsClearanceRecord -> engine category of the settlement row (lab fees are a
# clearance cost, the rest customs). Same seven fields as customs_clearance DUTY_COMPONENT_FIELDS.
DUTY_COMPONENT_CATEGORIES = (
    ("import_duty_amount", "Customs Duty"),
    ("vat_amount", "VAT"),
    ("schedule_tax_amount", "Taxes"),
    ("development_fee_amount", "Customs"),
    ("customs_service_fees", "Customs"),
    ("wht_amount", "Taxes"),
    ("lab_service_fees", "Clearance"),
)

CUSTOMS_COMPONENT_BUCKET = {
    "import_duty_amount": "Customs Duty",
    "vat_amount": "VAT & Taxes",
    "schedule_tax_amount": "VAT & Taxes",
    "development_fee_amount": "VAT & Taxes",
    "customs_service_fees": "VAT & Taxes",
    "wht_amount": "VAT & Taxes",
    "lab_service_fees": "Clearance & Port",
}


def _duty_row(clearance: Any, category: str, amount: float, component: str) -> Dict[str, Any]:
    return {
        "invoice_no": f"{clearance.declaration_46_no or clearance.clearance_code}/{component}",
        "category": category,
        "description": f"Customs {component} - declaration {clearance.declaration_46_no or clearance.clearance_code}",
        "provider_name": "Egyptian Customs Authority",
        "duty_component": component,
        "amount_egp": amount,
        "amount_fx": 0.0,
        "exchange_rate": 1.0,
        "currency": "EGP",
        "allocation_rule": "Value-Based",
        "is_seller_paid": False,
        "payer": "Importer",
        "note": "Auto-fetched from the customs clearance record",
    }


def _customs_duty_rows(clearance: Any) -> List[Dict[str, Any]]:
    """Settlement rows of an assessed declaration totalling exactly ``actual_duty_total``."""
    total = float(clearance.actual_duty_total or 0.0)
    parts = [(field, cat, float(getattr(clearance, field, 0.0) or 0.0)) for field, cat in DUTY_COMPONENT_CATEGORIES]
    parts = [p for p in parts if p[2] != 0.0]
    if parts and abs(round(sum(p[2] for p in parts), 2) - round(total, 2)) < 0.005:
        return [_duty_row(clearance, cat, amount, field) for field, cat, amount in parts]
    # Assessed / overridden total that the components do not explain: keep the total as one customs row.
    return [_duty_row(clearance, "Customs Duty", total, "actual_duty_total")]


def _recalculate_in_place(record: LandedCostSettlementRecord, actor: str) -> None:
    incoterm = record.incoterm_code or (record.import_file.incoterm_code if record.import_file else "FOB")
    calc_res = calculate_landed_cost_engine(
        [dict(e) for e in (record.expense_invoices or [])],
        [dict(i) for i in (record.item_landed_costs or [])],
        incoterm=incoterm,
    )
    record.total_fob_egp = calc_res["total_fob_egp"]
    record.total_expenses_egp = calc_res["total_expenses_egp"]
    record.total_landed_cost_egp = calc_res["total_landed_cost_egp"]
    record.average_markup_factor = calc_res["average_markup_factor"]
    record.item_landed_costs = calc_res["item_landed_costs"]
    record.status = "Calculated"
    record.updated_at = datetime.now(timezone.utc)
    record.updated_by = actor


def recalculate_settlement_totals(record: LandedCostSettlementRecord, actor: Optional[str] = None) -> None:
    """External-write recomputation (BEW0-06): recalculates totals via the engine.
    If the settlement was in Draft status, it remains in Draft (not promoted to Calculated).
    """
    prior_status = record.status
    _recalculate_in_place(record, actor=actor or "System")
    if prior_status == "Draft":
        record.status = "Draft"



def _audit(db: Session, record: LandedCostSettlementRecord, action: str, actor: str,
           new_data: Optional[Dict[str, Any]] = None, old_data: Optional[Dict[str, Any]] = None) -> None:
    from modules.audit_logs.service import AuditLogService
    AuditLogService(db).log_activity(
        entity_type="LandedCostSettlementRecord",
        entity_id=record.settlement_id,
        entity_code=record.settlement_code,
        action=action,
        old_data=old_data,
        new_data=new_data,
        performed_by=actor,
    )


def _audit_import_file(
    db: Session,
    record: ImportFile,
    action: str,
    actor: str,
    new_data: Optional[Dict[str, Any]] = None,
    old_data: Optional[Dict[str, Any]] = None,
) -> None:
    from modules.audit_logs.service import AuditLogService
    AuditLogService(db).log_activity(
        entity_type="ImportFile",
        entity_id=record.import_file_id,
        entity_code=record.import_file_code,
        action=action,
        old_data=old_data,
        new_data=new_data,
        performed_by=actor,
    )


def _settlement_snapshot_dict(record: Optional[LandedCostSettlementRecord]) -> Dict[str, Any]:
    if not record:
        return {
            "status": None,
            "total_expenses_egp": 0.0,
            "total_landed_cost_egp": 0.0,
            "rows": 0,
        }
    rows = record.expense_invoices if isinstance(record.expense_invoices, list) else []
    return {
        "status": record.status,
        "total_expenses_egp": float(record.total_expenses_egp or 0.0),
        "total_landed_cost_egp": float(record.total_landed_cost_egp or 0.0),
        "rows": len(rows),
    }


def build_initial_settlement(
    db: Session,
    imp_file: ImportFile,
    actor: str,
    expenses_in: Optional[List[Dict[str, Any]]] = None,
    items_in: Optional[List[Dict[str, Any]]] = None,
    incoterm: Optional[str] = None,
    notes: Optional[str] = None,
) -> LandedCostSettlementRecord:
    """Builds an unflushed, calculated LandedCostSettlementRecord with auto-fetched duties and PO items (BE09-T10)."""
    incoterm_code = (incoterm or imp_file.incoterm_code or "FOB").upper()

    expenses = [e if isinstance(e, dict) else e.model_dump() for e in (expenses_in or [])]
    ensure_no_client_adjustment_rows(expenses, stored_rows=[])
    _resolve_client_expense_rates(expenses, SettlementFx(db, "commercial"))
    _derive_expense_egp(expenses)
    _validate_client_expenses(expenses)

    # ── Auto-fetch: Customs Duty totals → expense_invoices pre-fill ──────────
    has_duty_expense = any(
        (e.get("category", "") or "").lower() in ("customs duty", "customs", "import duty", "taxes")
        for e in expenses
    )
    if not has_duty_expense:
        from modules.customs_clearance.model import CustomsClearanceRecord
        clearance = db.query(CustomsClearanceRecord).filter(
            CustomsClearanceRecord.import_file_id == imp_file.import_file_id,
            CustomsClearanceRecord.is_active == True,
            CustomsClearanceRecord.status == "Final Release Granted",
        ).order_by(CustomsClearanceRecord.customs_clearance_id.desc()).first()
        if clearance and (clearance.actual_duty_total or 0) > 0:
            # actual_duty_total already contains the lab fees: one row per duty component when the components add
            # up to the assessed total, else one row for the assessed total. Never a second lab-fee row (review #3).
            expenses.extend(_customs_duty_rows(clearance))
        elif clearance and (clearance.lab_service_fees or 0) > 0:
            expenses.append(_duty_row(clearance, "Clearance", float(clearance.lab_service_fees), "lab_service_fees"))

    # ── Auto-populate: item_landed_costs from PO Line Items (FS-05) ─────────
    messages_settlement: List[SettlementMessage] = []
    items = [i if isinstance(i, dict) else i.model_dump() for i in (items_in or [])]
    if not items:
        items = _items_from_purchase_orders(
            db, imp_file, SettlementFx(db, "commercial"), messages=messages_settlement
        )

    record = build_settlement(
        imp_file.import_file_id, expenses, items, accountant_name=actor, notes=notes, actor=actor
    )
    record.incoterm_code = incoterm_code

    # Perform Landed Cost Engine calculation
    calc_res = calculate_landed_cost_engine(record.expense_invoices, record.item_landed_costs, incoterm=incoterm_code)
    record.total_fob_egp = calc_res["total_fob_egp"]
    record.total_expenses_egp = calc_res["total_expenses_egp"]
    record.total_landed_cost_egp = calc_res["total_landed_cost_egp"]
    record.average_markup_factor = calc_res["average_markup_factor"]
    record.item_landed_costs = calc_res["item_landed_costs"]
    record.status = "Calculated"
    record.messages = messages_settlement
    return record




def _cairo_tz() -> Any:
    try:
        from zoneinfo import ZoneInfo
        return ZoneInfo("Africa/Cairo")
    except Exception:
        return timezone(timedelta(hours=2))

def cairo_date(dt: Optional[datetime] = None) -> date:
    d = dt or datetime.now(timezone.utc)
    if d.tzinfo is None:
        d = d.replace(tzinfo=timezone.utc)
    return d.astimezone(_cairo_tz()).date()

def cairo_today() -> date:
    return cairo_date()



__all__ = [name for name in list(globals().keys()) if not name.startswith('__')]
