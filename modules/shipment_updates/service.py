"""
Business Logic & Workflows for Operational & Daily Shipment Update Engine
"""

import logging
from typing import List, Optional, Tuple
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from modules.shipment_updates.model import ShipmentUpdateLog
from modules.shipment_updates.schemas import (
    ShipmentUpdateLogCreate,
    ShipmentUpdateLogUpdate,
    PhaseStatusInspection,
)
import modules.shipment_updates.repository as repo
import modules.shipment_updates.validators as val
from modules.common.errors import best_effort
from modules.common.file_tracking import set_file_tracking
from modules.common.validators import not_null_columns, not_found, require_active
from modules.import_files.model import ImportFile

logger = logging.getLogger(__name__)

RECORD_LABEL_AR = "تحديث الشحنة"


# phase_name is deprecated (single-language rule): Flutter renders the label from phase_number.
ALL_PHASES_DEFS = [
    ("Phase 1", "P1: التخطيط والنولون", 1),
    ("Phase 2", "P2: الاعتماد المالي", 2),
    ("Phase 3", "P3: المستندات و ACID", 3),
    ("Phase 4", "P4: حجز الشحن والناقل", 4),
    ("Phase 5", "P5: الشحن وتتبع CargoX", 5),
    ("Phase 6", "P6: إقرار 46 والتعريفه", 6),
    ("Phase 7", "P7: التخليص وسداد الرسوم", 7),
    ("Phase 8", "P8: استلام المخازن GRN", 8),
    ("Phase 9", "P9: تسوية تكلفة الوصول", 9),
    ("Phase 10", "P10: إغلاق الملف والأرشفة", 10),
]

MILESTONE_CATEGORY = "Milestone Phase Progression"


def _phase_number(value: Optional[str]) -> Optional[int]:
    return val.phase_number(value)


def _current_business_phase(import_file: ImportFile, logs: List[ShipmentUpdateLog]) -> int:
    """The file's board position (step code / board phase / legacy text), moved forward by the latest
    milestone progression log (milestones set only the board phase, never the GP-002 step)."""
    current = val.business_phase_of_file(
        import_file.current_step_code, import_file.current_phase_id, import_file.current_module
    )
    milestone = next((l for l in logs if l.update_category == MILESTONE_CATEGORY), None)
    milestone_phase = _phase_number(milestone.target_phase) if milestone else None
    return max(current, milestone_phase or 0)


def create_update_log_service(db: Session, schema: ShipmentUpdateLogCreate, user_name: str = "System") -> ShipmentUpdateLog:
    val.validate_update_log_create(schema)
    import_file = require_active(db, ImportFile, schema.import_file_id, "ملف الاستيراد", status_code=status.HTTP_404_NOT_FOUND)
    file_code = import_file.import_file_code or import_file.custom_file_number

    old_stage = import_file.current_stage
    server_prev_cost: Optional[float] = None
    # Cost Adjustment (Type B)
    if schema.update_category == "Phase Cost Adjustment":
        server_prev_cost = float(import_file.estimated_cost or 0.0)
        import_file.estimated_cost = schema.new_cost
        import_file.updated_at = datetime.now(timezone.utc)
    # Milestone progression: target_phase is validated as "Phase 1".."Phase 10" by the schema. Only the board
    # phase moves (through the shared tracking writer), never backwards, and never the GP-002 step.
    if schema.update_category == MILESTONE_CATEGORY:
        board_phase = val.BOARD_PHASE_BY_BUSINESS[_phase_number(schema.target_phase)]
        if import_file.current_phase_id is None or board_phase > import_file.current_phase_id:
            set_file_tracking(import_file, phase_id=board_phase)

    # Q8 (safe default): append to the file notes instead of overwriting them
    entry = f"[{schema.log_date} - {schema.target_phase}]: {schema.note}"
    import_file.notes = f"{import_file.notes}\n{entry}" if import_file.notes else entry
    import_file.updated_at = datetime.now(timezone.utc)

    assigned = schema.assigned_user if "assigned_user" in schema.model_fields_set and schema.assigned_user else user_name
    log_record = repo.create_update_log(
        db,
        schema,
        created_by=user_name,
        import_file_code=file_code,
        assigned_user=assigned,
        previous_cost=server_prev_cost,
    )
    db.commit()
    db.refresh(log_record)

    # Follow-up: smart tasks auto-generation & close previous phase (never undoes the saved log)
    def _sync_tasks() -> None:
        from modules.smart_tasks.service import auto_generate_system_tasks_for_file, auto_close_completed_phase_tasks
        # the full stage title ("Phase 3: Booking & Doc Prep"), so "Phase 1" never closes "Phase 10" tasks
        if old_stage and old_stage != import_file.current_stage:
            auto_close_completed_phase_tasks(db, import_file.import_file_id, old_stage)
        auto_generate_system_tasks_for_file(db, import_file)

    best_effort(db, _sync_tasks, f"Shipment update: smart tasks of file {import_file.import_file_id}")
    db.refresh(log_record)
    return log_record


def update_log_record_service(db: Session, update_id: int, schema: ShipmentUpdateLogUpdate, user_name: str = "System") -> ShipmentUpdateLog:
    record = repo.get_update_log_by_id(db, update_id)
    if not record:
        raise not_found(RECORD_LABEL_AR, update_id)

    val.validate_update_log_record(schema)

    required = not_null_columns(ShipmentUpdateLog)
    # an explicit null on a NOT NULL column (note, log_date, assigned_user...) keeps the stored value
    update_data = {k: v for k, v in schema.model_dump(exclude_unset=True).items() if v is not None or k not in required}
    updated = repo.update_log_record(db, update_id, update_data, updated_by=user_name)
    db.commit()
    db.refresh(updated)
    return updated


def inspect_shipment_phases_service(db: Session, import_file_id: int) -> List[PhaseStatusInspection]:
    import_file = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
    if not import_file:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ملف الاستيراد رقم '{import_file_id}' غير موجود.",
        )

    logs, _ = repo.get_all_update_logs(db, import_file_id=import_file_id, limit=500)  # newest first

    # Current phase index (0-based)
    current_idx = min(max(_current_business_phase(import_file, logs), 1), len(ALL_PHASES_DEFS)) - 1

    is_closed = import_file.status == "Closed"

    inspections = []
    for idx, (p_code, p_name, p_num) in enumerate(ALL_PHASES_DEFS):
        if is_closed:
            st = "Completed"
        elif idx < current_idx:
            st = "Completed"
        elif idx == current_idx:
            st = "Current"
        else:
            st = "Future"

        phase_logs = [l for l in logs if _phase_number(l.target_phase) == p_num]
        last_note = phase_logs[0].note if phase_logs else None
        last_date = phase_logs[0].log_date if phase_logs else None

        inspections.append(
            PhaseStatusInspection(
                phase_code=p_code,
                phase_name=p_name,
                phase_number=p_num,
                status=st,
                completion_date=last_date,
                last_note=last_note,
                update_count=len(phase_logs),
            )
        )

    return inspections


def get_all_update_logs_service(
    db: Session,
    import_file_id: Optional[int] = None,
    update_category: Optional[str] = None,
    target_phase: Optional[str] = None,
    search: Optional[str] = None,
    skip: int = 0,
    limit: int = 200,
) -> Tuple[List[ShipmentUpdateLog], int]:
    return repo.get_all_update_logs(
        db,
        import_file_id=import_file_id,
        update_category=update_category,
        target_phase=target_phase,
        search=search,
        skip=skip,
        limit=limit,
    )


def get_update_log_by_id_service(db: Session, update_id: int) -> ShipmentUpdateLog:
    record = repo.get_update_log_by_id(db, update_id)
    if not record:
        raise not_found(RECORD_LABEL_AR, update_id)
    return record


def soft_delete_update_log_service(db: Session, update_id: int, user_name: str = "System") -> bool:
    record = repo.get_update_log_by_id(db, update_id)
    if not record:
        raise not_found(RECORD_LABEL_AR, update_id)

    if record.update_category == "Phase Cost Adjustment":
        # Check if it is the latest active cost adjustment log for this file
        latest_cost_log = (
            db.query(ShipmentUpdateLog)
            .filter(
                ShipmentUpdateLog.import_file_id == record.import_file_id,
                ShipmentUpdateLog.is_active == True,
                ShipmentUpdateLog.update_category == "Phase Cost Adjustment",
            )
            .order_by(ShipmentUpdateLog.update_id.desc())
            .first()
        )
        if latest_cost_log and latest_cost_log.update_id == record.update_id:
            import_file = db.query(ImportFile).filter(ImportFile.import_file_id == record.import_file_id).first()
            if import_file and abs((import_file.estimated_cost or 0.0) - (record.new_cost or 0.0)) < 1e-6:
                import_file.estimated_cost = record.previous_cost or 0.0
                import_file.updated_at = datetime.now(timezone.utc)

    repo.soft_delete_update_log(db, update_id, deleted_by=user_name)
    db.commit()
    return True
