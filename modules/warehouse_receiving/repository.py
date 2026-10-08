from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

from fastapi import Response
from sqlalchemy import desc
from sqlalchemy.orm import Session

from modules.common.pagination import PageParams, like_term, paginate
from modules.common.sequence_generator import next_yearly_code

from .model import WarehouseReceivingRecord

WAREHOUSE_RECEIVING_SORT_MAP = {
    "receiving_id": WarehouseReceivingRecord.receiving_id,
    "grn_code": WarehouseReceivingRecord.grn_code,
    "created_at": WarehouseReceivingRecord.created_at,
    "status": WarehouseReceivingRecord.status,
    "warehouse_name": WarehouseReceivingRecord.warehouse_name,
    "arrival_datetime": WarehouseReceivingRecord.arrival_datetime,
    "import_file_id": WarehouseReceivingRecord.import_file_id,
    "discrepancy_type": WarehouseReceivingRecord.discrepancy_type,
}


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


def _apply_receiving_filters(
    query,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    search: Optional[str] = None,
):
    if not include_inactive:
        query = query.filter(WarehouseReceivingRecord.is_active == True)
    if import_file_id:
        query = query.filter(WarehouseReceivingRecord.import_file_id == import_file_id)
    if status:
        query = query.filter(WarehouseReceivingRecord.status == status)
    if search and search.strip():
        term = like_term(search)
        if term:
            query = query.filter(
                (WarehouseReceivingRecord.grn_code.ilike(term, escape="\\")) |
                (WarehouseReceivingRecord.truck_plate_number.ilike(term, escape="\\")) |
                (WarehouseReceivingRecord.driver_name.ilike(term, escape="\\")) |
                (WarehouseReceivingRecord.inspector_name.ilike(term, escape="\\")) |
                (WarehouseReceivingRecord.warehouse_name.ilike(term, escape="\\"))
            )
    return query


def paginate_warehouse_receivings(
    db: Session,
    params: PageParams,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    response: Optional[Response] = None,
) -> Dict[str, Any]:
    query = db.query(WarehouseReceivingRecord)
    query = _apply_receiving_filters(
        query,
        include_inactive=params.include_inactive or include_inactive,
        import_file_id=import_file_id,
        status=status,
        search=params.q,
    )
    return paginate(
        query,
        params,
        sort_map=WAREHOUSE_RECEIVING_SORT_MAP,
        default_sort=[desc(WarehouseReceivingRecord.receiving_id)],
        pk=WarehouseReceivingRecord.receiving_id,
        response=response,
    )


def get_warehouse_receiving_list(
    db: Session,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    search: Optional[str] = None,
    skip: int = 0,
    limit: int = 200,
) -> Tuple[List[WarehouseReceivingRecord], int]:
    query = db.query(WarehouseReceivingRecord)
    query = _apply_receiving_filters(
        query,
        include_inactive=include_inactive,
        import_file_id=import_file_id,
        status=status,
        search=search,
    )
    total = query.count()
    query = query.order_by(desc(WarehouseReceivingRecord.receiving_id))
    if skip:
        query = query.offset(skip)
    if limit is not None:
        query = query.limit(limit)
    return query.all(), total


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
