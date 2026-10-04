from datetime import date, datetime, timezone
from typing import List, Optional, Dict, Any
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
)
from .repository import (
    generate_settlement_code,
    get_settlement_by_id,
    get_settlement_by_import_file_id,
    list_settlements,
    create_settlement,
    update_settlement,
    soft_delete_settlement,
    restore_settlement,
    get_effective_tax_rate,
)
from .model import WHT_CLEARANCE_SERVICES, WHT_TRANSPORT_SERVICES
from .validators import validate_expense_invoice, validate_items_allocation_readiness
from modules.import_files.model import ImportFile
from modules.common import enum_codes
from modules.common.system_messages import msg, render_en
from modules.common.file_tracking import set_file_tracking


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

def calculate_landed_cost_engine(
    expenses: List[Dict[str, Any]],
    items: List[Dict[str, Any]],
    incoterm: str = "FOB",
) -> Dict[str, Any]:
    """
    Core Landed Cost & Cost Allocation Calculation Engine (BP-038 & BP-039).
    Allocates freight, customs duties, brokerage, local transport, and storage expenses
    across items based on Value, Weight, Volume (CBM), or Equal distribution rules,
    tailored to the Incoterms 2020 rules:
    - FOB / FAS / FCA: Importer pays international freight, insurance, customs duties, and clearance.
    - CIF / CIP: Invoice already covers freight and insurance.
    - CFR / CPT: Invoice already covers freight. Importer pays insurance, customs duties, and clearance.
    - EXW: Importer pays origin trucking/clearance, freight, insurance, customs duties, and local transport.
    - DDP: Exporter covers transport/duties; only exceptional storage or unincluded local charges apply.
    """
    incoterm_normalized = (incoterm or "FOB").upper().strip()

    if not items or len(items) == 0:
        return {
            "incoterm_code": incoterm_normalized,
            "total_fob_egp": 0.0,
            "total_expenses_egp": sum(e.get("amount_egp", 0.0) for e in expenses),
            "total_landed_cost_egp": sum(e.get("amount_egp", 0.0) for e in expenses),
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
        if exp.get("is_seller_paid", False) or exp.get("payer", "").lower() == "seller":
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

            if category in ("Freight", "Shipping", "Ocean Freight", "Air Freight"):
                item["allocated_freight_egp"] += allocated_share
            elif category in ("Customs Duty", "Customs", "Taxes", "VAT", "Import Duty"):
                item["allocated_customs_egp"] += allocated_share
            elif category in ("Brokerage", "Clearance", "Brokerage Fees", "Customs Clearance"):
                item["allocated_clearance_egp"] += allocated_share
            elif category in ("Local Transport", "Transport", "Trucking", "Inland Transport"):
                item["allocated_transport_egp"] += allocated_share
            else:
                item["allocated_other_egp"] += allocated_share

    # Compute final landed cost per item
    for item in items:
        qty = max(item.get("qty", 1), 1)
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

def create_settlement_service(db: Session, schema: FinancialSettlementCreate) -> LandedCostSettlementRecord:
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == schema.import_file_id, ImportFile.is_active == True).first()
    if not imp_file:
        raise HTTPException(status_code=404, detail="ملف الشحنة الاستيرادية المرتكز عليه غير موجود أو محذوف.")

    existing = db.query(LandedCostSettlementRecord).filter(
        LandedCostSettlementRecord.import_file_id == schema.import_file_id,
        LandedCostSettlementRecord.is_active == True,
    ).first()
    if existing:
        raise HTTPException(
            status_code=400,
            detail=f"يوجد بالفعل تسوية مالية وتكلفة وصول (Landed Cost) مسجلة لهذا الملف الاستيرادي (كود التسوية: {existing.settlement_code}). يرجى مراجعة وتحديث التسوية الحالية بدلاً من إنشاء تسوية مكررة.",
        )

    incoterm = (schema.incoterm_code or imp_file.incoterm_code or "FOB").upper()

    # ── Auto-fetch: Customs Duty totals → expense_invoices pre-fill ──────────
    expenses_in = [e if isinstance(e, dict) else e.model_dump() for e in (schema.expense_invoices or [])]
    has_duty_expense = any(
        (e.get("category", "") or "").lower() in ("customs duty", "customs", "import duty", "taxes")
        for e in expenses_in
    )
    if not has_duty_expense:
        try:
            from modules.customs_clearance.model import CustomsClearanceRecord
            clearance = db.query(CustomsClearanceRecord).filter(
                CustomsClearanceRecord.import_file_id == schema.import_file_id,
                CustomsClearanceRecord.is_active == True,
                CustomsClearanceRecord.status == "Final Release Granted",
            ).order_by(CustomsClearanceRecord.customs_clearance_id.desc()).first()
            if clearance and (clearance.actual_duty_total or 0) > 0:
                total_duty = float(clearance.actual_duty_total or clearance.total_duty_payable or 0)
                if total_duty > 0:
                    expenses_in.append({
                        "category": "Customs Duty",
                        "description": f"Customs duties and taxes - declaration {clearance.declaration_46_no or clearance.clearance_code}",
                        "amount_egp": total_duty,
                        "amount_fx": 0.0,
                        "exchange_rate": 1.0,
                        "currency": "EGP",
                        "allocation_rule": "Value-Based",
                        "is_seller_paid": False,
                        "payer": "Importer",
                        "note": "Auto-fetched from the customs clearance record",
                    })
            if clearance and (clearance.lab_service_fees or 0) > 0:
                expenses_in.append({
                    "category": "Clearance",
                    "description": f"Customs service fees - {clearance.clearance_code}",
                    "amount_egp": float(clearance.lab_service_fees),
                    "amount_fx": 0.0,
                    "exchange_rate": 1.0,
                    "currency": "EGP",
                    "allocation_rule": "Value-Based",
                    "is_seller_paid": False,
                    "payer": "Importer",
                    "note": "Customs service fees - auto-fetched",
                })
        except Exception as e:
            import logging
            logging.getLogger(__name__).warning("Auto-fetch customs duty for settlement failed: %s", e)
    schema.expense_invoices = expenses_in

    # ── Auto-populate: item_landed_costs from PO Line Items ────────────────
    items_in = [i if isinstance(i, dict) else i.model_dump() for i in (schema.item_landed_costs or [])]
    if not items_in:
        try:
            from modules.purchase_orders.model import PurchaseOrder, POLineItem
            po_ids_raw = imp_file.po_ids or []
            if isinstance(po_ids_raw, str):
                import json as _json
                po_ids_raw = _json.loads(po_ids_raw) if po_ids_raw else []
            if po_ids_raw:
                po_line_items = db.query(POLineItem).filter(
                    POLineItem.po_id.in_(po_ids_raw),
                    POLineItem.is_active == True,
                ).all()
                for li in po_line_items:
                    items_in.append({
                        "item_code": li.item_code or f"ITEM-{li.line_item_id}",
                        "description": li.item_description or li.item_code or "",
                        "qty": float(li.quantity or 1),
                        "fob_unit_egp": float(li.unit_price_egp or 0),
                        "gross_weight_kg": float(li.gross_weight_kg or 0),
                        "cbm": float(li.total_cbm or 0),
                        "hs_code": li.hs_code or "",
                        "note": "Auto-fetched from the purchase order lines",
                    })
        except Exception as e:
            import logging
            logging.getLogger(__name__).warning("Auto-populate settlement items from PO failed: %s", e)
    schema.item_landed_costs = items_in

    code = generate_settlement_code(db)
    record = create_settlement(db, schema, code)
    record.incoterm_code = incoterm

    # Perform Landed Cost Engine calculation based on Incoterm
    calc_res = calculate_landed_cost_engine(record.expense_invoices, record.item_landed_costs, incoterm=incoterm)
    record.total_fob_egp = calc_res["total_fob_egp"]
    record.total_expenses_egp = calc_res["total_expenses_egp"]
    record.total_landed_cost_egp = calc_res["total_landed_cost_egp"]
    record.average_markup_factor = calc_res["average_markup_factor"]
    record.item_landed_costs = calc_res["item_landed_costs"]
    record.status = "Calculated"

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

    # Lifecycle advance: STEP_19 → STEP_20 (GRN complete → Landed Cost Settlement)
    try:
        from modules.lifecycle_board.service import advance_lifecycle_step_service
        advance_lifecycle_step_service(
            db=db,
            import_file_id=schema.import_file_id,
            completed_step_code="STEP_19",
            target_step_codes=["STEP_20"],
            notes_msg=msg("FS_SETTLEMENT_CREATED", settlement_code=code),
            next_action_msg=msg("NA_REVIEW_SETTLEMENT_AND_CLOSE"),
            stage_code="LANDED_COST_CALCULATED",
            assigned_user="Finance Manager",
        )
    except Exception as e:
        import logging
        logging.getLogger(__name__).warning("Lifecycle advance STEP_19→STEP_20 failed: %s", e)

    try:
        from modules.audit_logs.service import AuditLogService
        AuditLogService(db).log_activity(
            entity_type="LandedCostSettlementRecord",
            entity_id=record.settlement_id,
            entity_code=record.settlement_code,
            action="CREATE",
            new_data=schema.model_dump(exclude_unset=True),
            performed_by=record.accountant_name or "Finance Manager",
        )
    except Exception as e:
        import logging
        logging.getLogger(__name__).warning("AuditLog for LandedCostSettlementRecord create failed: %s", e)

    return record



def recalculate_settlement_service(db: Session, settlement_id: int) -> LandedCostSettlementRecord:
    record = get_settlement_by_id(db, settlement_id)
    if not record:
        raise HTTPException(status_code=404, detail="سجل التسوية المالية غير موجود.")

    incoterm = record.incoterm_code or (record.import_file.incoterm_code if record.import_file else "FOB")
    calc_res = calculate_landed_cost_engine(record.expense_invoices, record.item_landed_costs, incoterm=incoterm)
    record.total_fob_egp = calc_res["total_fob_egp"]
    record.total_expenses_egp = calc_res["total_expenses_egp"]
    record.total_landed_cost_egp = calc_res["total_landed_cost_egp"]
    record.average_markup_factor = calc_res["average_markup_factor"]
    record.item_landed_costs = calc_res["item_landed_costs"]
    record.status = "Calculated"
    record.updated_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(record)
    return record

def update_settlement_service(db: Session, settlement_id: int, schema: FinancialSettlementUpdate) -> LandedCostSettlementRecord:
    existing = get_settlement_by_id(db, settlement_id)
    if not existing:
        raise HTTPException(status_code=404, detail="سجل التسوية المالية غير موجود.")
    update_data = schema.model_dump(exclude_unset=True, exclude_none=True)
    old_data = {k: getattr(existing, k, None) for k in update_data.keys()}

    updated = update_settlement(db, settlement_id, schema)
    recalculated = recalculate_settlement_service(db, settlement_id)

    try:
        from modules.audit_logs.service import AuditLogService
        AuditLogService(db).log_activity(
            entity_type="LandedCostSettlementRecord",
            entity_id=recalculated.settlement_id,
            entity_code=recalculated.settlement_code,
            action="UPDATE",
            old_data=old_data,
            new_data=update_data,
            performed_by=recalculated.accountant_name or "Finance Manager",
        )
    except Exception as e:
        import logging
        logging.getLogger(__name__).warning("AuditLog for LandedCostSettlementRecord update failed: %s", e)

    return recalculated

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

def soft_delete_settlement_service(db: Session, settlement_id: int) -> bool:
    get_settlement_service(db, settlement_id)
    return soft_delete_settlement(db, settlement_id)

def restore_settlement_service(db: Session, settlement_id: int) -> LandedCostSettlementRecord:
    record = restore_settlement(db, settlement_id)
    if not record:
        raise HTTPException(status_code=404, detail=f"سجل التسوية التكليفية رقم {settlement_id} غير موجود.")
    return record


# ==============================================================================
# PL-08: Estimated Landed Cost Simulation Service
# ==============================================================================
from datetime import date
from decimal import Decimal
from .schemas import (
    EstimatedLandedCostSimulationRequest,
    EstimatedLandedCostSimulationResponse,
    EstimatedLandedCostItemBreakdown,
    EstimatedLandedCostExpenseItem,
)

def simulate_estimated_landed_cost_service(
    db: Session,
    import_file_id: int,
    request: Optional[EstimatedLandedCostSimulationRequest] = None,
) -> EstimatedLandedCostSimulationResponse:
    """
    محاكاة واحتساب تكلفة الوصول التقديرية للشحنة وللوحدة الواحدة (PL-08: Estimated Landed Cost Simulation).
    تجمع بين:
    1. قيمة البضاعة التقديرية (FOB).
    2. النولون التقديري (من العرض الفائز في RFQ أو النولون الحكمي 2%).
    3. التأمين البحري التقديري (من الوثيقة أو التأمين الحكمي 2.5%).
    4. الرسوم الجمركية والضرائب ورسوم الخدمات (من محرك التعريفة الجمركية المصري MD-008).
    5. مصاريف الميناء والعتالة والتخليص الجمركي والنقل الداخلي والمصاريف البنكية.
    6. توزيع المصاريف على الأصناف واحتساب تكلفة الوصول للوحدة ومعامل الزيادة Markup %.
    """
    from modules.purchase_orders.model import PurchaseOrder
    from modules.customs_tariff.service import estimate_multi_item_customs_duty_service
    from modules.customs_tariff.schemas import (
        MultiItemCustomsEstimateRequest,
        MultiItemCustomsEstimateLine,
    )
    from modules.freight_quotations.model import FreightRFQRequest, FreightQuotationItem
    from modules.currencies.service import CurrencyService

    req = request or EstimatedLandedCostSimulationRequest()
    calc_date = req.estimate_date or date.today()

    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
    if not imp_file:
        raise HTTPException(
            status_code=404,
            detail=f"ملف الشحنة الاستيرادية رقم {import_file_id} غير موجود.",
        )

    # 1. Fetch Purchase Orders and Items
    pos = (
        db.query(PurchaseOrder)
        .filter(PurchaseOrder.import_file_id == import_file_id, PurchaseOrder.is_active == True)
        .all()
    )

    currency = "USD"
    items_raw = []
    line_no = 1

    for po in pos:
        if po.currency and getattr(po.currency, "currency_code", None):
            currency = po.currency.currency_code
        for itm in (po.line_items or []):
            hs = (itm.tariff.hs_code if getattr(itm, "tariff", None) else getattr(itm, "hs_code", "")) or ""
            hs = hs.strip() if hs else (imp_file.hs_code or "8479.89.90").strip()
            qty = float(itm.quantity or 1.0)
            u_price = float(itm.unit_price or 0.0)
            tot_price = float(itm.total_price or (qty * u_price))
            if tot_price <= 0:
                tot_price = 1000.0
                u_price = tot_price / max(qty, 1.0)

            w_kg = float(getattr(itm, "gross_weight_kg", 0.0) or 0.0)
            cbm_val = float(getattr(itm, "cbm", 0.0) or 0.0)
            origin = (getattr(itm, "country_of_origin", "") or getattr(po, "country_of_origin", "") or "").strip()
            if origin and " - " in origin:
                origin = origin.split(" - ")[0].strip()
            if origin and len(origin) > 2:
                origin = origin[:2]

            items_raw.append({
                "line_no": line_no,
                "item_code": getattr(itm, "item_code", "") or f"ITM-{line_no:03d}",
                "item_name": getattr(itm, "commercial_name", "") or getattr(itm, "item_name", "") or f"Item #{line_no}",
                "hs_code": hs,
                "qty": qty,
                "unit_price_fc": u_price,
                "fob_total_fc": tot_price,
                "weight_kg": w_kg,
                "cbm": cbm_val,
                "origin_country": origin.upper() if origin else None,
            })
            line_no += 1

    # Fallback to invoices or estimated_cost if no items
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
                    "hs_code": (imp_file.hs_code or "8479.89.90").strip(),
                    "qty": 1.0,
                    "unit_price_fc": inv_amt,
                    "fob_total_fc": inv_amt,
                    "weight_kg": 0.0,
                    "cbm": 0.0,
                    "origin_country": None,
                })
                line_no += 1

    if not items_raw:
        cost = float(imp_file.estimated_cost or 10000.0)
        currency = imp_file.estimated_cost_currency or "USD"
        items_raw.append({
            "line_no": 1,
            "item_code": "ITM-001",
            "item_name": getattr(imp_file, "product_category", "") or "General Imported Cargo",
            "hs_code": (imp_file.hs_code or "8479.89.90").strip(),
            "qty": 1.0,
            "unit_price_fc": cost,
            "fob_total_fc": cost,
            "weight_kg": 0.0,
            "cbm": 0.0,
            "origin_country": None,
        })

    # 2. Resolve Exchange Rate
    if req.exchange_rate_override and req.exchange_rate_override > 0:
        fx_rate = float(req.exchange_rate_override)
    else:
        try:
            c_svc = CurrencyService(db)
            r_val, _, _ = c_svc._get_rate_to_egp(currency, rate_type="customs", as_of_date=calc_date)
            fx_rate = float(r_val)
        except Exception:
            fx_rate = 48.5

    total_fob_fc = sum(i["fob_total_fc"] for i in items_raw)
    total_fob_egp = total_fob_fc * fx_rate

    # 3. Resolve Freight (RFQ or Deemed 2%)
    expenses_breakdown: List[EstimatedLandedCostExpenseItem] = []
    has_freight_doc = False
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
                freight_egp = q_cost if q_curr.upper() == "EGP" else (q_cost * fx_rate)
                p_name = getattr(winning_q, "provider_name", None) or getattr(winning_q, "carrier_name", "RFQ Winner")
                freight_src = f"العرض الفائز في مناقصة النولون ({p_name})"
                has_freight_doc = True
            else:
                freight_egp = total_fob_egp * 0.02
                freight_src = "نولون حكمي جمركي (2.0% من قيمة FOB)"
        else:
            freight_egp = total_fob_egp * 0.02
            freight_src = "نولون حكمي جمركي (2.0% من قيمة FOB)"

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

    # 4. Resolve Marine Insurance (2.5% deemed or override)
    has_ins_doc = False
    if req.insurance_amount_egp_override is not None and req.insurance_amount_egp_override >= 0:
        insurance_egp = float(req.insurance_amount_egp_override)
        ins_src = "تعديل يدوي (User Override)"
        has_ins_doc = True
    else:
        insurance_egp = total_fob_egp * 0.025
        ins_src = "تأمين بحري حكمي جمركي (2.5% من قيمة FOB)"

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

    # 5. Call Egyptian Customs Engine (PL-07) for accurate per-item customs & VAT
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
    ]

    calc_req = MultiItemCustomsEstimateRequest(
        currency=currency,
        exchange_rate=Decimal(str(round(fx_rate, 4))),
        insurance_egp=Decimal(str(round(insurance_egp, 2))),
        freight_egp=Decimal(str(round(freight_egp, 2))),
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
        description="ضريبة القيمة المضافة وضريبة الجدول ورسوم الخدمات الجمركية 1%",
        amount_fc=round((total_vat_egp + total_schedule_tax_egp + total_service_fee_egp) / fx_rate, 2),
        currency="EGP",
        amount_egp=round(total_vat_egp + total_schedule_tax_egp + total_service_fee_egp, 2),
        is_estimated=True,
        source="مصلحة الضرائب المصرية وقانون القيمة المضافة",
        allocation_rule="Direct HS Code Allocation",
    ))

    # 6. Additional Logistics & Clearance Expenses
    clearance_fee = float(req.clearance_fees_egp_override) if req.clearance_fees_egp_override is not None else 4500.0
    port_handling = float(req.port_handling_egp_override) if req.port_handling_egp_override is not None else 5000.0
    inland_trucking = float(req.inland_transport_egp_override) if req.inland_transport_egp_override is not None else 7500.0
    bank_fees = float(req.bank_fees_egp_override) if req.bank_fees_egp_override is not None else 2500.0
    other_fees = float(req.other_expenses_egp_override) if req.other_expenses_egp_override is not None else 2000.0

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

    # Map line-level customs results
    customs_line_map = {l.line_no: l for l in customs_breakdown.lines}

    for itm in items_raw:
        l_no = itm["line_no"]
        c_line = customs_line_map.get(l_no)

        fob_item_egp = itm["fob_total_fc"] * fx_rate
        qty = max(itm["qty"], 1.0)
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

    # Executive Summary in Arabic
    customs_pct = round((total_taxes_and_fees_egp / total_expenses * 100.0), 1) if total_expenses > 0 else 0.0
    freight_pct = round(((freight_egp + insurance_egp) / total_expenses * 100.0), 1) if total_expenses > 0 else 0.0

    summary_ar = (
        f"تبلغ تكلفة الوصول التقديرية الإجمالية للشحنة {total_landed_cost_egp:,.2f} جنيه مصري "
        f"({total_landed_cost_fc:,.2f} {currency}) مقارنة بقيمة البضاعة FOB البالغة {total_fob_egp:,.2f} جنيه، "
        f"بمتوسط معامل زيادة {avg_markup_factor:.3f} (أي بنسبة زيادة إجمالية قدرها {avg_markup_pct:.1f}%). "
        f"تشكل الضرائب والرسوم الجمركية النسبة الأكبر من المصاريف المضافة ({customs_pct}%)، "
        f"بينما يمثل النولون والتأمين البحري ({freight_pct}%)، والباقي موزع بين مصاريف الموانئ والتخليص والنقل الداخلي."
    )

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
        total_customs_and_taxes_egp=round(total_taxes_and_fees_egp, 2),
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
    )


# ==============================================================================
# CLO-01: Final Settlement Invoices Aggregation Services
# ==============================================================================

def resolve_wht_rate_percent(db: Session, tax_code: str, on_date: Optional[date] = None) -> float:
    """Withholding tax rate (percent) of ``tax_code`` valid on ``on_date`` (default today), read from the
    effective-dated ``tax_rates`` table. No configured rate -> 0 (nothing deducted)."""
    target = on_date or datetime.now(timezone.utc).date()
    record = get_effective_tax_rate(db, tax_code, target)
    return float(record.rate_percent) if record is not None else 0.0


def wht_amount_for(amount_egp: float, rate_percent: float) -> float:
    return round(amount_egp * rate_percent / 100.0, 2)


def aggregate_shipment_invoices_service(
    db: Session,
    import_file_id: int,
) -> InvoicesAggregationResponse:
    """
    CLO-01: Multi-Source Invoice Aggregation Engine.
    Scans all operational modules (Commercial Invoices, Freight Bookings, Cargo Insurance,
    Customs Declaration 46, Clearance Invoices CL-05, Inland Transport TR-01, Demurrage TR-02/TR-05,
    and Warehouse Discrepancies TR-03/TR-04) to assemble a unified multi-party settlement ledger.
    """
    from modules.freight_booking.model import ShipmentBooking
    from modules.cargo_insurance.model import CargoInsuranceCertificate
    from modules.customs_clearance.model import CustomsClearanceRecord, ClearanceExpenseInvoice
    from modules.inland_transport.model import InlandTransportBooking
    from modules.demurrage_detention.model import DemurrageTracking
    from modules.warehouse_receiving.model import WarehouseReceivingRecord

    imp = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
    if not imp:
        raise HTTPException(status_code=404, detail="ملف الشحنة غير موجود")

    currency = imp.estimated_cost_currency or "USD"
    base_exchange_rate = 48.5

    invoices: List[AggregatedInvoiceItemSchema] = []

    # 1. Commercial Goods Invoices (FOB / CIF from PO & Invoices Data)
    invoices_data = imp.invoices_data or []
    if invoices_data and isinstance(invoices_data, list):
        for idx, inv in enumerate(invoices_data):
            inv_no = str(inv.get("invoice_no") or inv.get("invoice_number") or f"COMM-{imp.import_file_code}-{idx+1}")
            inv_date = str(inv.get("invoice_date") or (imp.file_opening_date or ""))
            c_curr = str(inv.get("currency") or currency)
            c_rate = float(inv.get("exchange_rate") or (1.0 if c_curr == "EGP" else base_exchange_rate))
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
        amt_egp = round(amt_fc * base_exchange_rate if currency != "EGP" else amt_fc, 2)
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
            exchange_rate=base_exchange_rate if currency != "EGP" else 1.0,
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

    # 2. Freight Bookings (Ocean / Air Freight)
    bookings = db.query(ShipmentBooking).filter(
        ShipmentBooking.import_file_id == import_file_id,
        ShipmentBooking.is_active == True
    ).all()
    for b in bookings:
        amt_usd = float(b.total_freight_cost_usd or 0.0)
        if amt_usd > 0:
            amt_egp = round(amt_usd * base_exchange_rate, 2)
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
                exchange_rate=base_exchange_rate,
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
        CargoInsuranceCertificate.import_file_id == import_file_id
    ).all()
    for c in certs:
        prem = float(c.total_payable_premium or 0.0)
        if prem > 0:
            c_rate = float(c.exchange_rate or 1.0) if c.currency != "EGP" else 1.0
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
        CustomsClearanceRecord.import_file_id == import_file_id
    ).all()
    has_customs_inv = False
    for cl in clearances:
        c_duty = float(cl.duty_paid_amount or cl.total_duty_payable or 0.0)
        if c_duty > 0:
            has_customs_inv = True
            paid = float(cl.duty_paid_amount or 0.0)
            rem = max(0.0, (float(cl.total_duty_payable or c_duty)) - paid)
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

        # Delivery order fees
        if cl.delivery_order_fees and cl.delivery_order_fees > 0:
            do_fees = float(cl.delivery_order_fees)
            is_do_paid = (cl.delivery_order_status or "").lower() in ("paid and received", "paid & received", "paid", "مسدد")
            do_paid = do_fees if is_do_paid else 0.0
            do_rem = max(0.0, do_fees - do_paid)
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
                exchange_rate=1.0,
                amount_fc=do_fees,
                amount_egp=do_fees,
                paid_amount_egp=do_paid,
                remaining_amount_egp=do_rem,
                payment_status=do_stat,
                payment_reference=cl.delivery_order_payment_ref or cl.delivery_order_number or "إيصال التوكيل",
                withholding_tax_rate=0.0,
                withholding_tax_amount_egp=0.0,
                net_payable_egp=do_fees,
                source_module="Delivery Order (CS-02)",
                notes="رسوم ومصاريف إذن تسليم الشحنة",
            ))

    if not has_customs_inv and imp.customs_duty_paid_amount and imp.customs_duty_paid_amount > 0:
        c_duty = float(imp.customs_duty_paid_amount)
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

    # 5. Clearance Invoices (CL-05: ClearanceExpenseInvoice)
    cl_invoices = db.query(ClearanceExpenseInvoice).filter(
        ClearanceExpenseInvoice.import_file_id == import_file_id,
        ClearanceExpenseInvoice.is_active == True
    ).all()
    has_broker_inv = False
    for cl_inv in cl_invoices:
        has_broker_inv = True
        amt = float(cl_inv.amount_egp or (cl_inv.amount_fx * (cl_inv.exchange_rate or 1.0)))
        is_p = (cl_inv.payment_status or "").lower() in ("paid", "مسدد")
        is_part = "part" in (cl_inv.payment_status or "").lower()
        paid = float(cl_inv.net_payable_egp if is_p else (cl_inv.net_payable_egp * 0.5 if is_part else 0.0))
        rem = max(0.0, float(cl_inv.net_payable_egp or amt) - paid)
        # WHT rate valid on the invoice date (tax_rates table); a stored wht_amount always wins.
        wht_rate = (
            resolve_wht_rate_percent(
                db, WHT_CLEARANCE_SERVICES, cl_inv.invoice_date.date() if cl_inv.invoice_date else None
            )
            if cl_inv.wht_deducted
            else 0.0
        )
        wht_amt = float(cl_inv.wht_amount or (wht_amount_for(amt, wht_rate) if cl_inv.wht_deducted else 0.0))
        net = float(cl_inv.net_payable_egp or (amt - wht_amt))

        invoices.append(AggregatedInvoiceItemSchema(
            invoice_id=f"BROKER-{cl_inv.invoice_id}",
            invoice_no=cl_inv.invoice_number or cl_inv.invoice_code,
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
            exchange_rate=float(cl_inv.exchange_rate or 1.0),
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
        wht_rate = resolve_wht_rate_percent(db, WHT_CLEARANCE_SERVICES)
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
        amt = float(tr.transport_fare_egp or 0.0)
        if amt > 0:
            has_trans_inv = True
            wht_rate = resolve_wht_rate_percent(
                db, WHT_TRANSPORT_SERVICES, tr.booking_date.date() if tr.booking_date else None
            )
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
        wht_rate = resolve_wht_rate_percent(
            db, WHT_TRANSPORT_SERVICES, imp.inland_departure_date.date() if imp.inland_departure_date else None
        )
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
            d_rate = float(d.exchange_rate or 50.0)
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

    warnings: List[str] = []
    for inv in invoices:
        if inv.remaining_amount_egp > 0:
            warnings.append(
                f"مستحق غير مسدد لصالح [{inv.party_name}]: {inv.remaining_amount_egp:,.2f} جنيه (فاتورة {inv.invoice_no})"
            )

    return InvoicesAggregationResponse(
        import_file_id=imp.import_file_id,
        import_file_code=imp.import_file_code or f"IMP-{imp.import_file_id}",
        supplier_name=imp.supplier_name or "المورد الأجنبي",
        currency=currency,
        exchange_rate=round(base_exchange_rate, 4),
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
    )


def confirm_invoices_settlement_service(
    db: Session,
    payload: ConfirmInvoicesSettlementRequest,
) -> ConfirmInvoicesSettlementResponse:
    """
    CLO-01: Confirms and locks the aggregated invoices for the Import File.
    - Updates ImportFile status, progress to >= 98.5%, and financial settlement summary.
    - Closes SmartTask TSK-0901.
    - Creates and dispatches downstream SmartTask TSK-0902 for Landed Cost Engine allocation (CLO-02).
    - Emits a central high-priority SystemNotification.
    """
    from modules.smart_tasks.model import SmartTask
    from modules.notifications.model import SystemNotification

    imp = db.query(ImportFile).filter(ImportFile.import_file_id == payload.import_file_id).first()
    if not imp:
        raise HTTPException(status_code=404, detail="ملف الشحنة غير موجود")

    if payload.invoices_overrides and len(payload.invoices_overrides) > 0:
        invoices = payload.invoices_overrides
    else:
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
        (SmartTask.task_code.ilike("%0901%") | SmartTask.title.ilike("%تسوية الفواتير%") | SmartTask.title.ilike("%فواتير%"))
    ).all()
    for t in tasks_901:
        t.status = "Completed"
        t.is_auto_closed = True
        t.notes = f"Invoices settlement and reconciliation approved by {payload.settled_by} on {today_str}"

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
            assigned_user=payload.settled_by or "Cost Accounting Specialist",
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
        settled_by=payload.settled_by,
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
    imp = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
    if not imp:
        raise HTTPException(status_code=404, detail=f"ملف الشحنة رقم {import_file_id} غير موجود")

    req = request or ActualLandedCostCalculationRequest()
    pref = req.allocation_preference or "Value-Based"

    # 1. Fetch simulation estimates (PL-08) for baseline comparison
    try:
        sim = simulate_estimated_landed_cost_service(db, import_file_id)
    except Exception:
        sim = None

    # 2. Fetch all aggregated actual invoices
    agg = aggregate_shipment_invoices_service(db, import_file_id)
    all_invoices = agg.invoices
    currency = agg.currency or "USD"
    exchange_rate = agg.exchange_rate or 48.5

    # Separate FOB Goods from other Expenses
    goods_invoices = [inv for inv in all_invoices if "goods" in inv.category.lower() or "fob" in inv.category.lower() or "commercial" in inv.category.lower()]
    expense_invoices = [inv for inv in all_invoices if inv not in goods_invoices]

    # Calculate actual FOB from goods invoices, or fallback to simulation / estimated_cost
    if goods_invoices:
        actual_total_fob_egp = sum(inv.amount_egp for inv in goods_invoices)
    elif sim and sim.total_fob_egp > 0:
        actual_total_fob_egp = sim.total_fob_egp
    else:
        actual_total_fob_egp = float(imp.estimated_cost or 0.0) * exchange_rate

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

    # Estimated numbers from simulation
    est_total_fob = sim.total_fob_egp if sim else actual_total_fob_egp
    est_freight = sim.total_freight_egp if sim else 0.0
    est_ins = sim.total_insurance_egp if sim else 0.0
    est_taxes = sim.total_customs_and_taxes_egp if sim else 0.0
    est_duty = est_taxes * 0.4 if sim else 0.0 # estimated split
    est_vat = est_taxes * 0.6 if sim else 0.0
    est_clearance = sim.total_clearance_and_port_egp if sim else 0.0
    est_transport = sim.total_inland_transport_egp if sim else 0.0
    est_demurrage = 0.0 # usually 0 planned
    est_other = sim.total_other_expenses_egp if sim else 0.0

    est_total_expenses = sim.total_expenses_egp if sim else (est_freight + est_ins + est_taxes + est_clearance + est_transport + est_other)
    est_total_landed = sim.total_landed_cost_egp if sim else (est_total_fob + est_total_expenses)
    est_markup = sim.average_markup_factor if sim else 1.0

    # Build Categories Breakdown
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

    categories_breakdown: List[ActualLandedCostCategoryBreakdown] = []
    for c_key, c_data in cat_expenses.items():
        est_val = cat_est_map.get(c_key, 0.0)
        act_val = c_data["actual"]
        v_egp = round(act_val - est_val, 2)
        v_pct = round((v_egp / est_val * 100.0), 2) if est_val > 0 else (100.0 if act_val > 0 else 0.0)
        
        # Determine allocation rule for category
        rule = "Value-Based"
        if req.custom_category_allocation and c_key in req.custom_category_allocation:
            rule = req.custom_category_allocation[c_key]
        elif c_key in ["Freight", "Demurrage & Storage"]:
            rule = "Volume-Based" if pref in ["Volume-Based", "Weight-Based"] else pref
        elif c_key in ["Inland Transport"]:
            rule = "Weight-Based" if pref in ["Weight-Based", "Volume-Based"] else pref

        categories_breakdown.append(ActualLandedCostCategoryBreakdown(
            category=c_key,
            category_ar=c_data["ar"],
            estimated_egp=round(est_val, 2),
            actual_egp=round(act_val, 2),
            variance_egp=v_egp,
            variance_pct=v_pct,
            invoices_count=c_data["count"],
            allocation_rule=rule,
        ))

    # 3. Extract items to allocate across: Prefer POLineItem directly if available
    items_raw = []
    from modules.purchase_orders.model import PurchaseOrder, POLineItem
    po_lines = db.query(POLineItem).join(PurchaseOrder).filter(
        PurchaseOrder.import_file_id == import_file_id,
        PurchaseOrder.is_active == True,
    ).all()

    sim_map = {}
    if sim and sim.items_breakdown:
        sim_map = {s.item_code: s for s in sim.items_breakdown}

    if po_lines:
        for idx, pl in enumerate(po_lines):
            qty = float(pl.quantity or 1.0)
            u_p = float(pl.unit_price or 0.0)
            tot_p = float(pl.total_price or (qty * u_p))
            fob_tot_egp = tot_p * exchange_rate
            fob_u_egp = fob_tot_egp / qty if qty > 0 else 0.0

            s_match = sim_map.get(pl.item_code)
            est_u = float(s_match.unit_landed_cost_egp) if s_match else (fob_u_egp * est_markup)

            items_raw.append({
                "line_no": idx + 1,
                "item_code": pl.item_code or f"ITM-{idx+1:03d}",
                "item_name": pl.description_ar or pl.description_en or f"Item #{idx+1}",
                "hs_code": (pl.tariff.hs_code if pl.tariff else getattr(pl, "hs_code", "")) or imp.hs_code or "8479.89.90",
                "qty": qty,
                "fob_unit_egp": fob_u_egp,
                "fob_total_egp": fob_tot_egp,
                "gross_weight_kg": float(pl.gross_weight_kg or 100.0),
                "cbm": float(pl.total_cbm or 0.5),
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
                "gross_weight_kg": 100.0,
                "cbm": 0.5,
                "estimated_unit_landed_cost_egp": float(s_itm.unit_landed_cost_egp or 0.0),
            })
    else:
        # Fallback to single general cargo item
        items_raw.append({
            "line_no": 1,
            "item_code": "ITM-001",
            "item_name": imp.product_category or "بضائع استيرادية عامة",
            "hs_code": imp.hs_code or "8479.89.90",
            "qty": 1.0,
            "fob_unit_egp": actual_total_fob_egp,
            "fob_total_egp": actual_total_fob_egp,
            "gross_weight_kg": 100.0,
            "cbm": 1.0,
            "estimated_unit_landed_cost_egp": est_total_landed,
        })

    total_items_fob = sum(i["fob_total_egp"] for i in items_raw)
    total_items_wt = sum(i["gross_weight_kg"] for i in items_raw)
    total_items_cbm = sum(i["cbm"] for i in items_raw)
    n_items = len(items_raw)

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
        qty = max(itm["qty"], 1.0)
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

    # Executive Summary in Arabic
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

    return ActualLandedCostCalculationResponse(
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
    )


def approve_actual_landed_cost_service(
    db: Session,
    payload: ApproveActualLandedCostRequest,
) -> ApproveActualLandedCostResponse:
    """
    CLO-02: Approves and finalizes the Actual Landed Cost calculation for the Import File.
    - Synchronizes item landed costs and total landed cost to LandedCostSettlementRecord.
    - Updates ImportFile status to 'COST_ALLOCATED', sets actual landed cost KPIs, and advances progress >= 99.0%.
    - Resolves SmartTask TSK-0902.
    - Dispatches downstream SmartTask TSK-0903 for Final Dossier Dossier Export (CLO-03).
    - Emits central SystemNotification.
    """
    from modules.smart_tasks.model import SmartTask
    from modules.notifications.model import SystemNotification

    imp = db.query(ImportFile).filter(ImportFile.import_file_id == payload.import_file_id).first()
    if not imp:
        raise HTTPException(status_code=404, detail="ملف الشحنة غير موجود")

    # Run calculation
    calc_req = ActualLandedCostCalculationRequest(
        allocation_preference=payload.allocation_preference,
        custom_category_allocation=payload.custom_category_allocation,
    )
    calc = calculate_actual_landed_cost_service(db, payload.import_file_id, calc_req)

    now_utc = datetime.now(timezone.utc)
    today_str = str(now_utc.date())

    # 1. Update or create LandedCostSettlementRecord
    settlement = db.query(LandedCostSettlementRecord).filter(
        LandedCostSettlementRecord.import_file_id == imp.import_file_id,
        LandedCostSettlementRecord.is_active == True,
    ).first()

    items_json = [itm.model_dump() for itm in calc.items_breakdown]
    expenses_json = [c.model_dump() for c in calc.categories_breakdown]

    if not settlement:
        code = generate_settlement_code(db)
        settlement = LandedCostSettlementRecord(
            settlement_code=code,
            import_file_id=imp.import_file_id,
            incoterm_code=calc.incoterm,
            expense_invoices=expenses_json,
            total_fob_egp=calc.actual_total_fob_egp,
            total_expenses_egp=calc.actual_total_expenses_egp,
            total_landed_cost_egp=calc.actual_total_landed_cost_egp,
            average_markup_factor=calc.actual_markup_factor,
            item_landed_costs=items_json,
            status="Approved",
            accountant_name=payload.approved_by,
            notes=payload.notes,
            created_by=payload.approved_by,
            created_at=now_utc,
            updated_at=now_utc,
        )
        db.add(settlement)
        db.flush()
    else:
        settlement.incoterm_code = calc.incoterm
        settlement.expense_invoices = expenses_json
        settlement.total_fob_egp = calc.actual_total_fob_egp
        settlement.total_expenses_egp = calc.actual_total_expenses_egp
        settlement.total_landed_cost_egp = calc.actual_total_landed_cost_egp
        settlement.average_markup_factor = calc.actual_markup_factor
        settlement.item_landed_costs = items_json
        settlement.status = "Approved"
        settlement.accountant_name = payload.approved_by
        if payload.notes:
            settlement.notes = f"{settlement.notes or ''}\n{payload.notes}".strip()
        settlement.updated_at = now_utc

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
        t.notes = f"Actual landed cost calculated and approved by {payload.approved_by} on {today_str}"

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
            assigned_user=payload.approved_by or "Cost Accounting Manager",
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
        approved_by=payload.approved_by,
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

    # 6. Advance lifecycle board step
    try:
        from modules.lifecycle_board.service import advance_lifecycle_step_service
        advance_lifecycle_step_service(
            db=db,
            import_file_id=imp.import_file_id,
            completed_step_code="STEP_20",
            target_step_codes=["STEP_21"],
            notes_msg=msg("FS_LANDED_COST_APPROVED", settlement_code=settlement.settlement_code),
            next_action_msg=msg("NA_CLO_EXPORT_DOSSIER"),
            assigned_user=payload.approved_by,
        )
    except Exception as e:
        import logging
        logging.getLogger(__name__).warning("Lifecycle advance STEP_20->STEP_21 notice: %s", e)

    set_file_tracking(imp, next_action=msg("NA_CLO_EXPORT_DOSSIER"))
    db.commit()
    db.refresh(imp)
    db.refresh(settlement)

    return ApproveActualLandedCostResponse(
        success=True,
        import_file_id=imp.import_file_id,
        import_file_code=imp.import_file_code or f"IMP-{imp.import_file_id}",
        settlement_id=settlement.settlement_id,
        settlement_code=settlement.settlement_code,
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

