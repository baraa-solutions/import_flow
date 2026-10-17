import pytest
from datetime import date, timedelta
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.common.system_parameters import (
    SystemParameter,
    seed_default_parameters,
)
from modules.currencies.model import Currency, ExchangeRate
from modules.currencies.schemas import CurrencyCreate, ExchangeRateCreate
from modules.currencies.service import CurrencyService
from modules.demurrage_detention.schemas import (
    ContainerItemInput,
    DemurragePolicyCreate,
    DemurragePolicyUpdate,
    DemurrageTrackingCreate,
    DemurrageTrackingUpdate,
    TierRateItem,
)
from modules.demurrage_detention.service import (
    create_demurrage_policy_service,
    create_demurrage_tracking_service,
    default_tariff,
    recalculate_and_update_tracking_service,
    update_demurrage_policy_service,
)


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


def test_tracking_currency_follows_policy(db_session):
    """
    Worked example: EUR policy with 100 EUR/day, 5 overdue days, EUR rate 54 on discharge date ->
    currency == 'EUR', exchange_rate == 54.0, total_cost_egp == 27000.00.
    """
    # 1. Setup EUR currency and rate 54.0 on discharge date (2026-08-01)
    curr_svc = CurrencyService(db_session)
    eur = curr_svc.create_currency(CurrencyCreate(
        currency_code="EUR",
        currency_name="Euro",
        currency_symbol="€",
    ))
    curr_svc.add_exchange_rate(ExchangeRateCreate(
        currency_id=eur.currency_id,
        commercial_rate=54.0,
        customs_rate=53.0,
        effective_date=date(2026, 8, 1),
        created_by="Admin",
    ))

    # 2. Setup EUR carrier policy (100 EUR/day, 14 free days demurrage, 0 storage rate)
    policy = create_demurrage_policy_service(
        db_session,
        DemurragePolicyCreate(
            carrier_name="Hapag-Lloyd",
            container_type="40ft High Cube",
            demurrage_free_days=14,
            detention_free_days=7,
            port_storage_free_days=5,
            port_storage_daily_rate_egp=0.0,
            currency="EUR",
            demurrage_tiers=[TierRateItem(from_day=1, to_day=None, rate_per_day=100.0)],
            detention_tiers=[TierRateItem(from_day=1, to_day=None, rate_per_day=80.0)],
        ),
    )
    assert policy.currency == "EUR"

    # 3. Create tracking with omitted currency (19 days in port - 14 free = 5 overdue days)
    track_in = DemurrageTrackingCreate(
        carrier_name="Hapag-Lloyd",
        bill_of_lading_no="HLX123456",
        port_name="Alexandria Port",
        discharge_date=date(2026, 8, 1),
        gate_out_date=date(2026, 8, 20),
        empty_return_date=date(2026, 8, 25),
        containers=[ContainerItemInput(container_no="HLXU9999999", container_type="40ft High Cube")],
        currency=None,  # omitted / null -> inherits policy currency
    )
    tracking = create_demurrage_tracking_service(db_session, track_in, user="test_user")

    # 4. Assertions: 5 overdue days * 100 EUR = 500 EUR; 500 EUR * 54.0 = 27000.00 EGP
    assert tracking.currency == "EUR"
    assert tracking.exchange_rate == 54.0
    assert tracking.total_demurrage_fx == 500.0
    assert tracking.total_detention_fx == 0.0
    assert tracking.total_storage_egp == 0.0
    assert tracking.total_cost_egp == 27000.00

    # 5. Policy currency changed after creation: recalculation keeps stored tracking currency
    update_demurrage_policy_service(db_session, policy.policy_id, DemurragePolicyUpdate(currency="USD"))
    recalculated = recalculate_and_update_tracking_service(
        db_session,
        tracking.tracking_id,
        DemurrageTrackingUpdate(notes="Recalculated after policy currency update"),
    )
    assert recalculated.currency == "EUR"
    assert recalculated.exchange_rate == 54.0
    assert recalculated.total_cost_egp == 27000.00


def test_tracking_currency_mismatch_422(db_session):
    """
    Creating a tracking with a currency that differs from the carrier tariff policy raises 422.
    """
    create_demurrage_policy_service(
        db_session,
        DemurragePolicyCreate(
            carrier_name="MSC",
            container_type="40ft High Cube",
            demurrage_free_days=14,
            detention_free_days=7,
            port_storage_free_days=5,
            port_storage_daily_rate_egp=250.0,
            currency="EUR",
        ),
    )

    track_in = DemurrageTrackingCreate(
        carrier_name="MSC",
        bill_of_lading_no="MSCU123456",
        port_name="Alexandria Port",
        discharge_date=date(2026, 8, 1),
        containers=[ContainerItemInput(container_no="MSCU1111111", container_type="40ft High Cube")],
        currency="USD",  # Mismatched currency
    )

    with pytest.raises(HTTPException) as exc_info:
        create_demurrage_tracking_service(db_session, track_in, user="test_user")

    assert exc_info.value.status_code == 422
    assert "عملة جلسة التتبع (USD) تختلف عن عملة سياسة الخط الملاحي (EUR)." in exc_info.value.detail


def test_default_tariff_currency_parameter(db_session):
    """
    Default tariff currency comes from system parameter DD_DEFAULT_TARIFF_CURRENCY (default USD).
    """
    tariff = default_tariff(db_session)
    assert tariff.currency == "USD"

    # Setup EUR currency and rate for tracking fallback
    curr_svc = CurrencyService(db_session)
    eur = curr_svc.create_currency(CurrencyCreate(
        currency_code="EUR",
        currency_name="Euro",
        currency_symbol="€",
    ))
    curr_svc.add_exchange_rate(ExchangeRateCreate(
        currency_id=eur.currency_id,
        commercial_rate=54.0,
        customs_rate=53.0,
        effective_date=date(2026, 8, 1),
        created_by="Admin",
    ))

    # Update system parameter to EUR
    param = db_session.query(SystemParameter).filter(
        SystemParameter.param_key == "DD_DEFAULT_TARIFF_CURRENCY"
    ).first()
    assert param is not None
    param.param_value = "EUR"
    db_session.commit()

    tariff_eur = default_tariff(db_session)
    assert tariff_eur.currency == "EUR"

    # Tracking without carrier policy inherits EUR from default tariff
    track_in = DemurrageTrackingCreate(
        carrier_name="Unknown Line Without Policy",
        bill_of_lading_no="UNK123456",
        port_name="Alexandria Port",
        discharge_date=date(2026, 8, 1),
        containers=[ContainerItemInput(container_no="UNKU1111111", container_type="40ft High Cube")],
        currency=None,
    )
    tracking = create_demurrage_tracking_service(db_session, track_in, user="test_user")
    assert tracking.currency == "EUR"
    assert tracking.exchange_rate == 54.0
