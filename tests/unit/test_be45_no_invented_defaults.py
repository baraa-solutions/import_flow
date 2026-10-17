"""Unit tests for BE45-T18: Remove invented defaults.

Verifies that:
1. Demurrage tracking create without `port_name` returns HTTP 422.
2. Demurrage tracking create with container missing `container_type` returns HTTP 422.
3. Cargo insurance certificate create without `claims_payable_at` stores NULL in DB (and returns null in response).
4. Demurrage policy create without free days or storage rate fills them from configured `system_parameters` (default tariff).
5. Empty container return without `depot_name` leaves `empty_containers_depot_name` as None.
6. GET `/api/v1/demurrage-detention/free-days-agreement/{file_id}` returns `carrier_name: null` when unknown.
"""

from datetime import date, datetime, timezone
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

import main
from database.database import Base, get_db
from modules.auth.router import get_current_user
from modules.users.model import User
from modules.import_files.model import ImportFile
from modules.demurrage_detention.model import DemurrageTracking, DemurragePolicy
from modules.cargo_insurance.model import CargoInsuranceCertificate


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

    test_user = User(
        user_id=1,
        username="test_admin",
        full_name="Test Admin",
        role="Admin",
        is_active=True,
    )

    def override_get_current_user():
        return test_user

    main.app.dependency_overrides[get_db] = override_get_db
    main.app.dependency_overrides[get_current_user] = override_get_current_user
    with TestClient(main.app) as c:
        yield c
    main.app.dependency_overrides.clear()


class TestBE45NoInventedDefaults:

    def test_tracking_create_without_port_name_gives_422(self, db_session, client):
        """Demurrage tracking create without port_name fails with 422 Unprocessable Entity."""
        imp_file = ImportFile(
            import_file_id=1,
            import_file_code="IMP-2026-0001",
            company_name="Test Co",
            supplier_name="Test Sup",
            is_active=True,
        )
        db_session.add(imp_file)
        db_session.commit()

        payload = {
            "import_file_id": 1,
            "carrier_name": "MSC",
            "bill_of_lading_no": "BL-TEST-123",
            # "port_name" omitted
            "discharge_date": "2026-01-01",
            "containers": [
                {"container_no": "MSCU1234567", "container_type": "40ft High Cube"}
            ],
            "currency": "USD",
        }
        res = client.post("/api/v1/demurrage-detention/trackings", json=payload)
        assert res.status_code == 422
        errors = res.json().get("detail", [])
        assert any("port_name" in str(err) for err in errors)

    def test_tracking_create_without_container_type_gives_422(self, db_session, client):
        """Demurrage tracking create with container missing container_type fails with 422."""
        imp_file = ImportFile(
            import_file_id=1,
            import_file_code="IMP-2026-0002",
            company_name="Test Co",
            supplier_name="Test Sup",
            is_active=True,
        )
        db_session.add(imp_file)
        db_session.commit()

        payload = {
            "import_file_id": 1,
            "carrier_name": "MSC",
            "bill_of_lading_no": "BL-TEST-456",
            "port_name": "Alexandria Port",
            "discharge_date": "2026-01-01",
            "containers": [
                {"container_no": "MSCU1234567"}  # "container_type" omitted
            ],
            "currency": "USD",
        }
        res = client.post("/api/v1/demurrage-detention/trackings", json=payload)
        assert res.status_code == 422
        errors = res.json().get("detail", [])
        assert any("container_type" in str(err) for err in errors)

    def test_certificate_create_without_claims_payable_at_stores_null(self, db_session, client):
        """A cargo insurance certificate created without claims_payable_at stores NULL in DB."""
        payload = {
            "insured_entity_name": "Modern Importers LLC",
            "port_of_loading": "Ningbo, China",
            "port_of_discharge": "Alexandria Port, Egypt",
            "invoice_value": 50000.0,
            "freight_cost": 3000.0,
            "currency": "USD",
            "exchange_rate": 50.0,
            "coverage_clause": "ICC_A",
            # "claims_payable_at" omitted
        }
        res = client.post("/api/v1/cargo-insurance/certificates", json=payload)
        assert res.status_code == 201, res.text
        cert_data = res.json()
        assert cert_data["claims_payable_at"] is None

        # Verify in DB directly
        cert_db = db_session.query(CargoInsuranceCertificate).filter_by(
            certificate_code=cert_data["certificate_code"]
        ).first()
        assert cert_db is not None
        assert cert_db.claims_payable_at is None

    def test_policy_create_without_free_days_fills_from_default_tariff(self, db_session, client):
        """Demurrage policy create without free days or storage rate takes configured system_parameters values."""
        payload = {
            "carrier_name": "Maersk",
            "container_type": "40ft High Cube",
            "currency": "USD",
            # free days and storage rate omitted
        }
        res = client.post("/api/v1/demurrage-detention/policies", json=payload)
        assert res.status_code == 201, res.text
        policy_data = res.json()
        assert policy_data["demurrage_free_days"] == 14
        assert policy_data["detention_free_days"] == 7
        assert policy_data["port_storage_free_days"] == 5
        assert policy_data["port_storage_daily_rate_egp"] == 250.0

        # Verify in DB directly
        policy_db = db_session.query(DemurragePolicy).filter_by(
            policy_id=policy_data["policy_id"]
        ).first()
        assert policy_db.demurrage_free_days == 14
        assert policy_db.detention_free_days == 7
        assert policy_db.port_storage_free_days == 5
        assert policy_db.port_storage_daily_rate_egp == 250.0

    def test_empty_container_return_without_depot_name_stores_null(self, db_session, client):
        """EIR container return without depot_name leaves empty_containers_depot_name as None."""
        imp_file = ImportFile(
            import_file_id=1,
            import_file_code="IMP-2026-0003",
            company_name="Test Co",
            supplier_name="Test Sup",
            is_active=True,
        )
        db_session.add(imp_file)
        db_session.commit()

        tracking = DemurrageTracking(
            tracking_code="TRK-EIR-001",
            import_file_id=1,
            carrier_name="MSC",
            bill_of_lading_no="BL-EIR-001",
            port_name="Alexandria Port",
            discharge_date=date(2026, 1, 1),
            containers=[
                {"container_no": "MSCU9999999", "container_type": "40ft High Cube"}
            ],
            currency="USD",
            exchange_rate=50.0,
            status="Free Time Active",
            is_active=True,
        )
        db_session.add(tracking)
        db_session.commit()

        payload = {
            "import_file_id": 1,
            "eir_number": "EIR-2026-9999",
            "empty_return_date": "2026-01-10",
            # "depot_name" omitted
        }
        res = client.post("/api/v1/demurrage-detention/empty-container-return", json=payload)
        assert res.status_code == 201, res.text

        db_session.refresh(imp_file)
        assert imp_file.empty_containers_depot_name is None

    def test_free_days_agreement_unknown_carrier_returns_null(self, db_session, client):
        """GET /free-days-agreement/{id} returns carrier_name: null when unknown (no booking)."""
        imp_file = ImportFile(
            import_file_id=1,
            import_file_code="IMP-2026-0004",
            company_name="Test Co",
            supplier_name="Test Sup",
            is_active=True,
        )
        db_session.add(imp_file)
        db_session.commit()

        res = client.get("/api/v1/demurrage-detention/free-days-agreement/1")
        assert res.status_code == 200, res.text
        data = res.json()
        assert data["carrier_name"] is None
