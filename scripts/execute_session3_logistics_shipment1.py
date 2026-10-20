"""
Session 3 Operational Execution: Inland Transport Booking (TR-01), Port Gate-Out (TR-03),
Warehouse Arrival (TR-04), and Warehouse Receiving GRN (WR-01) for IMP-2026-0001.
Completes delivery to Tenth of Ramadan Plant, closes transport tasks,
and elevates lifecycle progress to 98.0% (ready for Final Settlement).
"""

import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

from database.database import SessionLocal
from modules.import_files.model import ImportFile
from modules.inland_transport.schemas import (
    InlandTransportBookingCreate,
    InlandTransportGateOutSubmit,
    InlandTransportArrivalSubmit,
)
from modules.inland_transport.service import (
    create_transport_booking_service,
    record_port_gate_out_service,
    record_warehouse_arrival_service,
    get_transport_booking_by_file_service,
)
from modules.warehouse_receiving.schemas import WarehouseReceivingCreate, GrnItemSchema
from modules.warehouse_receiving.service import (
    create_warehouse_receiving_service,
    get_warehouse_receiving_by_file_service,
)
from modules.smart_tasks.model import SmartTask


def execute():
    db = SessionLocal()
    try:
        imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == 1).first()
        if not imp_file:
            print("ERROR: IMP-2026-0001 not found!")
            return

        print("=" * 70)
        print("Executing Session 3: Inland Transport & Warehouse Receiving for IMP-2026-0001")
        print(f"Target: {imp_file.import_file_code} | Stage: {imp_file.current_stage_code} | Progress: {imp_file.progress_percent}%")
        print("=" * 70)

        now = datetime.now(timezone.utc)

        existing_transport = get_transport_booking_by_file_service(db, 1)
        if not existing_transport:
            print("\n>>> Step 1: Booking Inland Transport (TR-01)...")
            booking_payload = InlandTransportBookingCreate(
                import_file_id=1,
                waybill_number="WB-ALX-2026-001",
                booking_date=now - timedelta(hours=6),
                carrier_name="Al-Buraq Heavy Transport & Logistics",
                truck_plate_number="أ ل ج 9812",
                truck_type="CONTAINER_CHASSIS",
                driver_name="Ahmed Kamal Abdel-Rahman",
                driver_phone="01001234567",
                driver_national_id="28501011200331",
                container_numbers="MSKU1234567",
                pickup_port_location="Alexandria Port Berth 42",
                destination_warehouse="Tenth of Ramadan Factory Warehouse",
                planned_departure_at=now - timedelta(hours=4),
                expected_arrival_at=now,
                transport_fare_egp=12000.0,
                status="Booking Confirmed",
                tracking_notes="Flatbed truck dispatched under customs seal GP-ALX-2026-1102 to Tenth of Ramadan plant.",
            )
            transport = create_transport_booking_service(db, booking_payload, user="Logistics Officer")
            print(f"Transport Booking created: {transport.transport_id} | Waybill: {transport.waybill_number}")

            print("\n>>> Step 2: Recording Port Gate-Out (TR-03)...")
            gate_out_payload = InlandTransportGateOutSubmit(
                actual_departure_at=now - timedelta(hours=3),
                gate_pass_no="GP-ALX-2026-1102",
                notes="Truck passed through Alexandria Port Gate 22 after customs inspection and seal verification.",
            )
            transport = record_port_gate_out_service(db, transport.transport_id, gate_out_payload, user="Customs Broker")
            print(f"Gate-Out confirmed: {transport.actual_departure_at} | Status: {transport.status}")

            print("\n>>> Step 3: Recording Warehouse Arrival (TR-04)...")
            arrival_payload = InlandTransportArrivalSubmit(
                actual_arrival_at=now,
                seal_intact=True,
                seal_number="ML-EG-99881",
                notes="Truck arrived safely at Tenth of Ramadan plant. Liner seal ML-EG-99881 intact and verified.",
            )
            transport = record_warehouse_arrival_service(db, transport.transport_id, arrival_payload, user="Warehouse Manager")
            print(f"Warehouse Arrival confirmed: {transport.actual_arrival_at} | Status: {transport.status}")
        else:
            transport = existing_transport
            print(f"Existing Transport Booking found: {transport.transport_id} (Status: {transport.status})")

        # -------------------------------------------------------------
        # STEP 4: Create Warehouse Goods Receipt Note GRN (WR-01)
        # -------------------------------------------------------------
        existing_grn = get_warehouse_receiving_by_file_service(db, 1)
        if not existing_grn:
            print("\n>>> Step 4: Generating Warehouse Goods Receipt Note (GRN)...")
            grn_payload = WarehouseReceivingCreate(
                import_file_id=1,
                warehouse_name="Tenth of Ramadan Factory Warehouse",
                arrival_datetime=now,
                truck_plate_number="أ ل ج 9812",
                driver_name="Ahmed Kamal Abdel-Rahman",
                driver_phone="01001234567",
                seal_number="ML-EG-99881",
                seal_intact=True,
                grn_items=[
                    GrnItemSchema(
                        item_code="CHL-AC-500TR",
                        item_name="Air Cooled Water Chillers 500TR",
                        invoiced_qty=2,
                        accepted_qty=2,
                        shortage_qty=0,
                        damaged_qty=0,
                        quarantine_flag=False,
                    )
                ],
                notes="Full quantity received in excellent condition. Zero shortages and zero damages.",
            )
            grn = create_warehouse_receiving_service(db, grn_payload, user="Warehouse Manager")
        else:
            grn = existing_grn
            print(f"Existing GRN Record found: {grn.grn_code} (Status: {grn.status})")
        db.refresh(imp_file)

        print("\n=== FINAL VERIFICATION AFTER RECEIVING ===")
        print(f"GRN Code: {grn.grn_code} | Status: {grn.status} | Verdict: {grn.inspection_verdict}")
        print(f"Shipment: {imp_file.import_file_code}")
        print(f"  - Progress Percent: {imp_file.progress_percent}% (Expected >= 98.0%)")
        print(f"  - Current Step Code: {imp_file.current_step_code}")
        print(f"  - Current Module: {imp_file.current_module}")
        print(f"  - GRN Code Created: {grn.grn_code}")

        assert imp_file.progress_percent >= 98.0, f"Expected progress >= 98%, got {imp_file.progress_percent}%"
        assert grn.grn_code is not None, "GRN code missing"

        # Check remaining tasks
        tasks = db.query(SmartTask).filter(
            SmartTask.import_file_id == 1,
            SmartTask.status != "Completed",
        ).all()
        print(f"\nOpen Tasks remaining for IMP-2026-0001 ({len(tasks)}):")
        for t in tasks:
            print(f"  - [{t.task_code}] {t.task_type}: {t.title} ({t.priority})")

        print("\n" + "=" * 70)
        print("SUCCESS: Session 3 logistics completed! IMP-2026-0001 is officially RECEIVED AT WAREHOUSE (98.0%)!")
        print("=" * 70)

    finally:
        db.close()


if __name__ == "__main__":
    execute()
