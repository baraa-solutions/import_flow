from .landed_cost_simulation_service import simulate_estimated_landed_cost_service
import logging
import math
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from typing import List, Optional, Dict, Any, Tuple
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
WHT_RATE_NOT_CONFIGURED = "WHT_RATE_NOT_CONFIGURED"

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
from .settlement_crud_service import *

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

    currency: Optional[str] = None
    messages: List[SettlementMessage] = []
    goods_rate: Optional[float] = None

    invoices: List[AggregatedInvoiceItemSchema] = []

    # 1. Commercial Goods Invoices (FOB / CIF from PO & Invoices Data)
    # Query Paid supplier payment requests for this import file (ACC2-T07)
    import sqlalchemy as sa
    from modules.financial_approval.model import PaymentRequestSession

    paid_supplier_reqs = (
        db.query(PaymentRequestSession)
        .filter(
            PaymentRequestSession.import_file_id == import_file_id,
            PaymentRequestSession.is_active == True,
            sa.func.lower(PaymentRequestSession.status) == "paid",
        )
        .order_by(PaymentRequestSession.payment_id.asc())
        .all()
    )

    paid_fc_by_curr: Dict[str, float] = {}
    for req in paid_supplier_reqs:
        c_code = (req.swift_transferred_currency or req.currency_code or "").strip().upper()
        if c_code:
            amt = float(req.swift_transferred_amount if req.swift_transferred_amount is not None else (req.requested_amount or 0.0))
            paid_fc_by_curr[c_code] = paid_fc_by_curr.get(c_code, 0.0) + amt

    file_has_supplier_reqs = (
        db.query(PaymentRequestSession)
        .filter(
            PaymentRequestSession.import_file_id == import_file_id,
            PaymentRequestSession.is_active == True,
        )
        .count() > 0
    )

    unallocated_paid_fc = dict(paid_fc_by_curr)
    allocated_goods_egp_at_inv_rate = 0.0

    invoices_data = imp.invoices_data or []
    if invoices_data and isinstance(invoices_data, list):
        for idx, inv in enumerate(invoices_data):
            inv_no = str(inv.get("invoice_no") or inv.get("invoice_number") or f"COMM-{imp.import_file_code}-{idx+1}")
            inv_date = str(inv.get("invoice_date") or (imp.file_opening_date or ""))
            amt_fc = float(inv.get("amount") or inv.get("total_amount") or inv.get("total_fob") or 0.0)
            inv_curr = inv.get("currency")
            if amt_fc > 0:
                if not inv_curr or not str(inv_curr).strip():
                    raise currency_missing_error("Commercial Invoice", inv_no)
                c_curr = str(inv_curr).strip().upper()
                if not currency:
                    currency = c_curr
            else:
                c_curr = str(inv_curr).strip().upper() if inv_curr else (currency or "EGP")

            if c_curr == "EGP":
                c_rate = float(inv.get("exchange_rate") or 1.0)
            elif inv.get("exchange_rate") and float(inv.get("exchange_rate")) != 1.0:  # 1.0 on foreign = not set
                c_rate = float(inv.get("exchange_rate"))
            else:
                c_rate = fx.rate(c_curr, _as_date(inv.get("invoice_date")))
            if goods_rate is None and amt_fc > 0:
                goods_rate = c_rate
            amt_egp = round(amt_fc * c_rate if c_curr != "EGP" else amt_fc, 2)

            # Sourcing paid amounts (ACC2-T07): when PaymentRequestSession rows exist for the file,
            # allocate transferred FC from Paid requests only (imp.swift_no does NOT decide).
            # When no payment requests exist in the system for this file, legacy swift_no / paid flag applies.
            if file_has_supplier_reqs:
                avail_fc = unallocated_paid_fc.get(c_curr, 0.0)
                inv_paid_fc = min(avail_fc, amt_fc) if amt_fc > 0 else 0.0
                unallocated_paid_fc[c_curr] = max(0.0, avail_fc - inv_paid_fc)
                paid_egp = round(inv_paid_fc * c_rate if c_curr != "EGP" else inv_paid_fc, 2)
                allocated_goods_egp_at_inv_rate += paid_egp
            else:
                is_paid = bool(imp.swift_no or inv.get("payment_status") == "PAID" or inv.get("paid"))
                inv_paid_fc = amt_fc if is_paid else 0.0
                paid_egp = amt_egp if is_paid else 0.0

            rem_egp = max(0.0, round(amt_egp - paid_egp, 2))
            status = "PAID" if rem_egp == 0 and amt_egp > 0 else ("PARTIAL" if paid_egp > 0 else "UNPAID")

            swift_refs = [r.swift_reference_no for r in paid_supplier_reqs if r.swift_reference_no]
            pay_ref = ", ".join(swift_refs) if swift_refs else (imp.swift_no or inv.get("payment_ref") or "سويفت بنكي")

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
                payment_reference=pay_ref,
                withholding_tax_rate=0.0,
                withholding_tax_amount_egp=0.0,
                net_payable_egp=amt_egp,
                source_module="Commercial Invoice",
                notes=f"فاتورة تجارية للشحنة {imp.import_file_code}",
            ))
    elif imp.estimated_cost and imp.estimated_cost > 0:
        if not imp.estimated_cost_currency or not str(imp.estimated_cost_currency).strip():
            raise currency_missing_error("Import File Estimated Cost", imp.import_file_code)
        currency = str(imp.estimated_cost_currency).strip().upper()
        amt_fc = float(imp.estimated_cost)
        est_rate = 1.0 if currency == "EGP" else fx.rate(currency, _as_date(imp.file_opening_date))
        goods_rate = est_rate
        amt_egp = round(amt_fc * est_rate if currency != "EGP" else amt_fc, 2)

        if file_has_supplier_reqs:
            avail_fc = unallocated_paid_fc.get(currency, 0.0)
            inv_paid_fc = min(avail_fc, amt_fc) if amt_fc > 0 else 0.0
            unallocated_paid_fc[currency] = max(0.0, avail_fc - inv_paid_fc)
            paid_egp = round(inv_paid_fc * est_rate if currency != "EGP" else inv_paid_fc, 2)
            allocated_goods_egp_at_inv_rate += paid_egp
        else:
            is_paid = bool(imp.swift_no)
            inv_paid_fc = amt_fc if is_paid else 0.0
            paid_egp = amt_egp if is_paid else 0.0

        rem_egp = max(0.0, round(amt_egp - paid_egp, 2))
        status = "PAID" if rem_egp == 0 and amt_egp > 0 else ("PARTIAL" if paid_egp > 0 else "UNPAID")

        swift_refs = [r.swift_reference_no for r in paid_supplier_reqs if r.swift_reference_no]
        pay_ref = ", ".join(swift_refs) if swift_refs else (imp.swift_no or "سويفت بنكي")

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
            payment_reference=pay_ref,
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
            customs_components: List[CustomsDutyComponentSchema] = []
            for field_name, cat in DUTY_COMPONENT_CATEGORIES:
                val = float(getattr(cl, field_name, 0.0) or 0.0)
                if val > 0:
                    customs_components.append(CustomsDutyComponentSchema(
                        component=field_name,
                        category=cat,
                        amount_egp=val,
                    ))
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
                components=customs_components,
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

        # A partial payment has no stored paid amount: it is reported as unknown and counted as 0 paid (FS-10).
        paid = net if is_p else 0.0
        if is_part:
            messages.append(_message(PAYMENT_STATUS_UNKNOWN, invoice_no=inv_ref, party_name=cl_inv.provider_name or "-"))
        rem = max(0.0, net - paid)

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

    # 5.1 Logistics Service Invoices (modules.logistics_invoices.model.LogisticsServiceInvoice)
    from modules.logistics_invoices.model import LogisticsServiceInvoice
    lsi_invoices = db.query(LogisticsServiceInvoice).filter(
        LogisticsServiceInvoice.shipment_id == import_file_id,
        LogisticsServiceInvoice.is_active == True,
    ).all()
    for lsi in lsi_invoices:
        pt_map = {
            "freight": ("SHIPPING_LINE", "خط الشحن / وكيل النولون", "Freight Forwarding"),
            "clearance": ("BROKER", "مخلص جمركي", "Customs Clearance"),
            "inspection": ("INSPECTION", "شركة فحص وتفتيش", "Inspection & Testing"),
            "insurance": ("INSURANCE", "شركة تأمين بحري", "Marine Insurance"),
        }
        pt_code, pt_ar, cat_desc = pt_map.get(lsi.partner_type, ("OTHER", "شريك لوجستي", "Logistics Service"))
        invoices.append(AggregatedInvoiceItemSchema(
            invoice_id=f"LSI-{lsi.invoice_id}",
            invoice_no=lsi.invoice_number or lsi.invoice_code,
            invoice_date=str(lsi.invoice_date.date() if hasattr(lsi.invoice_date, "date") else lsi.invoice_date),
            party_type=pt_code,
            party_type_ar=pt_ar,
            party_name=lsi.partner_name,
            category=cat_desc,
            category_ar=cat_desc,
            currency=lsi.currency,
            exchange_rate=float(lsi.exchange_rate or 1.0),
            amount_fc=float(lsi.total_amount_fx or 0.0),
            amount_egp=float(lsi.total_amount_egp or 0.0),
            paid_amount_egp=float(lsi.paid_amount_egp or 0.0),
            remaining_amount_egp=float(lsi.remaining_amount_egp or 0.0),
            payment_status=lsi.payment_status.upper(),
            payment_reference=lsi.invoice_code,
            withholding_tax_rate=0.0,
            withholding_tax_amount_egp=float(lsi.wht_amount or 0.0),
            net_payable_egp=float(lsi.net_payable_egp or 0.0),
            source_module="Logistics Service Invoice LSI",
            notes=lsi.notes or f"فاتورة خدمات لوجستية {lsi.partner_type} رقم {lsi.invoice_number}",
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
            if tot_fx > 0 and (not d.currency or not str(d.currency).strip()):
                raise currency_missing_error("Demurrage Tracking", d.tracking_code or str(d.tracking_id))
            d_ccy = (d.currency or "EGP").upper()
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
                currency=d.currency or "EGP",
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

    # Trade-finance costs (Pillar 3): bank charges of the file's financing instruments and realized FX
    # variance are part of the actual landed cost, allocated like other overheads (Value-Based).
    invoices.extend(_trade_finance_cost_invoices(db, import_file_id))

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
                "net_payable_egp": 0.0,
            }
        parties_map[pkey]["invoices_count"] += 1
        parties_map[pkey]["total_egp"] = round(parties_map[pkey]["total_egp"] + inv.amount_egp, 2)
        parties_map[pkey]["paid_egp"] = round(parties_map[pkey]["paid_egp"] + inv.paid_amount_egp, 2)
        parties_map[pkey]["remaining_egp"] = round(parties_map[pkey]["remaining_egp"] + inv.remaining_amount_egp, 2)
        net_egp = inv.net_payable_egp if inv.net_payable_egp is not None else inv.amount_egp
        parties_map[pkey]["net_payable_egp"] = round(parties_map[pkey].get("net_payable_egp", 0.0) + net_egp, 2)

    parties_summary = [InvoicesPartySummary(**pdata) for pdata in parties_map.values()]

    total_amt = round(sum(inv.amount_egp for inv in invoices), 2)
    total_paid = round(sum(inv.paid_amount_egp for inv in invoices), 2)
    total_rem = round(sum(inv.remaining_amount_egp for inv in invoices), 2)
    total_wht = round(sum(inv.withholding_tax_amount_egp for inv in invoices), 2)
    total_net = round(sum((inv.net_payable_egp if inv.net_payable_egp is not None else inv.amount_egp) for inv in invoices), 2)
    readiness = min(100.0, round((total_paid / total_net * 100.0), 1)) if total_net > 0 else 100.0

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
    elif currency and currency.upper() == "EGP":
        reported_rate = 1.0
    elif currency:
        reported_rate = fx.rate_or_none(currency) or 0.0
    else:
        reported_rate = 0.0

    # Realised FX difference on supplier payments (ACC2-T07): sum(paid_amount_egp) - sum(paid FC x invoice rate)
    fx_diff_egp: Optional[float] = None
    paid_reqs_with_debit = [r for r in paid_supplier_reqs if r.paid_amount_egp is not None]
    if paid_reqs_with_debit:
        total_paid_debit_egp = sum(float(r.paid_amount_egp) for r in paid_reqs_with_debit)
        fx_diff_egp = round(total_paid_debit_egp - allocated_goods_egp_at_inv_rate, 2)

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
        total_net_payable_egp=total_net,
        total_withholding_tax_egp=total_wht,
        settlement_readiness_percent=readiness,
        fx_difference_egp=fx_diff_egp,
        financial_settlement_status=imp.financial_settlement_status or "PENDING_SETTLEMENT",
        parties_summary=parties_summary,
        invoices=invoices,
        unsettled_warnings=warnings,
        messages=messages,
    )


def _trade_finance_cost_invoices(db: Session, import_file_id: int) -> List[AggregatedInvoiceItemSchema]:
    """Settlement rows for the bank charges (already debited, so PAID) and the realized FX gain / loss of the
    file's non-cancelled finance instruments. An FX gain is a negative amount: it lowers the landed cost.
    Unsettled FX records (no settlement rate yet) are not realized and are skipped."""
    from modules.trade_finance.model import ImportFinanceInstrument

    rows: List[AggregatedInvoiceItemSchema] = []
    instruments = (
        db.query(ImportFinanceInstrument)
        .filter(
            ImportFinanceInstrument.import_file_id == import_file_id,
            ImportFinanceInstrument.is_active == True,  # noqa: E712
            ImportFinanceInstrument.status != "CANCELLED",
        )
        .order_by(ImportFinanceInstrument.id.asc())
        .all()
    )
    for inst in instruments:
        bank = inst.issuing_bank or "البنك"
        for charge in inst.charges:
            amount = round(float(charge.amount_egp or 0.0), 2)
            if not charge.is_active or amount <= 0:
                continue
            rows.append(AggregatedInvoiceItemSchema(
                invoice_id=f"BANK-{charge.id}",
                invoice_no=charge.swift_reference or f"BANK-{inst.instrument_number}-{charge.id}",
                invoice_date=str(charge.debit_date),
                party_type="BANK",
                party_type_ar="البنك",
                party_name=bank,
                category="Bank & Financing Charges",
                category_ar="عمولات ومصاريف بنكية وتمويل",
                currency="EGP",
                exchange_rate=1.0,
                amount_fc=amount,
                amount_egp=amount,
                paid_amount_egp=amount,
                remaining_amount_egp=0.0,
                payment_status="PAID",
                payment_reference=inst.instrument_number,
                withholding_tax_rate=0.0,
                withholding_tax_amount_egp=0.0,
                net_payable_egp=amount,
                source_module="Trade Finance (LC / CAD)",
                notes=f"{charge.charge_type} — {inst.instrument_type} {inst.instrument_number}",
            ))
        for fx_rec in inst.fx_records:
            variance = round(float(fx_rec.variance_amount_egp or 0.0), 2)
            if not fx_rec.is_active or fx_rec.settlement_rate is None or variance == 0:
                continue
            rows.append(AggregatedInvoiceItemSchema(
                invoice_id=f"FXV-{fx_rec.id}",
                invoice_no=fx_rec.hedging_contract_ref or f"FXV-{inst.instrument_number}-{fx_rec.id}",
                invoice_date=str(fx_rec.settlement_date or fx_rec.booking_date),
                party_type="BANK",
                party_type_ar="البنك",
                party_name=bank,
                category="Realized FX Variance",
                category_ar="فروق عملة محققة",
                currency="EGP",
                exchange_rate=1.0,
                amount_fc=variance,
                amount_egp=variance,
                paid_amount_egp=variance,
                remaining_amount_egp=0.0,
                payment_status="PAID",
                payment_reference=inst.instrument_number,
                withholding_tax_rate=0.0,
                withholding_tax_amount_egp=0.0,
                net_payable_egp=variance,
                source_module="Trade Finance FX Variance",
                notes=(
                    f"{fx_rec.foreign_currency} {fx_rec.original_amount:,.2f}: "
                    f"{fx_rec.booking_rate} → {fx_rec.settlement_rate} ({fx_rec.variance_nature})"
                ),
            ))
    return rows


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
    ensure_file_open(imp)
    ensure_invoices_not_settled(imp)

    agg = aggregate_shipment_invoices_service(db, payload.import_file_id)
    invoices = agg.invoices

    unpaid_count = sum(1 for inv in invoices if inv.payment_status != "PAID")
    ensure_invoices_settlement_ready(
        agg.settlement_readiness_percent,
        unpaid_count,
        payload.acknowledge_unpaid,
    )

    total_settled_egp = round(sum(inv.amount_egp for inv in invoices), 2)
    today_date = cairo_today()
    today_str = str(today_date)

    old_data = {
        "status": imp.financial_settlement_status,
        "total_expenses_egp": float(imp.financial_settlement_total_egp or 0.0),
        "total_landed_cost_egp": float(imp.actual_landed_cost_total_egp or 0.0),
        "rows": int(imp.financial_settlement_invoices_count or 0),
    }

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
    ack_suffix = " (unpaid acknowledged)" if payload.acknowledge_unpaid else ""
    for t in tasks_901:
        t.status = "Completed"
        t.is_auto_closed = True
        t.notes = f"Invoices settlement and reconciliation approved by {actor} on {today_str}{ack_suffix}"

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

    new_data = {
        "status": imp.financial_settlement_status,
        "total_expenses_egp": float(imp.financial_settlement_total_egp or 0.0),
        "total_landed_cost_egp": float(imp.actual_landed_cost_total_egp or 0.0),
        "rows": int(imp.financial_settlement_invoices_count or 0),
    }
    best_effort(
        db,
        _audit_import_file,
        "AuditLog for ImportFile confirm invoices",
        db,
        imp,
        "CONFIRM_INVOICES",
        actor,
        new_data=new_data,
        old_data=old_data,
    )

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


def scale_item_fobs_to_header(items: List[Dict[str, Any]], target_fob_egp: float) -> None:
    """Scale item fob_total_egp so they sum exactly to target_fob_egp using largest remainder (ACC2-T06).
    Distributes cents with largest remainder so the rounded item FOB sum equals the rounded header.
    fob_unit = fob_total / qty (unrounded internally).
    """
    if not items:
        return
    total_fob = sum(float(i.get("fob_total_egp", 0.0) or 0.0) for i in items)
    if total_fob <= 0:
        return
    target_cents = int(round(target_fob_egp * 100))
    allocations = []
    for idx, item in enumerate(items):
        fob = float(item.get("fob_total_egp", 0.0) or 0.0)
        share_cents = (fob / total_fob) * target_cents
        base_cents = int(math.floor(share_cents))
        rem = share_cents - base_cents
        allocations.append({"idx": idx, "base": base_cents, "rem": rem})

    deficit = target_cents - sum(a["base"] for a in allocations)
    allocations.sort(key=lambda a: (-a["rem"], a["idx"]))
    for i in range(deficit):
        allocations[i]["base"] += 1

    allocations.sort(key=lambda a: a["idx"])
    for idx, item in enumerate(items):
        cents = allocations[idx]["base"]
        item_fob = round(cents / 100.0, 2)
        qty = float(item.get("qty", 1.0) or 1.0)
        item["fob_total_egp"] = item_fob
        item["fob_unit_egp"] = (item_fob / qty) if qty > 0 else item_fob


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
    unit_tol = get_float_parameter(db, PARAM_VARIANCE_UNIT_TOLERANCE_EGP, DEFAULT_VARIANCE_UNIT_TOLERANCE_EGP)
    file_tol = get_float_parameter(db, PARAM_VARIANCE_FILE_TOLERANCE_EGP, DEFAULT_VARIANCE_FILE_TOLERANCE_EGP)

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
    currency = agg.currency
    exchange_rate = agg.exchange_rate

    # Separate FOB Goods from other Expenses
    goods_invoices = [inv for inv in all_invoices if _is_goods_invoice(inv)]
    expense_invoices = [inv for inv in all_invoices if inv not in goods_invoices]

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
        if inv.components:
            for comp in inv.components:
                b = CUSTOMS_COMPONENT_BUCKET.get(comp.component, actual_expense_bucket(comp.category, inv.party_type))
                cat_expenses[b]["actual"] += float(comp.amount_egp or 0.0)
                cat_expenses[b]["count"] += 1
        else:
            bucket = actual_expense_bucket(inv.category, inv.party_type)
            cat_expenses[bucket]["actual"] += float(inv.amount_egp or 0.0)
            cat_expenses[bucket]["count"] += 1

    actual_total_expenses_egp = sum(c["actual"] for c in cat_expenses.values())

    # Estimated numbers from simulation (duty / VAT split = the simulation's own totals, FS-07)
    if sim:
        est_total_fob = sim.total_fob_egp
        est_freight = sim.total_freight_egp
        est_ins = sim.total_insurance_egp
        est_taxes = sim.total_customs_and_taxes_egp
        est_duty = sim.total_customs_duty_egp
        est_vat = sim.total_vat_and_fees_egp
        est_clearance = sim.total_clearance_and_port_egp
        est_transport = sim.total_inland_transport_egp
        est_demurrage = 0.0 # usually 0 planned
        est_other = sim.total_other_expenses_egp
        est_total_expenses = sim.total_expenses_egp
        est_total_landed = sim.total_landed_cost_egp
        est_markup = sim.average_markup_factor
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
        for b_key, est_val in cat_est_map.items():
            if est_val and est_val > 0 and cat_expenses.get(b_key, {}).get("count", 0) == 0:
                messages.append(
                    _message(
                        ACTUAL_SOURCE_MISSING,
                        bucket=b_key,
                        estimated_egp=round(est_val, 2),
                    )
                )
    else:
        est_total_fob = None
        est_freight = None
        est_ins = None
        est_taxes = None
        est_duty = None
        est_vat = None
        est_clearance = None
        est_transport = None
        est_demurrage = None
        est_other = None
        est_total_expenses = None
        est_total_landed = None
        est_markup = None
        cat_est_map = {}

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
            est_u = float(s_match.unit_landed_cost_egp) if s_match else (float(fob_u_egp * est_markup) if (sim and est_markup) else None)

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

    total_items_fob = sum(i["fob_total_egp"] for i in items_raw)

    # 4. Single FOB basis determination and scaling (ACC2-T06, F08, F09)
    if goods_invoices:
        fob_basis = "INVOICE"
        actual_total_fob_egp = sum(inv.amount_egp for inv in goods_invoices)
        if total_items_fob > 0:
            scale_item_fobs_to_header(items_raw, actual_total_fob_egp)
    elif items_raw:
        fob_basis = "PO"
        actual_total_fob_egp = total_items_fob
    elif sim and sim.total_fob_egp > 0:
        fob_basis = "ESTIMATE"
        actual_total_fob_egp = sim.total_fob_egp
    elif (imp.estimated_cost or 0) > 0:
        fob_basis = "ESTIMATE"
        actual_total_fob_egp = float(imp.estimated_cost) * (fx.rate(currency, _as_date(imp.file_opening_date)) if currency else 1.0)
    else:
        fob_basis = "ESTIMATE"
        actual_total_fob_egp = 0.0

    actual_total_landed_cost_egp = actual_total_fob_egp + actual_total_expenses_egp
    actual_markup_factor = (actual_total_landed_cost_egp / actual_total_fob_egp) if actual_total_fob_egp > 0 else 1.0
    total_items_wt = sum(i["gross_weight_kg"] for i in items_raw)
    total_items_cbm = sum(i["cbm"] for i in items_raw)
    n_items = len(items_raw)

    ship_mode = (getattr(imp, "shipment_mode", None) or getattr(imp, "shipping_mode", None) or "").lower()
    is_air = "air" in ship_mode or "طيران" in ship_mode or "جوي" in ship_mode
    default_freight_rule = "Weight-Based" if is_air else "Volume-Based"

    intended_rules = {
        "Freight": default_freight_rule,
        "Insurance": "Value-Based",
        "Customs Duty": "Value-Based",
        "VAT & Taxes": "Value-Based",
        "Clearance & Port": pref,
        "Inland Transport": "Weight-Based",
        "Demurrage & Storage": "Volume-Based",
        "Other & Admin": "Value-Based",
    }

    rules_used: Dict[str, str] = {}
    bucket_ratios: Dict[str, List[float]] = {}
    for b_key in cat_expenses:
        intended = intended_rules.get(b_key, pref)
        ratios, actual_rule, missing = allocation_ratios(items_raw, intended)
        rules_used[b_key] = actual_rule
        bucket_ratios[b_key] = ratios
        if missing and cat_expenses[b_key]["actual"] > 0:
            messages.append(_message(
                ALLOCATION_BASIS_INCOMPLETE,
                bucket=b_key,
                rule=intended,
                item_codes=", ".join(missing),
            ))

    # Build Categories Breakdown
    categories_breakdown: List[ActualLandedCostCategoryBreakdown] = []
    for c_key, c_data in cat_expenses.items():
        act_val = c_data["actual"]
        if sim is not None:
            est_val = cat_est_map.get(c_key, 0.0)
            v_egp = round(act_val - est_val, 2)
            v_pct = round((v_egp / est_val * 100.0), 2) if est_val > 0 else (100.0 if act_val > 0 else 0.0)
            c_est_egp: Optional[float] = round(est_val, 2)
            c_var_egp: Optional[float] = v_egp
            c_var_pct: Optional[float] = v_pct
        else:
            c_est_egp = None
            c_var_egp = None
            c_var_pct = None

        categories_breakdown.append(ActualLandedCostCategoryBreakdown(
            category=c_key,
            category_ar=c_data["ar"],
            estimated_egp=c_est_egp,
            actual_egp=round(act_val, 2),
            variance_egp=c_var_egp,
            variance_pct=c_var_pct,
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

    for idx, itm in enumerate(items_raw):
        qty = _unit_qty(itm["qty"])
        fob_tot = itm["fob_total_egp"]
        fob_u = itm["fob_unit_egp"]

        # Allocation per bucket using BP-038 ratios
        all_freight = act_freight * bucket_ratios["Freight"][idx]
        all_ins = act_ins * bucket_ratios["Insurance"][idx]
        all_duty = act_duty * bucket_ratios["Customs Duty"][idx]
        all_vat = act_vat * bucket_ratios["VAT & Taxes"][idx]
        all_clearance = act_clearance * bucket_ratios["Clearance & Port"][idx]
        all_transport = act_transport * bucket_ratios["Inland Transport"][idx]
        all_demurrage = act_demurrage * bucket_ratios["Demurrage & Storage"][idx]
        all_other = act_other * bucket_ratios["Other & Admin"][idx]

        tot_alloc = all_freight + all_ins + all_duty + all_vat + all_clearance + all_transport + all_demurrage + all_other
        item_landed_tot = fob_tot + tot_alloc
        item_landed_u = item_landed_tot / qty
        item_mkp = (item_landed_u / fob_u) if fob_u > 0 else 1.0
        item_mkp_pct = (item_mkp - 1.0) * 100.0

        if sim is not None and itm.get("estimated_unit_landed_cost_egp") is not None:
            est_u = float(itm["estimated_unit_landed_cost_egp"])
            u_var = item_landed_u - est_u
            u_var_pct = (u_var / est_u * 100.0) if est_u > 0 else 0.0
            if u_var < -unit_tol:
                v_status = "SAVING"
            elif u_var > unit_tol:
                v_status = "INCREASED"
            else:
                v_status = "MATCHED"
            i_est_u: Optional[float] = round(est_u, 2)
            i_u_var: Optional[float] = round(u_var, 2)
            i_u_var_pct: Optional[float] = round(u_var_pct, 2)
        else:
            i_est_u = None
            i_u_var = None
            i_u_var_pct = None
            v_status = "NO_ESTIMATE"

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
            estimated_unit_landed_cost_egp=i_est_u,
            unit_cost_variance_egp=i_u_var,
            unit_cost_variance_pct=i_u_var_pct,
            item_variance_status=v_status,
        ))

    # Overall file variances
    if sim is not None:
        fob_var_egp = round(actual_total_fob_egp - est_total_fob, 2)
        fob_var_pct = round((fob_var_egp / est_total_fob * 100.0), 2) if est_total_fob > 0 else 0.0

        exp_var_egp = round(actual_total_expenses_egp - est_total_expenses, 2)
        exp_var_pct = round((exp_var_egp / est_total_expenses * 100.0), 2) if est_total_expenses > 0 else 0.0

        landed_var_egp = round(actual_total_landed_cost_egp - est_total_landed, 2)
        landed_var_pct = round((landed_var_egp / est_total_landed * 100.0), 2) if est_total_landed > 0 else 0.0

        if landed_var_egp < -file_tol:
            overall_status = "UNDER_BUDGET"
            overall_status_ar = f"وفورات في التكلفة بنسبة {abs(landed_var_pct):.1f}% (تحت الميزانية التقديرية)"
        elif landed_var_egp > file_tol:
            overall_status = "OVER_BUDGET"
            overall_status_ar = f"تجاوز وحيود في التكلفة بنسبة {landed_var_pct:.1f}% (فوق الميزانية التقديرية)"
        else:
            overall_status = "ON_BUDGET"
            overall_status_ar = "مطابق للميزانية التقديرية بدقة عالية"

        res_est_fob: Optional[float] = round(est_total_fob, 2)
        res_est_exp: Optional[float] = round(est_total_expenses, 2)
        res_est_landed: Optional[float] = round(est_total_landed, 2)
        res_est_markup: Optional[float] = round(est_markup, 4) if est_markup is not None else None

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
    else:
        fob_var_egp = None
        fob_var_pct = None
        exp_var_egp = None
        exp_var_pct = None
        landed_var_egp = None
        landed_var_pct = None
        overall_status = "NO_ESTIMATE"
        overall_status_ar = "لا يوجد تقدير مبدئي للمقارنة"
        res_est_fob = None
        res_est_exp = None
        res_est_landed = None
        res_est_markup = None

        exec_summary = (
            f"بلغت التكلفة الإجمالية الفعلية الواصلة للشحنة {imp.import_file_code} ما قيمته "
            f"{actual_total_landed_cost_egp:,.2f} جنيه مصري (لا يوجد تقدير مبدئي للمقارنة). "
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
        fob_basis=fob_basis,
        allocation_preference=pref,
        total_items_count=len(items_breakdown),
        total_invoices_count=len(all_invoices),
        estimated_total_fob_egp=res_est_fob,
        actual_total_fob_egp=round(actual_total_fob_egp, 2),
        fob_variance_egp=fob_var_egp,
        fob_variance_pct=fob_var_pct,
        estimated_total_expenses_egp=res_est_exp,
        actual_total_expenses_egp=round(actual_total_expenses_egp, 2),
        expenses_variance_egp=exp_var_egp,
        expenses_variance_pct=exp_var_pct,
        estimated_total_landed_cost_egp=res_est_landed,
        actual_total_landed_cost_egp=round(actual_total_landed_cost_egp, 2),
        landed_variance_egp=landed_var_egp,
        landed_variance_pct=landed_var_pct,
        estimated_markup_factor=res_est_markup,
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
        "vat_amount_egp": round(float(getattr(inv, "vat_amount_egp", 0.0) or 0.0), 2),
        "wht_amount_egp": round(float(getattr(inv, "withholding_tax_amount_egp", 0.0) or 0.0), 2),
        "net_payable_egp": round(float(getattr(inv, "net_payable_egp", inv.amount_egp) or 0.0), 2),
        "duty_component": getattr(inv, "duty_component", None),
    }


def settlement_item_row(line: ActualLandedCostItemLine) -> Dict[str, Any]:
    """An actual item line stored in the canonical ``ItemLandedCostSchema`` keys (FS-01): customs = duty + VAT,
    other = insurance + demurrage + other. The actual line keys stay additively (canonical keys win)."""
    qty = _unit_qty(line.qty)
    fob_unit_unrounded = (line.fob_total_egp / qty) if qty > 0 else line.fob_unit_egp
    canonical = {
        "item_code": line.item_code,
        "item_name": line.item_name,
        "qty": line.qty,
        "gross_weight_kg": line.gross_weight_kg,
        "cbm": line.cbm,
        "fob_unit_egp": fob_unit_unrounded,
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
    ensure_file_open(imp)
    ensure_cost_not_approved(imp, get_settlement_by_import_file_id(db, imp.import_file_id))
    ensure_invoices_settled(imp)

    # Run calculation
    calc_req = ActualLandedCostCalculationRequest(
        allocation_preference=payload.allocation_preference,
        custom_category_allocation=payload.custom_category_allocation,
    )
    calc, expense_invoices = _calculate_actual_landed_cost(db, payload.import_file_id, calc_req)
    if calc.fob_basis == "ESTIMATE":
        raise coded_error(
            status.HTTP_409_CONFLICT,
            SETTLEMENT_ACTUAL_FOB_MISSING,
            "لا يمكن اعتماد تكلفة الوصول الفعلية لعدم وجود فواتير بضائع تجارية أو بنود أمر شراء لتحديد قيمة FOB الفعلية.",
            import_file_id=payload.import_file_id,
        )
    validate_items_allocation_readiness(calc.items_breakdown)

    now_utc = datetime.now(timezone.utc)
    today_str = str(now_utc.date())

    # 1. Update or create LandedCostSettlementRecord
    settlement = get_settlement_by_import_file_id(db, imp.import_file_id)
    if settlement and settlement.expense_invoices:
        aggregated_nos = {inv.invoice_no for inv in expense_invoices}
        for inv in expense_invoices:
            if getattr(inv, "components", None):
                for comp in inv.components:
                    aggregated_nos.add(f"{inv.invoice_no}/{comp.component}")
        manual_rows = [
            e for e in settlement.expense_invoices
            if e.get("invoice_no") not in aggregated_nos
            and (e.get("invoice_no") or "").split("/")[0] not in aggregated_nos
            and not str(e.get("note") or "").startswith("Auto-fetched")
            and not str(e.get("invoice_no") or "").startswith(RECALC_ADJUSTMENT_PREFIX)
        ]
        ensure_no_manual_rows(manual_rows)

    old_data = _settlement_snapshot_dict(settlement)

    rules_used = {c.category: c.allocation_rule for c in calc.categories_breakdown}
    items_json = [settlement_item_row(itm) for itm in calc.items_breakdown]
    expenses_json = []
    for inv in expense_invoices:
        if inv.components:
            for comp in inv.components:
                comp_bucket = CUSTOMS_COMPONENT_BUCKET.get(comp.component, actual_expense_bucket(comp.category, inv.party_type))
                rule = rules_used.get(comp_bucket, rules_used.get(comp.category, "Value-Based"))
                expenses_json.append({
                    "invoice_no": f"{inv.invoice_no}/{comp.component}",
                    "category": comp.category,
                    "duty_component": comp.component,
                    "provider_name": inv.party_name,
                    "currency": "EGP",
                    "amount_fx": 0.0,
                    "exchange_rate": 1.0,
                    "amount_egp": round(float(comp.amount_egp or 0.0), 2),
                    "allocation_rule": rule,
                    "bucket": comp_bucket,
                    "source_category": comp.category,
                    "category_code": inv.category_code,
                    "party_type": inv.party_type,
                    "invoice_date": inv.invoice_date,
                    "source_module": inv.source_module,
                    "is_seller_paid": False,
                    "payer": "Importer",
                    "note": f"Declaration 46 component {comp.component}",
                })
        else:
            expenses_json.append(
                settlement_expense_row(inv, rules_used.get(actual_expense_bucket(inv.category, inv.party_type), "Value-Based"))
            )

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

    # Auto-sync Landed Costs into Item Price History
    from modules.master_items.service import MasterItemService
    MasterItemService.update_landed_costs_from_settlement(db, imp.import_file_id, items_json)

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
        SmartTask.status != "Completed",
        SmartTask.task_code.ilike("TSK-0902%"),
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

    new_data = _settlement_snapshot_dict(settlement)
    best_effort(
        db,
        _audit,
        "AuditLog for LandedCostSettlementRecord approve",
        db,
        settlement,
        "APPROVE",
        actor,
        new_data=new_data,
        old_data=old_data,
    )

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


def get_shipment_fx_reconciliation(db: Session, import_file_id: int) -> Dict[str, Any]:
    """
    Reconciles customs exchange rate (applied by customs authority for duties/VAT)
    vs commercial bank settlement exchange rates (applied by commercial bank for wire transfers).
    Calculates the resulting foreign exchange variance impact.
    """
    from modules.customs_clearance.model import CustomsClearanceRecord
    from modules.financial_approval.model import PaymentRequestSession

    customs_rec = db.query(CustomsClearanceRecord).filter(
        CustomsClearanceRecord.import_file_id == import_file_id,
        CustomsClearanceRecord.is_active == True,
    ).first()
    customs_rate = customs_rec.customs_exchange_rate if customs_rec and customs_rec.customs_exchange_rate else None

    payments = db.query(PaymentRequestSession).filter(
        PaymentRequestSession.import_file_id == import_file_id,
        PaymentRequestSession.is_active == True,
        PaymentRequestSession.status.in_(["Approved", "Paid"]),
    ).all()

    total_fx = sum(p.requested_amount for p in payments if p.currency_code != "EGP")
    total_egp = sum(p.requested_amount_egp for p in payments if p.currency_code != "EGP")
    weighted_bank_rate = round(total_egp / total_fx, 4) if total_fx > 0 else None

    fx_variance_rate = round(weighted_bank_rate - customs_rate, 4) if (weighted_bank_rate and customs_rate) else 0.0
    fx_variance_total_egp = round(fx_variance_rate * total_fx, 2) if total_fx > 0 else 0.0

    return {
        "import_file_id": import_file_id,
        "customs_exchange_rate": customs_rate,
        "commercial_bank_exchange_rate": weighted_bank_rate,
        "fx_variance_rate": fx_variance_rate,
        "fx_variance_total_egp": fx_variance_total_egp,
        "has_variance": abs(fx_variance_total_egp) > 0.01,
        "total_foreign_currency_paid": total_fx,
    }

