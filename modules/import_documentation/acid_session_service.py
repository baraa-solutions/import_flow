"""
ACID Registration & Nafeza ACI session management service (Phase 3 - BP-014).
"""

import logging
from datetime import date, datetime, timezone, timedelta
from typing import Any, Dict, List, Optional, Set, Tuple
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

logger = logging.getLogger(__name__)

from modules.freight_booking.model import ShipmentBooking
from modules.import_companies.model import ImportCompany
from modules.cargo_shipping.model import CargoShippingRecord
from modules.suppliers.model import Supplier
from modules.import_documentation.model import POPackingReconciliationSession, DraftBLReviewSession, ShipmentDocumentItem, BankingDocumentSession, AcidRegistrationSession, CertificateOfOriginReviewSession, InspectionCertificateReviewSession, InvoiceBLMatchSession


from modules.import_documentation.model import AcidRegistrationSession
from modules.import_files.model import ImportFile
from modules.import_documentation.schemas import *
from modules.import_documentation.validators import (
    acid_flags,
    validate_acid_number,
    validate_acid_expiry,
    validate_no_duplicate_acid_session,
    validate_status,
)
import modules.import_documentation.repository as repo
from modules.common.system_messages import coded_text, msg, render_en
from modules.common.enum_codes import Placeholder, finalize_structured_values
from modules.common.file_tracking import set_file_tracking
from modules.common.errors import best_effort
from modules.common.validators import not_found, require_active
from modules.import_files.repository import codes_by_ids

from modules.import_documentation.nafeza_acid_parser import (
    parse_nafeza_acid_text,
    compare_acid_data,
    generate_whatsapp_request_text,
    generate_email_request_template,
)
from modules.import_documentation.doc_common import (
    ACID_DEFAULT_VALIDITY_DAYS,
    ACID_EXPIRING_SOON_DAYS,
    DEFAULT_ETA_DAYS,
    ETA_SAFETY_MARGIN_DAYS,
    SYSTEM_ACTOR,
    LABEL_IMPORT_FILE,
    LABEL_ACID_SESSION,
    _actor,
    _bad_request,
    _conflict,
    _active_import_file,
    _get_active_import_file,
    _check_acid_conflict,
    _require_active_po,
    _field_accepts_none,
    _commit_follow_up,
    _lifecycle_follow_up,
    get_import_files_map,
)

def enrich_acid_response(db: Session, item: AcidRegistrationSession, import_files_map: dict = None) -> AcidRegistrationResponse:
    today = date.today()
    # Safely compute days remaining — expiry_date can be None for legacy/pending records
    if item.expiry_date:
        try:
            days_rem = (item.expiry_date - today).days
        except Exception:
            days_rem = 0
    else:
        days_rem = 0
    is_ver = (
        item.status in ["Verified", "Discrepancy_Accepted"]
        and item.is_importer_matched
        and item.is_exporter_matched
        and item.is_invoice_matched
        and item.is_ports_matched
        and days_rem > 0
    )

    import_file_code = None
    if item.import_file_id:
        if import_files_map is not None:
            imp = import_files_map.get(item.import_file_id)
            if imp:
                import_file_code = imp.import_file_code or imp.custom_file_number
        else:
            import_file_code = codes_by_ids(db, [item.import_file_id]).get(item.import_file_id)

    return AcidRegistrationResponse(
        acid_id=item.acid_id,
        acid_code=item.acid_code,
        acid_number=item.acid_number,
        import_file_id=item.import_file_id,
        import_file_code=import_file_code,
        po_id=item.po_id,
        po_number=item.po_number,
        po_date=item.po_date,
        importer_id=item.importer_id,
        importer_name=item.importer_name,
        importer_tax_id=item.importer_tax_id,
        importer_address=item.importer_address,
        supplier_id=item.supplier_id,
        exporter_name=item.exporter_name,
        exporter_reg_type=item.exporter_reg_type,
        exporter_reg_id=item.exporter_reg_id,
        exporter_country=item.exporter_country,
        exporter_country_code=item.exporter_country_code,
        exporter_address=item.exporter_address,
        exporter_phone=item.exporter_phone,
        cargox_id=item.cargox_id,
        proforma_invoice_no=item.proforma_invoice_no,
        proforma_invoice_date=item.proforma_invoice_date,
        invoice_date=item.invoice_date,
        invoice_type=item.invoice_type,
        invoice_attachment_name=item.invoice_attachment_name,
        pol_name=item.pol_name,
        pod_name=item.pod_name,
        customs_broker_id=item.customs_broker_id,
        customs_broker_name=item.customs_broker_name,
        customs_broker_phone=item.customs_broker_phone,
        requested_date=item.requested_date,
        generated_date=item.generated_date,
        expiry_date=item.expiry_date,
        raw_nafeza_text=item.raw_nafeza_text,
        requested_data=item.requested_data,
        generated_data=item.generated_data,
        discrepancies_data=item.discrepancies_data,
        discrepancy_override_reason=item.discrepancy_override_reason,
        is_importer_matched=item.is_importer_matched,
        is_exporter_matched=item.is_exporter_matched,
        is_invoice_matched=item.is_invoice_matched,
        is_ports_matched=item.is_ports_matched,
        has_discrepancies=item.has_discrepancies,
        verification_notes=item.verification_notes,
        status=item.status,
        days_to_expiry=days_rem,
        execution_days=item.execution_days,
        is_verified=is_ver,
        is_active=item.is_active,
        created_at=item.created_at,
        updated_at=item.updated_at,
        created_by=item.created_by,
        updated_by=item.updated_by,
    )



def _handle_acid_verification_workflow(
    db: Session,
    db_item: AcidRegistrationSession,
    previous_status: Optional[str] = None,
    previous_ref: Optional[str] = None,
) -> None:
    """
    Central business engine workflow triggered whenever an ACID Registration Session
    is saved or updated with an issued 19-digit ACID number and verified (DC-01 / BP-014):
    1. Synchronizes ACID details into linked ImportFile (number, dates, execution days).
    2. Advances ImportFile lifecycle step from STEP_05 to STEP_06 (Booking & Carrier Space Allocation).
    3. Auto-completes prior pending SmartTasks for extracting ACID registration.
    4. Dispatches new SmartTask for Logistics Officer to proceed with Freight Booking (BK-01 / STEP_06).
    5. Emits SystemNotification for LOGISTICS_OFFICER & ALL.

    Runs after the session commit: every step is a best-effort follow-up that commits its own work (DOC-11).
    BE03-T09: Follow-ups 2-5 only fire on transition into the issued state (was not issued before, or reference number changed).
    """
    if not db_item.import_file_id:
        return

    acid_num = (db_item.acid_number or "").strip()
    is_issued_acid = len(acid_num) == 19 and acid_num.isdigit() and acid_num.upper() != "PENDING"

    imp = _get_active_import_file(db, db_item.import_file_id)
    if not imp:
        return
    file_id = imp.import_file_id

    # 1. Synchronize to ImportFile
    if is_issued_acid:
        _check_acid_conflict(db, db_item.import_file_id, acid_num)

        def _sync_file() -> None:
            imp.acid_number = acid_num
            if db_item.requested_date:
                imp.acid_request_date = db_item.requested_date
            if db_item.generated_date:
                imp.acid_issue_date = db_item.generated_date
            elif db_item.requested_date and not imp.acid_issue_date:
                imp.acid_issue_date = db_item.requested_date
            if db_item.expiry_date:
                imp.acid_expiry_date = db_item.expiry_date
            if db_item.execution_days is not None:
                imp.acid_execution_days = db_item.execution_days

        _commit_follow_up(db, _sync_file, "ACID import file sync")

    # Only advance lifecycle and dispatch next tasks if it's verified/issued (BE03-T06)
    if not (is_issued_acid and db_item.status in ["Verified", "Discrepancy_Accepted"]):
        return

    # BE03-T09: Only fire lifecycle advance, smart tasks, and notifications on transition into issued state
    prev_num = (previous_ref or "").strip()
    prev_is_issued_acid = len(prev_num) == 19 and prev_num.isdigit() and prev_num.upper() != "PENDING"
    prev_was_issued = prev_is_issued_acid and (previous_status in ["Verified", "Discrepancy_Accepted", "Generated", "Issued", "ACID Issued"])
    if prev_was_issued and prev_num == acid_num:
        return

    imp = _get_active_import_file(db, file_id)
    if not imp:
        return
    file_code = imp.import_file_code or imp.custom_file_number or f"IMP-{imp.import_file_id}"
    acid_id = db_item.acid_id
    expiry_date = db_item.expiry_date

    # 2. Advance lifecycle from STEP_05 to STEP_06 (Phase 3: Booking & Doc Prep)
    _lifecycle_follow_up(
        db, "Lifecycle advance STEP_05->STEP_06",
        completed_step_code="STEP_05",
        import_file_id=file_id,
        target_step_codes=["STEP_06"],
        auto_complete_prior=True,
        assigned_user="Logistics Officer",
        notes_msg=msg("DOC_ACID_REGISTERED", acid_number=acid_num, import_file_code=file_code),
        next_action_msg=msg("NA_STEP06_CONFIRM_BOOKING"),
        source_module="ACID Verification Engine",
        min_progress_percent=40.0,
    )

    # 3. Auto-complete prior pending SmartTasks for ACID issuance
    def _complete_prior_tasks() -> None:
        from modules.smart_tasks.model import SmartTask
        pending_acid_tasks = (
            db.query(SmartTask)
            .filter(
                SmartTask.import_file_id == file_id,
                SmartTask.status.in_(["Pending", "In Progress"]),
            )
            .all()
        )
        for t in pending_acid_tasks:
            if any(k in (t.title or "") + (t.description or "") for k in ["ACID", "نافذة", "STEP_05", "رقم القيد"]):
                t.status = "Completed"
                t.completion_notes = f"ACID {acid_num} obtained and verified via Nafeza."

    _commit_follow_up(db, _complete_prior_tasks, "Complete prior ACID smart tasks")

    # 4. Dispatch new SmartTask for Logistics Officer for Freight Booking (BK-01 / STEP_06)
    def _create_booking_task() -> None:
        from modules.smart_tasks.model import SmartTask
        from modules.smart_tasks.repository import create_task as create_smart_task
        from modules.smart_tasks.schemas import SmartTaskCreate

        booking_task_msg = msg("DOC_TASK_FREIGHT_BOOKING", import_file_code=file_code, acid_number=acid_num)

        # BE03-T09: Skip if an active non-completed task already exists for this file and message
        existing_task = (
            db.query(SmartTask)
            .filter(
                SmartTask.import_file_id == file_id,
                SmartTask.msg_code == booking_task_msg.code,
                SmartTask.is_active == True,
                SmartTask.status.in_(["Pending", "In Progress"]),
            )
            .first()
        )
        if existing_task:
            return

        task_title = render_en(booking_task_msg.code, booking_task_msg.params, "title")
        task_desc = render_en(booking_task_msg.code, booking_task_msg.params, "body")
        booking_due = date.today() + timedelta(days=3)
        task_schema = SmartTaskCreate(
            title=task_title,
            description=task_desc,
            task_type="System Generated",
            import_file_id=file_id,
            import_file_code=file_code,
            phase_name="Phase 3: Booking & Doc Prep",
            assigned_user="Logistics Officer",
            priority="High",
            reminder_type="Freight Booking",
            due_date=str(booking_due),
            status="Pending",
            notes=f"ACTION:FREIGHT_BOOKING | File: {file_code} | ACID: {acid_num}",
        )
        create_smart_task(db, task_schema, commit=False, msg_code=booking_task_msg.code, msg_params=booking_task_msg.params, created_by="ACID Verification Engine")

    _commit_follow_up(db, _create_booking_task, "Create freight booking smart task")

    # 5. Emit SystemNotification
    def _notify() -> None:
        from modules.notifications.model import SystemNotification
        acid_msg = msg(
            "DOC_ACID_REGISTERED",
            acid_number=acid_num,
            import_file_code=file_code,
            expiry_date=str(expiry_date) if expiry_date else None,
        )
        db.add(SystemNotification(
            title=render_en(acid_msg.code, acid_msg.params, "title"),
            message=render_en(acid_msg.code, acid_msg.params, "body"),
            msg_code=acid_msg.code,
            msg_params=acid_msg.params,
            severity="INFO",
            category="ACID_VERIFICATION",
            entity_type="AcidRegistrationSession",
            entity_id=acid_id,
            target_role="LOGISTICS_OFFICER",
        ))

    _commit_follow_up(db, _notify, "ACID system notification")


_ACID_PENDING_NUMBERS = frozenset({"", "PENDING", "REQUESTED", "DRAFT"})
_ACID_ISSUED_STATUSES = frozenset({"Verified", "Discrepancy_Accepted", "Generated", "Issued", "ACID Issued"})


def _acid_number_is_pending(acid_number: Optional[str]) -> bool:
    return (acid_number or "").strip().upper() in _ACID_PENDING_NUMBERS


def _apply_acid_derived_fields(item: AcidRegistrationSession) -> bool:
    """Server-derived ACID fields (DOC-15 / BE03-T06): execution days from the dates,
    match flags from discrepancies_data, and server-owned verification status.
    Returns True when something changed."""
    changed = False
    if item.generated_date and item.requested_date:
        days = max(0, (item.generated_date - item.requested_date).days)
        if item.execution_days != days:
            item.execution_days = days
            changed = True

    # 1. Server-derived match flags from discrepancies_data
    imp_m, exp_m, inv_m, port_m, has_disc = acid_flags(item.discrepancies_data)
    if (
        item.is_importer_matched != imp_m
        or item.is_exporter_matched != exp_m
        or item.is_invoice_matched != inv_m
        or item.is_ports_matched != port_m
        or item.has_discrepancies != has_disc
    ):
        item.is_importer_matched = imp_m
        item.is_exporter_matched = exp_m
        item.is_invoice_matched = inv_m
        item.is_ports_matched = port_m
        item.has_discrepancies = has_disc
        changed = True

    # 2. Server-derived status
    target_status: str
    if _acid_number_is_pending(item.acid_number) or not item.generated_date:
        target_status = "Requested"
    elif not item.has_discrepancies:
        target_status = "Verified"
    elif item.discrepancy_override_reason and item.discrepancy_override_reason.strip():
        target_status = "Discrepancy_Accepted"
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="يوجد اختلافات في بيانات الـ ACID: يجب كتابة مبرر قبول الاختلافات.",
        )

    if item.status != target_status:
        item.status = target_status
        changed = True

    return changed


def create_acid_session_service(
    db: Session, schema: AcidRegistrationCreate, user: Optional[str] = None
) -> AcidRegistrationResponse:
    validate_acid_number(schema.acid_number, allow_pending=True)
    validate_acid_expiry(schema.expiry_date, schema.requested_date)
    if schema.import_file_id is not None:
        _active_import_file(db, schema.import_file_id)
        _check_acid_conflict(db, schema.import_file_id, schema.acid_number)
    _require_active_po(db, schema.po_id)

    # Check if an active session already exists for this import file - if so, seamlessly update it (Upsert)
    if schema.import_file_id:
        existing = (
            db.query(AcidRegistrationSession)
            .filter(
                AcidRegistrationSession.import_file_id == schema.import_file_id,
                AcidRegistrationSession.is_active == True,
            )
            .first()
        )
        if existing:
            prev_status = existing.status
            prev_ref = existing.acid_number
            update_data = schema.model_dump(exclude_unset=True)
            for f in repo._SERVER_OWNED_ACID_FIELDS:
                update_data.pop(f, None)
            for k, v in update_data.items():
                if hasattr(existing, k) and v is not None:
                    setattr(existing, k, v)
            if user is not None:
                existing.updated_by = user
            if hasattr(existing, "set_updated_info"):
                existing.set_updated_info()
            _apply_acid_derived_fields(existing)

            db.commit()
            db.refresh(existing)

            # Trigger ACID verification and synchronization workflow
            _handle_acid_verification_workflow(db, existing, previous_status=prev_status, previous_ref=prev_ref)
            return enrich_acid_response(db, existing)

    db_item = repo.create_acid_session(db, schema, commit=False, user=user)

    # DOC-15: no expiry sent -> issue (or request) date + ACID_DEFAULT_VALIDITY_DAYS, the same default the tracker
    # uses. The column is NOT NULL, so "leave it null" needs a schema change (deferred); never "today" any more.
    if schema.expiry_date is None:
        base = db_item.generated_date or db_item.requested_date or date.today()
        default_expiry = base + timedelta(days=ACID_DEFAULT_VALIDITY_DAYS)
        if db_item.expiry_date != default_expiry:
            db_item.expiry_date = default_expiry
    _apply_acid_derived_fields(db_item)
    db.commit()
    db.refresh(db_item)

    # Trigger ACID verification and synchronization workflow
    _handle_acid_verification_workflow(db, db_item, previous_status=None, previous_ref=None)

    return enrich_acid_response(db, db_item)


def update_acid_session_service(
    db: Session, acid_id: int, schema: AcidRegistrationUpdate, user: Optional[str] = None
) -> AcidRegistrationResponse:
    validate_status("acid", schema.status)
    db_item = repo.get_acid_session_by_id(db, acid_id)
    if not db_item:
        raise not_found(LABEL_ACID_SESSION, acid_id)

    if schema.import_file_id is not None:
        _active_import_file(db, schema.import_file_id)
        validate_no_duplicate_acid_session(db, schema.import_file_id, current_acid_id=acid_id)

    # BE03-T06: the duplicate-session rule (400) is checked before the file ACID conflict (409).
    target_file_id = schema.import_file_id if schema.import_file_id is not None else db_item.import_file_id
    target_acid_num = schema.acid_number if schema.acid_number else db_item.acid_number
    _check_acid_conflict(db, target_file_id, target_acid_num)
    if "po_id" in schema.model_fields_set:
        _require_active_po(db, schema.po_id)

    if schema.acid_number:
        validate_acid_number(schema.acid_number, allow_pending=True)

    # DOC-15: the expiry rule applies on update too, whenever a date changes.
    if {"expiry_date", "requested_date"} & schema.model_fields_set:
        new_expiry = schema.expiry_date if "expiry_date" in schema.model_fields_set else db_item.expiry_date
        new_requested = schema.requested_date if "requested_date" in schema.model_fields_set else db_item.requested_date
        if new_expiry is not None:
            validate_acid_expiry(new_expiry, new_requested)

    prev_status = db_item.status
    prev_ref = db_item.acid_number
    # BE03-T06: Drop status and match flags before repo update
    payload_data = schema.model_dump(exclude_unset=True)
    for f in repo._SERVER_OWNED_ACID_FIELDS:
        payload_data.pop(f, None)

    # DOC-15: expiry_date and requested_date are NOT NULL at database level.
    # If the update payload sends None, preserve existing value or apply safe business default.
    if "expiry_date" in payload_data and payload_data["expiry_date"] is None:
        if db_item.expiry_date is not None:
            payload_data.pop("expiry_date", None)
        else:
            base = payload_data.get("generated_date") or db_item.generated_date or payload_data.get("requested_date") or db_item.requested_date or date.today()
            if isinstance(base, datetime):
                base = base.date()
            payload_data["expiry_date"] = base + timedelta(days=ACID_DEFAULT_VALIDITY_DAYS)

    if "requested_date" in payload_data and payload_data["requested_date"] is None:
        if db_item.requested_date is not None:
            payload_data.pop("requested_date", None)
        else:
            payload_data["requested_date"] = date.today()

    updated = repo.update_acid_session(db, db_item, payload_data, commit=False, user=user)

    _apply_acid_derived_fields(updated)
    db.commit()
    db.refresh(updated)

    # Trigger ACID verification and synchronization workflow
    _handle_acid_verification_workflow(db, updated, previous_status=prev_status, previous_ref=prev_ref)

    return enrich_acid_response(db, updated)


def list_acid_sessions_service(
    db: Session,
    include_inactive: bool = False,
    search: Optional[str] = None,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    skip: int = 0,
    limit: Optional[int] = None,
    return_total: bool = False,
) -> Union[List[AcidRegistrationResponse], Tuple[List[AcidRegistrationResponse], int]]:
    """ACID sessions with the import file code, one bulk file query (DOC-17 / DOC-24)."""
    res = repo.get_all_acid_sessions(
        db,
        include_inactive=include_inactive,
        search=search,
        import_file_id=import_file_id,
        status=status,
        skip=skip,
        limit=limit,
        return_total=return_total,
    )
    if return_total:
        items, total = res
    else:
        items, total = res, len(res)

    if not items:
        return ([], total) if return_total else []
    import_files_map = get_import_files_map(db, [item.import_file_id for item in items])
    enriched = [enrich_acid_response(db, item, import_files_map=import_files_map) for item in items]
    return (enriched, total) if return_total else enriched


def get_acid_session_service(db: Session, acid_id: int) -> AcidRegistrationResponse:
    item = repo.get_acid_session_by_id(db, acid_id)
    if not item:
        raise not_found(LABEL_ACID_SESSION, acid_id)
    return enrich_acid_response(db, item)


def _acid_tracker_status(acid_number: Optional[str], days_rem: int, is_released: bool) -> Tuple[str, str, bool]:
    """(status, deprecated Arabic label, alert_required) for one tracker row. Buckets: released, pending number,
    <= 0 days Expired, <= ACID_EXPIRING_SOON_DAYS Expiring Soon, else Valid."""
    if is_released:
        return "Customs Released", "صُرفت من الجمرك (معفى من التنبيه)", False
    if _acid_number_is_pending(acid_number):
        return "Pending Issue", "قيد استخراج الـ ACID", False
    if days_rem <= 0:
        return "Expired", f"منتهي الصلاحية (منذ {abs(days_rem)} يوم)", True
    if days_rem <= ACID_EXPIRING_SOON_DAYS:
        return "Expiring Soon", f"يوشك على الانتهاء (متبقي {days_rem} يوم)", True
    return "Valid", f"ساري وصالح (متبقي {days_rem} يوم)", False


def _tracker_message(status_value: str, days_rem: int) -> Dict[str, Any]:
    # DOC-19 / C6: language-neutral twin of status_label_ar (code registered centrally, see review-shared-needs.md).
    return {"message_code": "DOC_ACID_TRACKER_STATUS", "message_params": {"status": status_value, "days": days_rem}}


def get_acid_tracker_service(db: Session):
    from modules.customs_clearance.model import CustomsClearanceRecord
    from modules.import_documentation.schemas import AcidTrackerItem, AcidTrackerSummary

    today = date.today()
    items = []
    names_nullable = _field_accepts_none(AcidTrackerItem, "importer_name")
    blank_name = None if names_nullable else ""

    # Map clearances for rapid release check
    clearances = db.query(CustomsClearanceRecord).filter(CustomsClearanceRecord.is_active == True).all()
    clearance_by_file = {}
    for cl in clearances:
        if cl.import_file_id not in clearance_by_file:
            clearance_by_file[cl.import_file_id] = cl
        elif cl.dispatch_authorized or cl.release_permit_no:
            clearance_by_file[cl.import_file_id] = cl

    # Query all acid sessions
    acid_sessions = db.query(AcidRegistrationSession).filter(AcidRegistrationSession.is_active == True).all()
    acid_sessions_by_file = {s.import_file_id: s for s in acid_sessions if s.import_file_id}
    processed_session_ids = set()

    # Query all import files (single-laptop scale: DOC-24 keeps this as is)
    import_files = db.query(ImportFile).filter(ImportFile.is_active == True).all()

    for imp in import_files:
        acid_sess = acid_sessions_by_file.get(imp.import_file_id)
        if acid_sess:
            processed_session_ids.add(acid_sess.acid_id)

        acid_num = imp.acid_number or (acid_sess.acid_number if acid_sess else None)
        if not acid_num and not acid_sess:
            continue

        acid_issue_date = imp.acid_issue_date or (acid_sess.generated_date if acid_sess else None) or (acid_sess.requested_date if acid_sess else None)
        acid_expiry_date = imp.acid_expiry_date or (acid_sess.expiry_date if acid_sess else None)
        if not acid_expiry_date and acid_issue_date:
            acid_expiry_date = acid_issue_date + timedelta(days=ACID_DEFAULT_VALIDITY_DAYS)

        cl = clearance_by_file.get(imp.import_file_id)
        is_released = (
            imp.is_customs_released
            or (cl is not None and (cl.dispatch_authorized or bool(cl.release_permit_no) or cl.status in ["Final Release Granted", "Cleared", "Completed"]))
            or imp.current_stage in ["Phase 8 - Warehouse Receiving", "Phase 9 - Financial Settlement", "Phase 10 - Closure", "Warehouse Received", "Closed"]
        )
        customs_released_at = imp.customs_released_at or (cl.release_date if cl else None) or (cl.dispatch_date if cl else None)
        release_permit_no = cl.release_permit_no if cl else None

        days_rem = (acid_expiry_date - today).days if acid_expiry_date else ACID_DEFAULT_VALIDITY_DAYS
        total_days = (acid_expiry_date - acid_issue_date).days if (acid_expiry_date and acid_issue_date) else ACID_DEFAULT_VALIDITY_DAYS
        if total_days <= 0:
            total_days = ACID_DEFAULT_VALIDITY_DAYS
        validity_pct = max(0.0, min(100.0, (days_rem / total_days) * 100.0)) if not is_released else 100.0

        status, status_label_ar, alert_required = _acid_tracker_status(acid_num, days_rem, is_released)

        items.append(
            AcidTrackerItem(
                import_file_id=imp.import_file_id,
                import_file_code=imp.import_file_code or imp.custom_file_number,
                custom_file_number=imp.custom_file_number,
                acid_session_id=acid_sess.acid_id if acid_sess else None,
                acid_code=acid_sess.acid_code if acid_sess else None,
                acid_number=acid_num or "PENDING",
                importer_name=imp.company_name or (acid_sess.importer_name if acid_sess else None) or blank_name,
                supplier_name=imp.supplier_name or (acid_sess.exporter_name if acid_sess else None) or blank_name,
                po_number=imp.po_number or (acid_sess.po_number if acid_sess else None),
                pi_number=imp.pi_number or (acid_sess.proforma_invoice_no if acid_sess else None),
                shipment_mode=imp.shipment_mode,
                current_stage=imp.current_stage,
                customs_broker_name=imp.broker_name or (acid_sess.customs_broker_name if acid_sess else None),
                acid_issue_date=acid_issue_date,
                acid_expiry_date=acid_expiry_date,
                execution_days=imp.acid_execution_days or (acid_sess.execution_days if acid_sess else None),
                days_remaining=days_rem,
                total_validity_days=total_days,
                validity_percentage=round(validity_pct, 1),
                is_customs_released=is_released,
                customs_released_at=customs_released_at,
                release_permit_no=release_permit_no,
                status=status,
                status_label_ar=status_label_ar,
                alert_required=alert_required,
                **_tracker_message(status, days_rem),
            )
        )

    # Standalone acid sessions
    for sess in acid_sessions:
        if sess.acid_id in processed_session_ids:
            continue
        days_rem = (sess.expiry_date - today).days if sess.expiry_date else ACID_DEFAULT_VALIDITY_DAYS
        total_days = (sess.expiry_date - (sess.generated_date or sess.requested_date)).days if sess.expiry_date else ACID_DEFAULT_VALIDITY_DAYS
        if total_days <= 0:
            total_days = ACID_DEFAULT_VALIDITY_DAYS
        validity_pct = max(0.0, min(100.0, (days_rem / total_days) * 100.0))

        if sess.acid_number == "PENDING":
            status, status_label_ar, alert_required = "Pending Issue", "قيد استخراج الـ ACID", False
        else:
            # Same buckets; "pending" here means the literal PENDING number only (unchanged behaviour).
            status, status_label_ar, alert_required = _acid_tracker_status("X", days_rem, False)

        items.append(
            AcidTrackerItem(
                import_file_id=None,
                import_file_code=None,
                custom_file_number=None,
                acid_session_id=sess.acid_id,
                acid_code=sess.acid_code,
                acid_number=sess.acid_number,
                importer_name=sess.importer_name,
                supplier_name=sess.exporter_name,
                po_number=sess.po_number,
                pi_number=sess.proforma_invoice_no,
                shipment_mode=None,
                current_stage="ACID Registration",
                customs_broker_name=sess.customs_broker_name,
                acid_issue_date=sess.generated_date or sess.requested_date,
                acid_expiry_date=sess.expiry_date,
                execution_days=sess.execution_days,
                days_remaining=days_rem,
                total_validity_days=total_days,
                validity_percentage=round(validity_pct, 1),
                is_customs_released=False,
                customs_released_at=None,
                release_permit_no=None,
                status=status,
                status_label_ar=status_label_ar,
                alert_required=alert_required,
                **_tracker_message(status, days_rem),
            )
        )

    valid_count = sum(1 for i in items if i.status == "Valid")
    expiring_soon_count = sum(1 for i in items if i.status == "Expiring Soon")
    expired_count = sum(1 for i in items if i.status == "Expired")
    customs_released_count = sum(1 for i in items if i.status == "Customs Released")
    pending_issue_count = sum(1 for i in items if i.status == "Pending Issue")

    return AcidTrackerSummary(
        total_acids_count=len(items),
        valid_count=valid_count,
        expiring_soon_count=expiring_soon_count,
        expired_count=expired_count,
        customs_released_count=customs_released_count,
        pending_issue_count=pending_issue_count,
        items=items,
    )


def parse_acid_text_service(
    db: Session, raw_text: str, import_file_id: int | None = None
) -> dict:
    parsed = parse_nafeza_acid_text(raw_text)
    comparison = None

    if import_file_id:
        from modules.suppliers.model import Supplier
        from modules.import_companies.model import ImportCompany

        file_obj = _get_active_import_file(db, import_file_id)
        if file_obj:
            comp_obj = db.query(ImportCompany).filter(ImportCompany.company_id == file_obj.company_id).first() if file_obj.company_id else None
            supp_obj = db.query(Supplier).filter(Supplier.supplier_id == file_obj.supplier_id).first() if file_obj.supplier_id else None

            requested_dict = {
                "importer_name": comp_obj.importer_name if comp_obj else file_obj.company_name,
                "importer_tax_id": comp_obj.vat_id if comp_obj else "",
                "exporter_name": supp_obj.company_name if supp_obj else file_obj.supplier_name,
                "exporter_reg_type": supp_obj.registration_type if supp_obj else "VAT Number",
                "exporter_reg_id": supp_obj.foreign_exporter_id if supp_obj else "",
                "exporter_country": supp_obj.foreign_exporter_country if supp_obj else "",
                "exporter_country_code": supp_obj.foreign_exporter_country_code if supp_obj else "",
                "proforma_invoice_no": file_obj.pi_number or "",
                "pol_name": "",
                "pod_name": "",
                "cargox_id": getattr(supp_obj, "cargox_platform_id", None) or "",
            }
            comparison = compare_acid_data(requested_dict, parsed)

    return {
        "parsed_data": parsed,
        "comparison": comparison,
    }


def compare_acid_datasets_service(requested: dict, generated: dict) -> dict:
    return compare_acid_data(requested, generated)


def generate_acid_templates_service(req_data: dict) -> dict:
    wa_text = generate_whatsapp_request_text(req_data)
    email_dict = generate_email_request_template(req_data)
    return {
        "whatsapp_text": wa_text,
        "email_subject": email_dict["subject"],
        "email_body": email_dict["body"],
    }


def restore_acid_session_service(db: Session, acid_id: int, user: Optional[str] = None) -> AcidRegistrationResponse:
    item = repo.restore_acid_session(db, acid_id)
    if not item:
        raise not_found(LABEL_ACID_SESSION, acid_id)
    db.commit()
    db.refresh(item)
    return enrich_acid_response(db, item)


def soft_delete_acid_session_service(db: Session, acid_id: int, user: Optional[str] = None) -> bool:
    if not repo.soft_delete_acid_session(db, acid_id):
        raise not_found(LABEL_ACID_SESSION, acid_id)
    db.commit()
    return True



def get_all_acid_sessions_service(
    db: Session,
    include_inactive: bool = False,
    search: str = None,
    import_file_id: int = None,
    status: str = None,
    skip: int = 0,
    limit: int | None = None,
    return_total: bool = False,
):
    return repo.get_all_acid_sessions(
        db,
        include_inactive=include_inactive,
        search=search,
        import_file_id=import_file_id,
        status=status,
        skip=skip,
        limit=limit,
        return_total=return_total,
    )

def get_acid_session_by_id_service(db: Session, acid_id: int):
    return repo.get_acid_session_by_id(db, acid_id)

