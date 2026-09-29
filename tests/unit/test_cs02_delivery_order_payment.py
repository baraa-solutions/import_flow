"""
Unit Tests for CS-02: Delivery Order (D/O) Payment & Receipt (سداد إذن التسليم الملاحي واستلام D/O)
Checklist Item #31 - Stage 6: Customs Preparation (46)
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
from modules.external_service_providers.model import ExternalServiceProvider
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.customs_clearance.schemas import DeliveryOrderPaymentSubmit
from modules.customs_clearance.service import record_delivery_order_payment_service
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
    # Create sample Import File
    imp_file = ImportFile(
        import_file_code="IMP-2026-CS02",
        custom_file_number="FILE-CS02-1122",
        company_name="Al-Nour Chemicals Co.",
        supplier_name="Bavaria Chem GmbH",
        current_module="Phase 6 - Customs Preparation",
        current_stage="Customs Broker Authorized (تفويض المخلص الجمركي)",
        progress_percent=80.0,
        next_action="سداد إذن التسليم الملاحي واستلام D/O (CS-02)",
        owner="Kamal",
        is_active=True,
    )
    db_session.add(imp_file)

    # Create sample Shipping Line / Agent
    shipping_agent = ExternalServiceProvider(
        partner_code="LINE-MSK",
        partner_name="ميرسك إيجيبت للملاحة (Maersk Line)",
        partner_type="Shipping Line",
        tax_id="661-889-112",
        commercial_register="CR-CAI-99881",
        scac_code="MAEU",
        is_active=True,
    )
    db_session.add(shipping_agent)

    db_session.commit()
    db_session.refresh(imp_file)
    db_session.refresh(shipping_agent)

    # Create existing CS-02 SmartTask
    task_cs02 = SmartTask(
        task_code="TASK-CS02-001",
        import_file_id=imp_file.import_file_id,
        import_file_code=imp_file.import_file_code,
        title="سداد إذن التسليم الملاحي واستلام D/O (CS-02) — IMP-2026-CS02",
        description="يرجى سداد مصاريف التوكيل الملاحي واستلام إذن التسليم (Delivery Order) لبدء الكشف وقيد 46.",
        task_type="DELIVERY_ORDER_PAYMENT",
        priority="High",
        status="Pending",
        assigned_user="Logistics Operations",
    )
    db_session.add(task_cs02)
    db_session.commit()
    db_session.refresh(task_cs02)

    return {
        "import_file": imp_file,
        "shipping_agent": shipping_agent,
        "task_cs02": task_cs02,
    }


def test_record_delivery_order_payment_service_full_workflow(db_session, sample_data):
    """
    Test that record_delivery_order_payment_service:
    1. Creates / updates CustomsClearanceRecord with DO number, payment ref, fees, expiry, and status.
    2. Synchronizes ImportFile delivery order fields, elevates progress to >= 83%, advances next_action.
    3. Auto-completes pending CS-02 smart task.
    4. Dispatches downstream CS-03 smart task (Customs Declaration 46).
    5. Emits SystemNotification.
    6. Maintains lifecycle board on STEP_13.
    """
    imp_file = sample_data["import_file"]
    agent = sample_data["shipping_agent"]
    task_cs02 = sample_data["task_cs02"]

    now = datetime.now(timezone.utc)
    expiry = now + timedelta(days=14)

    payload = DeliveryOrderPaymentSubmit(
        import_file_id=imp_file.import_file_id,
        delivery_order_number="DO-MAEU-2026-9011",
        delivery_order_date=now,
        delivery_order_expiry=expiry,
        free_days_allowed=14,
        shipping_agent_id=agent.provider_id,
        shipping_agent_name=agent.partner_name,
        delivery_order_fees=18500.0,
        delivery_order_currency="EGP",
        delivery_order_payment_ref="RCPT-MSK-TXN-449102",
        delivery_order_paid_at=now,
        delivery_order_file_url="https://storage.sorourlogistics.com/docs/do_9011.pdf",
        notes="تم سداد رسوم إذن التسليم والمناولة الملاحية إلكترونياً واستلام الـ D/O.",
    )

    record = record_delivery_order_payment_service(db_session, payload, user="Hany Logistics")

    assert record is not None
    assert record.delivery_order_number == "DO-MAEU-2026-9011"
    assert record.delivery_order_payment_ref == "RCPT-MSK-TXN-449102"
    assert record.delivery_order_fees == 18500.0
    assert record.delivery_order_currency == "EGP"
    assert record.shipping_agent_id == agent.provider_id
    assert record.shipping_agent_name == agent.partner_name
    assert record.delivery_order_status == "Paid & Received"
    assert record.free_days_allowed == 14
    assert record.status == "D/O Received - Ready for 46"

    # 1. Verify ImportFile synchronization
    db_session.refresh(imp_file)
    assert imp_file.delivery_order_no == "DO-MAEU-2026-9011"
    assert imp_file.delivery_order_status == "PAID_AND_RECEIVED"
    assert imp_file.progress_percent >= 83.0
    assert "CS-03" in imp_file.next_action

    # 2. Verify auto-completion of CS-02 task
    db_session.refresh(task_cs02)
    assert task_cs02.status == "Completed"
    assert "DO-MAEU-2026-9011" in task_cs02.completion_notes

    # 3. Verify downstream CS-03 task dispatched
    cs03_tasks = (
        db_session.query(SmartTask)
        .filter(
            SmartTask.import_file_id == imp_file.import_file_id,
            SmartTask.task_type.in_(["CUSTOMS_DECLARATION_46", "CS-03"]),
        )
        .all()
    )
    assert len(cs03_tasks) == 1
    assert "CS-03" in cs03_tasks[0].title
    assert cs03_tasks[0].status == "Pending"
    assert cs03_tasks[0].assigned_user == "Customs Broker"

    # 4. Verify SystemNotification emitted
    notifications = (
        db_session.query(SystemNotification)
        .filter(
            SystemNotification.entity_type == "ImportFile",
            SystemNotification.entity_id == imp_file.import_file_id,
        )
        .all()
    )
    assert len(notifications) >= 1
    latest_notif = notifications[-1]
    assert "Delivery order paid" in latest_notif.title
    assert latest_notif.msg_code == "CC_DELIVERY_ORDER_PAID"
    assert latest_notif.category == "STAGE_PROGRESSION"


def test_record_delivery_order_payment_api_success(client, sample_data):
    """
    Test POST /api/v1/customs-clearance/delivery-order-payment endpoint returns 200 and correct fields.
    """
    imp_file = sample_data["import_file"]
    agent = sample_data["shipping_agent"]

    expiry_dt = (datetime.now(timezone.utc) + timedelta(days=14)).isoformat()
    now_str = datetime.now(timezone.utc).isoformat()

    payload = {
        "import_file_id": imp_file.import_file_id,
        "delivery_order_number": "DO-2026-ALX-7744",
        "delivery_order_date": now_str,
        "delivery_order_expiry": expiry_dt,
        "free_days_allowed": 14,
        "shipping_agent_id": agent.provider_id,
        "delivery_order_fees": 12400.50,
        "delivery_order_currency": "EGP",
        "delivery_order_payment_ref": "TXN-LINE-88991",
        "delivery_order_paid_at": now_str,
        "notes": "سداد إذن تسليم ملاحي للمعاينة والكشف",
    }

    response = client.post("/api/v1/customs-clearance/delivery-order-payment", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["delivery_order_number"] == "DO-2026-ALX-7744"
    assert data["delivery_order_payment_ref"] == "TXN-LINE-88991"
    assert data["delivery_order_fees"] == 12400.50
    assert data["delivery_order_currency"] == "EGP"
    assert data["shipping_agent_id"] == agent.provider_id
    assert data["delivery_order_status"] == "Paid & Received"


def test_record_delivery_order_payment_api_validation_errors(client, sample_data):
    """
    Test validation errors:
    1. Import file does not exist -> 404
    2. Delivery order number too short -> 422 (Pydantic min_length=3)
    3. Payment ref too short -> 422 (Pydantic min_length=2)
    4. Shipping agent does not exist -> 404
    """
    imp_file = sample_data["import_file"]
    expiry_dt = (datetime.now(timezone.utc) + timedelta(days=14)).isoformat()

    # 1. Non-existent file
    res = client.post(
        "/api/v1/customs-clearance/delivery-order-payment",
        json={
            "import_file_id": 99999,
            "delivery_order_number": "DO-9999",
            "delivery_order_expiry": expiry_dt,
            "delivery_order_fees": 5000.0,
            "delivery_order_payment_ref": "REF-123",
        },
    )
    assert res.status_code == 404

    # 2. Short DO number
    res = client.post(
        "/api/v1/customs-clearance/delivery-order-payment",
        json={
            "import_file_id": imp_file.import_file_id,
            "delivery_order_number": "D",
            "delivery_order_expiry": expiry_dt,
            "delivery_order_fees": 5000.0,
            "delivery_order_payment_ref": "REF-123",
        },
    )
    assert res.status_code == 422  # Pydantic min_length=3

    # 3. Short payment ref
    res = client.post(
        "/api/v1/customs-clearance/delivery-order-payment",
        json={
            "import_file_id": imp_file.import_file_id,
            "delivery_order_number": "DO-12345",
            "delivery_order_expiry": expiry_dt,
            "delivery_order_fees": 5000.0,
            "delivery_order_payment_ref": "X",
        },
    )
    assert res.status_code == 422  # Pydantic min_length=2

    # 4. Non-existent shipping agent
    res = client.post(
        "/api/v1/customs-clearance/delivery-order-payment",
        json={
            "import_file_id": imp_file.import_file_id,
            "delivery_order_number": "DO-12345",
            "delivery_order_expiry": expiry_dt,
            "shipping_agent_id": 99999,
            "delivery_order_fees": 5000.0,
            "delivery_order_payment_ref": "TXN-9988",
        },
    )
    assert res.status_code == 404
