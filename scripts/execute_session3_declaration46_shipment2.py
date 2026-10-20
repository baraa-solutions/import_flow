"""
Session 3 Operational Execution: Customs Declaration 46 (CS-03) for IMP-2026-0002
Registers Form 46 on Nafeza MTS, advances lifecycle board from STEP_13 to STEP_14/15,
auto-closes open Declaration 46 tasks, and dispatches CL-01 inspection task.
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
from modules.customs_clearance.schemas import CustomsDeclaration46Submit
from modules.customs_clearance.service import register_customs_declaration_46_service
from modules.smart_tasks.model import SmartTask
from modules.lifecycle_board.model import ShipmentStageActivity
from modules.notifications.model import SystemNotification

def execute():
    db = SessionLocal()
    try:
        imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == 2).first()
        if not imp_file:
            print("ERROR: IMP-2026-0002 not found!")
            return

        print("=== BEFORE EXECUTION (IMP-2026-0002) ===")
        print(f"Shipment: {imp_file.import_file_code} | Stage: {imp_file.current_stage} | Progress: {imp_file.progress_percent}%")
        
        clr = db.query(CustomsClearanceRecord).filter(
            CustomsClearanceRecord.import_file_id == imp_file.import_file_id,
            CustomsClearanceRecord.is_active == True,
        ).first()
        if clr:
            print(f"Clearance Record: {clr.clearance_code} | Status: {clr.status} | D/O: {clr.delivery_order_number} | Dec46: {clr.declaration_46_no}")

        open_tasks = db.query(SmartTask).filter(
            SmartTask.import_file_id == imp_file.import_file_id,
            SmartTask.status.in_(["Pending", "Open", "In Progress"]),
        ).all()
        print(f"Open Tasks ({len(open_tasks)}):")
        for t in open_tasks:
            print(f"  - [{t.task_code}] {t.task_type}: {t.title}")

        # Execute CS-03 Customs Declaration 46
        print("\n>>> Executing register_customs_declaration_46_service (CS-03)...")
        payload = CustomsDeclaration46Submit(
            import_file_id=imp_file.import_file_id,
            declaration_46_no="DEC-46-2026-0002",
            declaration_46_date=datetime(2026, 9, 20, 10, 0, 0, tzinfo=timezone.utc),
            customs_office_name="Alexandria Port Customs",
            channel_type="Yellow Channel",
            regulatory_bodies=["GOEIC", "INDUSTRIAL_CONTROL"],
            mts_certificate_number="MTS-2026-0002-MR",
            customs_tariff_items_count=1,
            inspection_notes="تم قيد الإقرار الجمركي ونموذج 46 ك.م برقم DEC-46-2026-0002 بجمارك ميناء الإسكندرية (المسار الأصفر) مع العرض على الهيئة العامة للرقابة على الصادرات والواردات ومصلحة الرقابة الصناعية.",
        )

        record = register_customs_declaration_46_service(
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
        print(f"  - Declaration 46 No: {record.declaration_46_no}")
        print(f"  - Declaration Date: {record.declaration_46_date}")
        print(f"  - Channel: {record.channel_type}")
        print(f"  - MTS Cert: {record.mts_certificate_number}")
        print(f"  - Tariff Items: {record.customs_tariff_items_count}")
        print(f"  - Regulatory Bodies: {record.regulatory_bodies}")

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

        print("\nSUCCESS: CS-03 Customs Declaration 46 executed cleanly for IMP-2026-0002!")
    finally:
        db.close()

if __name__ == "__main__":
    execute()
