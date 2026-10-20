"""
Unit Tests for TASK-BE-10: Tax Coding & Bank Linkage on Nafeza before Form 4
"""

from datetime import datetime, timezone
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from main import app
from database.database import Base, get_db
from modules.import_files.model import ImportFile
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.import_documentation.model import BankingDocumentSession
from modules.customs_clearance.schemas import (
    TariffCodingSubmit,
    NafezaBankLinkSubmit,
    DutyPaymentRequestSubmit,
)
from modules.customs_clearance.service import (
    record_tariff_coding_service,
    record_bank_link_accepted_service,
    record_duty_payment_request_service,
)
from modules.common.errors import CodedHTTPException


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

    # Seed test import file
    file1 = ImportFile(
        import_file_id=1,
        import_file_code="IMP-2026-0001",
        company_name="Sorour Chemicals Ltd",
        supplier_name="Global Polymers Inc",
        status="Under Customs Clearance",
        is_active=True,
    )
    session.add(file1)

    # Seed test banking document session
    bdoc1 = BankingDocumentSession(
        bank_doc_id=1,
        bank_doc_code="BDOC-2026-0001",
        bank_name="Commercial International Bank",
        import_file_id=1,
        status="Draft",
        is_active=True,
    )
    session.add(bdoc1)

    session.commit()
    yield session
    session.close()


def test_tariff_coding_service_success(db_session):
    now = datetime.now(timezone.utc)
    payload = TariffCodingSubmit(
        import_file_id=1,
        tariff_coding_date=now,
        accountant_name="Ahmad Sorour",
        items_count_total=10,
        items_count_coded=10,
        notes="All 10 items successfully coded with EGS standards",
    )

    record = record_tariff_coding_service(db_session, payload, user="Accountant")
    assert record.tariff_coding_date is not None
    assert "Tax coding: All 10 items" in (record.notes or "")

    # Check sync with BankingDocumentSession
    bdoc = db_session.query(BankingDocumentSession).filter_by(import_file_id=1).first()
    assert bdoc.tax_coding_sheet_status == "Uploaded & Coded"
    assert bdoc.tax_coding_accountant_name == "Ahmad Sorour"
    assert bdoc.items_count_total == 10
    assert bdoc.items_count_coded == 10


def test_bank_link_requires_tariff_coding(db_session):
    # Try bank link without tariff coding -> should raise 400 CC_BANK_LINK_REQUIRES_TARIFF_CODING
    payload = NafezaBankLinkSubmit(
        import_file_id=1,
        linked_bank_id=5,
        linked_bank_name="Commercial International Bank (CIB)",
        notes="Attempting link without prior coding",
    )

    with pytest.raises(Exception) as exc_info:
        record_bank_link_accepted_service(db_session, payload, user="Broker")

    assert getattr(exc_info.value, "status_code", None) == 400
    detail = getattr(exc_info.value, "detail", {})
    code = detail.get("code") if isinstance(detail, dict) else getattr(exc_info.value, "code", None)
    assert code == "CC_BANK_LINK_REQUIRES_TARIFF_CODING"


def test_bank_link_accepted_service_success(db_session):
    now = datetime.now(timezone.utc)
    # First, record tariff coding
    coding_payload = TariffCodingSubmit(
        import_file_id=1,
        tariff_coding_date=now,
        accountant_name="Ahmad Sorour",
    )
    record_tariff_coding_service(db_session, coding_payload, user="Accountant")

    # Now, confirm bank link acceptance
    link_payload = NafezaBankLinkSubmit(
        import_file_id=1,
        bank_link_accepted_date=now,
        linked_bank_id=5,
        linked_bank_name="Commercial International Bank (CIB)",
        nafeza_bank_link_ref="MTS-LNK-88912",
        notes="Bank linkage accepted by Nafeza MTS",
    )
    record = record_bank_link_accepted_service(db_session, link_payload, user="Broker")
    assert record.bank_link_accepted_date is not None
    assert "Nafeza bank link:" in (record.notes or "")

    # Check sync with BankingDocumentSession
    bdoc = db_session.query(BankingDocumentSession).filter_by(import_file_id=1).first()
    assert bdoc.nafeza_bank_link_status == "Linked & Verified"
    assert bdoc.nafeza_linked_bank_id == 5


def test_duty_payment_request_service_success(db_session):
    now = datetime.now(timezone.utc)
    # Ensure clearance record exists first
    coding_payload = TariffCodingSubmit(
        import_file_id=1,
        tariff_coding_date=now,
    )
    record_tariff_coding_service(db_session, coding_payload, user="Accountant")

    req_payload = DutyPaymentRequestSubmit(
        import_file_id=1,
        duty_payment_requested_date=now,
        nafeza_claim_number="CLM-2026-9921",
        total_duty_payable=125000.0,
        notes="Claim generated and ready for payment voucher",
    )
    record = record_duty_payment_request_service(db_session, req_payload, user="Broker")
    assert record.duty_payment_requested_date is not None
    assert record.nafeza_claim_number == "CLM-2026-9921"
    assert record.total_duty_payable == 125000.0
    assert record.payment_status == "Payment Requested"
