import pytest
from datetime import date, datetime, timedelta, timezone
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient

from database.database import Base, get_db
from main import app
from modules.import_files.model import ImportFile
from modules.import_documentation.model import BankingDocumentSession
from modules.import_documentation.schemas import (
    BankingDocumentCreate,
    BankingDocumentUpdate,
    BankingDocumentReceive,
)
from modules.import_documentation.service import (
    create_banking_document_service,
    update_banking_document_service,
    receive_banking_document_service,
)
from modules.smart_tasks.model import SmartTask
from modules.notifications.model import SystemNotification


from sqlalchemy.pool import StaticPool


@pytest.fixture
def db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    session = Session()

    # Seed sample ImportFile
    imp_file = ImportFile(
        import_file_id=1,
        import_file_code="IMP-2026-0033",
        company_name="El-Araby Home Appliances",
        supplier_name="Hitachi Global Tokyo",
        po_number="PO-2026-8811",
        pi_number="PI-2026-5544",
        shipment_mode="Sea FCL",
        estimated_cost=120000.0,
        estimated_cost_currency="USD",
        current_module="STEP_12 Bank Form 4 Endorsement",
        current_stage="Phase 3 - Import Documentation",
        progress_percent=55.0,
        status="Open",
        is_active=True,
    )
    session.add(imp_file)
    session.commit()
    session.refresh(imp_file)

    yield session
    session.close()


def test_form4_creation_and_request_linking(db_session):
    """
    DC-03 Verification:
    Creating a Form 4 banking session links with the active ImportFile,
    records request date, and keeps reference as PENDING initially.
    """
    imp_file = db_session.query(ImportFile).filter(ImportFile.import_file_id == 1).first()

    payload = BankingDocumentCreate(
        doc_type="Form 4",
        import_file_id=1,
        bank_name="Commercial International Bank (CIB)",
        amount=120000.0,
        currency_code="USD",
        request_date=date.today(),
        doc_reference_number="PENDING",
        notes="Urgent Form 4 application submitted to CIB Mohandessin branch.",
    )

    created = create_banking_document_service(db_session, payload)
    assert created.bank_doc_id > 0
    assert created.doc_type == "Form 4"
    assert created.status == "Requested"
    assert created.bank_name == "Commercial International Bank (CIB)"
    assert created.amount == 120000.0
    assert created.import_file_code == "IMP-2026-0033"

    # Verify synchronization with ImportFile
    db_session.refresh(imp_file)
    assert imp_file.form4_request_date == date.today()


def test_letter_of_credit_creation_and_linking(db_session):
    """
    DC-03 Verification:
    Creating a Letter of Credit (L/C) banking session links with ImportFile
    and properly enriches importer and supplier info.
    """
    payload = BankingDocumentCreate(
        doc_type="Letter of Credit (L/C)",
        import_file_id=1,
        bank_name="National Bank of Egypt (NBE)",
        amount=75000.0,
        currency_code="EUR",
        request_date=date.today(),
        doc_reference_number="LC-APP-9988",
        notes="Irrevocable confirmed L/C at sight.",
    )

    created = create_banking_document_service(db_session, payload)
    assert created.doc_type == "Letter of Credit (L/C)"
    assert created.bank_name == "National Bank of Egypt (NBE)"
    assert created.importer_name == "El-Araby Home Appliances"
    assert created.supplier_name == "Hitachi Global Tokyo"


def test_receive_form4_calculates_execution_days_and_advances_lifecycle(db_session):
    """
    DC-03 Verification:
    Receiving and verifying Form 4 calculates execution turnaround days,
    updates ImportFile (form4_no, form4_received_date, form4_execution_days),
    and advances lifecycle STEP_12 -> STEP_13 with progress >= 65%.
    """
    imp_file = db_session.query(ImportFile).filter(ImportFile.import_file_id == 1).first()

    req_date = date.today() - timedelta(days=4)
    payload = BankingDocumentCreate(
        doc_type="Form 4",
        import_file_id=1,
        bank_name="Banque Misr",
        amount=120000.0,
        currency_code="USD",
        request_date=req_date,
        doc_reference_number="PENDING",
    )
    created = create_banking_document_service(db_session, payload)

    received_date = date.today()
    received = receive_banking_document_service(
        db_session,
        bank_doc_id=created.bank_doc_id,
        form4_number="F4-EGY-2026-993311",
        received_date=received_date,
        notes="Approved and verified by Banque Misr foreign trade department.",
    )

    assert received.status == "Received"
    assert received.doc_reference_number == "F4-EGY-2026-993311"
    assert received.execution_days == 4
    assert received.received_date == received_date

    # Verify ImportFile synchronization
    db_session.refresh(imp_file)
    assert imp_file.form4_no == "F4-EGY-2026-993311"
    assert imp_file.form4_received_date == received_date
    assert imp_file.form4_execution_days == 4
    assert imp_file.progress_percent >= 65.0
    assert "STEP_13" in (imp_file.current_module or "") or "Customs" in (imp_file.current_stage or "")


def test_receive_lc_resolves_smart_tasks_and_dispatches_declaration46(db_session):
    """
    DC-03 Verification:
    When an L/C is received:
    - Auto-completes prior pending banking SmartTask.
    - Dispatches new downstream SmartTask for Customs Broker (CS-03 Declaration 46).
    - Emits high-priority SystemNotification for CUSTOMS_BROKER.
    """
    imp_file = db_session.query(ImportFile).filter(ImportFile.import_file_id == 1).first()

    # Seed prior pending smart task for Form 4 / LC
    prior_task = SmartTask(
        task_code="TASK-TEST-001",
        title="استخراج نموذج 4 البنكي أو فتح الاعتماد المستندي",
        description="متابعة قسم التجارة الخارجية بالبنك لاستلام نموذج 4 أو إشعار الاعتماد L/C",
        import_file_id=1,
        import_file_code="IMP-2026-0033",
        status="Pending",
        assigned_user="Financial Controller",
        priority="High",
        reminder_type="Bank Form 4",
        due_date=str(date.today() + timedelta(days=1)),
    )
    db_session.add(prior_task)
    db_session.commit()

    # Create & Receive LC
    payload = BankingDocumentCreate(
        doc_type="Letter of Credit (L/C)",
        import_file_id=1,
        bank_name="QNB Alahli",
        amount=95000.0,
        currency_code="USD",
        request_date=date.today() - timedelta(days=6),
        doc_reference_number="PENDING",
    )
    created = create_banking_document_service(db_session, payload)

    received = receive_banking_document_service(
        db_session,
        bank_doc_id=created.bank_doc_id,
        form4_number="LC-QNB-2026-7788",
        received_date=date.today(),
        notes="LC issued and confirmed.",
    )
    assert received.status == "Received"

    # 1. Verify prior SmartTask is auto-completed
    db_session.refresh(prior_task)
    assert prior_task.status == "Completed"
    assert "received and approved" in (prior_task.completion_notes or "")

    # 2. Verify downstream Customs Broker SmartTask for Declaration 46 is dispatched
    downstream_task = (
        db_session.query(SmartTask)
        .filter(
            SmartTask.import_file_id == 1,
            SmartTask.reminder_type == "Customs Declaration 46",
        )
        .first()
    )
    assert downstream_task is not None
    assert "CS-03" in downstream_task.title
    assert downstream_task.assigned_user == "Customs Broker"
    assert downstream_task.priority == "High"

    # 3. Verify SystemNotification is created
    notif = (
        db_session.query(SystemNotification)
        .filter(SystemNotification.category == "BANKING_DOCUMENT_VERIFICATION")
        .first()
    )
    assert notif is not None
    assert "LC-QNB-2026-7788" in notif.title
    assert notif.target_role == "CUSTOMS_BROKER"


def test_api_endpoints_banking_documents_flow(db_session):
    """
    DC-03 Verification:
    End-to-end API route testing for /banking-documents creation, retrieval, and receipt.
    """
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)

    # 1. POST create
    create_res = client.post(
        "/api/v1/import-documentation/banking-documents",
        json={
            "doc_type": "Form 4",
            "import_file_id": 1,
            "bank_name": "HSBC Egypt",
            "amount": 45000.0,
            "currency_code": "USD",
            "request_date": str(date.today() - timedelta(days=2)),
            "doc_reference_number": "PENDING",
            "notes": "API test banking document",
        },
    )
    assert create_res.status_code == 201
    doc_data = create_res.json()
    bank_doc_id = doc_data["bank_doc_id"]
    assert doc_data["status"] == "Requested"

    # 2. GET list
    list_res = client.get("/api/v1/import-documentation/banking-documents")
    assert list_res.status_code == 200
    docs = list_res.json()
    assert any(d["bank_doc_id"] == bank_doc_id for d in docs)

    # 3. POST receive
    receive_res = client.post(
        f"/api/v1/import-documentation/banking-documents/{bank_doc_id}/receive",
        json={
            "form4_number": "F4-HSBC-2026-3322",
            "received_date": str(date.today()),
            "notes": "Official bank receipt verified via API",
        },
    )
    assert receive_res.status_code == 200
    received_data = receive_res.json()
    assert received_data["status"] == "Received"
    assert received_data["doc_reference_number"] == "F4-HSBC-2026-3322"
    assert received_data["execution_days"] == 2

    app.dependency_overrides.clear()
