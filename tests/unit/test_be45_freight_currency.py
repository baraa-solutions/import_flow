"""Tests for BE45-T01: Currency-aware freight totals & container-type/decimal quantities (absorbs ACC3-T01).

Verifies:
1. Mixed currencies are converted to USD at the commercial rate:
   - USD charges keep fx_rate_to_usd = 1.0, amount_usd = item_total.
   - EGP charges convert to USD using 1 / USD_rate_to_egp.
   - EUR charges convert to USD using EUR_rate_to_egp / USD_rate_to_egp.
2. Missing exchange rate raises 409 (CURRENCY_RATE_MISSING).
3. Unknown currency code raises 422.
4. Container-specific charges:
   - "Per Container" charge with container_type uses only that container type's count.
   - "Per Container" charge without container_type uses total container count.
   - Unknown container_type raises 422.
5. Decimal quantities (e.g. LCL 12.3 CBM @ 45) calculate exact decimal totals (553.5).
"""
from datetime import date, datetime, timezone
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
)
from modules.freight_booking.validators import validate_charge_currencies


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:", poolclass=StaticPool)
    Base.metadata.create_all(engine)
    session = sessionmaker(bind=engine)()

    # Seed base currencies
    egp = Currency(
        currency_code="EGP",
        currency_name="Egyptian Pound",
        currency_symbol="EGP",
        is_base_currency=True,
        decimal_places=2,
        is_active=True,
    )
    usd = Currency(
        currency_code="USD",
        currency_name="US Dollar",
        currency_symbol="$",
        is_base_currency=False,
        decimal_places=2,
        is_active=True,
    )
    eur = Currency(
        currency_code="EUR",
        currency_name="Euro",
        currency_symbol="€",
        is_base_currency=False,
        decimal_places=2,
        is_active=True,
    )
    session.add_all([egp, usd, eur])
    session.commit()

    # Seed commercial exchange rates: USD = 50.0 EGP, EUR = 55.0 EGP
    usd_rate = ExchangeRate(
        currency_id=usd.currency_id,
        commercial_rate=50.0,
        customs_rate=49.5,
        effective_date=date.today(),
        is_active=True,
    )
    eur_rate = ExchangeRate(
        currency_id=eur.currency_id,
        commercial_rate=55.0,
        customs_rate=54.0,
        effective_date=date.today(),
        is_active=True,
    )
    session.add_all([usd_rate, eur_rate])
    session.commit()

    yield session
    session.close()


def test_mixed_currencies_converted_to_usd(db_session):
    """
    USD commercial rate = 50.0.
    2x 40HC containers.
    Sea Freight: Per Container, rate 1500 USD -> 3000.0 USD.
    THC: Per Shipment, qty 1, rate 4000 EGP -> fx_rate 1/50 = 0.02 -> 80.0 USD.
    Total = 3080.0 USD.
    """
    booking = ShipmentBooking(
        booking_code="BKG-TEST-001",
        shipment_type="Ocean FCL",
        containers_data=[{"container_type": "40HC", "quantity": 2}],
        cost_charges_data=[
            {"charge_type": "Sea Freight", "unit": "Per Container", "rate": 1500.0, "currency": "USD"},
            {"charge_type": "THC", "unit": "Per Shipment", "quantity": 1, "rate": 4000.0, "currency": "EGP"},
        ],
    )
    calculate_transit_time_and_costs(booking, db=db_session)

    assert booking.total_freight_cost_usd == 3080.0
    charges = booking.cost_charges_data
    assert len(charges) == 2

    # Sea Freight
    assert charges[0]["quantity"] == 2.0
    assert charges[0]["total"] == 3000.0
    assert charges[0]["fx_rate_to_usd"] == 1.0
    assert charges[0]["amount_usd"] == 3000.0

    # THC
    assert charges[1]["quantity"] == 1.0
    assert charges[1]["total"] == 4000.0
    assert charges[1]["fx_rate_to_usd"] == 0.02
    assert charges[1]["amount_usd"] == 80.0


def test_eur_to_usd_conversion(db_session):
    """
    EUR commercial rate = 55.0, USD commercial rate = 50.0.
    1000 EUR charge -> fx_rate = 55/50 = 1.1 -> amount_usd = 1100.0 USD.
    """
    booking = ShipmentBooking(
        booking_code="BKG-TEST-002",
        shipment_type="Ocean FCL",
        containers_data=[{"container_type": "20GP", "quantity": 1}],
        cost_charges_data=[
            {"charge_type": "Documentation", "unit": "Per Shipment", "quantity": 1, "rate": 1000.0, "currency": "EUR"},
        ],
    )
    calculate_transit_time_and_costs(booking, db=db_session)

    assert booking.total_freight_cost_usd == 1100.0
    charge = booking.cost_charges_data[0]
    assert charge["fx_rate_to_usd"] == 1.1
    assert charge["amount_usd"] == 1100.0


def test_missing_exchange_rate_raises_409(db_session):
    """A registered currency with no exchange rate on the target date raises 409 CURRENCY_RATE_MISSING."""
    # Add GBP without exchange rate
    gbp = Currency(
        currency_code="GBP",
        currency_name="British Pound",
        currency_symbol="£",
        is_base_currency=False,
        decimal_places=2,
        is_active=True,
    )
    db_session.add(gbp)
    db_session.commit()

    booking = ShipmentBooking(
        booking_code="BKG-TEST-003",
        shipment_type="Ocean FCL",
        containers_data=[{"container_type": "20GP", "quantity": 1}],
        cost_charges_data=[
            {"charge_type": "Freight", "unit": "Per Shipment", "quantity": 1, "rate": 500.0, "currency": "GBP"},
        ],
    )
    with pytest.raises(HTTPException) as exc_info:
        calculate_transit_time_and_costs(booking, db=db_session)

    assert exc_info.value.status_code == 409
    assert exc_info.value.detail.get("code") == "CURRENCY_RATE_MISSING"


def test_unknown_currency_raises_422(db_session):
    """An unregistered currency code raises 422."""
    charges = [{"charge_type": "Freight", "rate": 100.0, "currency": "XYZ"}]
    with pytest.raises(HTTPException) as exc_info:
        validate_charge_currencies(db_session, charges)
    assert exc_info.value.status_code == 422
    assert "XYZ" in exc_info.value.detail

    # Also test via calculate_transit_time_and_costs
    booking = ShipmentBooking(
        booking_code="BKG-TEST-004",
        shipment_type="Ocean FCL",
        containers_data=[{"container_type": "20GP", "quantity": 1}],
        cost_charges_data=charges,
    )
    with pytest.raises(HTTPException) as exc_info:
        calculate_transit_time_and_costs(booking, db=db_session)
    assert exc_info.value.status_code == 422
    assert "XYZ" in exc_info.value.detail


def test_per_container_charge_uses_its_container_type(db_session):
    """
    Containers: 2x 40HC, 1x 20GP.
    40HC charge @ 2000 USD -> 4000.0 USD.
    20GP charge @ 1200 USD -> 1200.0 USD.
    Total = 5200.0 USD.
    """
    booking = ShipmentBooking(
        booking_code="BKG-TEST-005",
        shipment_type="Ocean FCL",
        containers_data=[
            {"container_type": "40HC", "quantity": 2},
            {"container_type": "20GP", "quantity": 1},
        ],
        cost_charges_data=[
            {"charge_type": "Sea Freight 40ft", "unit": "Per Container", "rate": 2000.0, "container_type": "40HC", "currency": "USD"},
            {"charge_type": "Sea Freight 20ft", "unit": "Per Container", "rate": 1200.0, "container_type": "20GP", "currency": "USD"},
        ],
    )
    calculate_transit_time_and_costs(booking, db=db_session)

    assert booking.total_freight_cost_usd == 5200.0
    assert booking.cost_charges_data[0]["quantity"] == 2.0
    assert booking.cost_charges_data[0]["total"] == 4000.0
    assert booking.cost_charges_data[1]["quantity"] == 1.0
    assert booking.cost_charges_data[1]["total"] == 1200.0


def test_per_container_charge_without_type_uses_all_containers(db_session):
    """SOLAS @ 25 USD Per Container without container_type multiplies by all 3 containers -> 75.0 USD."""
    booking = ShipmentBooking(
        booking_code="BKG-TEST-006",
        shipment_type="Ocean FCL",
        containers_data=[
            {"container_type": "40HC", "quantity": 2},
            {"container_type": "20GP", "quantity": 1},
        ],
        cost_charges_data=[
            {"charge_type": "SOLAS/VGM Fee", "unit": "Per Container", "rate": 25.0, "currency": "USD"},
        ],
    )
    calculate_transit_time_and_costs(booking, db=db_session)

    assert booking.total_freight_cost_usd == 75.0
    assert booking.cost_charges_data[0]["quantity"] == 3.0
    assert booking.cost_charges_data[0]["total"] == 75.0


def test_lcl_decimal_quantity(db_session):
    """LCL 12.3 CBM @ 45 USD/CBM -> 553.5 USD."""
    booking = ShipmentBooking(
        booking_code="BKG-TEST-007",
        shipment_type="LCL",
        cost_charges_data=[
            {"charge_type": "LCL Freight", "unit": "Per CBM", "quantity": 12.3, "rate": 45.0, "currency": "USD"},
        ],
    )
    calculate_transit_time_and_costs(booking, db=db_session)

    assert booking.total_freight_cost_usd == 553.5
    assert booking.cost_charges_data[0]["quantity"] == 12.3
    assert booking.cost_charges_data[0]["total"] == 553.5


def test_unknown_container_type_on_charge_raises_422(db_session):
    """Charge referencing a container type not in container allocation raises 422."""
    booking = ShipmentBooking(
        booking_code="BKG-TEST-008",
        shipment_type="Ocean FCL",
        containers_data=[{"container_type": "40HC", "quantity": 2}],
        cost_charges_data=[
            {"charge_type": "Sea Freight", "unit": "Per Container", "container_type": "20GP", "rate": 1000.0, "currency": "USD"},
        ],
    )
    with pytest.raises(HTTPException) as exc_info:
        calculate_transit_time_and_costs(booking, db=db_session)

    assert exc_info.value.status_code == 422
    assert "20GP" in exc_info.value.detail
    assert "غير موجود في توزيع الحاويات" in exc_info.value.detail


def test_create_and_update_booking_validates_currency(db_session):
    """create_booking_service and update_booking_service enforce currency validation."""
    payload = ShipmentBookingCreate(
        shipment_type="Ocean FCL",
        containers_data=[ContainerAllocationItem(container_type="40HC", quantity=1)],
        cost_charges_data=[
            BookingChargeItem(charge_type="THC", quantity=1, rate=500.0, currency="INVALID_CURR"),
        ],
    )
    with pytest.raises(HTTPException) as exc_info:
        create_booking_service(db_session, payload, user="test_user")
    assert exc_info.value.status_code == 422

    # Now create valid booking
    valid_payload = ShipmentBookingCreate(
        shipment_type="Ocean FCL",
        containers_data=[ContainerAllocationItem(container_type="40HC", quantity=1)],
        cost_charges_data=[
            BookingChargeItem(charge_type="Sea Freight", quantity=1, rate=1000.0, currency="USD"),
        ],
    )
    booking = create_booking_service(db_session, valid_payload, user="test_user")
    assert booking.total_freight_cost_usd == 1000.0

    # Updating with invalid currency raises 422
    update_payload = ShipmentBookingUpdate(
        cost_charges_data=[
            BookingChargeItem(charge_type="THC", quantity=1, rate=500.0, currency="FAKE_CCY"),
        ],
    )
    with pytest.raises(HTTPException) as exc_info:
        update_booking_service(db_session, booking.booking_id, update_payload, user="test_user")
    assert exc_info.value.status_code == 422


def test_inactive_currency_raises_422(db_session):
    """An inactive currency used on a charge raises 422."""
    inactive_curr = Currency(
        currency_code="GBP",
        currency_name="British Pound",
        currency_symbol="£",
        is_active=False,
    )
    db_session.add(inactive_curr)
    db_session.commit()

    booking = ShipmentBooking(
        booking_code="BKG-TEST-INACTIVE",
        shipment_type="Ocean FCL",
        containers_data=[{"container_type": "40HC", "quantity": 1}],
        cost_charges_data=[
            {"charge_type": "Sea Freight", "unit": "Per Container", "rate": 1000.0, "currency": "GBP"},
        ],
    )
    with pytest.raises(HTTPException) as exc_info:
        calculate_transit_time_and_costs(booking, db=db_session)
    assert exc_info.value.status_code == 422
    assert "عملة البند غير معروفة: GBP" in str(exc_info.value.detail)


def test_db_none_with_non_usd_currency_raises_422():
    """Non-USD charge with db=None raises 422 instead of fallback 1.0."""
    booking = ShipmentBooking(
        booking_code="BKG-TEST-NO-DB",
        shipment_type="Ocean FCL",
        containers_data=[{"container_type": "40HC", "quantity": 1}],
        cost_charges_data=[
            {"charge_type": "Sea Freight", "unit": "Per Container", "rate": 1000.0, "currency": "EUR"},
        ],
    )
    with pytest.raises(HTTPException) as exc_info:
        calculate_transit_time_and_costs(booking, db=None)
    assert exc_info.value.status_code == 422
    assert "يتطلب تحويل عملة البند EUR جلسة قاعدة بيانات صالحة" in str(exc_info.value.detail)
