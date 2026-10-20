from datetime import date
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.currencies.model import Currency, ExchangeRate
from modules.currencies.schemas import CurrencyCreate, CurrencyUpdate, ExchangeRateCreate
from modules.currencies.service import CurrencyService
from fastapi import HTTPException

# Import models required for metadata FK resolution
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
    try:
        yield session
    finally:
        session.close()


class TestCurrenciesBackend:

    def test_create_currency_and_rate(self, db_session):
        service = CurrencyService(db_session)
        currency = service.create_currency(CurrencyCreate(
            currency_code="usd",
            currency_name="US Dollar",
            currency_symbol="$",
            is_base_currency=False,
            decimal_places=2,
        ))

        assert currency.currency_id is not None
        assert currency.currency_code == "USD"  # Uppercased

        # Add exchange rate
        rate_resp = service.add_exchange_rate(ExchangeRateCreate(
            currency_id=currency.currency_id,
            commercial_rate=50.25,
            customs_rate=50.10,
            effective_date=date(2026, 8, 8),
        ))

        assert rate_resp.commercial_rate == 50.25
        assert rate_resp.customs_rate == 50.10

        # Retrieve currency with latest rate
        fetched = service.get_currency_by_id(currency.currency_id)
        assert fetched.latest_commercial_rate == 50.25
        assert fetched.latest_customs_rate == 50.10

    def test_duplicate_currency_code_raises_400(self, db_session):
        service = CurrencyService(db_session)
        service.create_currency(CurrencyCreate(currency_code="EUR", currency_name="Euro", currency_symbol="€"))

        with pytest.raises(HTTPException) as exc_info:
            service.create_currency(CurrencyCreate(currency_code="eur", currency_name="Euro Second", currency_symbol="€"))

        assert exc_info.value.status_code == 400
        assert "already exists" in exc_info.value.detail

    def test_soft_delete_and_restore_currency(self, db_session):
        service = CurrencyService(db_session)
        c = service.create_currency(CurrencyCreate(currency_code="GBP", currency_name="British Pound", currency_symbol="£"))

        service.soft_delete_currency(c.currency_id)
        active_list = service.get_all_currencies(include_inactive=False)
        assert len(active_list) == 0

        restored = service.restore_currency(c.currency_id)
        assert restored.is_active is True
        active_list = service.get_all_currencies(include_inactive=False)
        assert len(active_list) == 1

    def test_duplicate_exchange_rate_raises_409_unless_replace(self, db_session):
        service = CurrencyService(db_session)
        currency = service.create_currency(CurrencyCreate(
            currency_code="USD",
            currency_name="US Dollar",
            currency_symbol="$",
            is_base_currency=False,
            decimal_places=2,
        ))

        # Add rate on 2026-10-01 at 48.50
        rate1 = service.add_exchange_rate(ExchangeRateCreate(
            currency_id=currency.currency_id,
            commercial_rate=48.50,
            customs_rate=48.50,
            effective_date=date(2026, 10, 1),
        ))
        assert rate1.commercial_rate == 48.50

        # Adding same rate again without replace -> 409 CURRENCY_RATE_EXISTS
        with pytest.raises(HTTPException) as exc_info:
            service.add_exchange_rate(ExchangeRateCreate(
                currency_id=currency.currency_id,
                commercial_rate=48.60,
                customs_rate=48.60,
                effective_date=date(2026, 10, 1),
                replace=False,
            ))
        assert exc_info.value.status_code == 409
        detail = exc_info.value.detail
        assert isinstance(detail, dict)
        assert detail["code"] == "CURRENCY_RATE_EXISTS"

        # Adding same rate with replace=True -> succeeds, first row inactive, get_rate returns 48.60
        rate2 = service.add_exchange_rate(ExchangeRateCreate(
            currency_id=currency.currency_id,
            commercial_rate=48.60,
            customs_rate=48.60,
            effective_date=date(2026, 10, 1),
            replace=True,
        ))
        assert rate2.commercial_rate == 48.60

        rate_val, eff_date, _ = service._get_rate_to_egp("USD", as_of_date=date(2026, 10, 1))
        assert rate_val == 48.60

        # Verify old row is inactive in DB
        old_row = db_session.query(ExchangeRate).filter(ExchangeRate.rate_id == rate1.rate_id).first()
        assert old_row.is_active is False

    def test_second_base_currency_raises_409(self, db_session):
        service = CurrencyService(db_session)
        service.create_currency(CurrencyCreate(
            currency_code="EGP",
            currency_name="Egyptian Pound",
            currency_symbol="ج.م",
            is_base_currency=True,
            decimal_places=2,
        ))

        # Attempt to create another currency with is_base_currency=True -> 409 CURRENCY_BASE_EXISTS
        with pytest.raises(HTTPException) as exc_info:
            service.create_currency(CurrencyCreate(
                currency_code="USD",
                currency_name="US Dollar",
                currency_symbol="$",
                is_base_currency=True,
                decimal_places=2,
            ))
        assert exc_info.value.status_code == 409
        detail = exc_info.value.detail
        assert isinstance(detail, dict)
        assert detail["code"] == "CURRENCY_BASE_EXISTS"

        # Attempt to update existing currency to is_base_currency=True -> 409 CURRENCY_BASE_EXISTS
        usd = service.create_currency(CurrencyCreate(
            currency_code="USD",
            currency_name="US Dollar",
            currency_symbol="$",
            is_base_currency=False,
            decimal_places=2,
        ))
        with pytest.raises(HTTPException) as exc_info2:
            service.update_currency(usd.currency_id, CurrencyUpdate(is_base_currency=True))
        assert exc_info2.value.status_code == 409
        assert exc_info2.value.detail["code"] == "CURRENCY_BASE_EXISTS"
