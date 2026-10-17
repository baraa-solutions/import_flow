"""
Database Operations for Smart Tasks Repository
"""

from typing import Any, Dict, List, Optional
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_, func
from sqlalchemy.exc import IntegrityError

from modules.common.sequence_generator import next_yearly_code
from modules.smart_tasks.model import SmartTask
from modules.smart_tasks.schemas import SmartTaskCreate, SmartTaskUpdate


def generate_task_code(db: Session, year: Optional[int] = None) -> str:
    return next_yearly_code(db, SmartTask.task_code, "TSK", pad=4, year=year)


def create_task(
    db: Session,
    schema: SmartTaskCreate,
    created_by: str = "System",
    msg_code: Optional[str] = None,
    msg_params: Optional[Dict[str, Any]] = None,
    step_code: Optional[str] = None,
    commit: bool = True,
) -> SmartTask:
    """``msg_code`` / ``msg_params`` / ``step_code`` are server-only (system tasks): the request schema never
    carries them, so user tasks never get a code.

    ``commit=False`` only flushes (the task gets its id): use it inside a larger service transaction so a later
    failure rolls the task back together with the caller's own writes."""
    for attempt in range(3):
        task_code = generate_task_code(db)
        db_obj = SmartTask(
            task_code=task_code,
            title=schema.title,
            description=schema.description,
            task_type=schema.task_type,
            import_file_id=schema.import_file_id,
            import_file_code=schema.import_file_code,
            phase_name=schema.phase_name,
            assigned_user=schema.assigned_user,
            priority=schema.priority,
            reminder_type=schema.reminder_type,
            due_date=schema.due_date,
            reminder_date=schema.reminder_date,
            status=schema.status,
            notes=schema.notes,
            attachment_url=schema.attachment_url,
            msg_code=msg_code,
            msg_params=dict(msg_params) if msg_params else None,
            step_code=step_code,
            created_by=created_by,
            updated_by=created_by,
        )
        if commit:
            db.add(db_obj)
            try:
                db.commit()
                db.refresh(db_obj)
                return db_obj
            except IntegrityError:
                db.rollback()
                if attempt == 2:
                    raise
        else:
            try:
                with db.begin_nested():
                    db.add(db_obj)
                    db.flush()
                return db_obj
            except IntegrityError:
                if attempt == 2:
                    raise


def get_task_by_id(db: Session, task_id: int) -> Optional[SmartTask]:
    return db.query(SmartTask).filter(
        SmartTask.task_id == task_id,
        SmartTask.is_active == True,
    ).first()


def get_all_tasks(
    db: Session,
    include_inactive: bool = False,
    task_type: Optional[str] = None,
    status: Optional[str] = None,
    priority: Optional[str] = None,
    import_file_id: Optional[int] = None,
    search: Optional[str] = None,
    order_by_priority: bool = False,
) -> List[SmartTask]:
    query = db.query(SmartTask)

    if not include_inactive:
        query = query.filter(SmartTask.is_active == True)

    if task_type:
        query = query.filter(SmartTask.task_type == task_type)

    if status and status != "All":
        query = query.filter(SmartTask.status == status)

    if priority and priority != "All":
        query = query.filter(SmartTask.priority == priority)

    if import_file_id:
        query = query.filter(SmartTask.import_file_id == import_file_id)

    if search:
        term = f"%{search}%"
        query = query.filter(
            or_(
                SmartTask.task_code.ilike(term),
                SmartTask.title.ilike(term),
                SmartTask.description.ilike(term),
                SmartTask.import_file_code.ilike(term),
            )
        )

    if order_by_priority:
        from sqlalchemy import case
        p_order = case(
            (SmartTask.priority == "Critical", 1),
            (SmartTask.priority == "High", 2),
            (SmartTask.priority == "Medium", 3),
            (SmartTask.priority == "Low", 4),
            else_=5,
        )
        return query.order_by(p_order, SmartTask.task_id.desc()).all()

    return query.order_by(SmartTask.task_id.desc()).all()


def update_task(db: Session, task_id: int, update_data: dict, updated_by: str = "System") -> Optional[SmartTask]:
    db_obj = get_task_by_id(db, task_id)
    if not db_obj:
        return None

    for key, value in update_data.items():
        if hasattr(db_obj, key):
            setattr(db_obj, key, value)

    db_obj.updated_at = datetime.now(timezone.utc)
    db_obj.updated_by = updated_by
    db.commit()
    db.refresh(db_obj)
    return db_obj


def soft_delete_task(db: Session, task_id: int, deleted_by: str = "System") -> bool:
    db_obj = get_task_by_id(db, task_id)
    if not db_obj:
        return False

    db_obj.is_active = False
    db_obj.updated_at = datetime.now(timezone.utc)
    db_obj.updated_by = deleted_by
    db.commit()
    return True


def restore_task(db: Session, task_id: int) -> Optional[SmartTask]:
    db_obj = db.query(SmartTask).filter(SmartTask.task_id == task_id).first()
    if not db_obj:
        return None

    db_obj.is_active = True
    db_obj.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(db_obj)
    return db_obj


def get_due_and_overdue_tasks(db: Session, target_date_str: Optional[str] = None) -> dict:
    """
    Reminder Engine (Feature 2.5):
    Returns tasks that are due today, overdue, or due within the next N days.
    target_date_str: ISO date string e.g. '2026-08-13'. Defaults to today (UTC).
    """
    today = datetime.now(timezone.utc).date()
    target = today
    if target_date_str:
        try:
            from datetime import date
            target = date.fromisoformat(target_date_str)
        except ValueError:
            pass

    today_str = target.isoformat()
    all_pending = db.query(SmartTask).filter(
        SmartTask.is_active == True,
        SmartTask.status.in_(["Pending", "In Progress"]),
        SmartTask.due_date.isnot(None),
    ).all()

    overdue = []
    due_today = []
    due_this_week = []

    for task in all_pending:
        try:
            task_date = task.due_date[:10]  # Take first 10 chars: YYYY-MM-DD
            if task_date < today_str:
                overdue.append(task)
            elif task_date == today_str:
                due_today.append(task)
            elif task_date > today_str:
                # Check if within 7 days
                from datetime import date, timedelta
                td = date.fromisoformat(task_date)
                if td <= (target + timedelta(days=7)):
                    due_this_week.append(task)
        except Exception:
            continue

    return {
        "target_date": today_str,
        "overdue": overdue,
        "due_today": due_today,
        "due_this_week": due_this_week,
        "overdue_count": len(overdue),
        "due_today_count": len(due_today),
        "due_this_week_count": len(due_this_week),
    }
