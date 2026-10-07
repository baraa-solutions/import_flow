import logging
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from typing import List, Optional, Dict, Any, Tuple
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from sqlalchemy.orm import Session
from fastapi import HTTPException

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
)
from .repository import (
    add_with_new_code,
    apply_settlement_update,
    build_settlement,
    generate_settlement_code,
    get_settlement_by_id,
    get_settlement_by_import_file_id,
    list_settlements,
    soft_delete_settlement,
    restore_settlement,
    get_effective_tax_rate,
)
from .model import WHT_CLEARANCE_SERVICES, WHT_TRANSPORT_SERVICES
from .validators import (
    SETTLEMENT_FX_RATE_MISSING,
    ensure_cost_not_approved,
    ensure_invoices_not_settled,
    ensure_no_other_active_settlement,
    ensure_settlement_editable,
    fx_rate_missing_error,
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

# PL-08 estimate constants, configurable through system_parameters (FS-07). The defaults are the former literals,
# so the estimate is unchanged while no parameter row exists.
PARAM_DEEMED_FREIGHT_PCT = "settlement.deemed_freight_pct"
PARAM_DEEMED_INSURANCE_PCT = "settlement.deemed_insurance_pct"
PARAM_DEFAULT_CLEARANCE_EGP = "settlement.default_clearance_egp"
PARAM_DEFAULT_PORT_HANDLING_EGP = "settlement.default_port_handling_egp"
PARAM_DEFAULT_INLAND_TRANSPORT_EGP = "settlement.default_inland_transport_egp"
PARAM_DEFAULT_BANK_FEES_EGP = "settlement.default_bank_fees_egp"
PARAM_DEFAULT_OTHER_EXPENSES_EGP = "settlement.default_other_expenses_egp"
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
    """Actual landed-cost bucket of an aggregated expense invoice. For broker (clearance) invoices a
    CLEARANCE_EXPENSE_CATEGORY code or English label is matched through its legacy label, so coded rows land
    exactly where the legacy text landed."""
    text = category or ""
    if (party_type or "").upper() == "BROKER":
        text = enum_codes.legacy_text(enum_codes.CLEARANCE_EXPENSE_CATEGORY, text)
    cat_lower = text.lower()
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
        importer_total = sum(e.get("amount_egp", 0.0) for e in expenses if not is_seller_paid_expense(e))
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
        qty = item.get("qty", 1)
        fob_unit = item.get("fob_unit_egp", 0.0)
        item["fob_total_egp"] = qty * fob_unit
        item["allocated_freight_egp"] = 0.0
        item["allocated_customs_egp"] = 0.0
        item["allocated_clearance_egp"] = 0.0
        item["allocated_transport_egp"] = 0.0
        item["allocated_other_egp"] = 0.0

    total_fob_egp = sum(i["fob_total_egp"] for i in items)
    total_weight_kg = sum(i.get("gross_weight_kg", 0.0) for i in items)
    total_cbm = sum(i.get("cbm", 0.0) for i in items)
    num_items = len(items)

    total_expenses_egp = 0.0

    for exp in expenses:
        # If marked as seller-paid under CIF/CFR/DDP, do not double-add to importer's expense total
        if is_seller_paid_expense(exp):
            continue

        amount_egp = exp.get("amount_egp", 0.0)
        if amount_egp == 0.0:
            amount_egp = exp.get("amount_fx", 0.0) * exp.get("exchange_rate", 1.0)
            exp["amount_egp"] = amount_egp

        total_expenses_egp += amount_egp
        category = exp.get("category", "Other")
        rule = exp.get("allocation_rule", "Value-Based")

        for item in items:
            ratio = 1.0 / num_items
            if rule == "Value-Based" and total_fob_egp > 0:
                ratio = item["fob_total_egp"] / total_fob_egp
            elif rule == "Weight-Based" and total_weight_kg > 0:
                ratio = item.get("gross_weight_kg", 0.0) / total_weight_kg
            elif rule == "Volume-Based" and total_cbm > 0:
                ratio = item.get("cbm", 0.0) / total_cbm
            elif rule == "Equal":
                ratio = 1.0 / num_items

            allocated_share = amount_egp * ratio

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
                if exc.status_code != 404:  # unregistered currency or missing rate -> coded 409 below
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


def create_settlement_service(
    db: Session, schema: FinancialSettlementCreate, actor: str = "System"
) -> LandedCostSettlementRecord:
    imp_file = require_active(db, ImportFile, schema.import_file_id, IMPORT_FILE_LABEL_AR, status_code=404)

    existing = get_settlement_by_import_file_id(db, schema.import_file_id)
    if existing:
        raise HTTPException(
            status_code=400,
            detail=f"يوجد بالفعل تسوية مالية وتكلفة وصول (Landed Cost) مسجلة لهذا الملف الاستيرادي (كود التسوية: {existing.settlement_code}). يرجى مراجعة وتحديث التسوية الحالية بدلاً من إنشاء تسوية مكررة.",
        )

    incoterm = (schema.incoterm_code or imp_file.incoterm_code or "FOB").upper()

    expenses_in = [e if isinstance(e, dict) else e.model_dump() for e in (schema.expense_invoices or [])]
    _resolve_client_expense_rates(expenses_in, SettlementFx(db, "commercial"))
    _validate_client_expenses(expenses_in)

    # ── Auto-fetch: Customs Duty totals → expense_invoices pre-fill ──────────
    has_duty_expense = any(
        (e.get("category", "") or "").lower() in ("customs duty", "customs", "import duty", "taxes")
        for e in expenses_in
    )
    if not has_duty_expense:
        from modules.customs_clearance.model import CustomsClearanceRecord
        clearance = db.query(CustomsClearanceRecord).filter(
            CustomsClearanceRecord.import_file_id == schema.import_file_id,
            CustomsClearanceRecord.is_active == True,
            CustomsClearanceRecord.status == "Final Release Granted",
        ).order_by(CustomsClearanceRecord.customs_clearance_id.desc()).first()
        if clearance and (clearance.actual_duty_total or 0) > 0:
            # actual_duty_total already contains the lab fees: one row per duty component when the components add
            # up to the assessed total, else one row for the assessed total. Never a second lab-fee row (review #3).
            expenses_in.extend(_customs_duty_rows(clearance))
        elif clearance and (clearance.lab_service_fees or 0) > 0:
            expenses_in.append(_duty_row(clearance, "Clearance", float(clearance.lab_service_fees), "lab_service_fees"))

    # ── Auto-populate: item_landed_costs from PO Line Items (FS-05) ─────────
    messages_settlement: List[SettlementMessage] = []
    items_in = [i if isinstance(i, dict) else i.model_dump() for i in (schema.item_landed_costs or [])]
    if not items_in:
        items_in = _items_from_purchase_orders(
            db, imp_file, SettlementFx(db, "commercial"), messages=messages_settlement
        )

    record = build_settlement(
        schema.import_file_id, expenses_in, items_in, accountant_name=actor, notes=schema.notes, actor=actor
    )
    record.incoterm_code = incoterm

    # Perform Landed Cost Engine calculation
    calc_res = calculate_landed_cost_engine(record.expense_invoices, record.item_landed_costs, incoterm=incoterm)
    record.total_fob_egp = calc_res["total_fob_egp"]
    record.total_expenses_egp = calc_res["total_expenses_egp"]
    record.total_landed_cost_egp = calc_res["total_landed_cost_egp"]
    record.average_markup_factor = calc_res["average_markup_factor"]
    record.item_landed_costs = calc_res["item_landed_costs"]
    record.status = "Calculated"
    add_with_new_code(db, record)

    # Update Import File progress
    imp_file.current_module = "Phase 9 - Financial Settlement & Landed Cost Engine"
    if (imp_file.progress_percent or 0.0) < 95.0:
        imp_file.progress_percent = 95.0
    set_file_tracking(
        imp_file,
        stage_code="LANDED_COST_CALCULATED",
        next_action=msg("NA_REVIEW_SETTLEMENT_AND_CLOSE"),
    )
    db.commit()
    db.refresh(record)
    record.messages = messages_settlement
    code = record.settlement_code
    audit_data = {
        "import_file_id": schema.import_file_id,
        "incoterm_code": incoterm,
        "expense_invoices": expenses_in,
        "item_landed_costs": items_in,
        "notes": schema.notes,
    }

    # Follow-up steps never undo the saved settlement (FS-13).
    from modules.lifecycle_board.service import advance_lifecycle_step_service
    best_effort(
        db,
        lambda: advance_lifecycle_step_service(
            db=db,
            import_file_id=schema.import_file_id,
            completed_step_code="STEP_19",
            target_step_codes=["STEP_20"],
            notes_msg=msg("FS_SETTLEMENT_CREATED", settlement_code=code),
            next_action_msg=msg("NA_REVIEW_SETTLEMENT_AND_CLOSE"),
            stage_code="LANDED_COST_CALCULATED",
            assigned_user="Finance Manager",
        ),
        "Lifecycle advance STEP_19->STEP_20",
    )
    best_effort(db, _audit, "AuditLog for LandedCostSettlementRecord create", db, record, "CREATE", actor, new_data=audit_data)
    db.refresh(record)
    return record


def recalculate_settlement_service(db: Session, settlement_id: int, actor: str = "System") -> LandedCostSettlementRecord:
    record = get_settlement_by_id(db, settlement_id)
    if not record:
        raise HTTPException(status_code=404, detail="سجل التسوية المالية غير موجود.")
    ensure_settlement_editable(record)
    _recalculate_in_place(record, actor)
    db.commit()
    db.refresh(record)
    return record


# Columns that may not be set to NULL through PUT.
_NON_NULL_UPDATE_FIELDS = ("incoterm_code", "status", "expense_invoices", "item_landed_costs")


def update_settlement_service(
    db: Session, settlement_id: int, schema: FinancialSettlementUpdate, actor: str = "System"
) -> LandedCostSettlementRecord:
    existing = get_settlement_by_id(db, settlement_id)
    if not existing:
        raise HTTPException(status_code=404, detail="سجل التسوية المالية غير موجود.")
    ensure_settlement_editable(existing)

    update_data = schema.model_dump(exclude_unset=True)
    update_data.pop("accountant_name", None)  # ignored: the acting user is recorded in updated_by
    for key in _NON_NULL_UPDATE_FIELDS:
        if key in update_data and update_data[key] is None:
            del update_data[key]
    if update_data.get("expense_invoices") is not None:
        _resolve_client_expense_rates(update_data["expense_invoices"], SettlementFx(db, "commercial"))
        _validate_client_expenses(update_data["expense_invoices"])
    old_data = {k: getattr(existing, k, None) for k in update_data.keys()}

    apply_settlement_update(db, existing, update_data, actor)
    _recalculate_in_place(existing, actor)
    db.commit()
    db.refresh(existing)

    best_effort(
        db, _audit, "AuditLog for LandedCostSettlementRecord update", db, existing, "UPDATE", actor,
        new_data=update_data, old_data=old_data,
    )
    db.refresh(existing)
    return existing

def get_settlement_service(db: Session, settlement_id: int) -> LandedCostSettlementRecord:
    record = get_settlement_by_id(db, settlement_id)
    if not record:
        raise HTTPException(status_code=404, detail="سجل التسوية المالية غير موجود.")
    return record

def list_settlements_service(
    db: Session,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    search: Optional[str] = None,
) -> List[LandedCostSettlementRecord]:
    return list_settlements(db, include_inactive, import_file_id, status, search)

def soft_delete_settlement_service(db: Session, settlement_id: int, actor: str = "System") -> bool:
    record = get_settlement_service(db, settlement_id)
    ensure_settlement_editable(record)
    soft_delete_settlement(db, record, actor)
    db.commit()
    return True

def restore_settlement_service(db: Session, settlement_id: int, actor: str = "System") -> LandedCostSettlementRecord:
    record = get_settlement_by_id(db, settlement_id, include_inactive=True)
    if not record:
        raise HTTPException(status_code=404, detail=f"سجل التسوية التكليفية رقم {settlement_id} غير موجود.")
    if not record.is_active:
        ensure_no_other_active_settlement(get_settlement_by_import_file_id(db, record.import_file_id), settlement_id)
    restore_settlement(db, record, actor)
    db.commit()
    db.refresh(record)
    return record


# ==============================================================================
# PL-08: Estimated Landed Cost Simulation Service
# ==============================================================================

def _estimate_parameter(db: Session, key: str) -> float:
    return get_float_parameter(db, key, ESTIMATE_PARAMETER_DEFAULTS[key])


def simulate_estimated_landed_cost_service(
    db: Session,
    import_file_id: int,
    request: Optional[EstimatedLandedCostSimulationRequest] = None,
) -> EstimatedLandedCostSimulationResponse:
    """
    محاكاة واحتساب تكلفة الوصول التقديرية للشحنة وللوحدة الواحدة (PL-08: Estimated Landed Cost Simulation).
    تجمع بين:
    1. قيمة البضاعة التقديرية (FOB).
    2. النولون التقديري (من العرض الفائز في RFQ أو النولون الحكمي - system parameter، الافتراضي 2%).
    3. التأمين البحري التقديري (من الوثيقة أو التأمين الحكمي - system parameter، الافتراضي 2.5%).
    4. الرسوم الجمركية والضرائب ورسوم الخدمات (من محرك التعريفة الجمركية المصري MD-008).
    5. مصاريف الميناء والعتالة والتخليص الجمركي والنقل الداخلي والمصاريف البنكية.
    6. توزيع المصاريف على الأصناف واحتساب تكلفة الوصول للوحدة ومعامل الزيادة Markup %.
    Lines without an HS code are left out of the customs estimate (``messages[] SETTLEMENT_LINE_NO_HS``).
    """
    from modules.purchase_orders.model import PurchaseOrder
    from modules.customs_tariff.service import estimate_multi_item_customs_duty_service
    from modules.customs_tariff.schemas import (
        MultiItemCustomsEstimateRequest,
        MultiItemCustomsEstimateLine,
    )
    from modules.freight_quotations.model import FreightRFQRequest, FreightQuotationItem

    req = request or EstimatedLandedCostSimulationRequest()
    calc_date = req.estimate_date or cairo_today()
    messages: List[SettlementMessage] = []

    imp_file = require_active(db, ImportFile, import_file_id, IMPORT_FILE_LABEL_AR, status_code=404)

    # 1. Fetch Purchase Orders and Items (FS-05, ACC2-T01: partial shipments supported)
    line_shares = file_po_line_shares(db, imp_file, messages=messages)

    currency = "USD"
    items_raw = []
    line_no = 1

    for itm, share_qty, ratio in line_shares:
        if share_qty <= 0.0:
            continue
        po = itm.purchase_order
        if po and po.currency and getattr(po.currency, "currency_code", None):
            currency = po.currency.currency_code
        po_currency = (getattr(po.currency, "currency_code", None) or "") if (po and po.currency) else ""

        hs = (itm.tariff.hs_code if itm.tariff else "") or ""
        hs = hs.strip() if hs.strip() else (imp_file.hs_code or "").strip()
        qty = share_qty
        u_price = float(itm.unit_price or 0.0)
        tot_price = round(qty * u_price, 2)

        w_kg = round(float(itm.gross_weight_kg or 0.0) * ratio, 4)
        cbm_val = round(float(itm.total_cbm or 0.0) * ratio, 4)
        origin = (getattr(itm, "country_of_origin", "") or (getattr(po, "country_of_origin", "") if po else "") or "").strip()
        if origin and " - " in origin:
            origin = origin.split(" - ")[0].strip()
        if origin and len(origin) > 2:
            origin = origin[:2]

        items_raw.append({
            "line_no": line_no,
            "item_code": itm.item_code or f"ITM-{line_no:03d}",
            "item_name": _line_item_name(itm, f"Item #{line_no}"),
            "hs_code": hs,
            "qty": qty,
            "unit_price_fc": u_price,
            "fob_total_fc": tot_price,
            "weight_kg": w_kg,
            "cbm": cbm_val,
            "origin_country": origin.upper() if origin else None,
            "currency": po_currency,
        })
        line_no += 1

    # Fallback to invoices or estimated_cost if no items (Q4: no invented value or HS code)
    if not items_raw and imp_file.invoices_data:
        for inv in imp_file.invoices_data:
            inv_amt = float(inv.get("amount") or 0.0)
            if inv_amt > 0:
                inv_curr = inv.get("currency") or "USD"
                currency = inv_curr
                items_raw.append({
                    "line_no": line_no,
                    "item_code": f"INV-{line_no:03d}",
                    "item_name": inv.get("description") or f"Invoice Item #{line_no}",
                    "hs_code": (imp_file.hs_code or "").strip(),
                    "qty": 1.0,
                    "unit_price_fc": inv_amt,
                    "fob_total_fc": inv_amt,
                    "weight_kg": 0.0,
                    "cbm": 0.0,
                    "origin_country": None,
                })
                line_no += 1

    if not items_raw and (imp_file.estimated_cost or 0) > 0:
        cost = float(imp_file.estimated_cost)
        currency = imp_file.estimated_cost_currency or "USD"
        items_raw.append({
            "line_no": 1,
            "item_code": "ITM-001",
            "item_name": getattr(imp_file, "product_category", "") or "General Imported Cargo",
            "hs_code": (imp_file.hs_code or "").strip(),
            "qty": 1.0,
            "unit_price_fc": cost,
            "fob_total_fc": cost,
            "weight_kg": 0.0,
            "cbm": 0.0,
            "origin_country": None,
        })

    # Lines left out of the customs request: no HS code, or no value (review 3 #6). Freight / insurance sent to the
    # customs engine are cut to the share of the included lines (review 3 #1).
    for itm in items_raw:
        if not itm["hs_code"]:
            itm["customs_excluded"] = True
            messages.append(_message(SETTLEMENT_LINE_NO_HS, item_code=itm["item_code"], line_no=itm["line_no"]))
        elif itm["fob_total_fc"] <= 0:
            itm["customs_excluded"] = True
            messages.append(_message(SETTLEMENT_LINE_ZERO_VALUE, item_code=itm["item_code"], line_no=itm["line_no"]))
        else:
            itm["customs_excluded"] = False

    # 2. Resolve Exchange Rate (customs rate on the estimate date; a missing rate is a 409, never a literal)
    customs_fx = SettlementFx(db, "customs")
    if req.exchange_rate_override and req.exchange_rate_override > 0:
        fx_rate = float(req.exchange_rate_override)
    else:
        fx_rate = customs_fx.rate(currency, calc_date)

    # Multi-currency POs (review 3 #7): a line in another PO currency is restated in the reference currency at
    # the ratio of the two customs rates, so every EGP value is the line's own currency x its own customs rate.
    for itm in items_raw:
        line_ccy = (itm.get("currency") or "").upper()
        if line_ccy and line_ccy != (currency or "").upper():
            line_rate = customs_fx.rate(line_ccy, calc_date)
            factor = line_rate / fx_rate
            itm["unit_price_fc"] = itm["unit_price_fc"] * factor
            itm["fob_total_fc"] = itm["fob_total_fc"] * factor

    total_fob_fc = sum(i["fob_total_fc"] for i in items_raw)
    total_fob_egp = total_fob_fc * fx_rate

    deemed_freight_pct = _estimate_parameter(db, PARAM_DEEMED_FREIGHT_PCT)
    deemed_insurance_pct = _estimate_parameter(db, PARAM_DEEMED_INSURANCE_PCT)

    # 3. Resolve Freight (RFQ or Deemed %)
    expenses_breakdown: List[EstimatedLandedCostExpenseItem] = []
    has_freight_doc = False
    deemed_freight_src = f"نولون حكمي جمركي ({deemed_freight_pct:.1f}% من قيمة FOB)"
    if req.freight_amount_egp_override is not None and req.freight_amount_egp_override >= 0:
        freight_egp = float(req.freight_amount_egp_override)
        freight_src = "تعديل يدوي (User Override)"
        has_freight_doc = True
    else:
        awarded_rfq = (
            db.query(FreightRFQRequest)
            .filter(FreightRFQRequest.import_file_id == import_file_id)
            .order_by(FreightRFQRequest.rfq_id.desc())
            .first()
        )
        if awarded_rfq and awarded_rfq.selected_quotation_id:
            winning_q = db.query(FreightQuotationItem).filter(
                FreightQuotationItem.quotation_id == awarded_rfq.selected_quotation_id
            ).first()
            if winning_q and winning_q.total_cost:
                q_cost = float(winning_q.total_cost)
                q_curr = winning_q.currency_code or currency
                if q_curr.upper() == "EGP":
                    freight_egp = q_cost
                elif q_curr.upper() == (currency or "").upper():
                    freight_egp = q_cost * fx_rate
                else:  # quote in another currency than the goods: its own customs rate (review 2 #1)
                    freight_egp = q_cost * SettlementFx(db, "customs").rate(q_curr, calc_date)
                p_name = getattr(winning_q, "provider_name", None) or getattr(winning_q, "carrier_name", "RFQ Winner")
                freight_src = f"العرض الفائز في مناقصة النولون ({p_name})"
                has_freight_doc = True
            else:
                freight_egp = total_fob_egp * (deemed_freight_pct / 100.0)
                freight_src = deemed_freight_src
        else:
            freight_egp = total_fob_egp * (deemed_freight_pct / 100.0)
            freight_src = deemed_freight_src

    expenses_breakdown.append(EstimatedLandedCostExpenseItem(
        category="Ocean/Air Freight",
        description="النولون والشحن الدولي التقديري",
        amount_fc=round(freight_egp / fx_rate, 2),
        currency=currency,
        amount_egp=round(freight_egp, 2),
        is_estimated=True,
        source=freight_src,
        allocation_rule="Volume-Based" if any(i["cbm"] > 0 for i in items_raw) else "Weight-Based" if any(i["weight_kg"] > 0 for i in items_raw) else "Value-Based",
    ))

    # 4. Resolve Marine Insurance (deemed % or override)
    has_ins_doc = False
    if req.insurance_amount_egp_override is not None and req.insurance_amount_egp_override >= 0:
        insurance_egp = float(req.insurance_amount_egp_override)
        ins_src = "تعديل يدوي (User Override)"
        has_ins_doc = True
    else:
        insurance_egp = total_fob_egp * (deemed_insurance_pct / 100.0)
        ins_src = f"تأمين بحري حكمي جمركي ({deemed_insurance_pct:.1f}% من قيمة FOB)"

    expenses_breakdown.append(EstimatedLandedCostExpenseItem(
        category="Marine Insurance",
        description="التأمين البحري / الجوي التقديري",
        amount_fc=round(insurance_egp / fx_rate, 2),
        currency=currency,
        amount_egp=round(insurance_egp, 2),
        is_estimated=True,
        source=ins_src,
        allocation_rule="Value-Based",
    ))

    # 5. Call Egyptian Customs Engine (PL-07) for accurate per-item customs & VAT (lines with an HS code only)
    customs_lines = [
        MultiItemCustomsEstimateLine(
            line_no=itm["line_no"],
            hs_code=itm["hs_code"],
            value_fc=Decimal(str(round(itm["fob_total_fc"], 2))),
            weight_kg=Decimal(str(round(itm["weight_kg"], 2))),
            qty=Decimal(str(round(itm["qty"], 2))),
            origin_country=itm["origin_country"],
        )
        for itm in items_raw
        if not itm["customs_excluded"]
    ]

    included_fob_fc = sum(i["fob_total_fc"] for i in items_raw if not i["customs_excluded"])
    if included_fob_fc < total_fob_fc and total_fob_fc > 0:
        customs_share = included_fob_fc / total_fob_fc
        customs_freight_egp = freight_egp * customs_share
        customs_insurance_egp = insurance_egp * customs_share
    else:  # every line declared: the full amounts, exactly as before
        customs_freight_egp = freight_egp
        customs_insurance_egp = insurance_egp

    if customs_lines:
        calc_req = MultiItemCustomsEstimateRequest(
            currency=currency,
            exchange_rate=Decimal(str(round(fx_rate, 4))),
            insurance_egp=Decimal(str(round(customs_insurance_egp, 2))),
            freight_egp=Decimal(str(round(customs_freight_egp, 2))),
            packaging_egp=Decimal("0.00"),
            has_insurance_document=has_ins_doc,
            has_freight_document=has_freight_doc,
            estimate_date=calc_date,
            lines=customs_lines,
        )

        customs_breakdown = estimate_multi_item_customs_duty_service(db, calc_req)

        total_customs_duty_egp = float(customs_breakdown.total_duty_egp)
        total_vat_egp = float(customs_breakdown.total_vat_egp)
        total_schedule_tax_egp = float(customs_breakdown.total_schedule_tax_egp)
        total_service_fee_egp = float(customs_breakdown.total_customs_service_fee_egp)
        total_taxes_and_fees_egp = float(getattr(customs_breakdown, "items_taxes_total_egp", None) or getattr(customs_breakdown, "grand_total_payable_egp", 0.0) or (total_customs_duty_egp + total_vat_egp + total_schedule_tax_egp + total_service_fee_egp))
        customs_line_map = {l.line_no: l for l in customs_breakdown.lines}
    else:
        total_customs_duty_egp = total_vat_egp = total_schedule_tax_egp = total_service_fee_egp = 0.0
        total_taxes_and_fees_egp = 0.0
        customs_line_map = {}

    expenses_breakdown.append(EstimatedLandedCostExpenseItem(
        category="Customs Duties",
        description="ضريبة الوارد الجمركية (Import Duty)",
        amount_fc=round(total_customs_duty_egp / fx_rate, 2),
        currency="EGP",
        amount_egp=round(total_customs_duty_egp, 2),
        is_estimated=True,
        source="محرك التعريفة الجمركية المصري MD-008",
        allocation_rule="Direct HS Code Allocation",
    ))

    expenses_breakdown.append(EstimatedLandedCostExpenseItem(
        category="VAT & Taxes",
        description="ضريبة القيمة المضافة وضريبة الجدول ورسوم الخدمات الجمركية",
        amount_fc=round((total_vat_egp + total_schedule_tax_egp + total_service_fee_egp) / fx_rate, 2),
        currency="EGP",
        amount_egp=round(total_vat_egp + total_schedule_tax_egp + total_service_fee_egp, 2),
        is_estimated=True,
        source="مصلحة الضرائب المصرية وقانون القيمة المضافة",
        allocation_rule="Direct HS Code Allocation",
    ))

    # 6. Additional Logistics & Clearance Expenses (overrides, else system parameters with the former defaults)
    clearance_fee = float(req.clearance_fees_egp_override) if req.clearance_fees_egp_override is not None else _estimate_parameter(db, PARAM_DEFAULT_CLEARANCE_EGP)
    port_handling = float(req.port_handling_egp_override) if req.port_handling_egp_override is not None else _estimate_parameter(db, PARAM_DEFAULT_PORT_HANDLING_EGP)
    inland_trucking = float(req.inland_transport_egp_override) if req.inland_transport_egp_override is not None else _estimate_parameter(db, PARAM_DEFAULT_INLAND_TRANSPORT_EGP)
    bank_fees = float(req.bank_fees_egp_override) if req.bank_fees_egp_override is not None else _estimate_parameter(db, PARAM_DEFAULT_BANK_FEES_EGP)
    other_fees = float(req.other_expenses_egp_override) if req.other_expenses_egp_override is not None else _estimate_parameter(db, PARAM_DEFAULT_OTHER_EXPENSES_EGP)

    expenses_breakdown.append(EstimatedLandedCostExpenseItem(
        category="Customs Clearance & Brokerage",
        description="أتعاب التخليص الجمركي وإصدار إذن التسليم والتراخيص",
        amount_fc=round(clearance_fee / fx_rate, 2),
        currency="EGP",
        amount_egp=round(clearance_fee, 2),
        is_estimated=True,
        source="تقدير قياسي / مخلص معتمد" if req.clearance_fees_egp_override is None else "تعديل يدوي",
        allocation_rule="Weight-Based" if any(i["weight_kg"] > 0 for i in items_raw) else "Value-Based",
    ))

    expenses_breakdown.append(EstimatedLandedCostExpenseItem(
        category="Port & Terminal Handling (THC)",
        description="مصاريف الميناء والتفريغ والعتالة والتخزين المؤقت",
        amount_fc=round(port_handling / fx_rate, 2),
        currency="EGP",
        amount_egp=round(port_handling, 2),
        is_estimated=True,
        source="تعريفة محطة الحاويات والميناء" if req.port_handling_egp_override is None else "تعديل يدوي",
        allocation_rule="Volume-Based" if any(i["cbm"] > 0 for i in items_raw) else "Weight-Based" if any(i["weight_kg"] > 0 for i in items_raw) else "Value-Based",
    ))

    expenses_breakdown.append(EstimatedLandedCostExpenseItem(
        category="Inland Transport",
        description="النقل الداخلي بالشاحنات من ميناء الوصول لمخازن الشركة",
        amount_fc=round(inland_trucking / fx_rate, 2),
        currency="EGP",
        amount_egp=round(inland_trucking, 2),
        is_estimated=True,
        source="أسعار النقل البري المعتمدة" if req.inland_transport_egp_override is None else "تعديل يدوي",
        allocation_rule="Weight-Based" if any(i["weight_kg"] > 0 for i in items_raw) else "Volume-Based" if any(i["cbm"] > 0 for i in items_raw) else "Value-Based",
    ))

    expenses_breakdown.append(EstimatedLandedCostExpenseItem(
        category="Banking & Form 4 Fees",
        description="عمولات التحويلات البنكية ومصاريف استخراج نموذج 4 وفتح الاعتماد",
        amount_fc=round(bank_fees / fx_rate, 2),
        currency="EGP",
        amount_egp=round(bank_fees, 2),
        is_estimated=True,
        source="جدول العمولات البنكية الرسمي" if req.bank_fees_egp_override is None else "تعديل يدوي",
        allocation_rule="Value-Based",
    ))

    expenses_breakdown.append(EstimatedLandedCostExpenseItem(
        category="Inspection & Administrative",
        description="فحص الرقابة على الصادرات والواردات، رسوم كارجو إكس، ومصاريف إدارية",
        amount_fc=round(other_fees / fx_rate, 2),
        currency="EGP",
        amount_egp=round(other_fees, 2),
        is_estimated=True,
        source="مصاريف إدارية تقديرية" if req.other_expenses_egp_override is None else "تعديل يدوي",
        allocation_rule="Value-Based",
    ))

    # 7. Allocation per item
    pref = req.allocation_preference or "Value-Based"
    total_weight = sum(i["weight_kg"] for i in items_raw)
    total_cbm = sum(i["cbm"] for i in items_raw)

    items_breakdown: List[EstimatedLandedCostItemBreakdown] = []

    for itm in items_raw:
        l_no = itm["line_no"]
        c_line = customs_line_map.get(l_no)
        excluded_from_customs = itm["customs_excluded"]

        fob_item_egp = itm["fob_total_fc"] * fx_rate
        qty = _unit_qty(itm["qty"])
        fob_unit_egp = fob_item_egp / qty

        # Ratios
        val_ratio = (fob_item_egp / total_fob_egp) if total_fob_egp > 0 else (1.0 / len(items_raw))
        wt_ratio = (itm["weight_kg"] / total_weight) if total_weight > 0 else val_ratio
        cbm_ratio = (itm["cbm"] / total_cbm) if total_cbm > 0 else wt_ratio

        # Select allocation ratio based on preference
        if pref == "Weight-Based" and total_weight > 0:
            primary_ratio = wt_ratio
        elif pref == "Volume-Based" and total_cbm > 0:
            primary_ratio = cbm_ratio
        else:
            primary_ratio = val_ratio

        # Allocation shares
        alloc_freight = freight_egp * (cbm_ratio if total_cbm > 0 else (wt_ratio if total_weight > 0 else val_ratio))
        alloc_ins = insurance_egp * val_ratio

        if excluded_from_customs:
            alloc_duty = 0.0
            alloc_vat = 0.0
        else:
            alloc_duty = float(c_line.duty_egp) if c_line else (total_customs_duty_egp * val_ratio)
            alloc_vat = (
                float(
                    c_line.vat_egp
                    + c_line.schedule_tax_egp
                    + c_line.customs_service_fee_egp
                    + getattr(c_line, "development_fee_egp", 0.0)
                    + getattr(c_line, "import_fee_egp", 0.0)
                )
                if c_line
                else ((total_vat_egp + total_schedule_tax_egp + total_service_fee_egp) * val_ratio)
            )

        alloc_clearance_port = (clearance_fee + port_handling) * primary_ratio
        alloc_inland = inland_trucking * (wt_ratio if total_weight > 0 else primary_ratio)
        alloc_other = (bank_fees + other_fees) * val_ratio

        tot_alloc_expenses = (
            alloc_freight + alloc_ins + alloc_duty + alloc_vat +
            alloc_clearance_port + alloc_inland + alloc_other
        )

        item_total_landed = fob_item_egp + tot_alloc_expenses
        item_unit_landed_egp = item_total_landed / qty
        item_unit_landed_fc = item_unit_landed_egp / fx_rate
        item_markup_factor = (item_unit_landed_egp / fob_unit_egp) if fob_unit_egp > 0 else 1.0
        item_markup_pct = (item_markup_factor - 1.0) * 100.0

        items_breakdown.append(EstimatedLandedCostItemBreakdown(
            line_no=l_no,
            item_code=itm["item_code"],
            item_name=itm["item_name"],
            hs_code=itm["hs_code"],
            qty=qty,
            unit_price_fc=round(itm["unit_price_fc"], 2),
            fob_total_fc=round(itm["fob_total_fc"], 2),
            fob_unit_egp=round(fob_unit_egp, 2),
            fob_total_egp=round(fob_item_egp, 2),
            allocated_freight_egp=round(alloc_freight, 2),
            allocated_insurance_egp=round(alloc_ins, 2),
            allocated_customs_duty_egp=round(alloc_duty, 2),
            allocated_vat_egp=round(alloc_vat, 2),
            allocated_clearance_and_port_egp=round(alloc_clearance_port, 2),
            allocated_inland_transport_egp=round(alloc_inland, 2),
            allocated_other_egp=round(alloc_other, 2),
            total_expenses_allocated_egp=round(tot_alloc_expenses, 2),
            total_landed_cost_egp=round(item_total_landed, 2),
            unit_landed_cost_egp=round(item_unit_landed_egp, 2),
            unit_landed_cost_fc=round(item_unit_landed_fc, 2),
            markup_factor=round(item_markup_factor, 4),
            markup_percent=round(item_markup_pct, 2),
        ))

    # 8. Grand Totals
    total_clearance_and_port = clearance_fee + port_handling
    total_other = bank_fees + other_fees
    total_expenses = (
        freight_egp + insurance_egp + total_taxes_and_fees_egp +
        total_clearance_and_port + inland_trucking + total_other
    )
    total_landed_cost_egp = total_fob_egp + total_expenses
    total_landed_cost_fc = total_landed_cost_egp / fx_rate
    avg_markup_factor = (total_landed_cost_egp / total_fob_egp) if total_fob_egp > 0 else 1.0
    avg_markup_pct = (avg_markup_factor - 1.0) * 100.0

    # Executive Summary in Arabic (deprecated: the client renders the numbers)
    customs_pct = round((total_taxes_and_fees_egp / total_expenses * 100.0), 1) if total_expenses > 0 else 0.0
    freight_pct = round(((freight_egp + insurance_egp) / total_expenses * 100.0), 1) if total_expenses > 0 else 0.0

    summary_ar = (
        f"تبلغ تكلفة الوصول التقديرية الإجمالية للشحنة {total_landed_cost_egp:,.2f} جنيه مصري "
        f"({total_landed_cost_fc:,.2f} {currency}) مقارنة بقيمة البضاعة FOB البالغة {total_fob_egp:,.2f} جنيه، "
        f"بمتوسط معامل زيادة {avg_markup_factor:.3f} (أي بنسبة زيادة إجمالية قدرها {avg_markup_pct:.1f}%). "
        f"تشكل الضرائب والرسوم الجمركية النسبة الأكبر من المصاريف المضافة ({customs_pct}%)، "
        f"بينما يمثل النولون والتأمين البحري ({freight_pct}%)، والباقي موزع بين مصاريف الموانئ والتخليص والنقل الداخلي."
    )

    total_customs_and_taxes_rounded = round(total_taxes_and_fees_egp, 2)
    total_customs_duty_rounded = round(total_customs_duty_egp, 2)

    return EstimatedLandedCostSimulationResponse(
        import_file_id=import_file_id,
        import_file_code=imp_file.import_file_code or f"IMP-{import_file_id}",
        currency=currency,
        exchange_rate=round(fx_rate, 4),
        incoterm=imp_file.incoterm_code or "FOB",
        total_fob_fc=round(total_fob_fc, 2),
        total_fob_egp=round(total_fob_egp, 2),
        total_freight_egp=round(freight_egp, 2),
        total_insurance_egp=round(insurance_egp, 2),
        total_customs_and_taxes_egp=total_customs_and_taxes_rounded,
        total_clearance_and_port_egp=round(total_clearance_and_port, 2),
        total_inland_transport_egp=round(inland_trucking, 2),
        total_other_expenses_egp=round(total_other, 2),
        total_expenses_egp=round(total_expenses, 2),
        total_landed_cost_egp=round(total_landed_cost_egp, 2),
        total_landed_cost_fc=round(total_landed_cost_fc, 2),
        average_markup_factor=round(avg_markup_factor, 4),
        average_markup_percent=round(avg_markup_pct, 2),
        expenses_breakdown=expenses_breakdown,
        items_breakdown=items_breakdown,
        executive_summary_ar=summary_ar,
        total_customs_duty_egp=total_customs_duty_rounded,
        total_vat_and_fees_egp=round(total_customs_and_taxes_rounded - total_customs_duty_rounded, 2),
        messages=messages,
    )


# ==============================================================================
# CLO-01: Final Settlement Invoices Aggregation Services
# ==============================================================================

WHT_RATE_NOT_CONFIGURED = "WHT_RATE_NOT_CONFIGURED"
_CAIRO_FALLBACK_TZ = timezone(timedelta(hours=2), "EET")


def _cairo_tz():
    try:
        return ZoneInfo("Africa/Cairo")
    except ZoneInfoNotFoundError:  # tzdata missing (frozen build): standard time, no DST
        logger.warning("Africa/Cairo time zone data unavailable; using a fixed UTC+2 offset")
        return _CAIRO_FALLBACK_TZ


def cairo_date(value: Optional[datetime]) -> Optional[date]:
    """Business date in Cairo of a stored timestamp. Naive values are stored UTC."""
    if value is None:
        return None
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(_cairo_tz()).date()


def cairo_today() -> date:
    return datetime.now(timezone.utc).astimezone(_cairo_tz()).date()


def get_wht_rate_percent(db: Session, tax_code: str, on_date: Optional[date] = None) -> Optional[float]:
    """Withholding tax rate (percent) of ``tax_code`` valid on ``on_date`` (default: today in Cairo), read from
    the effective-dated ``tax_rates`` table. ``None`` when no rate is configured for that date."""
    record = get_effective_tax_rate(db, tax_code, on_date or cairo_today())
    return float(record.rate_percent) if record is not None else None


def resolve_wht_rate_percent(db: Session, tax_code: str, on_date: Optional[date] = None) -> float:
    """``get_wht_rate_percent`` with 0 for "not configured"."""
    rate = get_wht_rate_percent(db, tax_code, on_date)
    return rate if rate is not None else 0.0


def wht_amount_for(amount_egp: float, rate_percent: float) -> float:
    # rate_percent / 100 first: for 1% this is exactly the old ``round(amount * 0.01, 2)`` (1.0 / 100.0 == 0.01),
    # while ``amount * rate / 100`` rounds differently on some cent amounts (17.50 -> 0.17 instead of 0.18).
    return round(amount_egp * (rate_percent / 100.0), 2)


def _wht_rate_missing_warning(tax_code: str, on_date: date, invoice_no: Optional[str]) -> str:
    return (
        f"لا توجد نسبة خصم من المنبع ({tax_code}) سارية بتاريخ {on_date.isoformat()}: "
        f"لم يتم احتساب خصم على الفاتورة {invoice_no or '-'}"
    )


def aggregate_shipment_invoices_service(
    db: Session,
    import_file_id: int,
) -> InvoicesAggregationResponse:
    """
    CLO-01: Multi-Source Invoice Aggregation Engine.
    Scans all operational modules (Commercial Invoices, Freight Bookings, Cargo Insurance,
    Customs Declaration 46, Clearance Invoices CL-05, Inland Transport TR-01, Demurrage TR-02/TR-05,
    and Warehouse Discrepancies TR-03/TR-04) to assemble a unified multi-party settlement ledger.

    Foreign-currency amounts use the row's stored rate, else the commercial rate on the document date (else
    Cairo today); a missing rate is a 409 ``SETTLEMENT_FX_RATE_MISSING`` (FS-02). Payment status rules kept as
    they were (Q8): freight and insurance count as PAID, a file SWIFT number marks the goods invoices PAID.
    """
    from modules.freight_booking.model import ShipmentBooking
    from modules.cargo_insurance.model import CargoInsuranceCertificate
    from modules.customs_clearance.model import CustomsClearanceRecord, ClearanceExpenseInvoice
    from modules.inland_transport.model import InlandTransportBooking
    from modules.demurrage_detention.model import DemurrageTracking

    imp = require_active(db, ImportFile, import_file_id, IMPORT_FILE_LABEL_AR, status_code=404)
    fx = SettlementFx(db, "commercial")

    currency = imp.estimated_cost_currency or "USD"
    messages: List[SettlementMessage] = []
    goods_rate: Optional[float] = None

    invoices: List[AggregatedInvoiceItemSchema] = []

    # 1. Commercial Goods Invoices (FOB / CIF from PO & Invoices Data)
    invoices_data = imp.invoices_data or []
    if invoices_data and isinstance(invoices_data, list):
        for idx, inv in enumerate(invoices_data):
            inv_no = str(inv.get("invoice_no") or inv.get("invoice_number") or f"COMM-{imp.import_file_code}-{idx+1}")
            inv_date = str(inv.get("invoice_date") or (imp.file_opening_date or ""))
            c_curr = str(inv.get("currency") or currency)
            if c_curr.upper() == "EGP":
                c_rate = float(inv.get("exchange_rate") or 1.0)
            elif inv.get("exchange_rate") and float(inv.get("exchange_rate")) != 1.0:  # 1.0 on foreign = not set
                c_rate = float(inv.get("exchange_rate"))
            else:
                c_rate = fx.rate(c_curr, _as_date(inv.get("invoice_date")))
            if goods_rate is None:
                goods_rate = c_rate
            amt_fc = float(inv.get("amount") or inv.get("total_amount") or inv.get("total_fob") or 0.0)
            amt_egp = round(amt_fc * c_rate if c_curr != "EGP" else amt_fc, 2)
            is_paid = bool(imp.swift_no or inv.get("payment_status") == "PAID" or inv.get("paid"))
            paid_egp = amt_egp if is_paid else 0.0
            rem_egp = max(0.0, amt_egp - paid_egp)
            status = "PAID" if rem_egp == 0 else ("PARTIAL" if paid_egp > 0 else "UNPAID")

            invoices.append(AggregatedInvoiceItemSchema(
                invoice_id=f"COMM-{idx+1}",
                invoice_no=inv_no,
                invoice_date=inv_date or None,
                party_type="SUPPLIER",
                party_type_ar="المورد الأجنبي",
                party_name=imp.supplier_name or "المورد الأجنبي",
                category="Commercial Goods",
                category_ar="قيمة البضاعة التجارية (FOB/CIF)",
                currency=c_curr,
                exchange_rate=c_rate,
                amount_fc=amt_fc,
                amount_egp=amt_egp,
                paid_amount_egp=paid_egp,
                remaining_amount_egp=rem_egp,
                payment_status=status,
                payment_reference=imp.swift_no or inv.get("payment_ref") or "سويفت بنكي",
                withholding_tax_rate=0.0,
                withholding_tax_amount_egp=0.0,
                net_payable_egp=amt_egp,
                source_module="Commercial Invoice",
                notes=f"فاتورة تجارية للشحنة {imp.import_file_code}",
            ))
    elif imp.estimated_cost and imp.estimated_cost > 0:
        amt_fc = float(imp.estimated_cost)
        est_rate = 1.0 if currency.upper() == "EGP" else fx.rate(currency, _as_date(imp.file_opening_date))
        goods_rate = est_rate
        amt_egp = round(amt_fc * est_rate if currency != "EGP" else amt_fc, 2)
        is_paid = bool(imp.swift_no)
        paid_egp = amt_egp if is_paid else 0.0
        rem_egp = max(0.0, amt_egp - paid_egp)
        status = "PAID" if rem_egp == 0 else "UNPAID"

        invoices.append(AggregatedInvoiceItemSchema(
            invoice_id="COMM-1",
            invoice_no=f"COMM-{imp.import_file_code}",
            invoice_date=str(imp.file_opening_date) if imp.file_opening_date else None,
            party_type="SUPPLIER",
            party_type_ar="المورد الأجنبي",
            party_name=imp.supplier_name or "المورد الأجنبي",
            category="Commercial Goods",
            category_ar="قيمة البضاعة التجارية (FOB)",
            currency=currency,
            exchange_rate=est_rate,
            amount_fc=amt_fc,
            amount_egp=amt_egp,
            paid_amount_egp=paid_egp,
            remaining_amount_egp=rem_egp,
            payment_status=status,
            payment_reference=imp.swift_no or "سويفت بنكي",
            withholding_tax_rate=0.0,
            withholding_tax_amount_egp=0.0,
            net_payable_egp=amt_egp,
            source_module="Commercial Invoice",
            notes="قيمة البضاعة التقديرية المعتمدة في أمر الشراء",
        ))

    # 2. Freight Bookings (Ocean / Air Freight), USD at the booking confirmation date
    bookings = db.query(ShipmentBooking).filter(
        ShipmentBooking.import_file_id == import_file_id,
        ShipmentBooking.is_active == True
    ).all()
    for b in bookings:
        amt_usd = float(b.total_freight_cost_usd or 0.0)
        if amt_usd > 0:
            frt_rate = fx.rate("USD", cairo_date(b.booking_confirmation_date))
            amt_egp = round(amt_usd * frt_rate, 2)
            invoices.append(AggregatedInvoiceItemSchema(
                invoice_id=f"FRT-{b.booking_id}",
                invoice_no=b.booking_confirmation_no or f"FRT-{b.booking_code}",
                invoice_date=str(b.booking_confirmation_date.date()) if b.booking_confirmation_date else str(b.created_at.date()),
                party_type="CARRIER",
                party_type_ar="وكيل الشحن / الخط الملاحي",
                party_name=b.freight_forwarder_name or b.shipping_line_name or "وكيل الشحن الدولي",
                category="Ocean/Air Freight",
                category_ar="نولون الشحن الدولي ومصاريف الشحن",
                currency="USD",
                exchange_rate=frt_rate,
                amount_fc=amt_usd,
                amount_egp=amt_egp,
                paid_amount_egp=amt_egp,
                remaining_amount_egp=0.0,
                payment_status="PAID",
                payment_reference=b.bill_of_lading_no or b.booking_code,
                withholding_tax_rate=0.0,
                withholding_tax_amount_egp=0.0,
                net_payable_egp=amt_egp,
                source_module="Freight Booking",
                notes=f"نولون بوليصة {b.bill_of_lading_no or b.booking_code}",
            ))

    # 3. Cargo Insurance
    certs = db.query(CargoInsuranceCertificate).filter(
        CargoInsuranceCertificate.import_file_id == import_file_id,
        CargoInsuranceCertificate.is_active == True,
    ).all()
    for c in certs:
        prem = float(c.total_payable_premium or 0.0)
        if prem > 0:
            ins_ccy = (c.currency or "EGP").upper()
            if ins_ccy == "EGP":
                c_rate = 1.0
            elif c.exchange_rate and float(c.exchange_rate) != 1.0:  # the column defaults to 1.0 = "not set"
                c_rate = float(c.exchange_rate)
            else:
                c_rate = fx.rate(ins_ccy, cairo_date(c.created_at))
            amt_egp = round(prem * c_rate, 2)
            invoices.append(AggregatedInvoiceItemSchema(
                invoice_id=f"INS-{c.certificate_id}",
                invoice_no=c.policy_number or c.certificate_code,
                invoice_date=str(c.created_at.date()),
                party_type="INSURANCE",
                party_type_ar="شركة التأمين البحري",
                party_name=c.insurance_company_name or "شركة التأمين البحري",
                category="Marine Insurance",
                category_ar="وثيقة التأمين البحري الشامل",
                currency=c.currency or "EGP",
                exchange_rate=c_rate,
                amount_fc=prem,
                amount_egp=amt_egp,
                paid_amount_egp=amt_egp,
                remaining_amount_egp=0.0,
                payment_status="PAID",
                payment_reference=c.policy_number or c.certificate_code,
                withholding_tax_rate=0.0,
                withholding_tax_amount_egp=0.0,
                net_payable_egp=amt_egp,
                source_module="Cargo Insurance",
                notes=f"وثيقة تأمين بحري تغطية {c.coverage_clause}",
            ))

    # 4. Customs Duties & Port / Delivery Order
    clearances = db.query(CustomsClearanceRecord).filter(
        CustomsClearanceRecord.import_file_id == import_file_id,
        CustomsClearanceRecord.is_active == True,
    ).all()
    has_customs_inv = False
    for cl in clearances:
        # The assessed total (CL-02 / override) is what clearance checks payment against; the component total
        # only while not assessed (review #2).
        assessed_total = float(cl.actual_duty_total or cl.total_duty_payable or 0.0)
        paid = float(cl.duty_paid_amount or 0.0)
        c_duty = round(assessed_total or paid, 2)
        if c_duty > 0:
            has_customs_inv = True
            rem = max(0.0, c_duty - paid)
            p_stat = "PAID" if rem == 0 else ("PARTIAL" if paid > 0 else "UNPAID")
            invoices.append(AggregatedInvoiceItemSchema(
                invoice_id=f"CUST-{cl.customs_clearance_id}",
                invoice_no=cl.sadad_number or cl.declaration_46_no or cl.bank_receipt_no or f"DECL46-{imp.import_file_code}",
                invoice_date=str(cl.payment_date.date()) if cl.payment_date else (str(cl.declaration_46_date.date()) if cl.declaration_46_date else None),
                party_type="CUSTOMS",
                party_type_ar="مصلحة الجمارك المصرية",
                party_name=cl.customs_office_name or "مصلحة الجمارك المصرية (منظومة نافذة)",
                category="Customs Duties & Taxes",
                category_ar="الرسوم والضرائب الجمركية (إقرار 46 / سداد)",
                currency="EGP",
                exchange_rate=1.0,
                amount_fc=c_duty,
                amount_egp=c_duty,
                paid_amount_egp=paid,
                remaining_amount_egp=rem,
                payment_status=p_stat,
                payment_reference=cl.sadad_number or cl.bank_receipt_no or "إيصال سداد إلكتروني",
                withholding_tax_rate=0.0,
                withholding_tax_amount_egp=0.0,
                net_payable_egp=c_duty,
                source_module="Customs Declaration 46",
                notes=f"سداد جمركي إقرار 46 رقم {cl.declaration_46_no or 'سداد'}",
            ))

        # Delivery order fees (converted at the delivery order date when not in EGP, FS-10)
        if cl.delivery_order_fees and cl.delivery_order_fees > 0:
            do_fees = float(cl.delivery_order_fees)
            do_ccy = (cl.delivery_order_currency or "EGP").upper()
            do_rate = fx.rate(do_ccy, cairo_date(cl.delivery_order_date)) if do_ccy != "EGP" else 1.0
            do_egp = round(do_fees * do_rate, 2) if do_ccy != "EGP" else do_fees
            is_do_paid = (cl.delivery_order_status or "").lower() in ("paid and received", "paid & received", "paid", "مسدد")
            do_paid = do_egp if is_do_paid else 0.0
            do_rem = max(0.0, do_egp - do_paid)
            do_stat = "PAID" if do_rem == 0 else "UNPAID"
            invoices.append(AggregatedInvoiceItemSchema(
                invoice_id=f"DO-{cl.customs_clearance_id}",
                invoice_no=cl.delivery_order_number or f"DO-{imp.import_file_code}",
                invoice_date=str(cl.delivery_order_date.date()) if cl.delivery_order_date else None,
                party_type="CARRIER",
                party_type_ar="التوكيل الملاحي",
                party_name=cl.shipping_agent_name or "التوكيل الملاحي",
                category="Delivery Order Fees",
                category_ar="رسوم إذن التسليم ومصروفات التوكيل الملاحي",
                currency=cl.delivery_order_currency or "EGP",
                exchange_rate=do_rate,
                amount_fc=do_fees,
                amount_egp=do_egp,
                paid_amount_egp=do_paid,
                remaining_amount_egp=do_rem,
                payment_status=do_stat,
                payment_reference=cl.delivery_order_payment_ref or cl.delivery_order_number or "إيصال التوكيل",
                withholding_tax_rate=0.0,
                withholding_tax_amount_egp=0.0,
                net_payable_egp=do_egp,
                source_module="Delivery Order (CS-02)",
                notes="رسوم ومصاريف إذن تسليم الشحنة",
            ))

    if not has_customs_inv and imp.customs_duty_paid_amount and imp.customs_duty_paid_amount > 0:
        c_duty = round(float(imp.customs_duty_paid_amount), 2)
        invoices.append(AggregatedInvoiceItemSchema(
            invoice_id="CUST-IMP",
            invoice_no=imp.customs_duty_sadad_no or imp.customs_duty_receipt_no or f"CUST-{imp.import_file_code}",
            invoice_date=str(imp.customs_duty_payment_date.date()) if imp.customs_duty_payment_date else None,
            party_type="CUSTOMS",
            party_type_ar="مصلحة الجمارك المصرية",
            party_name="مصلحة الجمارك المصرية (سداد)",
            category="Customs Duties & Taxes",
            category_ar="الرسوم والضرائب الجمركية (سداد)",
            currency="EGP",
            exchange_rate=1.0,
            amount_fc=c_duty,
            amount_egp=c_duty,
            paid_amount_egp=c_duty,
            remaining_amount_egp=0.0,
            payment_status="PAID",
            payment_reference=imp.customs_duty_sadad_no or imp.customs_duty_receipt_no or "سداد إلكتروني",
            withholding_tax_rate=0.0,
            withholding_tax_amount_egp=0.0,
            net_payable_egp=c_duty,
            source_module="Customs Declaration 46",
            notes="رسوم جمركية مسددة بنظام سداد",
        ))

    wht_warnings: List[str] = []

    def _wht_missing(tax_code: str, on_date: date, invoice_no: Optional[str]) -> None:
        wht_warnings.append(_wht_rate_missing_warning(tax_code, on_date, invoice_no))
        messages.append(_message(WHT_RATE_MISSING_WARNING, tax_code=tax_code, on_date=on_date.isoformat(),
                                 invoice_no=invoice_no or "-"))

    # 5. Clearance Invoices (CL-05: ClearanceExpenseInvoice)
    cl_invoices = db.query(ClearanceExpenseInvoice).filter(
        ClearanceExpenseInvoice.import_file_id == import_file_id,
        ClearanceExpenseInvoice.is_active == True
    ).all()
    has_broker_inv = False
    for cl_inv in cl_invoices:
        has_broker_inv = True
        inv_ref = cl_inv.invoice_number or cl_inv.invoice_code
        inv_ccy = (cl_inv.currency or "EGP").upper()
        reported_rate = float(cl_inv.exchange_rate or 1.0)
        if cl_inv.amount_egp:
            amt = round(float(cl_inv.amount_egp), 2)
        else:
            stored_rate = float(cl_inv.exchange_rate or 0.0)
            if inv_ccy == "EGP":
                inv_rate = stored_rate or 1.0
            elif stored_rate > 0 and stored_rate != 1.0:
                inv_rate = stored_rate
            else:
                inv_rate = fx.rate(inv_ccy, cairo_date(cl_inv.invoice_date))
            reported_rate = inv_rate  # the rate actually used (review 2 #11)
            amt = round(float(cl_inv.amount_fx * inv_rate), 2)  # stored rows are cents (review 2 #9)
        is_p = (cl_inv.payment_status or "").lower() in ("paid", "مسدد")
        is_part = "part" in (cl_inv.payment_status or "").lower()
        # A partial payment has no stored paid amount: it is reported as unknown and counted as 0 paid (FS-10).
        paid = float(cl_inv.net_payable_egp if is_p else 0.0)
        if is_part:
            messages.append(_message(PAYMENT_STATUS_UNKNOWN, invoice_no=inv_ref, party_name=cl_inv.provider_name or "-"))
        rem = max(0.0, float(cl_inv.net_payable_egp or amt) - paid)
        # WHT rate valid on the invoice date (Cairo, tax_rates table); a stored wht_amount always wins.
        wht_rate = 0.0
        if cl_inv.wht_deducted:
            wht_date = cairo_date(cl_inv.invoice_date) or cairo_today()
            configured = get_wht_rate_percent(db, WHT_CLEARANCE_SERVICES, wht_date)
            if configured is None and not cl_inv.wht_amount:
                # A real invoice marked "WHT deducted" cannot silently get 0: the net payable would be wrong.
                raise HTTPException(
                    status_code=409,
                    detail={
                        "code": WHT_RATE_NOT_CONFIGURED,
                        "message": (
                            f"لا توجد نسبة خصم من المنبع سارية بتاريخ {wht_date.isoformat()} لفاتورة التخليص "
                            f"{cl_inv.invoice_number or cl_inv.invoice_code}. يرجى ضبط النسبة ({WHT_CLEARANCE_SERVICES}) "
                            "أو إدخال قيمة الخصم على الفاتورة."
                        ),
                        "tax_code": WHT_CLEARANCE_SERVICES,
                        "on_date": wht_date.isoformat(),
                        "invoice_code": cl_inv.invoice_code,
                    },
                )
            wht_rate = configured or 0.0
        wht_amt = float(cl_inv.wht_amount or (wht_amount_for(amt, wht_rate) if cl_inv.wht_deducted else 0.0))
        net = float(cl_inv.net_payable_egp or (amt - wht_amt))

        invoices.append(AggregatedInvoiceItemSchema(
            invoice_id=f"BROKER-{cl_inv.invoice_id}",
            invoice_no=inv_ref,
            invoice_date=str(cl_inv.invoice_date.date()) if cl_inv.invoice_date else None,
            party_type="BROKER",
            party_type_ar="المخلص الجمركي / هيئة الميناء",
            party_name=cl_inv.provider_name or "المخلص الجمركي",
            # Labels, never raw codes; the stored value is exposed additively as category_code.
            category=enum_codes.label_en(enum_codes.CLEARANCE_EXPENSE_CATEGORY, cl_inv.expense_category)
            or "Clearance & Port Expenses",
            category_ar=enum_codes.label_ar(enum_codes.CLEARANCE_EXPENSE_CATEGORY, cl_inv.expense_category)
            or "أتعاب التخليص ومصاريف الميناء والعتالة",
            category_code=cl_inv.expense_category
            if enum_codes.is_code(enum_codes.CLEARANCE_EXPENSE_CATEGORY, cl_inv.expense_category)
            else None,
            currency=cl_inv.currency or "EGP",
            exchange_rate=reported_rate,
            amount_fc=float(cl_inv.amount_fx or amt),
            amount_egp=amt,
            paid_amount_egp=paid,
            remaining_amount_egp=rem,
            payment_status="PAID" if is_p else ("PARTIAL" if is_part else "UNPAID"),
            payment_reference=cl_inv.payment_ref or cl_inv.invoice_code,
            withholding_tax_rate=wht_rate,
            withholding_tax_amount_egp=wht_amt,
            net_payable_egp=net,
            source_module="Clearance Invoice CL-05",
            notes=cl_inv.notes or f"فاتورة تخليص ومصاريف ميناء رقم {cl_inv.invoice_number}",
        ))

    if not has_broker_inv and imp.total_clearance_expenses_egp and imp.total_clearance_expenses_egp > 0:
        amt = float(imp.total_clearance_expenses_egp)
        # Synthetic row: rate on the customs release date (file, else latest clearance record), today as last resort.
        release_dates = [c.release_date for c in clearances if c.release_date]
        wht_date = (
            cairo_date(imp.customs_released_at)
            or (cairo_date(max(release_dates)) if release_dates else None)
            or cairo_today()
        )
        configured = get_wht_rate_percent(db, WHT_CLEARANCE_SERVICES, wht_date)
        if configured is None:
            _wht_missing(WHT_CLEARANCE_SERVICES, wht_date, f"BROK-{imp.import_file_code}")
        wht_rate = configured or 0.0
        wht_amt = wht_amount_for(amt, wht_rate)
        net = round(amt - wht_amt, 2)
        invoices.append(AggregatedInvoiceItemSchema(
            invoice_id="BROKER-IMP",
            invoice_no=f"BROK-{imp.import_file_code}",
            invoice_date=str(datetime.now(timezone.utc).date()),
            party_type="BROKER",
            party_type_ar="المخلص الجمركي / هيئة الميناء",
            party_name=imp.broker_name or "المخلص الجمركي المعتمد",
            category="Customs Clearance & Port Expenses",
            category_ar="إجمالي أتعاب التخليص ومصاريف الميناء",
            currency="EGP",
            exchange_rate=1.0,
            amount_fc=amt,
            amount_egp=amt,
            paid_amount_egp=net,
            remaining_amount_egp=0.0,
            payment_status="PAID",
            payment_reference="سند صرف مكتب التخليص",
            withholding_tax_rate=wht_rate,
            withholding_tax_amount_egp=wht_amt,
            net_payable_egp=net,
            source_module="Clearance Invoice CL-05",
            notes="إجمالي مصاريف التخليص والخدمات بالميناء",
        ))

    # 6. Inland Transport (TR-01: InlandTransportBooking)
    transports = db.query(InlandTransportBooking).filter(
        InlandTransportBooking.import_file_id == import_file_id,
        InlandTransportBooking.is_active == True
    ).all()
    has_trans_inv = False
    for tr in transports:
        amt = round(float(tr.transport_fare_egp or 0.0), 2)
        if amt > 0:
            has_trans_inv = True
            wht_date = cairo_date(tr.booking_date) or cairo_today()
            configured = get_wht_rate_percent(db, WHT_TRANSPORT_SERVICES, wht_date)
            if configured is None:
                _wht_missing(WHT_TRANSPORT_SERVICES, wht_date, tr.waybill_number or tr.transport_code)
            wht_rate = configured or 0.0
            wht = wht_amount_for(amt, wht_rate)
            net = round(amt - wht, 2)
            is_p = tr.status in ("Delivered", "Arrived at Warehouse", "COMPLETED")
            invoices.append(AggregatedInvoiceItemSchema(
                invoice_id=f"TR-{tr.transport_id}",
                invoice_no=tr.waybill_number or tr.transport_code,
                invoice_date=str(tr.booking_date.date()) if tr.booking_date else None,
                party_type="TRANSPORT",
                party_type_ar="شركة النقل الداخلي",
                party_name=tr.carrier_name or "الناقل الداخلي",
                category="Inland Trucking",
                category_ar="نولون النقل البري إلى المستودعات",
                currency="EGP",
                exchange_rate=1.0,
                amount_fc=amt,
                amount_egp=amt,
                paid_amount_egp=net if is_p else 0.0,
                remaining_amount_egp=0.0 if is_p else net,
                payment_status="PAID" if is_p else "UNPAID",
                payment_reference=tr.waybill_number or tr.transport_code,
                withholding_tax_rate=wht_rate,
                withholding_tax_amount_egp=wht,
                net_payable_egp=net,
                source_module="Inland Transport TR-01",
                notes=f"نولون شاحنة {tr.truck_plate_number} السائق {tr.driver_name}",
            ))

    if not has_trans_inv and imp.inland_transport_cost_egp and imp.inland_transport_cost_egp > 0:
        amt = float(imp.inland_transport_cost_egp)
        wht_date = cairo_date(imp.inland_departure_date) or cairo_today()
        configured = get_wht_rate_percent(db, WHT_TRANSPORT_SERVICES, wht_date)
        if configured is None:
            _wht_missing(
                WHT_TRANSPORT_SERVICES, wht_date, imp.inland_transport_booking_no or f"TR-{imp.import_file_code}"
            )
        wht_rate = configured or 0.0
        wht = wht_amount_for(amt, wht_rate)
        net = round(amt - wht, 2)
        invoices.append(AggregatedInvoiceItemSchema(
            invoice_id="TR-IMP",
            invoice_no=imp.inland_transport_booking_no or f"TR-{imp.import_file_code}",
            invoice_date=str(imp.inland_departure_date.date()) if imp.inland_departure_date else None,
            party_type="TRANSPORT",
            party_type_ar="شركة النقل الداخلي",
            party_name=imp.inland_carrier_name or "شركة النقل الداخلي",
            category="Inland Trucking",
            category_ar="نولون النقل البري للشحنة",
            currency="EGP",
            exchange_rate=1.0,
            amount_fc=amt,
            amount_egp=amt,
            paid_amount_egp=net,
            remaining_amount_egp=0.0,
            payment_status="PAID",
            payment_reference=imp.inland_transport_booking_no or "بوليصة نقل بري",
            withholding_tax_rate=wht_rate,
            withholding_tax_amount_egp=wht,
            net_payable_egp=net,
            source_module="Inland Transport TR-01",
            notes=f"نولون نقل الشحنة إلى المستودع {imp.inland_truck_plate_no or ''}",
        ))

    # 7. Demurrage & Detention Penalties (TR-02 & TR-05)
    trackings = db.query(DemurrageTracking).filter(
        DemurrageTracking.import_file_id == import_file_id,
        DemurrageTracking.is_active == True
    ).all()
    for d in trackings:
        cost = float(d.total_cost_egp or 0.0)
        tot_fx = float(d.total_demurrage_fx or 0.0) + float(d.total_detention_fx or 0.0)
        if cost > 0 or tot_fx > 0:
            d_ccy = (d.currency or "USD").upper()
            if d.exchange_rate:
                d_rate = float(d.exchange_rate)
            elif d_ccy == "EGP":
                d_rate = 1.0
            elif cost <= 0:
                d_rate = fx.rate(d_ccy, _as_date(d.discharge_date))
            else:
                d_rate = 0.0  # display only: the stored EGP cost is used, no rate needed
            amt_egp = round(cost if cost > 0 else (tot_fx * d_rate + float(d.total_storage_egp or 0.0)), 2)
            is_p = bool(d.is_pushed_to_settlement or d.status in ("Closed", "Settled"))
            invoices.append(AggregatedInvoiceItemSchema(
                invoice_id=f"DND-{d.tracking_id}",
                invoice_no=f"DND-{d.tracking_code}",
                invoice_date=str(d.empty_return_date or d.discharge_date or d.created_at.date()),
                party_type="DEMURRAGE",
                party_type_ar="غرامات وأرضيات الحاويات",
                party_name=d.carrier_name or "الخط الملاحي",
                category="Demurrage & Detention",
                category_ar="غرامات تأخير الحاويات ورسوم الأرضيات",
                currency=d.currency or "USD",
                exchange_rate=d_rate,
                amount_fc=tot_fx,
                amount_egp=amt_egp,
                paid_amount_egp=amt_egp if is_p else 0.0,
                remaining_amount_egp=0.0 if is_p else amt_egp,
                payment_status="PAID" if is_p else "UNPAID",
                payment_reference=d.bill_of_lading_no or d.tracking_code,
                withholding_tax_rate=0.0,
                withholding_tax_amount_egp=0.0,
                net_payable_egp=amt_egp,
                source_module="Demurrage TR-02/TR-05",
                notes=f"غرامات تأخير الحاويات بوليصة {d.bill_of_lading_no}",
            ))

    # Summarize by party
    parties_map: Dict[str, Dict[str, Any]] = {}
    for inv in invoices:
        pkey = f"{inv.party_type}::{inv.party_name}"
        if pkey not in parties_map:
            parties_map[pkey] = {
                "party_type": inv.party_type,
                "party_type_ar": inv.party_type_ar,
                "party_name": inv.party_name,
                "invoices_count": 0,
                "total_egp": 0.0,
                "paid_egp": 0.0,
                "remaining_egp": 0.0,
            }
        parties_map[pkey]["invoices_count"] += 1
        parties_map[pkey]["total_egp"] = round(parties_map[pkey]["total_egp"] + inv.amount_egp, 2)
        parties_map[pkey]["paid_egp"] = round(parties_map[pkey]["paid_egp"] + inv.paid_amount_egp, 2)
        parties_map[pkey]["remaining_egp"] = round(parties_map[pkey]["remaining_egp"] + inv.remaining_amount_egp, 2)

    parties_summary = [InvoicesPartySummary(**pdata) for pdata in parties_map.values()]

    total_amt = round(sum(inv.amount_egp for inv in invoices), 2)
    total_paid = round(sum(inv.paid_amount_egp for inv in invoices), 2)
    total_rem = round(sum(inv.remaining_amount_egp for inv in invoices), 2)
    total_wht = round(sum(inv.withholding_tax_amount_egp for inv in invoices), 2)
    readiness = round((total_paid / total_amt * 100.0), 1) if total_amt > 0 else 100.0

    warnings: List[str] = list(wht_warnings)
    for inv in invoices:
        if inv.remaining_amount_egp > 0:
            warnings.append(
                f"مستحق غير مسدد لصالح [{inv.party_name}]: {inv.remaining_amount_egp:,.2f} جنيه (فاتورة {inv.invoice_no})"
            )
            messages.append(_message(SETTLEMENT_UNPAID_INVOICE, party_name=inv.party_name,
                                     amount=round(inv.remaining_amount_egp, 2), invoice_no=inv.invoice_no))

    # The reported rate: the goods invoice rate, else the file currency rate today (display only, 0 when missing).
    if goods_rate is not None:
        reported_rate = goods_rate
    elif currency.upper() == "EGP":
        reported_rate = 1.0
    else:
        reported_rate = fx.rate_or_none(currency) or 0.0

    return InvoicesAggregationResponse(
        import_file_id=imp.import_file_id,
        import_file_code=imp.import_file_code or f"IMP-{imp.import_file_id}",
        supplier_name=imp.supplier_name or "المورد الأجنبي",
        currency=currency,
        exchange_rate=round(reported_rate, 4),
        total_invoices_count=len(invoices),
        total_amount_egp=total_amt,
        total_paid_egp=total_paid,
        total_remaining_egp=total_rem,
        total_withholding_tax_egp=total_wht,
        settlement_readiness_percent=readiness,
        financial_settlement_status=imp.financial_settlement_status or "PENDING_SETTLEMENT",
        parties_summary=parties_summary,
        invoices=invoices,
        unsettled_warnings=warnings,
        messages=messages,
    )


def confirm_invoices_settlement_service(
    db: Session,
    payload: ConfirmInvoicesSettlementRequest,
    actor: str = "System",
) -> ConfirmInvoicesSettlementResponse:
    """
    CLO-01: Confirms and locks the aggregated invoices for the Import File (once: a second call is a 409).
    - The server re-aggregates the invoices: ``invoices_overrides`` and ``settled_by`` are ignored (Q9, FS-04).
    - Updates ImportFile status, progress to >= 98.5%, and financial settlement summary.
    - Closes SmartTask TSK-0901 (by task code only: never by title, never other STEP_19 tasks).
    - Creates and dispatches downstream SmartTask TSK-0902 for Landed Cost Engine allocation (CLO-02).
    - Emits a central high-priority SystemNotification.
    """
    from modules.smart_tasks.model import SmartTask
    from modules.notifications.model import SystemNotification

    imp = require_active(db, ImportFile, payload.import_file_id, IMPORT_FILE_LABEL_AR, status_code=404)
    ensure_invoices_not_settled(imp)

    agg = aggregate_shipment_invoices_service(db, payload.import_file_id)
    invoices = agg.invoices

    total_settled_egp = round(sum(inv.amount_egp for inv in invoices), 2)
    today_date = datetime.now(timezone.utc).date()
    today_str = str(today_date)

    # 1. Update ImportFile
    imp.financial_settlement_status = "INVOICES_SETTLED"
    imp.financial_settlement_date = today_date
    imp.financial_settlement_invoices_count = len(invoices)
    imp.financial_settlement_total_egp = total_settled_egp
    current_progress = float(imp.progress_percent or 0.0)
    imp.progress_percent = max(current_progress, 98.5)
    imp.current_stage = "Stage 9: Landed Cost & File Closure"
    imp.current_module = "CLO-01 Final Settlement Invoices Aggregation"
    set_file_tracking(imp, next_action=msg("NA_CLO_CALCULATE_LANDED_COST"))

    # 2. Resolve SmartTask TSK-0901
    tasks_901 = db.query(SmartTask).filter(
        SmartTask.import_file_id == imp.import_file_id,
        SmartTask.status != "Completed",
        SmartTask.task_code.ilike("TSK-0901%"),
    ).all()
    for t in tasks_901:
        t.status = "Completed"
        t.is_auto_closed = True
        t.notes = f"Invoices settlement and reconciliation approved by {actor} on {today_str}"

    # 3. Create downstream SmartTask TSK-0902
    task_code_902 = f"TSK-0902-{imp.import_file_id}"
    existing_902 = db.query(SmartTask).filter(SmartTask.task_code == task_code_902).first()
    if not existing_902:
        task_msg = msg(
            "FS_TASK_CALCULATE_LANDED_COST",
            import_file_code=imp.import_file_code,
            invoice_count=len(invoices),
            total_amount=round(float(total_settled_egp or 0.0), 2),
        )
        new_task = SmartTask(
            task_code=task_code_902,
            title=render_en(task_msg.code, task_msg.params, "title"),
            description=render_en(task_msg.code, task_msg.params, "body"),
            msg_code=task_msg.code,
            msg_params=task_msg.params,
            step_code="STEP_20",
            task_type="System Generated",
            import_file_id=imp.import_file_id,
            import_file_code=imp.import_file_code,
            phase_name="Stage 9: Landed Cost & File Closure",
            assigned_user=actor,
            priority="High",
            reminder_type="Financial Settlement",
            due_date=today_str,
            status="Pending",
        )
        db.add(new_task)

    # 4. Dispatch central SystemNotification
    notif_msg = msg(
        "FS_INVOICES_SETTLED",
        import_file_code=imp.import_file_code,
        settled_by=actor,
        invoice_count=len(invoices),
        total_amount=round(float(total_settled_egp or 0.0), 2),
    )
    notif = SystemNotification(
        title=render_en(notif_msg.code, notif_msg.params, "title"),
        message=render_en(notif_msg.code, notif_msg.params, "body"),
        msg_code=notif_msg.code,
        msg_params=notif_msg.params,
        severity="INFO",
        category="FINANCIAL_SETTLEMENT",
        entity_type="ImportFile",
        entity_id=imp.import_file_id,
        target_role="ALL",
    )
    db.add(notif)

    db.commit()
    db.refresh(imp)

    return ConfirmInvoicesSettlementResponse(
        success=True,
        import_file_id=imp.import_file_id,
        import_file_code=imp.import_file_code or f"IMP-{imp.import_file_id}",
        financial_settlement_status=imp.financial_settlement_status,
        financial_settlement_date=today_str,
        invoices_count=len(invoices),
        total_settled_egp=total_settled_egp,
        progress_percent=imp.progress_percent,
        current_stage=imp.current_stage,
        current_module=imp.current_module,
        next_task_code=task_code_902,
        next_task_title=render_en("FS_TASK_CALCULATE_LANDED_COST", {}, "title"),
        message=f"تم اعتماد تسوية فواتير الشحنة {imp.import_file_code} بنجاح بإجمالي {total_settled_egp:,.2f} جنيه مصري وإطلاق المهمة الذكية التالية.",
    )


# ==============================================================================
# CLO-02: Actual Landed Cost Calculation & Variance Services
# ==============================================================================

ACTUAL_BUCKETS = (
    "Freight", "Insurance", "Customs Duty", "VAT & Taxes", "Clearance & Port", "Inland Transport",
    "Demurrage & Storage", "Other & Admin",
)

# Engine category stored for an aggregated invoice of each actual bucket (FS-01), so a later engine run puts the
# amount in the matching item bucket (Insurance / Demurrage / Other go to allocated_other_egp).
BUCKET_ENGINE_CATEGORY = {
    "Freight": "Freight",
    "Insurance": "Insurance",
    "Customs Duty": "Customs Duty",
    "VAT & Taxes": "VAT",
    "Clearance & Port": "Clearance",
    "Inland Transport": "Inland Transport",
    "Demurrage & Storage": "Demurrage",
    "Other & Admin": "Other",
}


def _is_goods_invoice(inv: AggregatedInvoiceItemSchema) -> bool:
    cat = inv.category.lower()
    return "goods" in cat or "fob" in cat or "commercial" in cat


def calculate_actual_landed_cost_service(
    db: Session,
    import_file_id: int,
    request: Optional[ActualLandedCostCalculationRequest] = None,
) -> ActualLandedCostCalculationResponse:
    """
    CLO-02: Actual Landed Cost Calculation & Variance Engine.
    Allocates actual settled expenses from all modules across item lines,
    compares actual landed cost per item and category against estimated simulation (PL-08),
    and computes absolute (EGP) and percentage variance and markup factor.
    """
    response, _ = _calculate_actual_landed_cost(db, import_file_id, request)
    return response


def _calculate_actual_landed_cost(
    db: Session,
    import_file_id: int,
    request: Optional[ActualLandedCostCalculationRequest] = None,
) -> Tuple[ActualLandedCostCalculationResponse, List[AggregatedInvoiceItemSchema]]:
    """The CLO-02 calculation plus the aggregated expense invoices it allocated (approve stores them)."""
    imp = require_active(db, ImportFile, import_file_id, IMPORT_FILE_LABEL_AR, status_code=404)

    req = request or ActualLandedCostCalculationRequest()
    pref = req.allocation_preference or "Value-Based"
    fx = SettlementFx(db, "commercial")
    messages: List[SettlementMessage] = []

    # 1. Fetch simulation estimates (PL-08) for baseline comparison. A domain failure (e.g. missing customs rate)
    # leaves the estimate out with a message; anything else propagates (FS-13).
    try:
        sim = simulate_estimated_landed_cost_service(db, import_file_id)
    except HTTPException as exc:
        logger.warning("Estimated landed cost unavailable for import file %s: %s", import_file_id, exc.detail)
        reason = exc.detail.get("code") if isinstance(exc.detail, dict) else None
        messages.append(_message(ESTIMATE_UNAVAILABLE, reason=reason or f"HTTP_{exc.status_code}"))
        sim = None

    # 2. Fetch all aggregated actual invoices
    agg = aggregate_shipment_invoices_service(db, import_file_id)
    messages.extend(agg.messages)
    all_invoices = agg.invoices
    currency = agg.currency or "USD"
    exchange_rate = agg.exchange_rate

    # Separate FOB Goods from other Expenses
    goods_invoices = [inv for inv in all_invoices if _is_goods_invoice(inv)]
    expense_invoices = [inv for inv in all_invoices if inv not in goods_invoices]

    # Calculate actual FOB from goods invoices, or fallback to simulation / estimated_cost
    if goods_invoices:
        actual_total_fob_egp = sum(inv.amount_egp for inv in goods_invoices)
    elif sim and sim.total_fob_egp > 0:
        actual_total_fob_egp = sim.total_fob_egp
    elif (imp.estimated_cost or 0) > 0:
        actual_total_fob_egp = float(imp.estimated_cost) * fx.rate(currency, _as_date(imp.file_opening_date))
    else:
        actual_total_fob_egp = 0.0

    # Category buckets for actual expenses
    cat_expenses = {
        "Freight": {"ar": "النولون والشحن الدولي", "actual": 0.0, "count": 0},
        "Insurance": {"ar": "التأمين البحري", "actual": 0.0, "count": 0},
        "Customs Duty": {"ar": "ضريبة الوارد الجمركية", "actual": 0.0, "count": 0},
        "VAT & Taxes": {"ar": "ضريبة القيمة المضافة وضريبة الجدول", "actual": 0.0, "count": 0},
        "Clearance & Port": {"ar": "أتعاب التخليص ومصاريف الميناء والـ D/O", "actual": 0.0, "count": 0},
        "Inland Transport": {"ar": "النقل الداخلي والتعتيق", "actual": 0.0, "count": 0},
        "Demurrage & Storage": {"ar": "غرامات التأخير والأرضيات", "actual": 0.0, "count": 0},
        "Other & Admin": {"ar": "مصاريف إدارية وبنكية متنوعة", "actual": 0.0, "count": 0},
    }

    for inv in expense_invoices:
        bucket = actual_expense_bucket(inv.category, inv.party_type)
        cat_expenses[bucket]["actual"] += float(inv.amount_egp or 0.0)
        cat_expenses[bucket]["count"] += 1

    actual_total_expenses_egp = sum(c["actual"] for c in cat_expenses.values())
    actual_total_landed_cost_egp = actual_total_fob_egp + actual_total_expenses_egp
    actual_markup_factor = (actual_total_landed_cost_egp / actual_total_fob_egp) if actual_total_fob_egp > 0 else 1.0

    # Estimated numbers from simulation (duty / VAT split = the simulation's own totals, FS-07)
    est_total_fob = sim.total_fob_egp if sim else actual_total_fob_egp
    est_freight = sim.total_freight_egp if sim else 0.0
    est_ins = sim.total_insurance_egp if sim else 0.0
    est_taxes = sim.total_customs_and_taxes_egp if sim else 0.0
    est_duty = sim.total_customs_duty_egp if sim else 0.0
    est_vat = sim.total_vat_and_fees_egp if sim else 0.0
    est_clearance = sim.total_clearance_and_port_egp if sim else 0.0
    est_transport = sim.total_inland_transport_egp if sim else 0.0
    est_demurrage = 0.0 # usually 0 planned
    est_other = sim.total_other_expenses_egp if sim else 0.0

    est_total_expenses = sim.total_expenses_egp if sim else (est_freight + est_ins + est_taxes + est_clearance + est_transport + est_other)
    est_total_landed = sim.total_landed_cost_egp if sim else (est_total_fob + est_total_expenses)
    est_markup = sim.average_markup_factor if sim else 1.0

    cat_est_map = {
        "Freight": est_freight,
        "Insurance": est_ins,
        "Customs Duty": est_duty,
        "VAT & Taxes": est_vat,
        "Clearance & Port": est_clearance,
        "Inland Transport": est_transport,
        "Demurrage & Storage": est_demurrage,
        "Other & Admin": est_other,
    }

    # 3. Extract items to allocate across: Prefer POLineItem directly if available (ACC2-T01)
    items_raw = []
    line_shares = file_po_line_shares(db, imp, messages=messages)

    sim_map = {}
    if sim and sim.items_breakdown:
        sim_map = {s.item_code: s for s in sim.items_breakdown}

    if line_shares:
        po_rates: Dict[int, float] = {}
        for idx, (pl, share_qty, ratio) in enumerate(line_shares):
            if share_qty <= 0.0:
                continue
            if pl.po_id not in po_rates:
                po_rates[pl.po_id] = purchase_order_rate_to_egp(pl.purchase_order, fx)
            qty = share_qty
            u_p = float(pl.unit_price or 0.0)
            fob_tot_egp = round(u_p * qty * po_rates[pl.po_id], 2)  # unit_price x qty_share x rate (ACC2-T01)
            fob_u_egp = fob_tot_egp / qty if qty > 0 else 0.0

            s_match = sim_map.get(pl.item_code)
            est_u = float(s_match.unit_landed_cost_egp) if s_match else (fob_u_egp * est_markup)

            items_raw.append({
                "line_no": idx + 1,
                "item_code": pl.item_code or f"ITM-{idx+1:03d}",
                "item_name": pl.description_ar or pl.description_en or f"Item #{idx+1}",
                "hs_code": (pl.tariff.hs_code if pl.tariff else "") or imp.hs_code or "",
                "qty": qty,
                "fob_unit_egp": fob_u_egp,
                "fob_total_egp": fob_tot_egp,
                "gross_weight_kg": round(float(pl.gross_weight_kg or 0.0) * ratio, 4),
                "cbm": round(float(pl.total_cbm or 0.0) * ratio, 4),
                "estimated_unit_landed_cost_egp": est_u,
            })
    elif sim and sim.items_breakdown and len(sim.items_breakdown) > 0:
        for s_itm in sim.items_breakdown:
            items_raw.append({
                "line_no": s_itm.line_no,
                "item_code": s_itm.item_code,
                "item_name": s_itm.item_name,
                "hs_code": s_itm.hs_code,
                "qty": float(s_itm.qty or 1.0),
                "fob_unit_egp": float(s_itm.fob_unit_egp or 0.0),
                "fob_total_egp": float(s_itm.fob_total_egp or 0.0),
                "gross_weight_kg": 0.0,
                "cbm": 0.0,
                "estimated_unit_landed_cost_egp": float(s_itm.unit_landed_cost_egp or 0.0),
            })
    else:
        # Fallback to single general cargo item
        items_raw.append({
            "line_no": 1,
            "item_code": "ITM-001",
            "item_name": imp.product_category or "General Imported Cargo",
            "hs_code": imp.hs_code or "",
            "qty": 1.0,
            "fob_unit_egp": actual_total_fob_egp,
            "fob_total_egp": actual_total_fob_egp,
            "gross_weight_kg": 0.0,
            "cbm": 0.0,
            "estimated_unit_landed_cost_egp": est_total_landed,
        })

    total_items_fob = sum(i["fob_total_egp"] for i in items_raw)
    total_items_wt = sum(i["gross_weight_kg"] for i in items_raw)
    total_items_cbm = sum(i["cbm"] for i in items_raw)
    n_items = len(items_raw)

    # Rule actually applied per bucket (FS-09: reported as used; custom_category_allocation does not drive it, Q7)
    if pref == "Weight-Based" and total_items_wt > 0:
        pri_rule = "Weight-Based"
    elif pref == "Volume-Based" and total_items_cbm > 0:
        pri_rule = "Volume-Based"
    elif pref == "Equal":
        pri_rule = "Equal"
    else:
        pri_rule = "Value-Based"
    rules_used = {
        "Freight": "Volume-Based" if total_items_cbm > 0 else pri_rule,
        "Insurance": "Value-Based",
        "Customs Duty": "Value-Based",
        "VAT & Taxes": "Value-Based",
        "Clearance & Port": pri_rule,
        "Inland Transport": "Weight-Based" if total_items_wt > 0 else pri_rule,
        "Demurrage & Storage": pri_rule,
        "Other & Admin": "Value-Based",
    }

    # Build Categories Breakdown
    categories_breakdown: List[ActualLandedCostCategoryBreakdown] = []
    for c_key, c_data in cat_expenses.items():
        est_val = cat_est_map.get(c_key, 0.0)
        act_val = c_data["actual"]
        v_egp = round(act_val - est_val, 2)
        v_pct = round((v_egp / est_val * 100.0), 2) if est_val > 0 else (100.0 if act_val > 0 else 0.0)

        categories_breakdown.append(ActualLandedCostCategoryBreakdown(
            category=c_key,
            category_ar=c_data["ar"],
            estimated_egp=round(est_val, 2),
            actual_egp=round(act_val, 2),
            variance_egp=v_egp,
            variance_pct=v_pct,
            invoices_count=c_data["count"],
            allocation_rule=rules_used[c_key],
        ))

    items_breakdown: List[ActualLandedCostItemLine] = []

    act_freight = cat_expenses["Freight"]["actual"]
    act_ins = cat_expenses["Insurance"]["actual"]
    act_duty = cat_expenses["Customs Duty"]["actual"]
    act_vat = cat_expenses["VAT & Taxes"]["actual"]
    act_clearance = cat_expenses["Clearance & Port"]["actual"]
    act_transport = cat_expenses["Inland Transport"]["actual"]
    act_demurrage = cat_expenses["Demurrage & Storage"]["actual"]
    act_other = cat_expenses["Other & Admin"]["actual"]

    for itm in items_raw:
        qty = _unit_qty(itm["qty"])
        fob_tot = itm["fob_total_egp"]
        fob_u = itm["fob_unit_egp"]

        v_ratio = (fob_tot / total_items_fob) if total_items_fob > 0 else (1.0 / n_items)
        w_ratio = (itm["gross_weight_kg"] / total_items_wt) if total_items_wt > 0 else v_ratio
        c_ratio = (itm["cbm"] / total_items_cbm) if total_items_cbm > 0 else v_ratio
        eq_ratio = 1.0 / n_items

        if pref == "Weight-Based" and total_items_wt > 0:
            pri_ratio = w_ratio
        elif pref == "Volume-Based" and total_items_cbm > 0:
            pri_ratio = c_ratio
        elif pref == "Equal":
            pri_ratio = eq_ratio
        else:
            pri_ratio = v_ratio

        # Allocation per bucket
        all_freight = act_freight * (c_ratio if total_items_cbm > 0 else pri_ratio)
        all_ins = act_ins * v_ratio
        all_duty = act_duty * v_ratio
        all_vat = act_vat * v_ratio
        all_clearance = act_clearance * pri_ratio
        all_transport = act_transport * (w_ratio if total_items_wt > 0 else pri_ratio)
        all_demurrage = act_demurrage * pri_ratio
        all_other = act_other * v_ratio

        tot_alloc = all_freight + all_ins + all_duty + all_vat + all_clearance + all_transport + all_demurrage + all_other
        item_landed_tot = fob_tot + tot_alloc
        item_landed_u = item_landed_tot / qty
        item_mkp = (item_landed_u / fob_u) if fob_u > 0 else 1.0
        item_mkp_pct = (item_mkp - 1.0) * 100.0

        est_u = itm.get("estimated_unit_landed_cost_egp") or fob_u
        u_var = item_landed_u - est_u
        u_var_pct = (u_var / est_u * 100.0) if est_u > 0 else 0.0

        if u_var < -0.05:
            v_status = "SAVING"
        elif u_var > 0.05:
            v_status = "INCREASED"
        else:
            v_status = "MATCHED"

        items_breakdown.append(ActualLandedCostItemLine(
            line_no=itm["line_no"],
            item_code=itm["item_code"],
            item_name=itm["item_name"],
            hs_code=itm["hs_code"],
            qty=qty,
            gross_weight_kg=round(itm["gross_weight_kg"], 2),
            cbm=round(itm["cbm"], 2),
            fob_unit_egp=round(fob_u, 2),
            fob_total_egp=round(fob_tot, 2),
            allocated_freight_egp=round(all_freight, 2),
            allocated_insurance_egp=round(all_ins, 2),
            allocated_customs_duty_egp=round(all_duty, 2),
            allocated_vat_egp=round(all_vat, 2),
            allocated_clearance_egp=round(all_clearance, 2),
            allocated_inland_transport_egp=round(all_transport, 2),
            allocated_demurrage_egp=round(all_demurrage, 2),
            allocated_other_egp=round(all_other, 2),
            total_allocated_expenses_egp=round(tot_alloc, 2),
            actual_total_landed_cost_egp=round(item_landed_tot, 2),
            actual_unit_landed_cost_egp=round(item_landed_u, 2),
            actual_markup_factor=round(item_mkp, 4),
            actual_markup_pct=round(item_mkp_pct, 2),
            estimated_unit_landed_cost_egp=round(est_u, 2),
            unit_cost_variance_egp=round(u_var, 2),
            unit_cost_variance_pct=round(u_var_pct, 2),
            item_variance_status=v_status,
        ))

    # Overall file variances
    fob_var_egp = round(actual_total_fob_egp - est_total_fob, 2)
    fob_var_pct = round((fob_var_egp / est_total_fob * 100.0), 2) if est_total_fob > 0 else 0.0

    exp_var_egp = round(actual_total_expenses_egp - est_total_expenses, 2)
    exp_var_pct = round((exp_var_egp / est_total_expenses * 100.0), 2) if est_total_expenses > 0 else 0.0

    landed_var_egp = round(actual_total_landed_cost_egp - est_total_landed, 2)
    landed_var_pct = round((landed_var_egp / est_total_landed * 100.0), 2) if est_total_landed > 0 else 0.0

    if landed_var_egp < -100.0:
        overall_status = "UNDER_BUDGET"
        overall_status_ar = f"وفورات في التكلفة بنسبة {abs(landed_var_pct):.1f}% (تحت الميزانية التقديرية)"
    elif landed_var_egp > 100.0:
        overall_status = "OVER_BUDGET"
        overall_status_ar = f"تجاوز وحيود في التكلفة بنسبة {landed_var_pct:.1f}% (فوق الميزانية التقديرية)"
    else:
        overall_status = "ON_BUDGET"
        overall_status_ar = "مطابق للميزانية التقديرية بدقة عالية"

    # Executive Summary in Arabic (deprecated)
    exec_summary = (
        f"بلغت التكلفة الإجمالية الفعلية الواصلة للشحنة {imp.import_file_code} ما قيمته "
        f"{actual_total_landed_cost_egp:,.2f} جنيه مصري، مقارنة بالتكلفة التقديرية البالغة "
        f"{est_total_landed:,.2f} جنيه مصري، بفارق انحراف قدره {landed_var_egp:+,.2f} جنيه "
        f"({landed_var_pct:+.1f}% — {overall_status_ar}). "
        f"بلغت قيمة البضاعة الفعلية {actual_total_fob_egp:,.2f} جنيه، ومجموع المصاريف الفعلية "
        f"{actual_total_expenses_egp:,.2f} جنيه موزعة عبر {len(expense_invoices)} فاتورة ومطالبة. "
        f"متوسط معامل الزيادة الفعلي (Landed Markup Factor) يبلغ {actual_markup_factor:.3f}x، "
        f"وتم توزيع المصاريف بنجاح على عدد {len(items_breakdown)} صنف طبقا لقاعدة '{pref}'."
    )

    # Header vs items reconciliation (FS-08, Q6): reported, never redistributed.
    reconciliation_difference = round(
        round(actual_total_landed_cost_egp, 2) - sum(i.actual_total_landed_cost_egp for i in items_breakdown), 2
    )

    response = ActualLandedCostCalculationResponse(
        import_file_id=imp.import_file_id,
        import_file_code=imp.import_file_code or f"IMP-{imp.import_file_id}",
        supplier_name=imp.supplier_name or "المورد الأجنبي",
        currency=currency,
        exchange_rate=round(exchange_rate, 4),
        incoterm=imp.incoterm_code or "FOB",
        allocation_preference=pref,
        total_items_count=len(items_breakdown),
        total_invoices_count=len(all_invoices),
        estimated_total_fob_egp=round(est_total_fob, 2),
        actual_total_fob_egp=round(actual_total_fob_egp, 2),
        fob_variance_egp=fob_var_egp,
        fob_variance_pct=fob_var_pct,
        estimated_total_expenses_egp=round(est_total_expenses, 2),
        actual_total_expenses_egp=round(actual_total_expenses_egp, 2),
        expenses_variance_egp=exp_var_egp,
        expenses_variance_pct=exp_var_pct,
        estimated_total_landed_cost_egp=round(est_total_landed, 2),
        actual_total_landed_cost_egp=round(actual_total_landed_cost_egp, 2),
        landed_variance_egp=landed_var_egp,
        landed_variance_pct=landed_var_pct,
        estimated_markup_factor=round(est_markup, 4),
        actual_markup_factor=round(actual_markup_factor, 4),
        variance_status=overall_status,
        variance_status_ar=overall_status_ar,
        categories_breakdown=categories_breakdown,
        items_breakdown=items_breakdown,
        executive_summary_ar=exec_summary,
        reconciliation_difference_egp=reconciliation_difference,
        messages=messages,
    )
    return response, expense_invoices


def settlement_expense_row(inv: AggregatedInvoiceItemSchema, allocation_rule: str) -> Dict[str, Any]:
    """An aggregated expense invoice stored on the settlement in the ``ExpenseInvoiceSchema`` shape (FS-01),
    plus the additive ``bucket`` (actual landed-cost bucket) and its source fields."""
    bucket = actual_expense_bucket(inv.category, inv.party_type)
    return {
        "invoice_no": inv.invoice_no,
        "category": BUCKET_ENGINE_CATEGORY[bucket],
        "provider_name": inv.party_name,
        "currency": inv.currency or "EGP",
        "amount_fx": float(inv.amount_fc or 0.0),
        "exchange_rate": float(inv.exchange_rate or 1.0),
        "amount_egp": round(float(inv.amount_egp or 0.0), 2),
        "allocation_rule": allocation_rule,
        "bucket": bucket,
        "source_category": inv.category,
        "category_code": inv.category_code,
        "party_type": inv.party_type,
        "invoice_date": inv.invoice_date,
        "source_module": inv.source_module,
    }


def settlement_item_row(line: ActualLandedCostItemLine) -> Dict[str, Any]:
    """An actual item line stored in the canonical ``ItemLandedCostSchema`` keys (FS-01): customs = duty + VAT,
    other = insurance + demurrage + other. The actual line keys stay additively (canonical keys win)."""
    canonical = {
        "item_code": line.item_code,
        "item_name": line.item_name,
        "qty": line.qty,
        "gross_weight_kg": line.gross_weight_kg,
        "cbm": line.cbm,
        "fob_unit_egp": line.fob_unit_egp,
        "fob_total_egp": line.fob_total_egp,
        "allocated_freight_egp": line.allocated_freight_egp,
        "allocated_customs_egp": round(line.allocated_customs_duty_egp + line.allocated_vat_egp, 2),
        "allocated_clearance_egp": line.allocated_clearance_egp,
        "allocated_transport_egp": line.allocated_inland_transport_egp,
        "allocated_other_egp": round(
            line.allocated_insurance_egp + line.allocated_demurrage_egp + line.allocated_other_egp, 2
        ),
        "total_landed_cost_egp": line.actual_total_landed_cost_egp,
        "unit_landed_cost_egp": line.actual_unit_landed_cost_egp,
        "markup_factor": line.actual_markup_factor,
    }
    return {**line.model_dump(), **canonical}


def approve_actual_landed_cost_service(
    db: Session,
    payload: ApproveActualLandedCostRequest,
    actor: str = "System",
) -> ApproveActualLandedCostResponse:
    """
    CLO-02: Approves and finalizes the Actual Landed Cost calculation for the Import File.
    - Stores the allocated invoices and item lines on LandedCostSettlementRecord in the canonical settlement
      shapes (FS-01) and freezes it (status Approved).
    - Updates ImportFile status to 'COST_ALLOCATED', sets actual landed cost KPIs, and advances progress >= 99.0%.
    - Resolves SmartTask TSK-0902.
    - Dispatches downstream SmartTask TSK-0903 for Final Dossier Export (CLO-03).
    - Emits central SystemNotification. ``approved_by`` is ignored: the acting user is recorded.
    """
    from modules.smart_tasks.model import SmartTask
    from modules.notifications.model import SystemNotification

    imp = require_active(db, ImportFile, payload.import_file_id, IMPORT_FILE_LABEL_AR, status_code=404)
    ensure_cost_not_approved(imp, get_settlement_by_import_file_id(db, imp.import_file_id))

    # Run calculation
    calc_req = ActualLandedCostCalculationRequest(
        allocation_preference=payload.allocation_preference,
        custom_category_allocation=payload.custom_category_allocation,
    )
    calc, expense_invoices = _calculate_actual_landed_cost(db, payload.import_file_id, calc_req)

    now_utc = datetime.now(timezone.utc)
    today_str = str(now_utc.date())

    # 1. Update or create LandedCostSettlementRecord
    settlement = get_settlement_by_import_file_id(db, imp.import_file_id)

    rules_used = {c.category: c.allocation_rule for c in calc.categories_breakdown}
    items_json = [settlement_item_row(itm) for itm in calc.items_breakdown]
    expenses_json = [
        settlement_expense_row(inv, rules_used.get(actual_expense_bucket(inv.category, inv.party_type), "Value-Based"))
        for inv in expense_invoices
    ]

    if not settlement:
        settlement = LandedCostSettlementRecord(
            import_file_id=imp.import_file_id,
            incoterm_code=calc.incoterm,
            expense_invoices=expenses_json,
            total_fob_egp=calc.actual_total_fob_egp,
            total_expenses_egp=calc.actual_total_expenses_egp,
            total_landed_cost_egp=calc.actual_total_landed_cost_egp,
            average_markup_factor=calc.actual_markup_factor,
            item_landed_costs=items_json,
            status="Approved",
            accountant_name=actor,
            notes=payload.notes,
            created_by=actor,
            updated_by=actor,
            created_at=now_utc,
            updated_at=now_utc,
        )
        add_with_new_code(db, settlement)
    else:
        settlement.incoterm_code = calc.incoterm
        settlement.expense_invoices = expenses_json
        settlement.total_fob_egp = calc.actual_total_fob_egp
        settlement.total_expenses_egp = calc.actual_total_expenses_egp
        settlement.total_landed_cost_egp = calc.actual_total_landed_cost_egp
        settlement.average_markup_factor = calc.actual_markup_factor
        settlement.item_landed_costs = items_json
        settlement.status = "Approved"
        settlement.accountant_name = actor
        if payload.notes:
            settlement.notes = f"{settlement.notes or ''}\n{payload.notes}".strip()
        settlement.updated_at = now_utc
        settlement.updated_by = actor

    # 2. Update ImportFile
    imp.financial_settlement_status = "COST_ALLOCATED"
    imp.actual_landed_cost_total_egp = calc.actual_total_landed_cost_egp
    imp.actual_landed_cost_markup_factor = calc.actual_markup_factor
    imp.actual_landed_cost_variance_egp = calc.landed_variance_egp
    imp.actual_landed_cost_variance_pct = calc.landed_variance_pct
    imp.actual_landed_cost_calculated_at = now_utc
    current_progress = float(imp.progress_percent or 0.0)
    imp.progress_percent = max(current_progress, 99.0)
    imp.current_stage = "Stage 9: Landed Cost & File Closure"
    imp.current_module = "CLO-02 Actual Landed Cost Calculation"
    set_file_tracking(imp, next_action=msg("NA_CLO_EXPORT_DOSSIER"))

    # 3. Resolve SmartTask TSK-0902
    tasks_902 = db.query(SmartTask).filter(
        SmartTask.import_file_id == imp.import_file_id,
        (SmartTask.task_code.ilike("%0902%") | SmartTask.title.ilike("%تكلفة الوصول الفعلية%") | SmartTask.title.ilike("%CLO-02%"))
    ).all()
    for t in tasks_902:
        t.status = "Completed"
        t.is_auto_closed = True
        t.notes = f"Actual landed cost calculated and approved by {actor} on {today_str}"

    # 4. Dispatch downstream SmartTask TSK-0903
    task_code_903 = f"TSK-0903-{imp.import_file_id}"
    existing_903 = db.query(SmartTask).filter(SmartTask.task_code == task_code_903).first()
    if not existing_903:
        task_msg = msg(
            "FS_TASK_EXPORT_DOSSIER",
            import_file_code=imp.import_file_code,
            total_amount=round(float(calc.actual_total_landed_cost_egp or 0.0), 2),
            variance_pct=round(float(calc.landed_variance_pct or 0.0), 1),
        )
        new_task = SmartTask(
            task_code=task_code_903,
            title=render_en(task_msg.code, task_msg.params, "title"),
            description=render_en(task_msg.code, task_msg.params, "body"),
            msg_code=task_msg.code,
            msg_params=task_msg.params,
            step_code="STEP_21",
            task_type="System Generated",
            import_file_id=imp.import_file_id,
            import_file_code=imp.import_file_code,
            phase_name="Stage 9: Landed Cost & File Closure",
            assigned_user=actor,
            priority="High",
            reminder_type="Comprehensive Report",
            due_date=today_str,
            status="Pending",
        )
        db.add(new_task)

    # 5. Dispatch central SystemNotification
    notif_msg = msg(
        "FS_LANDED_COST_APPROVED",
        import_file_code=imp.import_file_code,
        approved_by=actor,
        total_amount=round(float(calc.actual_total_landed_cost_egp or 0.0), 2),
        markup_factor=round(float(calc.actual_markup_factor or 0.0), 3),
        variance_pct=round(float(calc.landed_variance_pct or 0.0), 1),
        variance_status_enum_landed_cost_variance_status=calc.variance_status,
    )
    notif = SystemNotification(
        title=render_en(notif_msg.code, notif_msg.params, "title"),
        message=render_en(notif_msg.code, notif_msg.params, "body"),
        msg_code=notif_msg.code,
        msg_params=notif_msg.params,
        severity="INFO",
        category="FINANCIAL_SETTLEMENT",
        entity_type="ImportFile",
        entity_id=imp.import_file_id,
        target_role="ALL",
    )
    db.add(notif)

    db.commit()
    settlement_id = settlement.settlement_id
    settlement_code = settlement.settlement_code

    # 6. Advance lifecycle board step: a follow-up that never undoes the approval (FS-13)
    from modules.lifecycle_board.service import advance_lifecycle_step_service
    import_file_id = imp.import_file_id
    best_effort(
        db,
        lambda: advance_lifecycle_step_service(
            db=db,
            import_file_id=import_file_id,
            completed_step_code="STEP_20",
            target_step_codes=["STEP_21"],
            notes_msg=msg("FS_LANDED_COST_APPROVED", settlement_code=settlement_code),
            next_action_msg=msg("NA_CLO_EXPORT_DOSSIER"),
            assigned_user=actor,
        ),
        "Lifecycle advance STEP_20->STEP_21",
    )
    db.refresh(imp)

    return ApproveActualLandedCostResponse(
        success=True,
        import_file_id=imp.import_file_id,
        import_file_code=imp.import_file_code or f"IMP-{imp.import_file_id}",
        settlement_id=settlement_id,
        settlement_code=settlement_code,
        financial_settlement_status=imp.financial_settlement_status,
        actual_landed_cost_total_egp=calc.actual_total_landed_cost_egp,
        actual_landed_cost_markup_factor=calc.actual_markup_factor,
        landed_variance_egp=calc.landed_variance_egp,
        landed_variance_pct=calc.landed_variance_pct,
        variance_status=calc.variance_status,
        progress_percent=imp.progress_percent,
        current_stage=imp.current_stage,
        current_module=imp.current_module,
        next_task_code=task_code_903,
        next_task_title=render_en("FS_TASK_EXPORT_DOSSIER", {}, "title"),
        message=f"تم اعتماد تكلفة الوصول الفعلية للشحنة {imp.import_file_code} بنجاح بإجمالي {calc.actual_total_landed_cost_egp:,.2f} جنيه وإطلاق مهمة الملف الشامل.",
    )
