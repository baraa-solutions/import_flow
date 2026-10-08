from datetime import date, datetime
from decimal import Decimal
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session

from database.database import Base
from modules.currencies.model import Currency, ExchangeRate
from modules.currencies.schemas import CurrencyCreate, ExchangeRateCreate
from modules.currencies.service import CurrencyService, clear_currency_cache
from modules.customs_tariff.service import (
    _customs_rate,
    create_tariff_service,
    estimate_multi_item_customs_duty_service,
)
from modules.customs_tariff.schemas import (
    CustomsTariffCreate,
    MultiItemCustomsEstimateRequest,
    MultiItemCustomsEstimateLine,
)

# Required for foreign key resolution across Base.metadata
from modules.external_service_providers.model import ExternalServiceProvider
from modules.import_files.model import ImportFile
from modules.purchase_orders.model import PurchaseOrder
from modules.financial_approval.model import PaymentRequestSession, ImportBudgetApproval


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    session = TestingSessionLocal()
    clear_currency_cache()
    try:
        yield session
    finally:
        clear_currency_cache()
        session.close()


def test_unregistered_currency_raises_404_currency_not_found(db_session: Session):
    service = CurrencyService(db_session)
    with pytest.raises(HTTPException) as exc_info:
        service.convert_currency(
            amount=100.0,
            from_currency_code="JPY",
            to_currency_code="EGP",
        )
    assert exc_info.value.status_code == 404
    detail = exc_info.value.detail
    assert isinstance(detail, dict)
    assert detail["code"] == "CURRENCY_NOT_FOUND"
    assert detail["currency"] == "JPY"


def test_registered_currency_without_rate_raises_409_currency_rate_missing(db_session: Session):
    service = CurrencyService(db_session)
    # Register USD without any exchange rate rows
    service.create_currency(CurrencyCreate(
        currency_code="USD",
        currency_name="US Dollar",
        currency_symbol="$",
        is_base_currency=False,
    ))

    with pytest.raises(HTTPException) as exc_info:
        service.convert_currency(
            amount=100.0,
            from_currency_code="USD",
            to_currency_code="EGP",
            rate_type="commercial",
            as_of_date=date(2026, 10, 5),
        )
    assert exc_info.value.status_code == 409
    detail = exc_info.value.detail
    assert isinstance(detail, dict)
    assert detail["code"] == "CURRENCY_RATE_MISSING"
    assert detail["currency"] == "USD"
    assert detail["rate_type"] == "commercial"
    assert detail["as_of_date"] == "2026-10-05"


def test_conversion_with_added_rates_commercial_and_customs(db_session: Session):
    service = CurrencyService(db_session)
    usd = service.create_currency(CurrencyCreate(
        currency_code="USD",
        currency_name="US Dollar",
        currency_symbol="$",
        is_base_currency=False,
    ))

    # Add rate USD commercial 50.00 / customs 49.00 effective 2026-10-01
    rate_resp = service.add_exchange_rate(ExchangeRateCreate(
        currency_id=usd.currency_id,
        commercial_rate=50.00,
        customs_rate=49.00,
        effective_date=date(2026, 10, 1),
    ))

    # Convert 100 USD (commercial, as of 2026-10-05)
    resp_comm = service.convert_currency(
        amount=100.0,
        from_currency_code="USD",
        to_currency_code="EGP",
        rate_type="commercial",
        as_of_date=date(2026, 10, 5),
    )
    assert resp_comm.converted_amount == 5000.00
    assert resp_comm.applied_rate == 50.0
    assert resp_comm.exchange_rate_id == rate_resp.rate_id

    # Convert 100 USD (customs, as of 2026-10-05)
    resp_cust = service.convert_currency(
        amount=100.0,
        from_currency_code="USD",
        to_currency_code="EGP",
        rate_type="customs",
        as_of_date=date(2026, 10, 5),
    )
    assert resp_cust.converted_amount == 4900.00
    assert resp_cust.applied_rate == 49.0
    assert resp_cust.exchange_rate_id == rate_resp.rate_id


def test_cross_currency_conversion(db_session: Session):
    service = CurrencyService(db_session)
    usd = service.create_currency(CurrencyCreate(
        currency_code="USD",
        currency_name="US Dollar",
        currency_symbol="$",
        is_base_currency=False,
    ))
    eur = service.create_currency(CurrencyCreate(
        currency_code="EUR",
        currency_name="Euro",
        currency_symbol="€",
        is_base_currency=False,
    ))

    service.add_exchange_rate(ExchangeRateCreate(
        currency_id=usd.currency_id,
        commercial_rate=50.00,
        customs_rate=49.00,
        effective_date=date(2026, 10, 1),
    ))
    service.add_exchange_rate(ExchangeRateCreate(
        currency_id=eur.currency_id,
        commercial_rate=52.80,
        customs_rate=51.50,
        effective_date=date(2026, 10, 1),
    ))

    # Convert 100 USD to EUR: 100 * 50.00 / 52.80 = 94.70, applied_rate = 50.00 / 52.80 = 0.947
    resp = service.convert_currency(
        amount=100.0,
        from_currency_code="USD",
        to_currency_code="EUR",
        rate_type="commercial",
        as_of_date=date(2026, 10, 5),
    )
    assert resp.converted_amount == 94.70
    assert resp.applied_rate == 0.947


def test_rate_miss_is_not_cached(db_session: Session):
    service = CurrencyService(db_session)
    gbp = service.create_currency(CurrencyCreate(
        currency_code="GBP",
        currency_name="British Pound",
        currency_symbol="£",
        is_base_currency=False,
    ))

    # 1. First call fails with 409 because no rate exists
    with pytest.raises(HTTPException) as exc_info:
        service._get_rate_to_egp("GBP", rate_type="commercial", as_of_date=date(2026, 10, 5))
    assert exc_info.value.status_code == 409
    assert exc_info.value.detail["code"] == "CURRENCY_RATE_MISSING"

    # 2. Add rate immediately afterwards
    service.add_exchange_rate(ExchangeRateCreate(
        currency_id=gbp.currency_id,
        commercial_rate=60.00,
        customs_rate=59.00,
        effective_date=date(2026, 10, 1),
    ))

    # 3. Second call must succeed without clearing cache (miss was NOT cached)
    rate_val, eff_date, rate_id = service._get_rate_to_egp("GBP", rate_type="commercial", as_of_date=date(2026, 10, 5))
    assert rate_val == 60.00
    assert eff_date == date(2026, 10, 1)
    assert rate_id is not None


def test_customs_rate_engine_no_rate_raises_422_ct_customs_rate_missing(db_session: Session):
    service = CurrencyService(db_session)
    # USD created but no customs rate
    service.create_currency(CurrencyCreate(
        currency_code="USD",
        currency_name="US Dollar",
        currency_symbol="$",
        is_base_currency=False,
    ))

    # Directly testing _customs_rate helper
    with pytest.raises(HTTPException) as exc_info:
        _customs_rate(db_session, "USD", on_date=date(2026, 10, 5))
    assert exc_info.value.status_code == 422
    assert exc_info.value.detail["code"] == "CT_CUSTOMS_RATE_MISSING"
    assert exc_info.value.detail["currency"] == "USD"
    assert exc_info.value.detail["on_date"] == "2026-10-05"

    create_tariff_service(
        db_session,
        CustomsTariffCreate(
            hs_code="84798990",
            hs_description="Test Machine",
            customs_duty_rate=Decimal("10.00"),
            vat_rate=Decimal("14.00"),
            customs_service_fee_rate=Decimal("1.00"),
        ),
    )

    # Multi-item engine without explicit exchange_rate raises 422
    req = MultiItemCustomsEstimateRequest(
        estimate_date=date(2026, 10, 5),
        currency="USD",
        exchange_rate=None,
        insurance_egp=Decimal("0.00"),
        freight_egp=Decimal("0.00"),
        has_insurance_document=False,
        lines=[
            MultiItemCustomsEstimateLine(
                line_no=1,
                hs_code="84798990",
                value_fc=Decimal("1000.00"),
                item_description="Test Machine",
            )
        ],
    )
    with pytest.raises(HTTPException) as exc_engine:
        estimate_multi_item_customs_duty_service(db_session, req)
    assert exc_engine.value.status_code == 422
    assert exc_engine.value.detail["code"] == "CT_CUSTOMS_RATE_MISSING"


def test_customs_rate_engine_explicit_exchange_rate(db_session: Session):
    create_tariff_service(
        db_session,
        CustomsTariffCreate(
            hs_code="84798990",
            hs_description="Test Machine",
            customs_duty_rate=Decimal("10.00"),
            vat_rate=Decimal("14.00"),
            customs_service_fee_rate=Decimal("1.00"),
            effective_from=date(2026, 1, 1),
        ),
    )
    # When explicit exchange_rate is provided, engine succeeds even without registered rate rows
    req = MultiItemCustomsEstimateRequest(
        estimate_date=date(2026, 10, 5),
        currency="USD",
        exchange_rate=Decimal("50.00"),
        insurance_egp=Decimal("0.00"),
        freight_egp=Decimal("0.00"),
        has_insurance_document=False,
        lines=[
            MultiItemCustomsEstimateLine(
                line_no=1,
                hs_code="84798990",
                value_fc=Decimal("1000.00"),
                item_description="Test Machine",
            )
        ],
    )
    result = estimate_multi_item_customs_duty_service(db_session, req)
    assert result.exchange_rate == Decimal("50.00")
    assert result.fob_value_egp == Decimal("50000.00")
    assert result.grand_total_payable_egp > Decimal("0.00")


def test_customs_rate_engine_registered_rate(db_session: Session):
    service = CurrencyService(db_session)
    usd = service.create_currency(CurrencyCreate(
        currency_code="USD",
        currency_name="US Dollar",
        currency_symbol="$",
        is_base_currency=False,
    ))
    rate_resp = service.add_exchange_rate(ExchangeRateCreate(
        currency_id=usd.currency_id,
        commercial_rate=50.00,
        customs_rate=49.10,
        effective_date=date(2026, 10, 1),
    ))

    create_tariff_service(
        db_session,
        CustomsTariffCreate(
            hs_code="84798990",
            hs_description="Test Machine",
            customs_duty_rate=Decimal("10.00"),
            vat_rate=Decimal("14.00"),
            customs_service_fee_rate=Decimal("1.00"),
            effective_from=date(2026, 1, 1),
        ),
    )

    # _customs_rate helper finds rate
    rate, r_date, r_id = _customs_rate(db_session, "USD", on_date=date(2026, 10, 5))
    assert rate == Decimal("49.10")
    assert r_date == date(2026, 10, 1)
    assert r_id == rate_resp.rate_id

    # estimate_multi uses it
    req = MultiItemCustomsEstimateRequest(
        estimate_date=date(2026, 10, 5),
        currency="USD",
        exchange_rate=None,
        insurance_egp=Decimal("0.00"),
        freight_egp=Decimal("0.00"),
        has_insurance_document=False,
        lines=[
            MultiItemCustomsEstimateLine(
                line_no=1,
                hs_code="84798990",
                value_fc=Decimal("1000.00"),
                item_description="Test Machine",
            )
        ],
    )
    result = estimate_multi_item_customs_duty_service(db_session, req)
    assert result.exchange_rate == Decimal("49.10")
    assert result.exchange_rate_id == rate_resp.rate_id


def test_customs_rate_egp_always_one(db_session: Session):
    rate, r_date, r_id = _customs_rate(db_session, "EGP", on_date=date(2026, 10, 5))
    assert rate == Decimal("1.0")
    assert r_date == date(2026, 10, 5)
    assert r_id is None
