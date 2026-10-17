"""
FastAPI Router for Phase 4 – Freight Booking & Container Allocation
"""

from typing import List, Optional
from fastapi import APIRouter, Depends, Query, Response, status
from modules.auth.router import get_current_user
from modules.auth.permissions import require_permission
from modules.users.model import User
from sqlalchemy.orm import Session

from database.database import get_db
from modules.freight_booking.schemas import (
    ShipmentBookingCreate,
    ShipmentBookingUpdate,
    ShipmentBookingConfirm,
    ShipmentDepartureConfirm,
    ShipmentBookingResponse,
)
import modules.freight_booking.service as service

router = APIRouter(prefix="/api/v1/freight-booking", tags=["Freight Booking & Container Allocation (Phase 4)"], dependencies=[Depends(get_current_user)])


@router.post(
    "",
    response_model=ShipmentBookingResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new Shipment Booking request",
)
def create_booking(
    payload: ShipmentBookingCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("freight_booking.create")),
):
    return service.create_booking_service(db, payload, user=current_user.username)


@router.get(
    "",
    response_model=List[ShipmentBookingResponse],
    summary="List shipment bookings with filters",
)
def list_bookings(
    response: Response,
    include_inactive: bool = False,
    import_file_id: Optional[int] = Query(None),
    status: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(200, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("freight_booking.view")),
):
    items, total = service.list_bookings_service(
        db, include_inactive, import_file_id, status, search, skip=skip, limit=limit
    )
    response.headers["X-Total-Count"] = str(total)
    return items


@router.get(
    "/{booking_id}",
    response_model=ShipmentBookingResponse,
    summary="Get single shipment booking by ID",
)
def get_booking(
    booking_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("freight_booking.view")),
):
    return service.get_booking_service(db, booking_id)


@router.put(
    "/{booking_id}",
    response_model=ShipmentBookingResponse,
    summary="Update shipment booking record",
)
def update_booking(
    booking_id: int,
    payload: ShipmentBookingUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("freight_booking.create")),
):
    return service.update_booking_service(db, booking_id, payload, user=current_user.username)


@router.post(
    "/{booking_id}/confirm",
    response_model=ShipmentBookingResponse,
    summary="Confirm freight booking with carrier booking confirmation no and dates (BK-01)",
)
def confirm_booking(
    booking_id: int,
    payload: ShipmentBookingConfirm,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("freight_booking.confirm")),
):
    return service.confirm_booking_service(db, booking_id, payload, user=current_user.username)


@router.post(
    "/{booking_id}/depart",
    response_model=ShipmentBookingResponse,
    summary="Confirm actual departure & register Bill of Lading (B/L) number (SH-01)",
)
def confirm_departure(
    booking_id: int,
    payload: ShipmentDepartureConfirm,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("freight_booking.confirm")),
):
    return service.confirm_departure_and_bol_service(db, booking_id, payload, user=current_user.username)


@router.delete(
    "/{booking_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft delete a shipment booking",
)
def delete_booking(
    booking_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("freight_booking.create")),
):
    service.soft_delete_booking_service(db, booking_id, user=current_user.username)
    return None


@router.patch(
    "/{booking_id}/restore",
    response_model=ShipmentBookingResponse,
    summary="Restore a soft-deleted shipment booking",
)
def restore_booking(
    booking_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("freight_booking.create")),
):
    return service.restore_booking_service(db, booking_id, user=current_user.username)
