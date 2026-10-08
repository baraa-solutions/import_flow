from datetime import datetime, date, timezone
import pytest
from pydantic import ValidationError
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.freight_booking.model import ShipmentBooking
from modules.freight_booking.schemas import (
    ShipmentBookingCreate,
    ShipmentBookingConfirm,
    ShipmentBookingUpdate,
    ShipmentBookingResponse,
    ContainerAllocationItem,
)
from modules.freight_booking.service import (
    create_booking_service,
    confirm_booking_service,
)
from modules.demurrage_detention.model import DemurragePolicy, DemurrageTracking
from modules.demurrage_detention.schemas import DemurrageTrackingCreate, ContainerItemInput
from modules.demurrage_detention.service import create_demurrage_tracking_service
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.incoterms.model import Incoterm
from modules.projects.model import Project
from modules.import_files.model import ImportFile


@pytest.fixture
def db_session():
    """Creates an isolated in-memory SQLite database session with seed entities."""
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
        echo=False,
    )
    Base.metadata.create_all(engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = TestingSessionLocal()

    comp = ImportCompany(
        company_id=1,
        importer_name="Egyptian Import Co",
        vat_id="100-200-300",
        vat_id_expiry=date(2028, 1, 1),
        registration_number="12345",
        registration_expiry=date(2028, 1, 1),
        address="Cairo",
        country="Egypt",
        importer_id="IMP-001",
        importer_id_expiry=date(2028, 1, 1),
    )
    sup = Supplier(
        supplier_id=1,
        company_name="ABC Global Exporters",
        supplier_code="SUP-01",
        supplier_type="Manufacturer",
        registration_type="Foreign Exporter",
        foreign_exporter_id="CN-99",
        foreign_exporter_country="China",
        foreign_exporter_country_code="CN",
        address="Shanghai",
    )
    inc = Incoterm(
        incoterm_id=1,
        incoterm_code="FOB",
        incoterm_name="Free on Board",
    )
    prj = Project(
        project_id=1,
        project_code="PRJ-01",
        project_name="Metro Line 4",
        project_owner="Kamal",
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        status="Active",
    )
    imp_file = ImportFile(
        import_file_id=1,
        import_file_code="IMP-2026-0001",
        custom_file_number="6701068100",
        company_name="Egyptian Import Co",
        supplier_name="ABC Global Exporters",
        current_module="STEP_06 حجز النولون وتأكيد الخط الملاحي",
        progress_percent=40.0,
        target_free_days=21,
        owner="Kamal",
    )

    db.add_all([comp, sup, inc, prj, imp_file])
    db.commit()
    yield db
    db.close()


def test_new_booking_without_free_days_stores_null(db_session):
    """A new booking created without free_demurrage_days stores NULL, not invented 14."""
    create_schema = ShipmentBookingCreate(
        import_file_id=1,
        shipping_line_name="MSC",
        pol_name="Shanghai",
        pod_name="Alexandria",
        free_demurrage_days=None,
        containers_data=[ContainerAllocationItem(container_type="40ft High Cube", quantity=1)],
    )
    booking = create_booking_service(db_session, create_schema, user="test_user")

    assert booking.free_demurrage_days is None

    # Verify Pydantic response schema also reflects null
    response = ShipmentBookingResponse.model_validate(booking)
    assert response.free_demurrage_days is None


def test_reconfirm_without_field_keeps_existing_days(db_session):
    """A booking at 21 confirmed via /confirm without free_demurrage_days keeps 21."""
    create_schema = ShipmentBookingCreate(
        import_file_id=1,
        shipping_line_name="MSC",
        pol_name="Shanghai",
        pod_name="Alexandria",
        free_demurrage_days=21,
        containers_data=[ContainerAllocationItem(container_type="40ft High Cube", quantity=1)],
    )
    booking = create_booking_service(db_session, create_schema, user="test_user")
    assert booking.free_demurrage_days == 21

    # Confirm without providing free_demurrage_days in payload
    confirm_payload = ShipmentBookingConfirm(
        booking_confirmation_no="MSC-CN-8800",
        vessel_name="MSC OSCAR",
        voyage_number="2608W",
    )
    confirmed = confirm_booking_service(db_session, booking.booking_id, confirm_payload, user="test_user")

    assert confirmed.free_demurrage_days == 21
    # Verify import file target_free_days was not overwritten with 14
    imp_file = db_session.query(ImportFile).filter_by(import_file_id=1).first()
    assert imp_file.target_free_days == 21


def test_tracking_for_file_without_free_days_uses_carrier_policy(db_session):
    """
    Policy MSC/40HC with 21 free days.
    Booking created without free days (NULL).
    Tracking discharge 2026-09-01 with gate-out 2026-09-23 (22 days consumed):
    overdue = 22 - 21 = 1, demurrage 40.00.
    (Under old code with invented 14: 22 - 14 = 8 overdue = 7x40 + 1x70 = 350.00).
    """
    # 1. Create carrier policy with 21 free days
    policy = DemurragePolicy(
        carrier_name="MSC",
        container_type="40ft High Cube",
        demurrage_free_days=21,
        detention_free_days=7,
        port_storage_free_days=5,
        port_storage_daily_rate_egp=0.0,
        demurrage_tiers=[
            {"from_day": 1, "to_day": 7, "rate_per_day": 40.0},
            {"from_day": 8, "to_day": 14, "rate_per_day": 70.0},
            {"from_day": 15, "to_day": None, "rate_per_day": 120.0},
        ],
        is_active=True,
    )
    db_session.add(policy)
    db_session.commit()

    # 2. Create booking without free days
    create_schema = ShipmentBookingCreate(
        import_file_id=1,
        shipping_line_name="MSC",
        pol_name="Shanghai",
        pod_name="Alexandria",
        free_demurrage_days=None,
        containers_data=[ContainerAllocationItem(container_type="40ft High Cube", quantity=1)],
    )
    booking = create_booking_service(db_session, create_schema, user="test_user")
    assert booking.free_demurrage_days is None

    # 3. Create tracking with discharge 2026-09-01 and gate-out 2026-09-23
    track_req = DemurrageTrackingCreate(
        import_file_id=1,
        carrier_name="MSC",
        bill_of_lading_no="MEDUST-2026",
        port_name="Alexandria Port",
        discharge_date=date(2026, 9, 1),
        gate_out_date=date(2026, 9, 23),
        currency="USD",
        exchange_rate=50.0,
        containers=[
            ContainerItemInput(
                container_no="MSCU9998881",
                container_type="40ft High Cube",
            )
        ],
    )
    tracking = create_demurrage_tracking_service(db_session, track_req, user="test_user")

    # 22 days in port - 21 free days = 1 overdue day
    # Demurrage fee = 1 * $40.00 = $40.00
    container = tracking.containers[0]
    assert container["demurrage_days"] == 1
    assert container["demurrage_fx"] == 40.0


def test_agreed_zero_days_applies_zero_not_policy(db_session):
    """Agreed 0 days applies 0, not falling back to the policy."""
    policy = DemurragePolicy(
        carrier_name="MSC",
        container_type="40ft High Cube",
        demurrage_free_days=21,
        detention_free_days=7,
        port_storage_free_days=5,
        port_storage_daily_rate_egp=0.0,
        demurrage_tiers=[
            {"from_day": 1, "to_day": 7, "rate_per_day": 40.0},
            {"from_day": 8, "to_day": 14, "rate_per_day": 70.0},
            {"from_day": 15, "to_day": None, "rate_per_day": 120.0},
        ],
        is_active=True,
    )
    db_session.add(policy)
    db_session.commit()

    # Create booking with explicitly agreed 0 free days
    create_schema = ShipmentBookingCreate(
        import_file_id=1,
        shipping_line_name="MSC",
        pol_name="Shanghai",
        pod_name="Alexandria",
        free_demurrage_days=0,
        containers_data=[ContainerAllocationItem(container_type="40ft High Cube", quantity=1)],
    )
    booking = create_booking_service(db_session, create_schema, user="test_user")
    assert booking.free_demurrage_days == 0

    track_req = DemurrageTrackingCreate(
        import_file_id=1,
        carrier_name="MSC",
        bill_of_lading_no="MEDUST-ZERO",
        port_name="Alexandria Port",
        discharge_date=date(2026, 9, 1),
        gate_out_date=date(2026, 9, 23),
        currency="USD",
        exchange_rate=50.0,
        containers=[
            ContainerItemInput(
                container_no="MSCU0000000",
                container_type="40ft High Cube",
            )
        ],
    )
    tracking = create_demurrage_tracking_service(db_session, track_req, user="test_user")

    # 22 days in port - 0 free days = 22 overdue days (not 22 - 21 = 1)
    container = tracking.containers[0]
    assert container["demurrage_days"] == 22


def test_negative_free_days_gives_validation_error():
    """Negative free_demurrage_days (-1) is rejected by Pydantic schemas (ge=0)."""
    with pytest.raises(ValidationError):
        ShipmentBookingCreate(
            import_file_id=1,
            shipping_line_name="MSC",
            free_demurrage_days=-1,
        )

    with pytest.raises(ValidationError):
        ShipmentBookingConfirm(
            booking_confirmation_no="MSC-CONF",
            free_demurrage_days=-1,
        )

    with pytest.raises(ValidationError):
        ShipmentBookingUpdate(
            free_demurrage_days=-1,
        )
