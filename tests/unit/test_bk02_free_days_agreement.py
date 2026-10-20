from datetime import datetime, date, timezone
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

from database.database import Base, get_db
from main import app
from modules.demurrage_detention.schemas import (
    FreeDaysAgreementRegister,
    DemurrageTrackingCreate,
    ContainerItemInput,
)
from modules.demurrage_detention.service import (
    register_free_days_agreement_service,
    get_free_days_agreement_service,
    create_demurrage_tracking_service,
)
from modules.freight_booking.schemas import (
    ShipmentBookingCreate,
    ContainerAllocationItem,
)
from modules.freight_booking.service import create_booking_service
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.incoterms.model import Incoterm
from modules.projects.model import Project
from modules.import_files.model import ImportFile
from modules.smart_tasks.model import SmartTask
from modules.notifications.model import SystemNotification


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
        project_name="Petrochemical Plant",
        project_owner="Ahmed",
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        status="ACTIVE",
    )
    db.add_all([comp, sup, inco, proj])
    db.commit()

    # Create active ImportFile
    import_file = ImportFile(
        import_file_id=1,
        import_file_code="IMP-2026-0042",
        custom_file_number="6701068100",
        company_name="Egyptian Import Co",
        supplier_name="ABC Global Exporters",
        current_module="STEP_07_BOOKING_PLACED",
        progress_percent=50.0,
        target_free_days=14,
        is_active=True,
    )
    db.add(import_file)
    db.commit()

    # Create associated ShipmentBooking
    booking_in = ShipmentBookingCreate(
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
        status="Draft",
    )
    create_booking_service(db, booking_in)

    # Add pending BK-02 SmartTask
    bk02_task = SmartTask(
        task_id=202,
        task_code="TSK-0202",
        title="تسجيل فترات السماح المجانية للحاويات لتغذية رادار الغرامات: IMP-2026-0042 (BK-02)",
        task_type="System Generated",
        status="Pending",
        import_file_id=1,
        import_file_code="IMP-2026-0042",
        assigned_user="Logistics Officer",
        priority="High",
        is_active=True,
    )
    db.add(bk02_task)
    db.commit()

    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(engine)


def test_register_free_days_agreement_workflow(db_session):
    """Test BK-02 service: registers agreement, syncs models, closes task, sends notification."""
    req = FreeDaysAgreementRegister(
        import_file_id=1,
        carrier_name="MSC",
        agreed_demurrage_free_days=21,
        agreed_detention_free_days=14,
        port_storage_free_days=5,
        agreement_reference="MSC-ADDENDUM-2026-42",
        agreement_date="2026-04-12",
        notes="Negotiated 21 days demurrage with MSC local agency",
    )

    resp = register_free_days_agreement_service(db_session, req)

    # 1. Check response calculations
    assert resp.import_file_id == 1
    assert resp.agreed_demurrage_free_days == 21
    assert resp.agreed_detention_free_days == 14
    assert resp.additional_free_days_gained == 16  # 21 - 5 (Standard carrier baseline is 5 days)
    # 2 containers * 16 days * $70/day = 2240.0
    assert resp.estimated_cost_avoidance_usd == 2240.0
    assert resp.radar_status == "Safe"

    # 2. Check ImportFile synchronization
    imp = db_session.query(ImportFile).filter_by(import_file_id=1).first()
    assert imp.target_free_days == 21

    # 3. Check SmartTask auto-completion
    task = db_session.query(SmartTask).filter_by(task_id=202).first()
    assert task.status == "Completed"
    assert task.is_auto_closed is True

    # 4. Check SystemNotification dispatched
    notifications = (
        db_session.query(SystemNotification)
        .filter_by(entity_id=1)
        .all()
    )
    assert len(notifications) >= 1
    assert any("Free days recorded" in n.title and n.msg_code == "DD_FREE_DAYS_RECORDED" for n in notifications)


def test_recalculate_active_demurrage_tracking_on_agreement(db_session):
    """Test that active DemurrageTracking containers are updated when agreement is registered."""
    # Create active DemurrageTracking session with standard 14 days
    track_req = DemurrageTrackingCreate(
        import_file_id=1,
        carrier_name="MSC",
        bill_of_lading_no="MEDUST991200",
        port_name="Alexandria Port",
        discharge_date="2026-05-02",
        currency="USD",
        exchange_rate=50.0,
        containers=[
            ContainerItemInput(
                container_no="MSCU1234567",
                container_type="40ft High Cube",
            )
        ],
    )
    create_demurrage_tracking_service(db_session, track_req)

    # Now register extended free days agreement
    req = FreeDaysAgreementRegister(
        import_file_id=1,
        carrier_name="MSC",
        agreed_demurrage_free_days=28,
        agreed_detention_free_days=14,
        port_storage_free_days=7,
        agreement_reference="EXT-FREE-28D",
    )
    resp = register_free_days_agreement_service(db_session, req)

    assert resp.additional_free_days_gained == 23  # 28 - 5

    # Fetch agreement details
    fetched = get_free_days_agreement_service(db_session, 1)
    assert fetched.agreed_demurrage_free_days == 28
    assert fetched.agreement_reference == "EXT-FREE-28D"


def test_free_days_agreement_api_endpoints(db_session):
    """Test FastAPI REST endpoints for BK-02."""
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)

    # 1. POST agreement
    payload = {
        "import_file_id": 1,
        "carrier_name": "MSC",
        "agreed_demurrage_free_days": 21,
        "agreed_detention_free_days": 14,
        "port_storage_free_days": 5,
        "agreement_reference": "API-TEST-REF-99",
        "agreement_date": "2026-04-15",
        "notes": "FastAPI Endpoint Integration Test",
    }
    res = client.post("/api/v1/demurrage-detention/free-days-agreement", json=payload)
    assert res.status_code == 201
    data = res.json()
    assert data["import_file_id"] == 1
    assert data["agreed_demurrage_free_days"] == 21
    assert data["additional_free_days_gained"] == 16
    assert data["estimated_cost_avoidance_usd"] == 2240.0

    # 2. GET agreement
    get_res = client.get("/api/v1/demurrage-detention/free-days-agreement/1")
    assert get_res.status_code == 200
    get_data = get_res.json()
    assert get_data["agreement_reference"] == "API-TEST-REF-99"
    assert get_data["agreed_demurrage_free_days"] == 21

    app.dependency_overrides.clear()
