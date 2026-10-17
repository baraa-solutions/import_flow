"""Unit tests for BE45-T12: Lock Sailed and Cancelled bookings.

Validates that:
- Cancelled bookings cannot be edited (PUT returns 409 Conflict).
- Confirmed and Amended bookings lock bill_of_lading_no, atd, and import_file_id (409 Conflict).
- Sailed bookings lock all fields except SAILED_EDITABLE (notes, eta, vessel_name, voyage_number, status).
- PUT {"bill_of_lading_no": null} on Sailed gives 409 and keeps the original B/L.
- PUT with modified costs or container data on Sailed gives 409.
- Re-sending unchanged values on a Sailed booking gives 200 OK.
- Updating container allocation on update validates Ocean FCL requirement (400 if empty).
"""

from datetime import datetime, date, timezone
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi import HTTPException
from fastapi.testclient import TestClient

from database.database import Base, get_db
from main import app
from modules.freight_booking.model import ShipmentBooking
from modules.freight_booking.schemas import (
    ShipmentBookingCreate,
    ShipmentBookingUpdate,
    ContainerAllocationItem,
    BookingChargeItem,
)
from modules.freight_booking.service import (
    create_booking_service,
    update_booking_service,
    get_booking_service,
)
from modules.freight_booking import validators
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.incoterms.model import Incoterm
from modules.projects.model import Project
from modules.import_files.model import ImportFile
from modules.currencies.model import Currency


@pytest.fixture
def db_session():
    """Isolated in-memory SQLite database session."""
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
    inco = Incoterm(
        incoterm_id=1,
        incoterm_code="FOB",
        incoterm_name="Free On Board",
        description="FOB",
    )
    proj = Project(
        project_id=1,
        project_code="PRJ-01",
        project_name="Expansion 2026",
        project_owner="Kamal",
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
    )
    file_rec = ImportFile(
        import_file_id=1,
        import_file_code="IMP-2026-0001",
        custom_file_number="6701068100",
        company_name="Egyptian Import Co",
        supplier_name="ABC Global Exporters",
        current_module="STEP_06 حجز النولون وتأكيد الخط الملاحي",
        progress_percent=40.0,
        target_free_days=21,
        owner="Kamal",
        is_active=True,
    )
    file_rec2 = ImportFile(
        import_file_id=2,
        import_file_code="IMP-2026-0002",
        custom_file_number="6701068200",
        company_name="Egyptian Import Co",
        supplier_name="ABC Global Exporters",
        current_module="STEP_06 حجز النولون وتأكيد الخط الملاحي",
        progress_percent=40.0,
        target_free_days=21,
        owner="Kamal",
        is_active=True,
    )

    curr1 = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
    curr2 = Currency(currency_code="EGP", currency_name="Egyptian Pound", currency_symbol="EGP", is_base_currency=True, is_active=True)
    db.add_all([comp, sup, inco, proj, file_rec, file_rec2, curr1, curr2])
    db.commit()

    try:
        yield db
    finally:
        db.close()


@pytest.fixture
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    app.dependency_overrides.clear()


def _create_sample_booking(db, *, status="Draft", import_file_id=1, bl="BL-12345", atd=None):
    payload = ShipmentBookingCreate(
        import_file_id=import_file_id,
        shipping_line_name="MSC",
        freight_forwarder_name="FastFreight",
        shipment_type="Ocean FCL",
        pol_name="Shanghai",
        pod_name="Alexandria",
        etd=datetime(2026, 10, 1, 10, 0, tzinfo=timezone.utc),
        eta=datetime(2026, 10, 20, 10, 0, tzinfo=timezone.utc),
        free_demurrage_days=14,
        vessel_name="MSC OSCAR",
        voyage_number="2608W",
        containers_data=[ContainerAllocationItem(container_type="40HC", quantity=1)],
        cost_charges_data=[BookingChargeItem(charge_type="Sea Freight", rate=1500.0, quantity=1, total=1500.0)],
        notes="Initial booking note",
    )
    booking = create_booking_service(db, payload, user="tester")
    booking.status = status
    booking.bill_of_lading_no = bl
    if atd:
        booking.atd = atd
    db.commit()
    db.refresh(booking)
    return booking


class TestBE45BookingLock:

    def test_put_on_cancelled_booking_gives_409(self, db_session):
        """PUT on a Cancelled booking gives 409 Conflict, even when modifying costs or notes."""
        booking = _create_sample_booking(db_session, status="Cancelled")

        update_payload = ShipmentBookingUpdate(
            cost_charges_data=[
                BookingChargeItem(charge_type="Sea Freight", rate=2000.0, quantity=1, total=2000.0)
            ]
        )

        with pytest.raises(HTTPException) as exc_info:
            update_booking_service(db_session, booking.booking_id, update_payload)

        assert exc_info.value.status_code == 409
        assert "ملغاة" in exc_info.value.detail or "Cancelled" in exc_info.value.detail

    def test_put_locked_fields_on_confirmed_gives_409(self, db_session):
        """On Confirmed, PUT of bill_of_lading_no, atd or import_file_id gives 409."""
        booking = _create_sample_booking(db_session, status="Confirmed", bl="ORIG-BL")

        # 1. Changing B/L number gives 409
        with pytest.raises(HTTPException) as exc1:
            update_booking_service(
                db_session,
                booking.booking_id,
                ShipmentBookingUpdate(bill_of_lading_no="NEW-BL"),
            )
        assert exc1.value.status_code == 409
        assert "bill_of_lading_no" in exc1.value.detail

        # 2. Changing atd gives 409
        with pytest.raises(HTTPException) as exc2:
            update_booking_service(
                db_session,
                booking.booking_id,
                ShipmentBookingUpdate(atd=datetime(2026, 10, 5, 12, 0, tzinfo=timezone.utc)),
            )
        assert exc2.value.status_code == 409
        assert "atd" in exc2.value.detail

        # 3. Changing import_file_id gives 409
        with pytest.raises(HTTPException) as exc3:
            update_booking_service(
                db_session,
                booking.booking_id,
                ShipmentBookingUpdate(import_file_id=2),
            )
        assert exc3.value.status_code == 409
        assert "import_file_id" in exc3.value.detail

        # 4. Modifying notes or eta is allowed on Confirmed
        updated = update_booking_service(
            db_session,
            booking.booking_id,
            ShipmentBookingUpdate(notes="Updated confirmed notes", eta=datetime(2026, 10, 25, 10, 0, tzinfo=timezone.utc)),
        )
        assert updated.notes == "Updated confirmed notes"

    def test_put_locked_fields_on_amended_gives_409(self, db_session):
        """On Amended, PUT of bill_of_lading_no, atd or import_file_id gives 409."""
        booking = _create_sample_booking(db_session, status="Amended", bl="AMEND-BL")

        with pytest.raises(HTTPException) as exc:
            update_booking_service(
                db_session,
                booking.booking_id,
                ShipmentBookingUpdate(bill_of_lading_no="ANOTHER-BL"),
            )
        assert exc.value.status_code == 409
        assert "bill_of_lading_no" in exc.value.detail

    def test_put_bl_null_on_sailed_gives_409_and_keeps_bl(self, db_session):
        """PUT {"bill_of_lading_no": null} on Sailed gives 409 and original B/L is retained."""
        orig_bl = "MEDU-SAILED-777"
        booking = _create_sample_booking(
            db_session,
            status="Sailed",
            bl=orig_bl,
            atd=datetime(2026, 10, 2, 8, 0, tzinfo=timezone.utc),
        )

        with pytest.raises(HTTPException) as exc:
            update_booking_service(
                db_session,
                booking.booking_id,
                ShipmentBookingUpdate(bill_of_lading_no=None),
            )
        assert exc.value.status_code == 409
        assert "bill_of_lading_no" in exc.value.detail

        # Verify B/L number is unchanged in database
        db_session.refresh(booking)
        assert booking.bill_of_lading_no == orig_bl

    def test_put_costs_or_containers_on_sailed_gives_409(self, db_session):
        """On Sailed, cost and container fields give 409 as well."""
        booking = _create_sample_booking(
            db_session,
            status="Sailed",
            bl="BL-SAILED-100",
            atd=datetime(2026, 10, 2, 8, 0, tzinfo=timezone.utc),
        )

        # 1. Modifying costs gives 409
        with pytest.raises(HTTPException) as exc1:
            update_booking_service(
                db_session,
                booking.booking_id,
                ShipmentBookingUpdate(
                    cost_charges_data=[
                        BookingChargeItem(charge_type="Sea Freight", rate=3000.0, quantity=1, total=3000.0)
                    ]
                ),
            )
        assert exc1.value.status_code == 409
        assert "cost_charges_data" in exc1.value.detail

        # 2. Modifying containers gives 409
        with pytest.raises(HTTPException) as exc2:
            update_booking_service(
                db_session,
                booking.booking_id,
                ShipmentBookingUpdate(
                    containers_data=[
                        ContainerAllocationItem(container_type="20GP", quantity=3)
                    ]
                ),
            )
        assert exc2.value.status_code == 409
        assert "containers_data" in exc2.value.detail

    def test_put_resending_unchanged_values_on_sailed_gives_200(self, db_session):
        """A PUT re-sending unchanged values of a Sailed booking gives 200 OK."""
        booking = _create_sample_booking(
            db_session,
            status="Sailed",
            bl="BL-SAILED-200",
            atd=datetime(2026, 10, 2, 8, 0, tzinfo=timezone.utc),
        )

        # Re-send all current values as the frontend form does
        resend_payload = ShipmentBookingUpdate(
            booking_confirmation_no=booking.booking_confirmation_no,
            bill_of_lading_no=booking.bill_of_lading_no,
            import_file_id=booking.import_file_id,
            shipment_type=booking.shipment_type,
            pol_name=booking.pol_name,
            pod_name=booking.pod_name,
            etd=booking.etd,
            eta=booking.eta,
            atd=booking.atd,
            free_demurrage_days=booking.free_demurrage_days,
            vessel_name=booking.vessel_name,
            voyage_number=booking.voyage_number,
            containers_data=[ContainerAllocationItem(container_type="40HC", quantity=1)],
            cost_charges_data=[BookingChargeItem(charge_type="Sea Freight", rate=1500.0, quantity=1, total=1500.0)],
            notes=booking.notes,
            status=booking.status,
        )

        updated = update_booking_service(db_session, booking.booking_id, resend_payload)
        assert updated.booking_id == booking.booking_id
        assert updated.bill_of_lading_no == "BL-SAILED-200"
        assert updated.status == "Sailed"

    def test_put_allowed_fields_on_sailed_gives_200(self, db_session):
        """On Sailed, SAILED_EDITABLE fields (notes, eta, vessel_name, voyage_number) can be updated."""
        booking = _create_sample_booking(
            db_session,
            status="Sailed",
            bl="BL-SAILED-300",
            atd=datetime(2026, 10, 2, 8, 0, tzinfo=timezone.utc),
        )

        new_eta = datetime(2026, 10, 28, 14, 0, tzinfo=timezone.utc)
        payload = ShipmentBookingUpdate(
            notes="Delayed due to storm in Mediterranean",
            eta=new_eta,
            vessel_name="MSC NEW VESSEL",
            voyage_number="9999X",
        )

        updated = update_booking_service(db_session, booking.booking_id, payload)
        assert updated.notes == "Delayed due to storm in Mediterranean"
        assert updated.eta.replace(tzinfo=None) == new_eta.replace(tzinfo=None)
        assert updated.vessel_name == "MSC NEW VESSEL"
        assert updated.voyage_number == "9999X"

    def test_container_allocation_validation_on_update(self, db_session):
        """Updating container allocation on update validates Ocean FCL requirement."""
        booking = _create_sample_booking(db_session, status="Draft")

        # 1. Setting empty containers on Ocean FCL raises 400
        with pytest.raises(HTTPException) as exc:
            update_booking_service(
                db_session,
                booking.booking_id,
                ShipmentBookingUpdate(containers_data=[]),
            )
        assert exc.value.status_code == 400
        assert "حاوية واحدة على الأقل" in exc.value.detail

        # 2. Valid containers update passes
        updated = update_booking_service(
            db_session,
            booking.booking_id,
            ShipmentBookingUpdate(
                containers_data=[
                    ContainerAllocationItem(container_type="20GP", quantity=2)
                ]
            ),
        )
        assert len(updated.containers_data) == 1
        assert updated.containers_data[0]["container_type"] == "20GP"

    def test_router_put_locks_via_http_client(self, client, db_session):
        """Endpoint-level tests for HTTP 409 responses on locked bookings."""
        # Sailed booking
        booking_sailed = _create_sample_booking(db_session, status="Sailed", bl="BL-HTTP-SAILED")

        # 1. Modifying B/L on Sailed via PUT gives 409
        res1 = client.put(
            f"/api/v1/freight-booking/{booking_sailed.booking_id}",
            json={"bill_of_lading_no": "ALTERED-BL"},
        )
        assert res1.status_code == 409
        assert "bill_of_lading_no" in res1.json()["detail"]

        # 2. Cancelled booking via PUT gives 409
        booking_cancelled = _create_sample_booking(db_session, status="Cancelled", import_file_id=2)
        res2 = client.put(
            f"/api/v1/freight-booking/{booking_cancelled.booking_id}",
            json={"notes": "Try updating notes on cancelled"},
        )
        assert res2.status_code == 409
        assert "ملغاة" in res2.json()["detail"] or "Cancelled" in res2.json()["detail"]

        # 3. Unchanged re-send on Sailed via PUT gives 200
        res3 = client.put(
            f"/api/v1/freight-booking/{booking_sailed.booking_id}",
            json={
                "bill_of_lading_no": "BL-HTTP-SAILED",
                "notes": "Updated note on sailed",
            },
        )
        assert res3.status_code == 200
        assert res3.json()["notes"] == "Updated note on sailed"
