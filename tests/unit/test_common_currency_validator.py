"""Unit tests for BEW0-02: require_currency_code helper and CURRENCY_CODE_UNKNOWN."""
import pytest
from fastapi import HTTPException, status
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.common.errors import CodedHTTPException
from modules.common import system_messages as sm
from modules.common.validators import require_currency_code
from modules.currencies.model import Currency


@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine, autoflush=False)
    session = session_factory()

    # Seed currencies
    usd = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
    eur = Currency(currency_code="EUR", currency_name="Euro", currency_symbol="€", is_active=True)
    egp = Currency(currency_code="EGP", currency_name="Egyptian Pound", currency_symbol="EGP", is_active=True, is_base_currency=True)
    old = Currency(currency_code="OLD", currency_name="Old Currency", currency_symbol="O", is_active=False)

    session.add_all([usd, eur, egp, old])
    session.commit()

    yield session

    session.close()
    engine.dispose()


def test_system_message_catalog_registration():
    assert "CURRENCY_CODE_UNKNOWN" in sm.CATALOG
    assert "note" in sm.CATALOG["CURRENCY_CODE_UNKNOWN"]
    rendered = sm.render_en("CURRENCY_CODE_UNKNOWN", {"currency_code": "XYZ"}, "note")
    assert "XYZ" in rendered
    assert "Unknown or inactive currency code" in rendered


def test_none_and_empty_returns_none(db):
    assert require_currency_code(db, None) is None
    assert require_currency_code(db, "") is None
    assert require_currency_code(db, "   ") is None


def test_valid_active_currencies_normalized(db):
    assert require_currency_code(db, "usd") == "USD"
    assert require_currency_code(db, "USD") == "USD"
    assert require_currency_code(db, "  eur ") == "EUR"
    assert require_currency_code(db, "Egp") == "EGP"


def test_unknown_currency_raises_400_coded_exception(db):
    with pytest.raises(HTTPException) as exc_info:
        require_currency_code(db, "XYZ")

    exc = exc_info.value
    assert exc.status_code == status.HTTP_400_BAD_REQUEST
    assert isinstance(exc, CodedHTTPException)
    assert exc.code == "CURRENCY_CODE_UNKNOWN"
    assert exc.params == {"currency_code": "XYZ"}
    assert isinstance(exc.detail, dict)
    assert exc.detail["code"] == "CURRENCY_CODE_UNKNOWN"
    assert "XYZ" in exc.detail["message"]


def test_inactive_currency_raises_400_coded_exception(db):
    with pytest.raises(HTTPException) as exc_info:
        require_currency_code(db, "old")

    exc = exc_info.value
    assert exc.status_code == status.HTTP_400_BAD_REQUEST
    assert isinstance(exc, CodedHTTPException)
    assert exc.code == "CURRENCY_CODE_UNKNOWN"
    assert exc.params == {"currency_code": "OLD"}
    assert exc.detail["code"] == "CURRENCY_CODE_UNKNOWN"
    assert "OLD" in exc.detail["message"]


def test_custom_label_ar(db):
    with pytest.raises(HTTPException) as exc_info:
        require_currency_code(db, "BAD", label_ar="عملة المطالبة")

    exc = exc_info.value
    assert "عملة المطالبة" in exc.detail["message"]
