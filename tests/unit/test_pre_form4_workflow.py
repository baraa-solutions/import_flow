"""
Unit Tests for Pre-Form 4 Readiness Pipeline (BP-015 / STEP_12)
Tests:
1. Broker pulling tax coding sheet updates status and dispatches accountant task.
2. Accountant uploading and coding sheet updates status and dispatches broker verify & link task.
3. Items pull verification records counts and regulatory bodies.
4. Nafeza bank linkage validates matching against the SWIFT executing bank.
5. Readiness blockers and can_submit_form4 flag.
"""

from datetime import date
import pytest
from fastapi.testclient import TestClient

from main import app
from database.database import get_db
from modules.import_files.model import ImportFile
from modules.external_service_providers.model import ExternalServiceProvider
from modules.financial_approval.model import PaymentRequestSession
from modules.import_documentation.model import BankingDocumentSession
from modules.smart_tasks.model import SmartTask
from modules.currencies.model import Currency
from modules.import_documentation import service
from modules.import_documentation.schemas import (
    BankingDocumentCreate,
    TaxCodingSheetPullRequest,
    TaxCodingSheetUploadRequest,
    ItemsVerificationConfirmRequest,
    NafezaBankLinkConfirmRequest,
)

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from database.database import Base

client = TestClient(app)


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture
def test_setup(db_session):
    # 1. Create test banks (ExternalServiceProvider)
    bank_cib = ExternalServiceProvider(
        partner_code="BNK-CIB-001",
        partner_name="Commercial International Bank (CIB)",
        partner_type="Bank",
        is_active=True,
    )
    bank_nbe = ExternalServiceProvider(
        partner_code="BNK-NBE-002",
        partner_name="National Bank of Egypt (NBE)",
        partner_type="Bank",
        is_active=True,
    )
    broker = ExternalServiceProvider(
        partner_code="BRK-ALEX-001",
        partner_name="Tarek Customs Clearance Services",
        partner_type="Customs Broker",
        is_active=True,
    )
    # BE03-T13: banking documents validate their currency against the currencies master table.
    usd = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
    db_session.add_all([bank_cib, bank_nbe, broker, usd])
    db_session.commit()
    db_session.refresh(bank_cib)
    db_session.refresh(bank_nbe)
    db_session.refresh(broker)

    # 2. Create ImportFile with a confirmed SWIFT reference
    imp = ImportFile(
        import_file_code="IMP-2026-F4-001",
        company_name="Al Sorour Trading Co",
        supplier_name="Global Tech Shanghai Ltd",
        swift_no="FT2610050099",
        estimated_cost=50000.0,
        estimated_cost_currency="USD",
        current_module="BP-012 Bank Form 4",
        current_step_code="STEP_12",
        is_active=True,
    )
    db_session.add(imp)
    db_session.commit()
    db_session.refresh(imp)

    # 3. Create linked PaymentRequestSession establishing CIB as the executing bank in Egypt
    payment = PaymentRequestSession(
        payment_code="PAY-2026-F4-001",
        title="Advance payment for Shanghai order",
        import_file_id=imp.import_file_id,
        supplier_name=imp.supplier_name,
        payment_type="ADVANCE_PAYMENT",
        requested_amount=50000.0,
        currency_code="USD",
        exchange_rate=50.0,
        requested_amount_egp=2500000.0,
        due_date=date.today(),
        status="Paid",
        swift_reference_no="FT2610050099",
        swift_receipt_date=date.today(),
        swift_transferred_amount=50000.0,
        swift_transferred_currency="USD",
        swift_reconciliation_notes="Executing bank in Egypt: Commercial International Bank (CIB) (CIBIEGCX)",
        is_active=True,
    )
    db_session.add(payment)
    db_session.commit()

    return {
        "bank_cib": bank_cib,
        "bank_nbe": bank_nbe,
        "broker": broker,
        "import_file": imp,
        "payment": payment,
    }


def test_pre_form4_full_pipeline_lifecycle(db_session, test_setup):
    imp = test_setup["import_file"]
    cib = test_setup["bank_cib"]
    nbe = test_setup["bank_nbe"]
    broker = test_setup["broker"]

    # 1. Create BankingDocumentSession for Form 4
    bdoc_schema = BankingDocumentCreate(
        doc_type="Form 4",
        import_file_id=imp.import_file_id,
        bank_name="Commercial International Bank (CIB)",
        bank_id=cib.provider_id,
        amount=50000.0,
        currency_code="USD",
        request_date=date.today(),
    )
    created = service.create_banking_document_service(db_session, bdoc_schema, user="tester")
    assert created.bank_doc_id is not None
    assert created.can_submit_form4 is False
    assert len(created.blockers) > 0
    assert created.swift_coverage is not None
    assert created.swift_coverage.total_swift_transferred_amount == 50000.0
    assert created.swift_coverage.is_fully_covered is True
    assert created.swift_executing_bank_name == "Commercial International Bank (CIB)"

    # Verify initial task dispatched for customs broker to pull coding sheet
    pull_task = (
        db_session.query(SmartTask)
        .filter(
            SmartTask.import_file_id == imp.import_file_id,
            SmartTask.reminder_type == "Tax Coding Sheet",
        )
        .first()
    )
    assert pull_task is not None
    assert pull_task.assigned_user == "Customs Broker"
    assert pull_task.status == "Pending"

    # 2. Step 1-A: Broker pulls Tax Coding Sheet from Nafeza
    pull_req = TaxCodingSheetPullRequest(
        broker_id=broker.provider_id,
        broker_name=broker.partner_name,
        pulled_date=date.today(),
        file_url="https://nafeza.gov.eg/export/coding_sheet_IMP-2026-F4-001.xlsx",
        notes="Downloaded tax coding template from Nafeza portal",
    )
    pulled = service.record_tax_coding_sheet_pull_service(db_session, created.bank_doc_id, pull_req, user="broker")
    assert pulled.tax_coding_sheet_status == "PULLED_BY_BROKER"
    assert pulled.tax_coding_broker_id == broker.provider_id
    assert pulled.can_submit_form4 is False

    # Verify broker task closed and accountant task dispatched
    db_session.refresh(pull_task)
    assert pull_task.status == "Completed"

    upload_task = (
        db_session.query(SmartTask)
        .filter(
            SmartTask.import_file_id == imp.import_file_id,
            SmartTask.reminder_type == "Tax Coding Upload",
        )
        .first()
    )
    assert upload_task is not None
    assert upload_task.assigned_user == "Company Accountant"
    assert upload_task.status == "Pending"

    # 3. Step 1-B: Company Accountant uploads & codes sheet on Nafeza
    upload_req = TaxCodingSheetUploadRequest(
        accountant_name="Mohamed Mostafa",
        uploaded_date=date.today(),
        items_count_coded=12,
        items_count_total=12,
        notes="All 12 items coded with EGS and approved on Nafeza via token",
    )
    uploaded = service.record_tax_coding_sheet_upload_service(db_session, created.bank_doc_id, upload_req, user="accountant")
    assert uploaded.tax_coding_sheet_status == "UPLOADED_BY_ACCOUNTANT"
    assert uploaded.tax_coding_accountant_name == "Mohamed Mostafa"
    assert uploaded.can_submit_form4 is False

    # Verify accountant task completed and broker task dispatched for items verify & bank link
    db_session.refresh(upload_task)
    assert upload_task.status == "Completed"

    verify_link_task = (
        db_session.query(SmartTask)
        .filter(
            SmartTask.import_file_id == imp.import_file_id,
            SmartTask.reminder_type == "Items Verification & Bank Linkage",
        )
        .first()
    )
    assert verify_link_task is not None
    assert verify_link_task.assigned_user == "Customs Broker"
    assert verify_link_task.status == "Pending"

    # 4. Step 2-A: Broker pulls items to verify coding and flags regulatory bodies
    verify_req = ItemsVerificationConfirmRequest(
        verified=True,
        verified_date=date.today(),
        items_count_total=12,
        items_count_coded=12,
        regulatory_bodies_detected=["GOEIC - هيئة الرقابة على الصادرات والواردات"],
        notes="All 12 items verified coded; GOEIC inspection required.",
    )
    verified = service.record_items_verification_service(db_session, created.bank_doc_id, verify_req, user="broker")
    assert verified.items_pulled_verified is True
    assert verified.items_count_coded == 12
    assert "GOEIC - هيئة الرقابة على الصادرات والواردات" in verified.regulatory_bodies_detected

    # 5. Step 2-B: Broker links to Bank on Nafeza
    # Negative test: Linking to NBE when SWIFT was executed via CIB should fail with 400
    with pytest.raises(Exception) as excinfo:
        bad_link_req = NafezaBankLinkConfirmRequest(
            bank_id=nbe.provider_id,
            link_date=date.today(),
            notes="Attempting to link to wrong bank",
            override_swift_mismatch=False,
        )
        service.record_nafeza_bank_link_service(db_session, created.bank_doc_id, bad_link_req, user="broker")
    assert "عدم تطابق بنكي" in str(excinfo.value)

    # Positive test: Linking to CIB (the executing SWIFT bank) succeeds
    good_link_req = NafezaBankLinkConfirmRequest(
        bank_id=cib.provider_id,
        link_date=date.today(),
        notes="Declaration successfully linked to CIB on Nafeza",
    )
    linked = service.record_nafeza_bank_link_service(db_session, created.bank_doc_id, good_link_req, user="broker")
    assert linked.nafeza_bank_link_status == "LINKED_TO_BANK"
    assert linked.nafeza_linked_bank_id == cib.provider_id
    assert linked.is_bank_matching_swift is True

    # Now verify all blockers are cleared and can_submit_form4 is True!
    assert linked.can_submit_form4 is True
    assert len(linked.blockers) == 0

    # Verify task for broker is closed and task for Bank Specialist is dispatched
    db_session.refresh(verify_link_task)
    assert verify_link_task.status == "Completed"

    form4_submit_task = (
        db_session.query(SmartTask)
        .filter(
            SmartTask.import_file_id == imp.import_file_id,
            SmartTask.reminder_type == "Bank Form 4 Application",
        )
        .first()
    )
    assert form4_submit_task is not None
    assert form4_submit_task.status == "Pending"
    assert cib.partner_name in form4_submit_task.title
