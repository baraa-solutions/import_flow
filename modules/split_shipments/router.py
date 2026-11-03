"""
FastAPI Router for Split Shipments & Multi-PO Allocations
"""

from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.permissions import require_permission
from modules.split_shipments.schemas import (
    SplitShipmentAllocationCreate,
    SplitShipmentAllocationUpdate,
    SplitShipmentAllocationOut,
    SplitShipmentAllocationListOut,
    BatchAllocationCreate,
    ProratedCostCalculationRequest,
    ProratedCostCalculationResponse,
)
from modules.split_shipments.service import SplitShipmentService
from modules.split_shipments.repository import SplitShipmentRepository
from modules.users.model import User

router = APIRouter(
    prefix="/api/v1/split-shipments",
    tags=["Split Shipments & Allocations"],
)

can_view = require_permission("split_shipments.view")
can_manage = require_permission("split_shipments.manage")


@router.get(
    "/shipments/{shipment_id}/allocations",
    response_model=SplitShipmentAllocationListOut,
    summary="List split allocations for a shipment",
)
def list_allocations(
    shipment_id: int,
    split_bl_number: Optional[str] = Query(None),
    parent_bl_number: Optional[str] = Query(None),
    po_id: Optional[int] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    repo = SplitShipmentRepository(db)
    items, total = repo.list_by_shipment(
        shipment_id,
        split_bl_number=split_bl_number,
        parent_bl_number=parent_bl_number,
        po_id=po_id,
        skip=skip,
        limit=limit,
    )
    unique_bls = repo.get_unique_split_bls(shipment_id)

    total_qty = sum(item.allocated_quantity for item in items)
    total_customs = sum(item.prorated_customs_cost for item in items)
    total_freight = sum(item.prorated_freight_cost for item in items)

    return SplitShipmentAllocationListOut(
        items=items,
        total=total,
        unique_split_bl_count=len(unique_bls),
        total_allocated_quantity=round(total_qty, 2),
        total_prorated_customs=round(total_customs, 2),
        total_prorated_freight=round(total_freight, 2),
    )


@router.post(
    "/shipments/{shipment_id}/allocations",
    response_model=SplitShipmentAllocationOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create single split shipment allocation",
)
def create_allocation(
    shipment_id: int,
    payload: SplitShipmentAllocationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    payload.shipment_id = shipment_id
    service = SplitShipmentService(db)
    return service.create_allocation(payload, user_id=current_user.user_id)


@router.post(
    "/shipments/{shipment_id}/batch-allocate",
    response_model=List[SplitShipmentAllocationOut],
    status_code=status.HTTP_201_CREATED,
    summary="Batch create split allocations from multi-PO lines",
)
def batch_allocate(
    shipment_id: int,
    payload: BatchAllocationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    payload.shipment_id = shipment_id
    service = SplitShipmentService(db)
    return service.create_batch_allocations(payload, user_id=current_user.user_id)


@router.get(
    "/allocations/{allocation_id}",
    response_model=SplitShipmentAllocationOut,
    summary="Get allocation details",
)
def get_allocation(
    allocation_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    repo = SplitShipmentRepository(db)
    alloc = repo.get_by_id(allocation_id)
    if not alloc:
        from fastapi import HTTPException
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Split allocation #{allocation_id} not found.",
        )
    return alloc


@router.put(
    "/allocations/{allocation_id}",
    response_model=SplitShipmentAllocationOut,
    summary="Update allocation quantity or details",
)
def update_allocation(
    allocation_id: int,
    payload: SplitShipmentAllocationUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = SplitShipmentService(db)
    return service.update_allocation(allocation_id, payload, user_id=current_user.user_id)


@router.delete(
    "/allocations/{allocation_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft delete allocation",
)
def delete_allocation(
    allocation_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = SplitShipmentService(db)
    service.soft_delete_allocation(allocation_id, user_id=current_user.user_id)
    return None


@router.post(
    "/shipments/{shipment_id}/calculate-prorated-costs",
    response_model=ProratedCostCalculationResponse,
    summary="Recalculate prorated customs and freight costs across allocations",
)
def calculate_prorated_costs(
    shipment_id: int,
    payload: ProratedCostCalculationRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    payload.shipment_id = shipment_id
    service = SplitShipmentService(db)
    return service.calculate_prorated_costs(payload, user_id=current_user.user_id)
