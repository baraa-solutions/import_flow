"""
Unit Tests for TASK-BE-09: LifecycleAutoSyncEngine (Centralized 25-Stage Master Timeline)
"""

from datetime import datetime, date, timedelta, timezone
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.import_files.model import ImportFile
from modules.lifecycle_board.model import ShipmentTimelineSnapshot, ShipmentStageActivity
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.freight_booking.model import ShipmentBooking
from modules.lifecycle_board.sync_engine import LifecycleAutoSyncEngine, ORDERED_STAGES
import modules.lifecycle_board.service as service


@pytest.fixture
def db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    session = Session()

    file1 = ImportFile(
        import_file_id=1,
        import_file_code="IMP-2026-0001",
        company_name="Sorour Logistics Co.",
        supplier_name="Global Vendor Corp",
        po_number="PO-2026-991",
        status="Under Customs Clearance",
        selected_scenario="Direct",
        file_opening_date=date(2026, 10, 1),
        acid_number="9988776655443322110",
        acid_issue_date=date(2026, 10, 5),
        acid_expiry_date=date(2026, 12, 31),
        progress_percent=30.0,
        is_active=True,
    )
    session.add(file1)

    act1 = ShipmentStageActivity(
        import_file_code="IMP-2026-0001",
        step_code="STEP_01",
        status="Completed",
        started_at="2026-10-01 10:00:00",
        completed_at="2026-10-02 14:00:00",
    )
    session.add(act1)

    session.commit()
    yield session
    session.close()


def test_sync_file_timeline_initializes_25_stages(db_session):
    res = LifecycleAutoSyncEngine.sync_file_timeline(db_session, import_file_id=1, commit=True)
    assert res["import_file_id"] == 1
    assert res["total_stages"] == 25
    assert len(res["snapshots"]) == 25

    # Check that all 25 codes exist in snapshot table
    saved = db_session.query(ShipmentTimelineSnapshot).filter_by(import_file_id=1).all()
    assert len(saved) == 25
    saved_codes = {s.stage_code for s in saved}
    assert saved_codes == set(ORDERED_STAGES)


def test_stage_status_and_event_enrichment(db_session):
    # Seed CustomsClearanceRecord with Dec 46 and tax coding/bank link dates
    clearance = CustomsClearanceRecord(
        clearance_code="CLR-2026-0001",
        import_file_id=1,
        declaration_46_no="DEC-46-9921",
        declaration_46_date=datetime(2026, 10, 15, 12, 0, 0),
        tariff_coding_date=datetime(2026, 10, 12, 10, 0, 0),
        bank_link_accepted_date=datetime(2026, 10, 13, 11, 0, 0),
        duty_payment_requested_date=datetime(2026, 10, 16, 9, 0, 0),
        customs_office_name="Alexandria Port",
        channel_type="Yellow Channel",
    )
    db_session.add(clearance)
    db_session.commit()

    res = LifecycleAutoSyncEngine.sync_file_timeline(db_session, import_file_id=1, commit=True)
    snapshots = {s.stage_code: s for s in res["snapshots"]}

    # STEP_01 was completed
    assert snapshots["STEP_01"].status == "COMPLETED"

    # STEP_05 had acid_number
    assert snapshots["STEP_05"].status == "COMPLETED"
    assert snapshots["STEP_05"].event_details_json["acid_number"] == "9988776655443322110"

    # STEP_12 has tariff coding and bank link details
    assert snapshots["STEP_12"].event_details_json["tariff_coding_date"] is not None
    assert snapshots["STEP_12"].event_details_json["bank_link_accepted_date"] is not None

    # STEP_13 has declaration 46 details
    assert snapshots["STEP_13"].status == "COMPLETED"
    assert snapshots["STEP_13"].event_details_json["declaration_46_no"] == "DEC-46-9921"
    assert snapshots["STEP_13"].event_details_json["channel_type"] == "Yellow Channel"


def test_advance_lifecycle_step_triggers_auto_sync(db_session):
    # Advance to STEP_06 (Freight Booking)
    service.advance_lifecycle_step_service(
        db=db_session,
        completed_step_code="STEP_05",
        import_file_id=1,
        target_step_codes=["STEP_06"],
        auto_complete_prior=True,
    )

    # Verify that timeline snapshots were automatically synced
    snap_05 = db_session.query(ShipmentTimelineSnapshot).filter_by(import_file_id=1, stage_code="STEP_05").first()
    snap_06 = db_session.query(ShipmentTimelineSnapshot).filter_by(import_file_id=1, stage_code="STEP_06").first()

    assert snap_05 is not None
    assert snap_05.status == "COMPLETED"
    assert snap_06 is not None
    assert snap_06.status in ("IN_PROGRESS", "COMPLETED", "DELAYED")
    if snap_06.status == "DELAYED":
        assert snap_06.is_bottleneck is True


def test_get_timeline_snapshots_service_summary(db_session):
    summary = service.get_timeline_snapshots_service(db_session, import_file_id=1)
    assert summary["import_file_id"] == 1
    assert summary["total_stages"] == 25
    assert summary["completed_count"] >= 1
    assert "overall_progress_percent" in summary
    assert len(summary["snapshots"]) == 25


def test_sla_cascade_upstream_delay_rolls_forward_uncompleted_stages(db_session):
    """
    Test SLA Cascade: A delay in an upstream completed stage pushes the planned dates
    of all subsequent uncompleted stages forward and records cascade_delay_days.
    """
    # File 1 base date is 2026-10-01.
    res1 = LifecycleAutoSyncEngine.sync_file_timeline(db_session, import_file_id=1, commit=True)
    snap_po_before = db_session.query(ShipmentTimelineSnapshot).filter_by(import_file_id=1, stage_code="STEP_08_PO").first()
    planned_before = snap_po_before.planned_date

    # Now, complete STEP_06 (Freight Booking) with a delayed completion
    act_06 = ShipmentStageActivity(
        import_file_code="IMP-2026-0001",
        step_code="STEP_06",
        status="Completed",
        started_at="2026-10-05 09:00:00",
        completed_at="2026-10-20 18:00:00",
    )
    db_session.add(act_06)
    db_session.commit()

    # Re-sync
    res2 = LifecycleAutoSyncEngine.sync_file_timeline(db_session, import_file_id=1, commit=True)
    snaps = {s.stage_code: s for s in res2["snapshots"]}

    # STEP_06 was completed on Oct 20
    assert snaps["STEP_06"].status == "COMPLETED"
    assert snaps["STEP_06"].actual_date == datetime(2026, 10, 20, 18, 0, 0)
    assert snaps["STEP_06"].is_bottleneck is True

    # STEP_07 (Freight Allocations, SLA: 2 days) should cascade from Oct 20 -> Oct 22
    assert snaps["STEP_07"].planned_date.date() >= date(2026, 10, 22)
    assert snaps["STEP_07"].event_details_json["cascade_delay_days"] > 0
    assert snaps["STEP_07"].event_details_json["baseline_planned_date"] is not None

    # STEP_08_PO should cascade further forward
    assert snaps["STEP_08_PO"].planned_date > planned_before
    assert snaps["STEP_08_PO"].event_details_json["cascade_delay_days"] > 0


def test_vessel_tracking_eta_delay_cascades_clearance_and_warehouse(db_session):
    """
    Test Vessel Tracking ETA Delay Cascade:
    When vessel tracking logs report an arrival delay, STEP_13 (Declaration 46)
    anchors to the updated ETA, cascading clearance steps and warehouse receiving.
    """
    from modules.freight_booking.model import ShipmentEtaTrackingLog

    # Create booking for File 1
    booking = ShipmentBooking(
        booking_code="BKG-TEST-001",
        import_file_id=1,
        etd=datetime(2026, 10, 5, 0, 0, 0),
        eta=datetime(2026, 10, 20, 0, 0, 0),
        vessel_name="WAN HAI 626",
        status="Sailed",
    )
    db_session.add(booking)
    db_session.flush()

    # Seed ETA tracking log with a 4-day delay (current_eta: 2026-10-24)
    log = ShipmentEtaTrackingLog(
        booking_id=booking.booking_id,
        import_file_id=1,
        tracking_date=datetime(2026, 10, 15, 12, 0, 0),
        vessel_location="Approaching Port Said",
        current_eta=datetime(2026, 10, 24, 8, 0, 0),
        delay_days=4,
    )
    db_session.add(log)
    db_session.commit()

    res = LifecycleAutoSyncEngine.sync_file_timeline(db_session, import_file_id=1, commit=True)
    snaps = {s.stage_code: s for s in res["snapshots"]}

    # Verify vessel arrival anchor was identified
    assert res["vessel_arrival_anchor"] is not None
    assert res["vessel_arrival_anchor"]["anchor_source"] == "tracking_log_current_eta"
    assert res["vessel_arrival_anchor"]["anchor_date"].date() == date(2026, 10, 24)

    # STEP_13 (Customs Declaration 46) must anchor to at least 2026-10-24
    assert snaps["STEP_13"].planned_date.date() >= date(2026, 10, 24)
    assert snaps["STEP_13"].event_details_json["vessel_anchor_source"] == "tracking_log_current_eta"

    # STEP_19 (Warehouse Receiving GRN) must cascade after port arrival
    assert snaps["STEP_19"].planned_date.date() > date(2026, 10, 24)
    assert snaps["STEP_19"].event_details_json["anchor_source"] == "tracking_log_current_eta"


def test_predicted_warehouse_eta_uses_similar_shipments_history(db_session):
    """
    Test Predicted Warehouse ETA Engine:
    Averages historical customs clearance duration from similar shipments sharing
    the same supplier or HS code, adding inland transport days.
    """
    # Seed historical completed similar shipment (File 2)
    file2 = ImportFile(
        import_file_id=2,
        import_file_code="IMP-2026-0002",
        company_name="Sorour Logistics Co.",
        supplier_name="Global Vendor Corp",
        file_opening_date=date(2026, 8, 1),
        status="Closed",
        is_active=True,
    )
    db_session.add(file2)
    db_session.flush()

    # Seed clearance record for File 2 with 4 days actual clearance duration (Arrival: Aug 10, Release: Aug 14)
    clr2 = CustomsClearanceRecord(
        clearance_code="CLR-2026-0002",
        import_file_id=2,
        port_arrival_date=datetime(2026, 8, 10, 8, 0, 0),
        release_date=datetime(2026, 8, 14, 16, 0, 0),
        status="Released",
    )
    db_session.add(clr2)

    # File 1 booking with ETA on 2026-11-01 and expected_warehouse_days = 6 (4d clearance + 2d inland)
    booking1 = db_session.query(ShipmentBooking).filter_by(import_file_id=1).first()
    if not booking1:
        booking1 = ShipmentBooking(
            booking_code="BKG-2026-0001",
            import_file_id=1,
            eta=datetime(2026, 11, 1, 10, 0, 0),
            expected_warehouse_days=6,
            status="Sailed",
        )
        db_session.add(booking1)
    else:
        booking1.eta = datetime(2026, 11, 1, 10, 0, 0)
        booking1.expected_warehouse_days = 6
    db_session.commit()

    # Calculate warehouse prediction
    pred = LifecycleAutoSyncEngine.calculate_predicted_warehouse_eta(
        db_session, import_file_id=1
    )

    assert pred is not None
    assert pred["anchor_source"] in ("booking_eta", "tracking_log_current_eta")
    assert pred["historical_clearance_avg_days"] == 4.0
    assert pred["inland_transport_days"] == 2
    assert pred["total_offset_days"] == 6

    # Predicted date = 2026-11-01 + 6 days = 2026-11-07
    expected_pred_date = date(2026, 11, 1) + timedelta(days=6)
    assert pred["predicted_date"].date() == expected_pred_date

    # Verify that booking.expected_warehouse_arrival_date was updated
    db_session.refresh(booking1)
    assert booking1.expected_warehouse_arrival_date is not None
    assert booking1.expected_warehouse_arrival_date.date() == expected_pred_date

    # Verify sync_file_timeline embeds this prediction in STEP_19 snapshot
    res = LifecycleAutoSyncEngine.sync_file_timeline(db_session, import_file_id=1, commit=True)
    snaps = {s.stage_code: s for s in res["snapshots"]}

    step_19_details = snaps["STEP_19"].event_details_json
    assert step_19_details["historical_clearance_avg_days"] == 4.0
    assert step_19_details["predicted_warehouse_arrival_date"] == str(expected_pred_date)
    assert "calculation_breakdown" in step_19_details

