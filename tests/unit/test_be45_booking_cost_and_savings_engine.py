"""
Unit tests for Session 2: Booking Cost Engine, Freight Separation & Savings Engine
Covers:
- BE45-T01: Automatic USD conversion, decimal quantities, container-type cost resolution.
- ACC3-T02: Keep insurance and storage out of freight total, 422 on insurance charge.
- BE45-T20: Exact savings engine matching against original quotation/scenario.
"""
from datetime import date, datetime, timezone, timedelta
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.currencies.model import Currency, ExchangeRate
from modules.freight_booking.model import ShipmentBooking
from modules.freight_booking.schemas import (
    BookingChargeItem,
    ContainerAllocationItem,
    ShipmentBookingCreate,
    ShipmentBookingUpdate,
)
from modules.freight_booking.service import (
    calculate_transit_time_and_costs,
    create_booking_service,
    update_booking_service,
    get_booking_service,
)
from modules.shipping_scenarios.model import ShippingEvaluationSession, ShippingScenarioItem
from modules.import_files.model import ImportFile


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:", poolclass=StaticPool)
    Base.metadata.create_all(engine)
    session = sessionmaker(bind=engine)()

    # Currencies
    egp = Currency(currency_code="EGP", currency_name="Egyptian Pound", currency_symbol="EGP", is_base_currency=True, is_active=True)
    usd = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
    eur = Currency(currency_code="EUR", currency_name="Euro", currency_symbol="€", is_active=True)
    session.add_all([egp, usd, eur])
    session.commit()

    # Commercial rates: USD = 50.0 EGP, EUR = 55.0 EGP
    # Effective a week back: the service dates by UTC, so a rate dated local 'today' can be in its future.
    today = date.today() - timedelta(days=7)
    usd_rate = ExchangeRate(currency_id=usd.currency_id, commercial_rate=50.0, customs_rate=49.5, effective_date=today, is_active=True)
    eur_rate = ExchangeRate(currency_id=eur.currency_id, commercial_rate=55.0, customs_rate=54.0, effective_date=today, is_active=True)
    session.add_all([usd_rate, eur_rate])

    # Import file
    imp_file = ImportFile(
        import_file_id=1,
        import_file_code="IMP-2026-0001",
        custom_file_number="6701068100",
        company_name="Test Importer Co",
        supplier_name="ABC China",
        owner="Kamal",
        is_active=True,
    )
    session.add(imp_file)

    # Shipping Scenario Session & Items
    scenario_session = ShippingEvaluationSession(
        session_id=10,
        session_code="SES-2026-0001",
        cargo_ready_date=today,
        avg_form4_days=5,
        avg_clearance_days=4,
        is_active=True,
    )
    session.add(scenario_session)
    session.commit()

    scenario_item = ShippingScenarioItem(
        item_id=25,
        session_id=10,
        provider_name="Mediterranean Shipping Company",
        vessel_name="MSC Oscar",
        sailing_date=today,
        estimated_arrival_date=today,
        quotation_currency="USD",
        container_40ft_applicable=True,
        container_40ft_price=2200.0,
        container_40ft_currency="USD",
        container_20ft_applicable=True,
        container_20ft_price=1300.0,
        container_20ft_currency="USD",
        lcl_cbm_applicable=True,
        lcl_cbm_price=85.0,
        lcl_cbm_currency="USD",
        solas_vgm_applicable=True,
        solas_vgm_price=30.0,
        dthc_applicable=True,
        dthc_price=350.0,
        storage_per_week_applicable=True,
        storage_per_week_price=200.0,
        insurance_applicable=True,
        insurance_price=400.0,
    )
    session.add(scenario_item)
    session.commit()

    yield session
    session.close()


# ─── BE45-T01: Decimal Quantity & Multi-Currency USD Conversion ──────────────

def test_decimal_quantity_in_container_allocation(db_session):
    """ContainerAllocationItem supports fractional quantities (e.g. 1.5, 0.5 containers or shared slots)."""
    payload = ShipmentBookingCreate(
        shipment_type="Ocean FCL",
        containers_data=[
            ContainerAllocationItem(container_type="40HC", quantity=1.5),
        ],
        cost_charges_data=[
            BookingChargeItem(charge_type="Sea Freight", unit="Per Container", container_type="40HC", rate=2000.0, currency="USD"),
        ],
    )
    booking = create_booking_service(db_session, payload)
    assert booking.containers_data[0]["quantity"] == 1.5
    # 1.5 * 2000 = 3000.0 USD
    assert booking.total_freight_cost_usd == 3000.0
    assert booking.cost_charges_data[0]["quantity"] == 1.5
    assert booking.cost_charges_data[0]["total"] == 3000.0


def test_decimal_quantity_in_lcl_cbm_freight(db_session):
    """Charge quantities with decimal values (e.g. 14.75 CBM @ 60 USD/CBM) compute exact totals."""
    payload = ShipmentBookingCreate(
        shipment_type="Ocean LCL",
        cost_charges_data=[
            BookingChargeItem(charge_type="LCL Ocean Freight", unit="Per CBM", quantity=14.75, rate=60.0, currency="USD"),
        ],
    )
    booking = create_booking_service(db_session, payload)
    assert booking.total_freight_cost_usd == 885.0
    assert booking.cost_charges_data[0]["quantity"] == 14.75
    assert booking.cost_charges_data[0]["total"] == 885.0


def test_automatic_usd_conversion_from_mixed_currencies(db_session):
    """
    Charges in mixed currencies (USD, EUR, EGP) automatically convert to USD:
    - Sea Freight: 2000 USD (fx 1.0) -> 2000 USD
    - Documentation: 100 EUR (fx 55/50 = 1.1) -> 110 USD
    - Local Admin: 5000 EGP (fx 1/50 = 0.02) -> 100 USD
    Total = 2210.0 USD.
    """
    payload = ShipmentBookingCreate(
        shipment_type="Ocean FCL",
        containers_data=[ContainerAllocationItem(container_type="20GP", quantity=1)],
        cost_charges_data=[
            BookingChargeItem(charge_type="Sea Freight", unit="Per Container", container_type="20GP", rate=2000.0, currency="USD"),
            BookingChargeItem(charge_type="Documentation Fee", unit="Per Shipment", quantity=1, rate=100.0, currency="EUR"),
            BookingChargeItem(charge_type="Local Admin Fee", unit="Per Shipment", quantity=1, rate=5000.0, currency="EGP"),
        ],
    )
    booking = create_booking_service(db_session, payload)
    assert booking.total_freight_cost_usd == 2210.0
    charges = booking.cost_charges_data
    assert charges[0]["amount_usd"] == 2000.0
    assert charges[1]["amount_usd"] == 110.0
    assert charges[2]["amount_usd"] == 100.0


def test_container_type_specific_cost_determination(db_session):
    """Per Container charges with container_type multiply by that container type's specific count."""
    payload = ShipmentBookingCreate(
        shipment_type="Ocean FCL",
        containers_data=[
            ContainerAllocationItem(container_type="40HC", quantity=3),
            ContainerAllocationItem(container_type="20GP", quantity=2),
        ],
        cost_charges_data=[
            BookingChargeItem(charge_type="Sea Freight 40ft", unit="Per Container", container_type="40HC", rate=2500.0, currency="USD"),
            BookingChargeItem(charge_type="Sea Freight 20ft", unit="Per Container", container_type="20GP", rate=1500.0, currency="USD"),
            BookingChargeItem(charge_type="SOLAS VGM", unit="Per Container", rate=20.0, currency="USD"),
        ],
    )
    booking = create_booking_service(db_session, payload)
    # 40HC: 3 * 2500 = 7500
    # 20GP: 2 * 1500 = 3000
    # SOLAS (no container_type): (3 + 2) * 20 = 100
    # Total = 10600.0 USD
    assert booking.total_freight_cost_usd == 10600.0
    charges = booking.cost_charges_data
    assert charges[0]["quantity"] == 3.0
    assert charges[0]["total"] == 7500.0
    assert charges[1]["quantity"] == 2.0
    assert charges[1]["total"] == 3000.0
    assert charges[2]["quantity"] == 5.0
    assert charges[2]["total"] == 100.0


def test_unknown_container_type_in_charges_raises_422(db_session):
    """Charge referencing a container_type not present in containers_data raises 422."""
    payload = ShipmentBookingCreate(
        shipment_type="Ocean FCL",
        containers_data=[ContainerAllocationItem(container_type="40HC", quantity=1)],
        cost_charges_data=[
            BookingChargeItem(charge_type="Sea Freight", unit="Per Container", container_type="20GP", rate=1200.0, currency="USD"),
        ],
    )
    with pytest.raises(HTTPException) as exc:
        create_booking_service(db_session, payload)
    assert exc.value.status_code == 422
    assert "20GP" in exc.value.detail
    assert "غير موجود في توزيع الحاويات" in exc.value.detail


# ─── ACC3-T02: Insurance Rejection & Freight / Storage Separation ─────────────

def test_insurance_charge_rejected_on_create(db_session):
    """Booking charge with charge_category=INSURANCE or charge_type containing insurance raises 422."""
    payload = ShipmentBookingCreate(
        shipment_type="Ocean FCL",
        containers_data=[ContainerAllocationItem(container_type="40HC", quantity=1)],
        cost_charges_data=[
            BookingChargeItem(charge_type="Marine Insurance", unit="Per Policy", quantity=1, rate=350.0, currency="USD"),
        ],
    )
    with pytest.raises(HTTPException) as exc:
        create_booking_service(db_session, payload)
    assert exc.value.status_code == 422
    assert "التأمين البحري يُسجل في شاشة وثائق التأمين وليس ضمن تكاليف الحجز." in exc.value.detail


def test_storage_and_insurance_separated_from_freight_total(db_session):
    """
    Storage charges are kept in booking.cost_charges_data for transparency,
    but EXCLUDED from total_freight_cost_usd to prevent double-counting in customs CIF and financial settlement.
    """
    payload = ShipmentBookingCreate(
        shipment_type="Ocean FCL",
        containers_data=[ContainerAllocationItem(container_type="40HC", quantity=2)],
        cost_charges_data=[
            BookingChargeItem(charge_type="Sea Freight 40ft", unit="Per Container", container_type="40HC", rate=2000.0, currency="USD"),
            BookingChargeItem(charge_type="DTHC", unit="Per Shipment", quantity=1, rate=350.0, currency="USD"),
            BookingChargeItem(charge_type="Storage per one week", unit="Per Week", quantity=1, rate=250.0, currency="USD"),
            BookingChargeItem(charge_type="Extra day storage", unit="Per Day", quantity=3, rate=50.0, currency="USD"),
        ],
    )
    booking = create_booking_service(db_session, payload)
    # Ocean freight: 2 * 2000 = 4000
    # DTHC: 350
    # Total Freight Cost USD: 4350.0 (Storage 250 + 150 = 400 is EXCLUDED)
    assert booking.total_freight_cost_usd == 4350.0
    # Storage cost is tracked in quotation_details_data
    assert booking.quotation_details_data["storage_cost_usd"] == 400.0
    assert booking.quotation_details_data["freight_net_cost_usd"] == 4350.0
    assert len(booking.cost_charges_data) == 4


def test_legacy_insurance_and_storage_recalc_excludes_from_total(db_session):
    """Recalculating a legacy booking with an insurance line skips insurance and storage in total_freight_cost_usd."""
    legacy = ShipmentBooking(
        booking_code="BKG-LEGACY-INS-01",
        shipment_type="Ocean FCL",
        status="Draft",
        is_active=True,
        total_freight_cost_usd=2800.0,  # Legacy total that included insurance (350) and storage (200)
        containers_data=[{"container_type": "40HC", "quantity": 1}],
        cost_charges_data=[
            {"charge_type": "Sea Freight 40ft", "unit": "Per Container", "quantity": 1, "rate": 2000.0, "total": 2000.0, "currency": "USD", "amount_usd": 2000.0, "charge_category": "FREIGHT"},
            {"charge_type": "DTHC", "unit": "Per Shipment", "quantity": 1, "rate": 250.0, "total": 250.0, "currency": "USD", "amount_usd": 250.0, "charge_category": "DESTINATION_LOCAL"},
            {"charge_type": "Storage per week", "unit": "Per Week", "quantity": 1, "rate": 200.0, "total": 200.0, "currency": "USD", "amount_usd": 200.0, "charge_category": "STORAGE"},
            {"charge_type": "Marine Insurance", "unit": "Per Policy", "quantity": 1, "rate": 350.0, "total": 350.0, "currency": "USD", "amount_usd": 350.0, "charge_category": "INSURANCE"},
        ],
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )
    db_session.add(legacy)
    db_session.commit()

    calculate_transit_time_and_costs(legacy, db=db_session)
    # Pure freight total = 2000 + 250 = 2250.0 USD (insurance 350 and storage 200 excluded)
    assert legacy.total_freight_cost_usd == 2250.0
    assert legacy.quotation_details_data["storage_cost_usd"] == 200.0
    assert legacy.quotation_details_data["insurance_cost_usd"] == 350.0


# ─── BE45-T20: Savings Engine Freight Matching ────────────────────────────────

def test_savings_engine_matches_only_pure_freight_charges(db_session):
    """
    BE45-T20: Savings engine matches only pure ocean/air freight charges.
    Local surcharges (e.g. THC 40HC, SOLAS VGM 40ft) must NEVER enter the savings breakdown.
    """
    payload = ShipmentBookingCreate(
        shipment_type="Ocean FCL",
        containers_data=[ContainerAllocationItem(container_type="40HC", quantity=2)],
        quotation_details_data={
            "original_quote_total_usd": 4800.0,
            "original_container_40ft_price": 2400.0,
        },
        cost_charges_data=[
            # Executed ocean freight: negotiated from 2400 to 2000 (diff 400 * 2 = 800 savings)
            BookingChargeItem(charge_type="Sea Freight 40ft", unit="Per Container", container_type="40HC", rate=2000.0, currency="USD"),
            # THC mentioning 40HC: should NOT be matched as ocean freight!
            BookingChargeItem(charge_type="THC 40HC", unit="Per Container", quantity=2, rate=150.0, currency="USD"),
            # DTHC: should NOT enter savings breakdown
            BookingChargeItem(charge_type="DTHC Destination THC", unit="Per Shipment", quantity=1, rate=300.0, currency="USD"),
        ],
    )
    booking = create_booking_service(db_session, payload)
    # Total Freight Cost USD = (2000 * 2) + (150 * 2) + 300 = 4600.0 USD
    assert booking.total_freight_cost_usd == 4600.0
    # Original quote total was 4800.0 USD -> variance = 4800 - 4600 = 200.0 USD
    assert booking.original_freight_cost_usd == 4800.0
    assert booking.cost_variance_usd == 200.0
    assert booking.cost_savings_usd == 200.0

    breakdown = booking.quotation_details_data.get("savings_breakdown", [])
    # Only Sea Freight 40ft must enter the breakdown; THC and DTHC must NOT be in breakdown
    assert len(breakdown) == 1
    assert breakdown[0]["charge_type"] == "Sea Freight 40ft"
    assert breakdown[0]["unit_label"] == "40ft Container"
    assert breakdown[0]["original_rate"] == 2400.0
    assert breakdown[0]["executed_rate"] == 2000.0
    assert breakdown[0]["unit_diff"] == 400.0
    assert breakdown[0]["quantity"] == 2.0
    assert breakdown[0]["subtotal_savings"] == 800.0


def test_savings_engine_linked_to_scenario_item(db_session):
    """
    Savings engine resolves rates from linked ShippingScenarioItem (item_id=25):
    - 40ft quote rate in scenario = 2200.0 USD
    - Executed 40ft rate = 1950.0 USD x 2 containers -> diff = 250 x 2 = 500 USD savings
    """
    payload = ShipmentBookingCreate(
        scenario_session_id=10,
        scenario_item_id=25,
        shipment_type="Ocean FCL",
        containers_data=[ContainerAllocationItem(container_type="40HC", quantity=2)],
        cost_charges_data=[
            BookingChargeItem(charge_type="Sea Freight 40HC", unit="Per Container", container_type="40HC", rate=1950.0, currency="USD"),
        ],
    )
    booking = create_booking_service(db_session, payload)
    # Scenario 40ft rate was 2200.0 USD
    breakdown = booking.quotation_details_data.get("savings_breakdown", [])
    assert len(breakdown) == 1
    assert breakdown[0]["original_rate"] == 2200.0
    assert breakdown[0]["executed_rate"] == 1950.0
    assert breakdown[0]["unit_diff"] == 250.0
    assert breakdown[0]["quantity"] == 2.0
    assert breakdown[0]["subtotal_savings"] == 500.0
    assert "Sea Freight 40HC" in booking.savings_notes
    assert "$500.00 USD" in booking.savings_notes
