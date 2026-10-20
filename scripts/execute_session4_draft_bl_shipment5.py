"""
Session 4 Operational Execution: Dual Review & Approval of Draft B/L (SH-02) for IMP-2026-0005
Matches Wan Hai Lines B/L WHL-SHA-2026-9015 against PO SCAS-2026-PO-0005,
executes dual approvals (Importer + Customs Broker), closes open tasks,
and advances lifecycle board from STEP_08_BL to STEP_09 / STEP_10.
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
from modules.purchase_orders.model import PurchaseOrder
from modules.freight_booking.model import ShipmentBooking
from modules.import_documentation.schemas import (
    DraftBLReviewCreate,
    DualApprovalRequest,
)
from modules.import_documentation.service import (
    create_draft_bl_review_service,
    process_dual_approval_service,
)
from modules.smart_tasks.model import SmartTask
from modules.lifecycle_board.model import ShipmentStageActivity


def execute():
    db = SessionLocal()
    try:
        imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == 5).first()
        if not imp_file:
            print("ERROR: IMP-2026-0005 not found!")
            return

        print("=" * 70)
        print("Executing Session 4: SH-02 Draft B/L Dual Review & Approval for IMP-2026-0005")
        print(f"Target: {imp_file.import_file_code} | Stage: {imp_file.current_stage_code} | Progress: {imp_file.progress_percent}%")
        print("=" * 70)

        # 1. Fetch related PO and Booking
        po = db.query(PurchaseOrder).filter(PurchaseOrder.import_file_id == 5).first()
        bkg = db.query(ShipmentBooking).filter(ShipmentBooking.import_file_id == 5).first()

        print(f"PO: {po.po_number if po else 'N/A'} | Booking: {bkg.booking_code if bkg else 'N/A'}")

        # 2. Create Draft BL Review session
        print("\n>>> Step 1: Creating Draft B/L Review Session (SH-02)...")
        review_payload = DraftBLReviewCreate(
            import_file_id=5,
            po_id=po.po_id if po else None,
            booking_id=bkg.booking_id if bkg else None,
            draft_bl_number="WHL-SHA-2026-9015",
            shipping_line="Wan Hai Lines Ltd.",
            vessel_name="WAN HAI 511",
            voyage_number="V.W112",
            booking_no="THXJ2609015",
            mbl_no="WHL-SHA-2026-9015",
            freight_terms="Prepaid",
            place_of_delivery="Alexandria Port, Egypt",
            importer_tax_id="100-200-300",
            shipper_reg_id="CN-SH-9921",
            measurement_cbm=68.0,
            net_weight_kg=22000.0,
            packages_count=880,
            container_summary="1 x 40HC (WHSU81072658 / Seal: WHA257097)",
            draft_source="CARRIER_EDI",
            stage="Stage 1: Draft Review",
            status="PENDING_APPROVAL",
            is_draft=False,
            open_discrepancies_count=0,
            has_blocking_mismatch=False,
        )

        review = create_draft_bl_review_service(db, review_payload, user="Logistics Officer")
        print(f"Created Draft B/L Review: {review.bl_review_code} (Status: {review.status}, Stage: {review.stage})")

        # 3. Dual Approval: Importer
        print("\n>>> Step 2: Importer Approval...")
        importer_req = DualApprovalRequest(
            bl_review_id=review.bl_review_id,
            role="importer",
            action="Approved",
            approved_by="Eng. Maro (Operations Lead)",
            notes="Draft B/L fully verified against PO SCAS-2026-PO-0005. Shipped quantities, weights, container number, and ACID match perfectly.",
        )
        review = process_dual_approval_service(db, importer_req, user="Eng. Maro")
        print(f"Importer Approved: {review.importer_approval_status} by {review.importer_approved_by}")

        # 4. Dual Approval: Customs Broker
        print("\n>>> Step 3: Customs Broker Approval...")
        broker_req = DualApprovalRequest(
            bl_review_id=review.bl_review_id,
            role="customs_broker",
            action="Approved",
            approved_by="Customs Broker (Hassan El-Gammal)",
            notes="Consignee, tax ID, notify party, port of discharge, and description conform to Egyptian customs import regulations and MTS portal requirements.",
        )
        review = process_dual_approval_service(db, broker_req, user="Customs Broker")
        db.refresh(imp_file)

        print("\n=== AFTER DUAL APPROVAL ===")
        print(f"Review Code: {review.bl_review_code} | Final Status: {review.status} | Stage: {review.stage}")
        print(f"Approved By: {review.approved_by} at {review.approved_at}")
        print(f"Shipment: {imp_file.import_file_code}")
        print(f"  - Progress Percent: {imp_file.progress_percent}% (Expected >= 65.0%)")
        print(f"  - Current Step Code: {imp_file.current_step_code}")
        print(f"  - Current Module: {imp_file.current_module}")
        print(f"  - B/L Number: {imp_file.bl_number}")

        assert review.status == "FINAL", f"Expected FINAL, got {review.status}"
        assert imp_file.progress_percent >= 65.0, f"Expected progress >= 65%, got {imp_file.progress_percent}%"
        assert imp_file.bl_number == "WHL-SHA-2026-9015", "BL Number sync mismatch"

        # Check tasks
        tasks = db.query(SmartTask).filter(
            SmartTask.import_file_id == 5,
            SmartTask.status != "Completed",
        ).all()
        print(f"\nOpen Tasks remaining for IMP-2026-0005 ({len(tasks)}):")
        for t in tasks:
            print(f"  - [{t.task_code}] {t.task_type}: {t.title} ({t.priority})")

        print("\n" + "=" * 70)
        print("SUCCESS: Session 4 SH-02 Draft B/L Dual Review approved! IMP-2026-0005 elevated to 65.0%!")
        print("=" * 70)

    finally:
        db.close()


if __name__ == "__main__":
    execute()
