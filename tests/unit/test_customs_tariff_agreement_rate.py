from datetime import date, timedelta
from decimal import Decimal
import pytest
from fastapi import HTTPException
from pydantic import ValidationError
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.customs_tariff.model import CustomsTariff, PreferentialAgreement
from modules.customs_tariff.schemas import (
    CustomsDutyEstimateRequest,
    MultiItemCustomsEstimateRequest,
    MultiItemCustomsEstimateLine,
    OriginDutyCheckRequest,
    PreferentialAgreementCreate,
)
from modules.customs_tariff.service import (
    _agreement_duty_rate,
    estimate_customs_duty_service,
    estimate_multi_item_customs_duty_service,
    evaluate_duty_by_origin_and_document_service,
)
from modules.currencies.model import Currency, ExchangeRate


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    session = TestingSessionLocal()
    try:
        # Seed EGP and USD currencies
        egp = Currency(currency_code="EGP", currency_name="Egyptian Pound", currency_symbol="LE", is_active=True)
        usd = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
        session.add_all([egp, usd])
        session.commit()

        # Seed customs exchange rate for USD
        rate = ExchangeRate(
            currency_id=usd.currency_id,
            commercial_rate=Decimal("50.00"),
            customs_rate=Decimal("50.00"),
            effective_date=date(2026, 1, 1),
            is_active=True,
        )
        session.add(rate)
        session.commit()

        yield session
    finally:
        session.close()


def test_fixed_rate_estimate_customs_duty_service(db_session):
    """Test 1: Fixed rate Mercosur agreement (3.00%) on 30% tariff (8536.41.00) with origin BR."""
    tariff = CustomsTariff(
        hs_code="8536.41.00",
        hs_description="Relays for a voltage not exceeding 60 V",
        customs_duty_rate=Decimal("30.00"),
        vat_rate=Decimal("14.00"),
        schedule_tax_rate=Decimal("0.00"),
        development_fee_rate=Decimal("0.00"),
        import_fee_rate=Decimal("0.00"),
        customs_service_fee_rate=Decimal("0.00"),
        effective_from=date(2025, 1, 1),
        is_active=True,
    )
    db_session.add(tariff)

    ag = PreferentialAgreement(
        hs_code="8536.41.00",
        agreement_name="Mercosur Agreement",
        reduction_type="fixed_rate",
        preferential_duty_rate=Decimal("3.00"),
        origin_countries="BR, AR, PY, UY",
        effective_from=date(2025, 1, 1),
    )
    db_session.add(ag)
    db_session.commit()

    req = CustomsDutyEstimateRequest(
        hs_code="8536.41.00",
        cif_value=Decimal("100000.00"),
        origin_country="BR",
        estimate_date=date(2026, 5, 1),
    )
    res = estimate_customs_duty_service(db_session, req)

    # Duty: 100,000 * 3% = 3,000.00
    # VAT base: 100,000 + 3,000 = 103,000.00
    # VAT: 103,000 * 14% = 14,420.00
    assert res.customs_duty_rate == Decimal("3.00")
    assert res.import_duty_amount == Decimal("3000.00")
    assert res.vat_base == Decimal("103000.00")
    assert res.vat_amount == Decimal("14420.00")
    assert res.trade_agreement_applied == "Mercosur Agreement"


def test_fixed_rate_multi_item_customs_duty_service(db_session):
    """Test 2: Fixed rate Mercosur agreement via multi-item customs duty service."""
    tariff = CustomsTariff(
        hs_code="8536.41.00",
        hs_description="Relays for a voltage not exceeding 60 V",
        customs_duty_rate=Decimal("30.00"),
        vat_rate=Decimal("14.00"),
        schedule_tax_rate=Decimal("0.00"),
        development_fee_rate=Decimal("0.00"),
        import_fee_rate=Decimal("0.00"),
        customs_service_fee_rate=Decimal("0.00"),
        effective_from=date(2025, 1, 1),
        is_active=True,
    )
    db_session.add(tariff)

    ag = PreferentialAgreement(
        hs_code="8536.41.00",
        agreement_name="Mercosur Agreement",
        reduction_type="fixed_rate",
        preferential_duty_rate=Decimal("3.00"),
        origin_countries="BR, AR, PY, UY",
        effective_from=date(2025, 1, 1),
    )
    db_session.add(ag)
    db_session.commit()

    req = MultiItemCustomsEstimateRequest(
        currency="EGP",
        exchange_rate=Decimal("1.00"),
        estimate_date=date(2026, 5, 1),
        cif_declared_total_egp=Decimal("100000.00"),
        lines=[
            MultiItemCustomsEstimateLine(
                line_no=1,
                item_description="Relays",
                hs_code="8536.41.00",
                value_fc=Decimal("100000.00"),
                origin_country="BR",
            )
        ],
        has_insurance_document=True,
        insurance_egp=Decimal("0.00"),
        has_freight_document=True,
        freight_egp=Decimal("0.00"),
    )
    res = estimate_multi_item_customs_duty_service(db_session, req)

    assert len(res.lines) == 1
    line = res.lines[0]
    assert line.customs_duty_rate == Decimal("3.00")
    assert line.duty_egp == Decimal("3000.00")
    assert line.preferential_agreement_applied == "Mercosur Agreement"


def test_fixed_rate_check_duty_for_origin(db_session):
    """Test 3: Fixed rate Mercosur agreement via evaluate_duty_by_origin_and_document_service."""
    tariff = CustomsTariff(
        hs_code="8536.41.00",
        hs_description="Relays",
        customs_duty_rate=Decimal("30.00"),
        vat_rate=Decimal("14.00"),
        effective_from=date(2025, 1, 1),
        is_active=True,
    )
    db_session.add(tariff)

    ag = PreferentialAgreement(
        hs_code="8536.41.00",
        agreement_name="Mercosur Agreement",
        reduction_type="fixed_rate",
        preferential_duty_rate=Decimal("3.00"),
        origin_countries="BR, AR, PY, UY",
        effective_from=date(2025, 1, 1),
    )
    db_session.add(ag)
    db_session.commit()

    # With preferential document
    res_with_doc = evaluate_duty_by_origin_and_document_service(
        db_session,
        OriginDutyCheckRequest(
            hs_code="8536.41.00",
            origin_country="BR",
            has_preferential_document=True,
            check_date=date(2026, 5, 1),
        ),
    )
    assert res_with_doc.base_duty_rate == Decimal("30.00")
    assert res_with_doc.effective_duty_rate == Decimal("3.00")
    assert res_with_doc.has_matching_agreement is True
    assert res_with_doc.document_verified is True

    # Without preferential document -> falls back to base duty
    res_without_doc = evaluate_duty_by_origin_and_document_service(
        db_session,
        OriginDutyCheckRequest(
            hs_code="8536.41.00",
            origin_country="BR",
            has_preferential_document=False,
            check_date=date(2026, 5, 1),
        ),
    )
    assert res_without_doc.base_duty_rate == Decimal("30.00")
    assert res_without_doc.effective_duty_rate == Decimal("30.00")
    assert res_without_doc.has_matching_agreement is True
    assert res_without_doc.document_verified is False


def test_percentage_of_duty_agreement(db_session):
    """Test 4: Percentage of duty agreement (reduction_percentage = 0.10) on 40% duty -> 36.00%."""
    tariff = CustomsTariff(
        hs_code="3925.90.00",
        hs_description="Building plastics",
        customs_duty_rate=Decimal("40.00"),
        vat_rate=Decimal("14.00"),
        effective_from=date(2025, 1, 1),
        is_active=True,
    )
    db_session.add(tariff)

    ag = PreferentialAgreement(
        hs_code="3925.90.00",
        agreement_name="Serbia Agreement",
        reduction_type="percentage_of_duty",
        reduction_percentage=Decimal("0.10"),
        origin_countries="RS",
        effective_from=date(2025, 1, 1),
    )
    db_session.add(ag)
    db_session.commit()

    req = CustomsDutyEstimateRequest(
        hs_code="3925.90.00",
        cif_value=Decimal("100000.00"),
        origin_country="RS",
        estimate_date=date(2026, 5, 1),
    )
    res = estimate_customs_duty_service(db_session, req)

    # Standard 40% * (1 - 0.10) = 36%
    assert res.customs_duty_rate == Decimal("36.00")
    assert res.import_duty_amount == Decimal("36000.00")


def test_agreement_create_schema_validation():
    """Test 5: PreferentialAgreementCreate rejects reduction_percentage > 1.0."""
    # 50 instead of 0.50 should fail validation
    with pytest.raises(ValidationError):
        PreferentialAgreementCreate(
            hs_code="8536.41.00",
            agreement_name="Invalid Agreement",
            reduction_type="percentage_of_duty",
            reduction_percentage=Decimal("50.00"),
            origin_countries="BR",
        )

    # Valid 0.10 should succeed
    ag = PreferentialAgreementCreate(
        hs_code="8536.41.00",
        agreement_name="Valid Agreement",
        reduction_type="percentage_of_duty",
        reduction_percentage=Decimal("0.10"),
        origin_countries="RS",
    )
    assert ag.reduction_percentage == Decimal("0.10")


def test_invalid_agreement_data_raises_422():
    """Test 6: Invalid stored agreement data raises HTTPException 422 with CT_AGREEMENT_DATA_INVALID."""
    # 6a: fixed_rate without preferential_duty_rate
    class DummyFixed:
        reduction_type = "fixed_rate"
        preferential_duty_rate = None

    with pytest.raises(HTTPException) as exc_info:
        _agreement_duty_rate(Decimal("30.00"), DummyFixed())
    assert exc_info.value.status_code == 422
    assert exc_info.value.detail["code"] == "CT_AGREEMENT_DATA_INVALID"

    # 6b: percentage_of_duty with reduction_percentage > 1.0 (legacy dirty data)
    class DummyPercent:
        reduction_type = "percentage_of_duty"
        reduction_percentage = Decimal("50.00")

    with pytest.raises(HTTPException) as exc_info:
        _agreement_duty_rate(Decimal("30.00"), DummyPercent())
    assert exc_info.value.status_code == 422
    assert exc_info.value.detail["code"] == "CT_AGREEMENT_DATA_INVALID"

    # 6c: unknown reduction_type
    class DummyUnknown:
        reduction_type = "something_else"

    with pytest.raises(HTTPException) as exc_info:
        _agreement_duty_rate(Decimal("30.00"), DummyUnknown())
    assert exc_info.value.status_code == 422
    assert exc_info.value.detail["code"] == "CT_AGREEMENT_DATA_INVALID"


def test_expired_agreement_not_applied(db_session):
    """Test 7: Expired agreement is not applied (returns standard rate)."""
    tariff = CustomsTariff(
        hs_code="8536.41.00",
        hs_description="Relays",
        customs_duty_rate=Decimal("30.00"),
        vat_rate=Decimal("14.00"),
        effective_from=date(2020, 1, 1),
        is_active=True,
    )
    db_session.add(tariff)

    # Agreement expired on 2025-12-31
    ag = PreferentialAgreement(
        hs_code="8536.41.00",
        agreement_name="Expired Mercosur",
        reduction_type="fixed_rate",
        preferential_duty_rate=Decimal("3.00"),
        origin_countries="BR",
        effective_from=date(2020, 1, 1),
        effective_to=date(2025, 12, 31),
    )
    db_session.add(ag)
    db_session.commit()

    req = CustomsDutyEstimateRequest(
        hs_code="8536.41.00",
        cif_value=Decimal("100000.00"),
        origin_country="BR",
        estimate_date=date(2026, 5, 1),
    )
    # Estimate date is 2026-05-01 (after expiry)
    res = estimate_customs_duty_service(db_session, req)

    assert res.customs_duty_rate == Decimal("30.00")
    assert res.trade_agreement_applied is None


def test_dotless_hs_code_lookup(db_session):
    """Test 8: Dotted agreement matched by dotless lookup."""
    tariff = CustomsTariff(
        hs_code="85364100",
        hs_description="Relays",
        customs_duty_rate=Decimal("30.00"),
        vat_rate=Decimal("14.00"),
        effective_from=date(2025, 1, 1),
        is_active=True,
    )
    db_session.add(tariff)

    # Agreement stored with dots
    ag = PreferentialAgreement(
        hs_code="8536.41.00",
        agreement_name="Dotted Mercosur",
        reduction_type="fixed_rate",
        preferential_duty_rate=Decimal("3.00"),
        origin_countries="BR",
        effective_from=date(2025, 1, 1),
    )
    db_session.add(ag)
    db_session.commit()

    # Query with dotless hs_code
    req = CustomsDutyEstimateRequest(
        hs_code="85364100",
        cif_value=Decimal("100000.00"),
        origin_country="BR",
        estimate_date=date(2026, 5, 1),
    )
    res = estimate_customs_duty_service(db_session, req)

    assert res.customs_duty_rate == Decimal("3.00")
    assert res.trade_agreement_applied == "Dotted Mercosur"
