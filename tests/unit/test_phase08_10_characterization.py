"""
Phases 8 / 10 characterization (docs/plans/phase-08-10-quality-plan.md section 3).

Behaviour that the BE quality fixes must keep identical: GRN totals and discrepancy type, inspection rate and
stage, the under-bond dispatch lock, inland booking file sync and the single TR-03 task, dossier FOB in EGP
from the settlement, and the final-close end state.
"""
from datetime import date, datetime, timedelta, timezone

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main
from database.database import Base, get_db
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.demurrage_detention.model import DemurrageTracking
from modules.file_closure.schemas import FileClosureCreate
from modules.file_closure.service import (
    close_import_file_service,
    get_comprehensive_shipment_dossier_service,
)
from modules.financial_settlement.model import LandedCostSettlementRecord
from modules.import_files.model import ImportFile
from modules.inland_transport.model import InlandTransportBooking
from modules.inland_transport.schemas import InlandTransportBookingCreate
from modules.inland_transport.service import create_transport_booking_service
from modules.smart_tasks.model import SmartTask
from modules.warehouse_receiving.model import WarehouseReceivingRecord
from modules.warehouse_receiving.schemas import GrnItemSchema, WarehouseInspectionSubmit, WarehouseReceivingCreate
from modules.warehouse_receiving.service import (
    create_warehouse_receiving_service,
    submit_warehouse_inspection_protocol_service,
)

engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture
def db_session():
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture
def client(db_session):
    def override_get_db():
        yield db_session

    main.app.dependency_overrides[get_db] = override_get_db
    with TestClient(main.app) as c:
        yield c
    main.app.dependency_overrides.clear()


def _file(db, code="IMP-CHAR-0001", **extra) -> ImportFile:
    imp = ImportFile(
        import_file_code=code,
        company_name="Char Co",
        supplier_name="Char Supplier",
        status="Active",
        progress_percent=90.0,
        is_active=True,
        **extra,
    )
    db.add(imp)
    db.commit()
    db.refresh(imp)
    return imp


def _grn_payload(file_id: int, items=None) -> WarehouseReceivingCreate:
    return WarehouseReceivingCreate(
        import_file_id=file_id,
        warehouse_name="Main Warehouse",
        seal_intact=True,
        grn_items=items
        or [
            GrnItemSchema(item_code="A", item_name="Item A", invoiced_qty=100, accepted_qty=95, shortage_qty=3, damaged_qty=2),
            GrnItemSchema(item_code="B", item_name="Item B", invoiced_qty=50, accepted_qty=50),
        ],
        inspector_name="Inspector",
    )


def _booking_payload(file_id: int, waybill="WB-CHAR-1", truck_type="Flatbed Trailer (تريلا مسطح)"):
    now = datetime.now(timezone.utc)
    return InlandTransportBookingCreate(
        import_file_id=file_id,
        waybill_number=waybill,
        carrier_name="Carrier",
        truck_plate_number="ABC 123",
        truck_type=truck_type,
        driver_name="Driver",
        driver_phone="0101234567",
        pickup_port_location="Port",
        destination_warehouse="Main Warehouse",
        planned_departure_at=now + timedelta(hours=1),
        expected_arrival_at=now + timedelta(hours=5),
        transport_fare_egp=1000.0,
    )


# 1. GRN create -----------------------------------------------------------------------------------------------

def test_grn_create_totals_type_and_file_sync(db_session):
    imp = _file(db_session)
    booking = InlandTransportBooking(
        transport_code="TR-CHAR-0001", import_file_id=imp.import_file_id, waybill_number="WB", carrier_name="C",
        truck_plate_number="P1", driver_name="D", driver_phone="01000", pickup_port_location="Port",
        destination_warehouse="WH", planned_departure_at=datetime.now(timezone.utc),
        expected_arrival_at=datetime.now(timezone.utc), status="In Transit", is_active=True,
    )
    tracking = DemurrageTracking(
        tracking_code="DND-CHAR-1", import_file_id=imp.import_file_id, carrier_name="MSC",
        bill_of_lading_no="BL-1", discharge_date=date.today(), is_active=True,
        exchange_rate=50.0,  # no default rate since the review wave (NOT NULL, no fabricated 50.0)
    )
    db_session.add_all([booking, tracking])
    db_session.commit()

    rec = create_warehouse_receiving_service(db_session, _grn_payload(imp.import_file_id))

    assert (rec.total_invoiced_qty, rec.total_accepted_qty, rec.total_shortage_qty, rec.total_damaged_qty) == (150, 145, 3, 2)
    assert rec.discrepancy_type == "Shortage"  # Shortage wins even when there is damage too
    assert rec.grn_code.startswith(f"GRN-{datetime.now().year}-")
    db_session.refresh(imp)
    assert imp.progress_percent >= 98.0
    assert imp.inland_transport_status == "ARRIVED"
    assert imp.current_stage_code == "GOODS_RECEIVED"
    db_session.refresh(booking)
    assert booking.status == "Arrived at Warehouse"
    db_session.refresh(tracking)
    assert tracking.gate_out_date is not None


# 2. Inspection -----------------------------------------------------------------------------------------------

def test_inspection_rate_verdict_and_stage(db_session):
    imp = _file(db_session, "IMP-CHAR-0002")
    rec = WarehouseReceivingRecord(
        grn_code="GRN-CHAR-0002", import_file_id=imp.import_file_id, warehouse_name="WH",
        grn_items=[{"item_code": "A", "item_name": "A", "invoiced_qty": 100, "accepted_qty": 95, "shortage_qty": 3, "damaged_qty": 2}],
        total_invoiced_qty=100, total_accepted_qty=95, total_shortage_qty=3, total_damaged_qty=2,
        status="Goods Received", is_active=True,
    )
    db_session.add(rec)
    db_session.commit()

    out = submit_warehouse_inspection_protocol_service(
        db_session, rec.receiving_id, WarehouseInspectionSubmit(inspection_verdict=None, discrepancy_type=None)
    )

    assert out.discrepancy_rate_percent == 5.0
    assert out.inspection_verdict == "ACCEPTED_WITH_DISCREPANCY"
    assert out.discrepancy_type == "Shortage & Damaged"
    assert out.inspection_protocol_number == f"INSP-{datetime.now(timezone.utc).year}-{rec.receiving_id:04d}"
    db_session.refresh(imp)
    assert imp.current_stage_code == "DISCREPANCY_PROTOCOL_FILED"
    assert imp.progress_percent >= 99.0


# 3. Under-bond lock ------------------------------------------------------------------------------------------

def test_under_bond_lock_blocks_dispatch(db_session, client):
    imp = _file(db_session, "IMP-CHAR-0003")
    db_session.add(CustomsClearanceRecord(
        clearance_code="CC-CHAR-3", import_file_id=imp.import_file_id, status="Under-Bond Released",
        is_under_bond_release=True, quarantine_lock=True, bond_guarantee_ref="BG-1", is_active=True,
    ))
    db_session.commit()
    items = [GrnItemSchema(item_code="A", item_name="A", invoiced_qty=10, accepted_qty=10)]
    rec = create_warehouse_receiving_service(db_session, _grn_payload(imp.import_file_id, items))

    assert rec.is_under_bond_quarantine and rec.quarantine_lock_active and rec.dispatch_blocked
    assert rec.status == "Under Bond Quarantine"
    res = client.post(f"/api/v1/warehouse-receiving/{rec.receiving_id}/validate-dispatch")
    assert res.status_code == 400


# 4. Inland booking -------------------------------------------------------------------------------------------

def test_inland_booking_file_sync_single_tr03_task_and_truck_type(db_session):
    imp = _file(db_session, "IMP-CHAR-0004")
    first = create_transport_booking_service(db_session, _booking_payload(imp.import_file_id, "WB-1"), user="op")
    create_transport_booking_service(db_session, _booking_payload(imp.import_file_id, "WB-2"), user="op")

    assert first.truck_type == "FLATBED"
    db_session.refresh(imp)
    assert imp.inland_transport_status == "BOOKED"
    assert imp.inland_transport_booking_no == "WB-2"
    assert imp.progress_percent >= 97.0
    tasks = db_session.query(SmartTask).filter(
        SmartTask.import_file_id == imp.import_file_id, SmartTask.msg_code == "TR_TASK_TRACK_ARRIVAL_GRN"
    ).count()
    assert tasks == 1


# 5. Dossier FOB in EGP ---------------------------------------------------------------------------------------

def test_dossier_fob_egp_copied_from_settlement(db_session):
    imp = _file(db_session, "IMP-CHAR-0005", estimated_cost=1000.0, estimated_cost_currency="USD")
    db_session.add(LandedCostSettlementRecord(
        settlement_code="SET-CHAR-5", import_file_id=imp.import_file_id, status="Calculated",
        total_fob_egp=123456.0, is_active=True,
    ))
    db_session.add(CustomsClearanceRecord(
        clearance_code="CC-CHAR-5", import_file_id=imp.import_file_id, broker_name="Broker", is_active=True,
    ))
    db_session.commit()

    res = get_comprehensive_shipment_dossier_service(db_session, imp.import_file_id)
    assert res.total_fob_egp == 123456.0
    assert res.total_fob_fc == 1000.0


# 6. Final close ----------------------------------------------------------------------------------------------

def test_final_close_end_state(db_session):
    imp = _file(
        db_session, "IMP-CHAR-0006",
        is_customs_released=True, customs_release_permit_no="REL-6",
        dossier_exported_at=datetime.now(timezone.utc), actual_landed_cost_total_egp=1000.0,
    )
    db_session.add_all([
        CustomsClearanceRecord(clearance_code="CC-CHAR-6", import_file_id=imp.import_file_id,
                               status="Final Release Granted", is_active=True),
        WarehouseReceivingRecord(grn_code="GRN-CHAR-6", import_file_id=imp.import_file_id, warehouse_name="WH",
                                 is_active=True),
        LandedCostSettlementRecord(settlement_code="SET-CHAR-6", import_file_id=imp.import_file_id,
                                   status="Approved", total_landed_cost_egp=1000.0, is_active=True),
    ])
    db_session.commit()

    rec = close_import_file_service(db_session, FileClosureCreate(import_file_id=imp.import_file_id), trusted=True)

    assert rec.status == "Closed"
    db_session.refresh(imp)
    assert imp.status == "Closed"
    assert imp.progress_percent == 100.0
    assert imp.current_stage_code == "ARCHIVED_CLOSED"
