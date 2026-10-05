"""
Unit & Integration Tests for Live Logistics Tracking Radar (CL-003)
"""

import pytest
from datetime import date, timedelta
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base, get_db
from main import app
from modules.import_files.model import ImportFile
from modules.demurrage_detention.model import DemurrageTracking, DemurragePolicy
from modules.lifecycle_board.service import get_live_logistics_tracking_service

# Isolated in-memory SQLite database
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


@pytest.fixture(scope="function")
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


def test_live_logistics_tracking_aggregation_and_risk(db_session, client):
    today = date.today()

    # 1. Create active import files with various stages and conditions
    file1 = ImportFile(
        import_file_code="IMP-2026-0001",
        company_name="Al-Amal Import Co.",
        supplier_name="Global Steel Ltd",
        po_number="PO-9901",
        shipment_mode="Sea FCL",
        incoterm_code="CIF",
        priority="Critical",
        required_eta=today + timedelta(days=5),
        target_free_days=14,
        acid_number="1234567890123456789",
        form4_no="F4-8877",
        custom_file_number="BL-MSC-5544",
        is_active=True,
    )
    file2 = ImportFile(
        import_file_code="IMP-2026-0002",
        company_name="Nile Trading Group",
        supplier_name="Bavaria Tech GmbH",
        po_number="PO-9902",
        shipment_mode="Sea FCL",
        incoterm_code="FOB",
        priority="High",
        required_eta=today - timedelta(days=12),
        target_free_days=14,
        is_customs_released=False,
        is_active=True,
    )
    db_session.add_all([file1, file2])
    db_session.commit()

    # 2. Add a demurrage session for file 2 with discharge date
    dem = DemurrageTracking(
        tracking_code="DND-2026-0001",
        import_file_id=file2.import_file_id,
        import_file_code=file2.import_file_code,
        carrier_name="MSC Line",
        bill_of_lading_no="MEDU1234567",
        port_name="El Dekheila Port",
        discharge_date=today - timedelta(days=13),
        total_demurrage_fx=250.0,
        total_cost_egp=12500.0,
        exchange_rate=50.0,  # no default rate since the review wave (NOT NULL, no fabricated 50.0)
        status="Demurrage Incurred",
        is_active=True,
    )
    db_session.add(dem)
    db_session.commit()

    # 3. Call backend service directly
    res = get_live_logistics_tracking_service(db_session)
    assert res.total_active_shipments == 2
    assert res.in_transit_count == 1 # File 1 is sailing (ETA in 5 days)
    assert res.in_port_count == 1 # File 2 arrived 12 days ago
    assert res.high_risk_demurrage_count >= 1 # File 2 has demurrage incurred

    # Check File 1 item details
    item1 = next(item for item in res.items if item.import_file_code == "IMP-2026-0001")
    assert item1.arrival_status == "In Transit / Sailing"
    assert item1.eta_countdown_days == 5
    assert item1.demurrage_risk_level == "Low"
    assert item1.verified_documents_count >= 4 # Has ACID, Form 4, B/L
    assert item1.doc_readiness_percent > 50.0

    # Check File 2 item details
    item2 = next(item for item in res.items if item.import_file_code == "IMP-2026-0002")
    assert item2.arrival_status == "In Port / Clearing"
    assert item2.eta_countdown_days == -12
    assert item2.demurrage_risk_level == "Critical"
    assert item2.accumulated_demurrage_fx == 250.0
    assert item2.operational_health_score == "Critical Alert"

    # 4. Call via FastAPI endpoint
    api_res = client.get("/api/v1/lifecycle-board/live-tracking")
    assert api_res.status_code == 200
    data = api_res.json()
    assert data["total_active_shipments"] == 2
    assert len(data["items"]) == 2
