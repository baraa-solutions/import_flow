from datetime import date
from decimal import Decimal
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.currencies.model import Currency, ExchangeRate
from modules.currencies.service import clear_currency_cache
from modules.customs_tariff.model import CustomsTariff
from modules.customs_tariff.schemas import (
    MultiItemCustomsEstimateLine,
    MultiItemCustomsEstimateRequest,
)
from modules.customs_tariff.service import estimate_multi_item_customs_duty_service


@pytest.fixture
def db_session():
    clear_currency_cache()
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    session = TestingSessionLocal()
    try:
        # Seed currencies
        egp = Currency(currency_code="EGP", currency_name="Egyptian Pound", currency_symbol="LE", is_active=True)
        usd = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
        eur = Currency(currency_code="EUR", currency_name="Euro", currency_symbol="€", is_active=True)
        session.add_all([egp, usd, eur])
        session.commit()

        # Seed Tariff HS 8471.30.00: duty 10, VAT 14, service fee 1, others 0
        tariff = CustomsTariff(
            hs_code="8471.30.00",
            hs_description="Laptops and portable computers",
            customs_duty_rate=Decimal("10.00"),
            vat_rate=Decimal("14.00"),
            schedule_tax_rate=Decimal("0.00"),
            development_fee_rate=Decimal("0.00"),
            import_fee_rate=Decimal("0.00"),
            customs_service_fee_rate=Decimal("1.00"),
            effective_from=date(2025, 1, 1),
            is_active=True,
        )
        session.add(tariff)
        session.commit()

        yield session
    finally:
        clear_currency_cache()
        session.close()


def test_foreign_freight_converts_at_customs_rate_table(db_session):
    """Test 1: EUR invoice with USD freight resolves USD customs rate from table, never invoice EUR rate."""
    usd = db_session.query(Currency).filter(Currency.currency_code == "USD").one()
    rate = ExchangeRate(
        currency_id=usd.currency_id,
        commercial_rate=Decimal("50.00"),
        customs_rate=Decimal("50.00"),
        effective_date=date(2026, 5, 30),
        is_active=True,
    )
    db_session.add(rate)
    db_session.commit()

    req = MultiItemCustomsEstimateRequest(
        currency="EUR",
        exchange_rate=Decimal("55.00"),
        estimate_date=date(2026, 6, 1),
        insurance_egp=Decimal("27500.00"),
        has_insurance_document=True,
        freight_currency="USD",
        freight_foreign_amount=Decimal("2000.00"),
        has_freight_document=True,
        freight_exchange_rate=None,
        lines=[
            MultiItemCustomsEstimateLine(
                line_no=1,
                item_description="Laptops",
                hs_code="8471.30.00",
                value_fc=Decimal("20000.00"),
            )
        ],
    )
    res = estimate_multi_item_customs_duty_service(db_session, req)

    # FOB: 20,000 * 55 = 1,100,000
    # Freight: 2,000 * 50 = 100,000 (source: "table")
    # Insurance: 27,500
    # CIF: 1,100,000 + 100,000 + 27,500 = 1,227,500
    # Duty (10%): 122,750
    # VAT (14% on 1,227,500 + 122,750 = 1,350,250): 189,035
    # Service fee (1%): 12,275
    # Total taxes: 122,750 + 189,035 + 12,275 = 324,060
    assert res.freight_egp == Decimal("100000.00")
    assert res.freight_rate_source == "table"
    assert res.freight_exchange_rate_used == Decimal("50.00")
    assert res.lines[0].cif_value_egp == Decimal("1227500.00")
    assert res.total_duty_egp == Decimal("122750.00")
    assert res.total_vat_egp == Decimal("189035.00")
    assert res.total_customs_service_fee_egp == Decimal("12275.00")
    assert res.items_taxes_total_egp == Decimal("324060.00")


def test_foreign_freight_manual_override(db_session):
    """Test 2: Explicit freight_exchange_rate uses manual rate and reports source 'manual'."""
    req = MultiItemCustomsEstimateRequest(
        currency="EUR",
        exchange_rate=Decimal("55.00"),
        estimate_date=date(2026, 6, 1),
        insurance_egp=Decimal("27500.00"),
        has_insurance_document=True,
        freight_currency="USD",
        freight_foreign_amount=Decimal("2000.00"),
        has_freight_document=True,
        freight_exchange_rate=Decimal("51.00"),
        lines=[
            MultiItemCustomsEstimateLine(
                line_no=1,
                item_description="Laptops",
                hs_code="8471.30.00",
                value_fc=Decimal("20000.00"),
            )
        ],
    )
    res = estimate_multi_item_customs_duty_service(db_session, req)

    # Freight: 2,000 * 51 = 102,000 (source: "manual")
    assert res.freight_egp == Decimal("102000.00")
    assert res.freight_rate_source == "manual"
    assert res.freight_exchange_rate_used == Decimal("51.00")


def test_foreign_freight_missing_customs_rate_raises_422(db_session):
    """Test 3: Foreign freight with no rate in DB and no manual rate raises 422 CT_CUSTOMS_RATE_MISSING."""
    # No USD exchange rate seeded
    req = MultiItemCustomsEstimateRequest(
        currency="EUR",
        exchange_rate=Decimal("55.00"),
        estimate_date=date(2026, 6, 1),
        insurance_egp=Decimal("27500.00"),
        has_insurance_document=True,
        freight_currency="USD",
        freight_foreign_amount=Decimal("2000.00"),
        has_freight_document=True,
        freight_exchange_rate=None,
        lines=[
            MultiItemCustomsEstimateLine(
                line_no=1,
                item_description="Laptops",
                hs_code="8471.30.00",
                value_fc=Decimal("20000.00"),
            )
        ],
    )
    with pytest.raises(HTTPException) as exc_info:
        estimate_multi_item_customs_duty_service(db_session, req)
    assert exc_info.value.status_code == 422
    assert exc_info.value.detail["code"] == "CT_CUSTOMS_RATE_MISSING"
    assert exc_info.value.detail["currency"] == "USD"


def test_foreign_freight_matching_invoice_currency(db_session):
    """Test 4: When freight_currency matches invoice currency, uses invoice rate and source 'invoice_currency'."""
    req = MultiItemCustomsEstimateRequest(
        currency="USD",
        exchange_rate=Decimal("50.00"),
        estimate_date=date(2026, 6, 1),
        insurance_egp=Decimal("25000.00"),
        has_insurance_document=True,
        freight_currency="USD",
        freight_foreign_amount=Decimal("2000.00"),
        has_freight_document=True,
        freight_exchange_rate=None,
        lines=[
            MultiItemCustomsEstimateLine(
                line_no=1,
                item_description="Laptops",
                hs_code="8471.30.00",
                value_fc=Decimal("20000.00"),
            )
        ],
    )
    res = estimate_multi_item_customs_duty_service(db_session, req)

    # Freight: 2,000 * 50 = 100,000 (source: "invoice_currency")
    assert res.freight_egp == Decimal("100000.00")
    assert res.freight_rate_source == "invoice_currency"
    assert res.freight_exchange_rate_used == Decimal("50.00")


def test_freight_egp_or_deemed_source_is_none(db_session):
    """Test 5: EGP freight and deemed freight report freight_rate_source and freight_exchange_rate_used as None."""
    # 5a: Freight in EGP
    req_egp = MultiItemCustomsEstimateRequest(
        currency="USD",
        exchange_rate=Decimal("50.00"),
        estimate_date=date(2026, 6, 1),
        insurance_egp=Decimal("25000.00"),
        has_insurance_document=True,
        freight_currency="EGP",
        freight_egp=Decimal("15000.00"),
        has_freight_document=True,
        lines=[
            MultiItemCustomsEstimateLine(
                line_no=1,
                item_description="Laptops",
                hs_code="8471.30.00",
                value_fc=Decimal("20000.00"),
            )
        ],
    )
    res_egp = estimate_multi_item_customs_duty_service(db_session, req_egp)
    assert res_egp.freight_egp == Decimal("15000.00")
    assert res_egp.freight_source == "actual"
    assert res_egp.freight_rate_source is None
    assert res_egp.freight_exchange_rate_used is None

    # 5b: Deemed freight (no freight document)
    req_deemed = MultiItemCustomsEstimateRequest(
        currency="USD",
        exchange_rate=Decimal("50.00"),
        estimate_date=date(2026, 6, 1),
        insurance_egp=Decimal("25000.00"),
        has_insurance_document=True,
        freight_currency="USD",
        freight_foreign_amount=Decimal("2000.00"),
        has_freight_document=False,  # forces deemed
        lines=[
            MultiItemCustomsEstimateLine(
                line_no=1,
                item_description="Laptops",
                hs_code="8471.30.00",
                value_fc=Decimal("20000.00"),
            )
        ],
    )
    res_deemed = estimate_multi_item_customs_duty_service(db_session, req_deemed)
    assert res_deemed.freight_source == "deemed"
    assert res_deemed.freight_rate_source is None
    assert res_deemed.freight_exchange_rate_used is None


def test_deemed_freight_does_not_fail_when_unused_freight_currency_has_no_rate(db_session):
    """Test 6: EUR invoice, USD freight, has_freight_document=False, no USD rate -> 200 deemed."""
    # Ensure no ExchangeRate exists for USD
    usd = db_session.query(Currency).filter(Currency.currency_code == "USD").one()
    db_session.query(ExchangeRate).filter(ExchangeRate.currency_id == usd.currency_id).delete()
    db_session.commit()

    req = MultiItemCustomsEstimateRequest(
        currency="EUR",
        exchange_rate=Decimal("55.00"),
        estimate_date=date(2026, 6, 1),
        insurance_egp=Decimal("25000.00"),
        has_insurance_document=True,
        freight_currency="USD",
        freight_foreign_amount=Decimal("234.72"),
        has_freight_document=False,  # Deemed freight
        lines=[
            MultiItemCustomsEstimateLine(
                line_no=1,
                item_description="Laptops",
                hs_code="8471.30.00",
                value_fc=Decimal("20000.00"),
            )
        ],
    )
    res = estimate_multi_item_customs_duty_service(db_session, req)
    assert res.freight_source == "deemed"
    assert res.freight_rate_source is None
    assert res.freight_exchange_rate_used is None

