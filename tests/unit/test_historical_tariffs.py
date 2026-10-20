"""Unit tests for Historical Rate Cards: Terminals & Carriers (MD-TERM-CARR-001)

Verifies:
1. Terminal creation and retrieval
2. TerminalStorageRate historical resolution (effective_date <= target_date)
3. Carrier creation and retrieval
4. CarrierDemurrageRate historical resolution
5. Unique constraint enforcement on (terminal_id, container_type, effective_date)
6. DemurrageTracking optional linkage to Terminal and Carrier
"""

import pytest
from datetime import date
from sqlalchemy import create_engine
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.demurrage_detention.model import (
    Terminal,
    TerminalStorageRate,
    Carrier,
    CarrierDemurrageRate,
    DemurrageTracking,
)


@pytest.fixture
def session_factory():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    yield sessionmaker(bind=engine, autoflush=False)
    engine.dispose()


@pytest.fixture
def db(session_factory):
    session = session_factory()
    yield session
    session.close()


def test_terminal_and_storage_rate_historical_resolution(db: Session):
    # 1. Create a test terminal
    terminal = Terminal(
        terminal_code="TEST-TERM-01",
        terminal_name="Test Container Terminal",
        terminal_name_en="Test Terminal",
        port_name="Alexandria",
        country_code="EG",
        is_active=True,
    )
    db.add(terminal)
    db.commit()
    db.refresh(terminal)

    # 2. Add two historical rates with different effective dates
    rate_2025 = TerminalStorageRate(
        terminal_id=terminal.terminal_id,
        container_type="40ft DRY",
        free_days=5,
        storage_tiers=[{"from_day": 6, "to_day": 10, "rate_per_day": 30.0}],
        currency="USD",
        effective_date=date(2025, 1, 1),
        is_active=True,
    )
    rate_2026 = TerminalStorageRate(
        terminal_id=terminal.terminal_id,
        container_type="40ft DRY",
        free_days=7,
        storage_tiers=[
            {"from_day": 8, "to_day": 14, "rate_per_day": 36.0},
            {"from_day": 15, "to_day": 21, "rate_per_day": 40.0},
            {"from_day": 22, "to_day": None, "rate_per_day": 45.0},
        ],
        currency="USD",
        effective_date=date(2026, 1, 1),
        is_active=True,
    )
    db.add_all([rate_2025, rate_2026])
    db.commit()

    # Query in 2025 -> should get rate_2025 ($30.0)
    resolved_2025 = (
        db.query(TerminalStorageRate)
        .filter(
            TerminalStorageRate.terminal_id == terminal.terminal_id,
            TerminalStorageRate.container_type == "40ft DRY",
            TerminalStorageRate.effective_date <= date(2025, 6, 1),
            TerminalStorageRate.is_active == True,
        )
        .order_by(TerminalStorageRate.effective_date.desc())
        .first()
    )
    assert resolved_2025 is not None
    assert resolved_2025.free_days == 5
    assert resolved_2025.storage_tiers[0]["rate_per_day"] == 30.0

    # Query in September 2026 -> should get rate_2026 ($36/$40/$45)
    resolved_2026 = (
        db.query(TerminalStorageRate)
        .filter(
            TerminalStorageRate.terminal_id == terminal.terminal_id,
            TerminalStorageRate.container_type == "40ft DRY",
            TerminalStorageRate.effective_date <= date(2026, 9, 28),
            TerminalStorageRate.is_active == True,
        )
        .order_by(TerminalStorageRate.effective_date.desc())
        .first()
    )
    assert resolved_2026 is not None
    assert resolved_2026.free_days == 7
    assert len(resolved_2026.storage_tiers) == 3
    assert resolved_2026.storage_tiers[0]["rate_per_day"] == 36.0
    assert resolved_2026.storage_tiers[2]["rate_per_day"] == 45.0


def test_carrier_and_demurrage_rate_resolution(db: Session):
    # 1. Create a carrier
    carrier = Carrier(
        carrier_code="TEST-MSC",
        carrier_name="MSC Mediterranean Shipping Co",
        scac_code="TMSC",
        is_active=True,
    )
    db.add(carrier)
    db.commit()
    db.refresh(carrier)

    # 2. Add rate card
    dem_rate = CarrierDemurrageRate(
        carrier_id=carrier.carrier_id,
        container_type="40ft DRY",
        demurrage_free_days_standard=14,
        detention_free_days_standard=7,
        demurrage_tiers=[
            {"from_day": 1, "to_day": 7, "rate_per_day": 40.0},
            {"from_day": 8, "to_day": 14, "rate_per_day": 70.0},
            {"from_day": 15, "to_day": 21, "rate_per_day": 120.0},
            {"from_day": 22, "to_day": None, "rate_per_day": 165.0},
        ],
        detention_tiers=[
            {"from_day": 1, "to_day": 7, "rate_per_day": 35.0},
            {"from_day": 8, "to_day": None, "rate_per_day": 70.0},
        ],
        currency="USD",
        effective_date=date(2026, 1, 1),
        is_active=True,
    )
    db.add(dem_rate)
    db.commit()

    # Query for discharge date in 2026-09-28
    resolved = (
        db.query(CarrierDemurrageRate)
        .filter(
            CarrierDemurrageRate.carrier_id == carrier.carrier_id,
            CarrierDemurrageRate.container_type == "40ft DRY",
            CarrierDemurrageRate.effective_date <= date(2026, 9, 28),
            CarrierDemurrageRate.is_active == True,
        )
        .order_by(CarrierDemurrageRate.effective_date.desc())
        .first()
    )
    assert resolved is not None
    assert resolved.demurrage_free_days_standard == 14
    assert len(resolved.demurrage_tiers) == 4
    assert resolved.demurrage_tiers[3]["rate_per_day"] == 165.0


def test_unique_constraint_on_rates(db: Session):
    carrier = Carrier(
        carrier_code="TEST-DUP",
        carrier_name="Duplicate Test Carrier",
        is_active=True,
    )
    db.add(carrier)
    db.commit()

    r1 = CarrierDemurrageRate(
        currency="USD",carrier_id=carrier.carrier_id,
        container_type="40ft DRY",
        demurrage_tiers=[],
        detention_tiers=[],
        effective_date=date(2026, 1, 1),
    )
    db.add(r1)
    db.commit()

    # Adding another rate with same carrier, container_type, and effective_date must raise IntegrityError
    r2 = CarrierDemurrageRate(
        currency="USD",carrier_id=carrier.carrier_id,
        container_type="40ft DRY",
        demurrage_tiers=[],
        detention_tiers=[],
        effective_date=date(2026, 1, 1),
    )
    db.add(r2)
    with pytest.raises(IntegrityError):
        db.commit()
    db.rollback()


def test_demurrage_tracking_terminal_carrier_link(db: Session):
    terminal = Terminal(
        terminal_code="AICTC-TEST",
        terminal_name="Alexandria Container Handling",
        port_name="Alexandria",
        is_active=True,
    )
    carrier = Carrier(
        carrier_code="MSC-TEST",
        carrier_name="MSC Line",
        is_active=True,
    )
    db.add_all([terminal, carrier])
    db.commit()

    tracking = DemurrageTracking(
        tracking_code="DND-TEST-0001",
        carrier_id=carrier.carrier_id,
        terminal_id=terminal.terminal_id,
        carrier_name="MSC Line",
        bill_of_lading_no="BL-TEST-12345",
        port_name="Alexandria",
        discharge_date=date(2026, 9, 28),
        containers=[{"container_no": "MSCU1234567", "container_type": "40ft DRY"}],
        ancillary_fees=[{"fee_type": "INSPECTION", "amount_usd": 64.0}],
        currency="USD",
        exchange_rate=50.0,
        is_active=True,
    )
    db.add(tracking)
    db.commit()
    db.refresh(tracking)

    assert tracking.carrier.carrier_code == "MSC-TEST"
    assert tracking.terminal.terminal_code == "AICTC-TEST"
    assert len(tracking.ancillary_fees) == 1
    assert tracking.ancillary_fees[0]["amount_usd"] == 64.0


def test_simulation_aictc_storage_577_usd():
    """Verifies that 22 days stay with 7 free days under AICTC tiers results in exactly $577 USD:
    Days 8-14 (7 days @ $36 = $252)
    Days 15-21 (7 days @ $40 = $280)
    Day 22 (1 day @ $45 = $45)
    Total = $252 + $280 + $45 = $577 USD
    """
    from modules.demurrage_detention.schemas import DemurrageSimulationRequest, TierRateItem
    from modules.demurrage_detention.service import simulate_demurrage_and_detention

    aictc_tiers = [
        TierRateItem(from_day=8, to_day=14, rate_per_day=36.0),
        TierRateItem(from_day=15, to_day=21, rate_per_day=40.0),
        TierRateItem(from_day=22, to_day=None, rate_per_day=45.0),
    ]

    req = DemurrageSimulationRequest(
        carrier_name="MSC",
        container_type="40ft High Cube",
        containers_count=1,
        demurrage_free_days=21,
        detention_free_days=7,
        port_storage_free_days=7,
        port_storage_daily_rate_egp=250.0,
        storage_tiers=aictc_tiers,
        storage_currency="USD",
        discharge_date=date(2026, 9, 1),
        gate_out_date=date(2026, 9, 23),  # 22 days consumed
        exchange_rate=50.0,
    )

    res = simulate_demurrage_and_detention(req)

    assert res.storage_days_consumed == 22
    assert res.storage_days_overdue == 15
    assert res.storage_fee_fx == 577.0
    assert res.storage_fee_egp == 577.0 * 50.0
    assert len(res.storage_tier_breakdown) == 3
    assert res.storage_tier_breakdown[0]["tier_cost"] == 252.0
    assert res.storage_tier_breakdown[1]["tier_cost"] == 280.0
    assert res.storage_tier_breakdown[2]["tier_cost"] == 45.0


def test_simulation_msc_demurrage_495_usd():
    """Verifies that 24 days stay with 21 agreed free days under MSC demurrage tiers
    applies the punitive Tier 4 ($165/day) for the 3 overdue days (days 22, 23, 24):
    3 days @ $165 = $495 USD
    """
    from modules.demurrage_detention.schemas import DemurrageSimulationRequest, TierRateItem
    from modules.demurrage_detention.service import simulate_demurrage_and_detention

    msc_dem_tiers = [
        TierRateItem(from_day=1, to_day=7, rate_per_day=40.0),
        TierRateItem(from_day=8, to_day=14, rate_per_day=70.0),
        TierRateItem(from_day=15, to_day=21, rate_per_day=120.0),
        TierRateItem(from_day=22, to_day=None, rate_per_day=165.0),
    ]

    req = DemurrageSimulationRequest(
        carrier_name="MSC",
        container_type="40ft High Cube",
        containers_count=1,
        demurrage_free_days=21,
        detention_free_days=7,
        port_storage_free_days=7,
        demurrage_tiers=msc_dem_tiers,
        discharge_date=date(2026, 9, 1),
        gate_out_date=date(2026, 9, 25),  # 24 days consumed
        empty_return_date=date(2026, 9, 25),
        exchange_rate=50.0,
    )

    res = simulate_demurrage_and_detention(req)

    assert res.demurrage_days_consumed == 24
    assert res.demurrage_days_overdue == 3
    assert res.demurrage_fee_fx == 495.0
    assert res.total_fee_fx == 495.0


def test_simulation_imo_dangerous_goods():
    """Verifies IMO containers have reduced storage free days (max 1 day) and 2.0x multiplier."""
    from modules.demurrage_detention.schemas import DemurrageSimulationRequest, TierRateItem
    from modules.demurrage_detention.service import simulate_demurrage_and_detention

    aictc_tiers = [
        TierRateItem(from_day=8, to_day=14, rate_per_day=36.0),
    ]

    req = DemurrageSimulationRequest(
        carrier_name="MSC",
        container_type="40ft High Cube",
        containers_count=1,
        demurrage_free_days=14,
        detention_free_days=7,
        port_storage_free_days=7,
        storage_tiers=aictc_tiers,
        storage_currency="USD",
        is_imo=True,
        discharge_date=date(2026, 9, 1),
        gate_out_date=date(2026, 9, 3),  # 2 days consumed
        exchange_rate=50.0,
    )

    res = simulate_demurrage_and_detention(req)

    # 2 days consumed - 1 IMO free day = 1 overdue day
    assert res.storage_free_days == 1
    assert res.storage_days_overdue == 1
    # 1 day @ $36 * 2.0 (IMO multiplier) = $72.0
    assert res.storage_fee_fx == 72.0


def test_settlement_rows_with_ancillary_fees():
    """Verifies that _settlement_rows generates INV-ANC when ancillary fees are present."""
    from modules.demurrage_detention.service import _settlement_rows

    tracking = DemurrageTracking(
        tracking_code="DND-ANC-001",
        carrier_name="MSC Line",
        port_name="Alexandria Port",
        bill_of_lading_no="BL-ANC-999",
        discharge_date=date(2026, 9, 1),
        currency="USD",
        exchange_rate=50.0,
        total_demurrage_fx=495.0,
        total_detention_fx=0.0,
        total_storage_egp=28850.0,  # 577 USD * 50
        ancillary_fees=[
            {"fee_type": "INSPECTION", "amount_usd": 64.0},
            {"fee_type": "WEIGHING", "amount_usd": 60.0},
        ],
    )

    rows = _settlement_rows(tracking)

    assert len(rows) == 3
    carrier_row, storage_row, anc_row = rows[0], rows[1], rows[2]

    assert carrier_row["invoice_no"] == "INV-DND-DND-ANC-001"
    assert carrier_row["amount_fx"] == 495.0

    assert storage_row["invoice_no"] == "INV-STO-DND-ANC-001"
    assert storage_row["amount_egp"] == 28850.0

    assert anc_row["invoice_no"] == "INV-ANC-DND-ANC-001"
    assert anc_row["amount_fx"] == 124.0  # 64 + 60
    assert anc_row["amount_egp"] == 124.0 * 50.0
    assert anc_row["currency"] == "USD"


def test_terminal_and_carrier_service_crud(db: Session):
    """Tests CRUD lifecycle of Terminals, Carriers, and their historical rate cards."""
    from modules.demurrage_detention.schemas import (
        TerminalCreate,
        TerminalUpdate,
        TerminalStorageRateCreate,
        TierRateItem,
        CarrierCreate,
        CarrierUpdate,
        CarrierDemurrageRateCreate,
    )
    from modules.demurrage_detention.service import (
        create_terminal_service,
        get_terminals_service,
        get_terminal_by_id_service,
        update_terminal_service,
        create_terminal_storage_rate_service,
        get_terminal_storage_rates_service,
        create_carrier_service,
        get_carriers_service,
        get_carrier_by_id_service,
        update_carrier_service,
        create_carrier_demurrage_rate_service,
        get_carrier_demurrage_rates_service,
    )

    # 1. Create Terminal
    term_in = TerminalCreate(
        terminal_code="TMT-SVC-TEST",
        terminal_name="محطة تحيا مصر للاختبار",
        terminal_name_en="Tahya Misr Test Terminal",
        port_name="Alexandria",
        country_code="EG",
        notes="اختبار المحطة",
    )
    term = create_terminal_service(db, term_in, user="test_user")
    assert term.terminal_id is not None
    assert term.terminal_code == "TMT-SVC-TEST"

    # 2. Get & Update Terminal
    term_fetched = get_terminal_by_id_service(db, term.terminal_id)
    assert term_fetched.terminal_name_en == "Tahya Misr Test Terminal"

    term_updated = update_terminal_service(
        db, term.terminal_id, TerminalUpdate(notes="ملاحظات محدثة"), user="test_user"
    )
    assert term_updated.notes == "ملاحظات محدثة"

    # 3. Add Storage Rate to Terminal
    storage_rate_in = TerminalStorageRateCreate(
        container_type="40ft DRY",
        free_days=7,
        storage_tiers=[
            TierRateItem(from_day=8, to_day=14, rate_per_day=36.0),
            TierRateItem(from_day=15, to_day=None, rate_per_day=45.0),
        ],
        currency="USD",
        effective_date=date(2026, 1, 1),
        notes="تعريفة 2026",
    )
    s_rate = create_terminal_storage_rate_service(db, term.terminal_id, storage_rate_in, user="test_user")
    assert s_rate.rate_id is not None
    assert s_rate.free_days == 7

    rates_history = get_terminal_storage_rates_service(db, term.terminal_id)
    assert len(rates_history) == 1
    assert rates_history[0].rate_id == s_rate.rate_id

    # 4. Create Carrier
    carrier_in = CarrierCreate(
        carrier_code="CMA-SVC-TEST",
        carrier_name="CMA CGM Service Test",
        carrier_name_ar="سي إم إيه للاختبار",
        scac_code="CMAT",
        notes="اختبار الخط",
    )
    carr = create_carrier_service(db, carrier_in, user="test_user")
    assert carr.carrier_id is not None
    assert carr.carrier_code == "CMA-SVC-TEST"

    # 5. Get & Update Carrier
    carr_fetched = get_carrier_by_id_service(db, carr.carrier_id)
    assert carr_fetched.carrier_name == "CMA CGM Service Test"

    carr_updated = update_carrier_service(
        db, carr.carrier_id, CarrierUpdate(carrier_name_ar="سي إم إيه المحدثة"), user="test_user"
    )
    assert carr_updated.carrier_name_ar == "سي إم إيه المحدثة"

    # 6. Add Demurrage Rate to Carrier
    dem_rate_in = CarrierDemurrageRateCreate(
        container_type="40ft DRY",
        demurrage_free_days_standard=14,
        detention_free_days_standard=7,
        demurrage_tiers=[
            TierRateItem(from_day=1, to_day=7, rate_per_day=40.0),
            TierRateItem(from_day=8, to_day=None, rate_per_day=80.0),
        ],
        detention_tiers=[
            TierRateItem(from_day=1, to_day=7, rate_per_day=30.0),
            TierRateItem(from_day=8, to_day=None, rate_per_day=60.0),
        ],
        currency="USD",
        effective_date=date(2026, 1, 1),
        notes="تعريفة CMA 2026",
    )
    c_rate = create_carrier_demurrage_rate_service(db, carr.carrier_id, dem_rate_in, user="test_user")
    assert c_rate.rate_id is not None
    assert c_rate.demurrage_free_days_standard == 14

    c_history = get_carrier_demurrage_rates_service(db, carr.carrier_id)
    assert len(c_history) == 1
    assert c_history[0].rate_id == c_rate.rate_id


def test_get_rates_history_service_filtering(db: Session):
    """Tests get_rates_history_service with and without filters."""
    from modules.demurrage_detention.schemas import (
        TerminalCreate,
        TerminalStorageRateCreate,
        CarrierCreate,
        CarrierDemurrageRateCreate,
        TierRateItem,
    )
    from modules.demurrage_detention.service import (
        create_terminal_service,
        create_terminal_storage_rate_service,
        create_carrier_service,
        create_carrier_demurrage_rate_service,
        get_rates_history_service,
    )

    # 1. Setup 2 terminals
    t1 = create_terminal_service(db, TerminalCreate(
        terminal_code="TERM-HIST-1",
        terminal_name="محطة الدخيلة",
        port_name="El Dekheila",
    ))
    t2 = create_terminal_service(db, TerminalCreate(
        terminal_code="TERM-HIST-2",
        terminal_name="محطة الإسكندرية",
        port_name="Alexandria",
    ))

    # 2. Setup 2 carriers
    c1 = create_carrier_service(db, CarrierCreate(
        carrier_code="MSC-HIST-1",
        carrier_name="MSC Mediterranean",
    ))
    c2 = create_carrier_service(db, CarrierCreate(
        carrier_code="MSK-HIST-2",
        carrier_name="Maersk Line",
    ))

    # 3. Add storage rates
    create_terminal_storage_rate_service(db, t1.terminal_id, TerminalStorageRateCreate(
        currency="USD",container_type="40ft DRY",
        free_days=7,
        storage_tiers=[TierRateItem(from_day=8, to_day=None, rate_per_day=35.0)],
        effective_date=date(2026, 1, 1),
    ))
    create_terminal_storage_rate_service(db, t2.terminal_id, TerminalStorageRateCreate(
        currency="USD",container_type="20ft DRY",
        free_days=5,
        storage_tiers=[TierRateItem(from_day=6, to_day=None, rate_per_day=20.0)],
        effective_date=date(2026, 1, 1),
    ))

    # 4. Add demurrage rates
    create_carrier_demurrage_rate_service(db, c1.carrier_id, CarrierDemurrageRateCreate(
        currency="USD",container_type="40ft DRY",
        demurrage_free_days_standard=14,
        detention_free_days_standard=7,
        demurrage_tiers=[TierRateItem(from_day=1, to_day=None, rate_per_day=50.0)],
        detention_tiers=[TierRateItem(from_day=1, to_day=None, rate_per_day=30.0)],
        effective_date=date(2026, 1, 1),
    ))
    create_carrier_demurrage_rate_service(db, c2.carrier_id, CarrierDemurrageRateCreate(
        currency="USD",container_type="20ft DRY",
        demurrage_free_days_standard=10,
        detention_free_days_standard=5,
        demurrage_tiers=[TierRateItem(from_day=1, to_day=None, rate_per_day=30.0)],
        detention_tiers=[TierRateItem(from_day=1, to_day=None, rate_per_day=20.0)],
        effective_date=date(2026, 1, 1),
    ))

    # Query all
    all_rates = get_rates_history_service(db)
    assert len(all_rates["terminal_rates"]) == 2
    assert len(all_rates["carrier_rates"]) == 2

    # Filter by terminal_id
    t1_rates = get_rates_history_service(db, terminal_id=t1.terminal_id)
    assert len(t1_rates["terminal_rates"]) == 1
    assert t1_rates["terminal_rates"][0].terminal_id == t1.terminal_id
    assert len(t1_rates["carrier_rates"]) == 0

    # Filter by carrier_id
    c1_rates = get_rates_history_service(db, carrier_id=c1.carrier_id)
    assert len(c1_rates["carrier_rates"]) == 1
    assert c1_rates["carrier_rates"][0].carrier_id == c1.carrier_id
    assert len(c1_rates["terminal_rates"]) == 0

    # Filter by container_type
    dry20_rates = get_rates_history_service(db, container_type="20ft DRY")
    assert len(dry20_rates["terminal_rates"]) == 1
    assert dry20_rates["terminal_rates"][0].container_type == "20ft DRY"
    assert len(dry20_rates["carrier_rates"]) == 1
    assert dry20_rates["carrier_rates"][0].container_type == "20ft DRY"


def test_calculate_demurrage_detention_service_auto_resolution(db: Session):
    """Tests calculate_demurrage_detention_service automatically resolves effective rate cards based on discharge_date."""
    from modules.demurrage_detention.schemas import (
        TerminalCreate,
        TerminalStorageRateCreate,
        CarrierCreate,
        CarrierDemurrageRateCreate,
        TierRateItem,
        DemurrageSimulationRequest,
    )
    from modules.demurrage_detention.service import (
        create_terminal_service,
        create_terminal_storage_rate_service,
        create_carrier_service,
        create_carrier_demurrage_rate_service,
        calculate_demurrage_detention_service,
    )

    # 1. Setup Carrier with 2025 vs 2026 rates
    carrier = create_carrier_service(db, CarrierCreate(
        carrier_code="ONE-LINE",
        carrier_name="Ocean Network Express",
    ))
    create_carrier_demurrage_rate_service(db, carrier.carrier_id, CarrierDemurrageRateCreate(
        currency="USD",container_type="40ft High Cube",
        demurrage_free_days_standard=10,
        detention_free_days_standard=5,
        demurrage_tiers=[TierRateItem(from_day=1, to_day=None, rate_per_day=40.0)],
        detention_tiers=[TierRateItem(from_day=1, to_day=None, rate_per_day=20.0)],
        effective_date=date(2025, 1, 1),
    ))
    create_carrier_demurrage_rate_service(db, carrier.carrier_id, CarrierDemurrageRateCreate(
        currency="USD",container_type="40ft High Cube",
        demurrage_free_days_standard=14,
        detention_free_days_standard=7,
        demurrage_tiers=[TierRateItem(from_day=1, to_day=None, rate_per_day=50.0)],
        detention_tiers=[TierRateItem(from_day=1, to_day=None, rate_per_day=25.0)],
        effective_date=date(2026, 1, 1),
    ))

    # 2. Setup Terminal with 2025 vs 2026 rates
    terminal = create_terminal_service(db, TerminalCreate(
        terminal_code="HPH-ALEX",
        terminal_name="Hutchison Ports Alexandria",
        port_name="Alexandria Port",
    ))
    create_terminal_storage_rate_service(db, terminal.terminal_id, TerminalStorageRateCreate(
        currency="USD",container_type="40ft High Cube",
        free_days=5,
        storage_tiers=[TierRateItem(from_day=6, to_day=None, rate_per_day=30.0)],
        effective_date=date(2025, 1, 1),
    ))
    create_terminal_storage_rate_service(db, terminal.terminal_id, TerminalStorageRateCreate(
        currency="USD",container_type="40ft High Cube",
        free_days=7,
        storage_tiers=[TierRateItem(from_day=8, to_day=None, rate_per_day=40.0)],
        effective_date=date(2026, 1, 1),
    ))

    # 3. Simulate with 2025 discharge date -> Should pick 2025 rates (dem free=10, stor free=5)
    req_2025 = DemurrageSimulationRequest(
        carrier_id=carrier.carrier_id,
        terminal_id=terminal.terminal_id,
        container_type="40ft High Cube",
        containers_count=1,
        discharge_date=date(2025, 6, 1),
        gate_out_date=date(2025, 6, 15),  # 14 days stay
        empty_return_date=date(2025, 6, 15),
        exchange_rate=50.0,
        ancillary_fees=[
            {"fee_type": "INSPECTION", "amount_usd": 64.0},
        ],
    )
    res_2025 = calculate_demurrage_detention_service(db, req_2025)
    assert res_2025.demurrage_free_days == 10
    assert res_2025.storage_free_days == 5
    # Overdue demurrage: 14 - 10 = 4 days @ $40 = $160
    assert res_2025.demurrage_fee_fx == 160.0
    # Overdue storage: 14 - 5 = 9 days @ $30 = $270
    assert res_2025.storage_fee_fx == 270.0
    # Ancillary fees
    assert res_2025.ancillary_fee_fx == 64.0
    assert res_2025.ancillary_fee_egp == 64.0 * 50.0

    # 4. Simulate with 2026 discharge date -> Should pick 2026 rates (dem free=14, stor free=7)
    req_2026 = DemurrageSimulationRequest(
        carrier_id=carrier.carrier_id,
        terminal_id=terminal.terminal_id,
        container_type="40ft High Cube",
        containers_count=1,
        discharge_date=date(2026, 6, 1),
        gate_out_date=date(2026, 6, 15),  # 14 days stay
        empty_return_date=date(2026, 6, 15),
        exchange_rate=50.0,
    )
    res_2026 = calculate_demurrage_detention_service(db, req_2026)
    assert res_2026.demurrage_free_days == 14
    assert res_2026.storage_free_days == 7
    # Overdue demurrage: 14 - 14 = 0 days
    assert res_2026.demurrage_fee_fx == 0.0
    # Overdue storage: 14 - 7 = 7 days @ $40 = $280
    assert res_2026.storage_fee_fx == 280.0


def test_api_endpoints_terminals_carriers_and_rates_history(session_factory):
    """Tests FastAPI router endpoints for terminals, carriers, and rates-history."""
    from fastapi.testclient import TestClient
    import main
    from database.database import get_db

    session = session_factory()

    def override_get_db():
        try:
            yield session
        finally:
            pass

    main.app.dependency_overrides[get_db] = override_get_db
    try:
        with TestClient(main.app) as client:
            # 1. Create Terminal via API
            term_res = client.post(
                "/api/v1/demurrage-detention/terminals",
                json={
                    "terminal_code": "API-TERM-01",
                    "terminal_name": "محطة تجريبية للـ API",
                    "port_name": "Alexandria",
                    "country_code": "EG",
                },
            )
            assert term_res.status_code == 201
            term_data = term_res.json()
            term_id = term_data["terminal_id"]

            # Add storage rate to terminal
            term_rate_res = client.post(
                f"/api/v1/demurrage-detention/terminals/{term_id}/rates",
                json={
                    "container_type": "40ft DRY",
                    "free_days": 7,
                    "storage_tiers": [{"from_day": 8, "to_day": None, "rate_per_day": 36.0}],
                    "currency": "USD",
                    "effective_date": "2026-01-01",
                },
            )
            assert term_rate_res.status_code == 201

            # 2. Create Carrier via API
            carr_res = client.post(
                "/api/v1/demurrage-detention/carriers",
                json={
                    "carrier_code": "API-CARR-01",
                    "carrier_name": "خط تجريبي للـ API",
                },
            )
            assert carr_res.status_code == 201
            carr_data = carr_res.json()
            carr_id = carr_data["carrier_id"]

            # Add demurrage rate to carrier
            carr_rate_res = client.post(
                f"/api/v1/demurrage-detention/carriers/{carr_id}/rates",
                json={
                    "container_type": "40ft DRY",
                    "demurrage_free_days_standard": 14,
                    "detention_free_days_standard": 7,
                    "demurrage_tiers": [{"from_day": 1, "to_day": None, "rate_per_day": 40.0}],
                    "detention_tiers": [{"from_day": 1, "to_day": None, "rate_per_day": 20.0}],
                    "currency": "USD",
                    "effective_date": "2026-01-01",
                },
            )
            assert carr_rate_res.status_code == 201

            # 3. GET /terminals & /carriers
            get_terms = client.get("/api/v1/demurrage-detention/terminals")
            assert get_terms.status_code == 200
            assert any(t["terminal_id"] == term_id for t in get_terms.json())

            get_carrs = client.get("/api/v1/demurrage-detention/carriers")
            assert get_carrs.status_code == 200
            assert any(c["carrier_id"] == carr_id for c in get_carrs.json())

            # 4. GET /rates-history
            history_res = client.get("/api/v1/demurrage-detention/rates-history")
            assert history_res.status_code == 200
            hist_data = history_res.json()
            assert "terminal_rates" in hist_data
            assert "carrier_rates" in hist_data
            assert any(r["terminal_id"] == term_id for r in hist_data["terminal_rates"])
            assert any(r["carrier_id"] == carr_id for r in hist_data["carrier_rates"])

            # 5. GET /rates-history?terminal_id=...
            term_only_res = client.get(f"/api/v1/demurrage-detention/rates-history?terminal_id={term_id}")
            assert term_only_res.status_code == 200
            assert len(term_only_res.json()["terminal_rates"]) >= 1
            assert len(term_only_res.json()["carrier_rates"]) == 0
    finally:
        main.app.dependency_overrides.clear()
        session.close()



