from datetime import datetime, timezone
from typing import List, Optional, Dict, Any
from sqlalchemy.orm import Session
from fastapi import HTTPException

from .model import ImportFileClosureRecord
from .schemas import (
    FileClosureCreate,
    FileClosureUpdate,
    DossierSectionSummary,
    ComprehensiveShipmentDossierResponse,
    DossierExportConfirmRequest,
    DossierExportConfirmResponse,
    ClosurePrecheckResponse,
    OfficialClosureCertificateResponse,
)
from .repository import (
    generate_closure_code,
    get_closure_by_id,
    get_closure_by_import_file_id,
    list_closures,
    create_closure,
    update_closure,
    soft_delete_closure,
    restore_closure,
)
from .validators import validate_closure_checklist
from modules.import_files.model import ImportFile
from modules.smart_tasks.model import SmartTask
from modules.notifications.model import SystemNotification
from modules.common.system_messages import msg, render_en
from modules.common.file_tracking import set_file_tracking

def close_import_file_service(db: Session, schema: FileClosureCreate) -> ImportFileClosureRecord:
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == schema.import_file_id, ImportFile.is_active == True).first()
    if not imp_file:
        raise HTTPException(status_code=404, detail="ملف الشحنة الاستيرادية المرتكز عليه غير موجود أو محذوف.")

    checklist_dict = {k: v for k, v in schema.closure_checklist.model_dump().items() if v is not None}
    completed_count = sum(1 for v in checklist_dict.values() if v)
    total_items = len(checklist_dict) if checklist_dict else 5
    progress_percent = (completed_count / total_items) * 100.0 if total_items > 0 else 0.0

    # ── DB-Enforced Closure Validation (for non-draft final closure) ─────────
    if not schema.is_draft:
        validate_closure_checklist(checklist_dict, getattr(imp_file, 'skipped_stages', None))

        db_errors = []

        # 1. Verify customs clearance has Final Release Granted
        try:
            from modules.customs_clearance.model import CustomsClearanceRecord
            clearance = db.query(CustomsClearanceRecord).filter(
                CustomsClearanceRecord.import_file_id == schema.import_file_id,
                CustomsClearanceRecord.is_active == True,
                CustomsClearanceRecord.status == "Final Release Granted",
            ).first()
            if not clearance and not (imp_file.skipped_stages and "STEP_17" in (imp_file.skipped_stages or [])):
                db_errors.append("لم يتم إتمام التخليص الجمركي النهائي (Final Release Granted) لهذا الملف.")
        except Exception:
            pass

        # 2. Verify at least one GRN exists
        try:
            from modules.warehouse_receiving.model import WarehouseReceivingRecord
            grn = db.query(WarehouseReceivingRecord).filter(
                WarehouseReceivingRecord.import_file_id == schema.import_file_id,
                WarehouseReceivingRecord.is_active == True,
            ).first()
            if not grn and not (imp_file.skipped_stages and "STEP_19" in (imp_file.skipped_stages or [])):
                db_errors.append("لم يتم إصدار إذن إضافة (GRN) لاستلام البضاعة في المخزن.")
        except Exception:
            pass

        # 3. Verify financial settlement exists and is calculated
        try:
            from modules.financial_settlement.model import LandedCostSettlementRecord
            settlement = db.query(LandedCostSettlementRecord).filter(
                LandedCostSettlementRecord.import_file_id == schema.import_file_id,
                LandedCostSettlementRecord.is_active == True,
                LandedCostSettlementRecord.status.in_(["Calculated", "Approved", "Closed"]),
            ).first()
            actual_landed = getattr(imp_file, 'actual_landed_cost_total_egp', 0.0) or 0.0
            fin_status = getattr(imp_file, 'financial_settlement_status', '') or ''
            if not settlement and actual_landed <= 0 and fin_status not in ["SETTLED", "COST_ALLOCATED"] and not (imp_file.skipped_stages and "STEP_20" in (imp_file.skipped_stages or [])):
                db_errors.append("لم يتم إنشاء أو اعتماد تسوية التكلفة الاستيرادية الشاملة (Landed Cost Settlement).")
        except Exception:
            pass

        if db_errors:
            raise HTTPException(
                status_code=400,
                detail="لا يمكن إغلاق الملف نهائياً — المتطلبات التالية غير مستوفاة:\n" + "\n".join(f"• {e}" for e in db_errors)
            )

    existing_record = get_closure_by_import_file_id(db, schema.import_file_id)
    if existing_record:
        existing_record.closure_checklist = checklist_dict
        existing_record.auditor_name = schema.auditor_name
        existing_record.archive_location = schema.archive_location
        existing_record.archival_notes = schema.archival_notes
        existing_record.status = "Draft" if schema.is_draft else "Closed"
        record = existing_record
    else:
        code = generate_closure_code(db)
        record = create_closure(db, schema, code)
        record.status = "Draft" if schema.is_draft else "Closed"

    if schema.is_draft:
        imp_file.current_module = "Phase 10 - Import File Closure & Historical Archive (Draft)"
        set_file_tracking(imp_file, stage_code="CLOSURE_IN_PROGRESS", next_action=msg("NA_CLO_COMPLETE_CHECKLIST"))
    else:
        # Set ImportFile to 100% progress and status Closed
        imp_file.status = "Closed"
        imp_file.current_module = "Phase 10 - Import File Closure & Historical Archive"
        imp_file.progress_percent = 100.0
        set_file_tracking(imp_file, stage_code="ARCHIVED_CLOSED", next_action=msg("NA_FILE_ARCHIVED_READ_ONLY"))
        imp_file.closed_at = datetime.now(timezone.utc)

        # Auto-complete pending closure SmartTasks
        try:
            pending_tasks = db.query(SmartTask).filter(
                SmartTask.import_file_id == schema.import_file_id,
                SmartTask.is_active == True,
                SmartTask.status.in_(["Pending", "In-Progress", "Under Review"]),
            ).all()
            for t in pending_tasks:
                if (
                    "TSK-0904" in (t.task_code or "")
                    or "CLO-04" in (t.title or "")
                    or "إغلاق" in (t.title or "")
                    or "أرشفة" in (t.title or "")
                ):
                    t.status = "Completed"
                    t.completed_at = datetime.now(timezone.utc)
                    t.result_notes = f"Official closure and digital archiving completed under certificate {record.closure_code}"
        except Exception as e:
            import logging
            logging.getLogger(__name__).warning("Auto-completing closure smart tasks failed: %s", e)

        # Dispatch System Notification
        try:
            notif_msg = msg(
                "CLO_FILE_CLOSED",
                import_file_code=imp_file.import_file_code,
                closure_code=record.closure_code,
                archive_location=schema.archive_location,
            )
            notif = SystemNotification(
                title=render_en(notif_msg.code, notif_msg.params, "title"),
                message=render_en(notif_msg.code, notif_msg.params, "body"),
                msg_code=notif_msg.code,
                msg_params=notif_msg.params,
                severity="INFO",
                category="FILE_CLOSURE",
                entity_type="ImportFile",
                entity_id=schema.import_file_id,
                target_role="ALL",
            )
            db.add(notif)
        except Exception as e:
            import logging
            logging.getLogger(__name__).warning("Dispatching closure notification failed: %s", e)

        # Advance lifecycle board to 100% completion (STEP_21)
        try:
            from modules.lifecycle_board.service import advance_lifecycle_step_service
            advance_lifecycle_step_service(
                db=db,
                import_file_id=schema.import_file_id,
                completed_step_code="STEP_21",
                target_step_codes=[],
                notes_msg=msg(
                    "CLO_FILE_CLOSED",
                    closure_code=record.closure_code,
                    auditor_name=schema.auditor_name or "Finance Manager",
                ),
                next_action_msg=msg("NA_FILE_ARCHIVED_READ_ONLY"),
                stage_code="ARCHIVED_CLOSED",
                assigned_user=schema.auditor_name or "Finance Manager",
            )
        except Exception as e:
            import logging
            logging.getLogger(__name__).warning("Lifecycle advance STEP_21 failed: %s", e)

        # Enforce terminal next_action after lifecycle board call
        set_file_tracking(imp_file, stage_code="ARCHIVED_CLOSED", next_action=msg("NA_FILE_ARCHIVED_READ_ONLY"))
        imp_file.current_module = "Phase 10 - Import File Closure & Historical Archive"

        # KB-GUIDE-012 Section 5A: Autonomous Reference Engine Continuous Learning Trigger
        try:
            from modules.experience_guide.service import ExperienceGuideService
            ExperienceGuideService.run_autonomous_learning(db=db, trigger_import_file_id=imp_file.import_file_id)
        except Exception as e:
            import logging
            logging.getLogger(__name__).warning("Autonomous learning engine trigger on file closure failed: %s", e)
        imp_file.status = "Closed"
        imp_file.progress_percent = 100.0

    db.commit()
    db.refresh(record)

    return record


def get_closure_service(db: Session, closure_id: int) -> ImportFileClosureRecord:
    record = get_closure_by_id(db, closure_id)
    if not record:
        raise HTTPException(status_code=404, detail="سجل إغلاق وأرشفة الملف غير موجود.")
    return record

def list_closures_service(
    db: Session,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    search: Optional[str] = None,
) -> List[ImportFileClosureRecord]:
    return list_closures(db, include_inactive, import_file_id, search)

def update_closure_service(db: Session, closure_id: int, schema: FileClosureUpdate) -> ImportFileClosureRecord:
    get_closure_service(db, closure_id)
    updated = update_closure(db, closure_id, schema)
    if not updated:
        raise HTTPException(status_code=404, detail="فشل تحديث سجل الإغلاق.")
    return updated

def soft_delete_closure_service(db: Session, closure_id: int) -> bool:
    get_closure_service(db, closure_id)
    return soft_delete_closure(db, closure_id)

def restore_closure_service(db: Session, closure_id: int) -> ImportFileClosureRecord:
    record = restore_closure(db, closure_id)
    if not record:
        raise HTTPException(status_code=404, detail=f"سجل أرشفة وإغلاق الملف رقم {closure_id} غير موجود.")
    return record


# ==============================================================================
# CLO-03: Comprehensive Shipment Dossier Aggregation & Export Confirmation
# ==============================================================================

def get_comprehensive_shipment_dossier_service(
    db: Session,
    import_file_id: int,
) -> ComprehensiveShipmentDossierResponse:
    """
    CLO-03: Aggregates all operational, documentation, logistics, customs, warehouse,
    and financial settlement records across all 10 phases into a single comprehensive dossier.
    """
    imp = db.query(ImportFile).filter(
        ImportFile.import_file_id == import_file_id,
        ImportFile.is_active == True,
    ).first()
    if not imp:
        raise HTTPException(
            status_code=404,
            detail=f"ملف الشحنة الاستيرادية رقم {import_file_id} غير موجود أو محذوف.",
        )

    # 1. Party details
    company_name = (
        getattr(imp.company, "importer_name", None)
        or getattr(imp.company, "company_name", None)
        or getattr(imp, "company_name", None)
        or "شركة الاستيراد المصرية"
    )
    supplier_name = (
        getattr(imp.supplier, "company_name", None)
        or getattr(imp.supplier, "supplier_name", None)
        or getattr(imp, "supplier_name", None)
        or "المورد الأجنبي"
    )

    # 2. Purchase Orders & Line Items
    from modules.purchase_orders.model import PurchaseOrder
    pos = (
        db.query(PurchaseOrder)
        .filter(
            PurchaseOrder.import_file_id == import_file_id,
            PurchaseOrder.is_active == True,
        )
        .all()
    )

    po_summaries = []
    items_detail = []
    total_fob_fc = 0.0
    fob_currency = "USD"

    for po in pos:
        curr = po.currency.currency_code if getattr(po, "currency", None) else "USD"
        fob_currency = curr
        amt = float(po.total_amount_fob or 0.0)
        total_fob_fc += amt
        po_summaries.append({
            "po_id": po.po_id,
            "po_number": po.po_number,
            "po_reference": po.po_reference,
            "proforma_invoice_number": po.proforma_invoice_number,
            "currency": curr,
            "exchange_rate": float(po.exchange_rate or 1.0),
            "total_amount_fob": amt,
            "total_packages": int(po.total_packages_count or 0),
            "total_gross_weight_kg": float(po.total_gross_weight_kg or 0.0),
            "total_cbm": float(po.total_cbm or 0.0),
            "status": po.status,
        })

        for itm in (po.line_items or []):
            hs = (itm.tariff.hs_code if getattr(itm, "tariff", None) else getattr(itm, "hs_code", "")) or (imp.hs_code or "")
            qty = float(itm.quantity or 0.0)
            u_price = float(itm.unit_price or 0.0)
            tot_price = float(itm.total_price or (qty * u_price))
            items_detail.append({
                "item_code": itm.item_code or f"ITM-{len(items_detail)+1:03d}",
                "description": itm.description_ar or itm.description_en or itm.main_description or "بند استيرادي",
                "quantity": qty,
                "unit_of_measure": itm.unit_of_measure or "PCS",
                "unit_price": u_price,
                "total_price": tot_price,
                "hs_code": hs,
                "cbm": float(itm.total_cbm or 0.0),
                "weight_kg": float(itm.gross_weight_kg or 0.0),
            })

    # Fallback to estimated cost if no PO items found
    if total_fob_fc == 0.0 and getattr(imp, "estimated_cost", 0.0):
        total_fob_fc = float(imp.estimated_cost or 0.0)
        fob_currency = imp.estimated_cost_currency or "USD"

    # 3. Customs Clearance Record
    from modules.customs_clearance.model import CustomsClearanceRecord
    clearance = (
        db.query(CustomsClearanceRecord)
        .filter(
            CustomsClearanceRecord.import_file_id == import_file_id,
            CustomsClearanceRecord.is_active == True,
        )
        .order_by(CustomsClearanceRecord.customs_clearance_id.desc())
        .first()
    )

    broker_name = (
        (clearance.broker_name if clearance and clearance.broker_name else None)
        or getattr(imp.customs_broker, "provider_name", None)
        or getattr(imp.customs_broker, "name", None)
        or getattr(imp, "broker_name", None)
        or "مكتب التخليص المعتمد"
    )

    customs_declaration_no = (clearance.declaration_46_no if clearance else None) or imp.form46_no
    customs_channel = clearance.channel_type if clearance else None
    customs_office = (clearance.customs_office_name if clearance else None) or "ميناء الدخيلة / الإسكندرية"
    customs_duty_amount = float(clearance.import_duty_amount or 0.0) if clearance else 0.0
    vat_amount = float(clearance.vat_amount or 0.0) if clearance else 0.0
    schedule_tax_amount = float(clearance.schedule_tax_amount or 0.0) if clearance else 0.0
    total_customs_paid = float(
        (clearance.duty_paid_amount or clearance.total_duty_payable)
        if clearance
        else (imp.customs_duty_paid_amount or 0.0)
    )
    customs_release_permit_no = (clearance.release_permit_no if clearance else None) or imp.customs_release_permit_no
    customs_released_at_str = (
        clearance.release_date.isoformat()
        if clearance and clearance.release_date
        else (imp.customs_released_at.isoformat() if imp.customs_released_at else None)
    )

    # 4. Inland Transport Booking
    from modules.inland_transport.model import InlandTransportBooking
    inland = (
        db.query(InlandTransportBooking)
        .filter(
            InlandTransportBooking.import_file_id == import_file_id,
            InlandTransportBooking.is_active == True,
        )
        .order_by(InlandTransportBooking.transport_id.desc())
        .first()
    )

    inland_carrier = (inland.carrier_name if inland else None) or imp.inland_carrier_name
    inland_truck = (inland.truck_plate_number if inland else None) or imp.inland_truck_plate_no
    inland_driver = (inland.driver_name if inland else None) or imp.inland_driver_name
    inland_arrival_str = (
        inland.actual_arrival_at.isoformat()
        if inland and inland.actual_arrival_at
        else (imp.inland_actual_arrival_date.isoformat() if imp.inland_actual_arrival_date else None)
    )

    # 5. Warehouse Receiving Record
    from modules.warehouse_receiving.model import WarehouseReceivingRecord
    wh = (
        db.query(WarehouseReceivingRecord)
        .filter(WarehouseReceivingRecord.import_file_id == import_file_id)
        .order_by(WarehouseReceivingRecord.receiving_id.desc())
        .first()
    )
    wh_grn_code = wh.grn_code if wh else None
    wh_name = wh.warehouse_name if wh else "المستودع الرئيسي - القاهرة"
    wh_acc_qty = int(wh.total_accepted_qty or 0) if wh else 0
    wh_short_qty = int(wh.total_shortage_qty or 0) if wh else 0
    wh_dam_qty = int(wh.total_damaged_qty or 0) if wh else 0

    # 6. Landed Cost Settlement Record
    from modules.financial_settlement.model import LandedCostSettlementRecord
    settlement = (
        db.query(LandedCostSettlementRecord)
        .filter(
            LandedCostSettlementRecord.import_file_id == import_file_id,
            LandedCostSettlementRecord.is_active == True,
        )
        .order_by(LandedCostSettlementRecord.settlement_id.desc())
        .first()
    )

    fin_status = (settlement.status if settlement else None) or imp.financial_settlement_status
    inv_count = len(settlement.expense_invoices or []) if settlement else 0
    fin_expenses_egp = float(settlement.total_expenses_egp or 0.0) if settlement else 0.0
    actual_landed_egp = float(
        (settlement.total_landed_cost_egp if settlement else None)
        or imp.actual_landed_cost_total_egp
        or 0.0
    )
    markup_fac = float(
        (settlement.average_markup_factor if settlement else None)
        or imp.actual_landed_cost_markup_factor
        or 1.0
    )
    var_egp = float(imp.actual_landed_cost_variance_egp or 0.0)
    var_pct = float(imp.actual_landed_cost_variance_pct or 0.0)
    calc_at = imp.actual_landed_cost_calculated_at or (settlement.updated_at if settlement else None)
    total_fob_egp = float(settlement.total_fob_egp or 0.0) if settlement else (total_fob_fc * 48.5)

    # 7. 10-Phase Sections Dossier
    sections = [
        DossierSectionSummary(
            section_code="SEC-01",
            section_name_en="Phase 1 & 2: Commercial Contract & PO",
            section_name_ar="أمر الشراء والتوريد والتعاقد الخارجي",
            status="COMPLETED" if pos or total_fob_fc > 0 else "PENDING",
            status_ar="مكتمل" if pos or total_fob_fc > 0 else "قيد الانتظار",
            details={
                "po_count": len(pos),
                "total_fob_fc": total_fob_fc,
                "currency": fob_currency,
                "items_count": len(items_detail),
                "incoterm": imp.incoterm_code or "FOB",
            },
        ),
        DossierSectionSummary(
            section_code="SEC-02",
            section_name_en="Phase 3: Advance Cargo Information (ACID)",
            section_name_ar="التسجيل المسبق للشحنات نافذة ACID",
            status="COMPLETED" if imp.acid_number else "PENDING",
            status_ar="مكتمل ومسجل" if imp.acid_number else "معلق",
            details={
                "acid_number": imp.acid_number,
                "issue_date": str(imp.acid_issue_date or ""),
                "expiry_date": str(imp.acid_expiry_date or ""),
            },
        ),
        DossierSectionSummary(
            section_code="SEC-03",
            section_name_en="Phase 4: Banking Form 4 & Financing",
            section_name_ar="التمويل المصرفي ونموذج 4 وسويفت",
            status="COMPLETED" if imp.form4_no or imp.form4_received_date or imp.swift_no else "PENDING",
            status_ar="معتمد بنكياً" if imp.form4_no or imp.form4_received_date or imp.swift_no else "غير مكتمل",
            details={
                "form4_no": imp.form4_no,
                "form4_date": str(imp.form4_received_date or imp.form4_request_date or ""),
                "swift_no": imp.swift_no,
            },
        ),
        DossierSectionSummary(
            section_code="SEC-04",
            section_name_en="Phase 5: International Freight & Ocean Shipping",
            section_name_ar="الشحن الدولي والخط الملاحي وبوليصة الشحن",
            status="COMPLETED" if imp.bl_number or imp.booking_no or imp.vessel_name else "PENDING",
            status_ar="مشحون ومؤكد" if imp.bl_number or imp.booking_no or imp.vessel_name else "قيد الانتظار",
            details={
                "bl_number": imp.bl_number,
                "booking_no": imp.booking_no,
                "vessel_name": imp.vessel_name,
                "port_of_loading": imp.port_of_loading,
                "port_of_discharge": imp.port_of_discharge,
            },
        ),
        DossierSectionSummary(
            section_code="SEC-05",
            section_name_en="Phase 6: Customs Clearance & Form 46",
            section_name_ar="التخليص الجمركي ونموذج 46 والإفراج النهائي",
            status="COMPLETED" if (clearance and clearance.release_permit_no) or imp.customs_release_permit_no or imp.is_customs_released else ("IN_PROGRESS" if clearance or imp.form46_no else "PENDING"),
            status_ar="مفرج عنه نهائياً" if (clearance and clearance.release_permit_no) or imp.customs_release_permit_no or imp.is_customs_released else ("جاري التخليص" if clearance or imp.form46_no else "معلق"),
            details={
                "declaration_46_no": customs_declaration_no,
                "channel": customs_channel,
                "customs_office": customs_office,
                "release_permit_no": customs_release_permit_no,
                "total_customs_paid": total_customs_paid,
            },
        ),
        DossierSectionSummary(
            section_code="SEC-06",
            section_name_en="Phase 7: Inland Trucking & Delivery",
            section_name_ar="النقل الداخلي وتوصيل الشاحنات للمخزن",
            status="COMPLETED" if inland_arrival_str or imp.inland_transport_status in ["ARRIVED", "COMPLETED"] else ("IN_PROGRESS" if inland or imp.inland_transport_status == "IN_TRANSIT" else "PENDING"),
            status_ar="تم الوصول والتسليم" if inland_arrival_str or imp.inland_transport_status in ["ARRIVED", "COMPLETED"] else ("جاري النقل" if inland or imp.inland_transport_status == "IN_TRANSIT" else "معلق"),
            details={
                "carrier_name": inland_carrier,
                "truck_plate": inland_truck,
                "driver_name": inland_driver,
                "arrival_date": inland_arrival_str,
            },
        ),
        DossierSectionSummary(
            section_code="SEC-07",
            section_name_en="Phase 8: Warehouse Receiving & GRN",
            section_name_ar="فحص واستلام المستودع وإذن الإضافة GRN",
            status="COMPLETED" if wh else "PENDING",
            status_ar="مستلم بالكامل (GRN)" if wh else "معلق",
            details={
                "grn_code": wh_grn_code,
                "warehouse_name": wh_name,
                "accepted_qty": wh_acc_qty,
                "shortage_qty": wh_short_qty,
                "damaged_qty": wh_dam_qty,
            },
        ),
        DossierSectionSummary(
            section_code="SEC-08",
            section_name_en="Phase 8/9: Empty Container Return & EIR",
            section_name_ar="إعادة الحاويات الفارغة وإيصالات EIR",
            status="COMPLETED" if imp.empty_containers_returned_at or imp.empty_containers_return_status == "ALL_RETURNED" else "PENDING",
            status_ar="تمت الإعادة واستلام EIR" if imp.empty_containers_returned_at or imp.empty_containers_return_status == "ALL_RETURNED" else "معلق",
            details={
                "returned_at": imp.empty_containers_returned_at.isoformat() if imp.empty_containers_returned_at else None,
                "eir_numbers": imp.empty_containers_eir_numbers,
                "depot_name": imp.empty_containers_depot_name,
            },
        ),
        DossierSectionSummary(
            section_code="SEC-09",
            section_name_en="Phase 9: Multi-Party Invoices & Actual Landed Cost",
            section_name_ar="الفواتير متعددة الأطراف وتكلفة الوصول الفعلية",
            status="COMPLETED" if (settlement and settlement.status in ["Calculated", "Approved", "Closed"]) or imp.financial_settlement_status == "COST_ALLOCATED" else "IN_PROGRESS",
            status_ar="معتمد وموزع" if (settlement and settlement.status in ["Calculated", "Approved", "Closed"]) or imp.financial_settlement_status == "COST_ALLOCATED" else "قيد الاحتساب",
            details={
                "settlement_status": fin_status,
                "invoices_count": inv_count,
                "actual_landed_cost_total_egp": actual_landed_egp,
                "markup_factor": markup_fac,
                "variance_pct": var_pct,
            },
        ),
        DossierSectionSummary(
            section_code="SEC-10",
            section_name_en="Phase 10: Shipment Dossier & Final Archive",
            section_name_ar="الملف الشامل والأرشفة الرقمية والإغلاق الرسمي",
            status="COMPLETED" if imp.dossier_exported_at else "IN_PROGRESS",
            status_ar="مصدّر وجاهز للأرشفة" if imp.dossier_exported_at else "جاهز للتصدير والمراجعة",
            details={
                "exported_at": imp.dossier_exported_at.isoformat() if imp.dossier_exported_at else None,
                "exported_by": imp.dossier_exported_by,
            },
        ),
    ]

    closure_readiness = {
        "docs_verified": bool(imp.acid_number and (imp.form4_no or imp.swift_no)),
        "customs_cleared": bool(imp.is_customs_released or (clearance and clearance.release_permit_no) or imp.customs_release_permit_no),
        "warehouse_received": bool(wh is not None),
        "eir_returned": bool(imp.empty_containers_returned_at is not None or imp.empty_containers_return_status == "ALL_RETURNED"),
        "landed_cost_settled": bool(actual_landed_egp > 0 and (imp.financial_settlement_status == "COST_ALLOCATED" or (settlement and settlement.status in ["Calculated", "Approved", "Closed"]))),
        "tasks_closed": True,
    }

    summary_notes = (
        f"ملف الشحنة {imp.import_file_code} مستوفي لكافة مراحل الاستيراد العشر. "
        f"قيمة البضاعة FOB تبلغ {total_fob_fc:,.2f} {fob_currency}، "
        f"وتكلفة الوصول الفعلية الشاملة تبلغ {actual_landed_egp:,.2f} جنيه مصري بمعامل زيادة {markup_fac:.3f}x. "
        f"الملف جاهز للأرشفة الرقمية والاعتماد النهائي."
    )

    return ComprehensiveShipmentDossierResponse(
        import_file_id=imp.import_file_id,
        import_file_code=imp.import_file_code or f"IMP-{imp.import_file_id}",
        custom_file_number=imp.custom_file_number,
        status=imp.status,
        current_stage=imp.current_stage,
        current_module=imp.current_module,
        progress_percent=float(imp.progress_percent or 0.0),
        next_action=imp.next_action or render_en("NA_CLO_EXPORT_DOSSIER", {}, "action"),
        owner=imp.owner,
        created_at=imp.created_at,
        updated_at=imp.updated_at,
        dossier_exported_at=imp.dossier_exported_at,
        dossier_exported_by=imp.dossier_exported_by,
        company_id=imp.company_id,
        company_name=company_name,
        supplier_id=imp.supplier_id,
        supplier_name=supplier_name,
        broker_id=imp.customs_broker_id if hasattr(imp, "customs_broker_id") else None,
        broker_name=broker_name,
        shipment_mode=imp.shipment_mode or "Sea FCL",
        incoterm_code=imp.incoterm_code or "FOB",
        shipment_category=imp.shipment_category or "New Purchase",
        priority=imp.priority or "High",
        commodity=imp.product_category or imp.notes,
        port_of_loading=imp.port_of_loading,
        port_of_discharge=imp.port_of_discharge,
        total_packages=int(getattr(imp, "total_packages_count", 0) or sum(p.get("total_packages", 0) for p in po_summaries) or 0),
        gross_weight_kg=float(getattr(imp, "gross_weight_kg", 0.0) or sum(p.get("total_gross_weight_kg", 0.0) for p in po_summaries) or 0.0),
        net_weight_kg=float(getattr(imp, "net_weight_kg", 0.0) or sum(float(itm.get("weight_kg", 0.0) or 0.0) for itm in items_detail) or 0.0),
        total_cbm=float(getattr(imp, "total_cbm", 0.0) or sum(p.get("total_cbm", 0.0) for p in po_summaries) or 0.0),
        target_free_days=int(imp.target_free_days or 21),
        purchase_orders=po_summaries,
        total_fob_fc=total_fob_fc,
        total_fob_egp=total_fob_egp,
        fob_currency=fob_currency,
        items_count=len(items_detail),
        items_detail=items_detail,
        acid_number=imp.acid_number,
        acid_issue_date=str(imp.acid_issue_date) if imp.acid_issue_date else None,
        acid_expiry_date=str(imp.acid_expiry_date) if imp.acid_expiry_date else None,
        form4_no=imp.form4_no,
        form4_date=str(imp.form4_received_date or imp.form4_request_date) if (imp.form4_received_date or imp.form4_request_date) else None,
        swift_no=imp.swift_no,
        form46_no=imp.form46_no,
        form46_date=imp.form46_date.isoformat() if imp.form46_date else None,
        form46_status=imp.form46_status,
        cargox_envelope_id=str(imp.cargox_envelope_id) if imp.cargox_envelope_id else None,
        cargox_transferred_at=imp.cargox_transferred_at.isoformat() if imp.cargox_transferred_at else None,
        customs_declaration_no=customs_declaration_no,
        customs_channel=customs_channel,
        customs_office=customs_office,
        customs_duty_amount=customs_duty_amount,
        vat_amount=vat_amount,
        schedule_tax_amount=schedule_tax_amount,
        total_customs_paid=total_customs_paid,
        customs_release_permit_no=customs_release_permit_no,
        customs_released_at=customs_released_at_str,
        inland_carrier_name=inland_carrier,
        inland_truck_plate_no=inland_truck,
        inland_driver_name=inland_driver,
        inland_actual_arrival_date=inland_arrival_str,
        warehouse_grn_code=wh_grn_code,
        warehouse_name=wh_name,
        warehouse_accepted_qty=wh_acc_qty,
        warehouse_shortage_qty=wh_short_qty,
        warehouse_damaged_qty=wh_dam_qty,
        empty_containers_returned_at=imp.empty_containers_returned_at.isoformat() if imp.empty_containers_returned_at else None,
        empty_containers_eir_numbers=imp.empty_containers_eir_numbers,
        financial_settlement_status=fin_status,
        financial_settlement_invoices_count=inv_count,
        financial_settlement_total_egp=fin_expenses_egp,
        actual_landed_cost_total_egp=actual_landed_egp,
        actual_landed_cost_markup_factor=markup_fac,
        actual_landed_cost_variance_egp=var_egp,
        actual_landed_cost_variance_pct=var_pct,
        actual_landed_cost_calculated_at=calc_at,
        sections=sections,
        closure_readiness=closure_readiness,
        summary_notes=summary_notes,
    )


def confirm_dossier_export_service(
    db: Session,
    payload: DossierExportConfirmRequest,
) -> DossierExportConfirmResponse:
    """
    CLO-03: Confirms the export of the comprehensive shipment dossier, records export metadata,
    advances progress to >=99.5%, resolves SmartTask TSK-0903, dispatches TSK-0904, and posts system notification.
    """
    imp = db.query(ImportFile).filter(
        ImportFile.import_file_id == payload.import_file_id,
        ImportFile.is_active == True,
    ).first()
    if not imp:
        raise HTTPException(
            status_code=404,
            detail=f"ملف الشحنة الاستيرادية رقم {payload.import_file_id} غير موجود أو محذوف.",
        )

    now_utc = datetime.now(timezone.utc)
    today_str = datetime.now().strftime("%Y-%m-%d")

    # 1. Update ImportFile metadata & progress
    imp.dossier_exported_at = now_utc
    imp.dossier_exported_by = payload.exported_by
    current_progress = float(imp.progress_percent or 0.0)
    imp.progress_percent = max(current_progress, 99.5)
    imp.current_module = "Phase 10 - Comprehensive Dossier Export & Digital Archiving"
    set_file_tracking(imp, stage_code="CLOSURE_IN_PROGRESS", next_action=msg("NA_CLO_OFFICIAL_CLOSURE"))

    # 2. Resolve SmartTask TSK-0903
    tasks_903 = db.query(SmartTask).filter(
        SmartTask.import_file_id == imp.import_file_id,
        (SmartTask.task_code.ilike("%0903%") | SmartTask.title.ilike("%الملف الشامل%") | SmartTask.title.ilike("%CLO-03%"))
    ).all()
    for t in tasks_903:
        t.status = "Completed"
        t.is_auto_closed = True
        t.notes = f"Full dossier exported and approved as {payload.export_format} by {payload.exported_by} on {today_str}"

    # 3. Dispatch downstream SmartTask TSK-0904
    task_code_904 = f"TSK-0904-{imp.import_file_id}"
    existing_904 = db.query(SmartTask).filter(SmartTask.task_code == task_code_904).first()
    if not existing_904:
        task_msg = msg(
            "CLO_TASK_OFFICIAL_CLOSURE",
            import_file_code=imp.import_file_code,
            export_format=payload.export_format,
        )
        new_task = SmartTask(
            task_code=task_code_904,
            title=render_en(task_msg.code, task_msg.params, "title"),
            description=render_en(task_msg.code, task_msg.params, "body"),
            msg_code=task_msg.code,
            msg_params=task_msg.params,
            step_code="STEP_21",
            task_type="System Generated",
            import_file_id=imp.import_file_id,
            import_file_code=imp.import_file_code,
            phase_name="Stage 10: Import File Closure & Archival",
            assigned_user=payload.exported_by or "Internal Auditor / Finance Director",
            priority="High",
            reminder_type="Final Closure",
            due_date=today_str,
            status="Pending",
        )
        db.add(new_task)

    # 4. Dispatch central SystemNotification
    notif_msg = msg(
        "CLO_DOSSIER_EXPORTED",
        import_file_code=imp.import_file_code,
        exported_by=payload.exported_by,
        export_format=payload.export_format,
    )
    notif = SystemNotification(
        title=render_en(notif_msg.code, notif_msg.params, "title"),
        message=render_en(notif_msg.code, notif_msg.params, "body"),
        msg_code=notif_msg.code,
        msg_params=notif_msg.params,
        severity="INFO",
        category="FILE_CLOSURE",
        entity_type="ImportFile",
        entity_id=imp.import_file_id,
        target_role="ALL",
    )
    db.add(notif)

    # 5. Lifecycle advance STEP_20 -> STEP_21
    try:
        from modules.lifecycle_board.service import advance_lifecycle_step_service
        advance_lifecycle_step_service(
            db=db,
            import_file_id=imp.import_file_id,
            completed_step_code="STEP_20",
            target_step_codes=["STEP_21"],
            notes_msg=msg("CLO_DOSSIER_EXPORTED", export_format=payload.export_format, exported_by=payload.exported_by),
            next_action_msg=msg("NA_CLO_OFFICIAL_CLOSURE"),
            assigned_user=payload.exported_by,
        )
    except Exception as e:
        import logging
        logging.getLogger(__name__).warning("Lifecycle advance STEP_20->STEP_21 notice: %s", e)

    # Enforce next_action after lifecycle board call
    set_file_tracking(imp, next_action=msg("NA_CLO_OFFICIAL_CLOSURE"))

    db.commit()
    db.refresh(imp)

    return DossierExportConfirmResponse(
        success=True,
        import_file_id=imp.import_file_id,
        import_file_code=imp.import_file_code or f"IMP-{imp.import_file_id}",
        dossier_exported_at=imp.dossier_exported_at,
        dossier_exported_by=imp.dossier_exported_by,
        progress_percent=imp.progress_percent,
        current_stage=imp.current_stage,
        current_module=imp.current_module,
        next_task_code=task_code_904,
        next_task_title=render_en("CLO_TASK_OFFICIAL_CLOSURE", {}, "title"),
        message=f"تم تصدير واعتماد الملف الشامل للشحنة {imp.import_file_code} بنجاح وإطلاق مهمة الإغلاق النهائي والأرشفة (CLO-04).",
    )


# ==============================================================================
# CLO-04: Official File Closure & Digital Archive Services
# ==============================================================================

def get_closure_precheck_service(db: Session, import_file_id: int) -> ClosurePrecheckResponse:
    """
    CLO-04: Live audit gate checking the 6 core pillars before official file closure.
    """
    imp = db.query(ImportFile).filter(
        ImportFile.import_file_id == import_file_id,
        ImportFile.is_active == True,
    ).first()
    if not imp:
        raise HTTPException(
            status_code=404,
            detail=f"ملف الشحنة الاستيرادية رقم {import_file_id} غير موجود أو محذوف.",
        )

    company_name = (
        getattr(imp.company, "importer_name", None)
        or getattr(imp.company, "company_name", None)
        or getattr(imp, "company_name", None)
        or "شركة الاستيراد المصرية"
    )
    supplier_name = (
        getattr(imp.supplier, "company_name", None)
        or getattr(imp.supplier, "supplier_name", None)
        or getattr(imp, "supplier_name", None)
        or "المورد الأجنبي"
    )

    skipped = set(imp.skipped_stages or [])

    blocking_reasons: List[str] = []
    warnings: List[str] = []
    checklist_status: Dict[str, bool] = {}

    # 1. Customs Final Release Check
    customs_ok = False
    try:
        from modules.customs_clearance.model import CustomsClearanceRecord
        clearance = db.query(CustomsClearanceRecord).filter(
            CustomsClearanceRecord.import_file_id == import_file_id,
            CustomsClearanceRecord.is_active == True,
            CustomsClearanceRecord.status == "Final Release Granted",
        ).first()
        if clearance or getattr(imp, "customs_release_permit_no", None) or getattr(imp, "customs_released_at", None):
            customs_ok = True
    except Exception:
        if getattr(imp, "customs_release_permit_no", None) or getattr(imp, "customs_released_at", None):
            customs_ok = True

    if any(s in skipped for s in ["STEP_13", "STEP_14", "STEP_17"]):
        customs_ok = True

    checklist_status["customs_cleared"] = customs_ok
    if not customs_ok:
        blocking_reasons.append("لم يتم استخراج الإفراج الجمركي النهائي للرسالة (Customs Final Release Permit).")

    # 2. Warehouse Receiving / GRN Check
    warehouse_ok = False
    try:
        from modules.warehouse_receiving.model import WarehouseReceivingRecord
        grn = db.query(WarehouseReceivingRecord).filter(
            WarehouseReceivingRecord.import_file_id == import_file_id,
            WarehouseReceivingRecord.is_active == True,
        ).first()
        if grn or getattr(imp, "warehouse_grn_code", None) or getattr(imp, "actual_arrival_date", None):
            warehouse_ok = True
    except Exception:
        if getattr(imp, "warehouse_grn_code", None) or getattr(imp, "actual_arrival_date", None):
            warehouse_ok = True

    if "STEP_19" in skipped:
        warehouse_ok = True

    checklist_status["warehouse_received"] = warehouse_ok
    if not warehouse_ok:
        blocking_reasons.append("لم يتم تسجيل استلام الشحنة بالمخزن وإصدار إذن إضافة (Warehouse GRN).")

    # 3. Actual Landed Cost Settled Check
    landed_ok = False
    actual_landed = float(getattr(imp, 'actual_landed_cost_total_egp', 0.0) or 0.0)
    markup = float(getattr(imp, 'actual_landed_cost_markup_factor', 1.0) or 1.0)
    fin_status = getattr(imp, 'financial_settlement_status', '') or ''
    try:
        from modules.financial_settlement.model import LandedCostSettlementRecord
        settlement = db.query(LandedCostSettlementRecord).filter(
            LandedCostSettlementRecord.import_file_id == import_file_id,
            LandedCostSettlementRecord.is_active == True,
            LandedCostSettlementRecord.status.in_(["Calculated", "Approved", "Closed"]),
        ).first()
        if settlement or actual_landed > 0 or fin_status in ["SETTLED", "COST_ALLOCATED"]:
            landed_ok = True
            if settlement:
                actual_landed = float(getattr(settlement, "total_landed_cost_egp", None) or getattr(settlement, "actual_total_cost_egp", None) or actual_landed)
                markup = float(getattr(settlement, "average_markup_factor", None) or getattr(settlement, "actual_markup_factor", None) or markup)
    except Exception:
        if actual_landed > 0 or fin_status in ["SETTLED", "COST_ALLOCATED"]:
            landed_ok = True

    if "STEP_20" in skipped:
        landed_ok = True

    checklist_status["landed_cost_settled"] = landed_ok
    if not landed_ok:
        blocking_reasons.append("لم يتم احتساب واعتماد تسوية التكلفة الاستيرادية الشاملة (Actual Landed Cost Settled).")

    # 4. Comprehensive Dossier Export Check (CLO-03)
    dossier_ok = imp.dossier_exported_at is not None
    checklist_status["dossier_exported"] = dossier_ok
    if not dossier_ok:
        blocking_reasons.append("لم يتم تصدير واعتماد الملف الشامل للرسالة (Comprehensive Shipment Dossier Export - CLO-03).")

    # 5. Empty Containers Returned Check (TR-05)
    shipment_mode = (imp.shipment_mode or "SEA").upper()
    containers_ok = True
    if shipment_mode in ["AIR", "LAND", "TRUCK"]:
        containers_ok = True
    else:
        has_containers = False
        try:
            from modules.container_tracking.model import ContainerTrackingRecord
            containers = db.query(ContainerTrackingRecord).filter(
                ContainerTrackingRecord.import_file_id == import_file_id,
                ContainerTrackingRecord.is_active == True,
            ).all()
            if containers:
                has_containers = True
                all_returned = all(
                    c.status in ["Returned", "Closed", "EIR Confirmed"]
                    or c.actual_return_date is not None
                    for c in containers
                )
                containers_ok = all_returned
        except Exception:
            pass

        if getattr(imp, "empty_containers_returned_at", None) or getattr(imp, "empty_containers_eir_numbers", None):
            containers_ok = True

        if has_containers and not containers_ok:
            warnings.append("يوجد حاويات لم يتم تسجيل إيصال تسليمها الفارغ (EIR Return) — يرجى التأكد لتجنب غرامات التأخير.")

    checklist_status["empty_containers_returned"] = containers_ok

    # 6. Documentation verification
    docs_ok = bool(imp.acid_number or getattr(imp, 'form46_no', None) or getattr(imp, 'form4_no', None) or getattr(imp, 'cargox_envelope_id', None))
    checklist_status["docs_verified"] = docs_ok
    if not docs_ok:
        warnings.append("مستندات الشحن الأصلية غير مكتملة أو لم يتم التحقق منها بالكامل.")

    # 7. Operational Tasks Closed Check
    tasks_ok = True
    try:
        pending_tasks = db.query(SmartTask).filter(
            SmartTask.import_file_id == import_file_id,
            SmartTask.is_active == True,
            SmartTask.status.in_(["Pending", "In-Progress", "Under Review"]),
        ).all()
        blocking_tasks = [
            t for t in pending_tasks
            if "0904" not in (t.task_code or "")
            and "CLO-04" not in (t.title or "")
            and "إغلاق" not in (t.title or "")
        ]
        if blocking_tasks:
            warnings.append(f"يوجد عدد {len(blocking_tasks)} مهام تشغيلية لم تكتمل بعد ولكن سيتم أرشفة الملف وإغلاقها آلياً.")
    except Exception:
        pass

    checklist_status["tasks_closed"] = tasks_ok

    can_close = len(blocking_reasons) == 0
    preview_code = f"CLR-{datetime.now().year}-{imp.import_file_id:04d}"

    return ClosurePrecheckResponse(
        import_file_id=imp.import_file_id,
        import_file_code=imp.import_file_code or f"IMP-{imp.import_file_id}",
        company_name=company_name,
        supplier_name=supplier_name,
        can_close=can_close,
        blocking_reasons=blocking_reasons,
        warnings=warnings,
        checklist_status=checklist_status,
        actual_landed_cost_egp=actual_landed,
        actual_markup_factor=markup,
        dossier_exported_at=imp.dossier_exported_at,
        dossier_exported_by=imp.dossier_exported_by,
        empty_containers_returned_at=getattr(imp, "empty_containers_returned_at", None),
        certificate_code_preview=preview_code,
    )


def official_close_import_file_service(
    db: Session,
    schema: FileClosureCreate,
) -> OfficialClosureCertificateResponse:
    """
    CLO-04: Formal closure & digital archival.
    Issues digital certificate, locks file at 100%, and advances lifecycle board to terminal STEP_21.
    """
    schema.is_draft = False
    record = close_import_file_service(db, schema)

    imp = db.query(ImportFile).filter(
        ImportFile.import_file_id == schema.import_file_id,
    ).first()

    company_name = (
        getattr(imp.company, "importer_name", None)
        or getattr(imp.company, "company_name", None)
        or getattr(imp, "company_name", None)
        or "شركة الاستيراد المصرية"
    )
    supplier_name = (
        getattr(imp.supplier, "company_name", None)
        or getattr(imp.supplier, "supplier_name", None)
        or getattr(imp, "supplier_name", None)
        or "المورد الأجنبي"
    )

    return OfficialClosureCertificateResponse(
        success=True,
        closure_id=record.closure_id,
        closure_code=record.closure_code,
        import_file_id=imp.import_file_id,
        import_file_code=imp.import_file_code or f"IMP-{imp.import_file_id}",
        company_name=company_name,
        supplier_name=supplier_name,
        auditor_name=record.auditor_name or "Finance & Audit Controller",
        archive_location=record.archive_location or "Central Digital Archive Vault",
        archival_notes=record.archival_notes,
        closed_at=imp.closed_at or datetime.now(timezone.utc),
        status=imp.status or "Closed",
        progress_percent=float(imp.progress_percent or 100.0),
        current_stage=imp.current_stage or "Archived & Closed",
        current_module=imp.current_module or "Phase 10 - Import File Closure & Historical Archive",
        next_action=imp.next_action or "File Archived - Read-Only Historical State",
        message=f"تم إغلاق ملف الشحنة {imp.import_file_code} رسمياً بنجاح بنسبة إنجاز 100%، وتم إصدار شهادة الإغلاق والأرشفة الرقمية {record.closure_code}.",
    )


