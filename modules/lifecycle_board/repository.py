"""
Repository for Shipment Stage Activity & Lifecycle Board Queries
"""

from typing import Any, List, Optional, Dict
from sqlalchemy.orm import Session
from sqlalchemy import func
from modules.lifecycle_board.model import ShipmentStageActivity
from modules.import_files.model import ImportFile


def get_all_activities(db: Session, import_file_code: Optional[str] = None, status: Optional[str] = None) -> List[ShipmentStageActivity]:
    query = db.query(ShipmentStageActivity)
    if import_file_code:
        query = query.filter(ShipmentStageActivity.import_file_code == import_file_code)
    if status:
        query = query.filter(ShipmentStageActivity.status == status)
    return query.all()


def get_activity(db: Session, import_file_code: str, step_code: str) -> Optional[ShipmentStageActivity]:
    return (
        db.query(ShipmentStageActivity)
        .filter(
            ShipmentStageActivity.import_file_code == import_file_code,
            ShipmentStageActivity.step_code == step_code,
        )
        .first()
    )


def save_or_update_activity(
    db: Session,
    import_file_code: str,
    step_code: str,
    status: str,
    started_at: Optional[str] = None,
    completed_at: Optional[str] = None,
    assigned_user: Optional[str] = None,
    action_data: Optional[str] = None,
    notes: Optional[str] = None,
    msg_code: Optional[str] = None,
    msg_params: Optional[Dict[str, Any]] = None,
) -> ShipmentStageActivity:
    """``msg_code`` / ``msg_params`` describe ``notes`` (system message code + params, English render in
    ``notes``). Whenever ``notes`` is written they are written too, so user text clears a stale code."""
    rec = get_activity(db, import_file_code, step_code)
    if not rec:
        rec = ShipmentStageActivity(
            import_file_code=import_file_code,
            step_code=step_code,
            status=status,
            started_at=started_at,
            completed_at=completed_at,
            assigned_user=assigned_user,
            action_data=action_data,
            notes=notes,
            msg_code=msg_code if notes else None,
            msg_params=msg_params if notes else None,
        )
        db.add(rec)
    else:
        rec.status = status
        if started_at:
            rec.started_at = started_at
        if completed_at:
            rec.completed_at = completed_at
        if assigned_user:
            rec.assigned_user = assigned_user
        if action_data:
            rec.action_data = action_data
        if notes:
            rec.notes = notes
            rec.msg_code = msg_code
            rec.msg_params = msg_params
    db.commit()
    db.refresh(rec)
    return rec


def get_step_counts(db: Session) -> Dict[str, int]:
    rows = (
        db.query(ShipmentStageActivity.step_code, func.count(ShipmentStageActivity.id))
        .filter(ShipmentStageActivity.status == "In-Progress")
        .group_by(ShipmentStageActivity.step_code)
        .all()
    )
    return {row[0]: row[1] for row in rows}


def get_active_shipments_with_details(db: Session, step_code: Optional[str] = None):
    query = (
        db.query(ShipmentStageActivity, ImportFile)
        .join(ImportFile, ShipmentStageActivity.import_file_code == ImportFile.import_file_code)
        .filter(ShipmentStageActivity.status == "In-Progress")
    )
    if step_code:
        query = query.filter(ShipmentStageActivity.step_code == step_code)
    return query.all()


def get_completed_activities_for_files(db: Session, import_file_codes: List[str]) -> Dict[str, List[ShipmentStageActivity]]:
    """
    Batch fetches all completed activities for a list of import file codes in a single query
    to eliminate N+1 roundtrips.
    """
    if not import_file_codes:
        return {}
    activities = (
        db.query(ShipmentStageActivity)
        .filter(
            ShipmentStageActivity.import_file_code.in_(import_file_codes),
            ShipmentStageActivity.status == "Completed",
        )
        .order_by(ShipmentStageActivity.id.asc())
        .all()
    )
    result: Dict[str, List[ShipmentStageActivity]] = {}
    for act in activities:
        result.setdefault(act.import_file_code, []).append(act)
    return result


# ─── Configurable Step Risk & Settings Repository (Addendum: Section 10) ───

from modules.lifecycle_board.model import StepConfig, StepConfigAuditLog, PendingReferenceRecord


def get_all_step_configs(db: Session) -> List[StepConfig]:
    return db.query(StepConfig).order_by(StepConfig.phase_id.asc(), StepConfig.step_code.asc()).all()


def get_step_config(db: Session, step_code: str) -> Optional[StepConfig]:
    return db.query(StepConfig).filter(StepConfig.step_code == step_code).first()


def save_step_config(db: Session, config: StepConfig) -> StepConfig:
    db.add(config)
    db.commit()
    db.refresh(config)
    return config


def save_step_config_audit_log(db: Session, log: StepConfigAuditLog) -> StepConfigAuditLog:
    db.add(log)
    db.commit()
    db.refresh(log)
    return log


def get_step_config_audit_logs(db: Session, step_code: Optional[str] = None) -> List[StepConfigAuditLog]:
    query = db.query(StepConfigAuditLog)
    if step_code:
        query = query.filter(StepConfigAuditLog.step_code == step_code)
    return query.order_by(StepConfigAuditLog.id.desc()).all()


def save_pending_reference(db: Session, rec: PendingReferenceRecord) -> PendingReferenceRecord:
    db.add(rec)
    db.commit()
    db.refresh(rec)
    return rec


def get_pending_references(db: Session, import_file_code: Optional[str] = None, step_code: Optional[str] = None) -> List[PendingReferenceRecord]:
    query = db.query(PendingReferenceRecord)
    if import_file_code:
        query = query.filter(PendingReferenceRecord.import_file_code == import_file_code)
    if step_code:
        query = query.filter(PendingReferenceRecord.step_code == step_code)
    return query.order_by(PendingReferenceRecord.id.desc()).all()

