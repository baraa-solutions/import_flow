from datetime import datetime, date, timedelta, timezone
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

from database.database import Base, get_db
from main import app
from modules.freight_booking.schemas import (
    ShipmentBookingConfirm,
    ShipmentBookingCreate,
    ShipmentDepartureConfirm,
    ContainerAllocationItem,
    BookingChargeItem,
)
from modules.freight_booking.service import (
    create_booking_service,
    confirm_booking_service,
    confirm_departure_and_bol_service,
    get_booking_service,
)
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.import_files.model import ImportFile
from modules.smart_tasks.model import SmartTask
from modules.notifications.model import SystemNotification
from modules.demurrage_detention.model import DemurrageTracking


@pytest.fixture
def db_session():
    """Creates an isolated in-memory SQLite database session with seed data."""
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
        echo=False,
    )
    Base.metadata.create_all(engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = TestingSessionLocal()

    comp = ImportCompany(
        company_id=1,
        importer_name="Egyptian Import Co",
        vat_id="100-200-300",
        vat_id_expiry=date(2028, 1, 1),
        registration_number="12345",
        registration_expiry=date(2028, 1, 1),
        address="Cairo",
        country="Egypt",
        importer_id="IMP-001",
        importer_id_expiry=date(2028, 1, 1),
    )
    sup = Supplier(
        supplier_id=1,
        company_name="ABC Global Exporters",
        supplier_code="SUP-01",
        supplier_type="Manufacturer",
        registration_type="Foreign Exporter",
        foreign_exporter_id="CN-99",
        foreign_exporter_country="China",
        foreign_exporter_country_code="CN",
        address="Shanghai",
    )
    import_file = ImportFile(
        import_file_id=10,
        import_file_code="IMP-2026-0010",
        company_id=1,
        company_name="Egyptian Import Co",
        supplier_id=1,
        supplier_name="ABC Global Exporters",
        current_module="STEP_07 تخصيص وتوزيع الحاويات والبضائع",
        progress_percent=50.0,
        target_free_days=21,
        status="In Progress",
    )
    db.add_all([comp, sup, import_file])
    db.commit()

    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(engine)


@pytest.fixture
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


def test_confirm_departure_and_bol_success(db_session):
    """
    SH-01: Departure Confirmation & Bill of Lading Registration.
    Verifies ATD, B/L number, status transition to 'Sailed', delay calculation,
    ImportFile stage advancement, DemurrageTracking sync, SmartTask auto-close & SH-02 dispatch,
    and SystemNotification generation.
    """
    # 1. Create a prior pending departure SmartTask
    prior_task = SmartTask(
        task_id=101,
        task_code="TSK-2026-0101",
        title="تأكيد الإبحار الفعلي للشحنة: IMP-2026-0010 (SH-01)",
        task_type="System Generated",
        import_file_id=10,
        import_file_code="IMP-2026-0010",
        status="Pending",
        priority="High",
        is_active=True,
    )
    db_session.add(prior_task)

    # 2. Create DemurrageTracking session for the file
    dem = DemurrageTracking(
        tracking_id=1,
        tracking_code="DND-2026-0001",
        import_file_id=10,
        import_file_code="IMP-2026-0010",
        carrier_name="MSC",
        bill_of_lading_no="PENDING-BL",
        port_name="Alexandria Port",
        discharge_date=date(2026, 9, 1),
        containers=[],
        exchange_rate=50.0,  # no default rate since the review wave (NOT NULL, no fabricated 50.0)
        is_active=True,
    )
    db_session.add(dem)
    db_session.commit()

    # 3. Create a confirmed booking
    booking_create = ShipmentBookingCreate(
        import_file_id=10,
        booking_confirmation_no="MSC-CONF-8899",
        shipping_line_name="MSC Mediterranean Shipping Co",
        vessel_name="MSC LORETTO",
        voyage_number="2609W",
        etd=datetime(2026, 8, 20, 10, 0, tzinfo=timezone.utc),
        eta=datetime(2026, 9, 5, 18, 0, tzinfo=timezone.utc),
        containers_data=[
            ContainerAllocationItem(container_type="40HC", quantity=2)
        ],
        cost_charges_data=[
            BookingChargeItem(charge_type="Sea Freight", unit="Per Container", quantity=2, rate=2100.0, total=4200.0)
        ],
        # Confirmed is no longer a manual status on create: request first, then confirm (BK-01)
        status="Booking Requested",
    )
    booking = create_booking_service(db_session, booking_create)
    assert booking.booking_id is not None
    booking = confirm_booking_service(
        db_session,
        booking.booking_id,
        ShipmentBookingConfirm(
            booking_confirmation_no="MSC-CONF-8899",
            etd=datetime(2026, 8, 20, 10, 0, tzinfo=timezone.utc),
            eta=datetime(2026, 9, 5, 18, 0, tzinfo=timezone.utc),
        ),
    )
    assert booking.status == "Confirmed"

    # 4. Confirm departure with ATD 2 days after ETD (delayed departure)
    departure_payload = ShipmentDepartureConfirm(
        actual_departure_date=datetime(2026, 8, 22, 14, 0, tzinfo=timezone.utc),
        bill_of_lading_no="MEDUST1234567",
        revised_eta=datetime(2026, 9, 7, 18, 0, tzinfo=timezone.utc),
        vessel_name="MSC LORETTO",
        voyage_number="2609W",
        shipped_on_board_date=date(2026, 8, 22),
        notes="Vessel departed Alexandria feeder connection on schedule after customs clearance.",
    )

    updated_booking = confirm_departure_and_bol_service(db_session, booking.booking_id, departure_payload)

    # 5. Verify Booking updates
    assert updated_booking is not None
    assert updated_booking.status == "Sailed"
    assert updated_booking.bill_of_lading_no == "MEDUST1234567"
    assert updated_booking.atd.replace(tzinfo=None) == datetime(2026, 8, 22, 14, 0)
    assert updated_booking.departure_delay_days == 2
    assert updated_booking.eta.replace(tzinfo=None) == datetime(2026, 9, 7, 18, 0)

    # 6. Verify ImportFile synchronization
    file_rec = db_session.query(ImportFile).filter(ImportFile.import_file_id == 10).first()
    assert file_rec is not None
    assert "STEP_08" in file_rec.current_module
    assert file_rec.progress_percent >= 60.0
    assert file_rec.required_eta == date(2026, 9, 7)

    # 7. Verify DemurrageTracking synchronization
    db_session.refresh(dem)
    assert dem.bill_of_lading_no == "MEDUST1234567"

    # 8. Verify SmartTask auto-close & SH-02 creation
    db_session.refresh(prior_task)
    assert prior_task.status == "Completed"
    assert prior_task.is_auto_closed is True

    downstream_tasks = db_session.query(SmartTask).filter(
        SmartTask.import_file_id == 10,
        SmartTask.status == "Pending",
    ).all()
    sh02_tasks = [t for t in downstream_tasks if "sh-02" in t.title.lower() or "مزدوجة" in t.title]
    assert len(sh02_tasks) >= 1
    assert "MEDUST1234567" in sh02_tasks[0].description

    # 9. Verify SystemNotification
    notifs = db_session.query(SystemNotification).filter(
        SystemNotification.category == "SHIPMENT_DEPARTED",
        SystemNotification.entity_id == booking.booking_id,
    ).all()
    assert len(notifs) >= 1
    assert "MEDUST1234567" in notifs[0].title
    assert "IMP-2026-0010" in notifs[0].message


def test_departure_api_endpoint(client, db_session):
    """Tests the REST API endpoint POST /api/v1/freight-booking/{booking_id}/depart."""
    booking_create = ShipmentBookingCreate(
        import_file_id=10,
        booking_confirmation_no="CMA-CONF-7711",
        shipping_line_name="CMA CGM",
        containers_data=[
            ContainerAllocationItem(container_type="20GP", quantity=1)
        ],
        # Confirmed is no longer a manual status on create: request first, then confirm (BK-01)
        status="Booking Requested",
    )
    booking = create_booking_service(db_session, booking_create)
    booking = confirm_booking_service(
        db_session, booking.booking_id, ShipmentBookingConfirm(booking_confirmation_no="CMA-CONF-7711")
    )
    assert booking.status == "Confirmed"

    # Test valid depart call
    payload = {
        "actual_departure_date": "2026-08-25T15:00:00Z",
        "bill_of_lading_no": "CMA-BL-998877",
        "revised_eta": "2026-09-10T12:00:00Z",
        "vessel_name": "CMA CGM RIVOLI",
        "voyage_number": "FR99",
        "notes": "Sailed on time",
    }
    response = client.post(f"/api/v1/freight-booking/{booking.booking_id}/depart", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "Sailed"
    assert data["bill_of_lading_no"] == "CMA-BL-998877"

    # Test non-existent booking ID returns 404
    resp_404 = client.post("/api/v1/freight-booking/999999/depart", json=payload)
    assert resp_404.status_code == 404

    # Test validation error on short B/L
    bad_payload = {
        "actual_departure_date": "2026-08-25T15:00:00Z",
        "bill_of_lading_no": "A",  # Min length is 3
    }
    resp_bad = client.post(f"/api/v1/freight-booking/{booking.booking_id}/depart", json=bad_payload)
    assert resp_bad.status_code == 422
