"""
Session 3 Operational Execution: Freight Free Days (BK-02) & Sailing Departure (SH-01) for IMP-2026-0005
Registers 21-day demurrage agreement, confirms vessel sailing with ATD and B/L,
advances lifecycle board to STEP_08_BL, auto-closes prior tasks, and dispatches draft B/L task.
"""

from datetime import datetime, date, timezone
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

from database.database import SessionLocal
import database.models
from modules.import_files.model import ImportFile
from modules.freight_booking.model import ShipmentBooking
from modules.freight_booking.schemas import ShipmentDepartureConfirm
from modules.freight_booking.service import confirm_departure_and_bol_service
from modules.demurrage_detention.schemas import FreeDaysAgreementRegister
from modules.demurrage_detention.service import register_free_days_agreement_service
from modules.smart_tasks.model import SmartTask
from modules.lifecycle_board.model import ShipmentStageActivity
from modules.notifications.model import SystemNotification

def execute():
    db = SessionLocal()
    try:
        imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == 5).first()
        if not imp_file:
            print("ERROR: IMP-2026-0005 not found!")
            return

        booking = db.query(ShipmentBooking).filter(
            ShipmentBooking.import_file_id == imp_file.import_file_id,
            ShipmentBooking.is_active == True,
        ).first()
        if not booking:
            print("ERROR: Active booking for IMP-2026-0005 not found!")
            return

        print("=== BEFORE EXECUTION (IMP-2026-0005) ===")
        print(f"Shipment: {imp_file.import_file_code} | Stage: {imp_file.current_stage} | Progress: {imp_file.progress_percent}%")
        print(f"Booking: {booking.booking_code} | Confirmation: {booking.booking_confirmation_no} | Status: {booking.status}")
        print(f"  Vessel: {booking.vessel_name} | Voyage: {booking.voyage_number} | POL: {booking.pol_name} | POD: {booking.pod_name}")

        open_tasks = db.query(SmartTask).filter(
            SmartTask.import_file_id == imp_file.import_file_id,
            SmartTask.status.in_(["Pending", "Open", "In Progress"]),
        ).all()
        print(f"Open Tasks ({len(open_tasks)}):")
        for t in open_tasks:
            print(f"  - [{t.task_code}] {t.task_type}: {t.title}")

        # Step 1: BK-02 Free Days Agreement
        print("\n>>> Step 1: Registering Free Days Agreement (BK-02)...")
        fd_payload = FreeDaysAgreementRegister(
            import_file_id=imp_file.import_file_id,
            carrier_name="Wan Hai Lines Ltd.",
            agreed_demurrage_free_days=21,
            agreed_detention_free_days=7,
            port_storage_free_days=5,
            agreement_reference="WHL-THXJ2609015-FD",
            agreement_date=date(2026, 9, 22),
            notes="Confirmed 21 demurrage free days and 7 detention days with Wan Hai Lines for booking THXJ2609015.",
        )
        fd_resp = register_free_days_agreement_service(
            db=db,
            payload=fd_payload,
            user="Logistics Officer",
        )
        print(f"Free Days Registered: {fd_resp.agreed_demurrage_free_days} days demurrage | Ref: {fd_resp.agreement_reference}")

        # Step 2: SH-01 Sailing Departure & B/L Confirmation
        print("\n>>> Step 2: Confirming Vessel Sailing & B/L (SH-01)...")
        # Ensure booking_request_date aligns with file timeline (Sept 18) rather than seeding timestamp
        if booking.booking_request_date and booking.booking_request_date.date() > date(2026, 9, 25):
            booking.booking_request_date = datetime(2026, 9, 18, 10, 0, 0, tzinfo=timezone.utc)
            db.commit()

        dep_payload = ShipmentDepartureConfirm(
            actual_departure_date=datetime(2026, 9, 25, 12, 0, 0, tzinfo=timezone.utc),
            shipped_on_board_date=date(2026, 9, 25),
            bill_of_lading_no="WHL-SHA-2026-9015",
            vessel_name="WAN HAI 511",
            voyage_number="V.W112",
            revised_eta=datetime(2026, 10, 23, 18, 0, 0, tzinfo=timezone.utc),
            notes="Vessel WAN HAI 511 sailed from Shanghai Port with B/L WHL-SHA-2026-9015. Shipped on board confirmed.",
        )
        departed_booking = confirm_departure_and_bol_service(
            db=db,
            booking_id=booking.booking_id,
            payload=dep_payload,
            user="Logistics Officer",
        )

        db.refresh(imp_file)
        db.refresh(departed_booking)

        print("\n=== AFTER EXECUTION ===")
        print(f"Shipment: {imp_file.import_file_code} | Stage: {imp_file.current_stage} | Progress: {imp_file.progress_percent}% | Next: {imp_file.next_action}")
        print(f"Booking: {departed_booking.booking_code}")
        print(f"  - Status: {departed_booking.status}")
        print(f"  - ATD: {departed_booking.atd}")
        print(f"  - Shipped on Board: {departed_booking.shipped_on_board_date}")
        print(f"  - B/L Number: {departed_booking.bill_of_lading_no}")
        print(f"  - Free Demurrage Days: {departed_booking.free_demurrage_days}")

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

        print("\nSUCCESS: BK-02 and SH-01 executed cleanly for IMP-2026-0005!")
    finally:
        db.close()

if __name__ == "__main__":
    execute()
