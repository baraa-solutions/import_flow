from datetime import datetime

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.cargo_insurance.schemas import (
    InsuranceCalculationInput,
    CargoInsuranceCertificateCreate,
    CargoInsuranceCertificateUpdate,
)
from modules.cargo_insurance.service import (
    CargoInsuranceService,
    calculate_cargo_insurance_engine,
)
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
        yield db
    finally:
        db.close()


def test_cargo_insurance_calculation_formula_standard():
    # 1. Test standard ICC_A ocean shipment with War & Strikes
    payload = InsuranceCalculationInput(
        invoice_value=100000.0,
        freight_cost=5000.0,
        other_costs=1000.0,
        markup_percentage=0.10,
        coverage_clause="ICC_A",
        transport_mode="OCEAN",
        include_war_and_strikes=True,
        currency="USD",
        minimum_premium=30.0,
        issuance_fee=15.0,
        tax_rate=0.05,
    )
    result = calculate_cargo_insurance_engine(payload)

    assert result.cif_value == 106000.0
    assert result.insured_value == 116600.0 # 106,000 * 1.10
    assert result.base_rate == 0.0025      # ICC_A 0.25%
    assert result.base_premium == 291.50   # 116,600 * 0.0025
    assert result.war_rate == 0.0005       # 0.05%
    assert result.war_strikes_premium == 58.30 # 116,600 * 0.0005
    assert result.net_premium == 349.80    # 291.50 + 58.30
    assert result.issuance_fee == 15.00
    assert result.tax_amount == 18.24      # (349.80 + 15.00) * 0.05 = 18.24
    assert result.total_payable_premium == 383.04 # 349.80 + 15.00 + 18.24


def test_cargo_insurance_air_and_icc_clauses():
    # Test Air All Risks
    air_input = InsuranceCalculationInput(
        invoice_value=50000.0,
        freight_cost=2000.0,
        other_costs=0.0,
        coverage_clause="AIR_ALL_RISKS",
        transport_mode="AIR",
        include_war_and_strikes=False,
    )
    air_res = calculate_cargo_insurance_engine(air_input)
    assert air_res.cif_value == 52000.0
    assert air_res.insured_value == 57200.0
    assert air_res.base_rate == 0.0020 # Air All Risks 0.20%
    assert air_res.war_strikes_premium == 0.0

    # Test ICC_C (Minimum Coverage 0.10%)
    c_input = InsuranceCalculationInput(
        invoice_value=50000.0,
        freight_cost=2000.0,
        other_costs=0.0,
        coverage_clause="ICC_C",
        transport_mode="OCEAN",
        include_war_and_strikes=False,
    )
    c_res = calculate_cargo_insurance_engine(c_input)
    assert c_res.base_rate == 0.0010
    assert c_res.base_premium == 57.20


def test_cargo_insurance_minimum_premium_policy():
    # Low value sample shipment where calculated premium < minimum $30.00
    low_input = InsuranceCalculationInput(
        invoice_value=1000.0,
        freight_cost=100.0,
        other_costs=0.0,
        coverage_clause="ICC_C",
        include_war_and_strikes=False,
        minimum_premium=30.0,
        issuance_fee=15.0,
        tax_rate=0.05,
    )
    low_res = calculate_cargo_insurance_engine(low_input)
    # Calculated base is 1,210 * 0.0010 = 1.21 < 30.00
    assert low_res.base_premium == 1.21
    assert low_res.net_premium == 30.00 # Minimum floor applied
    assert low_res.tax_amount == 2.25   # (30 + 15) * 0.05
    assert low_res.total_payable_premium == 47.25 # 30 + 15 + 2.25


def test_cargo_insurance_certificate_workflow(db_session):
    service = CargoInsuranceService(db_session)

    # 1. Create Certificate Draft
    create_dto = CargoInsuranceCertificateCreate(
        insured_entity_name="Al-Ahram Industrial Corp",
        insurance_company_name="Misr Insurance Co",
        transport_mode="OCEAN",
        carrier_name="Maersk Line",
        vessel_or_flight_no="Maersk Mc-Kinney Moller",
        voyage_number="V.2608",
        tracking_reference="MAEU-88912401",
        port_of_loading="Shanghai Port, China",
        port_of_discharge="Alexandria Port, Egypt",
        currency="USD",
        exchange_rate=48.50,
        invoice_value=85000.0,
        freight_cost=4200.0,
        other_logistics_costs=800.0,
        markup_percentage=0.10,
        coverage_clause="ICC_A",
        include_war_and_strikes=True,
        goods_description="Industrial Textile Machines & Spare Parts",
        package_count=45,
        package_type="Wooden Crates",
        gross_weight_kg=14200.0,
    )

    cert = service.create_certificate(create_dto, current_user="ahmed_ops")
    assert cert.certificate_id is not None
    assert cert.certificate_code == f"INS-{datetime.now().year}-00001"
    assert cert.status == "DRAFT"
    assert cert.cif_value == 90000.0
    assert cert.insured_value == 99000.0
    assert cert.total_payable_premium > 0

    # 2. Query Certificate
    fetched = service.get_certificate(cert.certificate_id)
    assert fetched.insured_entity_name == "Al-Ahram Industrial Corp"

    # 3. Update Certificate
    update_dto = CargoInsuranceCertificateUpdate(
        freight_cost=4500.0,
        remarks="Updated after final freight booking confirmation",
    )
    updated = service.update_certificate(cert.certificate_id, update_dto, current_user="ahmed_ops")
    assert updated.freight_cost == 4500.0
    assert updated.cif_value == 90300.0
    assert updated.insured_value == 99330.0

    # 4. Officially Issue Certificate
    issued = service.issue_certificate(cert.certificate_id, current_user="ahmed_ops")
    assert issued.status == "ISSUED"
    assert issued.issued_at is not None

    # 5. List Certificates
    items, total = service.list_certificates(search="Al-Ahram")
    assert total == 1
    assert items[0].certificate_id == cert.certificate_id

    # 6. Soft Delete: an ISSUED certificate cannot be deleted (409, security review); a draft can
    with pytest.raises(HTTPException) as exc:
        service.delete_certificate(cert.certificate_id)
    assert exc.value.status_code == 409
    cert.status = "DRAFT"
    db_session.commit()
    service.delete_certificate(cert.certificate_id)
    items_after, total_after = service.list_certificates()
    assert total_after == 0
