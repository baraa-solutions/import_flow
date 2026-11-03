"""
Unit Tests for Wave 2: Container Tracking & Demurrage, Split Shipments, and Multimodal Freight Details
"""

from datetime import date, timedelta
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

import database.models  # noqa: F401 - registers all tables in Base.metadata
from database.database import Base
from modules.import_files.model import ImportFile
from modules.container_tracking.model import ContainerLifecycleUnit, ContainerDemurrageCharge
from modules.container_tracking.schemas import (
    ContainerLifecycleUnitCreate,
    ContainerLifecycleUnitUpdate,
    ContainerDemurrageUpdate,
    ContainerStatus,
)
from modules.container_tracking.service import ContainerTrackingService
from modules.container_tracking.validators import (
    validate_container_number,
    validate_container_dates,
    validate_container_weights,
)

from modules.split_shipments.model import SplitShipmentAllocation
from modules.split_shipments.schemas import (
    SplitShipmentAllocationCreate,
    SplitShipmentAllocationUpdate,
    BatchAllocationCreate,
    BatchAllocationItem,
    ProratedCostCalculationRequest,
)
from modules.split_shipments.service import SplitShipmentService
from modules.split_shipments.validators import validate_quantities, validate_bl_numbers

from modules.multimodal_freight.model import MultimodalFreightDetails
from modules.multimodal_freight.schemas import (
    MultimodalFreightCreate,
    MultimodalFreightUpdate,
    TransportMode,
)
from modules.multimodal_freight.service import MultimodalFreightService
from modules.multimodal_freight.validators import validate_multimodal_payload


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    session = Session()

    # Create dummy import file for foreign key relations
    shipment = ImportFile(
        import_file_id=101,
        import_file_code="IMP-2026-TEST-101",
        company_id=1,
        company_name="Test Company",
        supplier_name="Test Supplier",
        status="ACTIVE",
    )
    session.add(shipment)
    session.commit()

    try:
        yield session
    finally:
        session.close()


# =============================================================================
# 1. Container Tracking & Demurrage Tests
# =============================================================================

def test_container_number_validation():
    assert validate_container_number("msku1234567") == "MSKU1234567"
    assert validate_container_number("  CMAU7654321  ") == "CMAU7654321"

    with pytest.raises(HTTPException) as exc:
        validate_container_number("SHORT")
    assert exc.value.status_code == 400


def test_container_date_and_weight_validation():
    d1 = date(2026, 11, 1)
    d2 = date(2026, 11, 5)
    d3 = date(2026, 11, 10)

    # Valid chronological order
    validate_container_dates(d1, d2, d3)

    # Invalid: gate-out before discharge
    with pytest.raises(HTTPException):
        validate_container_dates(d2, d1, d3)

    # Invalid: empty return before gate-out
    with pytest.raises(HTTPException):
        validate_container_dates(d1, d3, d2)

    # Valid weights
    validate_container_weights(tare_weight=3800.0, payload_weight=22000.0, gross_weight=25800.0, vgm_weight=25800.0)

    # Negative weight
    with pytest.raises(HTTPException):
        validate_container_weights(tare_weight=-100.0, payload_weight=1000.0, gross_weight=900.0, vgm_weight=900.0)

    # Gross weight less than tare + payload beyond tolerance
    with pytest.raises(HTTPException):
        validate_container_weights(tare_weight=4000.0, payload_weight=20000.0, gross_weight=15000.0, vgm_weight=15000.0)


def test_create_container_and_auto_status_progression(db_session):
    service = ContainerTrackingService(db_session)

    payload = ContainerLifecycleUnitCreate(
        shipment_id=101,
        container_number="MSKU9876543",
        seal_number="SL-999",
        iso_type="40HC",
        tare_weight=3900.0,
        payload_weight=21000.0,
        gross_weight=24900.0,
        initial_free_time_days=14,
        daily_demurrage_rate=60.0,
        currency="USD",
    )
    unit = service.create_container(payload, user_id=1)
    assert unit.id is not None
    assert unit.status == "ON_VESSEL"
    assert len(unit.demurrage_charges) == 1
    assert unit.demurrage_charges[0].free_time_days == 14

    # Duplicate container in same shipment rejected
    with pytest.raises(HTTPException) as exc:
        service.create_container(payload, user_id=1)
    assert exc.value.status_code == 409

    # Update discharge date -> should transition to DISCHARGED
    d_discharge = date(2026, 10, 1)
    updated = service.update_container(
        unit.id,
        ContainerLifecycleUnitUpdate(discharge_date=d_discharge),
        user_id=1,
    )
    assert updated.status == "DISCHARGED"

    # Update gate-out -> GATE_OUT_HELD
    d_gate_out = date(2026, 10, 5)
    updated = service.update_container(
        unit.id,
        ContainerLifecycleUnitUpdate(gate_out_held_date=d_gate_out),
        user_id=1,
    )
    assert updated.status == "GATE_OUT_HELD"

    # Update empty returned -> RETURNED_EMPTY
    d_empty = date(2026, 10, 25)
    updated = service.update_container(
        unit.id,
        ContainerLifecycleUnitUpdate(empty_returned_date=d_empty),
        user_id=1,
    )
    assert updated.status == "RETURNED_EMPTY"


def test_individual_container_demurrage_calculation(db_session):
    service = ContainerTrackingService(db_session)

    # Container discharged Oct 1 with 14 days free time (Free end = Oct 15)
    d_discharge = date(2026, 10, 1)
    d_empty_late = date(2026, 10, 25)  # 10 days overdue past Oct 15

    payload = ContainerLifecycleUnitCreate(
        shipment_id=101,
        container_number="CMAU1122334",
        iso_type="20GP",
        discharge_date=d_discharge,
        empty_returned_date=d_empty_late,
        initial_free_time_days=14,
        daily_demurrage_rate=50.0,
        currency="USD",
    )
    unit = service.create_container(payload, user_id=1)
    assert unit.id is not None

    demurrage_calc = service.calculate_demurrage(unit.id, user_id=1)
    assert demurrage_calc.free_time_days == 14
    assert demurrage_calc.free_time_end_date == date(2026, 10, 15)
    assert demurrage_calc.days_overdue == 10
    assert demurrage_calc.total_demurrage_amount == 500.0  # 10 days * $50

    # On-time return: discharged Oct 1, returned Oct 12 -> 0 demurrage
    service.update_container(
        unit.id,
        ContainerLifecycleUnitUpdate(empty_returned_date=date(2026, 10, 12)),
        user_id=1,
    )
    on_time_calc = service.calculate_demurrage(unit.id, user_id=1)
    assert on_time_calc.days_overdue == 0
    assert on_time_calc.total_demurrage_amount == 0.0

    # Soft delete container
    assert service.soft_delete_container(unit.id, user_id=1) is True
    assert db_session.query(ContainerLifecycleUnit).filter_by(id=unit.id).first().is_deleted is True


# =============================================================================
# 2. Split Shipments & Multi-PO Allocations Tests
# =============================================================================

def test_split_shipment_allocation_and_prorating(db_session):
    service = SplitShipmentService(db_session)

    # 1. Single allocation
    payload = SplitShipmentAllocationCreate(
        shipment_id=101,
        parent_bl_number="MEDU12345678",
        split_bl_number="MEDU12345678-A",
        item_sku="SKU-CHIP-400",
        allocated_quantity=400.0,
        total_item_quantity=1000.0,
        customs_cost_pool=50000.0,
        freight_cost_pool=20000.0,
        currency="EGP",
    )
    alloc = service.create_allocation(payload, user_id=1)
    assert alloc.id is not None
    assert alloc.allocation_ratio == 0.4
    assert alloc.prorated_customs_cost == 20000.0  # 50,000 * 0.4
    assert alloc.prorated_freight_cost == 8000.0   # 20,000 * 0.4

    # 2. Exceeding total quantity must fail
    excess_payload = SplitShipmentAllocationCreate(
        shipment_id=101,
        parent_bl_number="MEDU12345678",
        split_bl_number="MEDU12345678-B",
        item_sku="SKU-CHIP-400",
        allocated_quantity=700.0,  # 400 + 700 = 1100 > 1000
        total_item_quantity=1000.0,
    )
    with pytest.raises(HTTPException) as exc:
        service.create_allocation(excess_payload, user_id=1)
    assert exc.value.status_code == 400

    # 3. Batch allocation
    batch = BatchAllocationCreate(
        parent_bl_number="HLCU98765432",
        shipment_id=101,
        customs_cost_pool=100000.0,
        freight_cost_pool=40000.0,
        currency="EGP",
        items=[
            BatchAllocationItem(
                split_bl_number="HLCU98765432-1",
                item_sku="SKU-MOTOR-50",
                allocated_quantity=30.0,
                total_item_quantity=100.0,
            ),
            BatchAllocationItem(
                split_bl_number="HLCU98765432-2",
                item_sku="SKU-MOTOR-50",
                allocated_quantity=70.0,
                total_item_quantity=100.0,
            ),
        ],
    )
    results = service.create_batch_allocations(batch, user_id=1)
    assert len(results) == 2
    assert results[0].allocation_ratio == 0.3
    assert results[0].prorated_customs_cost == 30000.0
    assert results[1].allocation_ratio == 0.7
    assert results[1].prorated_customs_cost == 70000.0

    # 4. Prorated cost recalculation
    recalc_req = ProratedCostCalculationRequest(
        shipment_id=101,
        customs_cost_pool=120000.0,
        freight_cost_pool=60000.0,
        currency="EGP",
    )
    recalc_res = service.calculate_prorated_costs(recalc_req, user_id=1)
    assert recalc_res.total_allocations >= 3
    # First allocation (0.4 ratio) should now have 120,000 * 0.4 = 48,000 customs
    first_updated = [a for a in recalc_res.allocations if a.allocation_id == alloc.id][0]
    assert first_updated.prorated_customs_cost == 48000.0
    assert first_updated.prorated_freight_cost == 24000.0

    # 5. Soft delete
    assert service.soft_delete_allocation(alloc.id, user_id=1) is True
    assert db_session.query(SplitShipmentAllocation).filter_by(id=alloc.id).first().is_deleted is True


# =============================================================================
# 3. Multimodal Freight Details Tests
# =============================================================================

def test_multimodal_freight_validation_and_calculations(db_session):
    service = MultimodalFreightService(db_session)

    # 1. Air Freight
    air_payload = MultimodalFreightCreate(
        shipment_id=101,
        transport_mode=TransportMode.AIR,
        awb_number="077-12345678",
        airline_code="MS",
        flight_number="MS777",
        terminal_handling_charges=3500.0,
    )
    air_record = service.create_details(air_payload, user_id=1)
    assert air_record.id is not None
    assert air_record.transport_mode == "AIR"
    assert service.calculate_subtotal(air_record) == 3500.0

    # Missing AWB number must fail
    with pytest.raises(HTTPException):
        service.create_details(
            MultimodalFreightCreate(
                shipment_id=101,
                transport_mode=TransportMode.AIR,
                awb_number="",
            )
        )

    # 2. LCL Freight
    lcl_payload = MultimodalFreightCreate(
        shipment_id=101,
        transport_mode=TransportMode.LCL,
        lcl_cbm=12.5,
        lcl_rate_per_cbm=85.0,
        lcl_cfs_fee=450.0,
    )
    lcl_record = service.create_details(lcl_payload, user_id=1)
    assert lcl_record.id is not None
    # Subtotal = (12.5 * 85) + 450 = 1062.5 + 450 = 1512.5
    assert service.calculate_subtotal(lcl_record) == 1512.5

    # 3. Ro-Ro Freight
    roro_payload = MultimodalFreightCreate(
        shipment_id=101,
        transport_mode=TransportMode.RORO,
        roro_vehicle_type="ELECTRIC_BUS_12M",
        roro_dimensions_cbm=85.0,
    )
    roro_record = service.create_details(roro_payload, user_id=1)
    assert roro_record.id is not None
    assert roro_record.roro_vehicle_type == "ELECTRIC_BUS_12M"
    assert service.calculate_subtotal(roro_record) == 85.0 * 120.0

    # 4. Bulk Cargo Freight
    bulk_payload = MultimodalFreightCreate(
        shipment_id=101,
        transport_mode=TransportMode.BULK,
        bulk_cargo_type="WHEAT_GRAIN",
        bulk_tonnage=2500.0,
    )
    bulk_record = service.create_details(bulk_payload, user_id=1)
    assert bulk_record.id is not None
    assert bulk_record.bulk_cargo_type == "WHEAT_GRAIN"
    assert service.calculate_subtotal(bulk_record) == 2500.0 * 45.0

    # 5. Cost Breakdown Endpoint Logic
    calc_res = service.calculate_mode_costs(lcl_record.id)
    assert calc_res.details_id == lcl_record.id
    assert calc_res.calculated_freight_subtotal == 1512.5
    assert calc_res.breakdown["cbm_charge"] == 1062.5
    assert calc_res.breakdown["cfs_fee"] == 450.0

    # 6. Soft Delete
    assert service.soft_delete_details(air_record.id, user_id=1) is True
    assert db_session.query(MultimodalFreightDetails).filter_by(id=air_record.id).first().is_deleted is True


def test_update_demurrage_settings_and_recalc(db_session):
    service = ContainerTrackingService(db_session)
    d_discharge = date(2026, 9, 1)

    payload = ContainerLifecycleUnitCreate(
        shipment_id=101,
        container_number="MSKU5544332",
        iso_type="40HC",
        discharge_date=d_discharge,
        initial_free_time_days=10,
        daily_demurrage_rate=40.0,
        currency="USD",
    )
    unit = service.create_container(payload, user_id=1)

    # Free time ends Sep 11. If actual return is Sep 21 -> 10 days overdue
    update_payload = ContainerDemurrageUpdate(
        free_time_days=10,
        actual_return_date=date(2026, 9, 21),
        daily_demurrage_rate=50.0,
        notes="Waiver rejected by shipping line",
    )
    demurrage = service.update_demurrage_settings(unit.id, update_payload, user_id=1)
    assert demurrage.days_overdue == 10
    assert demurrage.daily_demurrage_rate == 50.0
    assert demurrage.total_demurrage_amount == 500.0


def test_split_shipments_edge_cases(db_session):
    service = SplitShipmentService(db_session)

    # Empty parent B/L should raise 400
    with pytest.raises(HTTPException):
        service.create_allocation(
            SplitShipmentAllocationCreate(
                shipment_id=101,
                parent_bl_number="",
                split_bl_number="SPLIT-01",
                item_sku="SKU-TEST",
                allocated_quantity=10.0,
                total_item_quantity=20.0,
            )
        )

    # Empty items in batch should raise 400
    with pytest.raises(HTTPException):
        service.create_batch_allocations(
            BatchAllocationCreate(
                parent_bl_number="MASTER-123",
                shipment_id=101,
                items=[],
            )
        )


def test_multimodal_freight_edge_cases(db_session):
    service = MultimodalFreightService(db_session)

    # Negative CBM for LCL should fail
    with pytest.raises(HTTPException):
        validate_multimodal_payload(
            transport_mode=TransportMode.LCL,
            lcl_cbm=-5.0,
        )

    # Missing Ro-Ro vehicle type should fail
    with pytest.raises(HTTPException):
        validate_multimodal_payload(
            transport_mode=TransportMode.RORO,
            roro_vehicle_type="",
            roro_dimensions_cbm=50.0,
        )

    # Missing Bulk cargo type should fail
    with pytest.raises(HTTPException):
        validate_multimodal_payload(
            transport_mode=TransportMode.BULK,
            bulk_cargo_type="",
            bulk_tonnage=100.0,
        )

