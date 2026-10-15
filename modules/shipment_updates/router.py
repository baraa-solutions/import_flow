"""
FastAPI Router for Operational & Daily Shipment Update Engine
"""

from typing import List, Optional
from fastapi import APIRouter, Depends, status
from modules.auth.router import get_current_user
from modules.auth.permissions import require_permission
from modules.users.model import User
from sqlalchemy.orm import Session

from database.database import get_db
from modules.shipment_updates.schemas import (
    ShipmentUpdateLogCreate,
    ShipmentUpdateLogUpdate,
    ShipmentUpdateLogResponse,
    PhaseStatusInspection,
)
import modules.shipment_updates.service as service

router = APIRouter(prefix="/api/v1/shipment-updates", tags=["Shipment Operational & Daily Update Engine"], dependencies=[Depends(get_current_user)])


@router.post(
    "",
    response_model=ShipmentUpdateLogResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Record a new shipment update or daily check-in",
)
def create_update_log(
    payload: ShipmentUpdateLogCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("import_files.edit")),
):
    return service.create_update_log_service(db, payload, user_name=current_user.username)


@router.get(
    "",
    response_model=List[ShipmentUpdateLogResponse],
    summary="List all update logs with filters",
)
def list_update_logs(
    import_file_id: Optional[int] = None,
    update_category: Optional[str] = None,
    target_phase: Optional[str] = None,
    search: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("import_files.view")),
):
    return service.get_all_update_logs_service(
        db,
        import_file_id=import_file_id,
        update_category=update_category,
        target_phase=target_phase,
        search=search,
    )


@router.get(
    "/inspect/{import_file_id}",
    response_model=List[PhaseStatusInspection],
    summary="Inspect 10 phases status (Completed, Current, Future) for a specific shipment",
)
def inspect_shipment_phases(
    import_file_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("import_files.view")),
):
    return service.inspect_shipment_phases_service(db, import_file_id)


@router.get(
    "/{update_id}",
    response_model=ShipmentUpdateLogResponse,
    summary="Get single update record by ID",
)
def get_update_log(
    update_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("import_files.view")),
):
    return service.get_update_log_by_id_service(db, update_id)


@router.put(
    "/{update_id}",
    response_model=ShipmentUpdateLogResponse,
    summary="Update log record",
)
def update_log_record(
    update_id: int,
    payload: ShipmentUpdateLogUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("import_files.edit")),
):
    return service.update_log_record_service(db, update_id, payload, user_name=current_user.username)


@router.delete(
    "/{update_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft delete update record",
)
def soft_delete_update_log(
    update_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("import_files.edit")),
):
    service.soft_delete_update_log_service(db, update_id, user_name=current_user.username)
