"""
Unit tests for BE45-T11:
Departure data and import-file sync:
- shipped_on_board_date persisted and returned
- Future ATD rejected (422)
- ATD before booking_request_date rejected (422)
- Departure on file past STEP_08_BL (e.g. STEP_13) preserves current_module
- Draft save does not touch selected_scenario; confirm sets it
- Delay days & expected warehouse arrival date calculations
"""
from datetime import datetime, date, timedelta, timezone
import pytest
from fastapi import FastAPI, HTTPException, status
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import modules.auth.permissions as auth_permissions
from database.database import Base, get_db
from modules.auth.permissions import invalidate_permission_cache
from modules.auth.security import create_access_token, hash_password
from modules.auth.seed_rbac import seed_rbac
from modules.users.model import Permission, Role, RolePermission, User
from modules.import_files.model import ImportFile
from modules.freight_booking.model import ShipmentBooking
from modules.freight_booking.schemas import (
    ShipmentBookingCreate,
    ShipmentBookingUpdate,
    ShipmentBookingConfirm,
    ShipmentDepartureConfirm,
    ShipmentBookingResponse,
    ContainerAllocationItem,
)
import modules.freight_booking.service as fb_service
import modules.freight_booking.router as fb_router
from modules.common.clock import cairo_today


@pytest.fixture
def session_factory():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    invalidate_permission_cache()
    yield sessionmaker(bind=engine, autoflush=False)
    invalidate_permission_cache()
    engine.dispose()


@pytest.fixture
def db(session_factory):
    session = session_factory()
    seed_rbac(session)
    session.commit()
    yield session
    session.close()


def _create_user_with_permissions(db, username: str, permissions: list[str]) -> User:
    role = Role(
        role_code=f"ROLE_{username.upper()}",
        name_ar=username,
        name_en=username,
        is_active=True,
    )
    db.add(role)
    db.flush()

    for p_code in permissions:
        perm = db.query(Permission).filter(Permission.permission_code == p_code).first()
        if not perm:
            perm = Permission(permission_code=p_code, module_name="test", action="test", name_en=p_code, name_ar=p_code)
            db.add(perm)
            db.flush()
        rp = RolePermission(role_id=role.role_id, permission_id=perm.permission_id)
        db.add(rp)

    user = User(
        username=username,
        email=f"{username}@test.com",
        full_name=username,
        hashed_password=hash_password("Password123"),
        role=role.role_code,
        role_id=role.role_id,
        is_active=True,
    )
    db.add(user)
    db.commit()
    invalidate_permission_cache()
    return user


def _create_file(db, file_id: int, code: str, current_step_code: str = "STEP_06", current_module: str = "Freight", progress: float = 40.0) -> ImportFile:
    imp_file = ImportFile(
        import_file_id=file_id,
        import_file_code=code,
        company_name="Test Corp",
        supplier_name="Global Supplier",
        owner="tester",
        current_step_code=current_step_code,
        current_module=current_module,
        progress_percent=progress,
        is_active=True,
    )
    db.add(imp_file)
    db.commit()
    db.refresh(imp_file)
    return imp_file


def _create_booking(db, file_id: int, req_date: datetime, shipping_line: str = "MSC") -> ShipmentBooking:
    booking_req = ShipmentBookingCreate(
        import_file_id=file_id,
        shipping_line_name=shipping_line,
        etd=req_date + timedelta(days=5),
        eta=req_date + timedelta(days=25),
        containers_data=[ContainerAllocationItem(container_type="40HC", quantity=1)],
    )
    booking = fb_service.create_booking_service(db, booking_req, user="tester")
    booking.booking_request_date = req_date
    db.commit()
    db.refresh(booking)
    return booking


def test_shipped_on_board_date_persisted_and_returned(db):
    """Confirm departure persists shipped_on_board_date and response model reflects it."""
    today = cairo_today()
    req_date = datetime.combine(today - timedelta(days=10), datetime.min.time(), tzinfo=timezone.utc)
    atd_date = datetime.combine(today - timedelta(days=2), datetime.min.time(), tzinfo=timezone.utc)
    board_date = today - timedelta(days=2)

    _create_file(db, 1, "IMP-001")
    booking = _create_booking(db, 1, req_date)
    fb_service.confirm_booking_service(db, booking.booking_id, ShipmentBookingConfirm(booking_confirmation_no="CONF-1"))

    depart_payload = ShipmentDepartureConfirm(
        actual_departure_date=atd_date,
        bill_of_lading_no="BL-MSC-999",
        shipped_on_board_date=board_date,
    )
    sailed = fb_service.confirm_departure_and_bol_service(db, booking.booking_id, depart_payload)

    assert sailed.status == "Sailed"
    assert sailed.shipped_on_board_date == board_date

    # Validate response schema serialization
    resp = ShipmentBookingResponse.model_validate(sailed)
    assert resp.shipped_on_board_date == board_date


def test_future_atd_rejected(db):
    """Actual departure date in the future gives 422."""
    today = cairo_today()
    req_date = datetime.combine(today - timedelta(days=5), datetime.min.time(), tzinfo=timezone.utc)
    tomorrow = datetime.combine(today + timedelta(days=1), datetime.min.time(), tzinfo=timezone.utc)

    _create_file(db, 2, "IMP-002")
    booking = _create_booking(db, 2, req_date)
    fb_service.confirm_booking_service(db, booking.booking_id, ShipmentBookingConfirm(booking_confirmation_no="CONF-2"))

    depart_payload = ShipmentDepartureConfirm(
        actual_departure_date=tomorrow,
        bill_of_lading_no="BL-FUTURE",
    )
    with pytest.raises(HTTPException) as exc:
        fb_service.confirm_departure_and_bol_service(db, booking.booking_id, depart_payload)
    assert exc.value.status_code == status.HTTP_422_UNPROCESSABLE_CONTENT
    assert "في المستقبل" in exc.value.detail


def test_atd_before_booking_request_date_rejected(db):
    """Actual departure date before booking request date gives 422."""
    today = cairo_today()
    req_date = datetime.combine(today - timedelta(days=5), datetime.min.time(), tzinfo=timezone.utc)
    earlier_atd = datetime.combine(today - timedelta(days=7), datetime.min.time(), tzinfo=timezone.utc)

    _create_file(db, 3, "IMP-003")
    booking = _create_booking(db, 3, req_date)
    fb_service.confirm_booking_service(db, booking.booking_id, ShipmentBookingConfirm(booking_confirmation_no="CONF-3"))

    depart_payload = ShipmentDepartureConfirm(
        actual_departure_date=earlier_atd,
        bill_of_lading_no="BL-EARLY",
    )
    with pytest.raises(HTTPException) as exc:
        fb_service.confirm_departure_and_bol_service(db, booking.booking_id, depart_payload)
    assert exc.value.status_code == status.HTTP_422_UNPROCESSABLE_CONTENT
    assert "قبل تاريخ طلب الحجز" in exc.value.detail


def test_departure_on_file_past_step_08_bl_preserves_module(db):
    """Departure on an import file at STEP_13 preserves current_module and progress."""
    today = cairo_today()
    req_date = datetime.combine(today - timedelta(days=10), datetime.min.time(), tzinfo=timezone.utc)
    atd_date = datetime.combine(today - timedelta(days=3), datetime.min.time(), tzinfo=timezone.utc)

    imp = _create_file(db, 4, "IMP-004", current_step_code="STEP_13", current_module="Customs Clearance", progress=75.0)
    booking = _create_booking(db, 4, req_date)
    fb_service.confirm_booking_service(db, booking.booking_id, ShipmentBookingConfirm(booking_confirmation_no="CONF-4"))

    depart_payload = ShipmentDepartureConfirm(
        actual_departure_date=atd_date,
        bill_of_lading_no="BL-PAST-STEP",
    )
    fb_service.confirm_departure_and_bol_service(db, booking.booking_id, depart_payload)

    db.refresh(imp)
    assert imp.current_step_code == "STEP_13"
    assert imp.current_module == "Customs Clearance"
    assert imp.progress_percent == 75.0


def test_draft_booking_save_does_not_touch_selected_scenario(db):
    """Draft booking create and update do NOT set selected_scenario; confirm sets it."""
    today = cairo_today()
    req_date = datetime.combine(today - timedelta(days=5), datetime.min.time(), tzinfo=timezone.utc)

    imp = _create_file(db, 5, "IMP-005")
    assert imp.selected_scenario is None

    # 1. Create draft booking with shipping_line_name
    booking = _create_booking(db, 5, req_date, shipping_line="Hapag-Lloyd")
    db.refresh(imp)
    assert imp.selected_scenario is None

    # 2. Update draft booking with another carrier
    fb_service.update_booking_service(db, booking.booking_id, ShipmentBookingUpdate(shipping_line_name="CMA CGM"))
    db.refresh(imp)
    assert imp.selected_scenario is None

    # 3. Confirm booking (STEP_07) -> now selected_scenario is populated
    fb_service.confirm_booking_service(db, booking.booking_id, ShipmentBookingConfirm(booking_confirmation_no="CONF-5"))
    db.refresh(imp)
    assert imp.selected_scenario == "Confirmed booking: CMA CGM"


def test_delay_and_warehouse_arrival_calculation(db):
    """
    Delay example:
    ETD 2026-09-10, ATD 2026-09-13 -> departure_delay_days 3;
    ETA 2026-10-01 + 3 + 7 warehouse days -> expected_warehouse_arrival_date 2026-10-11.
    """
    etd = datetime(2026, 9, 10, 0, 0, tzinfo=timezone.utc)
    atd = datetime(2026, 9, 13, 0, 0, tzinfo=timezone.utc)
    eta = datetime(2026, 10, 1, 0, 0, tzinfo=timezone.utc)

    _create_file(db, 6, "IMP-006")
    booking = ShipmentBooking(
        booking_code="BKG-CALC",
        import_file_id=6,
        booking_request_date=datetime(2026, 9, 1, 0, 0, tzinfo=timezone.utc),
        etd=etd,
        eta=eta,
        expected_warehouse_days=7,
        status="Confirmed",
        containers_data=[{"container_type": "40HC", "quantity": 1}],
    )
    db.add(booking)
    db.commit()

    depart_payload = ShipmentDepartureConfirm(
        actual_departure_date=atd,
        bill_of_lading_no="BL-CALC-1",
        shipped_on_board_date=date(2026, 9, 13),
    )
    sailed = fb_service.confirm_departure_and_bol_service(db, booking.booking_id, depart_payload)

    assert sailed.departure_delay_days == 3
    assert sailed.expected_warehouse_arrival_date.date() == date(2026, 10, 11)


def test_router_depart_endpoint(session_factory, db, monkeypatch):
    """HTTP router tests for /depart endpoint validations and responses."""
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", False)

    user = _create_user_with_permissions(
        db, "fb_user", ["freight_booking.depart", "freight_booking.confirm", "freight_booking.create", "freight_booking.view"]
    )
    app = FastAPI()
    app.include_router(fb_router.router)

    def override_get_db():
        s = session_factory()
        try:
            yield s
        finally:
            s.close()

    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app, raise_server_exceptions=False)
    headers = {"Authorization": f"Bearer {create_access_token({'sub': str(user.user_id), 'role': user.role})}"}

    today = cairo_today()
    req_date = datetime.combine(today - timedelta(days=10), datetime.min.time(), tzinfo=timezone.utc)
    atd_date = datetime.combine(today - timedelta(days=2), datetime.min.time(), tzinfo=timezone.utc)
    tomorrow = datetime.combine(today + timedelta(days=1), datetime.min.time(), tzinfo=timezone.utc)

    _create_file(db, 7, "IMP-007")
    booking = _create_booking(db, 7, req_date)
    fb_service.confirm_booking_service(db, booking.booking_id, ShipmentBookingConfirm(booking_confirmation_no="CONF-7"))

    # 1. Future ATD via HTTP -> 422
    r_future = client.post(
        f"/api/v1/freight-booking/{booking.booking_id}/depart",
        json={"actual_departure_date": tomorrow.isoformat(), "bill_of_lading_no": "BL-HTTP-FUT"},
        headers=headers,
    )
    assert r_future.status_code == 422
    assert "في المستقبل" in r_future.json()["detail"]

    # 2. Valid ATD via HTTP -> 200 with shipped_on_board_date
    r_ok = client.post(
        f"/api/v1/freight-booking/{booking.booking_id}/depart",
        json={
            "actual_departure_date": atd_date.isoformat(),
            "bill_of_lading_no": "BL-HTTP-OK",
            "shipped_on_board_date": (today - timedelta(days=2)).isoformat(),
        },
        headers=headers,
    )
    assert r_ok.status_code == 200
    data = r_ok.json()
    assert data["status"] == "Sailed"
    assert data["shipped_on_board_date"] == (today - timedelta(days=2)).isoformat()
