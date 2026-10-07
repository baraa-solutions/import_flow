import logging
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from fastapi import HTTPException, Response
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from modules.common.pagination import PageParams

from .model import WarehouseReceivingRecord
from .schemas import (
    WarehouseReceivingCreate,
    WarehouseReceivingUpdate,
    DiscrepancyReportSubmit,
    WarehouseInspectionSubmit,
    InspectionSummaryResponse,
    WarehouseDispatchValidationResponse,
)
from .repository import (
    generate_grn_code,
    get_warehouse_receiving_by_id,
    get_active_grn_for_file,
    get_warehouse_receiving_list,
    paginate_warehouse_receivings as repo_paginate_warehouse_receivings,
    add_warehouse_receiving,
    apply_changes,
    set_active,
)
from .validators import (
    coded_error,
    ensure_file_open,
    validate_seal_integrity,
    validate_discrepancy_claim,
    validate_grn_lines,
    normalize_verdict,
    validate_verdict_consistency,
    validate_verdict_matches,
    validate_status_label,
    validate_discrepancy_type,
    validate_customs_release,
    validate_grn_deletable,
    WR_VERDICT_CODES,
)
from modules.import_files.model import ImportFile
# Module-level so the tables are registered whenever GRNs are (the GRN create syncs both in one transaction).
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.demurrage_detention.model import DemurrageTracking
from modules.inland_transport.model import InlandTransportBooking
from modules.common.errors import best_effort
from modules.common.system_messages import msg, render_en
from modules.common.file_tracking import set_file_tracking

logger = logging.getLogger(__name__)

DEFAULT_INSPECTION_COMMITTEE = "Technical & Warehouse Receiving Inspection Committee"
OPEN_TASK_STATUSES = ("Pending", "In Progress", "In-Progress")


def _grn_exists_error(grn_code: str) -> HTTPException:
    return coded_error(
        409,
        "WR_GRN_EXISTS",
        (
            f"يوجد بالفعل إذن استلام مخزني نشط لهذا الملف الاستيرادي (رقم الإذن: {grn_code}). "
            "يرجى مراجعة وتحديث الإذن الحالي بدلاً من إنشاء إذن مكرر."
        ),
        grn_code=grn_code,
    )


def _line_totals(items: List[Dict[str, Any]]) -> Dict[str, int]:
    return {
        "total_invoiced_qty": sum(int(i.get("invoiced_qty", 0) or 0) for i in items),
        "total_accepted_qty": sum(int(i.get("accepted_qty", 0) or 0) for i in items),
        "total_shortage_qty": sum(int(i.get("shortage_qty", 0) or 0) for i in items),
        "total_damaged_qty": sum(int(i.get("damaged_qty", 0) or 0) for i in items),
    }


def _create_discrepancy_type(totals: Dict[str, int]) -> str:
    """GRN create: Shortage > Damage > Excess > None (Shortage wins even when there is damage too)."""
    if totals["total_shortage_qty"] > 0:
        return "Shortage"
    if totals["total_damaged_qty"] > 0:
        return "Damage"
    if totals["total_accepted_qty"] > totals["total_invoiced_qty"]:
        return "Excess"
    return "None"


def _insert_grn(db: Session, values: Dict[str, Any]) -> WarehouseReceivingRecord:
    """Insert with a fresh GRN code; one retry when a concurrent insert took the same code (unique constraint).
    The GRN is the first write of the request, so the rollback before the retry loses nothing."""
    try:
        return add_warehouse_receiving(db, {**values, "grn_code": generate_grn_code(db)})
    except IntegrityError:
        db.rollback()
        return add_warehouse_receiving(db, {**values, "grn_code": generate_grn_code(db)})


def _require_open_file_for_grn(db: Session, import_file_id: int) -> None:
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
    if imp_file:
        ensure_file_open(imp_file)


def create_warehouse_receiving_service(
    db: Session,
    schema: WarehouseReceivingCreate,
    user: str = "System",
) -> WarehouseReceivingRecord:
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == schema.import_file_id, ImportFile.is_active == True).first()
    if not imp_file:
        raise HTTPException(status_code=404, detail="ملف الشحنة الاستيرادية المرتكز عليه غير موجود أو محذوف.")
    ensure_file_open(imp_file)

    clearance = db.query(CustomsClearanceRecord).filter(
        CustomsClearanceRecord.import_file_id == schema.import_file_id,
        CustomsClearanceRecord.is_active == True,
    ).order_by(CustomsClearanceRecord.customs_clearance_id.desc()).first()

    validate_customs_release(imp_file, clearance)

    existing = get_active_grn_for_file(db, schema.import_file_id)
    if existing:
        raise _grn_exists_error(existing.grn_code)

    validate_seal_integrity(schema.seal_intact, schema.seal_number or "")
    validate_grn_lines(schema.grn_items)

    items_list = [item.model_dump() for item in schema.grn_items]
    totals = _line_totals(items_list)
    inspector = user
    arrival_dt = schema.arrival_datetime or datetime.now(timezone.utc)

    record = _insert_grn(db, {
        "import_file_id": schema.import_file_id,
        "warehouse_name": schema.warehouse_name,
        "arrival_datetime": arrival_dt,
        "truck_plate_number": schema.truck_plate_number,
        "driver_name": schema.driver_name,
        "driver_phone": schema.driver_phone,
        "seal_number": schema.seal_number,
        "seal_intact": schema.seal_intact,
        "grn_items": items_list,
        **totals,
        "discrepancy_type": _create_discrepancy_type(totals),
        "discrepancy_notes": schema.discrepancy_notes,
        "inspector_name": inspector,
        "notes": schema.notes,
        "created_by": user,
        "updated_by": user,
    })
    code = record.grn_code
    # The retry path rolled the session back: reload the file row lazily through the session.
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == schema.import_file_id).first()

    # LOG-BOND-003: Check if shipment is Under-Bond Released (Quarantine Lock Active)
    if clearance and clearance.is_under_bond_release and clearance.quarantine_lock:
        record.is_under_bond_quarantine = True
        record.quarantine_lock_active = True
        record.dispatch_blocked = True
        record.status = "Under Bond Quarantine"
        record.notes = (record.notes or "") + f" | Goods under customs bond (under-bond release - guarantee #{clearance.bond_guarantee_ref}) - dispatch and production are blocked."

    # Core sync, committed together with the GRN: file stage, inland bookings, demurrage port-storage clock.
    imp_file.current_module = "Phase 8 - Warehouse Receiving & Quality Control"
    imp_file.inland_transport_status = "ARRIVED"
    if not imp_file.inland_actual_arrival_date:
        imp_file.inland_actual_arrival_date = arrival_dt

    active_bookings = db.query(InlandTransportBooking).filter(
        InlandTransportBooking.import_file_id == schema.import_file_id,
        InlandTransportBooking.is_active == True,
    ).all()
    for b in active_bookings:
        if b.status != "Arrived at Warehouse":
            b.status = "Arrived at Warehouse"
            b.actual_arrival_at = arrival_dt

    active_trackings = db.query(DemurrageTracking).filter(
        DemurrageTracking.import_file_id == schema.import_file_id,
        DemurrageTracking.is_active == True,
    ).all()
    for t in active_trackings:
        if not t.gate_out_date:
            t.gate_out_date = arrival_dt.date()

    wh_stage_code = "UNDER_BOND_QUARANTINE" if record.quarantine_lock_active else "GOODS_RECEIVED"
    wh_next_action = msg(
        "NA_AWAIT_LAB_APPROVAL_BEFORE_PRODUCTION"
        if record.quarantine_lock_active
        else "NA_TR_INSPECTION_DISCREPANCY_LANDED_COST"
    )
    set_file_tracking(imp_file, stage_code=wh_stage_code, next_action=wh_next_action)
    if (imp_file.progress_percent or 0.0) < 98.0:
        imp_file.progress_percent = 98.0
    db.commit()
    db.refresh(record)

    # Follow-ups: a failure is logged and never undoes the saved GRN.
    record_id = record.receiving_id
    file_code = imp_file.import_file_code

    def _audit() -> None:
        from modules.audit_logs.service import AuditLogService
        AuditLogService(db).log_activity(
            entity_type="WarehouseReceivingRecord",
            entity_id=record_id,
            entity_code=code,
            action="CREATE",
            new_data=schema.model_dump(exclude_unset=True),
            performed_by=user,
        )

    def _lifecycle() -> None:
        from modules.lifecycle_board.service import advance_lifecycle_step_service
        advance_lifecycle_step_service(
            db=db,
            import_file_id=schema.import_file_id,
            completed_step_code="STEP_19",
            target_step_codes=["STEP_20"],
            notes_msg=msg("WH_GRN_ISSUED", warehouse_name=schema.warehouse_name, grn_code=code),
            next_action_msg=wh_next_action,
            stage_code=wh_stage_code,
            assigned_user=user,
            min_progress_percent=98.0,
        )

    def _task_and_notification() -> None:
        from modules.smart_tasks.repository import create_task as create_smart_task
        from modules.smart_tasks.schemas import SmartTaskCreate
        from modules.notifications.model import SystemNotification
        task_msg = msg("WH_TASK_INSPECTION_DISCREPANCY", grn_code=code, import_file_code=file_code)
        create_smart_task(
            db,
            SmartTaskCreate(
                import_file_id=schema.import_file_id,
                import_file_code=file_code,
                title=render_en(task_msg.code, task_msg.params, "title"),
                description=render_en(task_msg.code, task_msg.params, "body"),
                priority="Medium",
                assigned_user=inspector,
                task_type="TR-04",
            ),
            created_by=user,
            msg_code=task_msg.code,
            msg_params=task_msg.params,
            step_code="STEP_19",
            commit=False,
        )
        notif_msg = msg(
            "WH_GRN_ISSUED",
            grn_code=code,
            import_file_code=file_code,
            warehouse_name=schema.warehouse_name,
        )
        db.add(SystemNotification(
            title=render_en(notif_msg.code, notif_msg.params, "title"),
            message=render_en(notif_msg.code, notif_msg.params, "body"),
            msg_code=notif_msg.code,
            msg_params=notif_msg.params,
            severity="INFO",
            category="Warehouse Receiving",
            entity_type="ImportFile",
            entity_id=schema.import_file_id,
            target_role="ALL",
            is_read=False,
        ))
        db.commit()

    best_effort(db, _audit, "WR create audit log")
    best_effort(db, _lifecycle, "WR lifecycle advance STEP_19 -> STEP_20")
    best_effort(db, _task_and_notification, "WR TR-04 task and notification")

    return get_warehouse_receiving_by_id(db, record_id, include_inactive=True)


def get_warehouse_receiving_service(db: Session, record_id: int) -> WarehouseReceivingRecord:
    record = get_warehouse_receiving_by_id(db, record_id)
    if not record:
        raise HTTPException(status_code=404, detail="سجل استلام الجودة والمخازن غير موجود.")
    return record


def list_warehouse_receivings_service(
    db: Session,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    search: Optional[str] = None,
    skip: int = 0,
    limit: int = 200,
    return_total: bool = False,
):
    items, total = get_warehouse_receiving_list(
        db,
        include_inactive=include_inactive,
        import_file_id=import_file_id,
        status=status,
        search=search,
        skip=skip,
        limit=limit,
    )
    if return_total:
        return items, total
    return items


def paginate_warehouse_receivings_service(
    db: Session,
    params: PageParams,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    response: Optional[Response] = None,
) -> Dict[str, Any]:
    return repo_paginate_warehouse_receivings(
        db,
        params=params,
        include_inactive=include_inactive,
        import_file_id=import_file_id,
        status=status,
        response=response,
    )


def get_warehouse_receiving_by_file_service(db: Session, import_file_id: int) -> Optional[WarehouseReceivingRecord]:
    """The active GRN of a file (newest first), or None."""
    return get_active_grn_for_file(db, import_file_id)


def report_receiving_discrepancy_service(
    db: Session,
    record_id: int,
    payload: DiscrepancyReportSubmit,
    user: str = "System",
) -> WarehouseReceivingRecord:
    """BP-035 Report Receiving Discrepancies & Damage Claims."""
    validate_discrepancy_type(payload.discrepancy_type)
    validate_discrepancy_claim(payload.discrepancy_type, payload.discrepancy_notes)

    record = get_warehouse_receiving_service(db, record_id)
    _require_open_file_for_grn(db, record.import_file_id)
    apply_changes(record, {
        "discrepancy_type": payload.discrepancy_type,
        "discrepancy_notes": payload.discrepancy_notes,
        "quarantine_zone_assigned": payload.quarantine_zone_assigned,
        "insurance_claim_filed": payload.insurance_claim_filed,
        "insurance_claim_ref": payload.insurance_claim_ref,
        "status": "Discrepancy Reported",
    }, user)

    db.commit()
    db.refresh(record)
    return record


def update_warehouse_receiving_service(
    db: Session,
    record_id: int,
    schema: WarehouseReceivingUpdate,
    user: str = "System",
) -> WarehouseReceivingRecord:
    existing = get_warehouse_receiving_service(db, record_id)
    _require_open_file_for_grn(db, existing.import_file_id)
    update_data = schema.model_dump(exclude_unset=True, exclude_none=True)

    validate_status_label(update_data.get("status"))
    validate_discrepancy_type(update_data.get("discrepancy_type"))
    if "inspection_verdict" in update_data:
        update_data["inspection_verdict"] = normalize_verdict(update_data["inspection_verdict"], WR_VERDICT_CODES)

    values: Dict[str, Any] = {k: v for k, v in update_data.items() if k != "grn_items"}
    if "inspector_name" in values:
        values["inspector_name"] = user
    if schema.grn_items is not None:
        validate_grn_lines(schema.grn_items)
        items = [i.model_dump() for i in schema.grn_items]
        values["grn_items"] = items
        values.update(_line_totals(items))

    if "inspection_verdict" in values:
        validate_verdict_consistency(
            values["inspection_verdict"],
            values.get("total_shortage_qty", existing.total_shortage_qty),
            values.get("total_damaged_qty", existing.total_damaged_qty),
        )

    old_data = {k: getattr(existing, k, None) for k in update_data.keys()}
    apply_changes(existing, values, user)
    db.commit()
    db.refresh(existing)

    def _audit() -> None:
        from modules.audit_logs.service import AuditLogService
        AuditLogService(db).log_activity(
            entity_type="WarehouseReceivingRecord",
            entity_id=existing.receiving_id,
            entity_code=existing.grn_code,
            action="UPDATE",
            old_data=old_data,
            new_data=update_data,
            performed_by=user,
        )

    best_effort(db, _audit, "WR update audit log")
    return get_warehouse_receiving_by_id(db, record_id)


def soft_delete_warehouse_receiving_service(db: Session, record_id: int, user: str = "System") -> bool:
    record = get_warehouse_receiving_service(db, record_id)
    _require_open_file_for_grn(db, record.import_file_id)
    validate_grn_deletable(record)
    set_active(record, False, user)
    db.commit()
    return True


def restore_warehouse_receiving_service(db: Session, record_id: int, user: str = "System") -> WarehouseReceivingRecord:
    record = get_warehouse_receiving_by_id(db, record_id, include_inactive=True)
    if not record:
        raise HTTPException(status_code=404, detail=f"سجل استلام المخزن رقم {record_id} غير موجود.")
    _require_open_file_for_grn(db, record.import_file_id)
    if not record.is_active:
        other = get_active_grn_for_file(db, record.import_file_id, exclude_id=record.receiving_id)
        if other:
            raise _grn_exists_error(other.grn_code)
    set_active(record, True, user)
    db.commit()
    db.refresh(record)
    return record


def release_quarantine_lock_for_file(
    db: Session, import_file_id: int, user: str = "System"
) -> List[WarehouseReceivingRecord]:
    """Release quarantine and dispatch lock on all active GRNs of the file when customs lifts the lock."""
    grns = db.query(WarehouseReceivingRecord).filter(
        WarehouseReceivingRecord.import_file_id == import_file_id,
        WarehouseReceivingRecord.is_active == True,
        WarehouseReceivingRecord.quarantine_lock_active == True,
    ).all()
    released = []
    for record in grns:
        record.quarantine_lock_active = False
        record.dispatch_blocked = False
        if record.status == "Under Bond Quarantine":
            record.status = "Goods Received"
        note = record.discrepancy_notes or ""
        if "Quarantine lock lifted after lab approval" not in note:
            record.discrepancy_notes = (note + " | Quarantine lock lifted after lab approval").lstrip(" | ")
        record.updated_by = user
        record.updated_at = datetime.now(timezone.utc)
        released.append(record)
    return released


def refresh_quarantine_lock(
    db: Session, record: WarehouseReceivingRecord, user: str = "System"
) -> WarehouseReceivingRecord:
    """If a GRN is still marked quarantine_lock_active but its customs clearance lifted the lock, sync & commit."""
    if record.quarantine_lock_active:
        from modules.customs_clearance.model import CustomsClearanceRecord
        clearance = db.query(CustomsClearanceRecord).filter(
            CustomsClearanceRecord.import_file_id == record.import_file_id,
            CustomsClearanceRecord.is_active == True,
        ).order_by(CustomsClearanceRecord.customs_clearance_id.desc()).first()
        if clearance is not None and clearance.quarantine_lock is False:
            release_quarantine_lock_for_file(db, record.import_file_id, user=user)
            db.commit()
            db.refresh(record)
    return record


def validate_warehouse_dispatch_authorization(db: Session, record_id: int, user: str = "System") -> bool:
    """
    LOG-BOND-003: Strict Quarantine Dispatch Lock Validator.
    Raises HTTP 400 if cargo is under laboratory quarantine lock.
    """
    record = get_warehouse_receiving_service(db, record_id)
    refresh_quarantine_lock(db, record, user=user)
    if record.quarantine_lock_active or record.dispatch_blocked:
        raise HTTPException(
            status_code=400,
            detail="ممنوع الصرف أو التداول أو التشغيل: هذه الرسالة محتجزة تحت التحفظ الجمركي المؤقت (سحب على عهدة) لحين ورود شهادة المطابقة المعملية وفك الحظر رسمياً.",
        )
    return True


def validate_dispatch_service(db: Session, record_id: int, user: str = "System") -> WarehouseDispatchValidationResponse:
    validate_warehouse_dispatch_authorization(db, record_id, user=user)
    record = get_warehouse_receiving_service(db, record_id)
    return WarehouseDispatchValidationResponse(
        receiving_id=record.receiving_id,
        grn_code=record.grn_code,
        is_dispatch_allowed=True,
        status=record.status,
        message="البضاعة مطابقة ومصرح بصرفها وتداولها واستخدامها في خطوط الإنتاج.",
    )


def submit_warehouse_inspection_protocol_service(
    db: Session,
    record_id: int,
    schema: WarehouseInspectionSubmit,
    user_name: str = "System",
) -> WarehouseReceivingRecord:
    """
    TR-04: Formal Warehouse Inspection & Discrepancy Protocol Issuance.
    - Recalculates quantities (invoiced vs accepted vs shortage vs damaged).
    - Computes discrepancy rate percentage.
    - Assigns formal inspection protocol number (e.g. INSP-2026-XXXX).
    - Sets inspection verdict (derived from the quantities when the client sends none; validated otherwise).
    - Records root cause of damage / shortage.
    - Captures insurance and foreign supplier claims.
    - Updates ImportFile current_stage and next_action.
    - Auto-resolves active SmartTasks for TR-04.
    - Dispatches system notification to QC, Operations, and Financial Accounting.
    """
    record = get_warehouse_receiving_service(db, record_id)
    refresh_quarantine_lock(db, record, user=user_name)
    _require_open_file_for_grn(db, record.import_file_id)
    verdict = normalize_verdict(schema.inspection_verdict)
    if schema.discrepancy_type is not None:
        validate_discrepancy_type(schema.discrepancy_type)

    # 1. Update line items if provided
    if schema.grn_items is not None:
        validate_grn_lines(schema.grn_items)
        items_dict_list = [item.model_dump() for item in schema.grn_items]
        record.grn_items = items_dict_list
        for key, value in _line_totals(items_dict_list).items():
            setattr(record, key, value)

    validate_verdict_consistency(verdict, record.total_shortage_qty or 0, record.total_damaged_qty or 0)

    # 2. Discrepancy calculations
    total_discrepancy = (record.total_shortage_qty or 0) + (record.total_damaged_qty or 0)
    invoiced = record.total_invoiced_qty or 0
    if invoiced > 0:
        record.discrepancy_rate_percent = round((total_discrepancy / invoiced) * 100.0, 2)
    else:
        record.discrepancy_rate_percent = 0.0

    # 3. Protocol Number Generation
    if not record.inspection_protocol_number:
        current_year = datetime.now(timezone.utc).year
        record.inspection_protocol_number = f"INSP-{current_year}-{record.receiving_id:04d}"

    # 4. Set inspection details
    record.inspection_date = schema.inspection_date or datetime.now(timezone.utc)
    record.inspection_committee = (schema.inspection_committee or "").strip() or DEFAULT_INSPECTION_COMMITTEE
    record.root_cause = schema.root_cause
    record.quarantine_zone_assigned = schema.quarantine_zone_assigned
    record.insurance_claim_filed = schema.insurance_claim_filed
    record.insurance_claim_ref = schema.insurance_claim_ref
    record.supplier_claim_filed = schema.supplier_claim_filed
    record.supplier_claim_ref = schema.supplier_claim_ref
    record.claim_amount_estimated = schema.claim_amount_estimated or 0.0
    record.claim_currency = schema.claim_currency or "EGP"
    record.inspector_name = user_name
    if schema.notes:
        record.notes = schema.notes

    # 5. Determine Verdict and Status (the quarantine branch wins over the discrepancy branch)
    discrepancy_type = schema.discrepancy_type or "None"
    if schema.quarantine_zone_assigned or record.quarantine_lock_active:
        validate_verdict_matches(verdict, frozenset({"REJECTED_QUARANTINED"}), "REJECTED_QUARANTINED")
        record.inspection_verdict = "REJECTED_QUARANTINED"
        record.status = "Under Quarantine Inspection"
        record.discrepancy_type = discrepancy_type if discrepancy_type != "None" else "Quarantine Rejection"
    elif total_discrepancy > 0:
        validate_verdict_matches(
            verdict, frozenset({"ACCEPTED_WITH_DISCREPANCY", "DAMAGE_CLAIM_PENDING"}), "ACCEPTED_WITH_DISCREPANCY"
        )
        record.inspection_verdict = verdict or "ACCEPTED_WITH_DISCREPANCY"
        record.status = "Discrepancy Reported"
        if discrepancy_type != "None":
            record.discrepancy_type = discrepancy_type
        elif (record.total_shortage_qty or 0) > 0 and (record.total_damaged_qty or 0) > 0:
            record.discrepancy_type = "Shortage & Damaged"
        elif (record.total_shortage_qty or 0) > 0:
            record.discrepancy_type = "Shortage"
        elif (record.total_damaged_qty or 0) > 0:
            record.discrepancy_type = "Damage"
    else:
        validate_verdict_matches(verdict, frozenset({"ACCEPTED_FULL"}), "ACCEPTED_FULL")
        record.inspection_verdict = "ACCEPTED_FULL"
        record.status = "Inspection Passed / Clean Receipt"
        record.discrepancy_type = "None"

    if schema.discrepancy_notes:
        record.discrepancy_notes = schema.discrepancy_notes

    record.updated_at = datetime.now(timezone.utc)
    record.updated_by = user_name

    # 6. Update Import File
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == record.import_file_id).first()
    if imp_file:
        if record.inspection_verdict == "ACCEPTED_FULL":
            stage_code = "QC_PASSED"
            next_action_code = "NA_CLO_CALCULATE_LANDED_COST_AND_SETTLE"
        elif record.inspection_verdict == "REJECTED_QUARANTINED":
            stage_code = "QUARANTINED_UNDER_INSPECTION"
            next_action_code = "NA_FOLLOW_LAB_RESULTS_WARRANTY_CLAIMS"
        else:
            stage_code = "DISCREPANCY_PROTOCOL_FILED"
            next_action_code = "NA_FOLLOW_COMPENSATION_LANDED_COST"

        set_file_tracking(imp_file, stage_code=stage_code, next_action=msg(next_action_code))
        if (imp_file.progress_percent or 0.0) < 99.0:
            imp_file.progress_percent = 99.0

    # 7. Auto-resolve TR-04 SmartTasks (same transaction as the protocol)
    from modules.smart_tasks.model import SmartTask
    open_tasks = db.query(SmartTask).filter(
        SmartTask.import_file_id == record.import_file_id,
        SmartTask.is_active == True,
        SmartTask.status.in_(OPEN_TASK_STATUSES),
    ).all()
    now = datetime.now(timezone.utc)
    resolution = (
        f"Technical inspection protocol ({record.inspection_protocol_number}) approved "
        f"with verdict {record.inspection_verdict} by {user_name}."
    )
    for task in open_tasks:
        is_tr04 = (
            task.msg_code == "WH_TASK_INSPECTION_DISCREPANCY"
            or task.task_type == "TR-04"
            # legacy rows created before msg codes existed
            or "TR-04" in (task.title or "")
            or "الفحص الفني" in (task.title or "")
        )
        if is_tr04:
            task.status = "Completed"
            task.is_auto_closed = True
            task.updated_by = user_name
            # Not columns (kept on the instance for the API response / callers in this request only).
            task.completed_at = now
            task.resolution_notes = resolution

    db.commit()
    db.refresh(record)

    # 8. Dispatch System Notification (follow-up: never undoes the saved protocol)
    def _notify() -> None:
        from modules.notifications.model import SystemNotification
        has_claims = bool(record.insurance_claim_filed or record.supplier_claim_filed)
        claim_params = (
            {
                "insurance_claim_ref": (record.insurance_claim_ref or "-") if record.insurance_claim_filed else "-",
                "supplier_claim_ref": (record.supplier_claim_ref or "-") if record.supplier_claim_filed else "-",
            }
            if has_claims
            else {}
        )
        notif_msg = msg(
            "WH_INSPECTION_PROTOCOL_APPROVED_CLAIMS" if has_claims else "WH_INSPECTION_PROTOCOL_APPROVED",
            **claim_params,
            protocol_no=record.inspection_protocol_number,
            committee=record.inspection_committee,
            import_file_code=imp_file.import_file_code if imp_file else "",
            verdict_enum_warehouse_inspection_verdict=record.inspection_verdict,
            accepted_qty=record.total_accepted_qty,
            shortage_qty=record.total_shortage_qty,
            damaged_qty=record.total_damaged_qty,
        )
        db.add(SystemNotification(
            title=render_en(notif_msg.code, notif_msg.params, "title"),
            message=render_en(notif_msg.code, notif_msg.params, "body"),
            msg_code=notif_msg.code,
            msg_params=notif_msg.params,
            severity="WARNING" if total_discrepancy > 0 else "INFO",
            category="Quality Control & Inspection",
            entity_type="ImportFile",
            entity_id=record.import_file_id,
            target_role="ALL",
            is_read=False,
        ))
        db.commit()

    best_effort(db, _notify, "WR inspection notification")
    return record


def get_inspection_summary_service(db: Session, record_id: int) -> InspectionSummaryResponse:
    record = get_warehouse_receiving_service(db, record_id)
    total_discrepancy = (record.total_shortage_qty or 0) + (record.total_damaged_qty or 0)
    return InspectionSummaryResponse(
        receiving_id=record.receiving_id,
        grn_code=record.grn_code,
        import_file_id=record.import_file_id,
        inspection_protocol_number=record.inspection_protocol_number,
        inspection_date=record.inspection_date or record.arrival_datetime,
        inspection_committee=record.inspection_committee,
        inspection_verdict=record.inspection_verdict or ("ACCEPTED_FULL" if total_discrepancy == 0 else "ACCEPTED_WITH_DISCREPANCY"),
        root_cause=record.root_cause,
        total_invoiced_qty=record.total_invoiced_qty or 0,
        total_accepted_qty=record.total_accepted_qty or 0,
        total_shortage_qty=record.total_shortage_qty or 0,
        total_damaged_qty=record.total_damaged_qty or 0,
        discrepancy_rate_percent=record.discrepancy_rate_percent or 0.0,
        quarantine_zone_assigned=record.quarantine_zone_assigned or False,
        insurance_claim_filed=record.insurance_claim_filed or False,
        insurance_claim_ref=record.insurance_claim_ref,
        supplier_claim_filed=record.supplier_claim_filed or False,
        supplier_claim_ref=record.supplier_claim_ref,
        claim_amount_estimated=record.claim_amount_estimated or 0.0,
        claim_currency=record.claim_currency or "EGP",
        status=record.status or "Goods Received",
        is_ready_for_landed_cost=(record.inspection_verdict != "REJECTED_QUARANTINED" and not record.quarantine_lock_active),
    )
