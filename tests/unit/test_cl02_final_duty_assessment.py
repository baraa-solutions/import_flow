"""
Unit Tests for CL-02: Final Duty & Tax Assessment (احتساب الرسوم والضرائب الجمركية النهائية)
Checklist Item #34 - Stage 7: Customs Clearance & Release (CL-02)
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
from modules.customs_clearance.schemas import FinalDutyAssessmentSubmit
from modules.customs_clearance.service import assess_final_customs_duties_service
from modules.smart_tasks.model import SmartTask
from modules.notifications.model import SystemNotification
from fastapi import HTTPException


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
    # Create sample Import File ready for CL-02
    imp_file = ImportFile(
        import_file_code="IMP-2026-CL02",
        custom_file_number="FILE-CL02-7788",
        company_name="Delta Industrial Machinery LLC",
        supplier_name="Bavaria Tech GmbH",
        current_module="Phase 7 - Customs Clearance & Inspection",
        current_stage="Customs Inspection & Sampling Completed (تم الكشف وسحب العينات)",
        progress_percent=88.0,
        next_action="احتساب الرسوم والضرائب الجمركية النهائية (CL-02)",
        form46_no="DEC-2026-DKH-5511",
        form46_date=datetime.now(timezone.utc),
        form46_status="REGISTERED",
        owner="Kamal",
        is_active=True,
    )
    db_session.add(imp_file)
    db_session.commit()
    db_session.refresh(imp_file)

    # Create existing clearance record from CL-01 with estimated duties
    record = CustomsClearanceRecord(
        clearance_code="CLR-2026-0002",
        import_file_id=imp_file.import_file_id,
        declaration_46_no="DEC-2026-DKH-5511",
        declaration_46_date=datetime.now(timezone.utc),
        customs_office_name="El Dekheila Port Customs",
        channel_type="Red Channel",
        inspection_result="Conforming",
        is_sample_drawn=True,
        sampling_record_no="SMP-2026-0002-88",
        sample_test_status="Samples Under Testing",
        estimated_duty_total=150000.0,
        status="Inspection & Sampling Recorded",
        owner="Kamal",
        created_by="System",
        updated_by="System",
    )
    db_session.add(record)
    db_session.commit()
    db_session.refresh(record)

    # Create existing CL-02 SmartTask
    task_cl02 = SmartTask(
        task_code="TASK-CL02-001",
        import_file_id=imp_file.import_file_id,
        import_file_code=imp_file.import_file_code,
        title="احتساب الرسوم والضرائب الجمركية النهائية (CL-02) — IMP-2026-CL02",
        description="يرجى مراجعة المطالبة الجمركية واحتساب الرسوم والضرائب الجمركية النهائية.",
        task_type="FINAL_DUTY_ASSESSMENT",
        priority="High",
        status="Pending",
        assigned_user="Customs Broker",
    )
    db_session.add(task_cl02)
    db_session.commit()

    return {
        "import_file": imp_file,
        "clearance_record": record,
        "task_cl02": task_cl02,
    }


def test_assess_final_customs_duties_service_success(db_session, sample_data):
    """Test successful Final Duty & Tax Assessment service logic and variance calculation."""
    imp_file = sample_data["import_file"]
    claim_dt = datetime(2026, 9, 18, 14, 0, 0, tzinfo=timezone.utc)

    # CIF base = 623,000 EGP
    # Import Duty = 62,300
    # VAT = 95,942
    # Schedule Tax = 6,230
    # Development Fee = 1,500
    # Customs Service Fees = 78,286.90
    # WHT = 2,500
    # Lab Fees = 1,200
    # Total = 247,958.90
    payload = FinalDutyAssessmentSubmit(
        import_file_id=imp_file.import_file_id,
        nafeza_claim_number="CLM-MTS-2026-987654",
        nafeza_claim_date=claim_dt,
        cif_base_amount=623000.0,
        customs_exchange_rate=48.50,
        import_duty_amount=62300.0,
        vat_amount=95942.0,
        schedule_tax_amount=6230.0,
        development_fee_amount=1500.0,
        customs_service_fees=78286.90,
        wht_amount=2500.0,
        lab_service_fees=1200.0,
        actual_duty_total=247958.90,
        duty_variance_reason="تعديل بند التعريفة وإضافة رسوم خدمات كشف بالأشعة",
        assessment_notes="تم التحقق من القيمة المقبولة جمركياً واعتماد كشف الحساب من مأمور التعريفة.",
    )

    record = assess_final_customs_duties_service(db_session, payload, user="TestAssessor")

    # Assert Clearance Record Updated
    assert record.nafeza_claim_number == "CLM-MTS-2026-987654"
    assert record.cif_base_amount == 623000.0
    assert record.customs_exchange_rate == 48.50
    assert record.import_duty_amount == 62300.0
    assert record.vat_amount == 95942.0
    assert record.schedule_tax_amount == 6230.0
    assert record.development_fee_amount == 1500.0
    assert record.customs_service_fees == 78286.90
    assert record.wht_amount == 2500.0
    assert record.lab_service_fees == 1200.0
    assert record.total_duty_payable == 247958.90
    assert record.actual_duty_total == 247958.90

    # Variance against estimated 150,000.0
    # Variance amount = 247,958.90 - 150,000.0 = 97,958.90
    # Variance pct = (97,958.90 / 150,000) * 100 = 65.31%
    assert record.duty_variance_amount == 97958.90
    assert record.duty_variance_percentage == 65.31
    assert record.duty_variance_reason == "تعديل بند التعريفة وإضافة رسوم خدمات كشف بالأشعة"
    assert record.assessment_status == "Assessed"
    assert record.status == "Customs Duties Assessed - Ready for Payment"
    assert record.updated_by == "TestAssessor"

    # Assert ImportFile Synchronized
    db_session.refresh(imp_file)
    assert imp_file.progress_percent >= 90.0
    assert "CL-03" in imp_file.next_action

    # Assert CL-02 SmartTask Auto-Completed
    task_cl02 = db_session.query(SmartTask).filter(SmartTask.task_code == "TASK-CL02-001").first()
    assert task_cl02.status == "Completed"
    assert "CLM-MTS-2026-987654" in task_cl02.notes

    # Assert Downstream CL-03 SmartTask Dispatched
    task_cl03 = (
        db_session.query(SmartTask)
        .filter(
            SmartTask.import_file_id == imp_file.import_file_id,
            SmartTask.task_type == "CUSTOMS_DUTY_PAYMENT",
        )
        .first()
    )
    assert task_cl03 is not None
    assert "CL-03" in task_cl03.title
    assert "Sadad" in task_cl03.title
    assert task_cl03.status == "Pending"

    # Assert SystemNotification Emitted
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
    assert "Customs duties and taxes assessed" in notif.title
    assert notif.msg_code == "CC_DUTIES_ASSESSED"
    assert "CLM-MTS-2026-987654" in notif.message


def test_assess_final_customs_duties_validation_and_auto_total(db_session, sample_data):
    """Test validation checks and auto-summation when actual_duty_total is not explicitly passed."""
    imp_file = sample_data["import_file"]

    # 1. Non-existent file -> 404
    payload_404 = FinalDutyAssessmentSubmit(
        import_file_id=99999,
        nafeza_claim_number="CLM-001",
        cif_base_amount=100000.0,
        import_duty_amount=10000.0,
        vat_amount=14000.0,
    )
    with pytest.raises(HTTPException) as exc_info:
        assess_final_customs_duties_service(db_session, payload_404)
    assert exc_info.value.status_code == 404

    # 2. Short claim number (<3 chars) raises Pydantic ValidationError
    from pydantic import ValidationError
    with pytest.raises(ValidationError):
        FinalDutyAssessmentSubmit(
            import_file_id=imp_file.import_file_id,
            nafeza_claim_number="C1",
            cif_base_amount=100000.0,
            import_duty_amount=10000.0,
            vat_amount=14000.0,
        )

    # 3. Auto-sum total if actual_duty_total is None
    payload_auto_sum = FinalDutyAssessmentSubmit(
        import_file_id=imp_file.import_file_id,
        nafeza_claim_number="CLM-AUTO-SUM-100",
        cif_base_amount=100000.0,
        import_duty_amount=5000.0,
        vat_amount=14700.0,
        schedule_tax_amount=1000.0,
        development_fee_amount=500.0,
        customs_service_fees=1200.0,
        wht_amount=800.0,
        lab_service_fees=300.0,
        actual_duty_total=None,
    )
    rec = assess_final_customs_duties_service(db_session, payload_auto_sum)
    # Expected sum = 5000 + 14700 + 1000 + 500 + 1200 + 800 + 300 = 23,500.0
    assert rec.total_duty_payable == 23500.0
    assert rec.actual_duty_total == 23500.0


def test_assess_final_duties_api_endpoint(client, sample_data):
    """Test FastAPI router endpoint for CL-02."""
    imp_file = sample_data["import_file"]

    body = {
        "import_file_id": imp_file.import_file_id,
        "nafeza_claim_number": "CLM-API-2026-0099",
        "nafeza_claim_date": "2026-09-18T14:30:00Z",
        "cif_base_amount": 500000.0,
        "customs_exchange_rate": 48.60,
        "import_duty_amount": 50000.0,
        "vat_amount": 77000.0,
        "schedule_tax_amount": 5000.0,
        "development_fee_amount": 1000.0,
        "customs_service_fees": 12500.0,
        "wht_amount": 2000.0,
        "lab_service_fees": 1500.0,
        "actual_duty_total": 149000.0,
        "duty_variance_reason": "فروق تقريبية طفيفة",
        "assessment_notes": "مطالبة معتمدة نهائياً من مصلحة الجمارك.",
    }

    res = client.post("/api/v1/customs-clearance/assess-final-duties", json=body)
    assert res.status_code == 200, res.text
    data = res.json()
    assert data["nafeza_claim_number"] == "CLM-API-2026-0099"
    assert data["cif_base_amount"] == 500000.0
    assert data["customs_exchange_rate"] == 48.60
    assert data["import_duty_amount"] == 50000.0
    assert data["vat_amount"] == 77000.0
    assert data["total_duty_payable"] == 149000.0
    assert data["status"] == "Customs Duties Assessed - Ready for Payment"
