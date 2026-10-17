"""
Unit Tests for CL-03: Customs Duty Payment Receipt (تسجيل سداد الرسوم الجمركية بسداد / E-Finance)
Checklist Item #35 - Stage 7: Customs Clearance & Release (CL-03)
"""

import pytest
from datetime import datetime, timezone
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base, get_db
from main import app
from modules.import_files.model import ImportFile
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.customs_clearance.schemas import CustomsDutyPaymentSubmit
from modules.customs_clearance.service import record_customs_duty_payment_service
from modules.smart_tasks.model import SmartTask
from modules.notifications.model import SystemNotification
from fastapi import HTTPException
from pydantic import ValidationError


@pytest.fixture
def db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    test_client = TestClient(app)
    yield test_client
    app.dependency_overrides.clear()


@pytest.fixture
def sample_data(db_session):
    # Create sample Import File ready for CL-03
    imp_file = ImportFile(
        import_file_code="IMP-2026-CL03",
        custom_file_number="FILE-CL03-5566",
        company_name="Alexandria Modern Polymers LLC",
        supplier_name="Sinopec Chemical Corp",
        current_module="Phase 7 - Customs Clearance",
        current_stage="Customs Duty Assessed (احتساب الرسوم الجمركية والمطالبة)",
        progress_percent=90.0,
        next_action="تسجيل سداد الرسوم الجمركية بسداد (CL-03)",
        form46_no="DEC-2026-ALX-7744",
        form46_date=datetime.now(timezone.utc),
        form46_status="REGISTERED",
        owner="Kamal",
        is_active=True,
    )
    db_session.add(imp_file)
    db_session.commit()
    db_session.refresh(imp_file)

    # Create existing clearance record from CL-02 with assessed duties
    record = CustomsClearanceRecord(
        clearance_code="CLR-2026-0003",
        import_file_id=imp_file.import_file_id,
        declaration_46_no="DEC-2026-ALX-7744",
        declaration_46_date=datetime.now(timezone.utc),
        customs_office_name="Alexandria Port Customs",
        channel_type="Yellow Channel",
        inspection_result="Conforming",
        is_sample_drawn=False,
        estimated_duty_total=180000.0,
        nafeza_claim_number="CLM-MTS-2026-885522",
        nafeza_claim_date=datetime.now(timezone.utc),
        cif_base_amount=750000.0,
        customs_exchange_rate=48.50,
        import_duty_amount=75000.0,
        vat_amount=115500.0,
        total_duty_payable=190500.0,
        actual_duty_total=190500.0,
        assessment_status="Assessed",
        status="Customs Duties Assessed - Ready for Payment",
        payment_status="Payment Requested",
        owner="Kamal",
        created_by="System",
        updated_by="System",
    )
    db_session.add(record)
    db_session.commit()
    db_session.refresh(record)

    # Create existing CL-03 SmartTask
    task_cl03 = SmartTask(
        task_code="TASK-CL03-001",
        import_file_id=imp_file.import_file_id,
        import_file_code=imp_file.import_file_code,
        title="تسجيل سداد الرسوم الجمركية عبر سداد / E-Finance (CL-03) — IMP-2026-CL03",
        description="صدرت المطالبة الجمركية رقم (CLM-MTS-2026-885522). يرجى سداد الرسوم عبر سداد وتوثيق الإيصال.",
        task_type="CUSTOMS_DUTY_PAYMENT",
        priority="Urgent",
        status="Pending",
        assigned_user="Customs Broker",
    )
    db_session.add(task_cl03)
    db_session.commit()

    return {
        "import_file": imp_file,
        "clearance_record": record,
        "task_cl03": task_cl03,
    }


def test_record_customs_duty_payment_service_success(db_session, sample_data):
    """Test successful CL-03 duty payment recording, file synchronization, task progression, and notification."""
    imp_file = sample_data["import_file"]
    pay_dt = datetime(2026, 9, 18, 15, 0, 0, tzinfo=timezone.utc)

    payload = CustomsDutyPaymentSubmit(
        import_file_id=imp_file.import_file_id,
        bank_receipt_no="RCP-BM-2026-991122",
        sadad_number="SADAD-2026-MTS-882200",
        paying_bank_name="Banque Misr - Corporate Branch",
        payment_date=pay_dt,
        payment_method="Sadad / E-Finance",
        duty_paid_amount=190500.0,
        receipt_file_url="/uploads/customs_receipts/rcp_991122.pdf",
        payment_notes="تم التحويل المباشر عبر حساب الشركة ببنك مصر وتم تسوية المطالبة بنظام نافذة.",
    )

    record = record_customs_duty_payment_service(db_session, payload, user="TestBroker")

    # 1. Assert CustomsClearanceRecord Updated
    assert record.bank_receipt_no == "RCP-BM-2026-991122"
    assert record.sadad_number == "SADAD-2026-MTS-882200"
    assert record.paying_bank_name == "Banque Misr - Corporate Branch"
    assert record.payment_method == "SADAD_EFINANCE"  # legacy label normalized to the enum code
    assert record.duty_paid_amount == 190500.0
    assert record.actual_duty_total == 190500.0
    assert record.payment_status == "Paid & Verified"
    assert record.status == "Duty Paid - Ready for Final Release"
    assert record.receipt_file_url == "/uploads/customs_receipts/rcp_991122.pdf"
    assert record.updated_by == "TestBroker"

    # 2. Assert ImportFile Synchronized
    db_session.refresh(imp_file)
    assert imp_file.customs_duty_paid_amount == 190500.0
    assert imp_file.customs_duty_receipt_no == "RCP-BM-2026-991122"
    assert imp_file.customs_duty_sadad_no == "SADAD-2026-MTS-882200"
    assert imp_file.customs_duty_payment_status == "PAID"
    assert imp_file.progress_percent >= 92.0
    assert "CL-04" in imp_file.next_action

    # 3. Assert CL-03 SmartTask Auto-Completed
    task_cl03 = db_session.query(SmartTask).filter(SmartTask.task_code == "TASK-CL03-001").first()
    assert task_cl03.status == "Completed"
    assert "SADAD-2026-MTS-882200" in task_cl03.notes
    assert "RCP-BM-2026-991122" in task_cl03.notes

    # 4. Assert Downstream CL-04 SmartTask Dispatched
    task_cl04 = (
        db_session.query(SmartTask)
        .filter(
            SmartTask.import_file_id == imp_file.import_file_id,
            SmartTask.task_type == "CUSTOMS_FINAL_RELEASE",
        )
        .first()
    )
    assert task_cl04 is not None
    assert "CL-04" in task_cl04.title
    assert "green customs release" in task_cl04.title
    assert task_cl04.status == "Pending"

    # 5. Assert SystemNotification Emitted
    notif = (
        db_session.query(SystemNotification)
        .filter(
            SystemNotification.entity_id == imp_file.import_file_id,
            SystemNotification.category == "STAGE_PROGRESSION",
        )
        .order_by(SystemNotification.notification_id.desc())
        .first()
    )
    assert notif is not None
    assert "Customs duties paid" in notif.title
    assert notif.msg_code == "CC_DUTIES_PAID"
    assert "SADAD-2026-MTS-882200" in notif.message


def test_record_customs_duty_payment_validation(db_session, sample_data):
    """Test validation rules for CL-03 duty payment."""
    imp_file = sample_data["import_file"]

    # 1. Non-existent file -> 404
    payload_404 = CustomsDutyPaymentSubmit(
        import_file_id=99999,
        bank_receipt_no="RCP-12345",
        sadad_number="SADAD-12345",
        paying_bank_name="CIB",
        duty_paid_amount=50000.0,
    )
    with pytest.raises(HTTPException) as exc_info:
        record_customs_duty_payment_service(db_session, payload_404)
    assert exc_info.value.status_code == 404

    # 2. Short Sadad number (< 3 chars) -> ValidationError
    with pytest.raises(ValidationError):
        CustomsDutyPaymentSubmit(
            import_file_id=imp_file.import_file_id,
            bank_receipt_no="RCP-12345",
            sadad_number="S1",
            paying_bank_name="CIB",
            duty_paid_amount=50000.0,
        )

    # 3. Non-positive amount -> ValidationError
    with pytest.raises(ValidationError):
        CustomsDutyPaymentSubmit(
            import_file_id=imp_file.import_file_id,
            bank_receipt_no="RCP-12345",
            sadad_number="SADAD-12345",
            paying_bank_name="CIB",
            duty_paid_amount=0.0,
        )


def test_record_duty_payment_api_endpoint(client, sample_data):
    """Test FastAPI router endpoint for CL-03."""
    imp_file = sample_data["import_file"]

    body = {
        "import_file_id": imp_file.import_file_id,
        "bank_receipt_no": "RCP-API-2026-7788",
        "sadad_number": "SADAD-API-2026-4433",
        "paying_bank_name": "Commercial International Bank (CIB)",
        "payment_date": "2026-09-18T15:30:00Z",
        "payment_method": "Sadad / E-Finance",
        "duty_paid_amount": 190500.0,
        "receipt_file_url": "/uploads/rcp_4433.pdf",
        "payment_notes": "سداد إلكتروني ناجح ومطابقة كاملة.",
    }

    res = client.post("/api/v1/customs-clearance/record-duty-payment", json=body)
    assert res.status_code == 200, res.text
    data = res.json()
    assert data["bank_receipt_no"] == "RCP-API-2026-7788"
    assert data["sadad_number"] == "SADAD-API-2026-4433"
    assert data["paying_bank_name"] == "CIB"  # known bank label normalized to its code
    assert data["duty_paid_amount"] == 190500.0
    assert data["payment_status"] == "Paid & Verified"
    assert data["status"] == "Duty Paid - Ready for Final Release"


def test_unassessed_duty_payment_flow_and_claim_put_ignored(client, db_session):
    """BE67-T06: payment is 409 until CL-02 actually ran; PUT nafeza_claim_number is ignored."""
    imp_file = ImportFile(
        import_file_code="IMP-2026-UNASSESSED",
        company_name="Alexandria Modern Polymers LLC",
        supplier_name="Sinopec Chemical Corp",
        current_module="Phase 7 - Customs Clearance",
        is_active=True,
    )
    db_session.add(imp_file)
    db_session.commit()
    db_session.refresh(imp_file)

    # 1. Create clearance record directly with components (1000 duty + 140 vat = 1140 total)
    create_payload = {
        "import_file_id": imp_file.import_file_id,
        "declaration_46_no": "DEC-2026-UNASS-1",
        "import_duty_amount": 1000.0,
        "vat_amount": 140.0,
    }
    create_res = client.post("/api/v1/customs-clearance", json=create_payload)
    assert create_res.status_code == 201, create_res.text
    clearance_id = create_res.json()["customs_clearance_id"]
    assert create_res.json()["total_duty_payable"] == 1140.0

    # 2. Attempt payment before CL-02 -> 409 CC_DUTY_NOT_ASSESSED
    pay_payload = {
        "import_file_id": imp_file.import_file_id,
        "bank_receipt_no": "RCP-9988",
        "sadad_number": "SADAD-9988",
        "paying_bank_name": "CIB",
        "duty_paid_amount": 1140.0,
    }
    pay_res = client.post("/api/v1/customs-clearance/record-duty-payment", json=pay_payload)
    assert pay_res.status_code == 409, pay_res.text
    assert pay_res.json()["detail"]["code"] == "CC_DUTY_NOT_ASSESSED"

    # 3. PUT with nafeza_claim_number is ignored (record still unassessed)
    put_res = client.put(f"/api/v1/customs-clearance/{clearance_id}", json={"nafeza_claim_number": "NFZ-HACK-01"})
    assert put_res.status_code == 200, put_res.text
    assert put_res.json().get("nafeza_claim_number") is None

    # Payment still fails with 409
    pay_res2 = client.post("/api/v1/customs-clearance/record-duty-payment", json=pay_payload)
    assert pay_res2.status_code == 409
    assert pay_res2.json()["detail"]["code"] == "CC_DUTY_NOT_ASSESSED"

    # 4. Run CL-02 assess-final-duties with nafeza_claim_number="NFZ-123"
    cl02_payload = {
        "import_file_id": imp_file.import_file_id,
        "nafeza_claim_number": "NFZ-123",
        "cif_base_amount": 10000.0,
        "import_duty_amount": 1000.0,
        "vat_amount": 140.0,
    }
    cl02_res = client.post("/api/v1/customs-clearance/assess-final-duties", json=cl02_payload)
    assert cl02_res.status_code == 200, cl02_res.text
    assert cl02_res.json()["nafeza_claim_number"] == "NFZ-123"
    assert cl02_res.json()["actual_duty_total"] == 1140.0

    # 5. Payment now succeeds
    pay_res3 = client.post("/api/v1/customs-clearance/record-duty-payment", json=pay_payload)
    assert pay_res3.status_code == 200, pay_res3.text
    assert pay_res3.json()["payment_status"] == "Paid & Verified"


def test_negative_money_and_bad_rate_validation_endpoints(client, sample_data):
    """BE67-T06: negative money and non-positive exchange rate are rejected with 422 on create and PUT."""
    imp_file = sample_data["import_file"]
    record = sample_data["clearance_record"]

    # POST create negative money -> 422
    res_neg_vat = client.post("/api/v1/customs-clearance", json={
        "import_file_id": imp_file.import_file_id,
        "vat_amount": -5.0,
    })
    assert res_neg_vat.status_code == 422

    # POST create exchange_rate <= 0 -> 422
    res_zero_rate = client.post("/api/v1/customs-clearance", json={
        "import_file_id": imp_file.import_file_id,
        "customs_exchange_rate": 0.0,
    })
    assert res_zero_rate.status_code == 422

    # PUT negative money -> 422
    res_put_neg = client.put(f"/api/v1/customs-clearance/{record.customs_clearance_id}", json={
        "vat_amount": -5.0,
    })
    assert res_put_neg.status_code == 422

    # PUT exchange_rate <= 0 -> 422
    res_put_rate = client.put(f"/api/v1/customs-clearance/{record.customs_clearance_id}", json={
        "customs_exchange_rate": -1.0,
    })
    assert res_put_rate.status_code == 422

