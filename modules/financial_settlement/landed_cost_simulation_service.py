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



from .landed_cost_engine_service import *

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

    currency: Optional[str] = None
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
        if tot_price > 0 and not po_currency:
            raise currency_missing_error("Purchase Order", getattr(po, "po_number", None) if po else None)

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
        from .fob_valuation_service import net_fob_foreign

        for inv in imp_file.invoices_data:
            # Net goods value only: the supplier financing markup and discount never enter the customs base
            # (single net FOB rule, qJZNzixC).
            inv_amt = net_fob_foreign(
                float(inv.get("amount") or 0.0),
                float(inv.get("discount_amount") or 0.0),
                float(inv.get("financing_markup_amount") or 0.0),
                inv.get("invoice_no") or inv.get("invoice_number"),
            )
            if inv_amt > 0:
                inv_curr = inv.get("currency")
                if not inv_curr or not str(inv_curr).strip():
                    inv_no = inv.get("invoice_no") or inv.get("invoice_number")
                    raise currency_missing_error("Commercial Invoice", inv_no)
                currency = str(inv_curr).strip()
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
        if not imp_file.estimated_cost_currency or not str(imp_file.estimated_cost_currency).strip():
            raise currency_missing_error("Import File Estimated Cost", imp_file.import_file_code)
        currency = str(imp_file.estimated_cost_currency).strip()
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
    elif currency:
        fx_rate = customs_fx.rate(currency, calc_date)
    else:
        fx_rate = 1.0

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
            .filter(
                FreightRFQRequest.import_file_id == import_file_id,
                FreightRFQRequest.is_active == True,
            )
            .order_by(FreightRFQRequest.rfq_id.desc())
            .first()
        )
        winning_q = None
        if awarded_rfq and awarded_rfq.selected_quotation_id:
            winning_q = db.query(FreightQuotationItem).filter(
                FreightQuotationItem.quotation_id == awarded_rfq.selected_quotation_id,
                FreightQuotationItem.rfq_id == awarded_rfq.rfq_id,
            ).first()

        q_cost = float(winning_q.ocean_freight_cost or 0.0) if winning_q else 0.0
        if winning_q and q_cost > 0:
            q_curr = winning_q.currency_code or currency
            if q_curr.upper() == "EGP":
                freight_egp = q_cost
            elif q_curr.upper() == (currency or "").upper():
                freight_egp = q_cost * fx_rate
            else:  # quote in another currency than the goods: its own customs rate (review 2 #1)
                freight_egp = q_cost * SettlementFx(db, "customs").rate(q_curr, calc_date)
            p_name = getattr(winning_q, "provider_name", None) or getattr(winning_q, "carrier_name", "RFQ Winner")
            freight_src = f"نولون الشحن البحري للعرض الفائز في المناقصة ({p_name})"
            has_freight_doc = True
        else:
            freight_egp = total_fob_egp * (deemed_freight_pct / 100.0)
            freight_src = deemed_freight_src

    ship_mode = (getattr(imp_file, "shipment_mode", None) or getattr(imp_file, "shipping_mode", None) or "").lower()
    is_air = "air" in ship_mode or "طيران" in ship_mode or "جوي" in ship_mode
    intended_freight_rule = "Weight-Based" if is_air else "Volume-Based"
    freight_ratios, actual_freight_rule, missing_freight = allocation_ratios(items_raw, intended_freight_rule)
    if missing_freight and freight_egp > 0:
        messages.append(_message(
            ALLOCATION_BASIS_INCOMPLETE,
            bucket="Ocean/Air Freight",
            rule=intended_freight_rule,
            item_codes=", ".join(missing_freight),
        ))

    expenses_breakdown.append(EstimatedLandedCostExpenseItem(
        category="Ocean/Air Freight",
        description="النولون والشحن الدولي التقديري",
        amount_fc=round(freight_egp / fx_rate, 2),
        currency=currency,
        amount_egp=round(freight_egp, 2),
        is_estimated=True,
        source=freight_src,
        allocation_rule=actual_freight_rule,
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
        total_inspection_fees_egp = float(getattr(customs_breakdown, "total_inspection_fees_egp", 0.0) or 0.0)
        total_taxes_and_fees_egp = float(getattr(customs_breakdown, "items_taxes_total_egp", None) or getattr(customs_breakdown, "grand_total_payable_egp", 0.0) or (total_customs_duty_egp + total_vat_egp + total_schedule_tax_egp + total_service_fee_egp + total_inspection_fees_egp))
        customs_line_map = {l.line_no: l for l in customs_breakdown.lines}
    else:
        total_customs_duty_egp = total_vat_egp = total_schedule_tax_egp = total_service_fee_egp = 0.0
        total_inspection_fees_egp = 0.0
        total_taxes_and_fees_egp = 0.0
        customs_line_map = {}

    vat_and_taxes_line_egp = round(total_taxes_and_fees_egp - total_customs_duty_egp, 2)

    expenses_breakdown.append(EstimatedLandedCostExpenseItem(
        category="Customs Duties",
        description="ضريبة الوارد الجمركية (Import Duty)",
        amount_fc=round(total_customs_duty_egp / fx_rate, 2),
        currency=currency,
        amount_egp=round(total_customs_duty_egp, 2),
        is_estimated=True,
        source="محرك التعريفة الجمركية المصري MD-008",
        allocation_rule="Direct HS Code Allocation",
    ))

    expenses_breakdown.append(EstimatedLandedCostExpenseItem(
        category="VAT & Taxes",
        description="ضريبة القيمة المضافة وضريبة الجدول ورسوم الخدمات الجمركية",
        amount_fc=round(vat_and_taxes_line_egp / fx_rate, 2),
        currency=currency,
        amount_egp=vat_and_taxes_line_egp,
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
        currency=currency,
        amount_egp=round(clearance_fee, 2),
        is_estimated=True,
        source="تقدير قياسي / مخلص معتمد" if req.clearance_fees_egp_override is None else "تعديل يدوي",
        allocation_rule="Weight-Based" if any(i["weight_kg"] > 0 for i in items_raw) else "Value-Based",
    ))

    expenses_breakdown.append(EstimatedLandedCostExpenseItem(
        category="Port & Terminal Handling (THC)",
        description="مصاريف الميناء والتفريغ والعتالة والتخزين المؤقت",
        amount_fc=round(port_handling / fx_rate, 2),
        currency=currency,
        amount_egp=round(port_handling, 2),
        is_estimated=True,
        source="تعريفة محطة الحاويات والميناء" if req.port_handling_egp_override is None else "تعديل يدوي",
        allocation_rule="Volume-Based" if any(i["cbm"] > 0 for i in items_raw) else "Weight-Based" if any(i["weight_kg"] > 0 for i in items_raw) else "Value-Based",
    ))

    inland_ratios, actual_inland_rule, missing_inland = allocation_ratios(items_raw, "Weight-Based")
    if missing_inland and inland_trucking > 0:
        messages.append(_message(
            ALLOCATION_BASIS_INCOMPLETE,
            bucket="Inland Transport",
            rule="Weight-Based",
            item_codes=", ".join(missing_inland),
        ))

    expenses_breakdown.append(EstimatedLandedCostExpenseItem(
        category="Inland Transport",
        description="النقل الداخلي بالشاحنات من ميناء الوصول لمخازن الشركة",
        amount_fc=round(inland_trucking / fx_rate, 2),
        currency=currency,
        amount_egp=round(inland_trucking, 2),
        is_estimated=True,
        source="أسعار النقل البري المعتمدة" if req.inland_transport_egp_override is None else "تعديل يدوي",
        allocation_rule=actual_inland_rule,
    ))

    expenses_breakdown.append(EstimatedLandedCostExpenseItem(
        category="Banking & Form 4 Fees",
        description="عمولات التحويلات البنكية ومصاريف استخراج نموذج 4 وفتح الاعتماد",
        amount_fc=round(bank_fees / fx_rate, 2),
        currency=currency,
        amount_egp=round(bank_fees, 2),
        is_estimated=True,
        source="جدول العمولات البنكية الرسمي" if req.bank_fees_egp_override is None else "تعديل يدوي",
        allocation_rule="Value-Based",
    ))

    expenses_breakdown.append(EstimatedLandedCostExpenseItem(
        category="Inspection & Administrative",
        description="فحص الرقابة على الصادرات والواردات، رسوم كارجو إكس، ومصاريف إدارية",
        amount_fc=round(other_fees / fx_rate, 2),
        currency=currency,
        amount_egp=round(other_fees, 2),
        is_estimated=True,
        source="مصاريف إدارية تقديرية" if req.other_expenses_egp_override is None else "تعديل يدوي",
        allocation_rule="Value-Based",
    ))

    # 7. Allocation per item
    pref = req.allocation_preference or "Value-Based"
    primary_ratios, actual_pri_rule, missing_pri = allocation_ratios(items_raw, pref)
    if missing_pri and (clearance_fee + port_handling) > 0:
        messages.append(_message(
            ALLOCATION_BASIS_INCOMPLETE,
            bucket="Clearance & Port",
            rule=pref,
            item_codes=", ".join(missing_pri),
        ))
    val_ratios, _, _ = allocation_ratios(items_raw, "Value-Based")

    items_breakdown: List[EstimatedLandedCostItemBreakdown] = []

    for idx, itm in enumerate(items_raw):
        l_no = itm["line_no"]
        c_line = customs_line_map.get(l_no)
        excluded_from_customs = itm["customs_excluded"]

        fob_item_egp = itm["fob_total_fc"] * fx_rate
        qty = _unit_qty(itm["qty"])
        fob_unit_egp = fob_item_egp / qty

        # Allocation shares
        alloc_freight = freight_egp * freight_ratios[idx]
        alloc_ins = insurance_egp * val_ratios[idx]

        if excluded_from_customs:
            alloc_duty = 0.0
            alloc_vat = 0.0
        else:
            inc_val_ratio = (itm["fob_total_fc"] / included_fob_fc) if included_fob_fc > 0 else 0.0
            alloc_duty = float(c_line.duty_egp) if c_line else (total_customs_duty_egp * inc_val_ratio)
            alloc_inspection = total_inspection_fees_egp * inc_val_ratio
            alloc_vat = (
                float(
                    c_line.vat_egp
                    + c_line.schedule_tax_egp
                    + c_line.customs_service_fee_egp
                    + getattr(c_line, "development_fee_egp", 0.0)
                    + getattr(c_line, "import_fee_egp", 0.0)
                )
                + alloc_inspection
                if c_line
                else ((total_taxes_and_fees_egp - total_customs_duty_egp) * inc_val_ratio)
            )

        alloc_clearance_port = (clearance_fee + port_handling) * primary_ratios[idx]
        alloc_inland = inland_trucking * inland_ratios[idx]
        alloc_other = (bank_fees + other_fees) * val_ratios[idx]

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




__all__ = ["simulate_estimated_landed_cost_service", "_estimate_parameter"]
