from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import desc

from modules.vessel_tracking.model import Vessel, VesselPositionLog, ShipmentVesselTracking
from modules.vessel_tracking.schemas import (
    VesselCreate,
    VesselPositionCreate,
    ShipmentTrackingCreate,
)


class VesselTrackingRepository:
    def __init__(self, db: Session):
        self.db = db

    # ── Vessels ─────────────────────────────────────────────────────────────
    def get_vessel_by_id(self, vessel_id: int) -> Optional[Vessel]:
        return self.db.query(Vessel).filter(Vessel.vessel_id == vessel_id, Vessel.is_active == True).first()

    def get_vessel_by_imo(self, imo_number: str) -> Optional[Vessel]:
        return self.db.query(Vessel).filter(Vessel.imo_number == imo_number, Vessel.is_active == True).first()

    def get_or_create_vessel(self, payload: VesselCreate, user: str = "System") -> Vessel:
        if payload.imo_number:
            existing = self.get_vessel_by_imo(payload.imo_number)
            if existing:
                return existing
        vessel = Vessel(
            vessel_name=payload.vessel_name,
            imo_number=payload.imo_number,
            mmsi_number=payload.mmsi_number,
            call_sign=payload.call_sign,
            flag_country=payload.flag_country,
            vessel_type=payload.vessel_type,
            built_year=payload.built_year,
            capacity_teu=payload.capacity_teu,
            shipping_line_name=payload.shipping_line_name,
            notes=payload.notes,
            created_by=user,
            updated_by=user,
        )
        self.db.add(vessel)
        self.db.commit()
        self.db.refresh(vessel)
        return vessel

    # ── Telemetry Positions ─────────────────────────────────────────────────
    def record_position(self, payload: VesselPositionCreate) -> VesselPositionLog:
        ts = payload.timestamp or datetime.now(timezone.utc)
        pos = VesselPositionLog(
            vessel_id=payload.vessel_id,
            timestamp=ts,
            latitude=payload.latitude,
            longitude=payload.longitude,
            speed_knots=payload.speed_knots,
            course_degrees=payload.course_degrees,
            heading_degrees=payload.heading_degrees,
            nav_status=payload.nav_status,
            current_zone=payload.current_zone,
            destination_port_code=payload.destination_port_code,
            distance_remaining_nm=payload.distance_remaining_nm,
            eta_predicted=payload.eta_predicted,
            source=payload.source,
        )
        self.db.add(pos)
        self.db.commit()
        self.db.refresh(pos)
        return pos

    def get_latest_position(self, vessel_id: int) -> Optional[VesselPositionLog]:
        return (
            self.db.query(VesselPositionLog)
            .filter(VesselPositionLog.vessel_id == vessel_id)
            .order_by(desc(VesselPositionLog.timestamp))
            .first()
        )

    def get_position_history(self, vessel_id: int, limit: int = 50) -> List[VesselPositionLog]:
        return (
            self.db.query(VesselPositionLog)
            .filter(VesselPositionLog.vessel_id == vessel_id)
            .order_by(desc(VesselPositionLog.timestamp))
            .limit(limit)
            .all()
        )

    # ── Shipment Tracking Sessions ──────────────────────────────────────────
    def get_tracking_by_file_id(self, import_file_id: int) -> Optional[ShipmentVesselTracking]:
        return (
            self.db.query(ShipmentVesselTracking)
            .filter(ShipmentVesselTracking.import_file_id == import_file_id, ShipmentVesselTracking.is_active == True)
            .first()
        )

    def create_or_update_tracking(
        self,
        payload: ShipmentTrackingCreate,
        voyage_progress_pct: float = 0.0,
        delay_hours: float = 0.0,
        delay_severity: str = "ON_TIME",
        user: str = "System",
    ) -> ShipmentVesselTracking:
        tracking = self.get_tracking_by_file_id(payload.import_file_id)
        if tracking:
            tracking.vessel_id = payload.vessel_id
            tracking.booking_id = payload.booking_id or tracking.booking_id
            tracking.voyage_number = payload.voyage_number or tracking.voyage_number
            tracking.pol_port_code = payload.pol_port_code
            tracking.pol_port_name = payload.pol_port_name
            tracking.pod_port_code = payload.pod_port_code
            tracking.pod_port_name = payload.pod_port_name
            tracking.scheduled_departure = payload.scheduled_departure or tracking.scheduled_departure
            tracking.actual_departure = payload.actual_departure or tracking.actual_departure
            tracking.scheduled_arrival = payload.scheduled_arrival or tracking.scheduled_arrival
            tracking.estimated_arrival = payload.estimated_arrival or tracking.estimated_arrival
            tracking.tracking_milestone = payload.tracking_milestone
            tracking.voyage_progress_pct = voyage_progress_pct
            tracking.delay_hours = delay_hours
            tracking.delay_severity = delay_severity
            tracking.route_waypoints = payload.route_waypoints or tracking.route_waypoints
            tracking.last_polled_at = datetime.now(timezone.utc)
            tracking.updated_at = datetime.now(timezone.utc)
            tracking.updated_by = user
        else:
            tracking_code = f"TRK-{payload.import_file_id:04d}-{datetime.now().strftime('%m%d')}"
            tracking = ShipmentVesselTracking(
                tracking_code=tracking_code,
                import_file_id=payload.import_file_id,
                booking_id=payload.booking_id,
                vessel_id=payload.vessel_id,
                voyage_number=payload.voyage_number,
                pol_port_code=payload.pol_port_code,
                pol_port_name=payload.pol_port_name,
                pod_port_code=payload.pod_port_code,
                pod_port_name=payload.pod_port_name,
                scheduled_departure=payload.scheduled_departure,
                actual_departure=payload.actual_departure,
                scheduled_arrival=payload.scheduled_arrival,
                estimated_arrival=payload.estimated_arrival,
                tracking_milestone=payload.tracking_milestone,
                voyage_progress_pct=voyage_progress_pct,
                delay_hours=delay_hours,
                delay_severity=delay_severity,
                last_polled_at=datetime.now(timezone.utc),
                route_waypoints=payload.route_waypoints,
                notes=payload.notes,
                created_by=user,
                updated_by=user,
            )
            self.db.add(tracking)

        self.db.commit()
        self.db.refresh(tracking)
        return tracking

    def get_all_active_trackings(self) -> List[ShipmentVesselTracking]:
        return (
            self.db.query(ShipmentVesselTracking)
            .filter(ShipmentVesselTracking.is_active == True)
            .order_by(desc(ShipmentVesselTracking.last_polled_at))
            .all()
        )
