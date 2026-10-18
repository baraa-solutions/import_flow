"""
FastAPI Router for Smart Task Management & Reminder Engine (Feature 2.4 & 2.5)
"""

from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.router import get_current_user, require_admin
from modules.auth.permissions import require_permission
from modules.common.pagination import Page, PageParams
from modules.smart_tasks.schemas import (
    SmartTaskCreate,
    SmartTaskUpdate,
    SmartTaskResponse,
    SmartTaskSummaryMetrics,
    ReminderEngineResponse,
)
from modules.smart_tasks.model import SmartTask
import modules.smart_tasks.service as service

router = APIRouter(prefix="/api/v1/smart-tasks", tags=["Smart Task Management & Reminders"], dependencies=[Depends(get_current_user)])


@router.post(
    "",
    response_model=SmartTaskResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new Smart Task or Manual To-Do",
    dependencies=[Depends(require_permission("import_files.edit"))],
)
def create_task(payload: SmartTaskCreate, db: Session = Depends(get_db)):
    return service.create_task_service(db, payload)


@router.get(
    "/paginated",
    response_model=Page[SmartTaskResponse],
    summary="List tasks with pagination, sorting, search, and filters",
    dependencies=[Depends(require_permission("import_files.view"))],
)
def list_tasks_paginated(
    response: Response,
    params: PageParams = Depends(),
    task_type: Optional[str] = None,
    status: Optional[str] = None,
    priority: Optional[str] = None,
    import_file_id: Optional[int] = None,
    assigned_to: Optional[str] = None,
    db: Session = Depends(get_db),
):
    return service.get_paginated_tasks_service(
        db,
        params=params,
        response=response,
        task_type=task_type,
        status=status,
        priority=priority,
        import_file_id=import_file_id,
        assigned_to=assigned_to,
    )


@router.get(
    "",
    response_model=List[SmartTaskResponse],
    summary="List all tasks with filters",
    dependencies=[Depends(require_permission("import_files.view"))],
)
def list_tasks(
    include_inactive: bool = False,
    task_type: Optional[str] = None,
    status: Optional[str] = None,
    priority: Optional[str] = None,
    import_file_id: Optional[int] = None,
    search: Optional[str] = None,
    order_by_priority: bool = False,
    db: Session = Depends(get_db),
):
    return service.get_all_tasks_service(
        db,
        include_inactive=include_inactive,
        task_type=task_type,
        status=status,
        priority=priority,
        import_file_id=import_file_id,
        search=search,
        order_by_priority=order_by_priority,
    )


@router.get(
    "/metrics/summary",
    response_model=SmartTaskSummaryMetrics,
    summary="Get operational dashboard metrics summary",
    dependencies=[Depends(require_permission("import_files.view"))],
)
def get_metrics_summary(db: Session = Depends(get_db)):
    return service.get_dashboard_summary_metrics_service(db)


@router.get(
    "/reminders/due",
    response_model=ReminderEngineResponse,
    summary="Feature 2.5 — Reminder Engine: Get overdue, due today, and upcoming tasks",
    dependencies=[Depends(require_permission("import_files.view"))],
)
def get_due_reminders(
    target_date: Optional[str] = None,
    db: Session = Depends(get_db),
):
    """
    Reminder Engine (Feature 2.5):
    Returns tasks segmented into: overdue, due today, due this week.
    Optionally pass target_date=YYYY-MM-DD to simulate a specific day.
    """
    return service.get_due_and_overdue_tasks_service(db, target_date_str=target_date)


@router.get(
    "/{task_id}",
    response_model=SmartTaskResponse,
    summary="Get single smart task by ID",
    dependencies=[Depends(require_permission("import_files.view"))],
)
def get_task(task_id: int, db: Session = Depends(get_db)):
    task = service.get_task_by_id_service(db, task_id)
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"المهمة رقم '{task_id}' غير موجودة.",
        )
    return task


@router.put(
    "/{task_id}",
    response_model=SmartTaskResponse,
    summary="Update smart task",
    dependencies=[Depends(require_permission("import_files.edit"))],
)
def update_task(task_id: int, payload: SmartTaskUpdate, db: Session = Depends(get_db)):
    return service.update_task_service(db, task_id, payload)


@router.delete(
    "/{task_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft delete a smart task",
    dependencies=[Depends(require_permission("import_files.edit"))],
)
def soft_delete_task(task_id: int, db: Session = Depends(get_db)):
    success = service.soft_delete_task_service(db, task_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"المهمة رقم '{task_id}' غير موجودة.",
        )


@router.patch(
    "/{task_id}/restore",
    response_model=SmartTaskResponse,
    summary="Restore soft deleted smart task",
    dependencies=[Depends(require_permission("import_files.edit"))],
)
def restore_task(task_id: int, db: Session = Depends(get_db)):
    task = service.restore_task_service(db, task_id)
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"المهمة رقم '{task_id}' غير موجودة.",
        )
    return task


# ─── Phase Transition Endpoints (Feature Medium Priority) ─────────────────────

@router.post(
    "/phase-transition/generate-tasks/{import_file_id}",
    summary="Generate system tasks automatically for current phase of import file",
    response_model=dict,
    dependencies=[Depends(require_permission("import_files.edit"))],
)
def generate_phase_tasks(import_file_id: int, db: Session = Depends(get_db)):
    """
    Medium Priority: Automatic Smart Task Generation on Phase Transition.
    Call this endpoint whenever an import file advances to a new phase.
    System will auto-create standard follow-up tasks for the current phase.
    """
    return service.generate_phase_tasks_service(db, import_file_id)

@router.post(
    "/phase-transition/complete-phase/{import_file_id}",
    summary="Auto-close system tasks when a phase is marked complete",
    response_model=dict,
    dependencies=[Depends(require_permission("import_files.edit"))],
)
def complete_phase_tasks(
    import_file_id: int,
    completed_phase: str,
    db: Session = Depends(get_db),
):
    """
    Medium Priority: Auto-close all system tasks belonging to a completed phase.
    E.g. when Phase 3 is done, all Phase 3 system tasks become 'Completed'.
    """
    return service.complete_phase_tasks_service(db, import_file_id, completed_phase)

@router.post(
    "/sync-all-active-files",
    summary="Synchronize and generate pending tasks for all active import files",
    response_model=dict,
    dependencies=[Depends(require_admin)],
)
def sync_all_active_files(db: Session = Depends(get_db)):
    count = service.sync_all_active_shipments_tasks(db)
    return {
        "processed_files_count": count,
        "message": f"تمت مزامنة وتوليد المهام الذكية لـ {count} ملف استيرادي نشط بنجاح.",
    }
