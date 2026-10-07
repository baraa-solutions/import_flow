"""
Unit Tests for Multi-Currency Engine & FX Gain/Loss Processing
"""

import pytest
from datetime import date
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session

from database.database import Base
from modules.currencies.model import Currency, ExchangeRate
from modules.currencies.service import CurrencyService
from modules.currencies.schemas import (
    CurrencyCreate,
    ExchangeRateCreate,
    CurrencyConversionRequest,
    ExchangeGainLossRequest,
)

# Import models required for metadata FK resolution
from modules.external_service_providers.model import ExternalServiceProvider
from modules.import_files.model import ImportFile
from modules.purchase_orders.model import PurchaseOrder
from modules.financial_approval.model import PaymentRequestSession, ImportBudgetApproval

SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"
engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="module")
def db_session():
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    c_usd = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_base_currency=False, is_active=True)
    c_eur = Currency(currency_code="EUR", currency_name="Euro", currency_symbol="€", is_base_currency=False, is_active=True)
    db.add_all([c_usd, c_eur])
    db.commit()
    r_usd = ExchangeRate(currency_id=c_usd.currency_id, commercial_rate=48.50, customs_rate=48.50, effective_date=date(2026, 1, 1), is_active=True)
    r_eur = ExchangeRate(currency_id=c_eur.currency_id, commercial_rate=52.80, customs_rate=52.80, effective_date=date(2026, 1, 1), is_active=True)
    db.add_all([r_usd, r_eur])
    db.commit()
    yield db
    db.close()


def test_currency_conversion_usd_to_egp(db_session: Session):
    service = CurrencyService(db_session)

    # 1. Test direct conversion USD -> EGP
    resp = service.convert_currency(
        amount=100.0,
        from_currency_code="USD",
        to_currency_code="EGP",
        rate_type="commercial",
    )

    assert resp.amount == 100.0
    assert resp.from_currency_code == "USD"
    assert resp.to_currency_code == "EGP"
    assert resp.converted_amount > 0
    assert resp.base_currency_equivalent_egp == resp.converted_amount
    assert "تم تحويل 100.00 USD" in resp.summary_ar


def test_currency_conversion_cross_rates(db_session: Session):
    service = CurrencyService(db_session)

    # Test EUR -> USD cross rate
    resp = service.convert_currency(
        amount=1000.0,
        from_currency_code="EUR",
        to_currency_code="USD",
        rate_type="commercial",
    )

    assert resp.amount == 1000.0
    assert resp.from_currency_code == "EUR"
    assert resp.to_currency_code == "USD"
    assert resp.converted_amount > 0
    # EUR (52.80) to USD (48.50) => ~ 1088.66 USD
    assert resp.converted_amount > 1000.0


def test_exchange_gain_calculation(db_session: Session):
    service = CurrencyService(db_session)

    # PO booked at 49.00 EGP/USD, settled at 47.50 EGP/USD (Rate dropped = Saved EGP = GAIN)
    resp = service.calculate_gain_loss(
        foreign_amount=10000.0,
        currency_code="USD",
        initial_rate=49.00,
        settlement_rate=47.50,
    )

    assert resp.foreign_amount == 10000.0
    assert resp.initial_amount_egp == 490000.0
    assert resp.settlement_amount_egp == 475000.0
    assert resp.variance_egp == -15000.0
    assert resp.is_gain is True
    assert resp.status_label == "ربح فروق عملة"
    assert "انخفاض سعر الصرف حقق وفر" in resp.summary_ar


def test_exchange_loss_calculation(db_session: Session):
    service = CurrencyService(db_session)

    # PO booked at 47.50 EGP/USD, settled at 50.00 EGP/USD (Rate increased = Paid extra EGP = LOSS)
    resp = service.calculate_gain_loss(
        foreign_amount=10000.0,
        currency_code="USD",
        initial_rate=47.50,
        settlement_rate=50.00,
    )

    assert resp.foreign_amount == 10000.0
    assert resp.initial_amount_egp == 475000.0
    assert resp.settlement_amount_egp == 500000.0
    assert resp.variance_egp == 25000.0
    assert resp.is_gain is False
    assert resp.status_label == "خسارة فروق عملة"
    assert "ارتفاع سعر الصرف سبب زيادة تكلفة" in resp.summary_ar


def test_invalid_conversion_amount_raises_error(db_session: Session):
    service = CurrencyService(db_session)

    with pytest.raises(HTTPException) as exc_info:
        service.convert_currency(amount=-50.0, from_currency_code="USD")

    assert exc_info.value.status_code == 422
