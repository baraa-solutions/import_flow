"""
Business Logic & Workflows for Operational & Daily Shipment Update Engine
"""

import logging
from typing import List, Optional
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
from modules.import_files.model import ImportFile

logger = logging.getLogger(__name__)


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


def create_update_log_service(db: Session, schema: ShipmentUpdateLogCreate, user_name: str = "System") -> ShipmentUpdateLog:
    val.validate_update_log_create(schema)

    # Sync with ImportFile if needed
    import_file = db.query(ImportFile).filter(ImportFile.import_file_id == schema.import_file_id).first()
    if import_file:
        old_phase = import_file.current_module
        # If Cost Adjustment (Type B)
        if schema.update_category == "Phase Cost Adjustment" and schema.new_cost and schema.new_cost > 0:
            import_file.estimated_cost = schema.new_cost

        # Update target phase if milestone progression
        if schema.update_category == "Milestone Phase Progression" and schema.target_phase and schema.target_phase.strip():
            import_file.current_module = schema.target_phase

        # Update last notes on ImportFile
        import_file.notes = f"[{schema.log_date} - {schema.target_phase}]: {schema.note}"
        import_file.updated_at = datetime.now(timezone.utc)
        db.commit()

        # Trigger smart tasks auto-generation & close previous phase
        try:
            from modules.smart_tasks.service import auto_generate_system_tasks_for_file, auto_close_completed_phase_tasks
            if old_phase and old_phase != import_file.current_module:
                auto_close_completed_phase_tasks(db, import_file.import_file_id, old_phase)
            auto_generate_system_tasks_for_file(db, import_file)
        except Exception as exc:  # task generation must not block the update log itself
            db.rollback()
            logger.error("Shipment update: smart tasks of file %s not synced: %s", import_file.import_file_id, exc, exc_info=True)

    log_record = repo.create_update_log(db, schema, created_by=user_name)
    return log_record


def update_log_record_service(db: Session, update_id: int, schema: ShipmentUpdateLogUpdate, user_name: str = "System") -> ShipmentUpdateLog:
    update_data = schema.model_dump(exclude_unset=True)
    record = repo.update_log_record(db, update_id, update_data, updated_by=user_name)
    if not record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"تحديث الشحنة رقم '{update_id}' غير موجود.",
        )
    return record


def inspect_shipment_phases_service(db: Session, import_file_id: int) -> List[PhaseStatusInspection]:
    import_file = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
    if not import_file:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ملف الاستيراد رقم '{import_file_id}' غير موجود.",
        )

    current_mod = import_file.current_module or "Phase 1"
    
    # Determine current phase index (0-based)
    current_idx = 0
    for idx, (p_code, _, _) in enumerate(ALL_PHASES_DEFS):
        if p_code in current_mod:
            current_idx = idx
            break

    is_closed = import_file.status == "Closed"

    logs = repo.get_all_update_logs(db, import_file_id=import_file_id)

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

        phase_logs = [l for l in logs if p_code in l.target_phase]
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

def get_all_update_logs_service(db: Session, import_file_id: int = None, update_category: str = None, target_phase: str = None, search: str = None):
    return repo.get_all_update_logs(db, import_file_id=import_file_id, update_category=update_category, target_phase=target_phase, search=search)

def get_update_log_by_id_service(db: Session, update_id: int):
    return repo.get_update_log_by_id(db, update_id)

def soft_delete_update_log_service(db: Session, update_id: int):
    return repo.soft_delete_update_log(db, update_id)
