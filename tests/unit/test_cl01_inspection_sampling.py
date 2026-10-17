"""
Unit Tests for CL-01: Inspection & Samples GOEIC Report (تسجيل الكشف والمعاينة وسحب العينات ومطابقة الرقابة)
Checklist Item #33 - Stage 7: Customs Clearance & Release (CL-01)
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
from modules.customs_clearance.schemas import CustomsInspectionSamplingSubmit
from modules.customs_clearance.service import record_customs_inspection_sampling_service
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
    # Create sample Import File ready for CL-01
    imp_file = ImportFile(
        import_file_code="IMP-2026-CL01",
        custom_file_number="FILE-CL01-4455",
        company_name="Alexandria Chemicals Ltd",
        supplier_name="Global Chem Corp",
        current_module="Phase 7 - Customs Clearance",
        current_stage="Under Customs Clearance (تحت التخليص والكشف 46)",
        progress_percent=86.0,
        next_action="تسجيل الكشف والمعاينة وسحب العينات (CL-01)",
        form46_no="DEC-2026-ALX-9988",
        form46_date=datetime.now(timezone.utc),
        form46_status="REGISTERED",
        owner="Kamal",
        is_active=True,
    )
    db_session.add(imp_file)
    db_session.commit()
    db_session.refresh(imp_file)

    # Create existing clearance record from CS-03
    record = CustomsClearanceRecord(
        clearance_code="CLR-2026-0001",
        import_file_id=imp_file.import_file_id,
        declaration_46_no="DEC-2026-ALX-9988",
        declaration_46_date=datetime.now(timezone.utc),
        customs_office_name="Alexandria Port Customs",
        channel_type="Red Channel",
        regulatory_bodies=["GOEIC", "Food Safety Authority"],
        status="Under Customs Clearance",
        owner="Kamal",
        created_by="System",
        updated_by="System",
    )
    db_session.add(record)
    db_session.commit()
    db_session.refresh(record)

    # Create existing CL-01 SmartTask
    task_cl01 = SmartTask(
        task_code="TASK-CL01-001",
        import_file_id=imp_file.import_file_id,
        import_file_code=imp_file.import_file_code,
        title="تسجيل الكشف والمعاينة وسحب العينات (CL-01) — IMP-2026-CL01",
        description="يرجى البدء في إجراءات المعاينة الميدانية وسحب العينات لجهات العرض المحددة.",
        task_type="CUSTOMS_INSPECTION_SAMPLING",
        priority="High",
        status="Pending",
        assigned_user="Customs Broker",
    )
    db_session.add(task_cl01)
    db_session.commit()

    return {
        "import_file": imp_file,
        "clearance_record": record,
        "task_cl01": task_cl01,
    }


def test_record_customs_inspection_sampling_service_success(db_session, sample_data):
    """Test successful Customs Inspection & Sampling service logic."""
    imp_file = sample_data["import_file"]
    insp_dt = datetime(2026, 9, 18, 11, 0, 0, tzinfo=timezone.utc)
    smp_dt = datetime(2026, 9, 18, 11, 30, 0, tzinfo=timezone.utc)

    payload = CustomsInspectionSamplingSubmit(
        import_file_id=imp_file.import_file_id,
        inspection_date=insp_dt,
        inspection_type="Physical & Sampling",
        inspection_yard="ساحة الفحص المشترك - رصيف 42",
        inspector_name="م. إبراهيم خليل - رئيس لجنة الفحص",
        inspection_result="Conforming",
        is_sample_drawn=True,
        sampling_date=smp_dt,
        sampling_record_no="SMP-2026-ALX-8822",
        sample_test_status="Samples Under Testing",
        sampled_regulatory_bodies=["GOEIC", "Radiation Safety"],
        goeic_certificate_no="GOEIC-INSP-2026-5544",
        lab_service_fees=1250.0,
        inspection_notes="تمت المعاينة ومطابقة الأختام وسحب عدد 3 عينات للتحليل المعملي.",
    )

    record = record_customs_inspection_sampling_service(db_session, payload, user="TestBroker")

    # Assert Clearance Record Updated
    assert record.inspection_type == "Physical & Sampling"
    assert record.inspection_yard == "ساحة الفحص المشترك - رصيف 42"
    assert record.inspector_name == "م. إبراهيم خليل - رئيس لجنة الفحص"
    assert record.inspection_result == "Conforming"
    assert record.is_sample_drawn is True
    assert record.sampling_record_no == "SMP-2026-ALX-8822"
    assert record.sample_test_status == "Samples Under Testing"
    assert record.sampled_regulatory_bodies == ["GOEIC", "Radiation Safety"]
    assert record.goeic_certificate_no == "GOEIC-INSP-2026-5544"
    assert record.lab_service_fees == 1250.0
    assert record.status == "Inspection & Sampling Recorded"
    assert record.updated_by == "TestBroker"

    # Assert ImportFile Synchronized
    db_session.refresh(imp_file)
    assert "STEP_1" in imp_file.current_module or "Customs" in imp_file.current_module or "Inspection" in imp_file.current_module
    assert imp_file.progress_percent >= 88.0
    assert "CL-02" in imp_file.next_action

    # Assert CL-01 SmartTask Auto-Completed
    task_cl01 = db_session.query(SmartTask).filter(SmartTask.task_code == "TASK-CL01-001").first()
    assert task_cl01.status == "Completed"
    assert "SMP-2026-ALX-8822" in task_cl01.notes

    # Assert Downstream CL-02 SmartTask Dispatched
    task_cl02 = (
        db_session.query(SmartTask)
        .filter(
            SmartTask.import_file_id == imp_file.import_file_id,
            SmartTask.task_type == "FINAL_DUTY_ASSESSMENT",
        )
        .first()
    )
    assert task_cl02 is not None
    assert "CL-02" in task_cl02.title
    assert task_cl02.status == "Pending"

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
    assert "Inspection & sampling recorded" in notif.title
    assert notif.msg_code == "CC_INSPECTION_RECORDED"


@pytest.mark.parametrize(
    "sent,stored",
    [
        ("ساحة الفحص المشترك - ميناء الدخيلة", "DEKHEILA"),  # legacy Arabic yard name from old clients
        ("OCTOBER_DRY_PORT", "OCTOBER_DRY_PORT"),  # new clients send the code
        ("Private bonded yard 7", "Private bonded yard 7"),  # free text stays as typed
        (None, "Joint Inspection Yard"),  # no yard -> English fallback
    ],
)
def test_inspection_yard_is_stored_as_code(db_session, sample_data, sent, stored):
    payload = CustomsInspectionSamplingSubmit(
        import_file_id=sample_data["import_file"].import_file_id,
        inspection_yard=sent,
        inspection_result="Conforming",
        is_sample_drawn=False,
    )
    record = record_customs_inspection_sampling_service(db_session, payload, user="TestBroker")
    assert record.inspection_yard == stored


def test_record_customs_inspection_sampling_validation_errors(db_session, sample_data):
    """Test validation errors for CL-01."""
    imp_file = sample_data["import_file"]

    # 1. Non-existent file -> 404
    payload_404 = CustomsInspectionSamplingSubmit(
        import_file_id=99999,
        inspection_result="Conforming",
        inspection_type="Physical & Sampling",
    )
    with pytest.raises(HTTPException) as exc_info:
        record_customs_inspection_sampling_service(db_session, payload_404)
    assert exc_info.value.status_code == 404

    # 2. Short sampling record no -> 400
    payload_short = CustomsInspectionSamplingSubmit(
        import_file_id=imp_file.import_file_id,
        inspection_result="Conforming",
        is_sample_drawn=True,
        sampling_record_no="SM",
    )
    with pytest.raises(HTTPException) as exc_info2:
        record_customs_inspection_sampling_service(db_session, payload_short)
    assert exc_info2.value.status_code == 400
    assert "3 أحرف/أرقام" in exc_info2.value.detail

    # 3. Missing sampling record no when sample drawn -> 400 (no invented SMP- generator)
    payload_missing_smp = CustomsInspectionSamplingSubmit(
        import_file_id=imp_file.import_file_id,
        inspection_result="Conforming",
        is_sample_drawn=True,
        sampling_record_no=None,
    )
    with pytest.raises(HTTPException) as exc_info3:
        record_customs_inspection_sampling_service(db_session, payload_missing_smp)
    assert exc_info3.value.status_code == 400
    assert "رقم محضر سحب العينات مطلوب عند سحب عينات." in exc_info3.value.detail


def test_record_inspection_sampling_api_endpoint(client, sample_data):
    """Test FastAPI router endpoint for CL-01."""
    imp_file = sample_data["import_file"]

    body = {
        "import_file_id": imp_file.import_file_id,
        "inspection_date": "2026-09-18T12:00:00Z",
        "inspection_type": "Physical & Sampling",
        "inspection_yard": "ساحة الفحص المشترك بميناء الدخيلة",
        "inspector_name": "لجنة الرقابة الجمركية المشتركة",
        "inspection_result": "Conforming",
        "is_sample_drawn": True,
        "sampling_date": "2026-09-18T12:30:00Z",
        "sampling_record_no": "SMP-2026-DKH-3399",
        "sample_test_status": "Samples Under Testing",
        "sampled_regulatory_bodies": ["GOEIC", "مصلحة الكيمياء"],
        "goeic_certificate_no": "GOEIC-CER-9922",
        "lab_service_fees": 850.0,
        "inspection_notes": "المعاينة سليمة والطرود مطابقة للفاتورة وقائمة التعبئة.",
    }

    res = client.post("/api/v1/customs-clearance/record-inspection-sampling", json=body)
    assert res.status_code == 200, res.text
    data = res.json()
    assert data["inspection_type"] == "Physical & Sampling"
    assert data["inspection_yard"] == "ساحة الفحص المشترك بميناء الدخيلة"
    assert data["sampling_record_no"] == "SMP-2026-DKH-3399"
    assert data["goeic_certificate_no"] == "GOEIC-CER-9922"
    assert data["status"] == "Inspection & Sampling Recorded"


def test_cl01_api_missing_inspection_result_returns_422(client, sample_data):
    """Omitting inspection_result must fail Pydantic validation with 422."""
    imp_file = sample_data["import_file"]
    body = {
        "import_file_id": imp_file.import_file_id,
        "is_sample_drawn": False,
    }
    res = client.post("/api/v1/customs-clearance/record-inspection-sampling", json=body)
    assert res.status_code == 422


def test_cl01_api_sample_drawn_without_record_returns_400(client, sample_data):
    """When is_sample_drawn=True, missing sampling_record_no must return 400."""
    imp_file = sample_data["import_file"]
    body = {
        "import_file_id": imp_file.import_file_id,
        "inspection_result": "Conforming",
        "is_sample_drawn": True,
        "sampling_record_no": "",
    }
    res = client.post("/api/v1/customs-clearance/record-inspection-sampling", json=body)
    assert res.status_code == 400
    assert "رقم محضر سحب العينات مطلوب عند سحب عينات." in res.text
