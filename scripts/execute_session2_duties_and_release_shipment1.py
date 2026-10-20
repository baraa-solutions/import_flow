"""
Session 2 Operational Execution: Customs Final Duty Assessment (CL-02), Payment (CL-03),
and Customs Final Release (CL-04) for Shipment IMP-2026-0001 (Air Cooled Water Chillers).
Elevates lifecycle progress to 95.0% and dispatches inland transport logistics.
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
from modules.customs_clearance.schemas import (
    FinalDutyAssessmentSubmit,
    CustomsDutyPaymentSubmit,
    CustomsFinalReleaseSubmit,
)
from modules.customs_clearance.service import (
    assess_final_customs_duties_service,
    record_customs_duty_payment_service,
    issue_final_customs_release_service,
)
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

        print("=" * 70)
        print("Executing Session 2: CL-02 Assessment -> CL-03 Payment -> CL-04 Release")
        print(f"Target Shipment: {imp_file.import_file_code} | Stage: {imp_file.current_stage_code} | Progress: {imp_file.progress_percent}%")
        print("=" * 70)

        # -------------------------------------------------------------
        # STEP 1: Final Duty Assessment (CL-02)
        # -------------------------------------------------------------
        print("\n>>> Step 1: Executing Final Duty Assessment (CL-02)...")
        cif_egp = 97000.0 * 48.50  # 4,704,500.00 EGP
        duty_2pct = round(cif_egp * 0.02, 2)  # 94,090.00 EGP
        vat_14pct = round((cif_egp + duty_2pct) * 0.14, 2)  # 671,802.60 EGP
        wht_1pct = round(cif_egp * 0.01, 2)  # 47,045.00 EGP
        dev_3pct = round(cif_egp * 0.03, 2)  # 141,135.00 EGP
        service_fees = 2500.0
        lab_fees = 2450.0
        total_payable = round(duty_2pct + vat_14pct + wht_1pct + dev_3pct + service_fees + lab_fees, 2)

        assess_payload = FinalDutyAssessmentSubmit(
            import_file_id=1,
            cif_base_amount=97000.0,
            customs_exchange_rate=48.50,
            import_duty_amount=duty_2pct,
            vat_amount=vat_14pct,
            schedule_tax_amount=0.0,
            wht_amount=wht_1pct,
            development_fee_amount=dev_3pct,
            customs_service_fees=service_fees,
            lab_service_fees=lab_fees,
            actual_duty_total=total_payable,
            nafeza_claim_number="CLM-ALX-2026-0001",
            nafeza_claim_date=datetime(2026, 9, 16, 9, 30, tzinfo=timezone.utc),
            assessment_notes="Final assessed duties calculated per Nafeza MTS tariff schedule 8418.69 with GOEIC conformity.",
        )

        record = assess_final_customs_duties_service(db, assess_payload, user="Customs Broker")
        db.refresh(imp_file)
        print(f"Assessed Total: {record.total_duty_payable} EGP | Status: {record.status}")
        print(f"File Progress: {imp_file.progress_percent}% | Next Action: {imp_file.next_action_code}")

        # -------------------------------------------------------------
        # STEP 2: Customs Duty Payment (CL-03)
        # -------------------------------------------------------------
        print("\n>>> Step 2: Executing Customs Duty Payment via Sadad (CL-03)...")
        payment_payload = CustomsDutyPaymentSubmit(
            import_file_id=1,
            bank_receipt_no="RCPT-CBE-2026-9812",
            sadad_number="SADAD-2026-00451",
            paying_bank_name="National Bank of Egypt (NBE)",
            payment_date=datetime(2026, 9, 16, 11, 0, tzinfo=timezone.utc),
            payment_method="Sadad Electronic / E-Finance",
            duty_paid_amount=total_payable,
            payment_notes="Sadad payment confirmed through NBE corporate portal. E-Finance receipt confirmed.",
        )

        record = record_customs_duty_payment_service(db, payment_payload, user="Finance Officer")
        db.refresh(imp_file)
        print(f"Paid Amount: {record.duty_paid_amount} EGP | Sadad: {record.sadad_number} | Status: {record.status}")

        # -------------------------------------------------------------
        # STEP 3: Customs Final Release (CL-04)
        # -------------------------------------------------------------
        print("\n>>> Step 3: Issuing Customs Final Release Permit (CL-04)...")
        release_payload = CustomsFinalReleaseSubmit(
            import_file_id=1,
            clearance_id=record.customs_clearance_id,
            release_permit_no="REL-ALX-2026-0091",
            release_date=datetime(2026, 9, 16, 14, 0, tzinfo=timezone.utc),
            release_officer_name="Counselor Ahmed El-Sayed (Customs General Director)",
            release_type="Unconditional Final Release",
            gate_pass_number="GP-ALX-2026-1102",
            transport_instructions="Dispatch under customs seal to Tenth of Ramadan Plant directly.",
            notes="Green release permit stamped and printed. Cargo released unconditionally for terminal gate-out.",
        )

        record = issue_final_customs_release_service(db, release_payload, user="Customs Broker")
        db.refresh(imp_file)

        print("\n=== FINAL VERIFICATION AFTER RELEASE ===")
        print(f"Shipment: {imp_file.import_file_code}")
        print(f"  - Progress Percent: {imp_file.progress_percent}% (Expected >= 95.0%)")
        print(f"  - Current Stage Code: {imp_file.current_stage_code}")
        print(f"  - Current Module: {imp_file.current_module}")
        print(f"  - Next Action Code: {imp_file.next_action_code}")
        print(f"Clearance Record: {record.clearance_code}")
        print(f"  - Status: {record.status}")
        print(f"  - Release Permit No: {record.release_permit_no}")
        print(f"  - Release Date: {record.release_date}")
        print(f"  - Gate Pass Number: {record.gate_pass_number}")
        print(f"  - Payment Status: {record.payment_status}")

        assert imp_file.progress_percent >= 95.0, f"Expected progress >= 95%, got {imp_file.progress_percent}%"
        assert record.status in ("Final Release Granted", "Released"), f"Expected Final Release Granted, got {record.status}"
        assert record.release_permit_no == "REL-ALX-2026-0091", "Permit mismatch"

        # Check dispatched inland transport tasks
        tasks = db.query(SmartTask).filter(
            SmartTask.import_file_id == 1,
            SmartTask.status != "Completed",
        ).all()
        print(f"\nOpen Tasks remaining for IMP-2026-0001 ({len(tasks)}):")
        for t in tasks:
            print(f"  - [{t.task_code}] {t.task_type}: {t.title} ({t.priority})")

        print("\n" + "=" * 70)
        print("SUCCESS: Session 2 operational milestones completed! IMP-2026-0001 is officially RELEASED!")
        print("=" * 70)

    finally:
        db.close()


if __name__ == "__main__":
    execute()
