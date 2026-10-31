import logging
logger = logging.getLogger(__name__)
import math
import uuid
from datetime import datetime, timezone, timedelta
from typing import List, Optional, Tuple, Dict, Any

from sqlalchemy.orm import Session

from modules.vessel_tracking.model import Vessel, VesselPositionLog, ShipmentVesselTracking
from modules.vessel_tracking.repository import VesselTrackingRepository
from modules.vessel_tracking.schemas import (
    VesselCreate,
    VesselPositionCreate,
    ShipmentTrackingCreate,
    ShipmentTrackingResponse,
    LiveRadarOverviewResponse,
)
from modules.vessel_tracking.validators import (
    clean_imo_number,
    validate_imo_checksum,
    validate_coordinates,
    validate_navigational_speed,
)
from modules.import_files.model import ImportFile
from modules.freight_booking.model import ShipmentBooking
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.customs_clearance import repository as customs_repo
from modules.demurrage_detention.model import DemurrageTracking
from modules.smart_tasks.model import SmartTask
from modules.notifications.model import SystemNotification
from modules.common.file_tracking import set_file_tracking
from modules.common.system_messages import msg
from modules.common.errors import best_effort


# Reference port coordinates (Lat, Lon)
MAJOR_PORT_COORDINATES = {
    "CNSHA": (31.2304, 121.4737),  # Shanghai
    "CNNGB": (29.8683, 121.5440),  # Ningbo
    "SGSIN": (1.3521, 103.8198),   # Singapore
    "ITGOA": (44.4056, 8.9463),    # Genoa
    "DEHAM": (53.5511, 9.9937),    # Hamburg
    "EGALY": (31.2001, 29.9187),   # Alexandria
    "EGEDK": (31.1350, 29.8050),   # Dekheila
    "EGPSD": (31.2653, 32.3019),   # Port Said
    "EGDAM": (31.4165, 31.8133),   # Damietta
    "EGSUZ": (29.9668, 32.5498),   # Sokhna / Suez
}


def haversine_distance_nm(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculates geodesic distance between two points on Earth in Nautical Miles."""
    R_NM = 3440.065  # Earth's mean radius in Nautical Miles
    d_lat = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)
    a = (
        math.sin(d_lat / 2.0) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(d_lon / 2.0) ** 2
    )
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return round(R_NM * c, 1)


def calculate_bearing_degrees(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculates initial navigational compass bearing from point 1 to point 2."""
    lat1_r, lat2_r = math.radians(lat1), math.radians(lat2)
    d_lon_r = math.radians(lon2 - lon1)
    y = math.sin(d_lon_r) * math.cos(lat2_r)
    x = math.cos(lat1_r) * math.sin(lat2_r) - math.sin(lat1_r) * math.cos(lat2_r) * math.cos(d_lon_r)
    initial_bearing = math.degrees(math.atan2(y, x))
    return round((initial_bearing + 360.0) % 360.0, 1)


def _to_naive_utc(dt: Optional[datetime]) -> Optional[datetime]:
    if dt is None:
        return None
    if dt.tzinfo is not None:
        return dt.astimezone(timezone.utc).replace(tzinfo=None)
    return dt


class VesselTrackingService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = VesselTrackingRepository(db)

    # ── Master Vessel Management ────────────────────────────────────────────
    def register_or_get_vessel(self, payload: VesselCreate, user: str = "System") -> Vessel:
        if payload.imo_number:
            cleaned = clean_imo_number(payload.imo_number)
            if not cleaned or not validate_imo_checksum(cleaned):
                raise ValueError(f"Invalid IMO checksum for IMO number: {payload.imo_number}")
            payload.imo_number = cleaned
        return self.repo.get_or_create_vessel(payload, user=user)

    # ── Ingest AIS Position ──────────────────────────────────────────────────
    def record_vessel_telemetry(self, payload: VesselPositionCreate) -> VesselPositionLog:
        is_coord_valid, coord_err = validate_coordinates(payload.latitude, payload.longitude)
        if not is_coord_valid:
            raise ValueError(coord_err)

        is_speed_valid, speed_err = validate_navigational_speed(payload.speed_knots)
        if not is_speed_valid:
            raise ValueError(speed_err)

        # Compute remaining distance if destination port is known
        if payload.destination_port_code and payload.destination_port_code in MAJOR_PORT_COORDINATES:
            dest_lat, dest_lon = MAJOR_PORT_COORDINATES[payload.destination_port_code]
            payload.distance_remaining_nm = haversine_distance_nm(
                payload.latitude, payload.longitude, dest_lat, dest_lon
            )
            # Estimate dynamic ETA
            if payload.speed_knots > 1.0:
                hours_left = payload.distance_remaining_nm / payload.speed_knots
                payload.eta_predicted = datetime.now(timezone.utc) + timedelta(hours=hours_left)

        return self.repo.record_position(payload)

    # ── Initialize or Retrieve Shipment Tracking ────────────────────────────
    def get_or_initialize_tracking_for_file(
        self, import_file_id: int, user: str = "System"
    ) -> Optional[ShipmentTrackingResponse]:
        tracking = self.repo.get_tracking_by_file_id(import_file_id)
        if not tracking:
            # Check if import file and booking exist
            import_file = self.db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
            if not import_file:
                return None

            booking = (
                self.db.query(ShipmentBooking)
                .filter(ShipmentBooking.import_file_id == import_file_id, ShipmentBooking.is_active == True)
                .first()
            )

            # Auto-seed standard vessel and route if available
            vessel_name = (booking.vessel_name if booking and booking.vessel_name else None) or "CMA CGM ANTOINE"
            shipping_line = (booking.shipping_line_name if booking else None) or "CMA CGM"
            pol_code = "CNSHA"
            pol_name = (booking.pol_name if booking and booking.pol_name else "Shanghai, China")
            pod_code = "EGALY"
            pod_name = (booking.pod_name if booking and booking.pod_name else "Alexandria Port, Egypt")

            vessel = self.repo.get_or_create_vessel(
                VesselCreate(
                    vessel_name=vessel_name,
                    imo_number="9776432",
                    mmsi_number="228068900",
                    flag_country="France",
                    shipping_line_name=shipping_line,
                    capacity_teu=14414,
                ),
                user=user,
            )

            # Seed initial position in Mediterranean approaching Alexandria
            now = datetime.now(timezone.utc)
            init_lat, init_lon = 33.5000, 26.8000
            dest_lat, dest_lon = MAJOR_PORT_COORDINATES.get(pod_code, (31.2001, 29.9187))
            dist_nm = haversine_distance_nm(init_lat, init_lon, dest_lat, dest_lon)
            speed = 15.2
            course = calculate_bearing_degrees(init_lat, init_lon, dest_lat, dest_lon)
            hours_rem = dist_nm / speed
            est_eta = now + timedelta(hours=hours_rem)

            self.repo.record_position(
                VesselPositionCreate(
                    vessel_id=vessel.vessel_id,
                    latitude=init_lat,
                    longitude=init_lon,
                    speed_knots=speed,
                    course_degrees=course,
                    heading_degrees=course,
                    nav_status="Underway Using Engine",
                    current_zone="Eastern Mediterranean Basin",
                    destination_port_code=pod_code,
                    distance_remaining_nm=dist_nm,
                    eta_predicted=est_eta,
                )
            )

            # Build default waypoints
            waypoints = [
                {"name": "Shanghai Port (POL)", "latitude": 31.23, "longitude": 121.47, "passed": True},
                {"name": "Malacca Strait", "latitude": 2.50, "longitude": 101.50, "passed": True},
                {"name": "Bab el Mandeb Strait", "latitude": 12.58, "longitude": 43.33, "passed": True},
                {"name": "Suez Canal Transit", "latitude": 29.96, "longitude": 32.55, "passed": True},
                {"name": "Alexandria Approaches", "latitude": 31.50, "longitude": 29.50, "passed": False},
                {"name": "Alexandria Container Terminal (POD)", "latitude": 31.20, "longitude": 29.91, "passed": False},
            ]

            sched_dept = (booking.etd if booking and booking.etd else (now - timedelta(days=18)))
            sched_arr = (booking.eta if booking and booking.eta else (now + timedelta(days=2)))

            tracking = self.repo.create_or_update_tracking(
                ShipmentTrackingCreate(
                    import_file_id=import_file_id,
                    booking_id=booking.booking_id if booking else None,
                    vessel_id=vessel.vessel_id,
                    voyage_number=(booking.voyage_number if booking else None) or "0MEH4W1MA",
                    pol_port_code=pol_code,
                    pol_port_name=pol_name,
                    pod_port_code=pod_code,
                    pod_port_name=pod_name,
                    scheduled_departure=sched_dept,
                    actual_departure=sched_dept,
                    scheduled_arrival=sched_arr,
                    estimated_arrival=est_eta,
                    tracking_milestone="In Transit (Ocean)",
                    route_waypoints=waypoints,
                ),
                voyage_progress_pct=88.5,
                delay_hours=max(0.0, round((_to_naive_utc(est_eta) - _to_naive_utc(sched_arr)).total_seconds() / 3600.0, 1)) if sched_arr and est_eta else 0.0,
                delay_severity="ON_TIME",
                user=user,
            )

        return self._build_tracking_response(tracking)

    # ── Simulation & Telemetry Step ─────────────────────────────────────────
    def simulate_vessel_step(self, import_file_id: int, hours_advance: float = 4.0) -> ShipmentTrackingResponse:
        """
        Advances the vessel position along its vector towards POD,
        updating distance remaining, ETA, progress %, and milestones.
        """
        tracking = self.repo.get_tracking_by_file_id(import_file_id)
        if not tracking:
            raise ValueError(f"Tracking session for import_file_id {import_file_id} not found.")

        vessel_id = tracking.vessel_id
        latest_pos = self.repo.get_latest_position(vessel_id)
        dest_lat, dest_lon = MAJOR_PORT_COORDINATES.get(tracking.pod_port_code, (31.2001, 29.9187))

        cur_lat = latest_pos.latitude if latest_pos else 33.5
        cur_lon = latest_pos.longitude if latest_pos else 26.8
        speed = latest_pos.speed_knots if latest_pos else 15.0

        current_dist = haversine_distance_nm(cur_lat, cur_lon, dest_lat, dest_lon)
        dist_traveled = speed * hours_advance

        if current_dist <= dist_traveled or current_dist <= 5.0:
            # Vessel arrived at POD
            new_lat, new_lon = dest_lat, dest_lon
            new_dist = 0.0
            new_milestone = "In Port / Berthed"
            nav_status = "Moored"
            progress_pct = 100.0
            if not tracking.actual_arrival:
                now_utc = datetime.now(timezone.utc)
                return self.confirm_vessel_port_arrival(import_file_id, actual_arrival_date=now_utc, user="Simulation")
        else:
            # Interpolate towards POD
            fraction = dist_traveled / max(current_dist, 1.0)
            new_lat = cur_lat + (dest_lat - cur_lat) * fraction
            new_lon = cur_lon + (dest_lon - cur_lon) * fraction
            new_dist = haversine_distance_nm(new_lat, new_lon, dest_lat, dest_lon)
            new_milestone = "Approaching Port" if new_dist < 40.0 else "In Transit"
            nav_status = "Underway Using Engine"
            # Calculate progress (approx based on assumed total 6000 NM voyage)
            progress_pct = min(99.0, round(tracking.voyage_progress_pct + (fraction * 10.0), 1))

        course = calculate_bearing_degrees(new_lat, new_lon, dest_lat, dest_lon)
        hours_remaining = new_dist / max(speed, 1.0)
        now = datetime.now(timezone.utc)
        predicted_eta = now + timedelta(hours=hours_remaining)

        # Log new position
        self.repo.record_position(
            VesselPositionCreate(
                vessel_id=vessel_id,
                latitude=round(new_lat, 4),
                longitude=round(new_lon, 4),
                speed_knots=speed,
                course_degrees=course,
                heading_degrees=course,
                nav_status=nav_status,
                current_zone="Egyptian Territorial Waters" if new_dist < 30.0 else "Eastern Mediterranean",
                destination_port_code=tracking.pod_port_code,
                distance_remaining_nm=new_dist,
                eta_predicted=predicted_eta,
                source="SIMULATED",
            )
        )

        # Update Tracking Session
        delay_hrs = 0.0
        if tracking.scheduled_arrival:
            sched_naive = _to_naive_utc(tracking.scheduled_arrival)
            pred_naive = _to_naive_utc(predicted_eta)
            if sched_naive and pred_naive:
                diff_sec = (pred_naive - sched_naive).total_seconds()
                delay_hrs = round(max(0.0, diff_sec / 3600.0), 1)

        severity = "ON_TIME"
        if delay_hrs > 48.0:
            severity = "CRITICAL_DELAY"
        elif delay_hrs > 4.0:
            severity = "MINOR_DELAY"

        tracking.estimated_arrival = predicted_eta
        tracking.voyage_progress_pct = progress_pct
        tracking.tracking_milestone = new_milestone
        tracking.delay_hours = delay_hrs
        tracking.delay_severity = severity
        tracking.last_polled_at = now
        self.db.commit()
        self.db.refresh(tracking)

        return self._build_tracking_response(tracking)

    # ── Confirm Port Arrival & Automation Bridge ────────────────────────────
    def confirm_vessel_port_arrival(
        self,
        import_file_id: int,
        actual_arrival_date: Optional[datetime] = None,
        user: str = "System",
    ) -> ShipmentTrackingResponse:
        tracking = self.repo.get_tracking_by_file_id(import_file_id)
        if not tracking:
            raise ValueError(f"No active vessel tracking session found for import file #{import_file_id}")

        file_obj = self.db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
        if not file_obj:
            raise ValueError(f"Import file #{import_file_id} not found")

        arrival_dt = actual_arrival_date or datetime.now(timezone.utc)
        naive_arrival = _to_naive_utc(arrival_dt)
        now = datetime.now(timezone.utc)

        # 1. Update Shipment Vessel Tracking Session
        tracking.actual_arrival = naive_arrival
        tracking.tracking_milestone = "In Port / Berthed"
        tracking.voyage_progress_pct = 100.0
        tracking.delay_severity = "ON_TIME"
        if tracking.scheduled_arrival:
            sched_naive = _to_naive_utc(tracking.scheduled_arrival)
            if naive_arrival and sched_naive and naive_arrival > sched_naive:
                diff_sec = (naive_arrival - sched_naive).total_seconds()
                delay_hrs = round(diff_sec / 3600.0, 1)
                tracking.delay_hours = delay_hrs
                if delay_hrs > 48.0:
                    tracking.delay_severity = "CRITICAL_DELAY"
                elif delay_hrs > 4.0:
                    tracking.delay_severity = "MINOR_DELAY"
            else:
                tracking.delay_hours = 0.0

        if tracking.route_waypoints:
            wp_list = list(tracking.route_waypoints)
            for wp in wp_list:
                wp["status"] = "reached"
            tracking.route_waypoints = wp_list

        tracking.last_polled_at = now
        tracking.updated_at = now
        tracking.updated_by = user

        # 2. Update Latest Vessel Telemetry Position (Speed = 0, Moored)
        latest_pos = self.repo.get_latest_position(tracking.vessel_id)
        if latest_pos:
            latest_pos.nav_status = "Moored"
            latest_pos.speed_knots = 0.0
            latest_pos.distance_remaining_nm = 0.0
            latest_pos.eta_predicted = naive_arrival

        # 3. Advance ImportFile stage & tracking
        set_file_tracking(
            file_obj,
            step_code="STEP_13",
            phase_id="5",
            next_action=msg("NA_CS_PAY_DELIVERY_ORDER"),
        )
        if hasattr(file_obj, "inland_actual_arrival_date"):
            file_obj.inland_actual_arrival_date = naive_arrival
        if hasattr(file_obj, "delivery_order_status") and not file_obj.delivery_order_status:
            file_obj.delivery_order_status = "PENDING"
        file_obj.updated_at = now
        file_obj.updated_by = user

        # 4. Sync CustomsClearanceRecord (satisfies CHK_PRT_01)
        clr = customs_repo.get_active_clearance_for_file(self.db, import_file_id)
        if not clr:
            clr = CustomsClearanceRecord(
                clearance_code=customs_repo.generate_customs_clearance_code(self.db),
                import_file_id=import_file_id,
                owner=file_obj.owner or user,
                port_arrival_date=naive_arrival,
                delivery_order_status="Pending",
                created_by=user,
                updated_by=user,
            )
            self.db.add(clr)
        else:
            clr.port_arrival_date = naive_arrival
            if not clr.delivery_order_status:
                clr.delivery_order_status = "Pending"
            clr.updated_at = now
            clr.updated_by = user

        # 5. Sync or Auto-Provision DemurrageTracking (discharge_date starts container free time countdown)
        dem = self.db.query(DemurrageTracking).filter(
            DemurrageTracking.import_file_id == import_file_id,
            DemurrageTracking.is_active == True,
        ).first()

        from modules.demurrage_detention import service as dd_service
        from modules.demurrage_detention.schemas import DemurrageTrackingCreate, ContainerItemInput

        arr_date = naive_arrival.date() if naive_arrival else datetime.now(timezone.utc).date()
        if dem:
            dem.discharge_date = arr_date
            if "Auto-synced with Vessel Port Arrival" not in (dem.notes or ""):
                dem.notes = ((dem.notes + " | ") if dem.notes else "") + f"Auto-synced with Vessel Port Arrival: {arr_date}"
            try:
                tariff = dd_service._tracking_tariff(self.db, dem)
                rate = dem.exchange_rate or dd_service._resolve_exchange_rate(self.db, dem.currency or "USD", arr_date)
                dem.exchange_rate = rate
                containers, dem_fx, det_fx, stor_egp = dd_service._recalculate_containers(
                    dem, tariff, rate, dem.gate_out_date, dem.empty_return_date
                )
                dd_service._apply_totals(dem, containers, dem_fx, det_fx, stor_egp, rate)
                dem.status = dd_service._incurred_status(dem_fx, det_fx)
            except Exception as exc:
                logger.exception("Failed to recalculate demurrage tracking on vessel port arrival: %s", exc)
                if dem.status in ("Pending", "Not Started", None, "Free Time Active"):
                    dem.status = "Free Time Active"
            dem.updated_at = now
            dem.updated_by = user
        else:
            # Auto-provision DemurrageTracking if missing
            try:
                booking = self.db.query(ShipmentBooking).filter(
                    ShipmentBooking.import_file_id == import_file_id,
                    ShipmentBooking.is_active == True,
                ).first()
                carrier_name = (
                    (booking.shipping_line_name if booking and booking.shipping_line_name else None)
                    or (tracking.vessel.shipping_line_name if tracking.vessel else None)
                    or "Ocean Carrier"
                )
                bl_no = (booking.bill_of_lading_no if booking and booking.bill_of_lading_no else None) or tracking.tracking_code
                port_name = tracking.pod_port_name or (booking.pod_name if booking else None) or "Alexandria"

                containers_payload = []
                if booking and booking.containers_data and isinstance(booking.containers_data, list):
                    for idx, c in enumerate(booking.containers_data):
                        c_no = c.get("container_no") if isinstance(c, dict) else None
                        c_type = c.get("container_type") if isinstance(c, dict) else "40ft High Cube"
                        containers_payload.append(ContainerItemInput(container_no=c_no or f"CONT-{import_file_id}-{idx+1}", container_type=c_type or "40ft High Cube"))
                if not containers_payload:
                    containers_payload = [ContainerItemInput(container_no=f"CONT-{import_file_id}-01", container_type="40ft High Cube")]

                rate = None
                try:
                    rate = dd_service._resolve_exchange_rate(self.db, "USD", arr_date)
                except Exception as exc:
                    logger.warning("Could not resolve USD exchange rate on %s: %s", arr_date, exc)

                req_create = DemurrageTrackingCreate(
                    import_file_id=import_file_id,
                    carrier_name=carrier_name,
                    bill_of_lading_no=bl_no,
                    port_name=port_name,
                    discharge_date=arr_date,
                    exchange_rate=rate,
                    containers=containers_payload,
                    notes=f"Auto-created on vessel port arrival: {arr_date}",
                )
                dem = dd_service.create_demurrage_tracking_service(self.db, req_create, user=user)
            except Exception as exc:
                logger.exception("Failed to auto-provision demurrage tracking on vessel arrival: %s", exc)

        # 6. Primary Commit for Core Business Data
        self.db.commit()
        self.db.refresh(tracking)

        # 7. Best-Effort Side Effects: SmartTask & Notification
        def _create_task():
            existing = self.db.query(SmartTask).filter(
                SmartTask.import_file_id == import_file_id,
                SmartTask.status.in_(["Pending", "In Progress"]),
                SmartTask.msg_code.in_(["LOG_TASK_DELIVERY_ORDER", "CC_TASK_DELIVERY_ORDER_PAYMENT"]),
            ).first()
            if not existing:
                vessel_name = tracking.vessel.vessel_name if tracking.vessel else "Ocean Vessel"
                due_date_str = (naive_arrival + timedelta(days=2)).strftime("%Y-%m-%d") if naive_arrival else ""
                task = SmartTask(
                    task_code=f"TASK-{uuid.uuid4().hex[:8].upper()}",
                    title=f"Pay Delivery Order & Port Charges - {file_obj.import_file_code}",
                    description=f"Vessel {vessel_name} has berthed at {tracking.pod_port_name}. Settle container charges and collect Delivery Order (D/O).",
                    task_type="System Generated",
                    import_file_id=import_file_id,
                    import_file_code=file_obj.import_file_code,
                    phase_name="Customs Clearance",
                    assigned_user=file_obj.owner or "Kamal",
                    priority="Critical",
                    reminder_type="Port Arrival / Delivery Order",
                    due_date=due_date_str,
                    status="Pending",
                    msg_code="LOG_TASK_DELIVERY_ORDER",
                    msg_params={
                        "import_file_code": file_obj.import_file_code,
                        "vessel_name": vessel_name,
                        "port_name": tracking.pod_port_name,
                    },
                    step_code="STEP_13",
                    created_by=user,
                )
                self.db.add(task)
                self.db.commit()

        best_effort(self.db, _create_task, "confirm_vessel_port_arrival:create_task")

        def _create_notification():
            vessel_name = tracking.vessel.vessel_name if tracking.vessel else "Ocean Vessel"
            notif = SystemNotification(
                title=f"Vessel Berthed at {tracking.pod_port_name} - {file_obj.import_file_code}",
                message=f"Vessel {vessel_name} arrived at {tracking.pod_port_name}. Free days demurrage countdown is active.",
                severity="WARNING",
                category="VESSEL_ARRIVAL",
                entity_type="ImportFile",
                entity_id=import_file_id,
                target_role="ALL",
                is_read=False,
                msg_code="LOG_VESSEL_ARRIVED_PORT",
                msg_params={
                    "import_file_code": file_obj.import_file_code,
                    "vessel_name": vessel_name,
                    "port_name": tracking.pod_port_name,
                    "arrival_date": naive_arrival.strftime("%Y-%m-%d") if naive_arrival else "",
                },
            )
            self.db.add(notif)
            self.db.commit()

        best_effort(self.db, _create_notification, "confirm_vessel_port_arrival:create_notification")

        return self._build_tracking_response(tracking)

    # ── Overview Radar for All Shipments ────────────────────────────────────

    def sync_vessel_demurrage_clock(self, import_file_id: int, user: str = "System") -> ShipmentTrackingResponse:
        tracking = self.repo.get_tracking_by_file_id(import_file_id)
        if not tracking:
            raise ValueError(f"No active vessel tracking session found for import file #{import_file_id}")
        arr_date = tracking.actual_arrival or datetime.now(timezone.utc)
        return self.confirm_vessel_port_arrival(
            import_file_id=import_file_id,
            actual_arrival_date=arr_date,
            user=user,
        )

    def get_live_radar_overview(self) -> LiveRadarOverviewResponse:
        trackings = self.repo.get_all_active_trackings()
        responses = [self._build_tracking_response(t) for t in trackings]

        underway = sum(1 for r in responses if "In Transit" in r.tracking_milestone)
        approaching = sum(1 for r in responses if "Approaching" in r.tracking_milestone)
        in_port = sum(1 for r in responses if "In Port" in r.tracking_milestone or "Berthed" in r.tracking_milestone)
        delayed = sum(1 for r in responses if r.delay_severity in ("MINOR_DELAY", "CRITICAL_DELAY"))
        on_time = len(responses) - delayed

        return LiveRadarOverviewResponse(
            total_active_shipments=len(responses),
            underway_count=underway,
            approaching_port_count=approaching,
            in_port_count=in_port,
            delayed_count=delayed,
            on_time_count=on_time,
            shipments=responses,
        )

    # ── Internal Helper to Hydrate Response ─────────────────────────────────
    def _build_tracking_response(self, tracking: ShipmentVesselTracking) -> ShipmentTrackingResponse:
        vessel = self.repo.get_vessel_by_id(tracking.vessel_id)
        latest_pos = self.repo.get_latest_position(tracking.vessel_id)

        dem = self.db.query(DemurrageTracking).filter(
            DemurrageTracking.import_file_id == tracking.import_file_id,
            DemurrageTracking.is_active == True,
        ).first()

        dem_id = dem.tracking_id if dem else None
        dem_code = dem.tracking_code if dem else None
        dem_status = dem.status if dem else None
        dem_discharge = dem.discharge_date.strftime("%Y-%m-%d") if dem and dem.discharge_date else None
        dem_started = bool(dem and dem.discharge_date and dem.status in ("Free Time Active", "Demurrage Incurred", "Detention Incurred", "Demurrage & Detention Incurred"))

        return ShipmentTrackingResponse(
            tracking_id=tracking.tracking_id,
            tracking_code=tracking.tracking_code,
            import_file_id=tracking.import_file_id,
            booking_id=tracking.booking_id,
            vessel_id=tracking.vessel_id,
            voyage_number=tracking.voyage_number,
            pol_port_code=tracking.pol_port_code,
            pol_port_name=tracking.pol_port_name,
            pod_port_code=tracking.pod_port_code,
            pod_port_name=tracking.pod_port_name,
            scheduled_departure=tracking.scheduled_departure,
            actual_departure=tracking.actual_departure,
            scheduled_arrival=tracking.scheduled_arrival,
            estimated_arrival=tracking.estimated_arrival,
            actual_arrival=tracking.actual_arrival,
            tracking_milestone=tracking.tracking_milestone,
            voyage_progress_pct=tracking.voyage_progress_pct,
            delay_hours=tracking.delay_hours,
            delay_severity=tracking.delay_severity,
            last_polled_at=tracking.last_polled_at,
            route_waypoints=tracking.route_waypoints or [],
            notes=tracking.notes,
            is_active=tracking.is_active,
            created_at=tracking.created_at,
            vessel_name=vessel.vessel_name if vessel else None,
            vessel_imo=vessel.imo_number if vessel else None,
            shipping_line_name=vessel.shipping_line_name if vessel else None,
            current_latitude=latest_pos.latitude if latest_pos else None,
            current_longitude=latest_pos.longitude if latest_pos else None,
            current_speed_knots=latest_pos.speed_knots if latest_pos else None,
            current_course_degrees=latest_pos.course_degrees if latest_pos else None,
            current_nav_status=latest_pos.nav_status if latest_pos else None,
            current_zone=latest_pos.current_zone if latest_pos else None,
            distance_remaining_nm=latest_pos.distance_remaining_nm if latest_pos else None,
            demurrage_tracking_id=dem_id,
            demurrage_tracking_code=dem_code,
            demurrage_status=dem_status,
            demurrage_discharge_date=dem_discharge,
            demurrage_clock_started=dem_started,
        )
