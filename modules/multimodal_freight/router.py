"""
FastAPI Router for Multimodal Freight Details (Air, LCL, Ro-Ro, Bulk)
"""

from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.permissions import require_permission
from modules.multimodal_freight.schemas import (
    MultimodalFreightCreate,
    MultimodalFreightUpdate,
    MultimodalFreightOut,
    MultimodalFreightListOut,
    ModeCostCalculationResult,
)
from modules.multimodal_freight.service import MultimodalFreightService
from modules.multimodal_freight.repository import MultimodalFreightRepository
from modules.users.model import User

router = APIRouter(
    prefix="/api/v1/multimodal-freight",
    tags=["Multimodal Freight Details"],
)

can_view = require_permission("multimodal_freight.view")
can_manage = require_permission("multimodal_freight.manage")


@router.get(
    "/shipments/{shipment_id}/freight-details",
    response_model=MultimodalFreightListOut,
    summary="List multimodal freight details for a shipment",
)
def list_freight_details(
    shipment_id: int,
    transport_mode: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    repo = MultimodalFreightRepository(db)
    service = MultimodalFreightService(db)
    items, total = repo.list_by_shipment(shipment_id, transport_mode, skip, limit)
    counts = repo.count_modes(shipment_id)

    out_items = []
    total_est = 0.0
    for it in items:
        subtotal = service.calculate_subtotal(it)
        total_est += subtotal
        out_item = MultimodalFreightOut.model_validate(it)
        out_item.calculated_subtotal = subtotal
        out_items.append(out_item)

    return MultimodalFreightListOut(
        items=out_items,
        total=total,
        air_count=counts.get("AIR", 0),
        lcl_count=counts.get("LCL", 0),
        roro_count=counts.get("RORO", 0),
        bulk_count=counts.get("BULK", 0),
        total_estimated_charges=round(total_est, 2),
    )


@router.post(
    "/shipments/{shipment_id}/freight-details",
    response_model=MultimodalFreightOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create multimodal freight details record",
)
def create_freight_details(
    shipment_id: int,
    payload: MultimodalFreightCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    payload.shipment_id = shipment_id
    service = MultimodalFreightService(db)
    record = service.create_details(payload, user_id=current_user.user_id)
    out = MultimodalFreightOut.model_validate(record)
    out.calculated_subtotal = service.calculate_subtotal(record)
    return out


@router.get(
    "/freight-details/{details_id}",
    response_model=MultimodalFreightOut,
    summary="Get single freight details record",
)
def get_freight_details(
    details_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    repo = MultimodalFreightRepository(db)
    service = MultimodalFreightService(db)
    details = repo.get_by_id(details_id)
    if not details:
        from fastapi import HTTPException
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Freight details #{details_id} not found.",
        )
    out = MultimodalFreightOut.model_validate(details)
    out.calculated_subtotal = service.calculate_subtotal(details)
    return out


@router.put(
    "/freight-details/{details_id}",
    response_model=MultimodalFreightOut,
    summary="Update multimodal freight details",
)
def update_freight_details(
    details_id: int,
    payload: MultimodalFreightUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = MultimodalFreightService(db)
    record = service.update_details(details_id, payload, user_id=current_user.user_id)
    out = MultimodalFreightOut.model_validate(record)
    out.calculated_subtotal = service.calculate_subtotal(record)
    return out


@router.delete(
    "/freight-details/{details_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft delete multimodal freight details",
)
def delete_freight_details(
    details_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = MultimodalFreightService(db)
    service.soft_delete_details(details_id, user_id=current_user.user_id)
    return None


@router.post(
    "/freight-details/{details_id}/calculate-mode-costs",
    response_model=ModeCostCalculationResult,
    summary="Calculate mode charges subtotal and breakdown",
)
def calculate_mode_costs(
    details_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = MultimodalFreightService(db)
    return service.calculate_mode_costs(details_id)
