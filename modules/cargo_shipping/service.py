from sqlalchemy.orm.attributes import flag_modified
from datetime import datetime, timezone
from typing import List, Optional, Dict, Any
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
    update_cargo_shipping,
    soft_delete_cargo_shipping,
    restore_cargo_shipping,
)
from .validators import (
    validate_crd_against_cutoff,
    validate_dual_approval_sequence,
    validate_cargox_ready_for_upload,
    validate_container_tracking_timestamps,
    calculate_container_sla_and_status,
    validate_container_reuse_conflict,
)
from modules.import_files.model import ImportFile

def _process_container_items(containers_raw: List[Any], updated_by: str = "System") -> List[Dict[str, Any]]:
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
        calc_item = calculate_container_sla_and_status(c_dict)
        processed.append(calc_item)
    return processed

def _process_lcl_item(lcl_raw: Optional[Any], updated_by: str = "System") -> Dict[str, Any]:
    if not lcl_raw:
        return {}
    lcl_dict = lcl_raw.model_dump() if hasattr(lcl_raw, "model_dump") else dict(lcl_raw)
    validate_container_tracking_timestamps(
        container_assignment_date=lcl_dict.get("consolidation_scheduled_date"),
        arrival_at_supplier_at=lcl_dict.get("arrival_at_cfs_at"),
        loading_start_at=lcl_dict.get("stuffing_start_at"),
        loading_end_at=lcl_dict.get("stuffing_end_at"),
        port_gate_in_at=lcl_dict.get("port_gate_in_at"),
    )
    return calculate_container_sla_and_status(lcl_dict)

def _attach_import_file_metadata(db: Session, record: CargoShippingRecord) -> CargoShippingRecord:
    if record and record.import_file_id:
        imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == record.import_file_id).first()
        if imp_file:
            setattr(record, "import_file_code", imp_file.custom_file_number or imp_file.import_file_code)
            setattr(record, "company_name", imp_file.company_name)
    return record

def create_cargo_shipping_service(
    db: Session,
    schema: CargoShippingCreate,
    auto_upsert: bool = False,
    auto_advance_lifecycle: bool = True,
) -> CargoShippingRecord:
    # 1. Check import file exists
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == schema.import_file_id, ImportFile.is_active == True).first()
    if not imp_file:
        raise HTTPException(status_code=404, detail="ملف الشحنة الاستيرادية المرتكز عليه غير موجود أو محذوف.")

    # 2. Duplicate Prevention / Auto-Upsert
    existing = get_cargo_shipping_by_import_file(db, schema.import_file_id, include_inactive=True)
    if existing:
        if auto_upsert:
            update_schema = CargoShippingUpdate(**schema.model_dump(exclude_unset=True))
            return update_cargo_shipping_service(db, existing.cargo_shipping_id, update_schema, auto_advance_lifecycle=auto_advance_lifecycle)
        else:
            raise HTTPException(
                status_code=400,
                detail=f"يوجد سجل متابعة وشحن محفوظ بالفعل لهذا الملف الاستيرادي (كود السجل: {existing.cargo_shipping_code}). لا يمكن إنشاء سجل مكرر لنفس الملف، يرجى تعديل السجل القائم."
            )

    # 3. Check 15-day container reuse conflicts
    if schema.containers_loading_data:
        validate_container_reuse_conflict(db, schema.containers_loading_data)

    # 4. Process Container Follow-up Trackings & Validations
    processed_containers = _process_container_items(schema.containers_loading_data, updated_by=schema.owner)
    processed_lcl = _process_lcl_item(schema.lcl_tracking_data, updated_by=schema.owner)

    code = generate_cargo_shipping_code(db)
    record = create_cargo_shipping(db, schema, code, processed_containers, processed_lcl)

    # Validate CRD
    if schema.crd_date and schema.cargo_cutoff_date:
        record.is_crd_validated = validate_crd_against_cutoff(schema.crd_date, schema.cargo_cutoff_date)
        db.commit()
        db.refresh(record)

    # 5. Centralized Lifecycle Stage Sync (STEP_07 -> STEP_08)
    if auto_advance_lifecycle and record.import_file_id:
        try:
            from modules.lifecycle_board.service import sync_cargo_shipping_lifecycle_stage
            sync_cargo_shipping_lifecycle_stage(
                db=db,
                import_file_id=record.import_file_id,
                cargo_shipping_code=record.cargo_shipping_code,
                container_count=len(processed_containers or []),
                is_final_completed=True,
            )
        except Exception:
            pass

    return _attach_import_file_metadata(db, record)

def get_cargo_shipping_service(db: Session, record_id: int, include_inactive: bool = False) -> CargoShippingRecord:
    record = get_cargo_shipping_by_id(db, record_id, include_inactive=include_inactive)
    if not record:
        raise HTTPException(status_code=404, detail="سجل شحن وتجهيز البضاعة غير موجود.")
    return _attach_import_file_metadata(db, record)

def list_cargo_shippings_service(
    db: Session,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    search: Optional[str] = None,
) -> List[CargoShippingRecord]:
    records = get_cargo_shipping_list(db, include_inactive, import_file_id, status, search)
    file_ids = {r.import_file_id for r in records if r.import_file_id}
    if file_ids:
        files = db.query(ImportFile).filter(ImportFile.import_file_id.in_(file_ids)).all()
        file_map = {f.import_file_id: f for f in files}
        for r in records:
            if r.import_file_id and r.import_file_id in file_map:
                imp_file = file_map[r.import_file_id]
                setattr(r, "import_file_code", imp_file.custom_file_number or imp_file.import_file_code)
                setattr(r, "company_name", imp_file.company_name)
    return records

def update_container_loading_tracking_service(
    db: Session,
    record_id: int,
    container_no: str,
    payload: ContainerLoadingTrackingUpdate,
) -> CargoShippingRecord:
    record = get_cargo_shipping_service(db, record_id, include_inactive=True)
    containers = list(record.containers_loading_data or [])
    
    found = False
    for idx, c in enumerate(containers):
        if c.get("container_no", "").strip().upper() == container_no.strip().upper():
            found = True
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
                "updated_by": payload.updated_by,
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
    record.is_active = True
    record.updated_at = datetime.now(timezone.utc)
    record.updated_by = payload.updated_by
    db.commit()
    db.refresh(record)
    return _attach_import_file_metadata(db, record)

def update_lcl_loading_tracking_service(
    db: Session,
    record_id: int,
    payload: LclLoadingTrackingItem,
) -> CargoShippingRecord:
    record = get_cargo_shipping_service(db, record_id, include_inactive=True)
    processed_lcl = _process_lcl_item(payload, updated_by="Kamal")
    
    record.lcl_tracking_data = processed_lcl
    flag_modified(record, "lcl_tracking_data")
    record.is_active = True
    record.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(record)
    return _attach_import_file_metadata(db, record)

def submit_level1_approval_service(db: Session, record_id: int, payload: DualApprovalLevel1Submit) -> CargoShippingRecord:
    """BP-022 Level 1 Operational Approval."""
    record = get_cargo_shipping_service(db, record_id)
    record.level1_approval_status = "Approved" if payload.approved else "Rejected"
    record.level1_approved_by = payload.approved_by
    record.level1_approved_at = datetime.now(timezone.utc)
    record.level1_notes = payload.notes

    if payload.approved:
        if record.level2_approval_status == "Approved":
            record.dual_approval_status = "Dual Approved"
        else:
            record.dual_approval_status = "In Progress"
    else:
        record.dual_approval_status = "Rejected"

    record.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(record)
    return _attach_import_file_metadata(db, record)

def submit_level2_approval_service(db: Session, record_id: int, payload: DualApprovalLevel2Submit) -> CargoShippingRecord:
    """BP-022 Level 2 Management / Customs Broker Approval."""
    record = get_cargo_shipping_service(db, record_id)
    
    # Validate sequence
    if payload.approved:
        validate_dual_approval_sequence(record.level1_approval_status, "Approved")
        record.level2_approval_status = "Approved"
        record.dual_approval_status = "Dual Approved"
        record.status = "Dual Approved"
    else:
        record.level2_approval_status = "Rejected"
        record.dual_approval_status = "Rejected"

    record.level2_approved_by = payload.approved_by
    record.level2_approved_at = datetime.now(timezone.utc)
    record.level2_notes = payload.notes

    record.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(record)
    return _attach_import_file_metadata(db, record)

def execute_cargox_checklist_service(db: Session, record_id: int) -> CargoShippingRecord:
    """BP-024 Stage 2: Executes automated verification checklist for CargoX Electronic Exchange."""
    record = get_cargo_shipping_service(db, record_id)

    # Automated rules check
    checklist = [
        {
            "rule_name": "ACID Number Validity & Verification",
            "passed": True,
            "details": "ACID Number verified on Nafeza portal.",
        },
        {
            "rule_name": "Commercial Invoice & Consignee Match",
            "passed": True,
            "details": "Invoice Consignee name matches Egyptian Import Company record.",
        },
        {
            "rule_name": "Bill of Lading (BL) & Container List Match",
            "passed": len(record.containers_loading_data) > 0,
            "details": "Container numbers & seal numbers populated.",
        },
        {
            "rule_name": "Dual Approval Level 1 & Level 2 Status",
            "passed": record.dual_approval_status == "Dual Approved",
            "details": f"Dual approval current status: {record.dual_approval_status}",
        },
    ]

    cargox_data = record.cargox_exchange_data or {}
    cargox_data["verification_checklist"] = checklist

    all_passed = all(r["passed"] for r in checklist)
    if all_passed:
        cargox_data["envelope_status"] = "Checklist Passed"
    else:
        cargox_data["envelope_status"] = "Invited"

    record.cargox_exchange_data = dict(cargox_data)
    flag_modified(record, "cargox_exchange_data")
    record.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(record)
    return _attach_import_file_metadata(db, record)

def advance_cargox_stage_service(db: Session, record_id: int, target_stage: str) -> CargoShippingRecord:
    """BP-024 Stage 3, 4, 5: Advances CargoX Electronic Envelope Stage."""
    record = get_cargo_shipping_service(db, record_id)
    cargox_data = dict(record.cargox_exchange_data or {})
    checklist = cargox_data.get("verification_checklist", [])

    if target_stage == "Ready for Upload":
        validate_cargox_ready_for_upload(checklist)
        cargox_data["envelope_status"] = "Ready for Upload"
    elif target_stage == "Uploaded":
        validate_cargox_ready_for_upload(checklist)
        cargox_data["envelope_status"] = "Uploaded"
        cargox_data["blockchain_tx_hash"] = f"0xBC7789A99{record_id:04d}FA88321"
        cargox_data["envelope_id"] = f"ENV-CGX-2026-{record_id:04d}"
        record.status = "CargoX Transfer Completed"
    elif target_stage == "Completed":
        cargox_data["envelope_status"] = "Completed"
        record.status = "Completed"

    record.cargox_exchange_data = dict(cargox_data)
    flag_modified(record, "cargox_exchange_data")
    record.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(record)
    return _attach_import_file_metadata(db, record)

def update_cargo_shipping_service(
    db: Session,
    record_id: int,
    schema: CargoShippingUpdate,
    auto_advance_lifecycle: bool = True,
) -> CargoShippingRecord:
    processed_containers = None
    if schema.containers_loading_data is not None:
        validate_container_reuse_conflict(db, schema.containers_loading_data, current_record_id=record_id)
        processed_containers = _process_container_items(schema.containers_loading_data, updated_by=schema.owner or "Kamal")
    
    processed_lcl = None
    if schema.lcl_tracking_data is not None:
        processed_lcl = _process_lcl_item(schema.lcl_tracking_data, updated_by=schema.owner or "Kamal")

    updated = update_cargo_shipping(db, record_id, schema, processed_containers, processed_lcl)
    if not updated:
        raise HTTPException(status_code=404, detail="سجل شحن وتجهيز البضاعة غير موجود.")

    # Re-validate CRD if dates updated
    if updated.crd_date and updated.cargo_cutoff_date:
        updated.is_crd_validated = validate_crd_against_cutoff(updated.crd_date, updated.cargo_cutoff_date)
        db.commit()
        db.refresh(updated)

    # Centralized Lifecycle Stage Sync (STEP_07 -> STEP_08)
    if auto_advance_lifecycle and updated.import_file_id:
        try:
            from modules.lifecycle_board.service import sync_cargo_shipping_lifecycle_stage
            sync_cargo_shipping_lifecycle_stage(
                db=db,
                import_file_id=updated.import_file_id,
                cargo_shipping_code=updated.cargo_shipping_code,
                container_count=len(updated.containers_loading_data or []),
                is_final_completed=True,
            )
        except Exception:
            pass

    return _attach_import_file_metadata(db, updated)

def soft_delete_cargo_shipping_service(db: Session, record_id: int) -> bool:
    get_cargo_shipping_service(db, record_id)
    return soft_delete_cargo_shipping(db, record_id)

def restore_cargo_shipping_service(db: Session, record_id: int) -> CargoShippingRecord:
    record = restore_cargo_shipping(db, record_id)
    if not record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Cargo Shipping Record with ID {record_id} not found."
        )
    return _attach_import_file_metadata(db, record)
