"""
Import File Hold & Regulatory Clearance Service (ملفات الاستيراد - خدمات تعليق وإيقاف الشحنات).

Handles:
- Hold codes, reasons, and stage-specific pausing
- Resuming held shipments and clearing hold metadata
- Regulatory clearance locks, inspection halts, and release validations
- Audit logging for hold and resume events with multilingual system messages
"""

import logging
from datetime import datetime
from typing import Optional

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.audit_logs.service import AuditLogService
from modules.common import enum_codes
from modules.common.errors import CodedHTTPException
from modules.common.system_messages import msg, render_en
from modules.import_files.model import ImportFile
import modules.import_files.repository as repo
import modules.import_files.validators as validators

logger = logging.getLogger(__name__)


def hold_import_file_service(
    db: Session,
    import_file_id: int,
    hold_reason: str,
    hold_notes: Optional[str] = None,
    stage_name: Optional[str] = None,
    step_name: Optional[str] = None,
    hold_reason_code: Optional[str] = None,
    performed_by: str = "System",
) -> ImportFile:
    """Put a shipment on hold.

    The file's user ``notes`` are never touched: the system text goes to the lifecycle activity notes
    (``LC_STEP_ON_HOLD*``) and to an ``audit_logs`` HOLD entry (which also keeps ``hold_notes``).
    ``hold_reason_code`` must be a HOLD_REASON code; a legacy chip label in ``hold_reason`` is mapped to
    its code. ``paused_at_stage`` holds an English title resolved from the stage code when possible."""
    existing = repo.get_import_file_by_id(db, import_file_id)
    if not existing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ملف الاستيراد '{import_file_id}' غير موجود.",
        )

    validators.validate_status_transition(existing.status, "On Hold")

    if not hold_reason or not hold_reason.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="يلزم إدخال سبب إيقاف وتعليق الشحنة.",
        )

    reason_text = hold_reason.strip()
    if hold_reason_code:
        reason_code = enum_codes.normalize(enum_codes.HOLD_REASON, hold_reason_code)
        if not enum_codes.is_code(enum_codes.HOLD_REASON, reason_code):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="رمز سبب الإيقاف غير معروف",
            )
    else:
        derived = enum_codes.normalize(enum_codes.HOLD_REASON, reason_text)
        reason_code = derived if enum_codes.is_code(enum_codes.HOLD_REASON, derived) else None

    from modules.lifecycle_board.service import hold_shipment_activities_service, resolve_hold_stage

    now_dt = datetime.now()
    resolved = resolve_hold_stage(stage_name, step_name)
    stage = resolved["stage_title"] or stage_name or existing.current_stage
    step = resolved["step_code"] or step_name or existing.current_step_code or existing.current_module

    update_dict = {
        "status": "On Hold",
        "paused_at_stage": stage,
        "paused_at_step": step,
        "hold_reason": reason_text,
        "hold_reason_code": reason_code,
        "hold_date": now_dt,
        "updated_by": performed_by,
    }

    # Lifecycle board activities get the system note; a failure must not block the hold itself.
    try:
        hold_shipment_activities_service(db, existing.import_file_code, reason_text, reason_code)
    except Exception as exc:
        db.rollback()
        logger.error("Hold: lifecycle activities of %s not updated: %s", existing.import_file_code, exc, exc_info=True)

    updated = repo.update_import_file(db, import_file_id, update_dict)

    # Language-independent params: the phase id (rendered as the phase name) and the reason code or user text.
    hold_phase_id = resolved["phase_id"] or existing.current_phase_id
    notes_text = hold_notes.strip() if hold_notes and hold_notes.strip() else None
    base_code = "LC_FILE_ON_HOLD_CODED" if reason_code else "LC_FILE_ON_HOLD"
    reason_params = {"reason_enum_hold_reason": reason_code} if reason_code else {"reason": reason_text}
    if notes_text:
        note = msg(f"{base_code}_WITH_NOTES", phase_id=hold_phase_id, notes=notes_text, **reason_params)
    else:
        note = msg(base_code, phase_id=hold_phase_id, **reason_params)
    AuditLogService(db).log_activity(
        entity_type="ImportFile",
        entity_id=existing.import_file_id,
        entity_code=existing.import_file_code,
        action="HOLD",
        new_data={"msg_code": note.code, "msg_params": note.params, "hold_reason_code": reason_code},
        performed_by=performed_by,
        changes_summary=render_en(note.code, note.params, "note"),
    )
    return updated


def resume_import_file_service(
    db: Session,
    import_file_id: int,
    resume_notes: Optional[str] = None,
    performed_by: str = "System",
) -> ImportFile:
    """Resume a held shipment. Like hold, the file's user ``notes`` are left untouched: the system text goes
    to the lifecycle activities and an ``audit_logs`` RESUME entry."""
    existing = repo.get_import_file_by_id(db, import_file_id)
    if not existing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ملف الاستيراد '{import_file_id}' غير موجود.",
        )

    if existing.status != "On Hold":
        validators.validate_status_transition(existing.status, "In Progress")

        raise CodedHTTPException(
            status_code=status.HTTP_409_CONFLICT,
            code="IF_STATUS_TRANSITION_INVALID",
            message_ar=f"لا يمكن استئناف ملف الشحنة وهو في حالة '{existing.status}'.",
            **{"from": existing.status or "", "to": "In Progress"},
        )

    validators.validate_status_transition(existing.status, "In Progress")

    update_dict = {
        "status": "In Progress",
        "hold_reason": None,
        "hold_reason_code": None,
        "hold_date": None,
        "updated_by": performed_by,
    }

    from modules.lifecycle_board.service import resume_shipment_activities_service

    try:
        resume_shipment_activities_service(db, existing.import_file_code, resume_notes)
    except Exception as exc:
        db.rollback()
        logger.error("Resume: lifecycle activities of %s not updated: %s", existing.import_file_code, exc, exc_info=True)

    updated = repo.update_import_file(db, import_file_id, update_dict)

    note = (
        msg("LC_FILE_RESUMED", notes=resume_notes.strip())
        if resume_notes and resume_notes.strip()
        else msg("LC_FILE_RESUMED_DEFAULT")
    )
    AuditLogService(db).log_activity(
        entity_type="ImportFile",
        entity_id=existing.import_file_id,
        entity_code=existing.import_file_code,
        action="RESUME",
        new_data={"msg_code": note.code, "msg_params": note.params},
        performed_by=performed_by,
        changes_summary=render_en(note.code, note.params, "note"),
    )
    return updated


def validate_regulatory_clearance_lock(import_file: ImportFile) -> None:
    """Validates that the import file is not subject to a regulatory hold or clearance lock."""
    if import_file.status == "On Hold":
        raise CodedHTTPException(
            status_code=status.HTTP_409_CONFLICT,
            code="IF_FILE_ON_HOLD",
            message_ar=f"ملف الشحنة '{import_file.import_file_code}' معلق حالياً ولا يمكن متابعة الإجراء الجمركي.",
            import_file_code=import_file.import_file_code,
            hold_reason=import_file.hold_reason or "",
        )


def validate_release_readiness(import_file: ImportFile) -> None:
    """Validates that a shipment is eligible for customs release."""
    if import_file.status in ("Closed", "Archived"):
        raise CodedHTTPException(
            status_code=status.HTTP_409_CONFLICT,
            code="IF_FILE_ALREADY_CLOSED",
            message_ar=f"ملف الشحنة '{import_file.import_file_code}' مغلق بالفعل.",
            import_file_code=import_file.import_file_code,
        )
    if import_file.status == "On Hold":
        raise CodedHTTPException(
            status_code=status.HTTP_409_CONFLICT,
            code="IF_FILE_ON_HOLD",
            message_ar=f"ملف الشحنة '{import_file.import_file_code}' معلق ولا يمكن الإفراج الجمركي عنه قبل الاستئناف.",
            import_file_code=import_file.import_file_code,
            hold_reason=import_file.hold_reason or "",
        )


def apply_inspection_halt_service(
    db: Session,
    import_file_id: int,
    halt_reason: str,
    inspection_notes: Optional[str] = None,
    performed_by: str = "System",
) -> ImportFile:
    """Puts a shipment on hold specifically due to customs/regulatory inspection requirements."""
    return hold_import_file_service(
        db=db,
        import_file_id=import_file_id,
        hold_reason=halt_reason,
        hold_notes=inspection_notes,
        hold_reason_code="ADDITIONAL_INSPECTION",
        performed_by=performed_by,
    )
