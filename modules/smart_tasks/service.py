"""
Business Logic & Workflows for Smart Tasks & Reminder Engine
"""

import re
from typing import List, Optional
from datetime import datetime, date, timezone
from sqlalchemy import and_, or_
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from modules.smart_tasks.model import SmartTask
from modules.smart_tasks.schemas import (
    SmartTaskCreate,
    SmartTaskUpdate,
    SmartTaskSummaryMetrics,
)
import modules.smart_tasks.repository as repo
import modules.smart_tasks.validators as val
from modules.import_files.model import ImportFile
from modules.common.system_messages import msg, render_en


def create_task_service(
    db: Session,
    schema: SmartTaskCreate,
    user_name: str = "System",
    msg_code: Optional[str] = None,
    msg_params: Optional[dict] = None,
    step_code: Optional[str] = None,
    commit: bool = True,
) -> SmartTask:
    """``msg_code`` / ``msg_params`` / ``step_code`` are for server-generated tasks only (routers never pass them).
    ``commit=False``: flush only, for callers that commit their own transaction afterwards."""
    val.validate_task_create(schema)
    return repo.create_task(
        db, schema, created_by=user_name, msg_code=msg_code, msg_params=msg_params, step_code=step_code,
        commit=commit,
    )


# Text fields a system message code renders. A user edit that changes one of them makes the text user-owned.
_CODED_TEXT_FIELDS = ("title", "description", "notes")


def update_task_service(db: Session, task_id: int, schema: SmartTaskUpdate, user_name: str = "System") -> SmartTask:
    update_data = schema.model_dump(exclude_unset=True)
    existing = repo.get_task_by_id(db, task_id)
    if existing is not None and existing.msg_code and any(
        field in update_data and update_data[field] != getattr(existing, field) for field in _CODED_TEXT_FIELDS
    ):
        # The stored English render no longer matches the code: drop the code so every client shows the edit.
        update_data["msg_code"] = None
        update_data["msg_params"] = None
    task = repo.update_task(db, task_id, update_data, updated_by=user_name)
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"المهمة رقم '{task_id}' غير موجودة.",
        )
    return task


# (phase prefix, PHASE_FOLLOW_UP_TASK code, reminder type, priority, legacy Arabic title suffix).
# The legacy suffix only matches tasks created before the task codes existed; it is never written.
SYSTEM_PHASE_TASK_DEFS = [
    ("Phase 1", "FREIGHT_SCENARIO_FOLLOW_UP", "Carrier Quote Review", "High",
     "متابعة دراسة وسيناريوهات النولون وشغور الخطوط"),
    ("Phase 2", "PAYMENT_BUDGET_FOLLOW_UP", "Payment & Budget Follow-up", "High",
     "متابعة الاعتماد والموافقة المالية وصرف الدفعة"),
    ("Phase 3", "NAFEZA_ACID_FOLLOW_UP", "Bank Form 4 & ACID Registration", "Critical",
     "متابعة تسجيل نافذة وحصول على رقم ACID (19-Digit)"),
    ("Phase 4", "BOOKING_BL_FOLLOW_UP", "Draft B/L & Vessel Confirmation", "High",
     "متابعة حجز الشحن وتأكيد رص الحاويات وتأكيد B/L"),
    ("Phase 5", "CARGOX_DOCUMENT_TRANSFER", "CargoX Blockchain Exchange", "Critical",
     "استلام Commercial Invoice ونقل المستندات عبر CargoX"),
    ("Phase 6", "ARRIVAL_NOTICE_DECLARATION_46", "Arrival Notice & Customs Declaration 46", "Critical",
     "متابعة وصول التنويه Arrival Notice وتسجيل إقرار 46 جمارك"),
    ("Phase 7", "BROKER_RELEASE_FOLLOW_UP", "Customs Broker Inspection & Release", "Critical",
     "تنفيذ ملاحظات المخلص الجمركي واستخراج إذن الإفراج النهائي"),
    ("Phase 8", "WAREHOUSE_GRN_REVIEW", "Warehouse Receiving & GRN Verification", "High",
     "مراجعة سلامة السليم واستلام المخازن وتوليد إذن GRN"),
    ("Phase 9", "LANDED_COST_SETTLEMENT", "Landed Cost Settlement", "High",
     "تسوية محرك تكلفة الوصول الكلية Landed Cost وتوزيع المصاريف"),
    ("Phase 10", "ARCHIVE_REVIEW", "Archival Verification", "Medium",
     "مراجعة شروط الأرشفة وإغلاق الملف التاريخي"),
]


def _phase_matches(prefix: str, phase_text: str) -> bool:
    """'Phase 1' must not match 'Phase 10'."""
    return re.search(rf"{re.escape(prefix)}(?!\d)", phase_text) is not None


def auto_generate_system_tasks_for_file(db: Session, import_file: ImportFile):
    """
    Business Rule 2.4 A: Generate System Tasks automatically based on Phase progression.
    Titles/descriptions/notes are TASK_AUTO_PHASE_FOLLOW_UP (code + params, English render stored).
    """
    file_id = import_file.import_file_id
    file_code = import_file.custom_file_number or import_file.import_file_code
    phase = import_file.current_module or "Phase 1"

    for ph_prefix, task_enum_code, r_type, priority, legacy_suffix in SYSTEM_PHASE_TASK_DEFS:
        if not _phase_matches(ph_prefix, phase):
            continue
        # Coded tasks are recognised by their reminder type; legacy ones by the Arabic title suffix.
        existing = db.query(SmartTask).filter(
            SmartTask.import_file_id == file_id,
            SmartTask.is_active == True,
            or_(
                and_(SmartTask.task_type == "System Generated", SmartTask.reminder_type == r_type),
                SmartTask.title.ilike(f"%{legacy_suffix}%"),
            ),
        ).first()
        if existing:
            continue

        message = msg(
            "TASK_AUTO_PHASE_FOLLOW_UP",
            import_file_code=file_code,
            task_enum_phase_follow_up_task=task_enum_code,
        )
        create_schema = SmartTaskCreate(
            title=render_en(message.code, message.params, "title"),
            description=render_en(message.code, message.params, "body"),
            task_type="System Generated",
            import_file_id=file_id,
            import_file_code=file_code,
            phase_name=phase,
            assigned_user=import_file.owner or "Kamal",
            priority=priority,
            reminder_type=r_type,
            status="Pending",
            due_date=date.today().isoformat(),
            notes=render_en(message.code, message.params, "note"),
        )
        repo.create_task(
            db, create_schema, created_by="System Generator", msg_code=message.code, msg_params=message.params
        )


def auto_close_completed_phase_tasks(db: Session, import_file_id: int, completed_phase: str):
    """
    Business Rule 2.4: Auto-close system tasks when associated phase completes
    """
    tasks = db.query(SmartTask).filter(
        SmartTask.import_file_id == import_file_id,
        SmartTask.task_type == "System Generated",
        SmartTask.status.in_(["Pending", "In Progress"]),
        SmartTask.is_active == True,
    ).all()

    for t in tasks:
        if t.phase_name and completed_phase in t.phase_name:
            t.status = "Completed"
            t.is_auto_closed = True
            t.updated_at = datetime.now(timezone.utc)
    db.commit()


def get_dashboard_summary_metrics_service(db: Session) -> SmartTaskSummaryMetrics:
    """
    Executes real-time database queries to calculate the 9 Operational Dashboard Metrics
    """
    today_str = date.today().isoformat()

    # 1. Tasks
    all_tasks = db.query(SmartTask).filter(SmartTask.is_active == True).all()
    todays_tasks_cnt = sum(1 for t in all_tasks if t.due_date == today_str and t.status != "Completed")
    pending_tasks_cnt = sum(1 for t in all_tasks if t.status in ["Pending", "In Progress"])

    # 2. Shipments Metrics
    active_shipments = db.query(ImportFile).filter(
        ImportFile.is_active == True,
        ImportFile.status != "Closed",
    ).all()

    upcoming_shipments_cnt = len(active_shipments)
    arriving_this_week_cnt = sum(1 for s in active_shipments if s.required_eta or s.estimated_cost > 0)
    eta_changes_cnt = sum(1 for s in active_shipments if s.required_eta is not None)
    waiting_for_payment_cnt = sum(1 for s in active_shipments if s.current_module and "Phase 2" in s.current_module)
    waiting_for_form4_cnt = sum(1 for s in active_shipments if s.form4_no is None or s.form4_no == "")
    pending_requirements_cnt = sum(1 for s in active_shipments if s.acid_number is None or s.form46_no is None)
    high_priority_alerts_cnt = sum(1 for s in active_shipments if s.priority in ["High", "Critical"])

    return SmartTaskSummaryMetrics(
        total_tasks=len(all_tasks),
        todays_tasks=todays_tasks_cnt,
        pending_tasks=pending_tasks_cnt,
        upcoming_shipments=upcoming_shipments_cnt,
        arriving_this_week=arriving_this_week_cnt,
        eta_changes=eta_changes_cnt,
        waiting_for_payment=waiting_for_payment_cnt,
        waiting_for_form4=waiting_for_form4_cnt,
        pending_requirements=pending_requirements_cnt,
        high_priority_alerts=high_priority_alerts_cnt,
    )


def sync_all_active_shipments_tasks(db: Session) -> int:
    """
    Synchronizes tasks across all active ImportFile records:
    Generates missing system tasks for the current phase, closes previous phases,
    and checks for critical conditions.
    """
    active_files = db.query(ImportFile).filter(
        ImportFile.is_active == True,
        ImportFile.status != "Closed",
    ).all()

    processed_count = 0
    for f in active_files:
        auto_generate_system_tasks_for_file(db, f)
        processed_count += 1

    return processed_count

def get_all_tasks_service(db: Session, include_inactive: bool = False, task_type: str = None, status: str = None, priority: str = None, import_file_id: int = None, search: str = None):
    return repo.get_all_tasks(db, include_inactive=include_inactive, task_type=task_type, status=status, priority=priority, import_file_id=import_file_id, search=search)

def get_due_and_overdue_tasks_service(db: Session, target_date_str: str = None):
    return repo.get_due_and_overdue_tasks(db, target_date_str=target_date_str)

def get_task_by_id_service(db: Session, task_id: int):
    return repo.get_task_by_id(db, task_id)

def soft_delete_task_service(db: Session, task_id: int):
    return repo.soft_delete_task(db, task_id)

def restore_task_service(db: Session, task_id: int):
    return repo.restore_task(db, task_id)

def generate_phase_tasks_service(db: Session, import_file_id: int) -> dict:
    from modules.import_files.repository import get_import_file_by_id
    import_file = get_import_file_by_id(db, import_file_id)
    if not import_file:
        raise HTTPException(status_code=404, detail="ملف الاستيراد غير موجود.")

    before_count = db.query(SmartTask).filter(
        SmartTask.import_file_id == import_file_id,
        SmartTask.task_type == "System Generated",
        SmartTask.is_active == True,
    ).count()

    auto_generate_system_tasks_for_file(db, import_file)

    after_count = db.query(SmartTask).filter(
        SmartTask.import_file_id == import_file_id,
        SmartTask.task_type == "System Generated",
        SmartTask.is_active == True,
    ).count()

    new_tasks_created = after_count - before_count
    return {
        "import_file_id": import_file_id,
        "current_phase": import_file.current_module,
        "new_tasks_created": new_tasks_created,
        "total_system_tasks": after_count,
        "message": f"تم إنشاء {new_tasks_created} مهمة جديدة تلقائياً للمرحلة {import_file.current_module}",
    }

def complete_phase_tasks_service(db: Session, import_file_id: int, completed_phase: str) -> dict:
    from modules.import_files.repository import get_import_file_by_id
    import_file = get_import_file_by_id(db, import_file_id)
    if not import_file:
        raise HTTPException(status_code=404, detail="ملف الاستيراد غير موجود.")

    auto_close_completed_phase_tasks(db, import_file_id, completed_phase)

    return {
        "import_file_id": import_file_id,
        "completed_phase": completed_phase,
        "message": f"تم إغلاق جميع مهام المرحلة {completed_phase} تلقائياً.",
    }
