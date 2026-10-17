"""
Unit tests for BE01-T02:
Shipping-scenario items upserted by id (bookings keep their quote).
"""
from datetime import date, timedelta
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main  # Register all models in Base.metadata
from database.database import Base
from modules.external_service_providers.model import ExternalServiceProvider
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
    session.add_all([
        ExternalServiceProvider(
            provider_id=1,
            partner_code="FF-001",
            partner_name="Forwarder One",
            partner_type="Freight Forwarder",
            is_active=True,
        ),
        ExternalServiceProvider(
            provider_id=2,
            partner_code="FF-002",
            partner_name="Forwarder Two",
            partner_type="Freight Forwarder",
            is_active=True,
        ),
    ])
    session.commit()
    yield session
    session.close()


def _create_study_with_items(db, num_items=2):
    crd = date.today() + timedelta(days=10)
    items = []
    for i in range(1, num_items + 1):
        items.append(
            ShippingScenarioItemCreate(
                provider_id=1,
                provider_name="Forwarder One",
                vessel_name=f"Vessel {i}",
                voyage_number=f"VOY-{i}",
                sailing_date=crd + timedelta(days=i * 2),
                estimated_arrival_date=crd + timedelta(days=i * 2 + 15),
                expected_line_delay_days=1,
                container_40ft_applicable=True,
                container_40ft_price=2000.0 * i,
                container_40ft_currency="USD",
            )
        )
    payload = ShippingEvaluationCreate(
        title="Upsert Test Study",
        cargo_ready_date=crd,
        items=items,
    )
    return ShippingScenarioService.create_session_service(db, payload)


def test_upsert_preserves_item_ids_and_updates_data(db):
    """
    PUT with existing item_ids updates options in-place, preserving item_id.
    A ShipmentBooking referencing Opt1 still points to Opt1.
    """
    study = _create_study_with_items(db, 2)
    opt1_id = study.items[0].item_id
    opt2_id = study.items[1].item_id
    assert opt1_id is not None
    assert opt2_id is not None

    # Attach booking referencing option 1
    booking = ShipmentBooking(
        booking_code="BK-2026-001",
        scenario_session_id=study.session_id,
        scenario_item_id=opt1_id,
        is_active=True,
    )
    db.add(booking)
    db.commit()

    # Update both items: send their item_ids and update prices
    crd = study.cargo_ready_date
    updated_items = [
        ShippingScenarioItemCreate(
            item_id=opt1_id,
            provider_id=1,
            provider_name="Forwarder One",
            vessel_name="Vessel 1 - Updated",
            voyage_number="VOY-1",
            sailing_date=crd + timedelta(days=2),
            estimated_arrival_date=crd + timedelta(days=17),
            expected_line_delay_days=1,
            container_40ft_applicable=True,
            container_40ft_price=2750.0,
            container_40ft_currency="USD",
        ),
        ShippingScenarioItemCreate(
            item_id=opt2_id,
            provider_id=1,
            provider_name="Forwarder One",
            vessel_name="Vessel 2 - Updated",
            voyage_number="VOY-2",
            sailing_date=crd + timedelta(days=4),
            estimated_arrival_date=crd + timedelta(days=19),
            expected_line_delay_days=1,
            container_40ft_applicable=True,
            container_40ft_price=4500.0,
            container_40ft_currency="USD",
        ),
    ]

    update_payload = ShippingEvaluationUpdate(items=updated_items)
    result = ShippingScenarioService.update_session_service(db, study.session_id, update_payload)

    # Assertions
    assert len(result.items) == 2
    res_items = {it.item_id: it for it in result.items}
    assert opt1_id in res_items
    assert opt2_id in res_items

    # Verify updated data in-place
    assert res_items[opt1_id].vessel_name == "Vessel 1 - Updated"
    assert res_items[opt1_id].container_40ft_price == 2750.0
    assert res_items[opt2_id].vessel_name == "Vessel 2 - Updated"
    assert res_items[opt2_id].container_40ft_price == 4500.0

    # Verify booking link still resolves
    db.refresh(booking)
    assert booking.scenario_item_id == opt1_id
    stored_opt1 = db.query(ShippingScenarioItem).filter_by(item_id=opt1_id).first()
    assert stored_opt1 is not None
    assert stored_opt1.vessel_name == "Vessel 1 - Updated"


def test_delete_booked_scenario_item_raises_409(db):
    """
    Omitting a booked option in PUT payload raises 409 SCENARIO_ITEMS_BOOKED
    and does not modify the study options.
    """
    study = _create_study_with_items(db, 2)
    opt1_id = study.items[0].item_id
    opt2_id = study.items[1].item_id

    booking = ShipmentBooking(
        booking_code="BK-2026-002",
        scenario_session_id=study.session_id,
        scenario_item_id=opt1_id,
        is_active=True,
    )
    db.add(booking)
    db.commit()

    # Payload omits Opt1 (sends only Opt2)
    crd = study.cargo_ready_date
    only_opt2 = [
        ShippingScenarioItemCreate(
            item_id=opt2_id,
            provider_id=1,
            provider_name="Forwarder One",
            vessel_name="Vessel 2",
            voyage_number="VOY-2",
            sailing_date=crd + timedelta(days=4),
            estimated_arrival_date=crd + timedelta(days=19),
            expected_line_delay_days=1,
            container_40ft_applicable=True,
            container_40ft_price=4000.0,
            container_40ft_currency="USD",
        ),
    ]

    update_payload = ShippingEvaluationUpdate(items=only_opt2)

    with pytest.raises(HTTPException) as exc_info:
        ShippingScenarioService.update_session_service(db, study.session_id, update_payload)

    assert exc_info.value.status_code == 409
    detail = exc_info.value.detail
    assert isinstance(detail, dict)
    assert detail.get("code") == SCENARIO_ITEMS_BOOKED
    assert str(opt1_id) in str(detail.get("item_ids"))

    # Verify study is unchanged in DB
    refreshed_session = ShippingScenarioService.get_session_service(db, study.session_id)
    stored_ids = {it.item_id for it in refreshed_session.items}
    assert opt1_id in stored_ids
    assert opt2_id in stored_ids


def test_delete_item_with_inactive_booking_succeeds(db):
    """
    If a booking is soft-deleted (is_active=False), omitting its scenario_item_id
    does not trigger 409 and successfully deletes the option.
    """
    study = _create_study_with_items(db, 2)
    opt1_id = study.items[0].item_id
    opt2_id = study.items[1].item_id

    # Inactive booking
    booking = ShipmentBooking(
        booking_code="BK-2026-003",
        scenario_session_id=study.session_id,
        scenario_item_id=opt1_id,
        is_active=False,
    )
    db.add(booking)
    db.commit()

    crd = study.cargo_ready_date
    only_opt2 = [
        ShippingScenarioItemCreate(
            item_id=opt2_id,
            provider_id=1,
            provider_name="Forwarder One",
            vessel_name="Vessel 2",
            voyage_number="VOY-2",
            sailing_date=crd + timedelta(days=4),
            estimated_arrival_date=crd + timedelta(days=19),
            expected_line_delay_days=1,
            container_40ft_applicable=True,
            container_40ft_price=4000.0,
            container_40ft_currency="USD",
        ),
    ]

    update_payload = ShippingEvaluationUpdate(items=only_opt2)
    result = ShippingScenarioService.update_session_service(db, study.session_id, update_payload)

    assert len(result.items) == 1
    assert result.items[0].item_id == opt2_id
    assert db.query(ShippingScenarioItem).filter_by(item_id=opt1_id).first() is None


def test_upsert_inserts_new_item_and_deletes_omitted(db):
    """
    PUT with Opt1 (with ID) + a new option (without ID):
    Opt1 ID is preserved, Opt2 is deleted, new option gets a new ID.
    """
    study = _create_study_with_items(db, 2)
    opt1_id = study.items[0].item_id
    opt2_id = study.items[1].item_id

    crd = study.cargo_ready_date
    items_payload = [
        ShippingScenarioItemCreate(
            item_id=opt1_id,
            provider_id=1,
            provider_name="Forwarder One",
            vessel_name="Vessel 1",
            voyage_number="VOY-1",
            sailing_date=crd + timedelta(days=2),
            estimated_arrival_date=crd + timedelta(days=17),
            expected_line_delay_days=1,
            container_40ft_applicable=True,
            container_40ft_price=2200.0,
            container_40ft_currency="USD",
        ),
        # New option: no item_id
        ShippingScenarioItemCreate(
            provider_id=1,
            provider_name="Forwarder One",
            vessel_name="Vessel 3 (Brand New)",
            voyage_number="VOY-3",
            sailing_date=crd + timedelta(days=6),
            estimated_arrival_date=crd + timedelta(days=21),
            expected_line_delay_days=1,
            container_40ft_applicable=True,
            container_40ft_price=3100.0,
            container_40ft_currency="USD",
        ),
    ]

    update_payload = ShippingEvaluationUpdate(items=items_payload)
    result = ShippingScenarioService.update_session_service(db, study.session_id, update_payload)

    assert len(result.items) == 2
    res_ids = [it.item_id for it in result.items]
    assert opt1_id in res_ids
    assert opt2_id not in res_ids

    # Find the new option
    new_opt = [it for it in result.items if it.item_id != opt1_id][0]
    assert new_opt.item_id is not None
    assert new_opt.item_id != opt1_id
    assert new_opt.vessel_name == "Vessel 3 (Brand New)"

    # Opt2 is gone from DB
    assert db.query(ShippingScenarioItem).filter_by(item_id=opt2_id).first() is None


def test_duplicate_item_ids_in_payload_raises_400(db):
    """
    Sending duplicate item_ids in update payload raises 400.
    """
    study = _create_study_with_items(db, 2)
    opt1_id = study.items[0].item_id

    crd = study.cargo_ready_date
    duplicate_items = [
        ShippingScenarioItemCreate(
            item_id=opt1_id,
            provider_id=1,
            provider_name="Forwarder One",
            vessel_name="Vessel 1 - Copy A",
            voyage_number="VOY-1A",
            sailing_date=crd + timedelta(days=2),
            estimated_arrival_date=crd + timedelta(days=17),
            expected_line_delay_days=1,
        ),
        ShippingScenarioItemCreate(
            item_id=opt1_id,
            provider_id=1,
            provider_name="Forwarder One",
            vessel_name="Vessel 1 - Copy B",
            voyage_number="VOY-1B",
            sailing_date=crd + timedelta(days=4),
            estimated_arrival_date=crd + timedelta(days=19),
            expected_line_delay_days=1,
        ),
    ]

    update_payload = ShippingEvaluationUpdate(items=duplicate_items)
    with pytest.raises(HTTPException) as exc_info:
        ShippingScenarioService.update_session_service(db, study.session_id, update_payload)

    assert exc_info.value.status_code == 400
    assert "مكرر" in str(exc_info.value.detail)


def test_foreign_item_id_in_payload_raises_400(db):
    """
    Sending an item_id belonging to another study raises 400.
    """
    study1 = _create_study_with_items(db, 1)
    study2 = _create_study_with_items(db, 1)

    opt2_id = study2.items[0].item_id

    crd = study1.cargo_ready_date
    foreign_item_payload = [
        ShippingScenarioItemCreate(
            item_id=opt2_id,  # From study 2!
            provider_id=1,
            provider_name="Forwarder One",
            vessel_name="Foreign Vessel",
            voyage_number="VOY-F",
            sailing_date=crd + timedelta(days=2),
            estimated_arrival_date=crd + timedelta(days=17),
            expected_line_delay_days=1,
        ),
    ]

    update_payload = ShippingEvaluationUpdate(items=foreign_item_payload)
    with pytest.raises(HTTPException) as exc_info:
        ShippingScenarioService.update_session_service(db, study1.session_id, update_payload)

    assert exc_info.value.status_code == 400
    assert "غير تابع" in str(exc_info.value.detail)
