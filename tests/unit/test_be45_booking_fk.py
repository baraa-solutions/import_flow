"""Unit tests for BE45-T19: Booking FK master data on update.

Verifies:
- Unknown or inactive shipping_line_id raises HTTP 422.
- Unknown or inactive freight_forwarder_id raises HTTP 422.
- Unknown or inactive pol_location_id raises HTTP 422.
- Unknown or inactive pod_location_id raises HTTP 422.
- Unknown or inactive rfq_request_id raises HTTP 422.
- Id-only update fills names from the master rows:
  - shipping_line_name from ExternalServiceProvider.partner_name
  - freight_forwarder_name from ExternalServiceProvider.partner_name
  - pol_name from TransportLocation.location_name
  - pod_name from TransportLocation.location_name
- shipment_type must be one of 'Ocean FCL', 'Ocean LCL', 'Air' (422 otherwise).
- freight_terms must be one of 'Prepaid', 'Collect' (422 otherwise).
- Legacy rows with unexpected types or terms are read tolerantly without 500.
"""

from datetime import datetime, date, timezone
import pytest
from sqlalchemy import create_engine, text
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
    ShipmentBookingResponse,
    ContainerAllocationItem,
    BookingChargeItem,
)
from modules.freight_booking.service import (
    create_booking_service,
    update_booking_service,
    get_booking_service,
)
from modules.external_service_providers.model import ExternalServiceProvider
from modules.transport_locations.model import TransportLocation
from modules.freight_quotations.model import FreightRFQRequest
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.incoterms.model import Incoterm
from modules.projects.model import Project
from modules.import_files.model import ImportFile
from modules.currencies.model import Currency


@pytest.fixture
def db_session():
    """Isolated in-memory SQLite database session with seed master records."""
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
        echo=False,
    )
    Base.metadata.create_all(engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = TestingSessionLocal()

    # Base dependencies
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
    db.add(imp_file)

    for c_code in ["USD", "EGP", "EUR"]:
        db.add(Currency(currency_code=c_code, currency_name=c_code, currency_symbol=c_code, is_active=True))

    # Master data for freight booking
    # 1. Active & inactive shipping line
    carrier_active = ExternalServiceProvider(
        provider_id=10,
        partner_code="CAR-001",
        partner_name="Maersk Line Egypt",
        partner_type="Shipping Line",
        is_active=True,
    )
    carrier_inactive = ExternalServiceProvider(
        provider_id=11,
        partner_code="CAR-002",
        partner_name="Old Inactive Carrier",
        partner_type="Shipping Line",
        is_active=False,
    )
    db.add_all([carrier_active, carrier_inactive])

    # 2. Active & inactive freight forwarder
    fwd_active = ExternalServiceProvider(
        provider_id=20,
        partner_code="FWD-001",
        partner_name="Apex Logistics Forwarding",
        partner_type="Freight Forwarder",
        is_active=True,
    )
    fwd_inactive = ExternalServiceProvider(
        provider_id=21,
        partner_code="FWD-002",
        partner_name="Dormant Forwarder LLC",
        partner_type="Freight Forwarder",
        is_active=False,
    )
    db.add_all([fwd_active, fwd_inactive])

    # 3. Active & inactive transport locations (POL / POD)
    pol_active = TransportLocation(
        location_id=100,
        un_locode="CNSHA",
        location_name="Shanghai Port",
        location_type="Sea Port",
        country="China",
        city="Shanghai",
        is_active=True,
    )
    pol_inactive = TransportLocation(
        location_id=101,
        un_locode="CNCLOSED",
        location_name="Closed Ancient Port",
        location_type="Sea Port",
        country="China",
        city="Somewhere",
        is_active=False,
    )
    pod_active = TransportLocation(
        location_id=200,
        un_locode="EGALY",
        location_name="Alexandria Port",
        location_type="Sea Port",
        country="Egypt",
        city="Alexandria",
        is_active=True,
    )
    pod_inactive = TransportLocation(
        location_id=201,
        un_locode="EGBUR",
        location_name="Decommissioned Port",
        location_type="Sea Port",
        country="Egypt",
        city="Bur Safaga",
        is_active=False,
    )
    db.add_all([pol_active, pol_inactive, pod_active, pod_inactive])

    # 4. Active & inactive RFQ request
    rfq_active = FreightRFQRequest(
        rfq_id=300,
        rfq_code="RFQ-2026-0001",
        title="RFQ Ocean FCL 40HC",
        shipping_method="Ocean FCL",
        crd_date=date(2026, 11, 1),
        pol_id=100,
        pol_name="Shanghai Port",
        pod_id=200,
        pod_name="Alexandria Port",
        import_file_id=1,
        is_active=True,
    )
    rfq_inactive = FreightRFQRequest(
        rfq_id=301,
        rfq_code="RFQ-2026-0002",
        title="RFQ Cancelled",
        shipping_method="Ocean FCL",
        crd_date=date(2026, 11, 1),
        pol_id=100,
        pol_name="Shanghai Port",
        pod_id=200,
        pod_name="Alexandria Port",
        is_active=False,
    )
    db.add_all([rfq_active, rfq_inactive])

    db.commit()
    yield db
    db.close()


@pytest.fixture
def test_client(db_session):
    def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)
    yield client
    app.dependency_overrides.clear()


def _create_sample_booking(db, shipment_type="Ocean FCL", status="Draft") -> ShipmentBooking:
    payload = ShipmentBookingCreate(
        import_file_id=1,
        shipment_type=shipment_type,
        status=status,
        containers_data=[ContainerAllocationItem(container_type="40HC", quantity=1)],
        cost_charges_data=[
            BookingChargeItem(
                charge_type="Sea Freight",
                unit="Per Container",
                quantity=1.0,
                currency="USD",
                rate=1500.0,
                total=1500.0,
            )
        ],
    )
    return create_booking_service(db, payload, user="test_user")


# ==============================================================================
# Master Data Foreign Key Validation Tests
# ==============================================================================

def test_unknown_shipping_line_id_gives_422(db_session):
    bkg = _create_sample_booking(db_session)
    update_payload = ShipmentBookingUpdate(shipping_line_id=999999)
    with pytest.raises(HTTPException) as exc_info:
        update_booking_service(db_session, bkg.booking_id, update_payload)
    assert exc_info.value.status_code == 422
    assert "الخط الملاحي غير موجود أو غير مفعل" in exc_info.value.detail


def test_inactive_shipping_line_id_gives_422(db_session):
    bkg = _create_sample_booking(db_session)
    update_payload = ShipmentBookingUpdate(shipping_line_id=11)
    with pytest.raises(HTTPException) as exc_info:
        update_booking_service(db_session, bkg.booking_id, update_payload)
    assert exc_info.value.status_code == 422
    assert "الخط الملاحي غير موجود أو غير مفعل" in exc_info.value.detail


def test_unknown_freight_forwarder_id_gives_422(db_session):
    bkg = _create_sample_booking(db_session)
    update_payload = ShipmentBookingUpdate(freight_forwarder_id=999999)
    with pytest.raises(HTTPException) as exc_info:
        update_booking_service(db_session, bkg.booking_id, update_payload)
    assert exc_info.value.status_code == 422
    assert "شركة الشحن / وكيل الشحن غير موجود أو غير مفعل" in exc_info.value.detail


def test_inactive_freight_forwarder_id_gives_422(db_session):
    bkg = _create_sample_booking(db_session)
    update_payload = ShipmentBookingUpdate(freight_forwarder_id=21)
    with pytest.raises(HTTPException) as exc_info:
        update_booking_service(db_session, bkg.booking_id, update_payload)
    assert exc_info.value.status_code == 422
    assert "شركة الشحن / وكيل الشحن غير موجود أو غير مفعل" in exc_info.value.detail


def test_unknown_pol_location_id_gives_422(db_session):
    bkg = _create_sample_booking(db_session)
    update_payload = ShipmentBookingUpdate(pol_location_id=999999)
    with pytest.raises(HTTPException) as exc_info:
        update_booking_service(db_session, bkg.booking_id, update_payload)
    assert exc_info.value.status_code == 422
    assert "ميناء الشحن (POL) غير موجود أو غير مفعل" in exc_info.value.detail


def test_inactive_pol_location_id_gives_422(db_session):
    bkg = _create_sample_booking(db_session)
    update_payload = ShipmentBookingUpdate(pol_location_id=101)
    with pytest.raises(HTTPException) as exc_info:
        update_booking_service(db_session, bkg.booking_id, update_payload)
    assert exc_info.value.status_code == 422
    assert "ميناء الشحن (POL) غير موجود أو غير مفعل" in exc_info.value.detail


def test_unknown_pod_location_id_gives_422(db_session):
    bkg = _create_sample_booking(db_session)
    update_payload = ShipmentBookingUpdate(pod_location_id=999999)
    with pytest.raises(HTTPException) as exc_info:
        update_booking_service(db_session, bkg.booking_id, update_payload)
    assert exc_info.value.status_code == 422
    assert "ميناء الوصول (POD) غير موجود أو غير مفعل" in exc_info.value.detail


def test_inactive_pod_location_id_gives_422(db_session):
    bkg = _create_sample_booking(db_session)
    update_payload = ShipmentBookingUpdate(pod_location_id=201)
    with pytest.raises(HTTPException) as exc_info:
        update_booking_service(db_session, bkg.booking_id, update_payload)
    assert exc_info.value.status_code == 422
    assert "ميناء الوصول (POD) غير موجود أو غير مفعل" in exc_info.value.detail


def test_unknown_rfq_request_id_gives_422(db_session):
    bkg = _create_sample_booking(db_session)
    update_payload = ShipmentBookingUpdate(rfq_request_id=999999)
    with pytest.raises(HTTPException) as exc_info:
        update_booking_service(db_session, bkg.booking_id, update_payload)
    assert exc_info.value.status_code == 422
    assert "طلب تسعير الشحن (RFQ) غير موجود أو غير مفعل" in exc_info.value.detail


def test_inactive_rfq_request_id_gives_422(db_session):
    bkg = _create_sample_booking(db_session)
    update_payload = ShipmentBookingUpdate(rfq_request_id=301)
    with pytest.raises(HTTPException) as exc_info:
        update_booking_service(db_session, bkg.booking_id, update_payload)
    assert exc_info.value.status_code == 422
    assert "طلب تسعير الشحن (RFQ) غير موجود أو غير مفعل" in exc_info.value.detail


# ==============================================================================
# ID-Only Update Auto-Fills Names Tests
# ==============================================================================

def test_id_only_update_fills_shipping_line_name(db_session):
    bkg = _create_sample_booking(db_session)
    assert bkg.shipping_line_id is None
    assert bkg.shipping_line_name is None

    update_payload = ShipmentBookingUpdate(shipping_line_id=10)
    updated = update_booking_service(db_session, bkg.booking_id, update_payload)

    assert updated.shipping_line_id == 10
    assert updated.shipping_line_name == "Maersk Line Egypt"


def test_id_only_update_fills_all_master_names(db_session):
    bkg = _create_sample_booking(db_session)

    update_payload = ShipmentBookingUpdate(
        shipping_line_id=10,
        freight_forwarder_id=20,
        pol_location_id=100,
        pod_location_id=200,
        rfq_request_id=300,
    )
    updated = update_booking_service(db_session, bkg.booking_id, update_payload)

    assert updated.shipping_line_id == 10
    assert updated.shipping_line_name == "Maersk Line Egypt"

    assert updated.freight_forwarder_id == 20
    assert updated.freight_forwarder_name == "Apex Logistics Forwarding"

    assert updated.pol_location_id == 100
    assert updated.pol_name == "Shanghai Port"

    assert updated.pod_location_id == 200
    assert updated.pod_name == "Alexandria Port"

    assert updated.rfq_request_id == 300


def test_explicit_name_not_overwritten(db_session):
    bkg = _create_sample_booking(db_session)

    update_payload = ShipmentBookingUpdate(
        shipping_line_id=10,
        shipping_line_name="Custom Carrier Alias",
    )
    updated = update_booking_service(db_session, bkg.booking_id, update_payload)

    assert updated.shipping_line_id == 10
    assert updated.shipping_line_name == "Custom Carrier Alias"


# ==============================================================================
# Literal Types: shipment_type & freight_terms Validation
# ==============================================================================

def test_invalid_shipment_type_gives_422_via_api(test_client, db_session):
    bkg = _create_sample_booking(db_session)

    # PUT invalid shipment_type
    res = test_client.put(
        f"/api/v1/freight-booking/{bkg.booking_id}",
        json={"shipment_type": "Space Freight"},
    )
    assert res.status_code == 422


def test_invalid_freight_terms_gives_422_via_api(test_client, db_session):
    bkg = _create_sample_booking(db_session)

    # PUT invalid freight_terms
    res = test_client.put(
        f"/api/v1/freight-booking/{bkg.booking_id}",
        json={"freight_terms": "Installments"},
    )
    assert res.status_code == 422


def test_valid_shipment_type_and_freight_terms_update(test_client, db_session):
    bkg = _create_sample_booking(db_session)

    res = test_client.put(
        f"/api/v1/freight-booking/{bkg.booking_id}",
        json={
            "shipment_type": "Air",
            "freight_terms": "Prepaid",
            "shipping_line_id": 10,
        },
    )
    assert res.status_code == 200
    data = res.json()
    assert data["shipment_type"] == "Air"
    assert data["freight_terms"] == "Prepaid"
    assert data["shipping_line_id"] == 10
    assert data["shipping_line_name"] == "Maersk Line Egypt"


# ==============================================================================
# Legacy Row Tolerance Test
# ==============================================================================

def test_legacy_response_tolerates_non_literal_values(db_session):
    """Raw SQL row with unexpected strings in shipment_type or freight_terms loads without 500."""
    stmt = text(
        """
        INSERT INTO shipment_bookings (
            booking_code, shipment_type, freight_terms,
            total_freight_cost_usd, original_freight_cost_usd, cost_savings_usd, cost_variance_usd,
            status, owner, is_active, created_at, updated_at
        ) VALUES (
            'BKG-LEGACY-001', 'Legacy Custom Mode', 'Custom Credit 60',
            1500.0, 1500.0, 0.0, 0.0,
            'Draft', 'system', 1, datetime('now'), datetime('now')
        )
        """
    )
    db_session.execute(stmt)
    db_session.commit()

    legacy_row = db_session.query(ShipmentBooking).filter_by(booking_code="BKG-LEGACY-001").first()
    assert legacy_row is not None

    # Serialization via ShipmentBookingResponse must not fail
    response_model = ShipmentBookingResponse.model_validate(legacy_row)
    assert response_model.booking_code == "BKG-LEGACY-001"
    assert response_model.shipment_type == "Legacy Custom Mode"
    assert response_model.freight_terms == "Custom Credit 60"
