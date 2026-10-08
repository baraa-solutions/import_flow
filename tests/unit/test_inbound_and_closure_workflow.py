import pytest
from datetime import datetime, timezone

# Register every table the GRN create / closure touch before the fixture runs create_all.
import modules.demurrage_detention.model  # noqa: F401
import modules.inland_transport.model  # noqa: F401
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.import_files.model import ImportFile
from modules.warehouse_receiving.model import WarehouseReceivingRecord
from modules.warehouse_receiving.schemas import WarehouseReceivingCreate, GrnItemSchema, DiscrepancyReportSubmit
from modules.warehouse_receiving.service import (
    create_warehouse_receiving_service,
    report_receiving_discrepancy_service,
)
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.financial_settlement.model import LandedCostSettlementRecord
from modules.financial_settlement.service import calculate_landed_cost_engine
from modules.file_closure.schemas import FileClosureCreate, ClosureChecklistSchema
from modules.file_closure.service import close_import_file_service

@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()

    # Create dummy import file
    imp_file = ImportFile(
        import_file_code="IMP-2026-0888",
        company_name="Archi Brands for Trading",
        supplier_name="Narbutas Furniture Corp",
        is_customs_released=True,
        is_active=True,
    )
    session.add(imp_file)
    session.commit()
    session.refresh(imp_file)

    yield session
    session.close()

def test_phase_08_warehouse_receiving_and_discrepancies(db_session):
    # 1. Create GRN
    grn_items = [
        GrnItemSchema(item_code="ITM-CHAIR-01", item_name="Ergonomic Desk Chair", invoiced_qty=100, accepted_qty=95, shortage_qty=3, damaged_qty=2, quarantine_flag=True),
        GrnItemSchema(item_code="ITM-DESK-02", item_name="Executive Wood Desk", invoiced_qty=50, accepted_qty=50, shortage_qty=0, damaged_qty=0, quarantine_flag=False),
    ]

    create_schema = WarehouseReceivingCreate(
        import_file_id=1,
        warehouse_name="Al-Obour Central Warehouse",
        truck_plate_number="TRK-9988-CAI",
        driver_name="Mahmoud Hassan",
        driver_phone="+201000000000",
        seal_number="SEAL-MAERSK-112233",
        seal_intact=True,
        grn_items=grn_items,
        discrepancy_notes="2 chairs damaged with carton torn, 3 units missing from pallet #4",
        inspector_name="Eng. Ahmed",
    )

    rec = create_warehouse_receiving_service(db_session, create_schema)
    assert rec.grn_code.startswith("GRN-")
    assert rec.warehouse_name == "Al-Obour Central Warehouse"
    assert rec.seal_intact is True
    assert rec.total_invoiced_qty == 150
    assert rec.total_accepted_qty == 145
    assert rec.total_shortage_qty == 3
    assert rec.total_damaged_qty == 2

    # Verify import file status updated
    imp_file = db_session.query(ImportFile).filter(ImportFile.import_file_id == 1).first()
    assert "Phase 8" in imp_file.current_module or "STEP_19" in imp_file.current_module or "STEP_20" in imp_file.current_module
    assert imp_file.progress_percent in (85.0, 92.0, 98.0)

    # 2. Report Discrepancy & Insurance Claim
    disc_payload = DiscrepancyReportSubmit(
        discrepancy_type="Damage & Shortage",
        discrepancy_notes="Formal damage survey done with insurance surveyor",
        quarantine_zone_assigned=True,
        insurance_claim_filed=True,
        insurance_claim_ref="CLAIM-ALLIANZ-2026-004",
    )

    updated_rec = report_receiving_discrepancy_service(db_session, rec.receiving_id, disc_payload)
    assert updated_rec.status == "Discrepancy Reported"
    assert updated_rec.insurance_claim_filed is True
    assert updated_rec.insurance_claim_ref == "CLAIM-ALLIANZ-2026-004"

def test_phase_09_landed_cost_allocation_engine():
    # Expenses: Freight (by Volume), Customs (by Value), Transport (by Weight)
    expenses = [
        {"category": "Freight", "amount_egp": 50000.0, "allocation_rule": "Volume-Based"},
        {"category": "Customs Duty", "amount_egp": 30000.0, "allocation_rule": "Value-Based"},
        {"category": "Local Transport", "amount_egp": 10000.0, "allocation_rule": "Weight-Based"},
        {"category": "Brokerage", "amount_egp": 5000.0, "allocation_rule": "Equal"},
    ]

    items = [
        {"item_code": "ITM-01", "item_name": "Product A", "qty": 100, "fob_unit_egp": 500.0, "gross_weight_kg": 1000.0, "cbm": 10.0},
        {"item_code": "ITM-02", "item_name": "Product B", "qty": 50, "fob_unit_egp": 1000.0, "gross_weight_kg": 3000.0, "cbm": 30.0},
    ]

    res = calculate_landed_cost_engine(expenses, items)

    assert res["total_fob_egp"] == 100000.0 # (100*500) + (50*1000) = 50,000 + 50,000 = 100,000
    assert res["total_expenses_egp"] == 95000.0
    assert res["total_landed_cost_egp"] == 195000.0
    assert round(res["average_markup_factor"], 2) == 1.95

    # Check item 1 (10 CBM out of 40 CBM = 25% freight = 12,500)
    # Value is 50,000 out of 100,000 = 50% customs = 15,000
    # Weight is 1,000 out of 4,000 = 25% transport = 2,500
    # Equal is 50% brokerage = 2,500
    # Total expenses for item 1 = 12,500 + 15,000 + 2,500 + 2,500 = 32,500
    # Item 1 Landed Cost = 50,000 + 32,500 = 82,500
    item1 = res["item_landed_costs"][0]
    assert item1["allocated_freight_egp"] == 12500.0
    assert item1["allocated_customs_egp"] == 15000.0
    assert item1["allocated_transport_egp"] == 2500.0
    assert item1["allocated_clearance_egp"] == 2500.0
    assert item1["total_landed_cost_egp"] == 82500.0
    assert item1["unit_landed_cost_egp"] == 825.0
    assert round(item1["markup_factor"], 2) == 1.65

def test_phase_10_file_closure_workflow(db_session):
    # 1. Create prerequisite customs clearance with Final Release Granted
    clearance = CustomsClearanceRecord(
        clearance_code="CLR-2026-0999",
        import_file_id=1,
        status="Final Release Granted",
        declaration_46_no="46-2026-0999",
        actual_duty_total=0.0,
        total_duty_payable=0.0,
        is_active=True,
    )
    db_session.add(clearance)

    # 2. Create prerequisite GRN
    grn = WarehouseReceivingRecord(
        grn_code="GRN-2026-0999",
        import_file_id=1,
        warehouse_name="Al-Obour Central Warehouse",
        status="Received",
        is_active=True,
    )
    db_session.add(grn)

    # 3. Create prerequisite Landed Cost Settlement
    settlement = LandedCostSettlementRecord(
        settlement_code="LCS-2026-0999",
        import_file_id=1,
        status="Calculated",
        incoterm_code="FOB",
        total_fob_egp=100000.0,
        total_expenses_egp=95000.0,
        total_landed_cost_egp=195000.0,
        is_active=True,
    )
    db_session.add(settlement)
    # Since FC-01 the server gate also requires the comprehensive dossier export (CLO-03).
    db_session.query(ImportFile).filter(ImportFile.import_file_id == 1).first().dossier_exported_at = datetime.now()
    db_session.commit()

    closure_schema = FileClosureCreate(
        import_file_id=1,
        closure_checklist=ClosureChecklistSchema(
            docs_verified=True,
            customs_cleared=True,
            warehouse_received=True,
            landed_cost_settled=True,
            tasks_closed=True,
        ),
        auditor_name="Chief Auditor Kamal",
        archive_location="Digital Archive Vault - Section 2026",
        archival_notes="All customs releases, GRNs, and GL journals verified and balanced.",
    )

    rec = close_import_file_service(db_session, closure_schema)
    assert rec.closure_code.startswith("CLR-")
    assert rec.status == "Closed"

    imp_file = db_session.query(ImportFile).filter(ImportFile.import_file_id == 1).first()
    assert imp_file.status == "Closed"
    assert imp_file.progress_percent == 100.0
    assert "Phase 10" in imp_file.current_module or "STEP_21" in imp_file.current_module

