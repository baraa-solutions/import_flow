"""
Unit tests for BE01-T01:
Broker fees converted to EGP per line via SettlementFx commercial rate.
"""
from datetime import date, datetime, timezone
from decimal import Decimal
import pytest
from fastapi import HTTPException
from pydantic import ValidationError
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.auth.seed_rbac import seed_rbac
from modules.currencies.model import Currency, ExchangeRate
from modules.currencies.service import clear_currency_cache
from modules.customs_consultation.model import CustomsConsultationSession
from modules.customs_consultation.schemas import (
    CustomsConsultationCreate,
    CustomsConsultationUpdate,
    CustomsBrokerQuoteItemCreate,
)
from modules.customs_consultation.service import CustomsConsultationService
from modules.external_service_providers.model import ExternalServiceProvider


@pytest.fixture
def session_factory():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    clear_currency_cache()
    yield sessionmaker(bind=engine, autoflush=False)
    clear_currency_cache()
    engine.dispose()


@pytest.fixture
def db(session_factory):
    session = session_factory()
    seed_rbac(session)

    # Seed base currencies
    egp = Currency(currency_id=1, currency_code="EGP", currency_name="Egyptian Pound", currency_symbol="EGP", is_active=True)
    usd = Currency(currency_id=2, currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
    session.add_all([egp, usd])
    session.commit()

    # Seed broker
    broker = ExternalServiceProvider(
        provider_id=1,
        partner_code="BRK-001",
        partner_name="Speedy Customs Broker",
        partner_type="Customs Broker",
        is_active=True,
    )
    session.add(broker)
    session.commit()

    yield session
    session.close()


def _seed_usd_rate(db, commercial_rate: float = 50.0):
    rate = ExchangeRate(
        currency_id=2,
        commercial_rate=Decimal(str(commercial_rate)),
        customs_rate=Decimal(str(commercial_rate)),
        effective_date=date.today(),
        is_active=True,
    )
    db.add(rate)
    db.commit()
    clear_currency_cache()


def test_be01_t01_broker_fees_converted_to_egp_per_line(db):
    """
    Create with items:
    - EGP 1000 x 1 applicable -> 1000.00 EGP
    - USD 100 x 2 applicable at rate 50.0 -> 10000.00 EGP
    - EGP 500 x 1 not applicable -> ignored
    Total stored broker fees EGP == 11000.00
    """
    _seed_usd_rate(db, commercial_rate=50.0)

    items = [
        CustomsBrokerQuoteItemCreate(
            expense_name="Local Inspection",
            category="Customs",
            unit_price=1000.0,
            currency="EGP",
            qty=1.0,
            is_applicable=True,
        ),
        CustomsBrokerQuoteItemCreate(
            expense_name="Documentation Fee USD",
            category="Customs",
            unit_price=100.0,
            currency="USD",
            qty=2.0,
            is_applicable=True,
        ),
        CustomsBrokerQuoteItemCreate(
            expense_name="Optional Packaging",
            category="Customs",
            unit_price=500.0,
            currency="EGP",
            qty=1.0,
            is_applicable=False,
        ),
    ]

    req = CustomsConsultationCreate(
        title="Consultation 1",
        broker_id=1,
        broker_name="Speedy Customs Broker",
        broker_quote_items=items,
    )

    res = CustomsConsultationService.create_consultation(db, req, modified_by="tester")
    assert res.total_broker_fees_egp == 11000.00

    # Verify directly from database session row
    sess_row = db.query(CustomsConsultationSession).filter(CustomsConsultationSession.consultation_id == res.consultation_id).first()
    assert sess_row is not None
    assert sess_row.total_broker_fees_egp == 11000.00


def test_be01_t01_missing_fx_rate_raises_409(db):
    """
    Same payload with USD quote item but WITHOUT USD exchange rate row
    must raise 409 SETTLEMENT_FX_RATE_MISSING, and persist no session row in DB.
    """
    clear_currency_cache()

    items = [
        CustomsBrokerQuoteItemCreate(
            expense_name="Documentation Fee USD",
            category="Customs",
            unit_price=100.0,
            currency="USD",
            qty=1.0,
            is_applicable=True,
        )
    ]

    req = CustomsConsultationCreate(
        title="Consultation with Missing Rate",
        broker_id=1,
        broker_name="Speedy Customs Broker",
        broker_quote_items=items,
    )

    with pytest.raises(HTTPException) as exc_info:
        CustomsConsultationService.create_consultation(db, req, modified_by="tester")

    assert exc_info.value.status_code == 409
    assert exc_info.value.detail.get("code") == "SETTLEMENT_FX_RATE_MISSING"
    assert exc_info.value.detail.get("currency") == "USD"

    # Confirm no session row was committed to DB
    count = db.query(CustomsConsultationSession).count()
    assert count == 0


def test_be01_t01_client_total_broker_fees_egp_ignored(db):
    """
    Client sends total_broker_fees_egp=99999 with one EGP 300 x 1 line.
    The client value must be ignored and server-computed total stored as 300.0.
    """
    items = [
        CustomsBrokerQuoteItemCreate(
            expense_name="Broker Flat Fee",
            category="Clearance",
            unit_price=300.0,
            currency="EGP",
            qty=1.0,
            is_applicable=True,
        )
    ]

    req = CustomsConsultationCreate(
        title="Consultation Client Value Ignored",
        broker_id=1,
        broker_name="Speedy Customs Broker",
        total_broker_fees_egp=99999.0,
        broker_quote_items=items,
    )

    res = CustomsConsultationService.create_consultation(db, req, modified_by="tester")
    assert res.total_broker_fees_egp == 300.0

    sess_row = db.query(CustomsConsultationSession).filter(CustomsConsultationSession.consultation_id == res.consultation_id).first()
    assert sess_row.total_broker_fees_egp == 300.0


def test_be01_t01_negative_unit_price_validation():
    """
    Negative unit_price in CustomsBrokerQuoteItemCreate must fail validation (ge=0).
    """
    with pytest.raises(ValidationError) as exc_info:
        CustomsBrokerQuoteItemCreate(
            expense_name="Invalid Fee",
            category="Customs",
            unit_price=-5.0,
            currency="EGP",
            qty=1.0,
        )
    errors = exc_info.value.errors()
    assert any(err["loc"] == ("unit_price",) for err in errors)


def test_be01_t01_update_and_clone_recompute_broker_fees(db):
    """
    Updating or cloning a consultation recomputes broker fees in EGP correctly.
    """
    _seed_usd_rate(db, commercial_rate=50.0)

    # 1. Create with EGP 400
    items = [
        CustomsBrokerQuoteItemCreate(
            expense_name="Fee 1",
            category="Clearance",
            unit_price=400.0,
            currency="EGP",
            qty=1.0,
            is_applicable=True,
        )
    ]
    req = CustomsConsultationCreate(
        title="Original",
        broker_id=1,
        broker_name="Speedy Customs Broker",
        broker_quote_items=items,
    )
    created = CustomsConsultationService.create_consultation(db, req, modified_by="tester")
    assert created.total_broker_fees_egp == 400.0

    # 2. Update with USD 50 x 2 (100 USD = 5000 EGP)
    upd_items = [
        CustomsBrokerQuoteItemCreate(
            expense_name="Fee 2 USD",
            category="Clearance",
            unit_price=50.0,
            currency="USD",
            qty=2.0,
            is_applicable=True,
        )
    ]
    upd_req = CustomsConsultationUpdate(broker_quote_items=upd_items)
    updated = CustomsConsultationService.update_consultation(db, created.consultation_id, upd_req, modified_by="tester")
    assert updated.total_broker_fees_egp == 5000.0

    # 3. Clone consultation
    from modules.customs_consultation.schemas import CloneConsultationRequest
    clone_req = CloneConsultationRequest(new_title="Cloned Consultation")
    cloned = CustomsConsultationService.clone_consultation(db, created.consultation_id, clone_req, modified_by="tester")
    assert cloned.total_broker_fees_egp == 5000.0
