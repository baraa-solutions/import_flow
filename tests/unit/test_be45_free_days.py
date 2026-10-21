"""
Unit tests for BE45-T04:
No invented 14 free days on the booking:
- free_demurrage_days is optional and nullable (null = not agreed yet).
- Negative free_demurrage_days rejected with 422 / ValidationError (ge=0).
- Confirming a booking without free_demurrage_days preserves existing agreed value.
- Demurrage tracking uses carrier policy free days (e.g. 21) when booking has None.
- Demurrage tracking respects agreed 0 days without falling back to policy.
"""
from datetime import date
import pytest
from pydantic import ValidationError
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.import_files.model import ImportFile
from modules.freight_booking.model import ShipmentBooking
from modules.freight_booking.schemas import (
    ShipmentBookingCreate,
    ShipmentBookingUpdate,
    ShipmentBookingConfirm,
    ContainerAllocationItem,
)
import modules.freight_booking.service as fb_service
from modules.demurrage_detention.model import DemurragePolicy
from modules.demurrage_detention.schemas import (
    DemurragePolicyCreate,
    DemurrageTrackingCreate,
    ContainerItemInput,
    TierRateItem,
)
import modules.demurrage_detention.service as dd_service


@pytest.fixture
def session_factory():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    yield sessionmaker(bind=engine, autoflush=False)
    engine.dispose()


@pytest.fixture
def db(session_factory):
    session = session_factory()
    file1 = ImportFile(
        import_file_id=1,
        import_file_code="IMP-2026-0001",
        custom_file_number="6701068100",
        company_name="Egyptian Import Co",
        supplier_name="ABC China",
        owner="Kamal",
    )
    session.add(file1)
    session.commit()
    yield session
    session.close()


def _containers_data():
    return [ContainerAllocationItem(container_type="40ft High Cube", quantity=1)]


def test_booking_creation_without_free_days_stores_none(db):
    """A new booking created without free days stores None (not 14)."""
    payload = ShipmentBookingCreate(
        import_file_id=1,
        shipping_line_name="MSC",
        shipment_type="Ocean FCL",
        containers_data=_containers_data(),
    )
    assert payload.free_demurrage_days is None

    booking = fb_service.create_booking_service(db, payload, user="tester")
    assert booking.free_demurrage_days is None


def test_negative_free_days_validation_rejected():
    """Negative free_demurrage_days must be rejected with validation error (ge=0)."""
    with pytest.raises(ValidationError):
        ShipmentBookingCreate(
            import_file_id=1,
            shipping_line_name="MSC",
            containers_data=_containers_data(),
            free_demurrage_days=-1,
        )

    with pytest.raises(ValidationError):
        ShipmentBookingUpdate(free_demurrage_days=-5)

    with pytest.raises(ValidationError):
        ShipmentBookingConfirm(
            booking_confirmation_no="CONF-001",
            free_demurrage_days=-1,
        )


def test_confirm_without_free_days_preserves_existing_value(db):
    """Confirming a booking without the field preserves existing free days (e.g. 21)."""
    # 1. Create booking with 21 agreed days
    booking = fb_service.create_booking_service(
        db,
        ShipmentBookingCreate(
            import_file_id=1,
            shipping_line_name="MSC",
            containers_data=_containers_data(),
            free_demurrage_days=21,
        ),
        user="tester",
    )
    assert booking.free_demurrage_days == 21

    # 2. Confirm without sending free_demurrage_days
    confirm_payload = ShipmentBookingConfirm(
        booking_confirmation_no="MSC-CONF-99",
        vessel_name="MSC OSCAR",
        voyage_number="042W",
    )
    confirmed = fb_service.confirm_booking_service(db, booking.booking_id, confirm_payload, user="tester")
    assert confirmed.free_demurrage_days == 21

    # Verify import file target_free_days is also 21
    file_rec = db.query(ImportFile).filter(ImportFile.import_file_id == 1).first()
    assert file_rec.target_free_days == 21


def test_confirm_with_explicit_free_days_updates(db):
    """Confirming with an explicit free days value updates both booking and import file."""
    booking = fb_service.create_booking_service(
        db,
        ShipmentBookingCreate(
            import_file_id=1,
            shipping_line_name="MSC",
            containers_data=_containers_data(),
        ),
        user="tester",
    )
    assert booking.free_demurrage_days is None

    confirm_payload = ShipmentBookingConfirm(
        booking_confirmation_no="MSC-CONF-100",
        free_demurrage_days=14,
    )
    confirmed = fb_service.confirm_booking_service(db, booking.booking_id, confirm_payload, user="tester")
    assert confirmed.free_demurrage_days == 14

    file_rec = db.query(ImportFile).filter(ImportFile.import_file_id == 1).first()
    assert file_rec.target_free_days == 14


def test_tracking_uses_policy_free_days_when_booking_has_none(db):
    """
    Policy MSC/40HC with 21 free days.
    Booking created without free days (NULL).
    Tracking discharge 2026-09-01 with gate-out 2026-09-23 (22 days consumed):
    Overdue = 22 - 21 = 1 day, demurrage = 40.00 USD.
    (Under old code with 14 default days: 22 - 14 = 8 days -> 7*40 + 1*70 = 350.00).
    """
    # 1. Create MSC Policy with 21 free demurrage days
    policy = dd_service.create_demurrage_policy_service(
        db,
        DemurragePolicyCreate(
            carrier_name="MSC",
            container_type="40ft High Cube",
            demurrage_free_days=21,
            detention_free_days=7,
            port_storage_free_days=7,
            port_storage_daily_rate_egp=50.0,
            currency="USD",
            demurrage_tiers=[
                TierRateItem(from_day=1, to_day=7, rate_per_day=40.0),
                TierRateItem(from_day=8, to_day=14, rate_per_day=70.0),
                TierRateItem(from_day=15, to_day=None, rate_per_day=120.0),
            ],
            detention_tiers=[
                TierRateItem(from_day=1, to_day=None, rate_per_day=35.0),
            ],
        ),
        user="tester",
    )

    # 2. Create booking for file without free days
    booking = fb_service.create_booking_service(
        db,
        ShipmentBookingCreate(
            import_file_id=1,
            shipping_line_name="MSC",
            shipment_type="Ocean FCL",
            containers_data=_containers_data(),
            free_demurrage_days=None,
        ),
        user="tester",
    )
    assert booking.free_demurrage_days is None

    # 3. Create tracking
    tracking = dd_service.create_demurrage_tracking_service(
        db,
        DemurrageTrackingCreate(
            import_file_id=1,
            carrier_name="MSC",
            bill_of_lading_no="MEDU12345678",
            port_name="Alexandria Port",
            discharge_date=date(2026, 9, 1),
            gate_out_date=date(2026, 9, 23),
            containers=[
                ContainerItemInput(container_no="MSCU9876543", container_type="40ft High Cube"),
            ],
            currency="USD",
            exchange_rate=50.0,
        ),
        user="tester",
    )

    # 22 days consumed - 21 policy free days = 1 overdue day (day 22). Extended free time (> 14 days) is priced
    # at the calendar tier of that day (decision 2026-10-21): day 22 is in the 15+ tier = 120.0 USD.
    assert tracking.total_demurrage_fx == 120.0


def test_tracking_respects_agreed_zero_free_days(db):
    """
    When booking explicitly has 0 free days agreed, 0 is applied rather than policy.
    22 days consumed -> all 22 days are overdue.
    7 days * 40 + 7 days * 70 + 8 days * 120 = 280 + 490 + 960 = 1730.00 USD.
    """
    # 1. Create MSC Policy with 21 free days
    dd_service.create_demurrage_policy_service(
        db,
        DemurragePolicyCreate(
            carrier_name="MSC",
            container_type="40ft High Cube",
            demurrage_free_days=21,
            detention_free_days=7,
            port_storage_free_days=7,
            port_storage_daily_rate_egp=50.0,
            currency="USD",
            demurrage_tiers=[
                TierRateItem(from_day=1, to_day=7, rate_per_day=40.0),
                TierRateItem(from_day=8, to_day=14, rate_per_day=70.0),
                TierRateItem(from_day=15, to_day=None, rate_per_day=120.0),
            ],
            detention_tiers=[
                TierRateItem(from_day=1, to_day=None, rate_per_day=35.0),
            ],
        ),
        user="tester",
    )

    # 2. Create booking with 0 free days
    booking = fb_service.create_booking_service(
        db,
        ShipmentBookingCreate(
            import_file_id=1,
            shipping_line_name="MSC",
            shipment_type="Ocean FCL",
            containers_data=_containers_data(),
            free_demurrage_days=0,
        ),
        user="tester",
    )
    assert booking.free_demurrage_days == 0

    # 3. Create tracking
    tracking = dd_service.create_demurrage_tracking_service(
        db,
        DemurrageTrackingCreate(
            import_file_id=1,
            carrier_name="MSC",
            bill_of_lading_no="MEDU87654321",
            port_name="Alexandria Port",
            discharge_date=date(2026, 9, 1),
            gate_out_date=date(2026, 9, 23),
            containers=[
                ContainerItemInput(container_no="MSCU1122334", container_type="40ft High Cube"),
            ],
            currency="USD",
            exchange_rate=50.0,
        ),
        user="tester",
    )

    # 22 overdue days:
    # 7 * 40.0 = 280.0
    # 7 * 70.0 = 490.0
    # 8 * 120.0 = 960.0
    # Total = 1730.0 USD
    assert tracking.total_demurrage_fx == 1730.0
