"""
Unit Tests for CS-03: Customs Declaration 46 Registration (قيد الإقرار الجمركي ونموذج 46 ك.م)
Checklist Item #32 - Stage 6: Customs Preparation (46)
"""

import pytest
from datetime import datetime, timezone, timedelta
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base, get_db
from main import app
from modules.import_files.model import ImportFile
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.customs_clearance.schemas import CustomsDeclaration46Submit
from modules.customs_clearance.service import register_customs_declaration_46_service
from modules.smart_tasks.model import SmartTask
from modules.notifications.model import SystemNotification


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
    # Create sample Import File with DO paid
    imp_file = ImportFile(
        import_file_code="IMP-2026-CS03",
        custom_file_number="FILE-CS03-9988",
        company_name="El-Delta Petrochemicals",
        supplier_name="Global Polymers Ltd",
        current_module="Phase 6 - Customs Preparation",
        current_stage="Delivery Order Paid & Received (سداد إذن التسليم الملاحي)",
        progress_percent=83.0,
        next_action="قيد الإقرار الجمركي ونموذج 46 ك.م (CS-03)",
        delivery_order_no="DO-2026-MSK-7711",
        delivery_order_date=datetime.now(timezone.utc),
        delivery_order_status="PAID_AND_RECEIVED",
        owner="Kamal",
        is_active=True,
    )
    db_session.add(imp_file)
    db_session.commit()
    db_session.refresh(imp_file)

    # Create existing CS-03 SmartTask
    task_cs03 = SmartTask(
        task_code="TASK-CS03-001",
        import_file_id=imp_file.import_file_id,
        import_file_code=imp_file.import_file_code,
        title="قيد الإقرار الجمركي ونموذج 46 ك.م (CS-03) — IMP-2026-CS03",
        description="يرجى سرعة قيد وتثبيت الإقرار الجمركي ونموذج 46 ك.م عبر نافذة MTS.",
        task_type="CUSTOMS_DECLARATION_46",
        priority="High",
        status="Pending",
        assigned_user="Customs Broker",
    )
    db_session.add(task_cs03)
    db_session.commit()

    return {
        "import_file": imp_file,
        "task_cs03": task_cs03,
    }


def test_register_customs_declaration_46_service_success(db_session, sample_data):
    """Test successful Customs Declaration 46 registration service logic."""
    imp_file = sample_data["import_file"]
    dec_dt = datetime(2026, 9, 18, 10, 0, 0, tzinfo=timezone.utc)

    payload = CustomsDeclaration46Submit(
        import_file_id=imp_file.import_file_id,
        declaration_46_no="46-2026-ALX-98124",
        declaration_46_date=dec_dt,
        customs_office_name="Alexandria Port Customs",
        channel_type="Red Channel",
        regulatory_bodies=["GOEIC", "Food Safety Authority"],
        mts_certificate_number="MTS-2026-EG-44910",
        customs_tariff_items_count=3,
        inspection_notes="معاينة كاملة وسحب عينات للبندين 1 و 3",
    )

    record = register_customs_declaration_46_service(
        db=db_session,
        payload=payload,
        user="TestUser",
    )

    # 1. Verify CustomsClearanceRecord
    assert record is not None
    assert record.declaration_46_no == "46-2026-ALX-98124"
    assert record.declaration_46_date is not None
    assert record.customs_office_name == "Alexandria Port Customs"
    assert record.channel_type == "Red Channel"
    assert "GOEIC" in record.regulatory_bodies
    assert "NFSA" in record.regulatory_bodies  # T3: legacy label normalized to its code
    assert record.mts_certificate_number == "MTS-2026-EG-44910"
    assert record.customs_tariff_items_count == 3
    assert record.status == "Under Customs Clearance"
    assert record.updated_by == "TestUser"

    # 2. Verify ImportFile sync
    db_session.refresh(imp_file)
    assert imp_file.form46_no == "46-2026-ALX-98124"
    assert imp_file.form46_date is not None
    assert imp_file.form46_status == "REGISTERED"
    assert "STEP_14" in imp_file.current_module or "Customs" in imp_file.current_module
    assert imp_file.progress_percent >= 86.0
    assert "CL-01" in imp_file.next_action

    # 3. Verify CS-03 SmartTask completed
    completed_task = (
        db_session.query(SmartTask)
        .filter(
            SmartTask.import_file_id == imp_file.import_file_id,
            SmartTask.task_type == "CUSTOMS_DECLARATION_46",
        )
        .first()
    )
    assert completed_task.status == "Completed"
    assert "46-2026-ALX-98124" in completed_task.notes

    # 4. Verify downstream CL-01 SmartTask dispatched
    downstream_task = (
        db_session.query(SmartTask)
        .filter(
            SmartTask.import_file_id == imp_file.import_file_id,
            SmartTask.task_type == "CUSTOMS_INSPECTION_SAMPLING",
        )
        .first()
    )
    assert downstream_task is not None
    assert downstream_task.status == "Pending"
    assert "CL-01" in downstream_task.title
    assert "inspection" in downstream_task.title
    assert downstream_task.msg_code == "CC_TASK_INSPECTION"

    # 5. Verify Notification emitted
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
    assert "46-2026-ALX-98124" in notif.message


def test_register_customs_declaration_46_service_validation_errors(db_session, sample_data):
    """Test error handling and validation for CS-03 service."""
    imp_file = sample_data["import_file"]

    # 1. Invalid import_file_id
    with pytest.raises(Exception) as exc_info_404:
        register_customs_declaration_46_service(
            db=db_session,
            payload=CustomsDeclaration46Submit(
                import_file_id=99999,
                declaration_46_no="46-ALX-12345",
                customs_office_name="Alexandria Port Customs",
                channel_type="Red Channel",
            ),
        )
    assert "غير موجود" in str(exc_info_404.value)

    # 2. Short declaration 46 number (Pydantic schema validation)
    with pytest.raises(Exception) as exc_info_short:
        CustomsDeclaration46Submit(
            import_file_id=imp_file.import_file_id,
            declaration_46_no="46",
            customs_office_name="Alexandria Port Customs",
            channel_type="Red Channel",
        )
    assert "at least 3 characters" in str(exc_info_short.value)

    # 3. Short declaration 46 number (Service-level validation via model_construct)
    with pytest.raises(Exception) as exc_info_srv:
        register_customs_declaration_46_service(
            db=db_session,
            payload=CustomsDeclaration46Submit.model_construct(
                import_file_id=imp_file.import_file_id,
                declaration_46_no="46",
                customs_office_name="Alexandria Port Customs",
                channel_type="Red Channel",
                regulatory_bodies=[],
                mts_certificate_number=None,
                customs_tariff_items_count=1,
                inspection_notes=None,
            ),
        )
    assert "يقل عن 3" in str(exc_info_srv.value)


def test_api_register_customs_declaration_46_endpoint(client, sample_data):
    """Test API endpoint POST /api/v1/customs-clearance/register-declaration-46."""
    imp_file = sample_data["import_file"]

    payload = {
        "import_file_id": imp_file.import_file_id,
        "declaration_46_no": "46-2026-DKH-55441",
        "customs_office_name": "El Dekheila Port Customs",
        "channel_type": "Yellow Channel",
        "regulatory_bodies": ["GOEIC", "Chemistry Department"],
        "mts_certificate_number": "MTS-DKH-99221",
        "customs_tariff_items_count": 2,
        "inspection_notes": "فحص مستندي وتدقيق شهادة المنشأ",
    }

    response = client.post(
        "/api/v1/customs-clearance/register-declaration-46",
        json=payload,
    )

    assert response.status_code == 200, response.text
    data = response.json()
    assert data["declaration_46_no"] == "46-2026-DKH-55441"
    assert data["customs_office_name"] == "El Dekheila Port Customs"
    assert data["channel_type"] == "Yellow Channel"
    assert data["status"] == "Under Customs Clearance"
    assert "GOEIC" in data["regulatory_bodies"]
    assert data["customs_tariff_items_count"] == 2


def test_cs03_api_missing_channel_type_returns_422(client, sample_data):
    """Omitting channel_type must return 422 Unprocessable Entity."""
    imp_file = sample_data["import_file"]
    payload = {
        "import_file_id": imp_file.import_file_id,
        "declaration_46_no": "46-2026-DKH-55441",
        "customs_office_name": "El Dekheila Port Customs",
    }
    response = client.post(
        "/api/v1/customs-clearance/register-declaration-46",
        json=payload,
    )
    assert response.status_code == 422


def test_cs03_api_missing_customs_office_name_returns_422(client, sample_data):
    """Omitting customs_office_name must return 422 Unprocessable Entity."""
    imp_file = sample_data["import_file"]
    payload = {
        "import_file_id": imp_file.import_file_id,
        "declaration_46_no": "46-2026-DKH-55441",
        "channel_type": "Red Channel",
    }
    response = client.post(
        "/api/v1/customs-clearance/register-declaration-46",
        json=payload,
    )
    assert response.status_code == 422
