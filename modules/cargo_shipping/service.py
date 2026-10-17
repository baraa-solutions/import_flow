import logging
from sqlalchemy.orm.attributes import flag_modified
from datetime import datetime, timezone
from typing import List, Optional, Dict, Any, Tuple
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from .model import CargoShippingRecord
from .schemas import (
    CargoShippingCreate,
    CargoShippingUpdate,
    ContainerLoadingTrackingUpdate,
    LclLoadingTrackingItem,
    DualApprovalLevel1Submit,
    DualApprovalLevel2Submit,
)
from .repository import (
    generate_cargo_shipping_code,
    get_cargo_shipping_by_id,
    get_cargo_shipping_by_import_file,
    get_cargo_shipping_list,
    create_cargo_shipping,
    apply_cargo_shipping_update,
    set_cargo_shipping_active,
)
from .validators import (
    MANUAL_CHECK_REQUIRED,
    MANUALLY_CONFIRMED,
    RECORD_LABEL_AR,
    STATUS_CARGO_READY,
    STATUS_CARGOX_DONE,
    STATUS_COMPLETED,
    STATUS_DUAL_APPROVED,
    _status_rank,
    resolve_manual_status,
    validate_crd_against_cutoff,
    validate_dual_approval_sequence,
    validate_cargox_ready_for_upload,
    validate_container_tracking_timestamps,
    calculate_container_sla_and_status,
    validate_container_reuse_conflict,
    validate_envelope_stage_order,
    validate_level1_allowed,
    validate_level2_allowed,
    validate_checklist_rerun_allowed,
    validate_deletable,
    validate_documents_editable,
    validate_booking_link,
    containers_or_seals_changed,
)
from modules.common.errors import best_effort
from modules.common.validators import not_found
from modules.import_files.model import ImportFile

logger = logging.getLogger(__name__)

LCL_FIELD_NAMES = ("consolidation_scheduled_date", "arrival_at_cfs_at", "stuffing_start_at", "stuffing_end_at", "port_gate_in_at")


def _process_container_items(containers_raw: List[Any]) -> List[Dict[str, Any]]:
    processed = []
    for c in containers_raw:
        c_dict = c.model_dump() if hasattr(c, "model_dump") else dict(c)

        # Validate sequential timestamps
        validate_container_tracking_timestamps(
            container_assignment_date=c_dict.get("container_assignment_date"),
            arrival_at_supplier_at=c_dict.get("arrival_at_supplier_at"),
            loading_start_at=c_dict.get("loading_start_at"),
            loading_end_at=c_dict.get("loading_end_at"),
            port_gate_in_at=c_dict.get("port_gate_in_at"),
        )

        # Calculate SLA & Status
        processed.append(calculate_container_sla_and_status(c_dict))
    return processed


def _process_lcl_item(lcl_raw: Optional[Any]) -> Dict[str, Any]:
    if not lcl_raw:
        return {}
    lcl_dict = lcl_raw.model_dump() if hasattr(lcl_raw, "model_dump") else dict(lcl_raw)
    validate_container_tracking_timestamps(
        container_assignment_date=lcl_dict.get("consolidation_scheduled_date"),
        arrival_at_supplier_at=lcl_dict.get("arrival_at_cfs_at"),
        loading_start_at=lcl_dict.get("stuffing_start_at"),
        loading_end_at=lcl_dict.get("stuffing_end_at"),
        port_gate_in_at=lcl_dict.get("port_gate_in_at"),
        field_names=LCL_FIELD_NAMES,
    )
    return calculate_container_sla_and_status(lcl_dict)


def _attach_import_file_metadata(db: Session, record: CargoShippingRecord) -> CargoShippingRecord:
    if record and record.import_file_id:
        imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == record.import_file_id).first()
        if imp_file:
            setattr(record, "import_file_code", imp_file.custom_file_number or imp_file.import_file_code)
            setattr(record, "company_name", imp_file.company_name)
    return record


def _active_record(db: Session, record_id: int) -> CargoShippingRecord:
    """Mutations work on active records only: a soft-deleted record is restored through /restore."""
    record = get_cargo_shipping_by_id(db, record_id)
    if not record:
        raise not_found(RECORD_LABEL_AR, record_id)
    return record


def _sync_lifecycle(db: Session, record: CargoShippingRecord) -> None:
    from modules.lifecycle_board.service import sync_cargo_shipping_lifecycle_stage
    # Q7 (safe default): the allocation step is reported final on every save, as today.
    sync_cargo_shipping_lifecycle_stage(
        db=db,
        import_file_id=record.import_file_id,
        cargo_shipping_code=record.cargo_shipping_code,
        container_count=len(record.containers_loading_data or []),
        is_final_completed=True,
    )
    db.commit()


def _commit_and_follow_up(db: Session, record: CargoShippingRecord, auto_advance_lifecycle: bool) -> CargoShippingRecord:
    db.commit()
    db.refresh(record)
    if auto_advance_lifecycle and record.import_file_id:
        best_effort(db, _sync_lifecycle, "Cargo shipping lifecycle sync (STEP_07 -> STEP_08_PO)", db, record)
        db.refresh(record)
    return _attach_import_file_metadata(db, record)


def create_cargo_shipping_service(
    db: Session,
    schema: CargoShippingCreate,
    auto_upsert: bool = False,
    auto_advance_lifecycle: bool = True,
    user: str = "system",
) -> CargoShippingRecord:
    # 1. Check import file exists
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == schema.import_file_id, ImportFile.is_active == True).first()
    if not imp_file:
        raise HTTPException(status_code=404, detail="ملف الشحنة الاستيرادية المرتكز عليه غير موجود أو محذوف.")

    # Validate booking link if provided
    if schema.booking_id is not None:
        validate_booking_link(db, schema.booking_id, schema.import_file_id)

    # 2. Duplicate Prevention / Auto-Upsert
    existing = get_cargo_shipping_by_import_file(db, schema.import_file_id, include_inactive=True)
    if existing:
        if not existing.is_active:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"السجل محذوف، استخدم الاستعادة (كود السجل: {existing.cargo_shipping_code}).",
            )
        if auto_upsert:
            update_schema = CargoShippingUpdate(**schema.model_dump(exclude_unset=True))
            return update_cargo_shipping_service(
                db, existing.cargo_shipping_id, update_schema, auto_advance_lifecycle=auto_advance_lifecycle, user=user
            )
        raise HTTPException(
            status_code=400,
            detail=f"يوجد سجل متابعة وشحن محفوظ بالفعل لهذا الملف الاستيرادي (كود السجل: {existing.cargo_shipping_code}). لا يمكن إنشاء سجل مكرر لنفس الملف، يرجى تعديل السجل القائم."
        )

    # 3. Check 15-day container reuse conflicts
    if schema.containers_loading_data:
        validate_container_reuse_conflict(db, schema.containers_loading_data)

    # 4. Process Container Follow-up Trackings & Validations
    processed_containers = _process_container_items(schema.containers_loading_data)
    processed_lcl = _process_lcl_item(schema.lcl_tracking_data)
    initial_status = resolve_manual_status(schema.status, None) or STATUS_CARGO_READY
    owner = schema.owner if "owner" in schema.model_fields_set and schema.owner else user

    def build() -> CargoShippingRecord:
        record = create_cargo_shipping(
            db, schema, generate_cargo_shipping_code(db), processed_containers, processed_lcl,
            status=initial_status, owner=owner, user=user,
        )
        if schema.crd_date and schema.cargo_cutoff_date:
            record.is_crd_validated = validate_crd_against_cutoff(schema.crd_date, schema.cargo_cutoff_date)
        return record

    try:
        record = build()
        db.flush()
    except IntegrityError:
        # a concurrent create took the same SHP code: retry once with the next one
        db.rollback()
        record = build()
    return _commit_and_follow_up(db, record, auto_advance_lifecycle)


def get_cargo_shipping_service(db: Session, record_id: int, include_inactive: bool = False) -> CargoShippingRecord:
    record = get_cargo_shipping_by_id(db, record_id, include_inactive=include_inactive)
    if not record:
        raise not_found(RECORD_LABEL_AR, record_id)
    return _attach_import_file_metadata(db, record)


def list_cargo_shippings_service(
    db: Session,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    search: Optional[str] = None,
    skip: int = 0,
    limit: int = 200,
) -> Tuple[List[CargoShippingRecord], int]:
    records, total = get_cargo_shipping_list(
        db, include_inactive, import_file_id, status, search, skip=skip, limit=limit
    )
    file_ids = {r.import_file_id for r in records if r.import_file_id}
    if file_ids:
        files = db.query(ImportFile).filter(ImportFile.import_file_id.in_(file_ids)).all()
        file_map = {f.import_file_id: f for f in files}
        for r in records:
            if r.import_file_id and r.import_file_id in file_map:
                imp_file = file_map[r.import_file_id]
                setattr(r, "import_file_code", imp_file.custom_file_number or imp_file.import_file_code)
                setattr(r, "company_name", imp_file.company_name)
    return records, total


def update_container_loading_tracking_service(
    db: Session,
    record_id: int,
    container_no: str,
    payload: ContainerLoadingTrackingUpdate,
    user: Optional[str] = None,
) -> CargoShippingRecord:
    record = _active_record(db, record_id)
    validate_documents_editable(record.status, record.cargo_shipping_code)
    actor = user or payload.updated_by
    containers = list(record.containers_loading_data or [])

    found = False
    for idx, c in enumerate(containers):
        if c.get("container_no", "").strip().upper() == container_no.strip().upper():
            found = True
            seal_changed = (
                payload.seal_no is not None
                and payload.seal_no.strip() != (c.get("seal_no") or "").strip()
            )
            if seal_changed and record.level1_approval_status == "Approved":
                record.level1_approval_status = "Pending"
                record.level2_approval_status = "Pending"
                record.dual_approval_status = "Pending"
                reset_note = "تمت إعادة تعيين الاعتماد لتعديل رقم السيل (Seal No)."
                record.level1_notes = f"{record.level1_notes}\n{reset_note}" if record.level1_notes else reset_note

            updated_item = dict(c)
            if payload.container_assignment_date is not None:
                updated_item["container_assignment_date"] = payload.container_assignment_date
            if payload.arrival_at_supplier_at is not None:
                updated_item["arrival_at_supplier_at"] = payload.arrival_at_supplier_at
            if payload.loading_start_at is not None:
                updated_item["loading_start_at"] = payload.loading_start_at
            if payload.loading_end_at is not None:
                updated_item["loading_end_at"] = payload.loading_end_at
            if payload.port_gate_in_at is not None:
                updated_item["port_gate_in_at"] = payload.port_gate_in_at
            if payload.seal_no is not None:
                updated_item["seal_no"] = payload.seal_no
            if payload.milestone_notes is not None:
                existing_notes = dict(updated_item.get("milestone_notes") or {})
                existing_notes.update(payload.milestone_notes)
                updated_item["milestone_notes"] = existing_notes

            # Validate
            validate_container_tracking_timestamps(
                container_assignment_date=updated_item.get("container_assignment_date"),
                arrival_at_supplier_at=updated_item.get("arrival_at_supplier_at"),
                loading_start_at=updated_item.get("loading_start_at"),
                loading_end_at=updated_item.get("loading_end_at"),
                port_gate_in_at=updated_item.get("port_gate_in_at"),
            )

            # Check container conflict
            validate_container_reuse_conflict(db, [updated_item], current_record_id=record_id)

            # Recalculate SLA & Status
            calc_item = calculate_container_sla_and_status(updated_item)

            # Audit log
            history = list(calc_item.get("tracking_history", []))
            history.append({
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "updated_by": actor,
                "notes": payload.notes or "Container tracking stage updated",
                "status": calc_item.get("tracking_status"),
            })
            calc_item["tracking_history"] = history
            containers[idx] = calc_item
            break

    if not found:
        raise HTTPException(status_code=404, detail=f"الحاوية رقم {container_no} غير موجودة في هذا السجل.")

    record.containers_loading_data = containers
    flag_modified(record, "containers_loading_data")
    record.updated_at = datetime.now(timezone.utc)
    record.updated_by = actor
    db.commit()
    db.refresh(record)
    return _attach_import_file_metadata(db, record)


def update_lcl_loading_tracking_service(
    db: Session,
    record_id: int,
    payload: LclLoadingTrackingItem,
    user: str = "system",
) -> CargoShippingRecord:
    record = _active_record(db, record_id)
    validate_documents_editable(record.status, record.cargo_shipping_code)
    record.lcl_tracking_data = _process_lcl_item(payload)
    flag_modified(record, "lcl_tracking_data")
    record.updated_at = datetime.now(timezone.utc)
    record.updated_by = user
    db.commit()
    db.refresh(record)
    return _attach_import_file_metadata(db, record)


def submit_level1_approval_service(
    db: Session, record_id: int, payload: DualApprovalLevel1Submit, user: str = "system"
) -> CargoShippingRecord:
    """BP-022 Level 1 Operational Approval. The approver is the logged-in user (``approved_by`` is ignored)."""
    record = _active_record(db, record_id)
    validate_level1_allowed(record.dual_approval_status, record.status)

    record.level1_approval_status = "Approved" if payload.approved else "Rejected"
    record.level1_approved_by = user
    record.level1_approved_at = datetime.now(timezone.utc)
    record.level1_notes = payload.notes

    if payload.approved:
        if record.level2_approval_status == "Approved":
            record.dual_approval_status = STATUS_DUAL_APPROVED
        else:
            record.dual_approval_status = "In Progress"
    else:
        record.dual_approval_status = "Rejected"

    record.updated_at = datetime.now(timezone.utc)
    record.updated_by = user
    db.commit()
    db.refresh(record)
    return _attach_import_file_metadata(db, record)


def submit_level2_approval_service(
    db: Session, record_id: int, payload: DualApprovalLevel2Submit, user: str = "system"
) -> CargoShippingRecord:
    """BP-022 Level 2 Management / Customs Broker Approval. The approver is the logged-in user."""
    record = _active_record(db, record_id)
    validate_level2_allowed(record.dual_approval_status, record.status)

    # Validate sequence
    same_approver = False
    if payload.approved:
        validate_dual_approval_sequence(record.level1_approval_status, "Approved")
        if record.level1_approved_by and record.level1_approved_by == user:
            # Q6 (safe default): the same person may approve both levels; it is logged and audited.
            same_approver = True
            logger.warning("Cargo shipping %s: level 1 and level 2 approved by the same user %s", record.cargo_shipping_code, user)
        record.level2_approval_status = "Approved"
        record.dual_approval_status = STATUS_DUAL_APPROVED
        record.status = STATUS_DUAL_APPROVED
    else:
        record.level2_approval_status = "Rejected"
        record.dual_approval_status = "Rejected"

    record.level2_approved_by = user
    record.level2_approved_at = datetime.now(timezone.utc)
    record.level2_notes = payload.notes

    record.updated_at = datetime.now(timezone.utc)
    record.updated_by = user
    db.commit()
    db.refresh(record)
    if same_approver:
        best_effort(db, _audit_same_approver, "AuditLog for same-approver dual approval", db, record, user)
    return _attach_import_file_metadata(db, record)


def _audit_same_approver(db: Session, record: CargoShippingRecord, user: str) -> None:
    from modules.audit_logs.service import AuditLogService
    AuditLogService(db).log_activity(
        entity_type="CargoShippingRecord",
        entity_id=record.cargo_shipping_id,
        entity_code=record.cargo_shipping_code,
        action="DUAL_APPROVAL_SAME_APPROVER",
        new_data={"same_approver": True, "level1_approved_by": record.level1_approved_by, "level2_approved_by": user},
        performed_by=user,
        changes_summary=f"Level 1 and level 2 approvals given by the same user ({user})",
    )


def execute_cargox_checklist_service(
    db: Session, record_id: int, invoice_match_confirmed: bool = False, user: str = "system"
) -> CargoShippingRecord:
    """BP-024 Stage 2: verification checklist for the CargoX electronic exchange.

    No rule is assumed passed: the ACID rule reads the import file's ACID number, and the invoice / consignee
    match stays MANUAL_CHECK_REQUIRED until a user confirms it (``invoice_match_confirmed``, recorded with
    the user name)."""
    record = _active_record(db, record_id)
    validate_checklist_rerun_allowed((record.cargox_exchange_data or {}).get("envelope_status"), record.cargo_shipping_code)
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == record.import_file_id).first()
    acid_number = (imp_file.acid_number or "").strip() if imp_file else ""

    invoice_rule = {
        "rule_name": "Commercial Invoice & Consignee Match",
        "passed": bool(invoice_match_confirmed),
        "details": MANUALLY_CONFIRMED if invoice_match_confirmed else MANUAL_CHECK_REQUIRED,
    }
    if invoice_match_confirmed:
        invoice_rule["confirmed_by"] = user
        invoice_rule["confirmed_at"] = datetime.now(timezone.utc).isoformat()

    shipment_type = (record.shipment_type or "FCL").strip().upper()
    if shipment_type == "AIR":
        bl_passed = True
        bl_details = "NOT_APPLICABLE"
    elif shipment_type == "LCL":
        lcl_data = record.lcl_tracking_data or {}
        bl_passed = bool(lcl_data.get("port_gate_in_at"))
        bl_details = (
            "LCL CFS consolidation gated in at port."
            if bl_passed
            else "LCL port gate-in date is missing."
        )
    else:  # FCL or default
        containers = record.containers_loading_data or []
        has_containers = len(containers) > 0
        all_have_seals = has_containers and all(
            bool((c.get("seal_no") or "").strip()) for c in containers
        )
        bl_passed = has_containers and all_have_seals
        if not has_containers:
            bl_details = "Container list is empty."
        elif not all_have_seals:
            bl_details = "One or more containers are missing seal numbers."
        else:
            bl_details = "Container numbers & seal numbers populated."

    checklist = [
        {
            "rule_name": "ACID Number Validity & Verification",
            "passed": bool(acid_number),
            "details": "ACID number recorded on the import file." if acid_number else "ACID number missing on the import file.",
        },
        invoice_rule,
        {
            "rule_name": "Bill of Lading (BL) & Container List Match",
            "passed": bl_passed,
            "details": bl_details,
        },
        {
            "rule_name": "Dual Approval Level 1 & Level 2 Status",
            "passed": record.dual_approval_status == STATUS_DUAL_APPROVED,
            "details": f"Dual approval current status: {record.dual_approval_status}",
        },
    ]

    cargox_data = dict(record.cargox_exchange_data or {})
    cargox_data["verification_checklist"] = checklist
    cargox_data["envelope_status"] = "Checklist Passed" if all(r["passed"] for r in checklist) else "Invited"

    record.cargox_exchange_data = cargox_data
    flag_modified(record, "cargox_exchange_data")
    record.updated_at = datetime.now(timezone.utc)
    record.updated_by = user
    db.commit()
    db.refresh(record)
    return _attach_import_file_metadata(db, record)


def advance_cargox_stage_service(
    db: Session,
    record_id: int,
    target_stage: str,
    tx_hash: Optional[str] = None,
    envelope_id: Optional[str] = None,
    user: str = "system",
) -> CargoShippingRecord:
    """BP-024 Stage 3, 4, 5: Checklist Passed -> Ready for Upload -> Uploaded -> Completed (409 out of order).
    The blockchain tx hash and envelope id are never invented: they are taken from the request or left null."""
    record = _active_record(db, record_id)
    cargox_data = dict(record.cargox_exchange_data or {})
    validate_envelope_stage_order(cargox_data.get("envelope_status"), target_stage)
    checklist = cargox_data.get("verification_checklist", [])

    if target_stage == "Ready for Upload":
        validate_cargox_ready_for_upload(checklist)
    elif target_stage == "Uploaded":
        validate_cargox_ready_for_upload(checklist)
        if tx_hash and tx_hash.strip():
            cargox_data["blockchain_tx_hash"] = tx_hash.strip()
        if envelope_id and envelope_id.strip():
            cargox_data["envelope_id"] = envelope_id.strip()
        cargox_data.setdefault("blockchain_tx_hash", None)
        cargox_data.setdefault("envelope_id", None)
        record.status = STATUS_CARGOX_DONE
    elif target_stage == "Completed":
        record.status = STATUS_COMPLETED
    cargox_data["envelope_status"] = target_stage

    record.cargox_exchange_data = cargox_data
    flag_modified(record, "cargox_exchange_data")
    record.updated_at = datetime.now(timezone.utc)
    record.updated_by = user
    db.commit()
    db.refresh(record)
    return _attach_import_file_metadata(db, record)


def update_cargo_shipping_service(
    db: Session,
    record_id: int,
    schema: CargoShippingUpdate,
    auto_advance_lifecycle: bool = True,
    user: str = "system",
) -> CargoShippingRecord:
    record = _active_record(db, record_id)

    if schema.booking_id is not None:
        validate_booking_link(db, schema.booking_id, record.import_file_id)

    if (
        schema.containers_loading_data is not None
        or schema.lcl_tracking_data is not None
        or schema.shipment_type is not None
    ):
        validate_documents_editable(record.status, record.cargo_shipping_code)

    if _status_rank(record.status) < _status_rank(STATUS_DUAL_APPROVED) and record.level1_approval_status == "Approved":
        shipment_type_changed = schema.shipment_type is not None and schema.shipment_type != record.shipment_type
        containers_changed = schema.containers_loading_data is not None and containers_or_seals_changed(
            record.containers_loading_data, schema.containers_loading_data
        )
        if shipment_type_changed or containers_changed:
            record.level1_approval_status = "Pending"
            record.level2_approval_status = "Pending"
            record.dual_approval_status = "Pending"
            reset_note = "تمت إعادة تعيين الاعتماد لتعديل بيانات الحاويات أو السيل."
            record.level1_notes = f"{record.level1_notes}\n{reset_note}" if record.level1_notes else reset_note

    processed_containers = None
    if schema.containers_loading_data is not None:
        validate_container_reuse_conflict(db, schema.containers_loading_data, current_record_id=record_id)
        processed_containers = _process_container_items(schema.containers_loading_data)

    processed_lcl = None
    if schema.lcl_tracking_data is not None:
        processed_lcl = _process_lcl_item(schema.lcl_tracking_data)

    apply_cargo_shipping_update(record, schema, processed_containers, processed_lcl)
    new_status = resolve_manual_status(schema.status, record.status)
    if new_status:
        record.status = new_status
    record.updated_by = user

    # Re-validate CRD if dates updated
    if record.crd_date and record.cargo_cutoff_date:
        record.is_crd_validated = validate_crd_against_cutoff(record.crd_date, record.cargo_cutoff_date)

    return _commit_and_follow_up(db, record, auto_advance_lifecycle)


def soft_delete_cargo_shipping_service(db: Session, record_id: int, user: str = "system") -> bool:
    record = _active_record(db, record_id)
    validate_deletable(record.status, record.cargo_shipping_code)
    set_cargo_shipping_active(record, False, user)
    db.commit()
    return True


def restore_cargo_shipping_service(db: Session, record_id: int, user: str = "system") -> CargoShippingRecord:
    record = get_cargo_shipping_by_id(db, record_id, include_inactive=True)
    if not record:
        raise not_found(RECORD_LABEL_AR, record_id)
    if not record.is_active:
        other = get_cargo_shipping_by_import_file(db, record.import_file_id)
        if other is not None and other.cargo_shipping_id != record.cargo_shipping_id:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"يوجد سجل شحن نشط آخر لنفس الملف (كود السجل: {other.cargo_shipping_code}).",
            )
    set_cargo_shipping_active(record, True, user)
    db.commit()
    db.refresh(record)
    return _attach_import_file_metadata(db, record)
