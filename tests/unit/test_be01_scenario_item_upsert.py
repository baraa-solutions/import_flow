"""
Unit tests for BE01-T02: Shipping-scenario items upserted by id (bookings keep their quote).

Tests verify:
- Updating a study with known item_id preserves the item_id and updates fields in place.
- Referenced scenario item in FreightBooking (ShipmentBooking) survives session update.
- Attempting to delete/omit a scenario item that is booked returns 409 SCENARIO_ITEMS_BOOKED.
- Adding a new option without item_id creates a new row while unreferenced omitted items are removed.
- Foreign item_id or duplicate item_id in update payload returns 400.
"""
from datetime import date, timedelta
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from database.database import Base
import main  # Ensure all models are registered
from modules.common.errors import CodedHTTPException
from modules.freight_booking.model import ShipmentBooking
from modules.shipping_scenarios.model import ShippingScenarioItem
from modules.shipping_scenarios.schemas import (
    ShippingEvaluationCreate,
    ShippingEvaluationUpdate,
    ShippingScenarioItemCreate,
)
from modules.shipping_scenarios.service import ShippingScenarioService
from modules.shipping_scenarios.validators import SCENARIO_ITEMS_BOOKED


@pytest.fixture
def db():
    test_engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=test_engine)
    TestingSession = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)
    session = TestingSession()

    from modules.external_service_providers.model import ExternalServiceProvider
    session.add_all([
        ExternalServiceProvider(provider_id=1, partner_code="FF-001", partner_name="Forwarder One", partner_type="Freight Forwarder"),
        ExternalServiceProvider(provider_id=2, partner_code="FF-002", partner_name="Forwarder Two", partner_type="Freight Forwarder"),
    ])
    session.commit()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=test_engine)


def test_scenario_items_upsert_and_booked_guard(db: Session):
    crd = date.today() + timedelta(days=5)
    item1 = ShippingScenarioItemCreate(
        provider_name="COSCO Shipping",
        vessel_name="COSCO UNIVERSE",
        voyage_number="101E",
        sailing_date=crd + timedelta(days=2),
        estimated_arrival_date=crd + timedelta(days=22),
        expected_line_delay_days=2,
        is_recommended=True,
        risk_level="Low",
        container_40ft_applicable=True,
        container_40ft_price=3000.0,
        container_40ft_currency="USD",
        container_40ft_qty=2,
    )
    item2 = ShippingScenarioItemCreate(
        provider_name="Maersk Line",
        vessel_name="MAERSK MC-KINNEY",
        voyage_number="202W",
        sailing_date=crd + timedelta(days=4),
        estimated_arrival_date=crd + timedelta(days=24),
        expected_line_delay_days=1,
        is_recommended=False,
        risk_level="Low",
        container_40ft_applicable=True,
        container_40ft_price=3200.0,
        container_40ft_currency="USD",
        container_40ft_qty=2,
    )

    create_payload = ShippingEvaluationCreate(
        title="Study For Upsert Test",
        cargo_ready_date=crd,
        items=[item1, item2],
    )
    created = ShippingScenarioService.create_session_service(db, create_payload)
    session_id = created.session_id

    assert len(created.items) == 2
    opt1_id = created.items[0].item_id
    opt2_id = created.items[1].item_id
    assert opt1_id is not None
    assert opt2_id is not None
    assert opt1_id != opt2_id

    # 1. Insert a ShipmentBooking referencing option 1
    booking = ShipmentBooking(
        booking_code="BKG-TEST-001",
        scenario_session_id=session_id,
        scenario_item_id=opt1_id,
        shipment_type="Ocean FCL",
    )
    db.add(booking)
    db.commit()

    # 2. PUT both options with their ids and a changed container_40ft_price
    update_item1 = ShippingScenarioItemCreate(
        item_id=opt1_id,
        provider_name="COSCO Shipping",
        vessel_name="COSCO UNIVERSE",
        voyage_number="101E",
        sailing_date=crd + timedelta(days=2),
        estimated_arrival_date=crd + timedelta(days=22),
        expected_line_delay_days=2,
        is_recommended=True,
        risk_level="Low",
        container_40ft_applicable=True,
        container_40ft_price=3500.0,  # Changed price
        container_40ft_currency="USD",
        container_40ft_qty=2,
    )
    update_item2 = ShippingScenarioItemCreate(
        item_id=opt2_id,
        provider_name="Maersk Line",
        vessel_name="MAERSK MC-KINNEY",
        voyage_number="202W",
        sailing_date=crd + timedelta(days=4),
        estimated_arrival_date=crd + timedelta(days=24),
        expected_line_delay_days=1,
        is_recommended=False,
        risk_level="Low",
        container_40ft_applicable=True,
        container_40ft_price=3200.0,
        container_40ft_currency="USD",
        container_40ft_qty=2,
    )

    update_payload = ShippingEvaluationUpdate(
        items=[update_item1, update_item2]
    )
    updated = ShippingScenarioService.update_session_service(db, session_id, update_payload)
    db.commit()

    # IDs remain equal, price updated, booking reference still valid
    assert len(updated.items) == 2
    updated_opt1 = next(it for it in updated.items if it.item_id == opt1_id)
    assert updated_opt1.container_40ft_price == 3500.0

    bkg_check = db.query(ShipmentBooking).filter(ShipmentBooking.booking_code == "BKG-TEST-001").first()
    assert bkg_check.scenario_item_id == opt1_id
    item_row = db.query(ShippingScenarioItem).filter(ShippingScenarioItem.item_id == opt1_id).first()
    assert item_row is not None
    assert item_row.container_40ft_price == 3500.0

    # 3. PUT only option 2 (trying to delete option 1 which is booked) -> 409 SCENARIO_ITEMS_BOOKED
    delete_booked_payload = ShippingEvaluationUpdate(
        items=[update_item2]
    )
    with pytest.raises(CodedHTTPException) as exc_info:
        ShippingScenarioService.update_session_service(db, session_id, delete_booked_payload)

    assert exc_info.value.status_code == 409
    assert exc_info.value.code == SCENARIO_ITEMS_BOOKED
    assert str(opt1_id) in exc_info.value.detail["item_ids"]

    # 4. PUT option 1 + new option without item_id -> 2 rows, option 2 deleted
    new_item3 = ShippingScenarioItemCreate(
        provider_name="CMA CGM",
        vessel_name="CMA CGM ANTOINE",
        voyage_number="303N",
        sailing_date=crd + timedelta(days=3),
        estimated_arrival_date=crd + timedelta(days=23),
        expected_line_delay_days=1,
        is_recommended=False,
        risk_level="Low",
    )
    add_new_payload = ShippingEvaluationUpdate(
        items=[update_item1, new_item3]
    )
    updated2 = ShippingScenarioService.update_session_service(db, session_id, add_new_payload)
    db.commit()

    assert len(updated2.items) == 2
    current_ids = {it.item_id for it in updated2.items}
    assert opt1_id in current_ids
    assert opt2_id not in current_ids  # Option 2 deleted since not booked
    opt2_row = db.query(ShippingScenarioItem).filter(ShippingScenarioItem.item_id == opt2_id).first()
    assert opt2_row is None


def test_scenario_item_id_validation_errors(db: Session):
    crd = date.today() + timedelta(days=5)
    item1 = ShippingScenarioItemCreate(
        provider_name="COSCO Shipping",
        vessel_name="COSCO UNIVERSE",
        sailing_date=crd + timedelta(days=2),
        estimated_arrival_date=crd + timedelta(days=22),
        expected_line_delay_days=2,
    )
    create_payload = ShippingEvaluationCreate(
        title="Study 2",
        cargo_ready_date=crd,
        items=[item1],
    )
    created = ShippingScenarioService.create_session_service(db, create_payload)
    session_id = created.session_id
    valid_id = created.items[0].item_id

    # Foreign item_id -> 400
    foreign_item = ShippingScenarioItemCreate(
        item_id=99999,
        provider_name="COSCO Shipping",
        vessel_name="COSCO UNIVERSE",
        sailing_date=crd + timedelta(days=2),
        estimated_arrival_date=crd + timedelta(days=22),
        expected_line_delay_days=2,
    )
    with pytest.raises(HTTPException) as exc_info:
        ShippingScenarioService.update_session_service(
            db, session_id, ShippingEvaluationUpdate(items=[foreign_item])
        )
    assert exc_info.value.status_code == 400
    assert "غير تابع لهذه الدراسة" in exc_info.value.detail

    # Duplicate item_id in payload -> 400
    dup_item_a = ShippingScenarioItemCreate(
        item_id=valid_id,
        provider_name="COSCO Shipping",
        vessel_name="COSCO UNIVERSE",
        sailing_date=crd + timedelta(days=2),
        estimated_arrival_date=crd + timedelta(days=22),
        expected_line_delay_days=2,
    )
    dup_item_b = ShippingScenarioItemCreate(
        item_id=valid_id,
        provider_name="COSCO Shipping 2",
        vessel_name="COSCO UNIVERSE 2",
        sailing_date=crd + timedelta(days=3),
        estimated_arrival_date=crd + timedelta(days=23),
        expected_line_delay_days=2,
    )
    with pytest.raises(HTTPException) as exc_info:
        ShippingScenarioService.update_session_service(
            db, session_id, ShippingEvaluationUpdate(items=[dup_item_a, dup_item_b])
        )
    assert exc_info.value.status_code == 400
    assert "مكرر في البيانات المرسلة" in exc_info.value.detail
