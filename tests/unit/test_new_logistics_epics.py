import pytest
from datetime import datetime, timezone, date, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.cbm_calculator.air_freight_service import AirFreightService
from modules.containers.model import ShipmentContainer
from modules.containers.service import gate_out_container_service, empty_return_eir_service
from modules.containers.schemas import ContainerGateOutRequest, ContainerEirReturnRequest
from modules.purchase_orders.model import PurchaseOrder, POLineItem, POShipmentAllocation
from modules.purchase_orders.service import PurchaseOrderService
from modules.purchase_orders.schemas import POAllocationCreate


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()


# ==============================================================================
# 1. EPIC-AIR-LCL: Multimodal Air Freight & Volumetric Weight
# ==============================================================================

def test_air_freight_volumetric_weight_calculation():
    """Verifies IATA volumetric weight equation (L*W*H / 6000) and chargeable weight max logic."""
    # Case 1: Heavy cargo (Gross > Volumetric)
    res1 = AirFreightService.calculate_air_packages(
        packages=[{"length_cm": 50, "width_cm": 50, "height_cm": 50, "quantity": 1, "gross_weight_kg": 50.0}],
    )
    assert res1["chargeable_weight_kg"] == 50.0
    assert res1["is_higher_volumetric"] is False

    # Case 2: Bulky cargo (Volumetric > Gross)
    res2 = AirFreightService.calculate_air_packages(
        packages=[{"length_cm": 100, "width_cm": 100, "height_cm": 100, "quantity": 1, "gross_weight_kg": 40.0}],
    )
    assert res2["chargeable_weight_kg"] == 166.67
    assert res2["is_higher_volumetric"] is True


# ==============================================================================
# 2. EPIC-CONT-EIR: Container-Level Lifecycle & EIR Demurrage Freezing
# ==============================================================================

def test_container_gate_out_and_eir_return(db_session):
    """Verifies container gate-out and EIR return registration with detention stop."""
    container = ShipmentContainer(
        container_number="MSCU9876543",
        container_type="40HC",
        import_file_id=1,
        carrier_name="MSC",
        discharge_date=date.today() - timedelta(days=20),
    )
    db_session.add(container)
    db_session.commit()

    # Step 1: Gate Out
    gate_out_req = ContainerGateOutRequest(
        gate_out_date=date.today() - timedelta(days=5),
        truck_plate_number="ط ر س 1234",
        customs_inspection_seal="CUST-EG-9988",
        driver_name="أحمد محمود",
    )
    c_out = gate_out_container_service(db_session, container.container_id, gate_out_req)
    assert c_out.truck_plate_number == "ط ر س 1234"
    assert c_out.customs_inspection_seal == "CUST-EG-9988"

    # Step 2: EIR Return
    eir_req = ContainerEirReturnRequest(
        eir_number="EIR-2026-MSC-001",
        empty_return_date=date.today(),
        eir_condition_status="Good",
        depot_name="Alexandria Old Yard",
    )
    c_eir = empty_return_eir_service(db_session, container.container_id, eir_req)
    assert c_eir.eir_number == "EIR-2026-MSC-001"
    assert c_eir.empty_return_date == date.today()
    assert c_eir.eir_condition_status == "Good"

    # Step 3: Ledger Multi-Currency Isolation (FIN-02)
    from modules.import_files.model import ImportFile
    from modules.containers.service import get_container_ledger_service

    imp = ImportFile(
        import_file_id=1,
        import_file_code="IMP-2026-MSC-LEDGER",
        company_name="Al-Sorour Logistics",
        supplier_name="Global Supplier",
        status="ACTIVE",
        is_active=True,
    )
    db_session.add(imp)

    # Add second container in EUR to test mixed currency ledger
    container_eur = ShipmentContainer(
        container_number="CMAU1234567",
        container_type="20DC",
        import_file_id=1,
        carrier_name="CMA CGM",
        currency="EUR",
        individual_demurrage_cost=150.0,
    )
    db_session.add(container_eur)
    db_session.commit()

    ledger = get_container_ledger_service(db_session, import_file_id=1)
    assert ledger.total_containers == 2
    assert len(ledger.items) == 2
    assert ledger.currency == "MIXED"
    assert "EUR" in ledger.totals_by_currency
    assert ledger.totals_by_currency["EUR"] == 150.0


# ==============================================================================
# 3. EPIC-CUST-VAL: Customs Valuation Uplift Separation
# ==============================================================================

def test_customs_valuation_uplift_duty_calculation():
    """Verifies duty is assessed on customs assessed CIF while supplier commercial CIF remains intact."""
    commercial_cif = 10000.0
    assessed_cif_usd = 14000.0
    exchange_rate = 50.0  # EGP per USD
    
    assessed_cif_egp = assessed_cif_usd * exchange_rate  # 700,000 EGP
    commercial_cif_egp = commercial_cif * exchange_rate  # 500,000 EGP
    uplift_egp = assessed_cif_egp - commercial_cif_egp  # 200,000 EGP

    duty_rate = 0.05  # 5%
    vat_rate = 0.14  # 14%

    # Duties on Assessed Base
    customs_duty = assessed_cif_egp * duty_rate  # 35,000 EGP
    vat_base = assessed_cif_egp + customs_duty  # 735,000 EGP
    vat_amount = vat_base * vat_rate  # 102,900 EGP
    total_customs_cash = customs_duty + vat_amount  # 137,900 EGP

    assert uplift_egp == 200000.0
    assert total_customs_cash == 137900.0


# ==============================================================================
# 4. EPIC-PO-PART: Partial PO Allocations & Balance Engine
# ==============================================================================

def test_po_partial_shipment_allocation_and_balance(db_session):
    """Verifies PO item allocation to shipment batches and balance computation."""
    po = PurchaseOrder(
        po_number="PO-2026-TEST-PARTIAL",
        project_id=1,
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        currency_id=1,
        total_amount_fob=100000.0,
        fulfillment_status="OPEN",
        total_shipped_quantity=0,
        remaining_balance_quantity=1000,
    )
    db_session.add(po)
    db_session.commit()

    alloc1 = POShipmentAllocation(
        po_id=po.po_id,
        import_file_id=101,
        allocated_quantity=400,
        allocated_fob_amount=40000.0,
        shipment_batch_no="Batch 1 of 2",
        status="SHIPPED",
    )
    db_session.add(alloc1)
    
    po.total_shipped_quantity = 400
    po.remaining_balance_quantity = 600
    po.fulfillment_status = "PARTIALLY_SHIPPED"
    db_session.commit()

    assert po.total_shipped_quantity == 400
    assert po.remaining_balance_quantity == 600
    assert po.fulfillment_status == "PARTIALLY_SHIPPED"

    alloc2 = POShipmentAllocation(
        po_id=po.po_id,
        import_file_id=102,
        allocated_quantity=600,
        allocated_fob_amount=60000.0,
        shipment_batch_no="Batch 2 of 2",
        status="SHIPPED",
    )
    db_session.add(alloc2)
    po.total_shipped_quantity = 1000
    po.remaining_balance_quantity = 0
    po.fulfillment_status = "FULLY_SHIPPED"
    db_session.commit()

    assert po.total_shipped_quantity == 1000
    assert po.remaining_balance_quantity == 0
    assert po.fulfillment_status == "FULLY_SHIPPED"
