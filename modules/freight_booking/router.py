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
    ShipmentEtaTrackingLogCreate,
    ShipmentEtaTrackingLogResponse,
    ConfirmAtaRequest,
    AirWeightCalculationRequest,
    AirWeightCalculationResponse,
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


@router.post(
    "/eta-tracking-logs",
    response_model=ShipmentEtaTrackingLogResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Record periodic vessel ETA tracking log (every 3 days) during transit (TASK-BE-11)",
)
def create_eta_tracking_log(
    payload: ShipmentEtaTrackingLogCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("freight_booking.create")),
):
    return service.create_eta_tracking_log_service(db, payload, user=current_user.username)


@router.get(
    "/bookings/{booking_id}/eta-tracking-logs",
    response_model=List[ShipmentEtaTrackingLogResponse],
    summary="Get all ETA tracking logs for a shipment booking (TASK-BE-11)",
)
def get_booking_eta_tracking_logs(
    booking_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("freight_booking.view")),
):
    return service.get_eta_tracking_logs_service(db, booking_id=booking_id)


@router.get(
    "/files/{import_file_id}/eta-tracking-logs",
    response_model=List[ShipmentEtaTrackingLogResponse],
    summary="Get all ETA tracking logs for an import file (TASK-BE-11)",
)
def get_file_eta_tracking_logs(
    import_file_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("freight_booking.view")),
):
    return service.get_eta_tracking_logs_service(db, import_file_id=import_file_id)


@router.post(
    "/bookings/{booking_id}/confirm-ata",
    response_model=ShipmentEtaTrackingLogResponse,
    summary="Confirm actual port arrival (ATA) and berth (TASK-BE-11)",
)
def confirm_port_arrival(
    booking_id: int,
    payload: ConfirmAtaRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("freight_booking.confirm")),
):
    return service.confirm_ata_service(db, booking_id, payload, user=current_user.username)


@router.post(
    "/calculate-air-weight",
    response_model=AirWeightCalculationResponse,
    summary="Calculate Air Freight volumetric and chargeable weight based on IATA rules",
)
def calculate_air_weight(
    payload: AirWeightCalculationRequest,
    current_user: User = Depends(require_permission("freight_booking.view")),
):
    return service.calculate_air_weight_service(payload)
