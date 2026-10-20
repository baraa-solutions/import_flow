import pytest
from datetime import datetime, date
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

import main
from database.database import Base, get_db
from modules.import_files.model import ImportFile
from modules.freight_booking.model import ShipmentBooking
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.warehouse_receiving.model import WarehouseReceivingRecord
from modules.file_closure.schemas import ShipmentAuditTimelineResponse, UpdateMeetingDirectivesPayload
from modules.file_closure.service import (
    get_shipment_audit_timeline_service,
    update_audit_meeting_directives_service,
)

SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="function")
def db_session():
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)


def test_get_shipment_audit_timeline_service_full(db_session):
    # 1. Seed sample ImportFile
    imp = ImportFile(
        import_file_code="IMP-2026-TEST-36",
        custom_file_number="PET-STOCK-TEST",
        company_name="Test Importer Co.",
        supplier_name="Test Supplier Ltd.",
        status="Open",
        progress_percent=65.0,
        is_active=True,
    )
    db_session.add(imp)
    db_session.flush()

    # 2. Seed Booking
    bkg = ShipmentBooking(
        booking_code="BKG-2026-TEST",
        booking_confirmation_no="THXJ-TEST-001",
        import_file_id=imp.import_file_id,
        shipping_line_name="Maersk Line",
        etd=datetime(2026, 9, 25, 10, 0, 0),
        atd=datetime(2026, 9, 25, 12, 0, 0),
        eta=datetime(2026, 10, 23, 18, 0, 0),
        free_demurrage_days=14,
        is_active=True,
    )
    db_session.add(bkg)

    # 3. Seed Customs Clearance
    clr = CustomsClearanceRecord(
        clearance_code="CLR-2026-TEST",
        import_file_id=imp.import_file_id,
        declaration_46_no="DEC-46-TEST",
        port_arrival_date=datetime(2026, 10, 19, 8, 0, 0),
        free_days_allowed=5,
        is_active=True,
    )
    db_session.add(clr)
    db_session.commit()

    # 4. Invoke service
    res = get_shipment_audit_timeline_service(db_session, imp.import_file_id)

    assert isinstance(res, ShipmentAuditTimelineResponse)
    assert res.import_file_id == imp.import_file_id
    assert res.import_file_code == "IMP-2026-TEST-36"
    assert res.company_name == "Test Importer Co."
    assert res.supplier_name == "Test Supplier Ltd."
    assert res.shipping_line_name == "Maersk Line"
    assert res.bill_of_lading_no == "THXJ-TEST-001"

    # Financial Radar asserts
    radar = res.financial_radar
    assert radar.port_storage_start_date == "2026-10-24"
    assert radar.port_storage_free_days == 5
    assert radar.demurrage_start_date == "2026-11-02"
    assert radar.demurrage_free_days == 14
    assert radar.expected_warehouse_delivery_date == "2026-10-28"

    # Milestones count assert
    assert len(res.milestones) == 39  # 36 core + 3 delivery/container targets
    
    # Verify critical watchpoints exist
    storage_mile = next((m for m in res.milestones if m.code == "MILE_20"), None)
    assert storage_mile is not None
    assert storage_mile.is_critical_watchpoint is True
    assert storage_mile.planned_date == "2026-10-24"

    demurrage_mile = next((m for m in res.milestones if m.code == "MILE_21"), None)
    assert demurrage_mile is not None
    assert demurrage_mile.is_critical_watchpoint is True
    assert demurrage_mile.planned_date == "2026-11-02"


def test_update_audit_meeting_directives_service(db_session):
    imp = ImportFile(
        import_file_code="IMP-2026-TEST-NOTE",
        company_name="Co",
        supplier_name="Sup",
        status="Open",
        is_active=True,
    )
    db_session.add(imp)
    db_session.commit()

    new_note = "توجيهات الاجتماع: سرعة إنهاء سداد المطالبة قبل موعد الأرضيات."
    resp = update_audit_meeting_directives_service(db_session, imp.import_file_id, new_note, user="Eng. Sorour")

    assert resp["success"] is True
    assert resp["meeting_directives"] == new_note

    # Verify reload
    reloaded = get_shipment_audit_timeline_service(db_session, imp.import_file_id)
    assert reloaded.meeting_directives == new_note
