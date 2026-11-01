"""
Shipment Lifecycle Step Management Sub-Service
Handles step configuration management, station SLAs, step validation rules, prerequisite gates, and lifecycle transitions.
"""

import json
import logging
import sys
from datetime import datetime
from typing import List, Dict, Any, Optional
from sqlalchemy import and_, func, or_
from sqlalchemy.orm import Session

from fastapi import HTTPException, status

import modules.lifecycle_board.repository as repo
import modules.lifecycle_board.validators as validators
from modules.lifecycle_board.model import StepConfig, StepConfigAuditLog, PendingReferenceRecord
from modules.audit_logs.model import AuditLog
from modules.import_files.model import ImportFile
from modules.users.model import Role, User
from modules.common import enum_codes
from modules.common.errors import CodedHTTPException
from modules.common.system_messages import SysMsg, msg, render_en
from modules.common.file_tracking import phase_title_en, set_file_tracking
from modules.auth.permissions import is_admin_user
from modules.lifecycle_board.schemas import (
    StageActivityResponse,
    StepAdvancePayload,
    MultiStageSetPayload,
    SkipStepPayload,
    StepConfigResponse,
    StepConfigUpdateRequest,
    StepConfigAuditLogResponse,
    RegisterPendingReferenceRequest,
    RegisterPendingReferenceResponse,
)
from modules.lifecycle_board.lifecycle_kanban_service import (
    ORDERED_STEP_CODES,
    STEP_TO_PHASE_MAP,
    STEP_NAME_MAP,
    PHASES_DEFINITION,
    get_step_neighbors,
)

logger = logging.getLogger(__name__)

# SKIP_REASON_CATEGORY codes (modules/common/enum_codes.py). Existing step_configs rows keep their legacy
# bilingual strings; the UI maps them with DomainEnums.legacyToCode.
DEFAULT_REASON_CATEGORIES = enum_codes.codes(enum_codes.SKIP_REASON_CATEGORY)


def _ensure_step_configs(db: Session) -> None:
    existing = {cfg.step_code: cfg for cfg in repo.get_all_step_configs(db)}
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    added = False
    for p in PHASES_DEFINITION:
        for code, names in p["step_names"].items():
            if code not in existing:
                cfg = StepConfig(
                    step_code=code,
                    step_name_en=names[0],
                    step_name_ar=names[1],
                    phase_id=p["phase_id"],
                    skip_policy="blocked",  # Safest default (Section 10.2)
                    reason_required=True,
                    reason_categories=DEFAULT_REASON_CATEGORIES,
                    approver_roles=["Manager"],  # Manager fallback (Section 10.7 & 10.8)
                    supports_pending_reference=False,
                    last_modified_by="SYSTEM",
                    last_modified_at=now_str,
                )
                db.add(cfg)
                added = True
    if added:
        db.commit()


def get_all_step_configs_service(db: Session) -> List[StepConfigResponse]:
    _ensure_step_configs(db)
    configs = repo.get_all_step_configs(db)
    return [StepConfigResponse.model_validate(c) for c in configs]


def get_step_config_service(db: Session, step_code: str) -> StepConfigResponse:
    validators.validate_step_code(step_code)
    cfg = repo.get_step_config(db, step_code)
    if not cfg:
        # Default state = safest option (Section 10.2)
        en_name, ar_name = STEP_NAME_MAP.get(step_code, (step_code, step_code))
        phase_id = STEP_TO_PHASE_MAP.get(step_code, 1)
        return StepConfigResponse(
            id=0,
            step_code=step_code,
            step_name_ar=ar_name,
            step_name_en=en_name,
            phase_id=phase_id,
            skip_policy="blocked",
            reason_required=True,
            reason_categories=DEFAULT_REASON_CATEGORIES,
            approver_roles=["Manager"],
            supports_pending_reference=False,
            last_modified_by="DEFAULT",
            last_modified_at=None,
        )
    return StepConfigResponse.model_validate(cfg)


def update_step_config_service(
    db: Session,
    step_code: str,
    payload: StepConfigUpdateRequest,
    current_user_role: Optional[str] = None,
    current_username: Optional[str] = None,
    actor: Optional[User] = None,
) -> StepConfigResponse:
    # 1. Fallback role guard for direct callers passing role string without actor (Section 10.7)
    if current_user_role is not None and actor is None:
        role_normalized = current_user_role.strip().upper()
        if role_normalized not in ["MANAGER", "GENERAL_MANAGER", "ADMIN"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="فقط دور المدير (Manager) مخول بالاطلاع على وتعديل سياسات وقواعد تصنيف المراحل (Section 10.7)."
            )

    # 2. Mandatory Justification (Section 10.3 & 10.7)
    if not payload.justification or len(payload.justification.strip()) < 5:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="يجب تقديم سبب تبريري إلزامي لتعديل تصنيف المرحلة (لا يقل عن 5 أحرف)."
        )

    # 3. Validate approver_roles against active roles table (BEX-T02)
    if payload.approver_roles is not None:
        if db.query(Role).first() is None:
            from modules.auth.seed_rbac import seed_rbac
            seed_rbac(db)

        for r in payload.approver_roles:
            cleaned_role = (r or "").strip().upper()
            target_role = "GENERAL_MANAGER" if cleaned_role == "MANAGER" else cleaned_role
            role_exists = db.query(Role).filter(
                or_(
                    func.upper(Role.role_code) == cleaned_role,
                    func.upper(Role.role_code) == target_role,
                )
            ).first()
            if not role_exists:
                raise CodedHTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    code="LC_APPROVER_ROLE_UNKNOWN",
                    message_ar=f"دور الاعتماد '{r}' غير معروف في أدوار النظام.",
                    role_code=r,
                )

    validators.validate_step_code(step_code)
    _ensure_step_configs(db)
    cfg = repo.get_step_config(db, step_code)
    if not cfg:
        en_name, ar_name = STEP_NAME_MAP.get(step_code, (step_code, step_code))
        phase_id = STEP_TO_PHASE_MAP.get(step_code, 1)
        cfg = StepConfig(
            step_code=step_code,
            step_name_en=en_name,
            step_name_ar=ar_name,
            phase_id=phase_id,
            skip_policy="blocked",
            reason_required=True,
            reason_categories=DEFAULT_REASON_CATEGORIES,
            approver_roles=["Manager"],
            supports_pending_reference=False,
        )
        db.add(cfg)

    # Store old values for audit trail
    old_policy = cfg.skip_policy
    old_roles = list(cfg.approver_roles or [])
    old_pending = cfg.supports_pending_reference

    # Apply modifications
    if payload.skip_policy is not None:
        cfg.skip_policy = payload.skip_policy
    if payload.reason_categories is not None:
        cfg.reason_categories = enum_codes.normalize_list(enum_codes.SKIP_REASON_CATEGORY, payload.reason_categories)
    if payload.approver_roles is not None:
        cfg.approver_roles = payload.approver_roles
    if payload.supports_pending_reference is not None:
        cfg.supports_pending_reference = payload.supports_pending_reference

    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    username = current_username or (actor.username if actor else "Manager")
    cfg.last_modified_by = username
    cfg.last_modified_at = now_str

    # Log rule change in audit trail (Section 10.3)
    audit_entry = StepConfigAuditLog(
        step_code=step_code,
        action="UPDATE_POLICY",
        changed_by=username,
        changed_at=now_str,
        old_policy=old_policy,
        new_policy=cfg.skip_policy,
        old_approver_roles=old_roles,
        new_approver_roles=cfg.approver_roles,
        old_supports_pending_reference=old_pending,
        new_supports_pending_reference=cfg.supports_pending_reference,
        justification=payload.justification.strip(),
    )
    repo.save_step_config_audit_log(db, audit_entry)

    db.commit()
    db.refresh(cfg)

    return StepConfigResponse.model_validate(cfg)


def get_step_config_audit_logs_service(db: Session, step_code: Optional[str] = None) -> List[StepConfigAuditLogResponse]:
    logs = repo.get_step_config_audit_logs(db, step_code=step_code)
    return [StepConfigAuditLogResponse.model_validate(l) for l in logs]


def register_pending_reference_service(
    db: Session,
    payload: RegisterPendingReferenceRequest,
    current_username: Optional[str] = None,
) -> RegisterPendingReferenceResponse:
    file_rec = _resolve_and_validate_file(db, import_file_code=payload.import_file_code)
    validators.validate_step_code(payload.step_code)

    # 1. Live Step Config Eligibility Check (Section 10.4)
    cfg = repo.get_step_config(db, payload.step_code)
    supports_pending = cfg.supports_pending_reference if cfg else False

    if not supports_pending:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"الخطوة '{payload.step_code}' غير مؤهلة لتسجيل مرجع معلق (Pending Reference) وفق سياسة النظام المعتمدة. يجب تفعيل 'supports_pending_reference' في إعدادات الخطوة أولاً."
        )

    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    username = current_username or "System"

    # 2. Record in PendingReferenceRecord table
    pending_rec = PendingReferenceRecord(
        import_file_code=file_rec.import_file_code,
        step_code=payload.step_code,
        reference_number=payload.reference_number.strip(),
        reason_text=payload.reason_text.strip(),
        expected_completion_date=payload.expected_completion_date,
        registered_by=username,
        registered_at=now_str,
        status="Pending Documentation",
    )
    repo.save_pending_reference(db, pending_rec)

    # 3. Update ShipmentStageActivity with distinct 6th status
    # Note: completed_at remains None! Step is NOT closed or bypassed.
    action_data_json = json.dumps({
        "reference_number": payload.reference_number.strip(),
        "reason_text": payload.reason_text.strip(),
        "expected_completion_date": payload.expected_completion_date,
        "registered_by": username,
        "registered_at": now_str,
        "type": "PENDING_REFERENCE",
    }, ensure_ascii=False)

    pending_msg = msg(
        "LC_PENDING_REFERENCE",
        reference_number=payload.reference_number.strip(),
        reason=payload.reason_text.strip(),
    )
    repo.save_or_update_activity(
        db,
        import_file_code=file_rec.import_file_code,
        step_code=payload.step_code,
        status="Reference recorded – pending full documentation",
        assigned_user=username,
        action_data=action_data_json,
        notes=render_en(pending_msg.code, pending_msg.params, "note"),
        msg_code=pending_msg.code,
        msg_params=pending_msg.params,
    )

    # 4. Central Audit Log
    audit_log = AuditLog(
        entity_type="LifecycleStep",
        entity_id=file_rec.import_file_id,
        entity_code=file_rec.import_file_code,
        action="REGISTER_PENDING_REFERENCE",
        changes_summary=f"Registered pending reference '{payload.reference_number}' for step {payload.step_code}. Step remains incomplete pending docs.",
        old_values=json.dumps({"step_code": payload.step_code, "status": "In-Progress"}),
        new_values=json.dumps({
            "step_code": payload.step_code,
            "status": "Reference recorded – pending full documentation",
            "reference_number": payload.reference_number,
            "expected_completion_date": payload.expected_completion_date,
        }),
        performed_by=username,
    )
    db.add(audit_log)
    db.commit()
    db.refresh(pending_rec)

    return RegisterPendingReferenceResponse(
        message=f"تم تسجيل المرجع المعلق '{payload.reference_number}' للمرحلة {payload.step_code} بنجاح. تظل المرحلة غير مكتملة امتثالياً حتى استيفاء المستندات.",
        import_file_code=file_rec.import_file_code,
        step_code=payload.step_code,
        reference_number=payload.reference_number,
        reason_text=payload.reason_text,
        expected_completion_date=payload.expected_completion_date,
        status="Reference recorded – pending full documentation",
        registered_at=now_str,
    )


def skip_step_service(
    db: Session,
    payload: SkipStepPayload,
    actor: Optional[User] = None,
    current_user_role: Optional[str] = None,
    current_username: Optional[str] = None,
) -> Dict[str, Any]:
    file_rec = _resolve_and_validate_file(db, import_file_code=payload.import_file_code)
    validators.validate_step_code(payload.current_step_code)

    # Mandatory Reason Check (Section 9.3 & 10.1)
    if not payload.skip_reason or len(payload.skip_reason.strip()) < 5:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="سبب التخطي إلزامي ويجب ألا يقل عن 5 أحرف لتبرير الإجراء تشغيلياً."
        )

    # Enforce Configurable Skip Policy (Section 10.1, 10.2, 10.5)
    cfg = repo.get_step_config(db, payload.current_step_code)
    skip_policy = cfg.skip_policy if cfg else "blocked"  # Safest default: blocked

    if skip_policy == "blocked":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"الخطوة '{payload.current_step_code}' محظورة من التخطي حسب سياسة النظام المعتمدة (Policy: blocked). يتطلب التخطي تعديل سياسة المرحلة من قبل المدير أولاً."
        )

    if skip_policy == "dual_approval" and not is_admin_user(actor):
        raise CodedHTTPException(
            status_code=status.HTTP_409_CONFLICT,
            code="LC_SKIP_DUAL_APPROVAL_REQUIRED",
            message_ar=f"الخطوة '{payload.current_step_code}' تتطلب موافقة مزدوجة لتخطيها، وهو مقصور حالياً على مدير النظام (ADMIN).",
            step_code=payload.current_step_code,
        )

    # Role validation is mandatory: the caller role comes from the authenticated user (never a header)
    effective_role = current_user_role or (
        actor.assigned_role.role_code
        if actor and getattr(actor, "assigned_role", None)
        else getattr(actor, "role", None)
    )
    is_admin = is_admin_user(actor)
    if not is_admin:
        if not effective_role or not effective_role.strip():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="تعذر تحديد دور المستخدم."
            )
        user_role_norm = effective_role.strip().upper()
        allowed_roles = [r.strip().upper() for r in (cfg.approver_roles if cfg else ["Manager"])]
        is_authorized = user_role_norm in allowed_roles or user_role_norm in ["ADMIN", "MANAGER", "GENERAL_MANAGER"]
        if not is_authorized:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"دورك '{effective_role}' غير مخول باعتماد تخطي هذه الخطوة. الأدوار المعتمدة: {cfg.approver_roles if cfg else ['Manager']}."
            )

    # Check for incomplete SmartTasks associated with this step
    from modules.smart_tasks.model import SmartTask
    open_tasks = db.query(SmartTask).filter(
        SmartTask.import_file_id == file_rec.import_file_id,
        SmartTask.is_active == True,
        SmartTask.status.in_(["Pending", "In Progress"]),
        or_(
            SmartTask.step_code == payload.current_step_code,
            and_(SmartTask.step_code.is_(None), SmartTask.title.ilike(f"%{payload.current_step_code}%")),
        ),
    ).all()

    force_skip = getattr(payload, "force_skip", False)
    if open_tasks and not force_skip:
        raise CodedHTTPException(
            status_code=status.HTTP_409_CONFLICT,
            code="LC_SKIP_HAS_OPEN_TASKS",
            message_ar=f"المرحلة '{payload.current_step_code}' تحتوي على {len(open_tasks)} مهمة غير مكتملة. يلزم تأكيد التخطي (force_skip=True) لتجاوز المهام.",
            step_code=payload.current_step_code,
            open_tasks_count=len(open_tasks),
        )

    # Auto-infer next step from sequence if not explicitly provided
    if not payload.next_step_codes:
        _, natural_next = get_step_neighbors(payload.current_step_code)
        if natural_next:
            payload.next_step_codes = [natural_next]

    if payload.next_step_codes:
        validators.validate_multi_step_codes(payload.next_step_codes)

    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # Mark current step as Skipped
    skipped_msg = msg("LC_STEP_SKIPPED", reason=payload.skip_reason)
    repo.save_or_update_activity(
        db,
        import_file_code=file_rec.import_file_code,
        step_code=payload.current_step_code,
        status="Skipped",
        completed_at=now_str,
        notes=render_en(skipped_msg.code, skipped_msg.params, "note"),
        msg_code=skipped_msg.code,
        msg_params=skipped_msg.params,
        completion_type="skipped",
    )

    # Activate next step(s)
    after_skip_msg = msg("LC_STEP_ACTIVATED_AFTER_SKIP", skipped_step_code=payload.current_step_code)
    for next_code in payload.next_step_codes:
        repo.save_or_update_activity(
            db,
            import_file_code=file_rec.import_file_code,
            step_code=next_code,
            status="In-Progress",
            started_at=now_str,
            notes=render_en(after_skip_msg.code, after_skip_msg.params, "note"),
            msg_code=after_skip_msg.code,
            msg_params=after_skip_msg.params,
        )

    # Update ImportFile record's skipped_stages list
    current_skipped = list(file_rec.skipped_stages or [])
    if payload.current_step_code not in current_skipped:
        current_skipped.append(payload.current_step_code)
        file_rec.skipped_stages = current_skipped

    # Sync ImportFile stage, module, progress, and Smart Tasks
    _sync_import_file_and_tasks_on_advance(
        db,
        file_code=file_rec.import_file_code,
        completed_step_code=payload.current_step_code,
        activated_step_codes=payload.next_step_codes,
        is_skipped=True,
        skip_reason=payload.skip_reason,
    )

    # Write permanent central audit log entry
    audit_username = current_username or (actor.username if actor else "System")
    audit_log = AuditLog(
        entity_type="LifecycleStep",
        entity_id=file_rec.import_file_id,
        entity_code=file_rec.import_file_code,
        action="SKIP_STAGE",
        changes_summary=f"Skipped {payload.current_step_code} -> Activated {payload.next_step_codes}. Reason: {payload.skip_reason}",
        old_values=json.dumps({"step_code": payload.current_step_code, "status": "In-Progress"}),
        new_values=json.dumps({"step_code": payload.current_step_code, "status": "Skipped", "reason": payload.skip_reason, "policy": skip_policy}),
        performed_by=audit_username,
    )
    db.add(audit_log)
    db.commit()
    db.refresh(file_rec)

    return {
        "message": f"تم تخطي الخطوة {payload.current_step_code} وتفعيل الخطوات اللاحقة بنجاح.",
        "skipped_step": payload.current_step_code,
        "activated_steps": payload.next_step_codes,
        "skip_reason": payload.skip_reason,
        "skip_policy": skip_policy,
        "warnings": [
            {
                "code": "OPEN_TASKS_BYPASSED",
                "count": len(open_tasks),
                "message": f"{len(open_tasks)} open task(s) were bypassed by the forced skip",
            }
        ] if open_tasks else [],
    }


def _resolve_and_validate_file(
    db: Session,
    import_file_code: Optional[str] = None,
    import_file_id: Optional[int] = None,
) -> ImportFile:
    """Resolve ImportFile by id or exact code; enforce active file and open/in-progress status.

    Raises:
        CodedHTTPException (422): LC_FILE_REF_REQUIRED when neither code nor id is given.
        CodedHTTPException (404): LC_FILE_NOT_FOUND when file does not exist or is_active=False.
        CodedHTTPException (409): LC_FILE_NOT_ACTIVE when file status in (Closed, Archived, On Hold).
    """
    if not import_file_code and not import_file_id:
        raise CodedHTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            code="LC_FILE_REF_REQUIRED",
            message_ar="يلزم تحديد معرف ملف الشحنة أو كود الشحنة.",
        )

    file_rec: Optional[ImportFile] = None
    if import_file_id:
        file_rec = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
        if file_rec and not import_file_code:
            import_file_code = file_rec.import_file_code
    elif import_file_code:
        file_rec = db.query(ImportFile).filter(ImportFile.import_file_code == import_file_code).first()

    code_label = import_file_code or (f"#{import_file_id}" if import_file_id else "")
    if file_rec is None or not getattr(file_rec, "is_active", True):
        raise CodedHTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            code="LC_FILE_NOT_FOUND",
            message_ar=f"ملف الشحنة {code_label} غير موجود أو غير نشط.",
            import_file_code=code_label,
        )

    if file_rec.status in ("Closed", "Archived", "On Hold"):
        raise CodedHTTPException(
            status_code=status.HTTP_409_CONFLICT,
            code="LC_FILE_NOT_ACTIVE",
            message_ar=f"ملف الشحنة {file_rec.import_file_code} في حالة '{file_rec.status}' ولا يمكن تحريك مراحله على اللوحة.",
            import_file_code=file_rec.import_file_code,
            status=file_rec.status,
        )

    return file_rec


def _apply_file_tracking(
    file_rec: Any,
    *,
    step_code: str,
    phase_id: Optional[int],
    next_action_msg: SysMsg,
    stage_code: Optional[str] = None,
    legacy_next_action: Optional[str] = None,
) -> None:
    """set_file_tracking + the legacy ``custom_next_action`` text path (stored without a code)."""
    set_file_tracking(
        file_rec,
        step_code=step_code,
        phase_id=str(phase_id) if phase_id is not None else None,
        next_action=next_action_msg,
        stage_code=stage_code,
    )
    if legacy_next_action:
        file_rec.next_action = legacy_next_action[:255]
        file_rec.next_action_code = None
        file_rec.next_action_params = None


def _close_step_tasks(db: Session, import_file_id: int, step_codes: List[str]) -> None:
    """Auto-close open system tasks of the given steps: by ``step_code`` (coded tasks) or, for legacy rows
    without one, by the step code in the title."""
    from modules.smart_tasks.model import SmartTask

    for stc in step_codes:
        prior_tasks = db.query(SmartTask).filter(
            SmartTask.import_file_id == import_file_id,
            SmartTask.task_type == "System Generated",
            SmartTask.status.in_(["Pending", "In Progress"]),
            SmartTask.is_active == True,
            or_(
                SmartTask.step_code == stc,
                and_(SmartTask.step_code.is_(None), SmartTask.title.ilike(f"%{stc}%")),
            ),
        ).all()
        for pt in prior_tasks:
            pt.status = "Completed"
            pt.is_auto_closed = True


def _create_next_step_task(
    db: Session,
    file_rec: Any,
    *,
    import_file_code: str,
    completed_step_code: str,
    next_step_code: str,
    phase_id: Optional[int],
    assigned_user: str,
    created_by: str,
    is_skipped: bool = False,
) -> None:
    """Create the system task of the next step unless one exists (coded by ``step_code``, or a legacy task
    whose title holds the step's Arabic name + code)."""
    from datetime import date
    from modules.smart_tasks.model import SmartTask
    from modules.smart_tasks.schemas import SmartTaskCreate
    import modules.smart_tasks.repository as task_repo

    names = STEP_NAME_MAP.get(next_step_code, (next_step_code, next_step_code))
    legacy_suffix = f"{names[1]} ({next_step_code})"
    existing_task = db.query(SmartTask).filter(
        SmartTask.import_file_id == file_rec.import_file_id,
        SmartTask.is_active == True,
        or_(
            and_(SmartTask.step_code == next_step_code, SmartTask.task_type == "System Generated"),
            and_(SmartTask.step_code.is_(None), SmartTask.title.ilike(f"%{legacy_suffix}%")),
        ),
    ).first()
    if existing_task:
        return

    message = msg(
        "LC_TASK_NEXT_STEP_SKIPPED" if is_skipped else "LC_TASK_NEXT_STEP",
        import_file_code=import_file_code,
        step_code=next_step_code,
        completed_step_code=completed_step_code,
        phase_id=phase_id,
    )
    schema = SmartTaskCreate(
        title=render_en(message.code, message.params, "title"),
        description=render_en(message.code, message.params, "body"),
        task_type="System Generated",
        import_file_id=file_rec.import_file_id,
        import_file_code=import_file_code,
        phase_name=phase_title_en(phase_id) if phase_id else None,
        assigned_user=assigned_user,
        priority="High",
        reminder_type=f"Lifecycle {next_step_code}",
        status="Pending",
        due_date=date.today().isoformat(),
        notes=render_en(message.code, message.params, "note"),
    )
    # Flush only: the calling advance/skip commits once for activities, file tracking and the task.
    task_repo.create_task(
        db, schema, created_by=created_by, msg_code=message.code, msg_params=message.params,
        step_code=next_step_code, commit=False,
    )


def _sync_import_file_and_tasks_on_advance(
    db: Session,
    file_code: str,
    completed_step_code: str,
    activated_step_codes: List[str],
    is_skipped: bool = False,
    skip_reason: Optional[str] = None,
):
    file_rec = db.query(ImportFile).filter(ImportFile.import_file_code == file_code).first()
    if not file_rec:
        return

    if activated_step_codes:
        first_next = activated_step_codes[0]
        phase_id = STEP_TO_PHASE_MAP.get(first_next, 1)

        if first_next in ORDERED_STEP_CODES:
            step_idx = ORDERED_STEP_CODES.index(first_next) + 1
            calc_progress = round((step_idx / len(ORDERED_STEP_CODES)) * 100.0, 1)
        else:
            calc_progress = float(file_rec.progress_percent or 0.0)

        set_file_tracking(
            file_rec,
            step_code=first_next,
            phase_id=str(phase_id),
            next_action=msg("NA_FOLLOW_UP_STEP", step_code=first_next),
        )
        file_rec.progress_percent = max(float(file_rec.progress_percent or 0.0), calc_progress)

        svc = sys.modules.get("modules.lifecycle_board.service")
        close_tasks_fn = getattr(svc, "_close_step_tasks", _close_step_tasks) if svc else _close_step_tasks
        close_tasks_fn(db, file_rec.import_file_id, [completed_step_code])
        create_task_fn = getattr(svc, "_create_next_step_task", _create_next_step_task) if svc else _create_next_step_task
        create_task_fn(
            db,
            file_rec,
            import_file_code=file_code,
            completed_step_code=completed_step_code,
            next_step_code=first_next,
            phase_id=phase_id,
            assigned_user=file_rec.owner or "Operations",
            created_by="Lifecycle Operations Board",
            is_skipped=is_skipped,
        )

    elif completed_step_code == "STEP_21":
        set_file_tracking(file_rec, step_code="STEP_21", phase_id="6", next_action=msg("NA_FILE_CLOSED"))
        file_rec.progress_percent = 100.0

    db.flush()


def _append_system_note(act: Any, message: SysMsg) -> None:
    """Append the English render of a system message to an activity's notes and keep its code/params
    as the latest event (earlier system text stays in ``notes``)."""
    text = render_en(message.code, message.params, "note")
    act.notes = f"{act.notes} | {text}" if act.notes else text
    act.msg_code = message.code
    act.msg_params = dict(message.params)


def resolve_hold_stage(stage_name: Optional[str], step_name: Optional[str]) -> Dict[str, Any]:
    """Language-independent stage reference for hold/pause.

    Clients send ``stage_name`` (a title, possibly Arabic, or a code) and ``step_name`` (a stage code such
    as 'STEP_08_BL', 'PHASE-4: STEP_11', 'PHASE-5'). Returns ``phase_id``, ``step_code`` and the English
    ``stage_title`` (None when nothing resolves, so the caller keeps its fallback)."""
    phase_id, step_code = enum_codes.parse_stage_reference(step_name)
    name_phase, name_step = enum_codes.parse_stage_reference(stage_name)
    step_code = step_code or name_step
    if step_code and step_code not in STEP_TO_PHASE_MAP:
        step_code = None
    phase_id = phase_id or name_phase or (STEP_TO_PHASE_MAP.get(step_code) if step_code else None)
    titles = {p["phase_id"]: p["title_en"] for p in PHASES_DEFINITION}
    if phase_id not in titles:
        phase_id = STEP_TO_PHASE_MAP.get(step_code) if step_code else None

    stage_title: Optional[str] = None
    explicit = (stage_name or "").strip()
    is_code_like = bool(name_phase or name_step)
    if explicit and not is_code_like and not enum_codes.contains_arabic(explicit):
        stage_title = explicit  # an English title chosen by the client
    elif phase_id in titles:
        stage_title = titles[phase_id]
    return {"phase_id": phase_id, "step_code": step_code, "stage_title": stage_title}


def hold_shipment_activities_service(
    db: Session, import_file_code: str, hold_reason: str, hold_reason_code: Optional[str] = None
) -> None:
    activities = db.query(repo.ShipmentStageActivity).filter(
        repo.ShipmentStageActivity.import_file_code == import_file_code,
        repo.ShipmentStageActivity.status == "In-Progress",
    ).all()

    message = (
        msg("LC_STEP_ON_HOLD_CODED", reason_enum_hold_reason=hold_reason_code)
        if hold_reason_code
        else msg("LC_STEP_ON_HOLD", reason=hold_reason)
    )
    for act in activities:
        act.status = "On-Hold"
        _append_system_note(act, message)
    db.commit()


def resume_shipment_activities_service(db: Session, import_file_code: str, resume_notes: Optional[str] = None) -> None:
    activities = db.query(repo.ShipmentStageActivity).filter(
        repo.ShipmentStageActivity.import_file_code == import_file_code,
        repo.ShipmentStageActivity.status == "On-Hold",
    ).all()

    message = msg("LC_STEP_RESUMED", notes=resume_notes) if resume_notes else msg("LC_STEP_RESUMED_DEFAULT")
    for act in activities:
        act.status = "In-Progress"
        _append_system_note(act, message)
    db.commit()


def get_all_activities_service(db: Session, import_file_code: str):
    return repo.get_all_activities(db, import_file_code=import_file_code)


def initialize_file_lifecycle_service(db: Session, import_file_code: str, starting_step: str = "STEP_01") -> None:
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    normalized_starting_step = "STEP_08_PO" if starting_step == "STEP_08" else starting_step

    if normalized_starting_step in ORDERED_STEP_CODES:
        start_idx = ORDERED_STEP_CODES.index(normalized_starting_step)
    else:
        start_idx = 0

    # Mark prior steps in ORDERED_STEP_CODES as Pre-Completed / Skipped
    bypass_msg = msg("LC_STEP_BYPASSED_FOR_LATER_START")
    has_step_08_sub = False
    for i in range(0, start_idx):
        prior_code = ORDERED_STEP_CODES[i]
        if prior_code.startswith("STEP_08_"):
            has_step_08_sub = True
        repo.save_or_update_activity(
            db,
            import_file_code=import_file_code,
            step_code=prior_code,
            status="Completed",
            completed_at=now_str,
            notes=render_en(bypass_msg.code, bypass_msg.params, "note"),
            msg_code=bypass_msg.code,
            msg_params=bypass_msg.params,
            completion_type="bypassed",
        )

    # Legacy STEP_08 fallback record for backward-compatibility
    if has_step_08_sub:
        repo.save_or_update_activity(
            db,
            import_file_code=import_file_code,
            step_code="STEP_08",
            status="Completed",
            completed_at=now_str,
            notes=render_en(bypass_msg.code, bypass_msg.params, "note"),
            msg_code=bypass_msg.code,
            msg_params=bypass_msg.params,
            completion_type="bypassed",
        )

    # Activate starting step
    start_msg = msg("LC_STARTING_POINT_SET", step_code=normalized_starting_step)
    repo.save_or_update_activity(
        db,
        import_file_code=import_file_code,
        step_code=normalized_starting_step,
        status="In-Progress",
        started_at=now_str,
        notes=render_en(start_msg.code, start_msg.params, "note"),
        msg_code=start_msg.code,
        msg_params=start_msg.params,
    )
    db.commit()


def transition_stage_activity_service(
    db: Session,
    completed_step_code: str,
    import_file_id: Optional[int] = None,
    import_file_code: Optional[str] = None,
    target_step_codes: Optional[List[str]] = None,
    notes: Optional[str] = None,
    performed_by: Optional[str] = None,
    assigned_user: Optional[str] = None,
    **kwargs,
) -> Dict[str, Any]:
    """
    Convenience alias / wrapper for advance_lifecycle_step_service used by downstream
    operational and documentation modules to advance the shipment through the 25 lifecycle steps.
    """
    user = assigned_user or performed_by
    return advance_lifecycle_step_service(
        db=db,
        completed_step_code=completed_step_code,
        import_file_id=import_file_id,
        import_file_code=import_file_code,
        target_step_codes=target_step_codes,
        notes=notes,
        assigned_user=user,
        **kwargs,
    )


def advance_lifecycle_step_service(
    db: Session,
    completed_step_code: str,
    import_file_code: Optional[str] = None,
    import_file_id: Optional[int] = None,
    target_step_codes: Optional[List[str]] = None,
    auto_complete_prior: bool = True,
    assigned_user: Optional[str] = None,
    action_data: Optional[Dict[str, Any]] = None,
    notes: Optional[str] = None,
    source_module: Optional[str] = None,
    custom_stage_title: Optional[str] = None,
    custom_module_name: Optional[str] = None,
    custom_next_action: Optional[str] = None,
    min_progress_percent: Optional[float] = None,
    notes_msg: Optional[SysMsg] = None,
    next_action_msg: Optional[SysMsg] = None,
    stage_code: Optional[str] = None,
    enforce_gatekeeper: bool = False,
    commit: bool = True,
) -> Dict[str, Any]:
    """
    Single-language storage (Phase B):
    - ``notes_msg``: system message for the completed step's activity notes (English render stored in
      ``notes``, code in ``msg_code``). Plain ``notes`` is user/caller text and carries no code. Default when
      neither is given: LC_STEP_COMPLETED.
    - ``next_action_msg``: ``NA_*`` message for ``import_files.next_action``. Default: NA_FOLLOW_UP_STEP
      (NA_FILE_CLOSED after STEP_21). ``custom_next_action`` (legacy text) is still honoured when no message is
      given; it is stored as-is without a code.
    - ``stage_code``: optional special STAGE code (e.g. CUSTOMS_RELEASED) for ``current_stage_code``.
    - ``custom_stage_title`` / ``custom_module_name`` are ignored: the stage and module come from
      ``current_phase_id`` / ``current_step_code`` and their English legacy texts from the step catalog.

    Generic Central Synchronization Mechanism for Shipment Lifecycle Operations Board (6 Phases / 25 Steps).
    - Idempotent and transaction-safe.
    - Resolves file by either import_file_code or import_file_id.
    - When auto_complete_prior=True, automatically marks all prior active or unrecorded steps up to
      completed_step_code as 'Completed', preventing orphaned shipments from remaining trapped in previous phases.
    - Marks completed_step_code as 'Completed'.
    - Activates target_step_codes (or auto-inferred natural next step) as 'In-Progress'.
    - Dynamically computes progress percentage based on target step index: (step_idx / 25) * 100%.
    - Updates ImportFile tracking fields (current_stage, current_module, next_action, progress_percent).
    - Auto-closes prior SmartTasks and creates the next step SmartTask.
    """
    from modules.import_files.model import ImportFile

    # 1. Resolve ImportFile record and code
    file_rec: Optional[ImportFile] = None
    if import_file_id:
        file_rec = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
        if file_rec and not import_file_code:
            import_file_code = file_rec.import_file_code
    elif import_file_code:
        file_rec = db.query(ImportFile).filter(ImportFile.import_file_code == import_file_code).first()

    if not import_file_code and not import_file_id:
        raise CodedHTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            code="LC_FILE_REF_REQUIRED",
            message_ar="يلزم تحديد معرف ملف الشحنة أو كود الشحنة.",
        )

    code_label = import_file_code or (f"#{import_file_id}" if import_file_id else "")
    if file_rec is None or not getattr(file_rec, "is_active", True):
        raise CodedHTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            code="LC_FILE_NOT_FOUND",
            message_ar=f"ملف الشحنة {code_label} غير موجود أو غير نشط.",
            import_file_code=code_label,
        )

    if not import_file_code:
        import_file_code = file_rec.import_file_code

    # 2. Validate completed step
    validators.validate_step_code(completed_step_code)

    # 3. Resolve target step(s)
    if target_step_codes is None:
        if completed_step_code == "STEP_21":
            target_step_codes = []
        else:
            _, natural_next = get_step_neighbors(completed_step_code)
            target_step_codes = [natural_next] if natural_next else []
    else:
        validators.validate_multi_step_codes(target_step_codes)

    # Gatekeeper check (Checklist Enforcement)
    if enforce_gatekeeper and file_rec and file_rec.import_file_id:
        chk_target = target_step_codes[0] if target_step_codes else completed_step_code
        chk_target_pid = STEP_TO_PHASE_MAP.get(chk_target, 1)
        phase_to_checklist = {
            4: "IN_TRANSIT",
            5: "PORT_ARRIVAL",
            6: "POST_CLEARANCE",
        }
        target_chk_phase = phase_to_checklist.get(chk_target_pid)
        if target_chk_phase:
            from modules.smart_checklists.service import enforce_gatekeeper_transition
            enforce_gatekeeper_transition(db, file_rec.import_file_id, target_chk_phase)

    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # 4. Auto-Reconciliation of prior steps (mark all prior active/unrecorded steps as Completed)
    auto_completed_steps: List[str] = []
    if auto_complete_prior and completed_step_code in ORDERED_STEP_CODES:
        curr_idx = ORDERED_STEP_CODES.index(completed_step_code)
        prior_codes = ORDERED_STEP_CODES[:curr_idx]
        for prior_code in prior_codes:
            existing_act = repo.get_activity(db, import_file_code, prior_code)
            if not existing_act:
                auto_msg = msg("LC_STEP_AUTO_COMPLETED", target_step_code=completed_step_code)
                repo.save_or_update_activity(
                    db,
                    import_file_code=import_file_code,
                    step_code=prior_code,
                    status="Completed",
                    completed_at=now_str,
                    notes=render_en(auto_msg.code, auto_msg.params, "note"),
                    msg_code=auto_msg.code,
                    msg_params=auto_msg.params,
                    completion_type="auto",
                )
                auto_completed_steps.append(prior_code)
            elif existing_act.status in ["In-Progress", "Pending"]:
                existing_act.status = "Completed"
                existing_act.completion_type = "auto"
                if not existing_act.completed_at:
                    existing_act.completed_at = now_str
                _append_system_note(
                    existing_act, msg("LC_STEP_AUTO_CLOSED_PRIOR", completed_step_code=completed_step_code)
                )
                auto_completed_steps.append(prior_code)

    # 5. Complete current step
    act_data_json = (
        json.dumps(action_data)
        if (action_data and isinstance(action_data, dict))
        else (action_data if isinstance(action_data, str) else None)
    )
    if notes_msg is not None:
        completed_notes, completed_code, completed_params = (
            render_en(notes_msg.code, notes_msg.params, "note"), notes_msg.code, dict(notes_msg.params)
        )
    elif notes:
        completed_notes, completed_code, completed_params = notes, None, None
    else:
        default_msg = msg("LC_STEP_COMPLETED", step_code=completed_step_code)
        completed_notes, completed_code, completed_params = (
            render_en(default_msg.code, default_msg.params, "note"), default_msg.code, default_msg.params
        )
    repo.save_or_update_activity(
        db,
        import_file_code=import_file_code,
        step_code=completed_step_code,
        status="Completed",
        completed_at=now_str,
        assigned_user=assigned_user,
        action_data=act_data_json,
        notes=completed_notes,
        msg_code=completed_code,
        msg_params=completed_params,
        completion_type="real",
    )

    # 6. Activate target steps as In-Progress
    activated_msg = msg("LC_STEP_ACTIVATED", completed_step_code=completed_step_code)
    for target_code in target_step_codes:
        existing_target = repo.get_activity(db, import_file_code, target_code)
        if not existing_target or existing_target.status != "Completed":
            repo.save_or_update_activity(
                db,
                import_file_code=import_file_code,
                step_code=target_code,
                status="In-Progress",
                started_at=now_str,
                notes=render_en(activated_msg.code, activated_msg.params, "note"),
                msg_code=activated_msg.code,
                msg_params=activated_msg.params,
            )

    # 7. Calculate dynamic progress percentage
    if completed_step_code == "STEP_21":
        calc_progress = 100.0
        target_phase_id = 6
        first_target = "STEP_21"
    elif target_step_codes:
        first_target = target_step_codes[0]
        target_phase_id = STEP_TO_PHASE_MAP.get(first_target, 1)
        if first_target in ORDERED_STEP_CODES:
            step_idx = ORDERED_STEP_CODES.index(first_target) + 1
            calc_progress = round((step_idx / len(ORDERED_STEP_CODES)) * 100.0, 1)
        else:
            calc_progress = float(file_rec.progress_percent or 0.0) if file_rec else 0.0
    else:
        first_target = completed_step_code
        target_phase_id = STEP_TO_PHASE_MAP.get(first_target, 1)
        if completed_step_code in ORDERED_STEP_CODES:
            step_idx = ORDERED_STEP_CODES.index(completed_step_code) + 1
            calc_progress = round((step_idx / len(ORDERED_STEP_CODES)) * 100.0, 1)
        else:
            calc_progress = float(file_rec.progress_percent or 0.0) if file_rec else 0.0

    if min_progress_percent is not None:
        calc_progress = max(calc_progress, min_progress_percent)

    # 8. Update ImportFile tracking attributes (structured codes + English legacy text)
    if file_rec:
        if completed_step_code == "STEP_21":
            default_next = msg("NA_FILE_CLOSED")
            file_rec.progress_percent = 100.0
        else:
            default_next = msg("NA_FOLLOW_UP_STEP", step_code=first_target)
            file_rec.progress_percent = max(float(file_rec.progress_percent or 0.0), calc_progress)
        _apply_file_tracking(
            file_rec,
            step_code=first_target,
            phase_id=target_phase_id,
            stage_code=stage_code,
            next_action_msg=next_action_msg or default_next,
            legacy_next_action=None if next_action_msg is not None else custom_next_action,
        )

        # 9. SmartTask management
        svc = sys.modules.get("modules.lifecycle_board.service")
        close_tasks_fn = getattr(svc, "_close_step_tasks", _close_step_tasks) if svc else _close_step_tasks
        close_tasks_fn(db, file_rec.import_file_id, [completed_step_code] + auto_completed_steps)
        if target_step_codes and completed_step_code != "STEP_21":
            create_task_fn = getattr(svc, "_create_next_step_task", _create_next_step_task) if svc else _create_next_step_task
            create_task_fn(
                db,
                file_rec,
                import_file_code=import_file_code,
                completed_step_code=completed_step_code,
                next_step_code=first_target,
                phase_id=target_phase_id,
                assigned_user=file_rec.owner or assigned_user or "Operations",
                created_by=source_module or "Lifecycle Operations Board",
            )

        # 10. Centralized 25-Stage Timeline Snapshot Auto-Sync (TASK-BE-09)
        try:
            from modules.lifecycle_board.sync_engine import LifecycleAutoSyncEngine
            LifecycleAutoSyncEngine.sync_file_timeline(db, import_file_id=file_rec.import_file_id, commit=False)
        except Exception as exc:
            logger.warning("LifecycleAutoSyncEngine snapshot sync failed: %s", exc)

    if commit:
        db.commit()
        if file_rec:
            db.refresh(file_rec)
            # 10. Auto-sync smart checklist upon step completion
            try:
                from modules.smart_checklists.service import auto_sync_checklist
                auto_sync_checklist(db, file_rec.import_file_id)
            except Exception as e:
                import logging
                logging.getLogger(__name__).warning(
                    "Checklist auto-sync failed after advancing step %s for file #%s: %s",
                    completed_step_code,
                    file_rec.import_file_id,
                    e,
                )
    else:
        db.flush()

    return {
        "message": f"تم إكمال الخطوة {completed_step_code} وتفعيل الخطوات التالية بنجاح.",
        "completed_step": completed_step_code,
        "activated_steps": target_step_codes,
        "auto_completed_prior_steps": auto_completed_steps,
        "import_file_code": import_file_code,
        "progress_percent": file_rec.progress_percent if file_rec else calc_progress,
        "current_stage": file_rec.current_stage if file_rec else None,
        "current_module": file_rec.current_module if file_rec else None,
        "next_action": file_rec.next_action if file_rec else None,
        "current_step_code": file_rec.current_step_code if file_rec else None,
        "current_phase_id": file_rec.current_phase_id if file_rec else None,
        "current_stage_code": file_rec.current_stage_code if file_rec else None,
        "next_action_code": file_rec.next_action_code if file_rec else None,
        "next_action_params": file_rec.next_action_params if file_rec else None,
    }


def sync_consultation_lifecycle_stage(db: Session, import_file_id: int):
    """
    Auto-advances shipment from Freight Studies (STEP_01) to Customs Studies (STEP_02)
    and sets Import Regulatory Requirements (STEP_03) as the Next Planned Step.
    """
    return advance_lifecycle_step_service(
        db=db,
        completed_step_code="STEP_01",
        import_file_id=import_file_id,
        target_step_codes=["STEP_02"],
        auto_complete_prior=True,
        notes_msg=msg("LC_SYNC_FREIGHT_STUDIES_DONE"),
        source_module="Customs Engine Lifecycle",
        next_action_msg=msg("NA_STEP03_REVIEW_REGULATORY_APPROVALS"),
        min_progress_percent=20.0,
    )


def sync_requirements_lifecycle_stage(db: Session, import_file_id: int):
    """
    Auto-advances shipment from Customs Studies (STEP_02) to Import Regulatory Requirements (STEP_03)
    and sets Finance Approvals & Budget (STEP_04) as the Next Planned Step.
    """
    return advance_lifecycle_step_service(
        db=db,
        completed_step_code="STEP_02",
        import_file_id=import_file_id,
        target_step_codes=["STEP_03"],
        auto_complete_prior=True,
        notes_msg=msg("LC_SYNC_CUSTOMS_STUDY_DONE"),
        source_module="Requirements Engine Lifecycle",
        next_action_msg=msg("NA_STEP04_REVIEW_BUDGET_SUPPLIER_TRANSFER"),
        min_progress_percent=25.0,
    )


def sync_budget_lifecycle_stage(
    db: Session,
    import_file_id: int,
    is_approved: bool = False,
    approved_by: Optional[str] = None,
):
    """
    Auto-advances shipment to Phase 2: Approvals & ACID (STEP_04 / STEP_05)
    when an Import Budget is created or approved.
    """
    if is_approved:
        return advance_lifecycle_step_service(
            db=db,
            completed_step_code="STEP_04",
            import_file_id=import_file_id,
            target_step_codes=["STEP_05"],
            auto_complete_prior=True,
            assigned_user=approved_by or "Finance Manager",
            notes_msg=msg("LC_SYNC_BUDGET_APPROVED"),
            source_module="Budget Approval Lifecycle",
            next_action_msg=msg("NA_STEP05_REQUEST_ACID"),
            min_progress_percent=40.0,
        )
    else:
        return advance_lifecycle_step_service(
            db=db,
            completed_step_code="STEP_03",
            import_file_id=import_file_id,
            target_step_codes=["STEP_04"],
            auto_complete_prior=True,
            notes_msg=msg("LC_SYNC_BUDGET_UNDER_REVIEW"),
            source_module="Budget Approval Lifecycle",
            next_action_msg=msg("NA_STEP04_APPROVE_BUDGET_SUPPLIER_PAYMENT"),
            min_progress_percent=30.0,
        )


def sync_booking_lifecycle_stage(
    db: Session,
    import_file_id: int,
    booking_code: Optional[str] = None,
    booking_confirmation_no: Optional[str] = None,
    is_confirmed: bool = True,
    vessel_name: Optional[str] = None,
):
    """
    Auto-advances shipment to Phase 3: Booking & Doc Prep (STEP_06 / STEP_07)
    when a Freight Booking is created or updated.
    """
    if is_confirmed:
        return advance_lifecycle_step_service(
            db=db,
            completed_step_code="STEP_06",
            import_file_id=import_file_id,
            target_step_codes=["STEP_07"],
            auto_complete_prior=True,
            notes_msg=(
                msg(
                    "LC_SYNC_BOOKING_CONFIRMED_DETAILS",
                    booking_code=booking_code or "-",
                    confirmation_no=booking_confirmation_no or "-",
                    vessel_name=vessel_name or "-",
                )
                if (booking_confirmation_no or vessel_name)
                else msg("LC_SYNC_BOOKING_CONFIRMED", booking_code=booking_code or "-")
            ),
            source_module="Freight Booking Lifecycle",
            next_action_msg=msg("NA_STEP07_AUDIT_ALLOCATION_VGM"),
            min_progress_percent=50.0,
        )
    else:
        return advance_lifecycle_step_service(
            db=db,
            completed_step_code="STEP_05",
            import_file_id=import_file_id,
            target_step_codes=["STEP_06"],
            auto_complete_prior=True,
            notes_msg=msg("LC_SYNC_BOOKING_PENDING", booking_code=booking_code or ""),
            source_module="Freight Booking Lifecycle",
            next_action_msg=msg("NA_STEP06_FOLLOW_BOOKING_CONFIRMATION"),
            min_progress_percent=45.0,
        )


def sync_cargo_shipping_lifecycle_stage(
    db: Session,
    import_file_id: int,
    cargo_shipping_code: Optional[str] = None,
    container_count: int = 1,
    is_final_completed: bool = True,
):
    """
    Auto-advances shipment from STEP_07 (Freight Allocations) to STEP_08_PO (PO & Packing Reconciliation)
    when Cargo Shipping allocations & container records are saved and finalized.
    """
    if is_final_completed:
        return advance_lifecycle_step_service(
            db=db,
            completed_step_code="STEP_07",
            import_file_id=import_file_id,
            target_step_codes=["STEP_08_PO"],
            auto_complete_prior=True,
            notes_msg=msg(
                "LC_SYNC_CARGO_ALLOCATION_DONE",
                cargo_shipping_code=cargo_shipping_code or "",
                container_count=int(container_count or 0),
            ),
            source_module="Cargo Shipping Lifecycle",
            next_action_msg=msg("NA_STEP08PO_RECONCILE_INVOICE_PACKING_PO"),
            min_progress_percent=48.0,
        )
    else:
        return advance_lifecycle_step_service(
            db=db,
            completed_step_code="STEP_06",
            import_file_id=import_file_id,
            target_step_codes=["STEP_07"],
            auto_complete_prior=True,
            notes_msg=msg("LC_SYNC_CARGO_ALLOCATION_DRAFT", cargo_shipping_code=cargo_shipping_code or ""),
            source_module="Cargo Shipping Lifecycle",
            next_action_msg=msg("NA_STEP07_COMPLETE_CONTAINERS_VGM"),
            min_progress_percent=50.0,
        )


def http_advance_step_service(
    db: Session,
    *,
    completed_step_code: str,
    import_file_code: Optional[str] = None,
    import_file_id: Optional[int] = None,
    target_step_codes: Optional[List[str]] = None,
    auto_complete_prior: bool = True,
    action_data: Optional[Any] = None,
    notes: Optional[str] = None,
    enforce_gatekeeper: bool = False,
    actor: User,
) -> Dict[str, Any]:
    """HTTP entry point for advancing lifecycle steps (BEX-T01).

    Enforces:
    - File exists, is active, not Closed/Archived/On Hold.
    - STEP_21 cannot be completed from HTTP (reserved for file_closure).
    - completed_step_code must currently be In-Progress or Reference recorded on that file.
    - auto_complete_prior is honoured only for ADMIN users.
    - assigned_user is taken strictly from actor.username (token).
    """
    file_rec = _resolve_and_validate_file(db, import_file_code=import_file_code, import_file_id=import_file_id)

    if completed_step_code == "STEP_21":
        raise CodedHTTPException(
            status_code=status.HTTP_409_CONFLICT,
            code="LC_CLOSURE_STEP_RESERVED",
            message_ar="خطوة إغلاق الملف STEP_21 مخصصة لمنظومة إغلاق الملفات الرسمية ولا يمكن إكمالها من اللوحة.",
        )

    act = repo.get_activity(db, file_rec.import_file_code, completed_step_code)
    valid_statuses = {"In-Progress", "Reference recorded – pending full documentation"}
    if not act or act.status not in valid_statuses:
        raise CodedHTTPException(
            status_code=status.HTTP_409_CONFLICT,
            code="LC_STEP_NOT_ACTIVE",
            message_ar=f"الخطوة {completed_step_code} ليست قيد التنفيذ حالياً على ملف الشحنة {file_rec.import_file_code}.",
            step_code=completed_step_code,
            import_file_code=file_rec.import_file_code,
        )

    if target_step_codes and (actor is not None and not is_admin_user(actor)):
        _, natural_next = get_step_neighbors(completed_step_code)
        allowed_targets = {natural_next} if natural_next else set()
        if natural_next == "STEP_08_PO":
            allowed_targets.add("STEP_08")
        for target in target_step_codes:
            if target not in allowed_targets:
                raise CodedHTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    code="LC_TARGET_STEP_INVALID",
                    message_ar=f"لا يمكن الانتقال مباشرة إلى الخطوة {target} بدون صلاحيات المسؤول.",
                    step_code=target,
                    import_file_code=file_rec.import_file_code,
                )

    effective_auto_complete = bool(auto_complete_prior) and is_admin_user(actor)

    return advance_lifecycle_step_service(
        db=db,
        completed_step_code=completed_step_code,
        import_file_code=file_rec.import_file_code,
        import_file_id=file_rec.import_file_id,
        target_step_codes=target_step_codes,
        auto_complete_prior=effective_auto_complete,
        assigned_user=actor.username,
        action_data=action_data,
        notes=notes,
        enforce_gatekeeper=enforce_gatekeeper,
        source_module="Lifecycle Operations Board",
    )


def advance_step_service(
    db: Session,
    payload: StepAdvancePayload,
    actor: Optional[User] = None,
) -> Dict[str, Any]:
    if actor is not None:
        return http_advance_step_service(
            db=db,
            completed_step_code=payload.current_step_code,
            import_file_code=payload.import_file_code,
            import_file_id=None,
            target_step_codes=payload.next_step_codes if payload.next_step_codes else None,
            auto_complete_prior=getattr(payload, "auto_complete_prior", True),
            action_data=payload.action_data,
            notes=payload.notes,
            actor=actor,
        )
    return advance_lifecycle_step_service(
        db=db,
        completed_step_code=payload.current_step_code,
        import_file_code=payload.import_file_code,
        target_step_codes=payload.next_step_codes if payload.next_step_codes else None,
        auto_complete_prior=getattr(payload, "auto_complete_prior", True),
        action_data=payload.action_data,
        notes=payload.notes,
    )


def set_multi_active_stages_service(
    db: Session,
    payload: MultiStageSetPayload,
    actor: Optional[User] = None,
) -> Dict[str, Any]:
    file_rec = _resolve_and_validate_file(db, import_file_code=payload.import_file_code)
    validators.validate_multi_step_codes(payload.active_step_codes)
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    existing_activities = repo.get_all_activities(db, import_file_code=file_rec.import_file_code)
    activities_by_code = {act.step_code: act for act in existing_activities}

    # 1. Reject already Completed or Skipped steps
    for step_code in payload.active_step_codes:
        existing_act = activities_by_code.get(step_code)
        if existing_act and existing_act.status in ("Completed", "Skipped"):
            raise CodedHTTPException(
                status_code=status.HTTP_409_CONFLICT,
                code="LC_STEP_ALREADY_COMPLETED",
                message_ar=f"المرحلة {step_code} مكتملة أو تم تخطيها بالفعل لملف الشحنة {file_rec.import_file_code}.",
                step_code=step_code,
                import_file_code=file_rec.import_file_code,
            )

    # 2. Sequence check for non-admin users: only allow steps at or before the next natural step
    if actor is not None and not is_admin_user(actor):
        def _get_idx(code: str) -> int:
            if code == "STEP_08":
                code = "STEP_08_PO"
            return ORDERED_STEP_CODES.index(code) if code in ORDERED_STEP_CODES else -1

        completed_indices = [
            _get_idx(act.step_code)
            for act in existing_activities
            if act.status in ("Completed", "Skipped") and _get_idx(act.step_code) >= 0
        ]
        active_indices = [
            _get_idx(act.step_code)
            for act in existing_activities
            if act.status not in ("Completed", "Skipped") and _get_idx(act.step_code) >= 0
        ]

        if completed_indices:
            next_natural_idx = max(completed_indices) + 1
        else:
            next_natural_idx = 0

        max_allowed_idx = max([next_natural_idx] + active_indices)
        max_allowed_idx = min(max_allowed_idx, len(ORDERED_STEP_CODES) - 1)

        for step_code in payload.active_step_codes:
            step_idx = _get_idx(step_code)
            if step_idx > max_allowed_idx:
                raise CodedHTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    code="LC_STEP_SEQUENCE_INVALID",
                    message_ar=f"لا يمكن تفعيل المرحلة {step_code} قبل الوصول إليها في مسار الشحنة لغير المسؤولين.",
                    step_code=step_code,
                    import_file_code=file_rec.import_file_code,
                )

    for step_code in payload.active_step_codes:
        repo.save_or_update_activity(
            db,
            import_file_code=file_rec.import_file_code,
            step_code=step_code,
            status="In-Progress",
            started_at=now_str,
            assigned_user=actor.username if actor else None,
            notes=payload.notes or render_en("LC_MULTI_STAGE_ACTIVATED", {}, "note"),
            msg_code=None if payload.notes else "LC_MULTI_STAGE_ACTIVATED",
            msg_params=None if payload.notes else {},
        )

    db.commit()
    return {
        "message": f"تم تفعيل {len(payload.active_step_codes)} مرحلة بالتوازي للشحنة {file_rec.import_file_code}.",
        "active_steps": payload.active_step_codes,
    }
