"""
Backfill and Data Cleansing Script for P0 Data Foundations (TASK-DB-03 to TASK-DB-08 & TASK-BE-09)
-------------------------------------------------------------------------------------------------
1. Backs up database before execution.
2. Cleanses misleading invoices_data JSON in import_files (e.g. aligning file 4 with real $43,704 PO).
3. Backfills all 25 operational stage snapshots across all 5 active import files via LifecycleAutoSyncEngine.
4. Seeds periodic ETA tracking logs (every 3 days) for active in-transit booking BKG-2026-0001.
5. Verifies schema integrity and database consistency.
"""

import os
import sys
import shutil
import json
import sqlite3
from datetime import datetime, timezone

# Ensure project root is in sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

from database.database import SessionLocal, engine
from modules.import_files.model import ImportFile
from modules.lifecycle_board.sync_engine import LifecycleAutoSyncEngine
from modules.lifecycle_board.model import ShipmentTimelineSnapshot
from modules.freight_booking.model import ShipmentBooking, ShipmentEtaTrackingLog

DB_PATH = "sorour_logistics.db"
BACKUP_PATH = "sorour_logistics.db.backup_p0"


def backup_database():
    print(f"📦 Backing up {DB_PATH} to {BACKUP_PATH}...")
    shutil.copy2(DB_PATH, BACKUP_PATH)
    print("✅ Backup completed successfully.")


def cleanse_misleading_invoices_data(db):
    print("🧹 Cleansing misleading invoices_data in import_files...")

    # File 4: Align with real PO-2026-003 approved amount ($43,704.00)
    file4 = db.query(ImportFile).filter(ImportFile.import_file_id == 4).first()
    if file4:
        old_data = file4.invoices_data
        file4.invoices_data = [
            {
                "invoice_no": file4.pi_number or "YH20260730-6",
                "invoice_type": "Proforma Invoice",
                "amount": 43704.0,
                "currency": "USD"
            }
        ]
        file4.estimated_cost = 43704.0
        file4.estimated_cost_currency = "USD"
        print(f"  - File 4: Cleaned invoices_data from {old_data} to {file4.invoices_data}")

    # File 5: Align with real PO-2026-005 amount ($39,820.00)
    file5 = db.query(ImportFile).filter(ImportFile.import_file_id == 5).first()
    if file5:
        old_data = file5.invoices_data
        file5.invoices_data = [
            {
                "invoice_no": file5.pi_number or "YH20260901-3",
                "invoice_type": "Proforma Invoice",
                "amount": 39820.0,
                "currency": "USD"
            }
        ]
        file5.estimated_cost = 39820.0
        file5.estimated_cost_currency = "USD"
        print(f"  - File 5: Cleaned invoices_data from {old_data} to {file5.invoices_data}")

    db.commit()
    print("✅ Misleading invoices_data cleansed.")


def backfill_timeline_snapshots(db):
    print("🚀 Backfilling 25-stage timeline snapshots for all active files...")
    files = db.query(ImportFile).order_by(ImportFile.import_file_id).all()
    
    total_snapshots = 0
    for f in files:
        res = LifecycleAutoSyncEngine.sync_file_timeline(db, import_file_id=f.import_file_id, commit=True)
        count = len(res.get("snapshots", []))
        total_snapshots += count
        completed = res.get("completed_count", 0)
        bottlenecks = res.get("bottlenecks_count", 0)
        progress = res.get("progress_percent", 0.0)
        print(f"  - File {f.import_file_code} (ID: {f.import_file_id}): {count} stages synced (Completed: {completed}, Bottlenecks: {bottlenecks}, Progress: {progress}%)")

    print(f"✅ Total timeline snapshots synced: {total_snapshots}")


def seed_vessel_eta_tracking_logs(db):
    print("🚢 Seeding periodic ETA tracking logs for in-transit booking...")
    booking = db.query(ShipmentBooking).filter(ShipmentBooking.booking_id == 1).first()
    if not booking:
        print("  - Booking ID 1 not found, skipping vessel tracking seed.")
        return

    # Check if tracking logs already exist
    existing_count = db.query(ShipmentEtaTrackingLog).filter(
        ShipmentEtaTrackingLog.booking_id == booking.booking_id
    ).count()
    if existing_count > 0:
        print(f"  - Booking {booking.booking_code} already has {existing_count} tracking logs. Skipping seed.")
        return

    tracking_data = [
        {
            "tracking_date": datetime(2026, 9, 22, 10, 0, 0),
            "vessel_location": "East China Sea / Dep Ningbo Port",
            "current_eta": datetime(2026, 10, 27, 8, 0, 0),
            "delay_days": 0,
            "remarks": "Vessel departed loading port on schedule, optimal weather conditions.",
            "is_ata_confirmed": False,
            "created_by": "Ops Manager",
        },
        {
            "tracking_date": datetime(2026, 9, 25, 14, 30, 0),
            "vessel_location": "South China Sea / Passing Taiwan Strait",
            "current_eta": datetime(2026, 10, 27, 8, 0, 0),
            "delay_days": 0,
            "remarks": "Cruising speed 18.5 knots, container temperature and seal verified.",
            "is_ata_confirmed": False,
            "created_by": "Ops Manager",
        },
        {
            "tracking_date": datetime(2026, 9, 29, 9, 15, 0),
            "vessel_location": "Malacca Strait / Passing Singapore",
            "current_eta": datetime(2026, 10, 27, 12, 0, 0),
            "delay_days": 0,
            "remarks": "Bunkering completed at Singapore anchorage. Resumed route.",
            "is_ata_confirmed": False,
            "created_by": "Ops Manager",
        },
        {
            "tracking_date": datetime(2026, 10, 3, 11, 45, 0),
            "vessel_location": "Indian Ocean / East of Sri Lanka",
            "current_eta": datetime(2026, 10, 28, 6, 0, 0),
            "delay_days": 1,
            "remarks": "Encountered monsoon rough seas, reduced speed to 14 knots. ETA revised +1 day.",
            "is_ata_confirmed": False,
            "created_by": "Ops Manager",
        },
        {
            "tracking_date": datetime(2026, 10, 7, 16, 20, 0),
            "vessel_location": "Arabian Sea / Crossing towards Bab el-Mandeb",
            "current_eta": datetime(2026, 10, 28, 6, 0, 0),
            "delay_days": 1,
            "remarks": "Weather cleared, resumed standard cruising speed.",
            "is_ata_confirmed": False,
            "created_by": "Ops Manager",
        },
        {
            "tracking_date": datetime(2026, 10, 11, 8, 0, 0),
            "vessel_location": "Southern Red Sea / Passing Hodeidah corridor",
            "current_eta": datetime(2026, 10, 27, 18, 0, 0),
            "delay_days": 0,
            "remarks": "Recovered 12 hours transit time, convoy slot booked at Suez Canal Authority.",
            "is_ata_confirmed": False,
            "created_by": "Ops Manager",
        },
        {
            "tracking_date": datetime(2026, 10, 15, 12, 0, 0),
            "vessel_location": "Gulf of Suez / Approaching Ain Sokhna Anchorage",
            "current_eta": datetime(2026, 10, 27, 8, 0, 0),
            "delay_days": 0,
            "remarks": "Approaching terminal fairway. ETA stable for Ain Sokhna DP World berth.",
            "is_ata_confirmed": False,
            "created_by": "Ops Manager",
        },
    ]

    for item in tracking_data:
        log = ShipmentEtaTrackingLog(
            booking_id=booking.booking_id,
            import_file_id=booking.import_file_id,
            tracking_date=item["tracking_date"],
            vessel_location=item["vessel_location"],
            current_eta=item["current_eta"],
            delay_days=item["delay_days"],
            remarks=item["remarks"],
            is_ata_confirmed=item["is_ata_confirmed"],
            created_at=item["tracking_date"],
            created_by=item["created_by"],
        )
        db.add(log)

    db.commit()
    print(f"✅ Successfully seeded {len(tracking_data)} periodic ETA tracking logs for booking {booking.booking_code}.")


def verify_results(db):
    print("🔍 Verifying database counts after backfill...")
    con = sqlite3.connect(DB_PATH)
    cur = con.cursor()

    snapshots_count = cur.execute("SELECT COUNT(*) FROM shipment_timeline_snapshots").fetchone()[0]
    eta_logs_count = cur.execute("SELECT COUNT(*) FROM shipment_eta_tracking_logs").fetchone()[0]
    file4_invoices = cur.execute("SELECT invoices_data FROM import_files WHERE import_file_id = 4").fetchone()[0]

    print(f"  - shipment_timeline_snapshots count: {snapshots_count} (Expected: 125)")
    print(f"  - shipment_eta_tracking_logs count: {eta_logs_count} (Expected: >= 7)")
    print(f"  - File 4 invoices_data: {file4_invoices}")

    assert snapshots_count == 125, f"Expected 125 snapshots, got {snapshots_count}"
    assert eta_logs_count >= 7, f"Expected >= 7 tracking logs, got {eta_logs_count}"
    assert "43704" in file4_invoices, f"Expected 43704 in file 4 invoices_data, got {file4_invoices}"
    assert "32000" not in file4_invoices, f"Found stale 32000 in file 4 invoices_data!"

    print("🎉 ALL CHECKS PASSED PERFECTLY!")


def main():
    print("=" * 80)
    print("STARTING P0 DATA FOUNDATIONS BACKFILL & CLEANSING")
    print("=" * 80)

    backup_database()

    db = SessionLocal()
    try:
        cleanse_misleading_invoices_data(db)
        backfill_timeline_snapshots(db)
        seed_vessel_eta_tracking_logs(db)
        verify_results(db)
    finally:
        db.close()

    print("=" * 80)
    print("P0 DATA FOUNDATIONS BACKFILL & CLEANSING COMPLETED SUCCESSFULLY")
    print("=" * 80)


if __name__ == "__main__":
    main()
