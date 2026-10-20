"""
Session 3 Operational Execution: Customs Inspection & Sampling (CL-01) for IMP-2026-0001
Registers Joint Committee field inspection, GOEIC sampling record, lab fees,
advances lifecycle board, completes open inspection tasks, and dispatches CL-02.
"""

from datetime import datetime, timezone
import sys
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
from modules.lifecycle_board.model import ShipmentStageActivity
from modules.notifications.model import SystemNotification

def execute():
    db = SessionLocal()
    try:
        imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == 1).first()
        if not imp_file:
            print("ERROR: IMP-2026-0001 not found!")
            return

        print(f"=== BEFORE EXECUTION ===")
        print(f"Shipment: {imp_file.import_file_code} | Stage: {imp_file.current_stage} | Progress: {imp_file.progress_percent}%")
        
        clr = db.query(CustomsClearanceRecord).filter(
            CustomsClearanceRecord.import_file_id == imp_file.import_file_id,
            CustomsClearanceRecord.is_active == True,
        ).first()
        if clr:
            print(f"Clearance Record: {clr.clearance_code} | Status: {clr.status} | Dec46: {clr.declaration_46_no}")

        open_tasks = db.query(SmartTask).filter(
            SmartTask.import_file_id == imp_file.import_file_id,
            SmartTask.status.in_(["Pending", "Open", "In Progress"]),
        ).all()
        print(f"Open Tasks ({len(open_tasks)}):")
        for t in open_tasks:
            print(f"  - [{t.task_code}] {t.task_type}: {t.title}")

        # Execute CL-01 Inspection & Sampling
        print("\n>>> Executing record_customs_inspection_sampling_service (CL-01)...")
        payload = CustomsInspectionSamplingSubmit(
            import_file_id=imp_file.import_file_id,
            inspection_date=datetime(2026, 9, 15, 10, 30, tzinfo=timezone.utc),
            inspection_type="Physical & Sampling",
            inspection_yard="ALEXANDRIA_BERTH_42",
            inspector_name="Eng. Tarek Mahmoud (Joint Inspection Committee)",
            inspection_result="Conforming",
            is_sample_drawn=True,
            sampling_date=datetime(2026, 9, 15, 11, 45, tzinfo=timezone.utc),
            sampling_record_no="SMP-2026-0012",
            sample_test_status="Samples Under Testing",
            sampled_regulatory_bodies=["GOEIC"],
            goeic_certificate_no="GOEIC-ALX-2026-9901",
            lab_service_fees=2450.0,
            inspection_notes="تمت المعاينة والكشف الظاهري بساحة الكشف المشترك رصيف 42 بميناء الإسكندرية، ومطابقة مشمول الحاويات والأوزان والأصناف بدقة مع الإقرار الجمركي 46، وتم سحب عينة فحص مطابقة للهيئة العامة للرقابة على الصادرات والواردات (GOEIC) بموجب محضر السحب رقم SMP-2026-0012 وسداد رسوم المعامل.",
        )

        record = record_customs_inspection_sampling_service(
            db=db,
            payload=payload,
            user="Customs Broker",
        )

        db.refresh(imp_file)
        db.refresh(record)

        print("\n=== AFTER EXECUTION ===")
        print(f"Shipment: {imp_file.import_file_code} | Stage: {imp_file.current_stage} | Progress: {imp_file.progress_percent}% | Next: {imp_file.next_action}")
        print(f"Clearance Record: {record.clearance_code}")
        print(f"  - Status: {record.status}")
        print(f"  - Yard: {record.inspection_yard}")
        print(f"  - Inspector: {record.inspector_name}")
        print(f"  - Result: {record.inspection_result}")
        print(f"  - Sample Drawn: {record.is_sample_drawn}")
        print(f"  - Sampling Record: {record.sampling_record_no}")
        print(f"  - Test Status: {record.sample_test_status}")
        print(f"  - Sampled Bodies: {record.sampled_regulatory_bodies}")
        print(f"  - GOEIC Cert: {record.goeic_certificate_no}")
        print(f"  - Lab Fees: {record.lab_service_fees} EGP")

        # Check tasks
        all_tasks = db.query(SmartTask).filter(
            SmartTask.import_file_id == imp_file.import_file_id,
        ).order_by(SmartTask.task_id.desc()).limit(10).all()
        print(f"\nRecent Tasks for {imp_file.import_file_code}:")
        for t in all_tasks:
            print(f"  - [{t.task_code}] {t.status:10} | {t.task_type:26} | {t.title}")

        # Check activities
        activities = db.query(ShipmentStageActivity).filter(
            ShipmentStageActivity.import_file_code == imp_file.import_file_code,
        ).order_by(ShipmentStageActivity.id.desc()).limit(5).all()
        print(f"\nRecent Activities:")
        for a in activities:
            print(f"  - Step: {a.step_code:10} | Status: {a.status:12} | Note: {a.notes or a.action_notes}")

        # Check notifications
        notifications = db.query(SystemNotification).filter(
            SystemNotification.entity_id == imp_file.import_file_id,
        ).order_by(SystemNotification.notification_id.desc()).limit(3).all()
        print(f"\nRecent Notifications:")
        for n in notifications:
            print(f"  - Code: {n.msg_code} | Title: {n.title} | Read: {n.is_read}")

        print("\nSUCCESS: CL-01 inspection and sampling executed cleanly!")
    finally:
        db.close()

if __name__ == "__main__":
    execute()
