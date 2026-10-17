import pytest
from datetime import date, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.external_service_providers.model import ExternalServiceProvider
from modules.transport_locations.model import TransportLocation
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.customs_tariff.model import CustomsTariff
from modules.projects.model import Project
from modules.incoterms.model import Incoterm
from modules.currencies.model import Currency
from modules.purchase_orders.model import PurchaseOrder
from modules.import_files.model import ImportFile
from modules.import_documentation.model import (
    AcidRegistrationSession,
    BankingDocumentSession,
    ShipmentDocumentItem,
    CustomsDeclarationDraft,
)
from modules.import_documentation.schemas import (
    BankingDocumentCreate,
    BankingDocumentUpdate,
    BankingDocumentReceive,
)
from modules.import_documentation.service import (
    create_banking_document_service,
    receive_banking_document_service,
    update_banking_document_service,
    delete_banking_document_service,
    enrich_banking_response,
)


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    session = Session()

    # Create dummy import file
    imp_file = ImportFile(
        import_file_code="IMP-2026-009",
        company_name="Al-Ahram Import Co.",
        supplier_name="Global Tech Supplier",
        po_number="PO-9901",
        pi_number="PI-7788",
        shipment_mode="Sea FCL",
        estimated_cost=85000.0,
        current_stage="Phase 3 - Import Documentation",
        status="Open",
        is_active=True,
    )
    session.add(imp_file)
    session.add(Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True))
    session.add(Currency(currency_code="EUR", currency_name="Euro", currency_symbol="€", is_active=True))
    session.commit()
    session.refresh(imp_file)

    yield session
    session.close()


def test_form4_request_stage_creation_and_file_linking(db_session):
    imp_file = db_session.query(ImportFile).first()
    assert imp_file is not None

    payload = BankingDocumentCreate(
        doc_type="Form 4",
        import_file_id=imp_file.import_file_id,
        bank_name="Commercial International Bank (CIB)",
        amount=85000.0,
        currency_code="USD",
        request_date=date.today(),
        doc_reference_number="PENDING",
        notes="Urgent Form 4 application for customs clearance",
    )

    created = create_banking_document_service(db_session, payload)

    assert created.bank_doc_id > 0
    assert created.bank_doc_code.startswith("FORM4-")
    assert created.doc_reference_number == "PENDING"
    assert created.status == "Requested"
    assert created.amount == 85000.0
    assert created.currency_code == "USD"
    assert created.import_file_code == "IMP-2026-009"
    assert created.importer_name == "Al-Ahram Import Co."
    assert created.supplier_name == "Global Tech Supplier"

    # Verify ImportFile was synced with request date
    db_session.refresh(imp_file)
    assert imp_file.form4_request_date == date.today()


def test_form4_receipt_stage_calculation_and_file_sync(db_session):
    imp_file = db_session.query(ImportFile).first()

    req_date = date.today() - timedelta(days=5)
    payload = BankingDocumentCreate(
        doc_type="Form 4",
        import_file_id=imp_file.import_file_id,
        bank_name="National Bank of Egypt (NBE)",
        amount=50000.0,
        currency_code="EUR",
        request_date=req_date,
        doc_reference_number="PENDING",
    )

    created = create_banking_document_service(db_session, payload)
    assert created.status == "Requested"

    # Receive Form 4
    received_date = date.today()
    receive_payload = BankingDocumentReceive(
        form4_number="F4-EG-2026-887711",
        received_date=received_date,
        notes="Form 4 approved and endorsed by NBE Cairo branch",
    )

    received = receive_banking_document_service(
        db_session,
        bank_doc_id=created.bank_doc_id,
        form4_number=receive_payload.form4_number,
        received_date=receive_payload.received_date,
        notes=receive_payload.notes,
    )

    assert received.status == "Received"
    assert received.doc_reference_number == "F4-EG-2026-887711"
    assert received.execution_days == 5
    assert received.received_date == received_date

    # Verify ImportFile was automatically synced with Form 4 number and execution days
    db_session.refresh(imp_file)
    assert imp_file.form4_no == "F4-EG-2026-887711"
    assert imp_file.form4_received_date == received_date
    assert imp_file.form4_execution_days == 5
