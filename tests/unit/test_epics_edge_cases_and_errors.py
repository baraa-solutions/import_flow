import pytest
from datetime import datetime, timezone, date, timedelta
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.cbm_calculator.air_freight_service import (
    AirFreightService,
    calculate_volumetric_weight_iata,
    calculate_chargeable_weight,
)
from modules.containers.model import ShipmentContainer
from modules.containers.service import (
    gate_out_container_service,
    empty_return_eir_service,
    get_container_ledger_service,
)
from modules.containers.schemas import ContainerGateOutRequest, ContainerEirReturnRequest
from modules.purchase_orders.model import PurchaseOrder, POLineItem, POShipmentAllocation
from modules.import_files.model import ImportFile
from modules.purchase_orders.service import PurchaseOrderService
from modules.purchase_orders.schemas import POShipmentAllocationCreate
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.customs_clearance.schemas import FinalDutyAssessmentSubmit
from modules.customs_clearance.service import assess_final_customs_duties_service
from modules.common.errors import CodedHTTPException


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()


# ==============================================================================
# 1. EPIC-AIR-LCL: Edge Cases and Negative Inputs
# ==============================================================================

def test_air_freight_zero_and_negative_dimensions():
    """Validates that zero or negative dimensions return 0.0 volumetric weight."""
    assert calculate_volumetric_weight_iata(0, 50, 50, 1) == 0.0
    assert calculate_volumetric_weight_iata(50, -10, 50, 1) == 0.0
    assert calculate_volumetric_weight_iata(50, 50, 0, 1) == 0.0
    assert calculate_volumetric_weight_iata(50, 50, 50, 0) == 0.0
    assert calculate_volumetric_weight_iata(50, 50, 50, -5) == 0.0


def test_air_freight_none_and_empty_packages():
    """Validates AirFreightService when packages is None or empty list."""
    res_empty = AirFreightService.calculate_air_packages(packages=[])
    assert res_empty["gross_weight_kg"] == 0.0
    assert res_empty["volumetric_weight_kg"] == 0.0
    assert res_empty["chargeable_weight_kg"] == 0.0
    assert res_empty["cbm"] == 0.0
    assert res_empty["is_higher_volumetric"] is False
    assert res_empty["details"] == []

    res_none = AirFreightService.calculate_air_packages(packages=None)
    assert res_none["gross_weight_kg"] == 0.0
    assert res_none["volumetric_weight_kg"] == 0.0
    assert res_none["chargeable_weight_kg"] == 0.0


def test_air_freight_extreme_heavy_and_light_cargo():
    """Validates boundary conditions: feather-light massive volume vs ultra-dense compact cargo."""
    # Ultra-dense: 10cm x 10cm x 10cm cube weighing 500kg
    res_dense = AirFreightService.calculate_air_packages(
        single_length_cm=10, single_width_cm=10, single_height_cm=10, single_gross_weight_kg=500.0
    )
    assert res_dense["volumetric_weight_kg"] == 0.17
    assert res_dense["chargeable_weight_kg"] == 500.0
    assert res_dense["is_higher_volumetric"] is False

    # Feather-light bulky: 200cm x 200cm x 200cm balloon weighing 1kg
    res_bulky = AirFreightService.calculate_air_packages(
        single_length_cm=200, single_width_cm=200, single_height_cm=200, single_gross_weight_kg=1.0
    )
    # Volumetric: (8,000,000) / 6,000 = 1,333.33 kg
    assert res_bulky["volumetric_weight_kg"] == 1333.33
    assert res_bulky["chargeable_weight_kg"] == 1333.33
    assert res_bulky["is_higher_volumetric"] is True


# ==============================================================================
# 2. EPIC-CONT-EIR: Chronological Violations & Error Handling
# ==============================================================================

def test_container_not_found(db_session):
    """Calling gate-out or EIR return on non-existent container ID must raise 404."""
    with pytest.raises(HTTPException) as exc_info:
        gate_out_container_service(db_session, 999999, ContainerGateOutRequest())
    assert exc_info.value.status_code == 404

    with pytest.raises(HTTPException) as exc_info2:
        empty_return_eir_service(db_session, 999999, ContainerEirReturnRequest(eir_number="EIR-999"))
    assert exc_info2.value.status_code == 404


def test_container_gate_out_before_discharge_date(db_session):
    """Gate-out date before discharge date must raise 422 Unprocessable Entity."""
    container = ShipmentContainer(
        container_number="MSCU1112233",
        container_type="40HC",
        import_file_id=1,
        discharge_date=date(2026, 10, 20),
    )
    db_session.add(container)
    db_session.commit()

    with pytest.raises(HTTPException) as exc_info:
        gate_out_container_service(
            db_session,
            container.container_id,
            ContainerGateOutRequest(gate_out_date=date(2026, 10, 15)),  # 5 days BEFORE discharge!
        )
    assert exc_info.value.status_code == 422
    assert "تفريغ" in exc_info.value.detail or "discharge" in exc_info.value.detail.lower()


def test_container_empty_return_before_gate_out_date(db_session):
    """EIR empty return date before gate out date must raise 422 Unprocessable Entity."""
    container = ShipmentContainer(
        container_number="MSCU4445566",
        container_type="40HC",
        import_file_id=1,
        discharge_date=date(2026, 10, 10),
        gate_out_date=date(2026, 10, 15),
    )
    db_session.add(container)
    db_session.commit()

    with pytest.raises(HTTPException) as exc_info:
        empty_return_eir_service(
            db_session,
            container.container_id,
            ContainerEirReturnRequest(
                eir_number="EIR-FAIL-01",
                empty_return_date=date(2026, 10, 12),  # 3 days BEFORE gate out!
            ),
        )
    assert exc_info.value.status_code == 422
    assert "خروج" in exc_info.value.detail or "gate-out" in exc_info.value.detail.lower()


def test_container_ledger_non_existent_file(db_session):
    """Retrieving container ledger for non-existent import file must raise 404."""
    with pytest.raises(HTTPException) as exc:
        get_container_ledger_service(db_session, 999999)
    assert exc.value.status_code == 404


# ==============================================================================
# 3. EPIC-CUST-VAL: Valuation Uplift Inverted & Edge Cases
# ==============================================================================

def test_customs_valuation_assessed_less_than_commercial(db_session):
    """When customs assessed CIF is lower than or equal to commercial invoice, uplift must be 0."""
    import_file = ImportFile(
        import_file_id=1,
        import_file_code="IMP-2026-VAL-01",
        company_name="Test Company",
        supplier_name="Test Supplier",
        status="ACTIVE",
        is_active=True,
    )
    db_session.add(import_file)

    record = CustomsClearanceRecord(
        import_file_id=1,
        clearance_code="CC-2026-VAL-01",
        declaration_46_no="DEC-46-9999",
        cif_base_amount=100000.0,
        commercial_cif_base_amount=100000.0,
        customs_assessed_cif_egp=100000.0,
        is_valuation_uplifted=False,
    )
    db_session.add(record)
    db_session.commit()

    # Case: Assessed is lower than commercial (e.g. 90,000 vs 100,000)
    payload = FinalDutyAssessmentSubmit(
        import_file_id=1,
        nafeza_claim_number="CLM-EG-12345",
        commercial_cif_base_amount=100000.0,
        customs_assessed_cif_egp=90000.0,
        import_duty_amount=4500.0,
        vat_amount=13230.0,
    )
    updated = assess_final_customs_duties_service(db_session, payload, user="TestAuditor")

    assert updated.is_valuation_uplifted is False
    assert updated.valuation_uplift_amount_egp == 0.0
    assert updated.cif_base_amount == 90000.0


# ==============================================================================
# 4. EPIC-PO-PART: Partial PO Allocations & Error States
# ==============================================================================

def test_po_allocation_on_closed_po(db_session):
    """Allocating a shipment to a closed PO must raise 409 Conflict."""
    po = PurchaseOrder(
        po_number="PO-CLOSED-001",
        project_id=1,
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        currency_id=1,
        status="CLOSED",
    )
    db_session.add(po)
    db_session.commit()

    service = PurchaseOrderService(db_session)
    alloc_req = POShipmentAllocationCreate(
        import_file_id=1,
        shipment_ref="BATCH-CLOSED",
        shipped_quantity=100,
        shipped_amount_fob=5000.0,
    )
    with pytest.raises(CodedHTTPException) as exc_info:
        service.allocate_shipment(po.po_id, alloc_req, current_user_name="TestBuyer")
    assert exc_info.value.status_code == 409


def test_po_allocation_invalid_line_item(db_session):
    """Allocating to a line item ID that does not belong to the PO must raise 400 Bad Request."""
    po = PurchaseOrder(
        po_number="PO-LINE-CHECK-001",
        project_id=1,
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        currency_id=1,
        status="DRAFT",
    )
    db_session.add(po)
    db_session.commit()

    service = PurchaseOrderService(db_session)
    alloc_req = POShipmentAllocationCreate(
        import_file_id=1,
        po_line_item_id=99999,  # Does not belong to this PO!
        shipment_ref="BATCH-INVALID-ITEM",
        shipped_quantity=50,
        shipped_amount_fob=2000.0,
    )
    with pytest.raises(HTTPException) as exc_info:
        service.allocate_shipment(po.po_id, alloc_req, current_user_name="TestBuyer")
    assert exc_info.value.status_code == 400
    assert "غير مرتبط" in exc_info.value.detail


def test_po_over_allocation_generates_warning(db_session):
    """Allocating more quantity than ordered generates an OVER_SHIPPED system warning."""
    import_file = ImportFile(
        import_file_id=1,
        import_file_code="IMP-2026-PO-01",
        company_name="Test Company",
        supplier_name="Test Supplier",
        status="ACTIVE",
        is_active=True,
    )
    db_session.add(import_file)

    po = PurchaseOrder(
        po_number="PO-OVER-SHIP-001",
        project_id=1,
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        currency_id=1,
        status="APPROVED",
    )
    db_session.add(po)
    db_session.flush()

    line_item = POLineItem(
        po_id=po.po_id,
        item_code="ITEM-TEST-1",
        description_ar="بند اختباري",
        quantity=100,
        unit_price=10.0,
        unit_of_measure="PCS",
    )
    db_session.add(line_item)
    db_session.commit()

    service = PurchaseOrderService(db_session)
    # Allocate 150 PCS on an order of 100 PCS -> Over-shipped!
    alloc_req = POShipmentAllocationCreate(
        import_file_id=1,
        po_line_item_id=line_item.item_id,
        shipment_ref="BATCH-OVER-1",
        shipped_quantity=150,
        shipped_amount_fob=1500.0,
    )
    res = service.allocate_shipment(po.po_id, alloc_req, current_user_name="TestBuyer")

    assert len(res.messages) > 0
    assert any(m.code == "OVER_SHIPPED" for m in res.messages)
    assert po.fulfillment_status == "FULLY_SHIPPED"
    assert po.total_shipped_quantity == 150.0
    assert po.remaining_balance_quantity == 0.0
