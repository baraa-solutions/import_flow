from datetime import date, datetime, timezone
import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main  # Ensures all models and routers are registered
from database.database import Base, get_db
from modules.bank_form4.model import BankForm4Record
from modules.bank_form4.schemas import (
    BankForm4Create,
    BankForm4Update,
    DelayCostCalculation,
    NafezaTransmissionUpdate,
)
from modules.bank_form4.service import BankForm4Service
from modules.bank_form4.validators import (
    validate_currency,
    validate_positive_amount,
    validate_swift_reference,
)
from modules.external_service_providers.model import ExternalServiceProvider
from modules.import_files.model import ImportFile


# Test database setup
engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture
def db():
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()

    # Seed test bank
    bank = ExternalServiceProvider(
        provider_id=1,
        partner_code="BNK-CIB-01",
        partner_name="Commercial International Bank (CIB)",
        partner_type="Bank",
        is_active=True,
    )
    session.add(bank)

    # Seed test import file
    imp_file = ImportFile(
        import_file_id=101,
        import_file_code="IMP-2026-0001",
        company_name="Al-Amal Trade",
        supplier_name="Global Tech Ltd",
        is_active=True,
    )
    session.add(imp_file)
    session.commit()

    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture
def client(db):
    def override_get_db():
        try:
            yield db
        finally:
            pass

    main.app.dependency_overrides[get_db] = override_get_db
    yield TestClient(main.app)
    main.app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Unit Tests: Validators
# ---------------------------------------------------------------------------
def test_validate_currency_valid():
    assert validate_currency("USD") == "USD"
    assert validate_currency("eur") == "EUR"
    assert validate_currency("EGP ") == "EGP"


def test_validate_currency_invalid():
    with pytest.raises(HTTPException) as exc:
        validate_currency("GBP")
    assert exc.value.status_code == 400


def test_validate_positive_amount():
    assert validate_positive_amount(1500.50) == 1500.50
    with pytest.raises(HTTPException):
        validate_positive_amount(0.0)
    with pytest.raises(HTTPException):
        validate_positive_amount(-50.0)


def test_validate_swift_reference_formats():
    assert validate_swift_reference("CITIUS33XXX") == "CITIUS33XXX"
    assert validate_swift_reference("FT/26228/KZ70Q") == "FT/26228/KZ70Q"
    assert validate_swift_reference("AAIB-EG-2026") == "AAIB-EG-2026"
    assert validate_swift_reference(None) is None

    # Invalid characters in SWIFT reference
    with pytest.raises(HTTPException):
        validate_swift_reference("SWIFT@INVALID#123")


# ---------------------------------------------------------------------------
# Unit Tests: BankForm4Service CRUD & Business Logic
# ---------------------------------------------------------------------------
def test_create_bank_form4_record(db):
    service = BankForm4Service(db)
    payload = BankForm4Create(
        import_file_id=101,
        bank_id=1,
        bank_name="Commercial International Bank (CIB)",
        bank_branch="Smart Village",
        bank_officer_name="Ahmed Ezzat",
        financing_mode="CAD",
        currency="USD",
        fx_amount=45000.0,
        fx_allotment_status="ALLOTTED",
        swift_reference="FT/26228/KZ70Q",
        form4_number="F4-2026-9901",
        form4_issue_date=date(2026, 4, 15),
        nafeza_transmission_status="AWAITING_BANK",
        bank_delay_days=3,
        daily_financing_cost=150.0,
        notes="Urgent processing required",
    )

    record = service.create_record(payload, current_user="accountant1")
    assert record.form4_id is not None
    assert record.import_file_code == "IMP-2026-0001"
    assert record.fx_amount == 45000.0
    assert record.total_financing_delay_cost == 450.0  # 3 days * 150.0
    assert record.created_by == "accountant1"


def test_create_bank_form4_duplicate_form4_number(db):
    service = BankForm4Service(db)
    payload1 = BankForm4Create(
        import_file_id=101,
        bank_name="CIB",
        financing_mode="LC",
        currency="EUR",
        fx_amount=20000.0,
        form4_number="F4-UNIQUE-01",
    )
    service.create_record(payload1)

    payload2 = BankForm4Create(
        import_file_id=101,
        bank_name="NBE",
        financing_mode="LC",
        currency="EUR",
        fx_amount=10000.0,
        form4_number="F4-UNIQUE-01",
    )
    with pytest.raises(HTTPException) as exc:
        service.create_record(payload2)
    assert exc.value.status_code == 409


def test_query_bank_form4_records(db):
    service = BankForm4Service(db)
    payload = BankForm4Create(
        import_file_id=101,
        bank_name="Bank of Alexandria",
        financing_mode="OPEN_ACCOUNT",
        currency="USD",
        fx_amount=15000.0,
        form4_number="F4-QUERY-01",
    )
    rec = service.create_record(payload)

    # By ID
    loaded = service.get_record(rec.form4_id)
    assert loaded.form4_id == rec.form4_id

    # By Form 4 Number
    loaded_by_num = service.get_record_by_form4_number("F4-QUERY-01")
    assert loaded_by_num.form4_id == rec.form4_id

    # By Import File ID
    files_list = service.get_records_by_file(101)
    assert len(files_list) >= 1
    assert files_list[0].import_file_id == 101

    # List & Search
    items, total = service.list_records(search="Alexandria")
    assert total == 1
    assert items[0].bank_name == "Bank of Alexandria"


def test_calculate_financing_delay_cost(db):
    service = BankForm4Service(db)
    payload = BankForm4Create(
        import_file_id=101,
        bank_name="CIB",
        financing_mode="CAD",
        currency="USD",
        fx_amount=100000.0,
        bank_delay_days=0,
        daily_financing_cost=0.0,
    )
    rec = service.create_record(payload)

    # 1. Calculation via direct daily financing cost
    calc1 = DelayCostCalculation(bank_delay_days=5, daily_financing_cost=250.0)
    updated1 = service.calculate_delay_costs(rec.form4_id, calc1)
    assert updated1.bank_delay_days == 5
    assert updated1.daily_financing_cost == 250.0
    assert updated1.total_financing_delay_cost == 1250.0  # 5 * 250

    # 2. Calculation via annual interest rate (e.g. 18.25% on 100,000 USD)
    # daily_cost = (100,000 * 0.1825) / 365 = 50.0
    calc2 = DelayCostCalculation(bank_delay_days=10, annual_interest_rate=18.25)
    updated2 = service.calculate_delay_costs(rec.form4_id, calc2)
    assert updated2.bank_delay_days == 10
    assert updated2.daily_financing_cost == 50.0
    assert updated2.total_financing_delay_cost == 500.0  # 10 * 50.0


def test_update_nafeza_transmission_state(db):
    service = BankForm4Service(db)
    rec = service.create_record(
        BankForm4Create(
            import_file_id=101,
            bank_name="QNB Alahli",
            financing_mode="CAD",
            currency="USD",
            fx_amount=30000.0,
            nafeza_transmission_status="AWAITING_BANK",
        )
    )

    # 1. Bank transmits
    rec = service.update_nafeza_transmission(
        rec.form4_id,
        NafezaTransmissionUpdate(
            nafeza_transmission_status="TRANSMITTED",
            notes="Transmitted to Nafeza via Central Bank Gateway",
        ),
    )
    assert rec.nafeza_transmission_status == "TRANSMITTED"
    assert "Central Bank Gateway" in (rec.notes or "")

    # 2. Value mismatch reported
    rec = service.update_nafeza_transmission(
        rec.form4_id,
        NafezaTransmissionUpdate(
            nafeza_transmission_status="VALUE_MISMATCH",
            notes="Invoice shows 30,000 USD but customs declaration registered 30,500 USD",
        ),
    )
    assert rec.nafeza_transmission_status == "VALUE_MISMATCH"

    # 3. Discrepancy rectified and Form 4 officially accepted
    rec = service.update_nafeza_transmission(
        rec.form4_id,
        NafezaTransmissionUpdate(
            nafeza_transmission_status="ACCEPTED",
            form4_number="F4-NAFEZA-OK-2026",
            form4_issue_date=date(2026, 5, 2),
            notes="Accepted by Nafeza customs clearance team",
        ),
    )
    assert rec.nafeza_transmission_status == "ACCEPTED"
    assert rec.form4_number == "F4-NAFEZA-OK-2026"
    assert rec.form4_issue_date == date(2026, 5, 2)


def test_soft_delete_bank_form4(db):
    service = BankForm4Service(db)
    rec = service.create_record(
        BankForm4Create(
            import_file_id=101,
            bank_name="Banque Misr",
            financing_mode="ADVANCE",
            currency="USD",
            fx_amount=5000.0,
        )
    )
    form4_id = rec.form4_id
    service.delete_record(form4_id)

    with pytest.raises(HTTPException) as exc:
        service.get_record(form4_id)
    assert exc.value.status_code == 404


# ---------------------------------------------------------------------------
# Integration Tests: FastAPI Endpoints (/api/v1/bank-form4)
# ---------------------------------------------------------------------------
def test_bank_form4_api_endpoints(client):
    # 1. Create Form 4 record
    res = client.post(
        "/api/v1/bank-form4",
        json={
            "import_file_id": 101,
            "bank_name": "Commercial International Bank",
            "financing_mode": "CAD",
            "currency": "EUR",
            "fx_amount": 28000.0,
            "fx_allotment_status": "ALLOTTED",
            "swift_reference": "FT/26228/TEST",
            "form4_number": "F4-API-TEST-01",
        },
    )
    assert res.status_code == 201
    data = res.json()
    form4_id = data["form4_id"]
    assert data["form4_number"] == "F4-API-TEST-01"
    assert data["currency"] == "EUR"

    # 2. Get by ID
    res = client.get(f"/api/v1/bank-form4/{form4_id}")
    assert res.status_code == 200
    assert res.json()["form4_id"] == form4_id

    # 3. Get by File
    res = client.get("/api/v1/bank-form4/by-file/101")
    assert res.status_code == 200
    assert len(res.json()) >= 1

    # 4. Get by Number
    res = client.get("/api/v1/bank-form4/by-number/F4-API-TEST-01")
    assert res.status_code == 200
    assert res.json()["form4_id"] == form4_id

    # 5. Calculate Delay Cost
    res = client.post(
        f"/api/v1/bank-form4/{form4_id}/calculate-delay-cost",
        json={"bank_delay_days": 4, "daily_financing_cost": 200.0},
    )
    assert res.status_code == 200
    assert res.json()["total_financing_delay_cost"] == 800.0

    # 6. Update Nafeza Transmission
    res = client.post(
        f"/api/v1/bank-form4/{form4_id}/nafeza-transmission",
        json={
            "nafeza_transmission_status": "ACCEPTED",
            "form4_number": "F4-API-TEST-01-ACC",
            "notes": "Transmission verified successfully",
        },
    )
    assert res.status_code == 200
    assert res.json()["nafeza_transmission_status"] == "ACCEPTED"
    assert res.json()["form4_number"] == "F4-API-TEST-01-ACC"

    # 7. Delete
    res = client.delete(f"/api/v1/bank-form4/{form4_id}")
    assert res.status_code == 204
