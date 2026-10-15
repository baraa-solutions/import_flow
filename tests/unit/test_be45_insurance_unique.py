"""
BE45-T05: One active insurance certificate per import file.

Prevents duplicate active insurance certificates for the same import file,
which would double-count insurance costs in financial settlement landed cost.
"""

from datetime import datetime
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.cargo_insurance.model import CargoInsuranceCertificate
from modules.cargo_insurance.schemas import CargoInsuranceCertificateCreate
from modules.cargo_insurance.service import CargoInsuranceService
from modules.import_files.model import ImportFile


@pytest.fixture
def db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        # Seed test import files
        f1 = ImportFile(
            import_file_id=1,
            import_file_code="IMP-2026-00001",
            company_name="Test Importer Co",
            supplier_name="Test Supplier Inc",
            created_by="test_user",
            updated_by="test_user",
        )
        f2 = ImportFile(
            import_file_id=2,
            import_file_code="IMP-2026-00002",
            company_name="Test Importer Co",
            supplier_name="Test Supplier Inc",
            created_by="test_user",
            updated_by="test_user",
        )
        db.add_all([f1, f2])
        db.commit()
        yield db
    finally:
        db.close()


def _sample_create_payload(import_file_id: int | None = 1) -> CargoInsuranceCertificateCreate:
    return CargoInsuranceCertificateCreate(
        import_file_id=import_file_id,
        insured_entity_name="Test Importer Co",
        insurance_company_name="Misr Insurance Co",
        transport_mode="OCEAN",
        carrier_name="Maersk Line",
        port_of_loading="Shanghai Port, China",
        port_of_discharge="Alexandria Port, Egypt",
        currency="USD",
        exchange_rate=50.0,
        invoice_value=1000.0,
        freight_cost=100.0,
        other_logistics_costs=0.0,
        coverage_clause="ICC_C",
        include_war_and_strikes=False,
        minimum_premium=30.0,
        issuance_fee=15.0,
        tax_rate=0.05,
    )


def test_cannot_create_second_active_insurance_for_same_file(db_session):
    """
    BE45-T05: Attempting to create a second certificate for the same import file
    must raise 409 Conflict with the active certificate code in the message.
    """
    service = CargoInsuranceService(db_session)

    # 1. First certificate succeeds
    cert1 = service.create_certificate(_sample_create_payload(import_file_id=1))
    assert cert1.certificate_id is not None
    assert cert1.certificate_code.startswith("INS-")

    # 2. Second certificate for the same file fails with 409
    with pytest.raises(HTTPException) as exc_info:
        service.create_certificate(_sample_create_payload(import_file_id=1))

    assert exc_info.value.status_code == 409
    assert "يوجد بالفعل وثيقة تأمين نشطة لهذا الملف" in exc_info.value.detail
    assert cert1.certificate_code in exc_info.value.detail


def test_can_create_insurance_after_first_is_soft_deleted(db_session):
    """
    BE45-T05: If the previous certificate is soft-deleted (is_active == False),
    creating a new certificate for the file is permitted.
    """
    service = CargoInsuranceService(db_session)

    # 1. Create first certificate
    cert1 = service.create_certificate(_sample_create_payload(import_file_id=1))

    # 2. Soft-delete the draft certificate
    service.delete_certificate(cert1.certificate_id)
    assert cert1.is_active is False

    # 3. Creating a new certificate for the file now succeeds
    cert2 = service.create_certificate(_sample_create_payload(import_file_id=1))
    assert cert2.certificate_id is not None
    assert cert2.certificate_id != cert1.certificate_id
    assert cert2.is_active is True


def test_can_create_insurance_after_first_is_cancelled(db_session):
    """
    BE45-T05: If the previous certificate is CANCELLED,
    creating a new certificate for the file is permitted.
    """
    service = CargoInsuranceService(db_session)

    # 1. Create first certificate
    cert1 = service.create_certificate(_sample_create_payload(import_file_id=1))

    # 2. Mark it as CANCELLED
    cert1.status = "CANCELLED"
    db_session.commit()

    # 3. Creating a new certificate for the file now succeeds
    cert2 = service.create_certificate(_sample_create_payload(import_file_id=1))
    assert cert2.certificate_id is not None
    assert cert2.certificate_id != cert1.certificate_id
    assert cert2.status == "DRAFT"


def test_can_create_multiple_unlinked_or_different_file_certificates(db_session):
    """
    BE45-T05: Certificates with import_file_id=None or linked to different files
    do not trigger 409 Conflict.
    """
    service = CargoInsuranceService(db_session)

    # Unlinked certificates (open declaration or standalone)
    c_none1 = service.create_certificate(_sample_create_payload(import_file_id=None))
    c_none2 = service.create_certificate(_sample_create_payload(import_file_id=None))
    assert c_none1.certificate_id != c_none2.certificate_id

    # Different files
    c_file1 = service.create_certificate(_sample_create_payload(import_file_id=1))
    c_file2 = service.create_certificate(_sample_create_payload(import_file_id=2))
    assert c_file1.import_file_id == 1
    assert c_file2.import_file_id == 2


def test_money_example_demonstrates_shared_need_prevention(db_session):
    """
    BE45-T05 Money Example:
    Without the single-active guard, two drafts with total_payable_premium = 47.25 USD each
    at FX rate 50.0 would sum to 4,725.00 EGP in settlement, whereas the true expected
    insurance cost is 2,362.50 EGP.

    With BE45-T05, the second draft is rejected at creation (409 Conflict), preventing
    this double-counting before it reaches financial settlement.
    """
    service = CargoInsuranceService(db_session)

    payload = _sample_create_payload(import_file_id=1)
    cert1 = service.create_certificate(payload)

    # In minimum premium policy, total payable is 47.25 USD
    assert cert1.total_payable_premium == 47.25
    expected_settlement_egp = round(47.25 * 50.0, 2)
    assert expected_settlement_egp == 2362.50

    # Second draft creation is blocked
    with pytest.raises(HTTPException) as exc_info:
        service.create_certificate(payload)
    assert exc_info.value.status_code == 409

    # Verifies only 1 active certificate exists for file 1
    active_cert = service.repo.get_active_for_file(1)
    assert active_cert is not None
    assert active_cert.certificate_id == cert1.certificate_id
