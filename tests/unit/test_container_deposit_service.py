import pytest
from datetime import date, datetime, timedelta, timezone
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main
from database.database import Base, get_db
from modules.auth.router import get_current_user
from modules.import_files.model import ImportFile
from modules.users.model import User
from modules.container_deposit.model import ContainerDepositLedger
from modules.container_deposit.schemas import (
    ContainerDepositCreate,
    ContainerDepositUpdate,
    RecordEIRReturnRequest,
    RecordDepositRefundRequest,
    DisputeDeductionRequest,
    ContainerCondition,
    DepositRefundStatus,
)
from modules.container_deposit.validators import (
    clean_container_number,
    validate_deposit_amount,
    validate_eir_submission,
    validate_refund_submission,
)
from modules.container_deposit.service import ContainerDepositService

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
        imp_file = ImportFile(
            import_file_id=1,
            import_file_code="IMP-2026-CONT-01",
            company_name="Alexandria Fibers Co.",
            supplier_name="Sinopec Global",
            is_active=True,
            created_by="Tester",
        )
        db.add(imp_file)
        db.commit()
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

    mock_admin = User(
        user_id=1,
        username="admin_tester",
        email="admin@test.com",
        full_name="Admin Tester",
        role_id=1,
        is_active=True,
    )

    def override_get_current_user():
        return mock_admin

    main.app.dependency_overrides[get_db] = override_get_db
    main.app.dependency_overrides[get_current_user] = override_get_current_user

    with TestClient(main.app, headers={"X-User-Role": "ADMIN", "X-User-Name": "admin_tester"}) as c:
        yield c

    main.app.dependency_overrides.clear()


# ─── 1. Validation & Math Tests ──────────────────────────────────────────────

def test_container_number_and_deposit_amount_validators():
    assert clean_container_number(" mscu1234567 ") == "MSCU1234567"
    with pytest.raises(HTTPException) as exc:
        clean_container_number("  ")
    assert exc.value.status_code == 400

    validate_deposit_amount(25000.0)
    with pytest.raises(HTTPException) as exc2:
        validate_deposit_amount(0.0)
    assert exc2.value.status_code == 400

    with pytest.raises(HTTPException) as exc3:
        validate_deposit_amount(-500.0)
    assert exc3.value.status_code == 400


def test_eir_submission_validators():
    pay_date = date(2026, 8, 1)
    eir_date = date(2026, 8, 15)

    # Valid sound clean
    validate_eir_submission("EIR-101", eir_date, pay_date, "SOUND_CLEAN", 0.0, 20000.0)

    # Empty EIR number
    with pytest.raises(HTTPException) as exc:
        validate_eir_submission("", eir_date, pay_date, "SOUND_CLEAN", 0.0, 20000.0)
    assert exc.value.status_code == 400

    # EIR date before payment
    with pytest.raises(HTTPException) as exc2:
        validate_eir_submission("EIR-101", date(2026, 7, 20), pay_date, "SOUND_CLEAN", 0.0, 20000.0)
    assert exc2.value.status_code == 400

    # Sound clean with deduction > 0
    with pytest.raises(HTTPException) as exc3:
        validate_eir_submission("EIR-101", eir_date, pay_date, "SOUND_CLEAN", 1500.0, 20000.0)
    assert exc3.value.status_code == 400

    # Deduction exceeding deposit amount
    with pytest.raises(HTTPException) as exc4:
        validate_eir_submission("EIR-101", eir_date, pay_date, "DAMAGE_CLAIMED", 25000.0, 20000.0)
    assert exc4.value.status_code == 400


def test_refund_submission_validators():
    eir_date = date(2026, 8, 15)
    refund_date = date(2026, 9, 5)

    # Valid
    validate_refund_submission(18500.0, 20000.0, 1500.0, refund_date, eir_date)

    # Negative or zero refund
    with pytest.raises(HTTPException) as exc:
        validate_refund_submission(0.0, 20000.0, 0.0, refund_date, eir_date)
    assert exc.value.status_code == 400

    # Refund date before EIR return date
    with pytest.raises(HTTPException) as exc2:
        validate_refund_submission(20000.0, 20000.0, 0.0, date(2026, 8, 10), eir_date)
    assert exc2.value.status_code == 400

    # Refund exceeding deposit
    with pytest.raises(HTTPException) as exc3:
        validate_refund_submission(22000.0, 20000.0, 0.0, refund_date, eir_date)
    assert exc3.value.status_code == 400


# ─── 2. Service Level Deposit Lifecycle Tests ────────────────────────────────

def test_create_and_get_container_deposit(db_session):
    today = date.today()
    payload = ContainerDepositCreate(
        import_file_id=1,
        carrier_name="Mediterranean Shipping Company (MSC)",
        container_number="MSCU7766554",
        container_type="40ft High Cube",
        deposit_amount_egp=25000.0,
        payment_reference="CHQ-MSC-9901",
        payment_date=today,
    )

    deposit = ContainerDepositService.create_deposit(db_session, payload, user="Accountant")
    assert deposit.deposit_id is not None
    assert deposit.container_number == "MSCU7766554"
    assert deposit.deposit_amount_egp == 25000.0
    assert deposit.refund_status == "PENDING_RETURN"
    assert deposit.days_overdue == 0
    assert deposit.is_active is True

    fetched = ContainerDepositService.get_deposit(db_session, deposit.deposit_id)
    assert fetched.deposit_id == deposit.deposit_id


def test_list_and_filter_container_deposits(db_session):
    today = date.today()
    ContainerDepositService.create_deposit(
        db_session,
        ContainerDepositCreate(
            import_file_id=1,
            carrier_name="Maersk Line",
            container_number="MAEU1122334",
            container_type="20ft Standard",
            deposit_amount_egp=15000.0,
            payment_date=today,
        ),
    )

    items, total = ContainerDepositService.list_deposits(db_session, carrier_name="Maersk")
    assert total >= 1
    assert any(i.container_number == "MAEU1122334" for i in items)


def test_update_and_soft_delete_deposit(db_session):
    today = date.today()
    deposit = ContainerDepositService.create_deposit(
        db_session,
        ContainerDepositCreate(
            import_file_id=1,
            carrier_name="CMA CGM",
            container_number="CMAU5566778",
            container_type="40ft High Cube",
            deposit_amount_egp=30000.0,
            payment_date=today,
        ),
    )

    updated = ContainerDepositService.update_deposit(
        db_session,
        deposit.deposit_id,
        ContainerDepositUpdate(notes="Security deposit transferred via CIB bank voucher"),
        user="Tester",
    )
    assert "CIB bank voucher" in updated.notes

    deleted = ContainerDepositService.soft_delete_deposit(db_session, deposit.deposit_id, user="Tester")
    assert deleted.is_active is False

    with pytest.raises(HTTPException) as exc:
        ContainerDepositService.get_deposit(db_session, deposit.deposit_id)
    assert exc.value.status_code == 404


# ─── 3. 30-Day Statutory Overdue Alert & EIR Logic ───────────────────────────

def test_eir_return_and_30_day_overdue_rule(db_session):
    # Deposit paid 50 days ago
    pay_date = date.today() - timedelta(days=50)
    deposit = ContainerDepositService.create_deposit(
        db_session,
        ContainerDepositCreate(
            import_file_id=1,
            carrier_name="Hapag-Lloyd",
            container_number="HLXU3344556",
            container_type="40ft High Cube",
            deposit_amount_egp=28000.0,
            payment_date=pay_date,
        ),
    )

    # 1. Returned 10 days ago (within 30 days)
    eir_recent = date.today() - timedelta(days=10)
    req1 = RecordEIRReturnRequest(
        eir_return_number="EIR-HL-9922",
        eir_return_date=eir_recent,
        container_condition=ContainerCondition.SOUND_CLEAN,
    )
    dep_recent = ContainerDepositService.record_eir_return(db_session, deposit.deposit_id, req1)
    assert dep_recent.refund_status == "CLAIM_SUBMITTED"
    assert dep_recent.days_overdue == 0

    # 2. Returned 45 days ago (Overdue by 15 days because 45 - 30 = 15)
    eir_old = date.today() - timedelta(days=45)
    req2 = RecordEIRReturnRequest(
        eir_return_number="EIR-HL-OLD",
        eir_return_date=eir_old,
        container_condition=ContainerCondition.SOUND_CLEAN,
    )
    dep_overdue = ContainerDepositService.record_eir_return(db_session, deposit.deposit_id, req2)
    assert dep_overdue.refund_status == "OVERDUE_30_DAYS"
    assert dep_overdue.days_overdue == 15


def test_refund_recording_full_and_partial(db_session):
    today = date.today()
    # Case A: Full Refund
    deposit_a = ContainerDepositService.create_deposit(
        db_session,
        ContainerDepositCreate(
            import_file_id=1,
            carrier_name="ONE Line",
            container_number="ONEU8899001",
            container_type="20ft Standard",
            deposit_amount_egp=18000.0,
            payment_date=today - timedelta(days=20),
        ),
    )
    ContainerDepositService.record_eir_return(
        db_session,
        deposit_a.deposit_id,
        RecordEIRReturnRequest(
            eir_return_number="EIR-ONE-01",
            eir_return_date=today - timedelta(days=10),
            container_condition=ContainerCondition.SOUND_CLEAN,
        ),
    )
    ref_a = ContainerDepositService.record_refund(
        db_session,
        deposit_a.deposit_id,
        RecordDepositRefundRequest(
            refund_cheque_or_transfer_no="TRF-ONE-8877",
            refund_received_date=today,
            refund_amount_egp=18000.0,
        ),
    )
    assert ref_a.refund_status == "REFUNDED_FULL"
    assert ref_a.days_overdue == 0

    # Case B: Partial Refund with Damage deduction
    deposit_b = ContainerDepositService.create_deposit(
        db_session,
        ContainerDepositCreate(
            import_file_id=1,
            carrier_name="ONE Line",
            container_number="ONEU8899002",
            container_type="40ft High Cube",
            deposit_amount_egp=25000.0,
            payment_date=today - timedelta(days=20),
        ),
    )
    ContainerDepositService.record_eir_return(
        db_session,
        deposit_b.deposit_id,
        RecordEIRReturnRequest(
            eir_return_number="EIR-ONE-02",
            eir_return_date=today - timedelta(days=10),
            container_condition=ContainerCondition.DAMAGE_CLAIMED,
            deduction_amount_egp=3500.0,
            deduction_reason="Dent on side panel",
        ),
    )
    ref_b = ContainerDepositService.record_refund(
        db_session,
        deposit_b.deposit_id,
        RecordDepositRefundRequest(
            refund_cheque_or_transfer_no="TRF-ONE-8878",
            refund_received_date=today,
            refund_amount_egp=21500.0,
        ),
    )
    assert ref_b.refund_status == "REFUNDED_PARTIAL"
    assert ref_b.deduction_amount_egp == 3500.0


def test_dispute_deduction_and_waiver(db_session):
    today = date.today()
    deposit = ContainerDepositService.create_deposit(
        db_session,
        ContainerDepositCreate(
            import_file_id=1,
            carrier_name="Evergreen",
            container_number="EGLV1234567",
            container_type="40ft High Cube",
            deposit_amount_egp=26000.0,
            payment_date=today - timedelta(days=15),
        ),
    )
    ContainerDepositService.record_eir_return(
        db_session,
        deposit.deposit_id,
        RecordEIRReturnRequest(
            eir_return_number="EIR-EVG-01",
            eir_return_date=today - timedelta(days=5),
            container_condition=ContainerCondition.CLEANING_FEE_DEDUCTED,
            deduction_amount_egp=2000.0,
        ),
    )
    assert deposit.deduction_amount_egp == 2000.0

    # 1. Dispute revised
    rev_res = ContainerDepositService.dispute_deduction(
        db_session,
        deposit.deposit_id,
        DisputeDeductionRequest(
            dispute_reason="Floor was swept clean prior to return",
            revised_deduction_amount_egp=800.0,
        ),
        user="OperationsLead",
    )
    assert rev_res.deduction_amount_egp == 800.0
    assert len(rev_res.dispute_history) == 1

    # 2. Dispute waived by carrier
    waived_res = ContainerDepositService.dispute_deduction(
        db_session,
        deposit.deposit_id,
        DisputeDeductionRequest(
            dispute_reason="Carrier accepted inspection photos and waived charge",
            waived=True,
        ),
        user="OperationsLead",
    )
    assert waived_res.deduction_amount_egp == 0.0
    assert waived_res.container_condition == "SOUND_CLEAN"
    assert len(waived_res.dispute_history) == 2


def test_overview_and_alerts_service(db_session):
    today = date.today()
    # 1 Overdue
    dep1 = ContainerDepositService.create_deposit(
        db_session,
        ContainerDepositCreate(
            import_file_id=1,
            carrier_name="Yang Ming",
            container_number="YMLU1111111",
            container_type="20ft Standard",
            deposit_amount_egp=15000.0,
            payment_date=today - timedelta(days=60),
        ),
    )
    ContainerDepositService.record_eir_return(
        db_session,
        dep1.deposit_id,
        RecordEIRReturnRequest(
            eir_return_number="EIR-YM-01",
            eir_return_date=today - timedelta(days=40),
        ),
    )

    overview = ContainerDepositService.get_overview_and_alerts(db_session, as_of_date=today)
    assert overview.total_active_deposits >= 1
    assert overview.overdue_30_days_count >= 1
    assert overview.overdue_deposit_amount_egp >= 15000.0
    assert len(overview.alerts) >= 1
    assert "Yang Ming" in overview.carrier_breakdown


# ─── 4. REST API Endpoint Integration Tests ──────────────────────────────────

def test_container_deposit_rest_api_full_journey(client):
    today = date.today().isoformat()
    pay_date = (date.today() - timedelta(days=35)).isoformat()
    eir_date = (date.today() - timedelta(days=32)).isoformat()

    create_payload = {
        "import_file_id": 1,
        "carrier_name": "Cosco Shipping Lines",
        "container_number": "COSU9988776",
        "container_type": "40ft High Cube",
        "deposit_amount_egp": 32000.0,
        "payment_reference": "VOUCH-COSCO-2026",
        "payment_date": pay_date,
        "notes": "تأمين حاوية شحنة كيماويات بميناء السخنة",
    }

    # 1. POST Create
    post_res = client.post("/api/v1/container-deposit", json=create_payload)
    assert post_res.status_code == 201
    dep_data = post_res.json()
    dep_id = dep_data["deposit_id"]
    assert dep_data["refund_status"] == "PENDING_RETURN"

    # 2. GET by ID
    get_res = client.get(f"/api/v1/container-deposit/{dep_id}")
    assert get_res.status_code == 200
    assert get_res.json()["container_number"] == "COSU9988776"

    # 3. GET List with filter
    list_res = client.get("/api/v1/container-deposit?carrier_name=Cosco")
    assert list_res.status_code == 200
    assert list_res.json()["total"] >= 1

    # 4. Record EIR Return
    eir_res = client.post(
        f"/api/v1/container-deposit/{dep_id}/record-eir",
        json={
            "eir_return_number": "EIR-COS-8877",
            "eir_return_date": eir_date,
            "container_condition": "DAMAGE_CLAIMED",
            "deduction_amount_egp": 2500.0,
            "deduction_reason": "خدش بسيط بالباب",
        },
    )
    assert eir_res.status_code == 200
    # Overdue because 32 days > 30 days
    assert eir_res.json()["refund_status"] == "OVERDUE_30_DAYS"
    assert eir_res.json()["days_overdue"] == 2

    # 5. Dispute deduction
    disp_res = client.post(
        f"/api/v1/container-deposit/{dep_id}/dispute-deduction",
        json={
            "dispute_reason": "الخدش مسجل مسبقاً قبل استلام الحاوية",
            "waived": True,
        },
    )
    assert disp_res.status_code == 200
    assert disp_res.json()["deduction_amount_egp"] == 0.0

    # 6. Record Refund
    ref_res = client.post(
        f"/api/v1/container-deposit/{dep_id}/record-refund",
        json={
            "refund_cheque_or_transfer_no": "CHQ-COS-112233",
            "refund_received_date": today,
            "refund_amount_egp": 32000.0,
        },
    )
    assert ref_res.status_code == 200
    assert ref_res.json()["refund_status"] == "REFUNDED_FULL"

    # 7. GET Overdue Alerts
    alerts_res = client.get("/api/v1/container-deposit/alerts/overdue")
    assert alerts_res.status_code == 200
    assert "total_active_deposits" in alerts_res.json()

    # 8. DELETE Soft-delete
    del_res = client.delete(f"/api/v1/container-deposit/{dep_id}")
    assert del_res.status_code == 200
    assert del_res.json()["is_active"] is False
