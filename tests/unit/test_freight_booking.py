from datetime import datetime, date, timezone
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.freight_booking.schemas import (
    ShipmentBookingCreate,
    ShipmentBookingUpdate,
    ContainerAllocationItem,
    BookingChargeItem,
)
from modules.freight_booking.service import (
    create_booking_service,
    get_booking_service,
    list_bookings_service,
    update_booking_service,
    soft_delete_booking_service,
    restore_booking_service,
)
from modules.customs_tariff.model import CustomsTariff
from modules.currencies.model import Currency
from modules.purchase_orders.model import PurchaseOrder
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.external_service_providers.model import ExternalServiceProvider
from modules.transport_locations.model import TransportLocation
from modules.freight_quotations.model import FreightRFQRequest
from modules.shipping_scenarios.model import ShippingEvaluationSession, ShippingScenarioItem
from modules.incoterms.model import Incoterm
from modules.projects.model import Project
from modules.import_files.model import ImportFile


@pytest.fixture
def db_session():
    """Creates in-memory SQLite DB fixture."""
    engine = create_engine("sqlite:///:memory:", echo=False)
    Base.metadata.create_all(engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = TestingSessionLocal()

    comp1 = ImportCompany(company_id=1, importer_name="Egyptian Import Co", vat_id="100-200-300", registration_number="12345", address="Cairo", country="Egypt", importer_id="IMP-001", importer_id_expiry=date(2028,1,1), vat_id_expiry=date(2028,1,1), registration_expiry=date(2028,1,1))
    sup1 = Supplier(supplier_id=1, company_name="ABC China", supplier_code="SUP-01", supplier_type="Manufacturer", registration_type="Foreign Exporter", foreign_exporter_id="CN-99", foreign_exporter_country="China", foreign_exporter_country_code="CN", address="Shanghai")
    inco1 = Incoterm(incoterm_id=1, incoterm_code="FOB", incoterm_name="Free On Board", description="Seller delivers goods on board vessel")
    proj1 = Project(project_id=1, project_code="PRJ-01", project_name="Textile Expansion", project_owner="Kamal", company_id=1, supplier_id=1, incoterm_id=1, import_type="Direct Commercial")
    file1 = ImportFile(import_file_id=1, import_file_code="IMP-2026-0001", custom_file_number="6701068100", company_name="Egyptian Import Co", supplier_name="ABC China", owner="Kamal")
    
    curr1 = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
    curr2 = Currency(currency_code="EGP", currency_name="Egyptian Pound", currency_symbol="EGP", is_base_currency=True, is_active=True)
    db.add_all([comp1, sup1, inco1, proj1, file1, curr1, curr2])
    db.commit()

    try:
        yield db
    finally:
        db.close()


class TestFreightBookingBackend:

    def test_create_shipment_booking_success(self, db_session):
        payload = ShipmentBookingCreate(
            import_file_id=1,
            booking_confirmation_no="MSC-CN-9900",
            freight_forwarder_name="El-Ahram Logistics",
            shipping_line_name="MSC",
            shipment_type="Ocean FCL",
            pol_name="Shanghai Port",
            pod_name="Alexandria Port",
            etd=datetime(2026, 8, 10, 10, 0, tzinfo=timezone.utc),
            eta=datetime(2026, 8, 25, 10, 0, tzinfo=timezone.utc),
            free_demurrage_days=14,
            containers_data=[
                ContainerAllocationItem(container_type="40HC", quantity=2, container_numbers=["MSCU11", "MSCU22"])
            ],
            cost_charges_data=[
                BookingChargeItem(charge_type="Sea Freight", unit="Per Container", quantity=1, rate=2000.0),
                BookingChargeItem(charge_type="BL Fee", unit="Per Shipment", quantity=1, rate=100.0)
            ],
            status="Draft",
            owner="Kamal",
        )

        booking = create_booking_service(db_session, payload)
        assert booking.booking_id is not None
        assert booking.booking_code.startswith("BKG-2026-")
        assert booking.transit_time_days == 15
        # 2 containers * 2000 + 1 * 100 = 4100
        assert booking.total_freight_cost_usd == 4100.0

    def test_transit_time_and_costs_calculation(self, db_session):
        payload = ShipmentBookingCreate(
            shipment_type="Ocean FCL",
            etd=datetime(2026, 9, 1, 0, 0, tzinfo=timezone.utc),
            eta=datetime(2026, 9, 21, 0, 0, tzinfo=timezone.utc),
            containers_data=[
                ContainerAllocationItem(container_type="20GP", quantity=3)
            ],
            cost_charges_data=[
                BookingChargeItem(charge_type="Sea Freight", unit="Per Container", quantity=1, rate=1500.0),
                BookingChargeItem(charge_type="THC", unit="Per Container", quantity=1, rate=300.0)
            ],
        )

        booking = create_booking_service(db_session, payload)
        assert booking.transit_time_days == 20
        # (1500 * 3) + (300 * 3) = 5400
        assert booking.total_freight_cost_usd == 5400.0

    def test_update_booking_status_and_vessel(self, db_session):
        payload = ShipmentBookingCreate(
            shipment_type="Ocean FCL",
            containers_data=[ContainerAllocationItem(container_type="40HC", quantity=1)],
            status="Draft"
        )
        booking = create_booking_service(db_session, payload)

        # FB-02: Confirmed / Sailed can no longer be set through PUT (409); the manual statuses still can
        with pytest.raises(HTTPException) as exc_info:
            update_booking_service(db_session, booking.booking_id, ShipmentBookingUpdate(status="Confirmed"))
        assert exc_info.value.status_code == 409

        update_payload = ShipmentBookingUpdate(
            vessel_name="MSC Oscar",
            voyage_number="VY-99",
            status="Booking Requested"
        )
        updated = update_booking_service(db_session, booking.booking_id, update_payload)
        assert updated.vessel_name == "MSC Oscar"
        assert updated.status == "Booking Requested"

    def test_soft_delete_booking(self, db_session):
        payload = ShipmentBookingCreate(
            shipment_type="Ocean FCL",
            containers_data=[ContainerAllocationItem(container_type="40HC", quantity=1)]
        )
        booking = create_booking_service(db_session, payload)
        b_id = booking.booking_id

        success = soft_delete_booking_service(db_session, b_id)
        assert success is True

        with pytest.raises(HTTPException) as exc_info:
            get_booking_service(db_session, b_id)
        assert exc_info.value.status_code == 404

        # Restore
        restored = restore_booking_service(db_session, b_id)
        assert restored is not None
        assert restored.booking_id == b_id
        assert restored.is_active is True

    def test_create_booking_linked_to_shipping_scenario_quote(self, db_session):
        payload = ShipmentBookingCreate(
            import_file_id=1,
            scenario_session_id=10,
            scenario_item_id=25,
            scenario_provider_name="Mediterranean Shipping Company (MSC)",
            booking_confirmation_no="MSC-EGY-2026-99",
            freight_forwarder_name="El-Ahram Logistics",
            shipping_line_name="MSC",
            vessel_name="MSC Oscar",
            voyage_number="VY-2026-X8",
            shipment_type="Ocean FCL",
            pol_name="Shanghai Port",
            pod_name="Alexandria Port",
            etd=datetime(2026, 8, 10, 10, 0, tzinfo=timezone.utc),
            eta=datetime(2026, 8, 28, 10, 0, tzinfo=timezone.utc),
            free_demurrage_days=21,
            containers_data=[
                ContainerAllocationItem(container_type="40HC", quantity=2, container_numbers=["MSCU1000000", "MSCU1111111"])
            ],
            cost_charges_data=[
                BookingChargeItem(charge_type="Sea Freight 40ft", unit="Per Container", quantity=2, rate=2200.0, total=4400.0),
                BookingChargeItem(charge_type="DTHC", unit="Per Shipment", quantity=1, rate=350.0, total=350.0),
                BookingChargeItem(charge_type="Storage per one week", unit="Per Week", quantity=1, rate=200.0, total=200.0),
            ],
            status="Draft",
            owner="Kamal",
        )

        booking = create_booking_service(db_session, payload)
        assert booking.booking_id is not None
        assert booking.scenario_session_id == 10
        assert booking.scenario_item_id == 25
        assert booking.scenario_provider_name == "Mediterranean Shipping Company (MSC)"
        assert booking.vessel_name == "MSC Oscar"
        assert booking.free_demurrage_days == 21
        assert len(booking.containers_data) == 1
        assert len(booking.cost_charges_data) == 3
        assert booking.total_freight_cost_usd == (2200.0 * 2) + 350.0 + 200.0

    def test_actual_departure_delay_and_warehouse_arrival_calc(self, db_session):
        payload = ShipmentBookingCreate(
            import_file_id=1,
            booking_confirmation_no="MSC-DELAY-001",
            shipping_line_name="MSC",
            shipment_type="Ocean FCL",
            etd=datetime(2026, 8, 1, 0, 0, tzinfo=timezone.utc),
            eta=datetime(2026, 8, 20, 0, 0, tzinfo=timezone.utc),
            atd=datetime(2026, 8, 5, 0, 0, tzinfo=timezone.utc),  # 4 days delay
            expected_warehouse_days=5,
            container_mismatch_reason="Client requested 40HC instead of 20GP due to volumetric cargo expansion",
            containers_data=[
                ContainerAllocationItem(
                    container_type="40HC",
                    quantity=1,
                    container_numbers=["MSCU998877"],
                    sealNumbers=["SL-12345"] if hasattr(ContainerAllocationItem, "sealNumbers") else []
                )
            ],
            quotation_details_data={"dthc_app": True, "dthc_price": 400.0},
        )

        booking = create_booking_service(db_session, payload)
        assert booking.departure_delay_days == 4
        # ETA was Aug 20, adjusted ETA with 4 days delay = Aug 24 + 5 days warehouse = Aug 29
    def test_prevent_duplicate_booking_for_same_import_file(self, db_session):
        from fastapi import HTTPException

        payload1 = ShipmentBookingCreate(
            import_file_id=1,
            booking_confirmation_no="MSC-FIRST-001",
            shipping_line_name="MSC",
            shipment_type="Ocean FCL",
            containers_data=[ContainerAllocationItem(container_type="40HC", quantity=1)],
        )
        b1 = create_booking_service(db_session, payload1)
        assert b1.booking_id is not None

        # Attempt to create a second booking for the same import_file_id=1
        payload2 = ShipmentBookingCreate(
            import_file_id=1,
            booking_confirmation_no="MSC-DUPLICATE-002",
            shipping_line_name="CMA CGM",
            shipment_type="Ocean FCL",
            containers_data=[ContainerAllocationItem(container_type="20GP", quantity=1)],
        )
        with pytest.raises(HTTPException) as exc_info:
            create_booking_service(db_session, payload2)

        assert exc_info.value.status_code == 400
        assert "يوجد بالفعل حجز شحن مسجل لهذا الملف الاستيرادي" in exc_info.value.detail

    def test_cost_savings_calculation_40ft(self, db_session):
        # 2x 40ft container: quoted at 8280.0, negotiated down to 7750.0
        # Savings = (8280 - 7750) * 2 = 1060 USD
        payload = ShipmentBookingCreate(
            booking_confirmation_no="WHL-SAV-40FT",
            shipping_line_name="Wan Hai Lines Ltd.",
            shipment_type="Ocean FCL",
            original_freight_cost_usd=16560.0,
            quotation_details_data={
                "original_quote_total_usd": 16560.0,
                "original_container_40ft_price": 8280.0,
                "container_40ft_app": True,
                "container_40ft_price": 7750.0,
                "container_40ft_qty": 2,
            },
            containers_data=[
                ContainerAllocationItem(container_type="40HC", quantity=2)
            ],
            cost_charges_data=[
                BookingChargeItem(charge_type="Sea Freight 40ft", unit="Per Container", quantity=2, rate=7750.0, total=15500.0)
            ],
        )
        booking = create_booking_service(db_session, payload)
        assert booking.original_freight_cost_usd == 16560.0
        assert booking.total_freight_cost_usd == 15500.0
        assert booking.cost_savings_usd == 1060.0
        assert booking.cost_variance_usd == 1060.0
        assert "Sea Freight 40ft" in booking.savings_notes
        assert "1,060.00 USD" in booking.savings_notes
        assert len(booking.quotation_details_data["savings_breakdown"]) == 1
        assert booking.quotation_details_data["savings_breakdown"][0]["unit_diff"] == 530.0
        assert booking.quotation_details_data["savings_breakdown"][0]["quantity"] == 2
        assert booking.quotation_details_data["savings_breakdown"][0]["item_savings"] == 1060.0

    def test_cost_savings_calculation_20ft_and_lcl(self, db_session):
        # 3x 20ft container: quoted at 2500.0, negotiated to 2200.0 (savings = 300 * 3 = 900)
        # Plus LCL: 10 CBM quoted at 80.0, negotiated to 70.0 (savings = 10 * 10 = 100)
        # Total savings = 1000.0 USD
        payload = ShipmentBookingCreate(
            booking_confirmation_no="MSC-SAV-20FT-LCL",
            shipping_line_name="MSC",
            shipment_type="Ocean FCL",
            quotation_details_data={
                "original_quote_total_usd": 8300.0,
                "original_container_20ft_price": 2500.0,
                "original_lcl_cbm_price": 80.0,
                "container_20ft_app": True,
                "container_20ft_price": 2200.0,
                "container_20ft_qty": 3,
                "lcl_cbm_app": True,
                "lcl_cbm_price": 70.0,
                "lcl_cbm_qty": 10.0,
            },
            containers_data=[
                ContainerAllocationItem(container_type="20GP", quantity=3)
            ],
            cost_charges_data=[
                BookingChargeItem(charge_type="Sea Freight 20ft", unit="Per Container", quantity=3, rate=2200.0, total=6600.0),
                BookingChargeItem(charge_type="LCL CBM Freight", unit="Per CBM", quantity=10, rate=70.0, total=700.0),
            ],
        )
        booking = create_booking_service(db_session, payload)
        assert booking.original_freight_cost_usd == 8300.0
        assert booking.total_freight_cost_usd == 7300.0
        assert booking.cost_savings_usd == 1000.0
        assert len(booking.quotation_details_data["savings_breakdown"]) == 2

    def test_cost_increase_scenario(self, db_session):
        # Executed price higher than original quote
        payload = ShipmentBookingCreate(
            booking_confirmation_no="AIR-INC-01",
            shipping_line_name="EgyptAir Cargo",
            shipment_type="Air Freight",
            original_freight_cost_usd=2000.0,
            cost_charges_data=[
                BookingChargeItem(charge_type="Air Freight", unit="Per Shipment", quantity=1, rate=2500.0, total=2500.0)
            ],
        )
        booking = create_booking_service(db_session, payload)
        assert booking.original_freight_cost_usd == 2000.0
        assert booking.total_freight_cost_usd == 2500.0
        assert booking.cost_savings_usd == 0.0
        assert booking.cost_variance_usd == -500.0
        assert "Freight cost increase" in booking.savings_notes

    def test_insurance_charge_rejected(self, db_session):
        # 1. By charge_type containing 'insurance'
        payload1 = ShipmentBookingCreate(
            booking_confirmation_no="INS-REJ-01",
            shipping_line_name="MSC",
            shipment_type="Ocean FCL",
            containers_data=[ContainerAllocationItem(container_type="40HC", quantity=1)],
            cost_charges_data=[
                BookingChargeItem(charge_type="Sea Freight 40ft", unit="Per Container", quantity=1, rate=2000.0, total=2000.0),
                BookingChargeItem(charge_type="Marine Insurance", unit="Per Policy", quantity=1, rate=350.0, total=350.0),
            ],
        )
        with pytest.raises(HTTPException) as exc1:
            create_booking_service(db_session, payload1)
        assert exc1.value.status_code == 422
        assert "التأمين البحري يُسجل في شاشة وثائق التأمين وليس ضمن تكاليف الحجز." in exc1.value.detail

        # 2. By charge_category = "INSURANCE"
        payload2 = ShipmentBookingCreate(
            booking_confirmation_no="INS-REJ-02",
            shipping_line_name="MSC",
            shipment_type="Ocean FCL",
            containers_data=[ContainerAllocationItem(container_type="40HC", quantity=1)],
            cost_charges_data=[
                BookingChargeItem(charge_type="Risk Coverage", charge_category="INSURANCE", unit="Per Policy", quantity=1, rate=350.0, total=350.0),
            ],
        )
        with pytest.raises(HTTPException) as exc2:
            create_booking_service(db_session, payload2)
        assert exc2.value.status_code == 422
        assert "التأمين البحري يُسجل في شاشة وثائق التأمين وليس ضمن تكاليف الحجز." in exc2.value.detail

        # 3. By Arabic text 'تأمين'
        payload3 = ShipmentBookingCreate(
            booking_confirmation_no="INS-REJ-03",
            shipping_line_name="MSC",
            shipment_type="Ocean FCL",
            containers_data=[ContainerAllocationItem(container_type="40HC", quantity=1)],
            cost_charges_data=[
                BookingChargeItem(charge_type="وثيقة تأمين بحري", unit="Per Policy", quantity=1, rate=350.0, total=350.0),
            ],
        )
        with pytest.raises(HTTPException) as exc3:
            create_booking_service(db_session, payload3)
        assert exc3.value.status_code == 422
        assert "التأمين البحري يُسجل في شاشة وثائق التأمين وليس ضمن تكاليف الحجز." in exc3.value.detail

    def test_insurance_charge_rejected_on_update(self, db_session):
        payload = ShipmentBookingCreate(
            booking_confirmation_no="UPD-REJ-01",
            shipping_line_name="CMA CGM",
            shipment_type="Ocean FCL",
            containers_data=[ContainerAllocationItem(container_type="40HC", quantity=1)],
            cost_charges_data=[
                BookingChargeItem(charge_type="Sea Freight 40ft", unit="Per Container", quantity=1, rate=2000.0, total=2000.0),
            ],
        )
        booking = create_booking_service(db_session, payload)

        update_payload = ShipmentBookingUpdate(
            cost_charges_data=[
                BookingChargeItem(charge_type="Sea Freight 40ft", unit="Per Container", quantity=1, rate=2000.0, total=2000.0),
                BookingChargeItem(charge_type="Marine Insurance", unit="Per Policy", quantity=1, rate=300.0, total=300.0),
            ]
        )
        with pytest.raises(HTTPException) as exc:
            update_booking_service(db_session, booking.booking_id, update_payload)
        assert exc.value.status_code == 422
        assert "التأمين البحري يُسجل في شاشة وثائق التأمين وليس ضمن تكاليف الحجز." in exc.value.detail

    def test_invalid_charge_category_rejected(self, db_session):
        payload = ShipmentBookingCreate(
            booking_confirmation_no="CAT-REJ-01",
            shipping_line_name="MSC",
            shipment_type="Ocean FCL",
            containers_data=[ContainerAllocationItem(container_type="40HC", quantity=1)],
            cost_charges_data=[
                BookingChargeItem(charge_type="Special Handling", charge_category="INVALID_CATEGORY", unit="Per Container", quantity=1, rate=100.0, total=100.0),
            ],
        )
        with pytest.raises(HTTPException) as exc:
            create_booking_service(db_session, payload)
        assert exc.value.status_code == 422
        assert "فئة التكلفة غير صحيحة" in exc.value.detail

    def test_legacy_insurance_charge_still_reads(self, db_session):
        from modules.freight_booking.model import ShipmentBooking
        # Direct DB insertion simulating a pre-existing legacy record with insurance charges
        legacy_booking = ShipmentBooking(
            booking_code="BKG-LEGACY-001",
            booking_confirmation_no="LEGACY-INS-01",
            shipping_line_name="Hapag-Lloyd",
            shipment_type="Ocean FCL",
            status="Draft",
            is_active=True,
            total_freight_cost_usd=2350.0,
            containers_data=[{"container_type": "40HC", "quantity": 1}],
            cost_charges_data=[
                {"charge_type": "Sea Freight 40ft", "unit": "Per Container", "quantity": 1, "rate": 2000.0, "total": 2000.0, "currency": "USD", "amount_usd": 2000.0, "charge_category": "FREIGHT"},
                {"charge_type": "Marine Insurance", "unit": "Per Policy", "quantity": 1, "rate": 350.0, "total": 350.0, "currency": "USD", "amount_usd": 350.0, "charge_category": "INSURANCE"},
            ],
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
        db_session.add(legacy_booking)
        db_session.commit()
        db_session.refresh(legacy_booking)

        # get_booking_service does not validate on read
        fetched = get_booking_service(db_session, legacy_booking.booking_id)
        assert fetched.booking_id == legacy_booking.booking_id
        assert len(fetched.cost_charges_data) == 2
        assert fetched.cost_charges_data[1]["charge_type"] == "Marine Insurance"

        # list_bookings_service also reads without validation
        all_bookings = list_bookings_service(db_session)
        assert any(b.booking_code == "BKG-LEGACY-001" for b in all_bookings)

    def test_charge_category_inferred_and_persisted(self, db_session):
        payload = ShipmentBookingCreate(
            booking_confirmation_no="CAT-INF-01",
            shipping_line_name="Maersk",
            shipment_type="Ocean FCL",
            containers_data=[ContainerAllocationItem(container_type="40HC", quantity=1)],
            cost_charges_data=[
                BookingChargeItem(charge_type="Sea Freight 40ft", unit="Per Container", quantity=1, rate=2000.0, total=2000.0),
                BookingChargeItem(charge_type="DTHC (Destination THC)", unit="Per Shipment", quantity=1, rate=250.0, total=250.0),
                BookingChargeItem(charge_type="Storage per one week", unit="Per Week", quantity=1, rate=150.0, total=150.0),
                BookingChargeItem(charge_type="Documentation Fee", unit="Per Shipment", quantity=1, rate=75.0, total=75.0),
            ],
        )
        booking = create_booking_service(db_session, payload)
        charges = booking.cost_charges_data
        assert charges[0]["charge_category"] == "FREIGHT"
        assert charges[1]["charge_category"] == "DESTINATION_LOCAL"
        assert charges[2]["charge_category"] == "STORAGE"
        assert charges[3]["charge_category"] == "OTHER"




