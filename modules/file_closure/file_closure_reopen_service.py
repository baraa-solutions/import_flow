"""
Sub-service for reopening protocol, supervisor overrides, justification logging,
and audit trail verification for closed import files and closure records.
"""
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from .model import ImportFileClosureRecord
from .helpers import (
    _get_active_file,
    _require_any_permission,
    CLOSURE_MODULE,
)
from . import repository as repo
from modules.audit_logs.model import AuditLog
from modules.common.errors import best_effort
from modules.common.file_tracking import set_file_tracking
from modules.common.system_messages import msg, render_en
from modules.import_files.model import ImportFile
from modules.notifications.model import SystemNotification
from modules.users.model import User

REOPEN_PERMISSIONS = ("import_files.close", "import_files.admin", "admin")


def validate_can_reopen_file(
    db: Session,
    imp: ImportFile,
    actor: Optional[User] = None,
    trusted: bool = False,
) -> None:
    """
    Validate that an import file is eligible for reopening:
    1. Actor must hold supervisor/admin closure permissions.
    2. File must currently be in Closed status.
    """
    _require_any_permission(db, actor, *REOPEN_PERMISSIONS, trusted=trusted)

    if imp.status != "Closed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"ملف الشحنة {imp.import_file_code} غير مغلق حالياً (الحالة الحالية: {imp.status}). لا يمكن إعادة فتح ملف مفتوح.",
        )


def reopen_closed_file_service(
    db: Session,
    import_file_id: int,
    justification: str,
    supervisor_actor: Optional[User] = None,
    override_locked_records: bool = False,
    trusted: bool = False,
) -> Dict[str, Any]:
    """
    Protocol to reopen a closed import file and its associated closure records.
    - Requires supervisor permission.
    - Requires non-empty business justification.
    - Transitions file status from Closed -> In Progress.
    - Restores previous module/phase and tracking.
    - Marks active closure record as 'Reopened'.
    - Logs audit activity and dispatches system notification.
    """
    if not justification or not justification.strip() or len(justification.strip()) < 3:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="يلزم إدخال سبب ومبرر رسمي لإعادة فتح الملف (3 أحرف على الأقل).",
        )

    imp = _get_active_file(db, import_file_id)
    validate_can_reopen_file(db, imp, actor=supervisor_actor, trusted=trusted)

    actor_username = supervisor_actor.username if supervisor_actor else "Supervisor"
    justification_clean = justification.strip()

    # 1. Restore previous phase or default
    restored_phase = imp.closed_at_phase or "Phase 1 - Import Planning & Feasibility"
    old_status = imp.status
    old_module = imp.current_module

    imp.status = "In Progress"
    imp.current_module = restored_phase
    imp.current_stage = f"Reopened at {restored_phase} - {justification_clean}"
    imp.closure_reason = None
    imp.closed_at_phase = None
    imp.updated_by = actor_username
    imp.updated_at = datetime.now(timezone.utc)
    set_file_tracking(imp, stage_code="REOPENED_IN_PROGRESS", next_action=msg("NA_RESUME_OPERATIONS"))

    # 2. Update active closure record if present
    closure_rec = repo.get_closure_by_import_file_id(db, import_file_id)
    closure_code = None
    if closure_rec:
        closure_code = closure_rec.closure_code
        closure_rec.status = "Reopened"
        closure_rec.updated_at = datetime.now(timezone.utc)
        closure_rec.updated_by = actor_username

    # 3. Create Audit Trail
    import json
    audit = AuditLog(
        entity_type="ImportFile",
        entity_id=import_file_id,
        entity_code=imp.import_file_code,
        action="REOPEN",
        changes_summary=f"Supervisor override reopen: {justification_clean}",
        old_values=json.dumps({"status": old_status, "current_module": old_module}),
        new_values=json.dumps({
            "status": "In Progress",
            "current_module": restored_phase,
            "justification": justification_clean,
            "closure_code": closure_code,
        }),
        performed_at=datetime.now(timezone.utc),
        performed_by=actor_username,
    )
    db.add(audit)

    # 4. System Notification
    db.add(SystemNotification(
        title=f"Shipment Reopened: {imp.import_file_code}",
        message=f"Import file {imp.import_file_code} has been officially reopened by supervisor {actor_username}. Reason: {justification_clean}",
        msg_code="CLO_FILE_REOPENED",
        msg_params={"import_file_code": imp.import_file_code, "justification": justification_clean, "reopened_by": actor_username},
        severity="WARNING",
        category="FILE_CLOSURE",
        entity_type="ImportFile",
        entity_id=import_file_id,
        target_role="ALL",
    ))

    db.commit()
    db.refresh(imp)
    if closure_rec:
        db.refresh(closure_rec)

    return {
        "success": True,
        "import_file_id": imp.import_file_id,
        "import_file_code": imp.import_file_code,
        "status": imp.status,
        "current_module": imp.current_module,
        "restored_phase": restored_phase,
        "closure_code": closure_code,
        "justification": justification_clean,
        "reopened_by": actor_username,
        "message": f"تمت إعادة فتح ملف الشحنة {imp.import_file_code} بنجاح واستعادة العمل على المرحلة ({restored_phase}).",
    }


def reopen_closure_record_service(
    db: Session,
    closure_id: int,
    justification: str,
    actor: Optional[User] = None,
    trusted: bool = False,
) -> ImportFileClosureRecord:
    """
    Supervisor override to reopen a specific closure record for modifications.
    """
    _require_any_permission(db, actor, *REOPEN_PERMISSIONS, trusted=trusted)
    record = repo.get_closure_by_id(db, closure_id)
    if not record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"سجل إغلاق الملف رقم {closure_id} غير موجود.",
        )

    if not justification or not justification.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="يلزم إدخال سبب ومبرر رسمي لإعادة فتح سجل الإغلاق.",
        )

    actor_username = actor.username if actor else "Supervisor"
    old_status = record.status
    record.status = "Reopened"
    record.updated_by = actor_username
    record.updated_at = datetime.now(timezone.utc)

    def _audit_record_reopen():
        from modules.audit_logs.service import AuditLogService
        AuditLogService(db).log_activity(
            entity_type="ImportFileClosureRecord",
            entity_id=record.closure_id,
            entity_code=record.closure_code,
            action="REOPEN",
            old_data={"status": old_status},
            new_data={"status": "Reopened", "justification": justification.strip()},
            performed_by=actor_username,
        )

    best_effort(db, _audit_record_reopen, "Closure record reopen audit log")
    db.commit()
    db.refresh(record)
    return record


def get_closure_reopen_history(db: Session, import_file_id: int) -> List[Dict[str, Any]]:
    """
    Retrieve audit trail of reopen events for an import file.
    """
    audits = (
        db.query(AuditLog)
        .filter(
            AuditLog.entity_type == "ImportFile",
            AuditLog.entity_id == import_file_id,
            AuditLog.action == "REOPEN",
        )
        .order_by(AuditLog.log_id.desc())
        .all()
    )
    return [
        {
            "log_id": a.log_id,
            "action": a.action,
            "performed_by": a.performed_by,
            "performed_at": a.performed_at.isoformat() if a.performed_at else None,
            "changes_summary": a.changes_summary,
            "old_values": a.old_values,
            "new_values": a.new_values,
        }
        for a in audits
    ]
