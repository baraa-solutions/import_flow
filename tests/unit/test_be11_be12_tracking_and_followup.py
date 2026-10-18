"""
Unit tests for TASK-BE-11 (Vessel ETA tracking log and ATA confirmation)
and TASK-BE-12 (Customs clearance field follow-up logs).
"""

from datetime import datetime, timedelta, timezone
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.customs_clearance.model import ClearanceFollowupLog, CustomsClearanceRecord
from modules.customs_clearance.schemas import ClearanceFollowupLogCreate
from modules.customs_clearance.service import (
    complete_clearance_followup_service,
    create_clearance_followup_log_service,
    get_clearance_followup_logs_service,
)
from modules.freight_booking.model import ShipmentBooking, ShipmentEtaTrackingLog
from modules.freight_booking.schemas import ConfirmAtaRequest, ShipmentEtaTrackingLogCreate
from modules.freight_booking.service import (
    confirm_ata_service,
    create_eta_tracking_log_service,
    get_eta_tracking_logs_service,
)
from modules.import_files.model import ImportFile


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()

    # Create dummy import file
    imp_file = ImportFile(
        import_file_id=101,
        import_file_code="IMP-2026-0101",
        custom_file_number="FILE-101",
        company_name="Al-Sorour Logistics Import Co.",
        supplier_name="Global Steel Ltd",
        po_number="PO-101",
        pi_number="PI-101",
        shipment_mode="Sea FCL",
        estimated_cost=50000.0,
        current_stage="Phase 4 - Freight & Shipping",
        is_active=True,
    )
    session.add(imp_file)

    # Create dummy booking
    booking = ShipmentBooking(
        booking_id=1,
        booking_code="BKG-2026-0001",
        booking_confirmation_no="CNF-9988",
        import_file_id=101,
        shipment_type="Ocean FCL",
        vessel_name="MSC MARINA",
        voyage_number="V.2026A",
        etd=datetime(2026, 10, 1, 10, 0, tzinfo=timezone.utc),
        eta=datetime(2026, 10, 20, 10, 0, tzinfo=timezone.utc),
        is_ata_confirmed=False,
        status="Sailing",
    )
    session.add(booking)

    # Create dummy customs clearance record
    clearance = CustomsClearanceRecord(
        customs_clearance_id=1,
        clearance_code="CLR-2026-0001",
        import_file_id=101,
        declaration_46_no="46/2026/8899",
        status="Inspection In Progress",
        is_active=True,
    )
    session.add(clearance)
    session.commit()

    yield session
    session.close()


def test_eta_tracking_log_creation_and_delay_calculation(db_session):
    """
    Test creating an ETA tracking log, verifying automatic delay days calculation
    and updating of the booking's current ETA.
    """
    initial_eta = datetime(2026, 10, 20, 10, 0, tzinfo=timezone.utc)
    updated_eta = datetime(2026, 10, 23, 10, 0, tzinfo=timezone.utc)  # 3 days delay

    payload = ShipmentEtaTrackingLogCreate(
        booking_id=1,
        import_file_id=101,
        tracking_date=datetime(2026, 10, 10, 12, 0, tzinfo=timezone.utc),
        vessel_location="Transit Red Sea / Bab El-Mandeb",
        current_eta=updated_eta,
        remarks="Bad weather causing a 3-day transit delay",
    )

    log = create_eta_tracking_log_service(db_session, payload, user="LogisticsCoordinator")
    assert log.log_id is not None
    assert log.booking_id == 1
    assert log.delay_days == 3
    assert log.vessel_location == "Transit Red Sea / Bab El-Mandeb"

    # Verify that the booking's ETA was updated
    booking = db_session.query(ShipmentBooking).filter(ShipmentBooking.booking_id == 1).first()
    assert booking.eta.date() == updated_eta.date()
    assert booking.eta.hour == updated_eta.hour
    assert booking.eta.minute == updated_eta.minute


def test_get_eta_tracking_logs_filtering(db_session):
    """Test retrieving ETA tracking logs by booking_id and import_file_id."""
    log1 = ShipmentEtaTrackingLog(
        booking_id=1,
        import_file_id=101,
        tracking_date=datetime(2026, 10, 5, 10, 0, tzinfo=timezone.utc),
        vessel_location="Port Kelang",
        current_eta=datetime(2026, 10, 20, 10, 0, tzinfo=timezone.utc),
        delay_days=0,
        remarks="Departed on schedule",
    )
    log2 = ShipmentEtaTrackingLog(
        booking_id=1,
        import_file_id=101,
        tracking_date=datetime(2026, 10, 10, 10, 0, tzinfo=timezone.utc),
        vessel_location="Colombo",
        current_eta=datetime(2026, 10, 21, 10, 0, tzinfo=timezone.utc),
        delay_days=1,
        remarks="Slight delay due to bunkering",
    )
    db_session.add_all([log1, log2])
    db_session.commit()

    logs = get_eta_tracking_logs_service(db_session, booking_id=1)
    assert len(logs) == 2

    logs_by_file = get_eta_tracking_logs_service(db_session, import_file_id=101)
    assert len(logs_by_file) == 2

    empty_logs = get_eta_tracking_logs_service(db_session, booking_id=999)
    assert len(empty_logs) == 0


def test_confirm_ata_service_and_sync(db_session):
    """Test vessel ATA confirmation and status update."""
    ata_time = datetime(2026, 10, 22, 14, 30, tzinfo=timezone.utc)
    payload = ConfirmAtaRequest(
        confirmed_ata=ata_time,
        remarks="Vessel safely berthed at Alexandria Old Port berth 42",
    )

    log = confirm_ata_service(db_session, booking_id=1, payload=payload, user="PortAgent")
    assert log.is_ata_confirmed is True
    assert log.confirmed_ata.date() == ata_time.date()
    assert log.confirmed_ata.hour == ata_time.hour
    assert log.confirmed_ata.minute == ata_time.minute

    booking = db_session.query(ShipmentBooking).filter(ShipmentBooking.booking_id == 1).first()
    assert booking.is_ata_confirmed is True
    assert booking.ata.date() == ata_time.date()
    assert booking.ata.hour == ata_time.hour
    assert booking.ata.minute == ata_time.minute
    assert booking.status == "Arrived"


def test_clearance_followup_log_workflow(db_session):
    """
    Test recording clearance field follow-up logs, listing them sequentially,
    and marking a follow-up as completed.
    """
    followup_1 = ClearanceFollowupLogCreate(
        customs_clearance_id=1,
        import_file_id=101,
        followup_seq=1,
        followup_date=datetime(2026, 10, 23, 9, 30, tzinfo=timezone.utc),
        authority_type="Customs Inspection Yard",
        official_contact="Eng. Ahmed Morsy",
        status_summary="Containers opened, visual inspection completed without discrepancies",
        action_required="Submit GOEIC sample request",
        next_visit_date=datetime(2026, 10, 24, 10, 0, tzinfo=timezone.utc),
        is_completed=False,
    )
    created_log_1 = create_clearance_followup_log_service(db_session, followup_1, user="FieldBroker")
    assert created_log_1.log_id is not None
    assert created_log_1.followup_seq == 1
    assert created_log_1.is_completed is False

    followup_2 = ClearanceFollowupLogCreate(
        customs_clearance_id=1,
        import_file_id=101,
        followup_seq=2,
        followup_date=datetime(2026, 10, 24, 10, 0, tzinfo=timezone.utc),
        authority_type="Customs Valuation Committee",
        official_contact="Mr. Sameh Farag",
        status_summary="Valuation accepted as per commercial invoice without price uplift",
        action_required="Proceed with final duty assessment",
        next_visit_date=None,
        is_completed=False,
    )
    created_log_2 = create_clearance_followup_log_service(db_session, followup_2, user="FieldBroker")
    assert created_log_2.log_id is not None
    assert created_log_2.followup_seq == 2

    # Query logs by clearance record
    logs = get_clearance_followup_logs_service(db_session, customs_clearance_id=1)
    assert len(logs) == 2
    assert logs[0].followup_seq == 1
    assert logs[1].followup_seq == 2

    # Query logs by import file
    logs_by_file = get_clearance_followup_logs_service(db_session, import_file_id=101)
    assert len(logs_by_file) == 2

    # Mark followup 1 as completed
    completed_log = complete_clearance_followup_service(db_session, log_id=created_log_1.log_id, user="FieldBroker")
    assert completed_log.is_completed is True


def test_clearance_followup_log_error_handling(db_session):
    """Test error handling when referencing non-existent records."""
    invalid_followup = ClearanceFollowupLogCreate(
        customs_clearance_id=9999,
        import_file_id=101,
        followup_seq=1,
        followup_date=datetime(2026, 10, 23, 9, 30, tzinfo=timezone.utc),
        authority_type="GOEIC",
        status_summary="Sample taken",
    )

    with pytest.raises(HTTPException) as exc_info:
        create_clearance_followup_log_service(db_session, invalid_followup, user="FieldBroker")
    assert exc_info.value.status_code == 404

    with pytest.raises(HTTPException) as exc_info_complete:
        complete_clearance_followup_service(db_session, log_id=9999, user="FieldBroker")
    assert exc_info_complete.value.status_code == 404
