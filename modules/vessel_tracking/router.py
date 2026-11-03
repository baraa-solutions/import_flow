"""
FastAPI Router for Live Vessel & Carrier Tracking Radar (ImportFlow ERP)
Provides real-time AIS radar overview, dynamic ETA recalculation,
geodesic telemetry logging, and voyage route waypoint simulation.
"""

from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.router import get_current_user
from modules.auth.permissions import require_permission
from modules.users.model import User
from modules.vessel_tracking.schemas import (
    VesselCreate,
    VesselResponse,
    VesselPositionCreate,
    VesselPositionResponse,
    ShipmentTrackingResponse,
    LiveRadarOverviewResponse,
    VesselArrivalConfirmRequest,
)
from modules.vessel_tracking.service import VesselTrackingService


router = APIRouter(
    prefix="/api/v1/vessel-tracking",
    tags=["Live Vessel & Carrier Tracking Radar"],
    dependencies=[Depends(get_current_user)],
)


@router.get(
    "/radar/overview",
    response_model=LiveRadarOverviewResponse,
    summary="Get live radar overview of all active ocean shipments and fleet status",
)
def get_radar_overview(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = VesselTrackingService(db)
    return service.get_live_radar_overview()


@router.get(
    "/shipment/{import_file_id}",
    response_model=ShipmentTrackingResponse,
    summary="Get or auto-initialize live tracking session for an import file",
)
def get_shipment_tracking(
    import_file_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = VesselTrackingService(db)
    tracking = service.get_or_initialize_tracking_for_file(
        import_file_id=import_file_id, user=current_user.username
    )
    if not tracking:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Import file #{import_file_id} not found or no tracking available.",
        )
    return tracking


@router.post(
    "/telemetry",
    response_model=VesselPositionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Ingest AIS or satellite live telemetry position for a vessel",
)
def record_telemetry_position(
    payload: VesselPositionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = VesselTrackingService(db)
    try:
        return service.record_vessel_telemetry(payload)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(e),
        )


@router.post(
    "/simulate-step/{import_file_id}",
    response_model=ShipmentTrackingResponse,
    summary="Advance vessel location along voyage vector towards POD (Simulation)",
)
def simulate_vessel_step(
    import_file_id: int,
    hours_advance: float = Query(4.0, ge=0.5, le=72.0, description="Hours to advance simulation"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = VesselTrackingService(db)
    try:
        return service.simulate_vessel_step(import_file_id=import_file_id, hours_advance=hours_advance)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )


@router.post(
    "/confirm-arrival/{import_file_id}",
    response_model=ShipmentTrackingResponse,
    summary="Confirm vessel port arrival, berth ship, and trigger delivery order workflow",
)
def confirm_port_arrival(
    import_file_id: int,
    payload: Optional[VesselArrivalConfirmRequest] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = VesselTrackingService(db)
    actual_date = payload.actual_arrival_date if payload else None
    try:
        return service.confirm_vessel_port_arrival(
            import_file_id=import_file_id,
            actual_arrival_date=actual_date,
            user=current_user.username,
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )


@router.post(
    "/sync-demurrage/{import_file_id}",
    response_model=ShipmentTrackingResponse,
    summary="Synchronize vessel arrival with Demurrage & Detention Radar to trigger free days clock",
)
def sync_demurrage_clock(
    import_file_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.update")),
):
    service = VesselTrackingService(db)
    try:
        return service.sync_vessel_demurrage_clock(
            import_file_id=import_file_id,
            user=current_user.username,
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )


@router.post(
    "/vessels",
    response_model=VesselResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new vessel or return existing vessel by IMO",
)
def register_vessel(
    payload: VesselCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = VesselTrackingService(db)
    try:
        return service.register_or_get_vessel(payload=payload, user=current_user.username)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(e),
        )


@router.get(
    "/vessels/{vessel_id}/history",
    response_model=List[VesselPositionResponse],
    summary="Get recent navigational position history for a vessel",
)
def get_vessel_history(
    vessel_id: int,
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = VesselTrackingService(db)
    vessel = service.repo.get_vessel_by_id(vessel_id)
    if not vessel:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Vessel with id {vessel_id} not found.",
        )
    return service.repo.get_position_history(vessel_id=vessel_id, limit=limit)
