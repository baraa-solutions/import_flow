"""
Unit tests for Live Vessel & Carrier Tracking Radar (LOG-TRACK-001/002/003)
Covers IMO checksum validation, geodesic math, telemetry logging,
step-forward simulation, radar overview, and API endpoints.
"""

from datetime import datetime, timezone, timedelta
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from main import app
from modules.vessel_tracking.validators import (
    clean_imo_number,
    validate_imo_checksum,
    validate_mmsi_number,
    validate_coordinates,
    validate_navigational_speed,
)
from modules.vessel_tracking.service import (
    haversine_distance_nm,
    calculate_bearing_degrees,
    VesselTrackingService,
)
from modules.vessel_tracking.schemas import (
    VesselCreate,
    VesselPositionCreate,
    ShipmentTrackingCreate,
)
from modules.vessel_tracking.model import Vessel, VesselPositionLog, ShipmentVesselTracking
from modules.import_files.model import ImportFile
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.demurrage_detention.model import DemurrageTracking
from modules.smart_tasks.model import SmartTask
from modules.notifications.model import SystemNotification


# ── Test 1: IMO Checksum & Validator Algorithms ──────────────────────────────

def test_imo_checksum_valid():
    # IMO 9776432: 9*7 + 7*6 + 7*5 + 6*4 + 4*3 + 3*2 = 63 + 42 + 35 + 24 + 12 + 6 = 182 -> 182 % 10 = 2 == 2
    assert validate_imo_checksum("9776432") is True
    # IMO 9321483: 9*7 + 3*6 + 2*5 + 1*4 + 4*3 + 8*2 = 63 + 18 + 10 + 4 + 12 + 16 = 123 -> 123 % 10 = 3 == 3
    assert validate_imo_checksum("9321483") is True


def test_imo_checksum_invalid():
    assert validate_imo_checksum("9776439") is False  # Checksum mismatch
    assert validate_imo_checksum("12345") is False  # Too short
    assert validate_imo_checksum("ABCDEFG") is False  # Non-digit


def test_imo_cleaning():
    assert clean_imo_number(" IMO-9776432 ") == "9776432"
    assert clean_imo_number("imo 9776432") == "9776432"
    assert clean_imo_number("") is None


def test_mmsi_validator():
    assert validate_mmsi_number("228068900") is True
    assert validate_mmsi_number("1234") is False
    assert validate_mmsi_number("ABC456789") is False


def test_coordinate_and_speed_validators():
    assert validate_coordinates(31.2001, 29.9187)[0] is True
    assert validate_coordinates(95.0, 30.0)[0] is False  # Lat out of range
    assert validate_coordinates(30.0, 190.0)[0] is False  # Lon out of range

    assert validate_navigational_speed(15.5)[0] is True
    assert validate_navigational_speed(-1.0)[0] is False
    assert validate_navigational_speed(65.0)[0] is False


# ── Test 2: Geodesic Math (Haversine & Bearing) ──────────────────────────────

def test_haversine_distance():
    # Alexandria (31.2001, 29.9187) to Port Said (31.2653, 32.3019)
    # Distance is roughly 123-125 Nautical Miles
    dist = haversine_distance_nm(31.2001, 29.9187, 31.2653, 32.3019)
    assert 120.0 <= dist <= 130.0

    # Distance to self is 0
    assert haversine_distance_nm(31.2, 29.9, 31.2, 29.9) == 0.0


def test_calculate_bearing():
    # Bearing due North: (0, 0) -> (10, 0)
    bearing_n = calculate_bearing_degrees(0.0, 0.0, 10.0, 0.0)
    assert bearing_n == 0.0

    # Bearing due East: (0, 0) -> (0, 10)
    bearing_e = calculate_bearing_degrees(0.0, 0.0, 0.0, 10.0)
    assert 89.0 <= bearing_e <= 91.0


# ── Test 3: Vessel Tracking Service & Simulation ─────────────────────────────

@pytest.fixture
def in_memory_db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()


def test_vessel_registration_and_telemetry(in_memory_db):
    service = VesselTrackingService(in_memory_db)

    # 1. Register Vessel
    vessel = service.register_or_get_vessel(
        VesselCreate(
            vessel_name="EVER GIVEN",
            imo_number="9811000",
            mmsi_number="353136000",
            flag_country="Panama",
            shipping_line_name="Evergreen Marine",
            capacity_teu=20124,
        ),
        user="TestUser",
    )
    assert vessel.vessel_id is not None
    assert vessel.vessel_name == "EVER GIVEN"

    # 2. Record AIS Position Telemetry
    pos = service.record_vessel_telemetry(
        VesselPositionCreate(
            vessel_id=vessel.vessel_id,
            latitude=31.5000,
            longitude=29.5000,
            speed_knots=14.0,
            course_degrees=115.0,
            destination_port_code="EGALY",
        )
    )
    assert pos.position_id is not None
    assert pos.distance_remaining_nm is not None
    assert pos.eta_predicted is not None

    # Verify history
    history = service.repo.get_position_history(vessel.vessel_id)
    assert len(history) == 1
    assert history[0].latitude == 31.5000


def test_simulate_vessel_step(in_memory_db):
    service = VesselTrackingService(in_memory_db)

    # Create dummy import file
    import_file = ImportFile(
        import_file_code="IMP-2026-TEST",
        company_name="Test Company",
        supplier_name="Test Supplier",
        created_by="TestUser",
        updated_by="TestUser",
    )
    in_memory_db.add(import_file)
    in_memory_db.commit()

    # Initialize tracking
    tracking_resp = service.get_or_initialize_tracking_for_file(import_file.import_file_id)
    assert tracking_resp is not None
    initial_dist = tracking_resp.distance_remaining_nm
    initial_progress = tracking_resp.voyage_progress_pct

    # Step simulation forward by 6 hours
    step_resp = service.simulate_vessel_step(import_file.import_file_id, hours_advance=6.0)
    assert step_resp.distance_remaining_nm < initial_dist
    assert step_resp.voyage_progress_pct >= initial_progress
    assert step_resp.tracking_milestone in ("In Transit", "Approaching Port", "In Port / Berthed")


def test_live_radar_overview(in_memory_db):
    service = VesselTrackingService(in_memory_db)

    # Empty overview
    overview = service.get_live_radar_overview()
    assert overview.total_active_shipments == 0
    assert overview.on_time_count == 0

    # Add a file and initialize tracking
    f = ImportFile(
        import_file_code="IMP-2026-RADAR",
        company_name="Test Company 2",
        supplier_name="Test Supplier 2",
    )
    in_memory_db.add(f)
    in_memory_db.commit()
    service.get_or_initialize_tracking_for_file(f.import_file_id)

    overview2 = service.get_live_radar_overview()
    assert overview2.total_active_shipments == 1
    assert len(overview2.shipments) == 1


# ── Test 4: API Endpoints (Integration via TestClient) ───────────────────────

def test_vessel_tracking_api_endpoints():
    client = TestClient(app)

    # Radar overview
    resp = client.get("/api/v1/vessel-tracking/radar/overview")
    assert resp.status_code == 200
    data = resp.json()
    assert "total_active_shipments" in data
    assert "shipments" in data

    # Create vessel via API
    vessel_payload = {
        "vessel_name": "COSCO SHIPPING PLANET",
        "imo_number": "9795646",
        "mmsi_number": "477218800",
        "flag_country": "Hong Kong",
        "vessel_type": "Container Ship",
        "capacity_teu": 21237,
        "shipping_line_name": "COSCO",
    }
    v_resp = client.post("/api/v1/vessel-tracking/vessels", json=vessel_payload)
    assert v_resp.status_code in (200, 201)
    v_data = v_resp.json()
    vessel_id = v_data["vessel_id"]

    # Ingest Telemetry via API
    pos_payload = {
        "vessel_id": vessel_id,
        "latitude": 28.5000,
        "longitude": 33.2000,
        "speed_knots": 16.2,
        "course_degrees": 340.0,
        "heading_degrees": 340.0,
        "nav_status": "Underway Using Engine",
        "current_zone": "Gulf of Suez",
        "destination_port_code": "EGPSD",
    }
    p_resp = client.post("/api/v1/vessel-tracking/telemetry", json=pos_payload)
    assert p_resp.status_code == 201
    p_data = p_resp.json()
    assert p_data["vessel_id"] == vessel_id
    assert p_data["distance_remaining_nm"] is not None

    # Get History via API
    h_resp = client.get(f"/api/v1/vessel-tracking/vessels/{vessel_id}/history")
    assert h_resp.status_code == 200
    h_data = h_resp.json()
    assert len(h_data) >= 1


# ── Test 5: Confirm Vessel Port Arrival & Automation Bridge ──────────────────

def test_confirm_vessel_port_arrival_flow(in_memory_db):
    service = VesselTrackingService(in_memory_db)

    # 1. Setup ImportFile
    file_obj = ImportFile(
        import_file_code="IMP-2026-ARRIV",
        company_name="El-Nasr Imports",
        supplier_name="Global Trade Ltd",
        owner="Kamal",
    )
    in_memory_db.add(file_obj)
    in_memory_db.commit()

    # 2. Setup Tracking Session
    tracking = service.get_or_initialize_tracking_for_file(file_obj.import_file_id)
    assert "In Transit" in tracking.tracking_milestone
    assert tracking.voyage_progress_pct < 100.0

    # 3. Setup Demurrage Tracking
    dem = DemurrageTracking(
        tracking_code="DND-2026-TEST",
        import_file_id=file_obj.import_file_id,
        carrier_name="Maersk Line",
        bill_of_lading_no="MSK12345678",
        port_name="Dekheila Port",
        discharge_date=datetime.now(timezone.utc).date() + timedelta(days=5),  # Future placeholder
        exchange_rate=50.0,
        status="Pending",
    )
    in_memory_db.add(dem)

    # 4. Setup Customs Clearance Record
    clr = CustomsClearanceRecord(
        clearance_code="CLR-2026-TEST",
        import_file_id=file_obj.import_file_id,
        owner="Kamal",
    )
    in_memory_db.add(clr)
    in_memory_db.commit()

    # 5. Execute Arrival Confirmation
    arrival_time = datetime(2026, 10, 20, 14, 30, tzinfo=timezone.utc)
    res = service.confirm_vessel_port_arrival(
        import_file_id=file_obj.import_file_id,
        actual_arrival_date=arrival_time,
        user="TestOfficer",
    )

    # 6. Verify Tracking State
    assert res.tracking_milestone == "In Port / Berthed"
    assert res.voyage_progress_pct == 100.0
    assert res.actual_arrival is not None

    # 7. Verify ImportFile Lifecycle Progression
    in_memory_db.refresh(file_obj)
    assert file_obj.current_step_code == "STEP_13"
    assert file_obj.current_phase_id == 5

    # 8. Verify CustomsClearanceRecord port_arrival_date Sync
    in_memory_db.refresh(clr)
    assert clr.port_arrival_date is not None
    assert clr.delivery_order_status == "Pending"

    # 9. Verify DemurrageTracking discharge_date Sync
    in_memory_db.refresh(dem)
    assert dem.discharge_date == arrival_time.date()
    assert dem.status == "Free Time Active"

    # 10. Verify SmartTask Auto-Generation
    task = (
        in_memory_db.query(SmartTask)
        .filter(SmartTask.import_file_id == file_obj.import_file_id)
        .first()
    )
    assert task is not None
    assert task.status == "Pending"
    assert task.priority == "Critical"
    assert task.msg_code == "LOG_TASK_DELIVERY_ORDER"

    # 11. Verify SystemNotification
    notif = (
        in_memory_db.query(SystemNotification)
        .filter(SystemNotification.entity_id == file_obj.import_file_id)
        .first()
    )
    assert notif is not None
    assert notif.severity == "WARNING"
    assert notif.msg_code == "LOG_VESSEL_ARRIVED_PORT"


def test_confirm_vessel_port_arrival_auto_creates_clearance(in_memory_db):
    service = VesselTrackingService(in_memory_db)

    # Setup File & Tracking without prior CustomsClearanceRecord
    file_obj = ImportFile(
        import_file_code="IMP-2026-NOCLR",
        company_name="Delta Trading",
        supplier_name="China Corp",
    )
    in_memory_db.add(file_obj)
    in_memory_db.commit()

    service.get_or_initialize_tracking_for_file(file_obj.import_file_id)

    # Confirm arrival
    res = service.confirm_vessel_port_arrival(import_file_id=file_obj.import_file_id)
    assert res.tracking_milestone == "In Port / Berthed"

    # Verify clearance was created automatically
    clr = (
        in_memory_db.query(CustomsClearanceRecord)
        .filter(CustomsClearanceRecord.import_file_id == file_obj.import_file_id)
        .first()
    )
    assert clr is not None
    assert clr.port_arrival_date is not None
    assert clr.delivery_order_status == "Pending"


def test_confirm_vessel_port_arrival_api():
    client = TestClient(app)

    # Initialize tracking via API
    init_resp = client.get("/api/v1/vessel-tracking/shipment/1")
    if init_resp.status_code == 200:
        # File 1 exists in DB
        arrival_resp = client.post("/api/v1/vessel-tracking/confirm-arrival/1", json={})
        assert arrival_resp.status_code == 200
        data = arrival_resp.json()
        assert data["tracking_milestone"] == "In Port / Berthed"
        assert data["voyage_progress_pct"] == 100.0
        assert data["actual_arrival"] is not None
    else:
        # File 999999 returns 404
        err_resp = client.post("/api/v1/vessel-tracking/confirm-arrival/999999", json={})
        assert err_resp.status_code == 404


def test_vessel_arrival_recalculates_demurrage_and_activates_clock(in_memory_db):
    service = VesselTrackingService(in_memory_db)

    file_obj = ImportFile(
        import_file_code="IMP-2026-BRIDGE",
        company_name="Bridge Import Co",
        supplier_name="Global Shipper",
    )
    in_memory_db.add(file_obj)
    in_memory_db.commit()

    service.get_or_initialize_tracking_for_file(file_obj.import_file_id)

    dem = DemurrageTracking(
        tracking_code="DND-BRIDGE-001",
        import_file_id=file_obj.import_file_id,
        carrier_name="Maersk Line",
        bill_of_lading_no="BL-BRIDGE-99",
        port_name="Alexandria Port",
        discharge_date=datetime.now(timezone.utc).date() + timedelta(days=10),
        exchange_rate=50.0,
        status="Pending",
        containers=[
            {"container_no": "MSCU1122334", "container_type": "40ft High Cube", "status": "Pending"}
        ],
    )
    in_memory_db.add(dem)
    in_memory_db.commit()

    # Confirm port arrival
    arrival_dt = datetime(2026, 10, 25, 10, 0, tzinfo=timezone.utc)
    res = service.confirm_vessel_port_arrival(
        import_file_id=file_obj.import_file_id,
        actual_arrival_date=arrival_dt,
        user="BridgeOfficer",
    )

    assert res.tracking_milestone == "In Port / Berthed"
    assert res.demurrage_tracking_code == "DND-BRIDGE-001"
    assert res.demurrage_clock_started is True
    assert res.demurrage_discharge_date == arrival_dt.date().strftime("%Y-%m-%d")

    # Verify demurrage record was updated & recalculated
    in_memory_db.refresh(dem)
    assert dem.discharge_date == arrival_dt.date()
    assert dem.status in ("Free Time Active", "Demurrage Incurred", "Detention Incurred")
    assert "Auto-synced with Vessel Port Arrival" in (dem.notes or "")


def test_vessel_arrival_auto_provisions_demurrage_if_missing(in_memory_db):
    service = VesselTrackingService(in_memory_db)

    file_obj = ImportFile(
        import_file_code="IMP-2026-AUTOPROV",
        company_name="Auto Provision Co",
        supplier_name="Global Line",
    )
    in_memory_db.add(file_obj)
    in_memory_db.commit()

    service.get_or_initialize_tracking_for_file(file_obj.import_file_id)

    # Confirm arrival with no prior DemurrageTracking
    arrival_dt = datetime(2026, 10, 26, 8, 0, tzinfo=timezone.utc)
    res = service.confirm_vessel_port_arrival(
        import_file_id=file_obj.import_file_id,
        actual_arrival_date=arrival_dt,
        user="AutoOfficer",
    )

    assert res.tracking_milestone == "In Port / Berthed"
    # Verify DemurrageTracking was provisioned
    dem = in_memory_db.query(DemurrageTracking).filter(
        DemurrageTracking.import_file_id == file_obj.import_file_id,
        DemurrageTracking.is_active == True,
    ).first()
    assert dem is not None
    assert dem.discharge_date == arrival_dt.date()
    assert dem.status in ("Free Time Active", "Demurrage Incurred")


def test_sync_vessel_demurrage_clock_method(in_memory_db):
    service = VesselTrackingService(in_memory_db)

    file_obj = ImportFile(
        import_file_code="IMP-2026-SYNC",
        company_name="Sync Co",
        supplier_name="Global Supplier",
    )
    in_memory_db.add(file_obj)
    in_memory_db.commit()

    service.get_or_initialize_tracking_for_file(file_obj.import_file_id)

    res = service.sync_vessel_demurrage_clock(file_obj.import_file_id, user="SyncOfficer")
    assert res.tracking_milestone == "In Port / Berthed"
    assert res.demurrage_clock_started is True


def test_sync_demurrage_clock_api():
    client = TestClient(app)
    # File 1 exists or test endpoint returns valid response or 404
    resp = client.post("/api/v1/vessel-tracking/sync-demurrage/1")
    assert resp.status_code in (200, 404)
