"""
Operational execution script for Session 2: Shipment IMP-2026-0001 (ID: 1)
- Task TASK-DD3656E9: Register customs declaration Form 46 (CS-03)
- Register Declaration 46 on Nafeza MTS (DEC-46-2026-0001, Yellow Channel, GOEIC)
- Advance lifecycle board from STEP_13 to STEP_14 & STEP_15
- Dispatch downstream inspection and sampling task (CL-01)
"""

import os
import sys
from datetime import datetime, timezone

# Ensure project root is on PYTHONPATH
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import database.models
from database.database import SessionLocal
from modules.customs_clearance.schemas import CustomsDeclaration46Submit
from modules.customs_clearance.service import register_customs_declaration_46_service
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.import_files.model import ImportFile
from modules.lifecycle_board.model import ShipmentStageActivity
from modules.smart_tasks.model import SmartTask
from modules.smart_checklists.service import (
    get_checklist_summary,
    check_gatekeeper,
)


def run_session_2():
    db = SessionLocal()
    try:
        print("=" * 70)
        print("Executing Session 2: Customs Declaration 46 for IMP-2026-0001 (ID: 1)")
        print("=" * 70)

        # 1. Verify ImportFile exists and is at STEP_13
        imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == 1).first()
        if not imp_file:
            print("ERROR: ImportFile #1 not found.")
            sys.exit(1)
        print(f"Loaded ImportFile: {imp_file.import_file_code} (Status: {imp_file.status}, Step: {imp_file.current_step_code}, Progress: {imp_file.progress_percent}%)")

        # 2. Register Customs Declaration 46 (CS-03)
        print("\n--- Step 1: Registering Customs Declaration 46 (CS-03) ---")
        payload = CustomsDeclaration46Submit(
            import_file_id=1,
            declaration_46_no="DEC-46-2026-0001",
            declaration_46_date=datetime(2026, 9, 14, 10, 0, 0, tzinfo=timezone.utc),
            customs_office_name="Alexandria Port Customs",
            channel_type="Yellow Channel",
            regulatory_bodies=["GOEIC"],
            mts_certificate_number="MTS-2026-00891",
            customs_tariff_items_count=1,
            inspection_notes="Customs Declaration Form 46 submitted via Nafeza MTS. Allocated to Yellow Channel with GOEIC presentation.",
        )

        record = register_customs_declaration_46_service(db, payload, user="Operations Lead")
        print(f"Customs Clearance Record updated: {record.clearance_code}")
        print(f"Record Status: {record.status}")
        print(f"Declaration 46 No: {record.declaration_46_no}, Date: {record.declaration_46_date}")
        print(f"Channel: {record.channel_type}, Office: {record.customs_office_name}")
        print(f"Regulatory Bodies: {record.regulatory_bodies}")

        # 3. Verification of database state
        print("\n--- Step 2: Verifying Database Entities ---")

        # Check task TASK-DD3656E9
        task_d46 = db.query(SmartTask).filter(SmartTask.task_code == "TASK-DD3656E9").first()
        if task_d46:
            print(f"Task TASK-DD3656E9: status = '{task_d46.status}' (Notes: {task_d46.notes})")
            assert task_d46.status == "Completed", f"Expected Completed, got {task_d46.status}"
        else:
            print("INFO: Task TASK-DD3656E9 not found by exact code (checking by task_type)")

        # Verify downstream inspection task was dispatched
        inspection_task = (
            db.query(SmartTask)
            .filter(
                SmartTask.import_file_id == 1,
                SmartTask.task_type.in_(["CUSTOMS_INSPECTION_SAMPLING", "CL-01"]),
                SmartTask.status != "Completed",
            )
            .first()
        )
        assert inspection_task is not None, "Downstream CUSTOMS_INSPECTION_SAMPLING task was not dispatched!"
        print(f"Dispatched Downstream Task: {inspection_task.task_code} | Title: {inspection_task.title} | Priority: {inspection_task.priority}")

        # Refresh and verify ImportFile #1
        db.refresh(imp_file)
        print(f"\nImportFile #1 Updated State:")
        print(f"  - Code: {imp_file.import_file_code}")
        print(f"  - Form 46 No: {imp_file.form46_no}")
        print(f"  - Form 46 Date: {imp_file.form46_date}")
        print(f"  - Form 46 Status: {imp_file.form46_status}")
        print(f"  - Progress Percent: {imp_file.progress_percent}%")
        print(f"  - Current Module: {imp_file.current_module}")
        print(f"  - Current Step Code: {imp_file.current_step_code}")
        print(f"  - Current Stage Code: {imp_file.current_stage_code}")
        print(f"  - Next Action Code: {imp_file.next_action_code}")

        assert imp_file.form46_no == "DEC-46-2026-0001", "Form 46 No mismatch"
        assert imp_file.form46_status == "REGISTERED", "Form 46 Status mismatch"
        assert imp_file.progress_percent >= 86.0, f"Expected progress >= 86%, got {imp_file.progress_percent}%"

        # Verify Lifecycle Board Activity
        print("\n--- Step 3: Verifying Lifecycle Board Steps ---")
        step_13_act = (
            db.query(ShipmentStageActivity)
            .filter(
                ShipmentStageActivity.import_file_code == imp_file.import_file_code,
                ShipmentStageActivity.step_code == "STEP_13",
            )
            .first()
        )
        if step_13_act:
            print(f"Step 13 Activity: Status = {step_13_act.status}, CompletionType = {getattr(step_13_act, 'completion_type', None)}")
            assert step_13_act.status == "Completed", f"Expected STEP_13 Completed, got {step_13_act.status}"

        # Verify Checklist Gatekeeper
        print("\n--- Step 4: Verifying Checklists & Gatekeeper ---")
        chk = get_checklist_summary(db, 1)
        print(f"Checklist Readiness: {chk.passed_items}/{chk.total_items} items passed ({chk.readiness_score_pct}%)")
        gk = check_gatekeeper(db, 1, "CLEARANCE")
        print(f"Gatekeeper CLEARANCE: can_advance={gk.can_advance}, blocking_count={gk.blocking_count}")

        print("\n" + "=" * 70)
        print("SUCCESS: Session 2 executed successfully! Shipment IMP-2026-0001 is now under customs inspection.")
        print("=" * 70)

    except Exception as e:
        db.rollback()
        print(f"\nFAILURE: Session 2 encountered an error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    finally:
        db.close()


if __name__ == "__main__":
    run_session_2()
