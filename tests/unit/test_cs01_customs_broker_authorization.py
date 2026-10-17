"""
Unit Tests for CS-01: Customs Broker Electronic Authorization (تعيين المخلص الجمركي والتفويض الإلكتروني)
Checklist Item #30 - Stage 6: Customs Preparation (46)
"""

import pytest
from datetime import datetime, timezone, date
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base, get_db
from main import app
from modules.import_files.model import ImportFile
from modules.external_service_providers.model import ExternalServiceProvider
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.customs_clearance.schemas import CustomsBrokerAuthorizationSubmit
from modules.customs_clearance.service import authorize_customs_broker_service
from modules.smart_tasks.model import SmartTask
from modules.notifications.model import SystemNotification
from modules.lifecycle_board.model import ShipmentStageActivity


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
    # Create sample Import File
    imp_file = ImportFile(
        import_file_code="IMP-2026-CS01",
        custom_file_number="FILE-CS01-9988",
        company_name="Al-Amal Medical Supplies",
        supplier_name="Global Pharma Ltd",
        current_module="Phase 5 - Sailing & CargoX",
        current_stage="Original Documents Collected",
        progress_percent=75.0,
        next_action="تعيين المخلص الجمركي والتفويض الإلكتروني (CS-01)",
        owner="Kamal",
        is_active=True,
    )
    db_session.add(imp_file)

    # Create sample Customs Broker Provider
    broker = ExternalServiceProvider(
        partner_code="BRK-001",
        partner_name="شركة الأهرام للتخليص الجمركي والخدمات اللوجستية",
        partner_type="Customs Broker",
        tax_id="771-223-990",
        commercial_register="CR-ALEX-55441",
        clearance_license_number="LIC-ALEX-2026-0881",
        authorized_ports="Alexandria, El Dekheila, Port Said",
        is_active=True,
    )
    db_session.add(broker)

    db_session.commit()
    db_session.refresh(imp_file)
    db_session.refresh(broker)

    # Create existing CS-01 SmartTask
    task_cs01 = SmartTask(
        task_code="TASK-CS01-001",
        import_file_id=imp_file.import_file_id,
        import_file_code=imp_file.import_file_code,
        title="تعيين المخلص الجمركي والتفويض الإلكتروني (CS-01) — IMP-2026-CS01",
        description="يرجى تعيين المخلص الجمركي وإصدار التفويض الإلكتروني عبر منظومة نافذة.",
        task_type="CUSTOMS_BROKER_ASSIGNMENT",
        priority="High",
        status="Pending",
        assigned_user="Customs Specialist",
    )
    db_session.add(task_cs01)
    db_session.commit()
    db_session.refresh(task_cs01)

    return {
        "import_file": imp_file,
        "broker": broker,
        "task_cs01": task_cs01,
    }


def test_authorize_customs_broker_service_full_workflow(db_session, sample_data):
    """
    Test that authorize_customs_broker_service:
    1. Creates CustomsClearanceRecord with broker and delegation info.
    2. Synchronizes ImportFile broker info, delegation no, elevates progress to >= 80%, advances next_action.
    3. Auto-completes pending CS-01 smart task.
    4. Dispatches downstream CS-02 smart task (Delivery Order Payment).
    5. Emits SystemNotification.
    6. Advances lifecycle board to STEP_13.
    """
    imp_file = sample_data["import_file"]
    broker = sample_data["broker"]
    task_cs01 = sample_data["task_cs01"]

    payload = CustomsBrokerAuthorizationSubmit(
        import_file_id=imp_file.import_file_id,
        broker_id=broker.provider_id,
        delegation_number="DEL-2026-ALEX-01",
        customs_office_name="Alexandria Port Customs",
        authorization_notes="تم إصدار التفويض عبر بوابة نافذة وتكليف المخلص بمتابعة إذن التسليم 46.",
        generate_mandate_letter=True,
    )

    record = authorize_customs_broker_service(db_session, payload, user="Tamer Specialist")

    assert record is not None
    assert record.broker_id == broker.provider_id
    assert record.broker_name == broker.partner_name
    assert record.delegation_number == "DEL-2026-ALEX-01"
    assert record.delegation_status == "Authorized"
    assert record.customs_office_name == "Alexandria Port Customs"
    assert record.status == "Broker Authorized - Ready for 46"
    assert record.customs_exchange_rate is None
    assert record.mandate_letter_code is not None  # Formal mandate letter was generated!

    # 1. Verify ImportFile sync
    db_session.refresh(imp_file)
    assert imp_file.broker_id == broker.provider_id
    assert imp_file.broker_name == broker.partner_name
    assert imp_file.customs_broker_delegation_no == "DEL-2026-ALEX-01"
    assert imp_file.customs_broker_delegated_at is not None
    assert imp_file.customs_broker_authorization_status == "Authorized"
    assert imp_file.progress_percent >= 80.0
    assert "CS-02" in imp_file.next_action

    # 2. Verify CS-01 SmartTask completed
    db_session.refresh(task_cs01)
    assert task_cs01.status == "Completed"
    assert "DEL-2026-ALEX-01" in (task_cs01.notes or "")

    # 3. Verify downstream CS-02 SmartTask dispatched
    downstream_cs02 = (
        db_session.query(SmartTask)
        .filter(
            SmartTask.import_file_id == imp_file.import_file_id,
            SmartTask.task_type.in_(["DELIVERY_ORDER_PAYMENT", "CS-02"]),
        )
        .first()
    )
    assert downstream_cs02 is not None
    assert "CS-02" in downstream_cs02.title
    assert "delivery order" in downstream_cs02.title
    assert downstream_cs02.msg_code == "CC_TASK_DELIVERY_ORDER_PAYMENT"
    assert downstream_cs02.status == "Pending"

    # 4. Verify SystemNotification emitted
    notifs = (
        db_session.query(SystemNotification)
        .filter(
            SystemNotification.entity_id == imp_file.import_file_id,
            SystemNotification.category == "STAGE_PROGRESSION",
        )
        .all()
    )
    assert len(notifs) >= 1
    broker_notif = [n for n in notifs if n.msg_code == "CC_BROKER_AUTHORIZED"]
    assert len(broker_notif) >= 1
    assert "DEL-2026-ALEX-01" in broker_notif[0].message
    assert broker_notif[0].title.startswith("Customs broker authorized electronically")
    assert broker_notif[0].msg_params["delegation_no"] == "DEL-2026-ALEX-01"
    assert imp_file.next_action_code == "NA_CS_PAY_DELIVERY_ORDER"

    # 5. Verify Lifecycle Stage Activity
    activities = (
        db_session.query(ShipmentStageActivity)
        .filter(
            ShipmentStageActivity.import_file_code == imp_file.import_file_code,
            ShipmentStageActivity.step_code == "STEP_13",
        )
        .all()
    )
    assert len(activities) >= 1


def test_authorize_broker_api_endpoint(client, sample_data):
    """
    Test REST endpoint POST /api/v1/customs-clearance/authorize-broker.
    """
    imp_file = sample_data["import_file"]
    broker = sample_data["broker"]

    payload = {
        "import_file_id": imp_file.import_file_id,
        "broker_id": broker.provider_id,
        "delegation_number": "MTS-AUTH-2026-9901",
        "customs_office_name": "El Dekheila Port Customs",
        "authorization_notes": "تفويض رسمي صادر عبر منظومة نافذة MTS",
        "generate_mandate_letter": True,
    }

    response = client.post("/api/v1/customs-clearance/authorize-broker", json=payload)
    assert response.status_code == 200, response.text
    data = response.json()

    assert data["import_file_id"] == imp_file.import_file_id
    assert data["broker_id"] == broker.provider_id
    assert data["broker_name"] == broker.partner_name
    assert data["delegation_number"] == "MTS-AUTH-2026-9901"
    assert data["delegation_status"] == "Authorized"
    assert data["customs_office_name"] == "El Dekheila Port Customs"
    assert data["status"] == "Broker Authorized - Ready for 46"


def test_authorize_broker_validation_errors(client, sample_data):
    """
    Test validation errors: non-existing import file, non-existing broker, invalid delegation number.
    """
    broker = sample_data["broker"]
    imp_file = sample_data["import_file"]

    # 1. Non-existing import file
    res1 = client.post(
        "/api/v1/customs-clearance/authorize-broker",
        json={
            "import_file_id": 999999,
            "broker_id": broker.provider_id,
            "delegation_number": "DEL-1234",
        },
    )
    assert res1.status_code == 404
    assert "غير موجود" in res1.json()["detail"]

    # 2. Non-existing broker
    res2 = client.post(
        "/api/v1/customs-clearance/authorize-broker",
        json={
            "import_file_id": imp_file.import_file_id,
            "broker_id": 888888,
            "delegation_number": "DEL-1234",
        },
    )
    assert res2.status_code == 404
    assert "غير مسجل" in res2.json()["detail"]

    # 3. Invalid / empty delegation number (< 3 chars)
    res3 = client.post(
        "/api/v1/customs-clearance/authorize-broker",
        json={
            "import_file_id": imp_file.import_file_id,
            "broker_id": broker.provider_id,
            "delegation_number": "A",
        },
    )
    assert res3.status_code == 422  # Pydantic min_length validation


def test_authorize_broker_without_office_and_empty_license_skips_letter(db_session):
    """When customs_office_name is omitted, it must stay None, and missing broker license skips letter."""
    imp_file = ImportFile(
        import_file_code="IMP-2026-NOLIC",
        custom_file_number="FILE-NOLIC-1",
        company_name="Test Company",
        supplier_name="Test Supplier",
        current_module="Phase 5 - Sailing & CargoX",
        owner="Kamal",
        is_active=True,
    )
    db_session.add(imp_file)

    broker = ExternalServiceProvider(
        partner_code="BRK-NOLIC",
        partner_name="مخلص بدون ترخيص مدخل",
        partner_type="Customs Broker",
        tax_id="771-000-001",
        commercial_register="CR-001",
        clearance_license_number="",  # Empty license
        is_active=True,
    )
    db_session.add(broker)
    db_session.commit()
    db_session.refresh(imp_file)
    db_session.refresh(broker)

    payload = CustomsBrokerAuthorizationSubmit(
        import_file_id=imp_file.import_file_id,
        broker_id=broker.provider_id,
        delegation_number="DEL-2026-NOLIC",
        customs_office_name=None,
        generate_mandate_letter=True,
    )

    record = authorize_customs_broker_service(db_session, payload, user="Tamer Specialist")

    assert record.customs_office_name is None
    assert record.customs_exchange_rate is None
    assert record.mandate_letter_code is None  # Mandate letter skipped, not invented!
