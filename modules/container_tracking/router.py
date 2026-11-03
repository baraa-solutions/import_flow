"""
FastAPI Router for Container Tracking & Individual Demurrage Charges
"""

from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.permissions import require_permission
from modules.container_tracking.schemas import (
    ContainerLifecycleUnitCreate,
    ContainerLifecycleUnitUpdate,
    ContainerLifecycleUnitOut,
    ContainerLifecycleUnitListOut,
    ContainerDemurrageOut,
    ContainerDemurrageUpdate,
    DemurrageCalculationResult,
)
from modules.container_tracking.service import ContainerTrackingService
from modules.container_tracking.repository import ContainerTrackingRepository
from modules.users.model import User

router = APIRouter(
    prefix="/api/v1/container-tracking",
    tags=["Container Tracking & Demurrage"],
)

can_view = require_permission("container_tracking.view")
can_manage = require_permission("container_tracking.manage")


@router.get(
    "/shipments/{shipment_id}/containers",
    response_model=ContainerLifecycleUnitListOut,
    summary="List containers for a shipment",
)
def list_containers(
    shipment_id: int,
    status_filter: Optional[str] = Query(None, alias="status"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    repo = ContainerTrackingRepository(db)
    items, total = repo.list_by_shipment(shipment_id, status_filter, skip, limit)
    counts = repo.count_statuses(shipment_id)

    total_demurrage = sum(
        sum(d.total_demurrage_amount for d in item.demurrage_charges if not d.is_deleted)
        for item in items
    )

    return ContainerLifecycleUnitListOut(
        items=items,
        total=total,
        on_vessel_count=counts.get("ON_VESSEL", 0),
        discharged_count=counts.get("DISCHARGED", 0),
        gate_out_held_count=counts.get("GATE_OUT_HELD", 0),
        returned_empty_count=counts.get("RETURNED_EMPTY", 0),
        damaged_count=counts.get("DAMAGED", 0),
        total_demurrage_accrued=round(total_demurrage, 2),
    )


@router.post(
    "/shipments/{shipment_id}/containers",
    response_model=ContainerLifecycleUnitOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create container lifecycle unit",
)
def create_container(
    shipment_id: int,
    payload: ContainerLifecycleUnitCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    payload.shipment_id = shipment_id
    service = ContainerTrackingService(db)
    return service.create_container(payload, user_id=current_user.user_id)


@router.get(
    "/containers/{container_id}",
    response_model=ContainerLifecycleUnitOut,
    summary="Get container details",
)
def get_container(
    container_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    repo = ContainerTrackingRepository(db)
    unit = repo.get_by_id(container_id)
    if not unit:
        from fastapi import HTTPException
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Container unit #{container_id} not found.",
        )
    return unit


@router.put(
    "/containers/{container_id}",
    response_model=ContainerLifecycleUnitOut,
    summary="Update container details and milestones",
)
def update_container(
    container_id: int,
    payload: ContainerLifecycleUnitUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = ContainerTrackingService(db)
    return service.update_container(container_id, payload, user_id=current_user.user_id)


@router.delete(
    "/containers/{container_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft delete container",
)
def delete_container(
    container_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = ContainerTrackingService(db)
    service.soft_delete_container(container_id, user_id=current_user.user_id)
    return None


@router.post(
    "/containers/{container_id}/calculate-demurrage",
    response_model=DemurrageCalculationResult,
    summary="Calculate individual container demurrage",
)
def calculate_demurrage(
    container_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = ContainerTrackingService(db)
    return service.calculate_demurrage(container_id, user_id=current_user.user_id)


@router.put(
    "/containers/{container_id}/demurrage",
    response_model=ContainerDemurrageOut,
    summary="Update container demurrage settings",
)
def update_demurrage(
    container_id: int,
    payload: ContainerDemurrageUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = ContainerTrackingService(db)
    return service.update_demurrage_settings(container_id, payload, user_id=current_user.user_id)
