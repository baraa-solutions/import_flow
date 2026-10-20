"""
Session 2 Operational Execution: Customs Inspection & Sampling (CL-01) for IMP-2026-0002 (Monorail Orascom)
Registers field inspection, GOEIC & Industrial Control sampling, lab fees,
advances lifecycle board, and dispatches CL-02 final duty assessment.
"""

import os
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

from database.database import SessionLocal
from modules.import_files.model import ImportFile
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.customs_clearance.schemas import CustomsInspectionSamplingSubmit
from modules.customs_clearance.service import record_customs_inspection_sampling_service
from modules.smart_tasks.model import SmartTask


def execute():
    db = SessionLocal()
    try:
        imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == 2).first()
        if not imp_file:
            print("ERROR: IMP-2026-0002 not found!")
            return

        print("=" * 70)
        print("Executing Session 2: Customs Inspection & Sampling (CL-01) for IMP-2026-0002")
        print(f"Target: {imp_file.import_file_code} | Stage: {imp_file.current_stage_code} | Progress: {imp_file.progress_percent}%")
        print("=" * 70)

        payload = CustomsInspectionSamplingSubmit(
            import_file_id=2,
            inspection_date=datetime(2026, 9, 16, 11, 0, tzinfo=timezone.utc),
            inspection_type="Technical & Regulatory Sampling",
            inspection_yard="ALEXANDRIA_BERTH_42",
            inspector_name="Eng. Mohamed Nabil (GOEIC Committee)",
            inspection_result="Conforming",
            is_sample_drawn=True,
            sampling_date=datetime(2026, 9, 16, 11, 30, tzinfo=timezone.utc),
            sampling_record_no="SMP-2026-0014",
            sample_test_status="Samples Under Testing",
            sampled_regulatory_bodies=["GOEIC", "INDUSTRIAL_CONTROL"],
            goeic_certificate_no="GOEIC-MR-2026-7701",
            lab_service_fees=3200.0,
            inspection_notes="Monorail project imported equipment inspected at Berth 42 joint inspection yard. Technical specifications conform to declaration 46 DEC-46-2026-0002. Samples submitted to GOEIC & Industrial Control laboratories.",
        )

        record = record_customs_inspection_sampling_service(
            db=db,
            payload=payload,
            user="Customs Broker",
        )

        db.refresh(imp_file)
        db.refresh(record)

        print("\n=== AFTER INSPECTION ===")
        print(f"Shipment: {imp_file.import_file_code}")
        print(f"  - Progress Percent: {imp_file.progress_percent}% (Expected >= 88.0%)")
        print(f"  - Current Module: {imp_file.current_module}")
        print(f"  - Next Action: {imp_file.next_action_code}")
        print(f"Clearance Record: {record.clearance_code}")
        print(f"  - Status: {record.status}")
        print(f"  - Yard: {record.inspection_yard}")
        print(f"  - Result: {record.inspection_result}")
        print(f"  - Sampling Record: {record.sampling_record_no}")
        print(f"  - GOEIC Certificate: {record.goeic_certificate_no}")
        print(f"  - Lab Fees: {record.lab_service_fees} EGP")

        assert imp_file.progress_percent >= 88.0, f"Expected progress >= 88%, got {imp_file.progress_percent}%"
        assert record.is_sample_drawn is True, "Sample drawn must be True"

        # Check dispatched downstream tasks
        tasks = db.query(SmartTask).filter(
            SmartTask.import_file_id == 2,
            SmartTask.status != "Completed",
        ).all()
        print(f"\nOpen Tasks remaining for IMP-2026-0002 ({len(tasks)}):")
        for t in tasks:
            print(f"  - [{t.task_code}] {t.task_type}: {t.title} ({t.priority})")

        print("\n" + "=" * 70)
        print("SUCCESS: CL-01 inspection executed for IMP-2026-0002; progressed to 88.0%!")
        print("=" * 70)

    finally:
        db.close()


if __name__ == "__main__":
    execute()
