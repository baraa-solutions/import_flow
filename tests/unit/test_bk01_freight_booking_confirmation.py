from datetime import datetime, date, timezone
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient

from database.database import Base, get_db
from main import app
from modules.freight_booking.schemas import (
    ShipmentBookingCreate,
    ShipmentBookingConfirm,
    ContainerAllocationItem,
    BookingChargeItem,
)
from modules.freight_booking.service import (
    create_booking_service,
    confirm_booking_service,
    get_booking_service,
)
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.incoterms.model import Incoterm
from modules.projects.model import Project
from modules.import_files.model import ImportFile
from modules.smart_tasks.model import SmartTask
from modules.notifications.model import SystemNotification
from modules.currencies.model import Currency


from sqlalchemy.pool import StaticPool

@pytest.fixture
def db_session():
    """Creates an isolated in-memory SQLite database session."""
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
    inco = Incoterm(
        incoterm_id=1,
        incoterm_code="FOB",
        incoterm_name="Free On Board",
        description="FOB",
    )
    proj = Project(
        project_id=1,
        project_code="PRJ-01",
        project_name="Expansion 2026",
        project_owner="Kamal",
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
    )
    file_rec = ImportFile(
        import_file_id=1,
        import_file_code="IMP-2026-0001",
        custom_file_number="6701068100",
        company_name="Egyptian Import Co",
        supplier_name="ABC Global Exporters",
        current_module="STEP_06 حجز النولون وتأكيد الخط الملاحي",
        progress_percent=40.0,
        target_free_days=21,
        owner="Kamal",
    )

    # Add a prior pending BK-01 task
    task1 = SmartTask(
        task_id=1,
        task_code="TSK-0001",
        title="متابعة حجز الشحن والناقل: IMP-2026-0001 (BK-01)",
        task_type="System Generated",
        status="Pending",
        import_file_id=1,
        import_file_code="IMP-2026-0001",
        assigned_user="Logistics Officer",
        priority="High",
        is_active=True,
    )

    curr1 = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
    curr2 = Currency(currency_code="EGP", currency_name="Egyptian Pound", currency_symbol="EGP", is_base_currency=True, is_active=True)
    db.add_all([comp, sup, inco, proj, file_rec, task1, curr1, curr2])
    db.commit()

    try:
        yield db
    finally:
        db.close()


@pytest.fixture
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    app.dependency_overrides.clear()


class TestBK01FreightBookingConfirmation:

    def test_create_and_confirm_booking_workflow(self, db_session):
        """Test full confirmation flow advancing to STEP_07, resolving prior tasks, and generating BK-02 task."""
        # 1. Create a draft booking
        create_payload = ShipmentBookingCreate(
            import_file_id=1,
            shipping_line_name="MSC",
            freight_forwarder_name="FastFreight",
            shipment_type="Ocean FCL",
            pol_name="Shanghai",
            pod_name="Alexandria",
            free_demurrage_days=14,
            containers_data=[
                ContainerAllocationItem(container_type="40HC", quantity=2)
            ],
            cost_charges_data=[
                BookingChargeItem(charge_type="Sea Freight", rate=1800.0, quantity=2, total=3600.0)
            ],
            status="Draft",
        )
        booking = create_booking_service(db_session, create_payload)
        assert booking.booking_id is not None
        assert booking.status == "Draft"

        # Check ImportFile initial state
        file_rec = db_session.query(ImportFile).filter_by(import_file_id=1).first()
        assert file_rec.current_module == "STEP_06 Freight Booking"
        assert file_rec.current_step_code == "STEP_06"
        assert file_rec.next_action_code.startswith("NA_STEP06_FOLLOW_BOOKING_CONFIRMATION")

        # 2. Confirm booking (BK-01)
        confirm_payload = ShipmentBookingConfirm(
            booking_confirmation_no="MSC-EGY-889977",
            vessel_name="MSC OSCAR",
            voyage_number="2608W",
            etd=datetime(2026, 8, 12, 12, 0, tzinfo=timezone.utc),
            eta=datetime(2026, 8, 28, 18, 0, tzinfo=timezone.utc),
            free_demurrage_days=21,
            notes="تم تأكيد الحجز ومطابقة فترات السماح المجانية 21 يوماً",
        )
        confirmed = confirm_booking_service(db_session, booking.booking_id, confirm_payload)
        assert confirmed is not None
        assert confirmed.status == "Confirmed"
        assert confirmed.booking_confirmation_no == "MSC-EGY-889977"
        assert confirmed.vessel_name == "MSC OSCAR"
        assert confirmed.voyage_number == "2608W"
        assert confirmed.free_demurrage_days == 21

        # 3. Verify two-way synchronization into ImportFile
        db_session.refresh(file_rec)
        assert file_rec.target_free_days == 21
        assert file_rec.required_eta == date(2026, 8, 28)
        assert "Confirmed booking: MSC (MSC OSCAR)" in (file_rec.selected_scenario or "")
        assert file_rec.current_module == "STEP_07 Freight Allocations"
        assert file_rec.progress_percent >= 50.0

        # 4. Verify prior BK-01 SmartTask was completed
        prior_task = db_session.query(SmartTask).filter_by(task_id=1).first()
        assert prior_task.status == "Completed"
        assert prior_task.is_auto_closed is True

        # 5. Verify downstream BK-02 SmartTask was created
        bk02_task = db_session.query(SmartTask).filter(
            SmartTask.import_file_id == 1,
            SmartTask.title.contains("BK-02"),
        ).first()
        assert bk02_task is not None
        assert "Record and confirm the container free days" in bk02_task.title
        assert bk02_task.assigned_user == "Logistics Officer"
        assert bk02_task.priority == "High"

        # 6. Verify SystemNotification was created
        notif = db_session.query(SystemNotification).filter(
            SystemNotification.category == "FREIGHT_BOOKING_CONFIRMED",
            SystemNotification.entity_id == booking.booking_id,
        ).first()
        assert notif is not None
        assert "Booking confirmed" in notif.title
        assert notif.msg_code == "FB_BOOKING_CONFIRMED"
        assert notif.msg_params["booking_no"] == "MSC-EGY-889977"
        assert "MSC-EGY-889977" in notif.message

    def test_api_confirm_booking_endpoint(self, client, db_session):
        """Test the HTTP POST endpoint /api/v1/freight-booking/{booking_id}/confirm."""
        # Create a booking first
        create_payload = ShipmentBookingCreate(
            import_file_id=1,
            shipping_line_name="CMA CGM",
            shipment_type="Ocean FCL",
            containers_data=[ContainerAllocationItem(container_type="20GP", quantity=1)],
            status="Draft",
        )
        booking = create_booking_service(db_session, create_payload)

        # Call POST confirm endpoint
        resp = client.post(
            f"/api/v1/freight-booking/{booking.booking_id}/confirm",
            json={
                "booking_confirmation_no": "CMA-2026-X1",
                "vessel_name": "CMA CGM CONCORDE",
                "voyage_number": "001E",
                "etd": "2026-09-01T10:00:00Z",
                "eta": "2026-09-18T10:00:00Z",
                "free_demurrage_days": 14,
                "notes": "Confirmed space",
            },
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "Confirmed"
        assert data["booking_confirmation_no"] == "CMA-2026-X1"
        assert data["vessel_name"] == "CMA CGM CONCORDE"
        assert data["free_demurrage_days"] == 14

        # Verify not found for non-existent booking
        resp_404 = client.post(
            "/api/v1/freight-booking/99999/confirm",
            json={"booking_confirmation_no": "FAKE-123"},
        )
        assert resp_404.status_code == 404
