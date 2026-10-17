"""Unit tests for BE45-T21: Audit wiring on shipment_bookings.

Verifies:
- create_booking sets both created_by and updated_by to the session user.
- update_booking sets updated_by to the session user while created_by remains unchanged.
- confirm_booking sets updated_by to the session user while created_by remains unchanged.
- confirm_departure sets updated_by to the session user while created_by remains unchanged.
- soft_delete_booking sets updated_by to the session user.
- restore_booking sets updated_by to the session user.
- User 'ops1' creates and 'ops2' confirms -> created_by 'ops1', updated_by 'ops2'.
- ShipmentBookingResponse serializes created_by and updated_by.
- FastAPI router endpoints correctly extract and pass current_user.username to all service actions.
"""

from datetime import datetime, date, timezone
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

from database.database import Base, get_db
from main import app
from modules.freight_booking.model import ShipmentBooking
from modules.freight_booking.schemas import (
    ShipmentBookingCreate,
    ShipmentBookingUpdate,
    ShipmentBookingConfirm,
    ShipmentDepartureConfirm,
    ShipmentBookingResponse,
    ContainerAllocationItem,
    BookingChargeItem,
)
from modules.freight_booking.service import (
    create_booking_service,
    update_booking_service,
    confirm_booking_service,
    confirm_departure_and_bol_service,
    soft_delete_booking_service,
    restore_booking_service,
    get_booking_service,
)
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.incoterms.model import Incoterm
from modules.projects.model import Project
from modules.import_files.model import ImportFile
from modules.currencies.model import Currency
from modules.users.model import User
from modules.auth.router import get_current_user


@pytest.fixture
def db_session():
    """Isolated in-memory SQLite database session with seed master records."""
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
        echo=False,
    )
    Base.metadata.create_all(bind=engine)
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = SessionLocal()

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
    db.add(comp)

    supp = Supplier(
        supplier_id=1,
        company_name="Global Shipper Ltd",
        supplier_code="SUP-01",
        supplier_type="Manufacturer",
        registration_type="Foreign Exporter",
        foreign_exporter_id="CN-99",
        foreign_exporter_country="China",
        foreign_exporter_country_code="CN",
        address="Shanghai",
    )
    db.add(supp)

    inco = Incoterm(
        incoterm_id=1,
        incoterm_code="FOB",
        incoterm_name="Free On Board",
        description="FOB",
    )
    db.add(inco)

    proj = Project(
        project_id=1,
        project_code="PRJ-01",
        project_name="Main Operations",
        project_owner="Kamal",
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
    )
    db.add(proj)

    imp_file = ImportFile(
        import_file_id=1,
        import_file_code="IF-2026-0001",
        company_name="Egyptian Import Co",
        supplier_name="Global Shipper Ltd",
        current_module="STEP_06 حجز النولون وتأكيد الخط الملاحي",
        is_active=True,
    )
    imp_file2 = ImportFile(
        import_file_id=2,
        import_file_code="IF-2026-0002",
        company_name="Egyptian Import Co",
        supplier_name="Global Shipper Ltd",
        current_module="STEP_06 حجز النولون وتأكيد الخط الملاحي",
        is_active=True,
    )
    db.add_all([imp_file, imp_file2])

    for c_code in ["USD", "EGP", "EUR"]:
        db.add(Currency(currency_code=c_code, currency_name=c_code, currency_symbol=c_code, is_active=True))

    db.commit()
    try:
        yield db
    finally:
        db.close()


def make_valid_payload():
    return ShipmentBookingCreate(
        import_file_id=1,
        shipment_type="Ocean FCL",
        freight_terms="Collect",
        containers_data=[
            ContainerAllocationItem(container_type="40HC", quantity=1),
        ],
        cost_charges_data=[
            BookingChargeItem(
                charge_type="Ocean Freight",
                currency="USD",
                rate=2500.0,
                quantity=1,
                unit="Per Container",
                total=2500.0,
            ),
        ],
        original_freight_cost_usd=2500.0,
        notes="Audit testing booking",
    )


# ==============================================================================
# Service Level Audit Tests
# ==============================================================================

def test_create_sets_created_by_and_updated_by(db_session):
    payload = make_valid_payload()
    booking = create_booking_service(db_session, payload, user="ops1")

    assert booking.created_by == "ops1"
    assert booking.updated_by == "ops1"
    assert booking.owner == "ops1"


def test_update_sets_updated_by_and_preserves_created_by(db_session):
    payload = make_valid_payload()
    booking = create_booking_service(db_session, payload, user="ops1")
    assert booking.created_by == "ops1"
    assert booking.updated_by == "ops1"

    update_payload = ShipmentBookingUpdate(notes="Updated by supervisor")
    updated_booking = update_booking_service(db_session, booking.booking_id, update_payload, user="ops2")

    assert updated_booking.created_by == "ops1"
    assert updated_booking.updated_by == "ops2"


def test_ops1_creates_and_ops2_confirms(db_session):
    """Specific finding scenario: user 'ops1' creates and 'ops2' confirms."""
    payload = make_valid_payload()
    booking = create_booking_service(db_session, payload, user="ops1")
    assert booking.created_by == "ops1"
    assert booking.updated_by == "ops1"

    confirm_payload = ShipmentBookingConfirm(
        booking_confirmation_no="CN-CONF-9988",
        vessel_name="MSC Oscar",
        voyage_number="V101",
        etd=datetime(2026, 11, 10, tzinfo=timezone.utc),
        eta=datetime(2026, 11, 28, tzinfo=timezone.utc),
    )
    confirmed_booking = confirm_booking_service(db_session, booking.booking_id, confirm_payload, user="ops2")

    assert confirmed_booking.created_by == "ops1"
    assert confirmed_booking.updated_by == "ops2"
    assert confirmed_booking.status == "Confirmed"


def test_confirm_departure_sets_updated_by(db_session):
    payload = make_valid_payload()
    booking = create_booking_service(db_session, payload, user="ops1")

    booking.booking_request_date = datetime(2026, 10, 1, 0, 0, tzinfo=timezone.utc)
    db_session.commit()

    confirm_payload = ShipmentBookingConfirm(
        booking_confirmation_no="CN-CONF-9988",
        vessel_name="MSC Oscar",
        voyage_number="V101",
        etd=datetime(2026, 10, 10, tzinfo=timezone.utc),
        eta=datetime(2026, 10, 25, tzinfo=timezone.utc),
    )
    confirm_booking_service(db_session, booking.booking_id, confirm_payload, user="ops2")

    depart_payload = ShipmentDepartureConfirm(
        actual_departure_date=datetime(2026, 10, 15, 10, 0, tzinfo=timezone.utc),
        bill_of_lading_no="MEDUST123456",
        shipped_on_board_date=date(2026, 10, 15),
        notes="Vessel departed on schedule",
    )
    sailed_booking = confirm_departure_and_bol_service(db_session, booking.booking_id, depart_payload, user="ops3")

    assert sailed_booking.created_by == "ops1"
    assert sailed_booking.updated_by == "ops3"
    assert sailed_booking.status == "Sailed"


def test_soft_delete_and_restore_set_updated_by(db_session):
    payload = make_valid_payload()
    booking = create_booking_service(db_session, payload, user="ops1")

    # Soft delete by ops4
    soft_delete_booking_service(db_session, booking.booking_id, user="ops4")
    db_session.refresh(booking)
    assert booking.is_active is False
    assert booking.created_by == "ops1"
    assert booking.updated_by == "ops4"

    # Restore by ops5
    restored_booking = restore_booking_service(db_session, booking.booking_id, user="ops5")
    assert restored_booking.is_active is True
    assert restored_booking.created_by == "ops1"
    assert restored_booking.updated_by == "ops5"


def test_response_schema_serializes_audit_fields(db_session):
    payload = make_valid_payload()
    booking = create_booking_service(db_session, payload, user="auditor_lead")

    res = ShipmentBookingResponse.model_validate(booking)
    assert res.created_by == "auditor_lead"
    assert res.updated_by == "auditor_lead"

    update_payload = ShipmentBookingUpdate(notes="Reviewed")
    updated = update_booking_service(db_session, booking.booking_id, update_payload, user="reviewer_agent")
    res_updated = ShipmentBookingResponse.model_validate(updated)
    assert res_updated.created_by == "auditor_lead"
    assert res_updated.updated_by == "reviewer_agent"


# ==============================================================================
# Router API Level Audit Tests (Testing session user flow via TestClient)
# ==============================================================================

def test_api_endpoints_wire_session_user(db_session):
    for u_id, name in [(10, "api_user_1"), (11, "api_user_2"), (12, "api_user_3"), (13, "api_user_4"), (14, "api_user_5")]:
        db_session.add(User(user_id=u_id, username=name, email=f"{name}@example.com", hashed_password="fake_hashed_pw", full_name=name, role="ADMIN", is_active=True))
    db_session.commit()

    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db

    client = TestClient(app)
    try:
        # 1. POST /api/v1/freight-booking as api_user_1
        create_data = {
            "import_file_id": 1,
            "shipment_type": "Ocean FCL",
            "freight_terms": "Collect",
            "containers_data": [{"container_type": "40HC", "quantity": 1}],
            "cost_charges_data": [
                {
                    "charge_type": "Ocean Freight",
                    "currency": "USD",
                    "rate": 2000.0,
                    "quantity": 1,
                    "unit": "Per Container",
                    "total": 2000.0,
                }
            ],
            "original_freight_cost_usd": 2000.0,
        }
        res = client.post("/api/v1/freight-booking", json=create_data, headers={"X-User-Name": "api_user_1"})
        assert res.status_code == 201, res.text
        data = res.json()
        booking_id = data["booking_id"]
        assert data["created_by"] == "api_user_1"
        assert data["updated_by"] == "api_user_1"

        # 2. PUT /api/v1/freight-booking/{id} as api_user_2
        res_put = client.put(f"/api/v1/freight-booking/{booking_id}", json={"notes": "Updated by user 2"}, headers={"X-User-Name": "api_user_2"})
        assert res_put.status_code == 200, res_put.text
        data_put = res_put.json()
        assert data_put["created_by"] == "api_user_1"
        assert data_put["updated_by"] == "api_user_2"

        # 3. POST /api/v1/freight-booking/{id}/confirm as api_user_3
        confirm_data = {
            "booking_confirmation_no": "CONF-API-99",
            "vessel_name": "API Vessel",
            "voyage_number": "V1",
            "etd": "2026-11-01T00:00:00Z",
            "eta": "2026-11-20T00:00:00Z",
        }
        res_conf = client.post(f"/api/v1/freight-booking/{booking_id}/confirm", json=confirm_data, headers={"X-User-Name": "api_user_3"})
        assert res_conf.status_code == 200, res_conf.text
        data_conf = res_conf.json()
        assert data_conf["created_by"] == "api_user_1"
        assert data_conf["updated_by"] == "api_user_3"

        # 4. DELETE /api/v1/freight-booking/{id} as api_user_4
        # Need Draft or Cancelled to delete; create a second booking for file 2
        create_data_2 = dict(create_data, import_file_id=2)
        res_draft = client.post("/api/v1/freight-booking", json=create_data_2, headers={"X-User-Name": "api_user_1"})
        assert res_draft.status_code == 201, res_draft.text
        draft_id = res_draft.json()["booking_id"]

        res_del = client.delete(f"/api/v1/freight-booking/{draft_id}", headers={"X-User-Name": "api_user_4"})
        assert res_del.status_code == 204

        # Check DB directly to verify updated_by on deleted row
        deleted_row = db_session.query(ShipmentBooking).filter_by(booking_id=draft_id).first()
        assert deleted_row.is_active is False
        assert deleted_row.updated_by == "api_user_4"

        # 5. PATCH /api/v1/freight-booking/{id}/restore as api_user_5
        res_rest = client.patch(f"/api/v1/freight-booking/{draft_id}/restore", headers={"X-User-Name": "api_user_5"})
        assert res_rest.status_code == 200
        data_rest = res_rest.json()
        assert data_rest["is_active"] is True
        assert data_rest["updated_by"] == "api_user_5"

    finally:
        app.dependency_overrides.clear()
