from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from sqlalchemy import desc
from sqlalchemy.orm import Session

from modules.common.sequence_generator import next_yearly_code

from .model import WarehouseReceivingRecord


def generate_grn_code(db: Session) -> str:
    """Next Goods Receipt Note code GRN-YYYY-NNNN (highest numeric suffix of the year + 1)."""
    return next_yearly_code(db, WarehouseReceivingRecord.grn_code, "GRN", pad=4)


def get_warehouse_receiving_by_id(db: Session, record_id: int, include_inactive: bool = False) -> Optional[WarehouseReceivingRecord]:
    query = db.query(WarehouseReceivingRecord).filter(WarehouseReceivingRecord.receiving_id == record_id)
    if not include_inactive:
        query = query.filter(WarehouseReceivingRecord.is_active == True)
    return query.first()


def get_active_grn_for_file(
    db: Session, import_file_id: int, exclude_id: Optional[int] = None
) -> Optional[WarehouseReceivingRecord]:
    query = db.query(WarehouseReceivingRecord).filter(
        WarehouseReceivingRecord.import_file_id == import_file_id,
        WarehouseReceivingRecord.is_active == True,
    )
    if exclude_id is not None:
        query = query.filter(WarehouseReceivingRecord.receiving_id != exclude_id)
    return query.order_by(desc(WarehouseReceivingRecord.receiving_id)).first()


def get_warehouse_receiving_list(
    db: Session,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    search: Optional[str] = None,
) -> List[WarehouseReceivingRecord]:
    query = db.query(WarehouseReceivingRecord)
    if not include_inactive:
        query = query.filter(WarehouseReceivingRecord.is_active == True)
    if import_file_id:
        query = query.filter(WarehouseReceivingRecord.import_file_id == import_file_id)
    if status:
        query = query.filter(WarehouseReceivingRecord.status == status)
    if search:
        pattern = f"%{search}%"
        query = query.filter(
            (WarehouseReceivingRecord.grn_code.ilike(pattern)) |
            (WarehouseReceivingRecord.truck_plate_number.ilike(pattern)) |
            (WarehouseReceivingRecord.driver_name.ilike(pattern)) |
            (WarehouseReceivingRecord.inspector_name.ilike(pattern))
        )
    return query.order_by(desc(WarehouseReceivingRecord.receiving_id)).all()


def add_warehouse_receiving(db: Session, values: Dict[str, Any]) -> WarehouseReceivingRecord:
    """Insert + flush (the service commits once together with the file sync)."""
    now = datetime.now(timezone.utc)
    db_obj = WarehouseReceivingRecord(created_at=now, updated_at=now, **values)
    db.add(db_obj)
    db.flush()
    return db_obj


def apply_changes(db_obj: WarehouseReceivingRecord, values: Dict[str, Any], user: str) -> WarehouseReceivingRecord:
    """Set already-validated fields (no commit)."""
    for key, value in values.items():
        setattr(db_obj, key, value)
    db_obj.updated_at = datetime.now(timezone.utc)
    db_obj.updated_by = user
    return db_obj


def set_active(db_obj: WarehouseReceivingRecord, is_active: bool, user: str) -> WarehouseReceivingRecord:
    db_obj.is_active = is_active
    db_obj.updated_at = datetime.now(timezone.utc)
    db_obj.updated_by = user
    return db_obj
