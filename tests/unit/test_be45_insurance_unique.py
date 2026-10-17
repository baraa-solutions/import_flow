import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.cargo_insurance.model import CargoInsuranceCertificate
from modules.cargo_insurance.schemas import CargoInsuranceCertificateCreate
from modules.cargo_insurance.service import CargoInsuranceService
from modules.common.system_parameters import seed_default_parameters
from modules.import_files.model import ImportFile


@pytest.fixture(scope="function")
def db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = TestingSessionLocal()
    seed_default_parameters(db)
    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)


def _make_file(db, code: str = "IMP-2026-00100") -> ImportFile:
    f = ImportFile(
        import_file_code=code,
        custom_file_number=code,
        company_name="Test Company",
        supplier_name="Global Supplier",
        status="ACTIVE",
        is_active=True,
    )
    db.add(f)
    db.commit()
    db.refresh(f)
    return f


def _sample_payload(import_file_id: int | None = None) -> CargoInsuranceCertificateCreate:
    return CargoInsuranceCertificateCreate(
        import_file_id=import_file_id,
        insured_entity_name="Al-Amal Importing Co.",
        transport_mode="OCEAN",
        port_of_loading="Shanghai Port",
        port_of_discharge="Alexandria Port",
        coverage_clause="ICC_A",
        include_war_and_strikes=True,
        currency="USD",
        exchange_rate=50.0,
        invoice_value=100000.0,
        freight_cost=5000.0,
        other_logistics_costs=1000.0,
    )


def test_one_active_insurance_certificate_per_file(db_session):
    """
    BE45-T05: Creating a second active insurance certificate for the same import file
    raises HTTP 409 Conflict.
    """
    service = CargoInsuranceService(db_session)
    import_file = _make_file(db_session)

    # 1. First certificate succeeds
    cert1 = service.create_certificate(_sample_payload(import_file.import_file_id))
    assert cert1.certificate_id is not None
    assert cert1.certificate_code is not None

    # 2. Second certificate for the same import file raises 409
    with pytest.raises(HTTPException) as exc_info:
        service.create_certificate(_sample_payload(import_file.import_file_id))

    assert exc_info.value.status_code == 409
    assert f"يوجد بالفعل وثيقة تأمين نشطة لهذا الملف ({cert1.certificate_code})" in exc_info.value.detail


def test_create_certificate_allowed_after_soft_delete(db_session):
    """
    BE45-T05: Once an existing certificate is soft-deleted, a new certificate can be created.
    """
    service = CargoInsuranceService(db_session)
    import_file = _make_file(db_session)

    # 1. Create first certificate
    cert1 = service.create_certificate(_sample_payload(import_file.import_file_id))
    assert cert1.is_active is True

    # 2. Delete the first certificate (soft delete)
    service.delete_certificate(cert1.certificate_id)
    assert cert1.is_active is False

    # 3. Create a second certificate for the same file now succeeds
    cert2 = service.create_certificate(_sample_payload(import_file.import_file_id))
    assert cert2.certificate_id != cert1.certificate_id
    assert cert2.is_active is True
    assert cert2.import_file_id == import_file.import_file_id


def test_create_certificate_allowed_after_cancellation(db_session):
    """
    BE45-T05: If the existing certificate is CANCELLED, a new certificate can be created.
    """
    service = CargoInsuranceService(db_session)
    import_file = _make_file(db_session)

    # 1. Create first certificate and mark it CANCELLED
    cert1 = service.create_certificate(_sample_payload(import_file.import_file_id))
    cert1.status = "CANCELLED"
    db_session.commit()

    # 2. Creating another certificate for the same file succeeds
    cert2 = service.create_certificate(_sample_payload(import_file.import_file_id))
    assert cert2.certificate_id != cert1.certificate_id
    assert cert2.status == "DRAFT"
    assert cert2.import_file_id == import_file.import_file_id


def test_standalone_certificates_without_file_allowed(db_session):
    """
    Certificates without an import_file_id do not trigger the per-file uniqueness guard.
    """
    service = CargoInsuranceService(db_session)

    cert1 = service.create_certificate(_sample_payload(None))
    cert2 = service.create_certificate(_sample_payload(None))

    assert cert1.certificate_id != cert2.certificate_id
    assert cert1.import_file_id is None
    assert cert2.import_file_id is None


def test_shared_need_money_example(db_session):
    """
    Verified calculation for the shared need:
    A low-value shipment (1,000 USD invoice + 100 USD freight, ICC_C) has total_payable_premium = 47.25 USD.
    At exchange rate 50 EGP/USD:
      1 certificate = 47.25 * 50 = 2,362.50 EGP.
    Duplicate active drafts previously doubled landed cost to 4,725.00 EGP.
    The uniqueness guard ensures exactly one active certificate exists.
    """
    service = CargoInsuranceService(db_session)
    import_file = _make_file(db_session, "IMP-2026-00101")

    low_payload = CargoInsuranceCertificateCreate(
        import_file_id=import_file.import_file_id,
        insured_entity_name="Al-Amal Co.",
        transport_mode="OCEAN",
        port_of_loading="Ningbo",
        port_of_discharge="Alexandria",
        coverage_clause="ICC_C",
        include_war_and_strikes=False,
        currency="USD",
        exchange_rate=50.0,
        invoice_value=1000.0,
        freight_cost=100.0,
        other_logistics_costs=0.0,
        minimum_premium=30.0,
        issuance_fee=15.0,
        tax_rate=0.05,
    )

    cert = service.create_certificate(low_payload)
    assert cert.total_payable_premium == 47.25

    single_certificate_egp = round(cert.total_payable_premium * cert.exchange_rate, 2)
    assert single_certificate_egp == 2362.50
    double_unwanted_egp = round(single_certificate_egp * 2, 2)
    assert double_unwanted_egp == 4725.00

    # Guard prevents creation of duplicate draft
    with pytest.raises(HTTPException) as exc_info:
        service.create_certificate(low_payload)
    assert exc_info.value.status_code == 409
