"""
Operational execution script for Session 1: Shipment IMP-2026-0001 (ID: 1)
- Task TSK-ARV-00009: Delivery Order Payment & Receipt
- Checklists: Resolve all pending checklist items (0 pending remaining)
- Step progression: Advance to STEP_13 (Customs Declaration 46 / CS-03)
"""

import os
import sys
from datetime import datetime, timezone

# Ensure project root is on PYTHONPATH
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database.database import SessionLocal
from modules.customs_clearance.schemas import DeliveryOrderPaymentSubmit
from modules.customs_clearance.service import record_delivery_order_payment_service
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.import_files.model import ImportFile
from modules.lifecycle_board.model import ShipmentStageActivity
from modules.smart_tasks.model import SmartTask
from modules.smart_checklists.service import (
    resolve_all_checklist_items_for_file,
    get_checklist_summary,
    check_gatekeeper,
)


def run_session_1():
    db = SessionLocal()
    try:
        print("=" * 60)
        print("Executing Session 1: Shipment IMP-2026-0001 (ID: 1)")
        print("=" * 60)

        # 1. Verify ImportFile exists and is open
        imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == 1).first()
        if not imp_file:
            print("ERROR: ImportFile #1 not found.")
            sys.exit(1)
        print(f"Loaded ImportFile: {imp_file.import_file_code} (Status: {imp_file.status}, Progress: {imp_file.progress_percent}%)")

        # 2. Record Delivery Order Payment (CS-02)
        print("\n--- Step 1: Recording Delivery Order Payment (CS-02) ---")
        payload = DeliveryOrderPaymentSubmit(
            import_file_id=1,
            delivery_order_number="DO-MAEU-2026-0001",
            delivery_order_date=datetime(2026, 9, 13, 11, 0, 0),
            delivery_order_expiry=datetime(2026, 10, 4, 23, 59, 59),
            free_days_allowed=21,
            shipping_agent_id=4,
            shipping_agent_name="Maersk Line (A.P. Moller - Maersk)",
            delivery_order_fees=14500.0,
            delivery_order_currency="EGP",
            delivery_order_payment_ref="RCPT-MSK-2026-0001",
            delivery_order_paid_at=datetime(2026, 9, 13, 11, 30, 0),
            notes="مطابقة الفاتورة الصادرة من التوكيل الملاحي Q26IMPOC479 وسداد مصاريف إذن التسليم واستلام D/O",
        )

        record = record_delivery_order_payment_service(db, payload, user="Operations Lead")
        print(f"Customs Clearance Record created/updated: {record.clearance_code}")
        print(f"Record Status: {record.status}")
        print(f"D/O Number: {record.delivery_order_number}, Status: {record.delivery_order_status}, Fees: {record.delivery_order_fees} {record.delivery_order_currency}")

        # 3. Resolve all checklist items for file #1
        print("\n--- Step 2: Resolving All Checklist Items ---")
        checklist_res = resolve_all_checklist_items_for_file(
            db=db,
            file_id=1,
            target_status="PASSED",
            verified_by="Operations Team",
            notes="استيفاء واعتماد كافة بنود قائمة التحقق التشغيلية بالكامل للشحنة IMP-2026-0001",
        )
        print(f"Total Checklist Items: {checklist_res.total_items}")
        print(f"Passed Items: {checklist_res.passed_items}")
        print(f"Pending Items: {checklist_res.pending_items}")
        print(f"Readiness Score: {checklist_res.readiness_score_pct}%")
        print(f"Is Gate Blocked: {checklist_res.is_gate_blocked}")

        # 4. Verification of database state
        print("\n--- Step 3: Verifying Database Entities ---")
        
        # Check task TSK-ARV-00009
        tsk = db.query(SmartTask).filter(SmartTask.task_code == "TSK-ARV-00009").first()
        if tsk:
            print(f"Task TSK-ARV-00009: status = '{tsk.status}' (Notes: {tsk.notes})")
            assert tsk.status == "Completed", f"Expected Completed, got {tsk.status}"
        else:
            print("WARNING: Task TSK-ARV-00009 not found by task_code!")

        # Refresh and verify ImportFile #1
        db.refresh(imp_file)
        print(f"ImportFile #1:")
        print(f"  - Code: {imp_file.import_file_code}")
        print(f"  - DO Number: {imp_file.delivery_order_no}")
        print(f"  - DO Status: {imp_file.delivery_order_status}")
        print(f"  - Progress Percent: {imp_file.progress_percent}%")
        print(f"  - Current Module: {imp_file.current_module}")
        print(f"  - Current Step Code: {imp_file.current_step_code}")
        assert imp_file.delivery_order_no == "DO-MAEU-2026-0001"
        assert imp_file.delivery_order_status == "PAID_AND_RECEIVED"
        assert imp_file.progress_percent >= 83.0

        # Verify Lifecycle Board Steps
        step12 = db.query(ShipmentStageActivity).filter(
            ShipmentStageActivity.import_file_code == "IMP-2026-0001",
            ShipmentStageActivity.step_code == "STEP_12",
        ).first()
        step13 = db.query(ShipmentStageActivity).filter(
            ShipmentStageActivity.import_file_code == "IMP-2026-0001",
            ShipmentStageActivity.step_code == "STEP_13",
        ).first()

        print(f"Lifecycle Steps:")
        print(f"  - STEP_12: status = '{step12.status if step12 else 'Not Found'}'")
        print(f"  - STEP_13: status = '{step13.status if step13 else 'Not Found'}'")
        assert step12 and step12.status == "Completed"
        assert step13 and step13.status == "In-Progress"

        # Verify downstream SmartTask for Customs Broker
        broker_tasks = db.query(SmartTask).filter(
            SmartTask.import_file_id == 1,
            SmartTask.task_type.in_(["CUSTOMS_DECLARATION_46", "CS-03"]),
        ).all()
        print(f"Downstream Broker Tasks count: {len(broker_tasks)}")
        for bt in broker_tasks:
            print(f"  - Task {bt.task_code}: type={bt.task_type}, status={bt.status}, assigned={bt.assigned_user}")
        assert len(broker_tasks) > 0
        assert any(bt.status == "Pending" for bt in broker_tasks)

        # Verify Gatekeeper for next stages
        gate_clearance = check_gatekeeper(db, file_id=1, target_phase="CLEARANCE")
        print(f"Gatekeeper Clearance Phase:")
        print(f"  - Can Advance: {gate_clearance.can_advance}")
        print(f"  - Blocking Count: {gate_clearance.blocking_count}")
        assert gate_clearance.can_advance is True
        assert gate_clearance.blocking_count == 0

        print("\n" + "=" * 60)
        print("SUCCESS: Session 1 for IMP-2026-0001 completed successfully!")
        print("=" * 60)

    finally:
        db.close()


if __name__ == "__main__":
    run_session_1()
