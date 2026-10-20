"""
Operational execution script for Session 4: Shipment IMP-2026-0005 (ID: 5)
- Task TSK-2026-0020: Confirm freight booking and shipping line (BK-01)
- Award & select winning freight quote from Wan Hai Lines Ltd.
- Checklists: Fulfill all 24 pending checklist items (0 pending remaining)
- Step progression: Advance automatically to STEP_07 (Freight Allocations)
"""

import os
import sys
from datetime import datetime, timezone

# Ensure project root is on PYTHONPATH
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import database.models
from database.database import SessionLocal
from modules.freight_booking.schemas import (
    ShipmentBookingCreate,
    ShipmentBookingConfirm,
    ContainerAllocationItem,
    BookingChargeItem,
)
from modules.freight_booking.service import (
    create_booking_service,
    confirm_booking_service,
)
from modules.import_files.model import ImportFile
from modules.smart_tasks.model import SmartTask
from modules.shipping_scenarios.model import ShippingScenarioItem
from modules.lifecycle_board.model import ShipmentStageActivity
from modules.smart_checklists.service import (
    auto_sync_checklist,
    resolve_all_checklist_items_for_file,
    get_checklist_summary,
    check_gatekeeper,
)


def run_session_4():
    db = SessionLocal()
    try:
        print("=" * 70)
        print("Executing Session 4: Shipment IMP-2026-0005 (ID: 5)")
        print("=" * 70)

        # 1. Verify ImportFile exists and is open
        imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == 5).first()
        if not imp_file:
            print("ERROR: ImportFile #5 not found.")
            sys.exit(1)
        print(f"Loaded ImportFile: {imp_file.import_file_code} (Status: {imp_file.status}, Step: {imp_file.current_step_code})")

        # 2. Award and select winning shipping scenario item (Wan Hai Lines)
        print("\n--- Step 1: Selecting Winning Freight Offer ---")
        scen_item = db.query(ShippingScenarioItem).filter(ShippingScenarioItem.item_id == 3).first()
        if scen_item:
            scen_item.is_selected = True
            scen_item.notes = (scen_item.notes or "") + " [Selected as winning freight quote for IMP-2026-0005 (BK-01)]"
            db.commit()
            print(f"Selected winning offer #{scen_item.item_id}: {scen_item.provider_name} - ${scen_item.total_quotation_amount} USD")

        # 3. Create or load freight booking
        from modules.freight_booking.model import ShipmentBooking
        existing_booking = db.query(ShipmentBooking).filter(
            ShipmentBooking.import_file_id == 5,
            ShipmentBooking.is_active == True,
        ).first()

        if not existing_booking:
            print("\n--- Step 2: Creating Freight Booking Draft ---")
            create_payload = ShipmentBookingCreate(
                import_file_id=5,
                scenario_session_id=2,
                scenario_item_id=3,
                scenario_provider_name="Wan Hai Lines Ltd.",
                shipping_line_name="Wan Hai Lines Ltd.",
                freight_forwarder_name="Wan Hai Lines Ltd.",
                shipment_type="Ocean FCL",
                pol_name="Shanghai Port",
                pod_name="Alexandria Port",
                free_demurrage_days=21,
                vessel_name="WAN HAI 511",
                voyage_number="V.W112",
                etd=datetime(2026, 9, 25, 10, 0, tzinfo=timezone.utc),
                eta=datetime(2026, 10, 23, 18, 0, tzinfo=timezone.utc),
                containers_data=[
                    ContainerAllocationItem(
                        container_type="40HC",
                        quantity=1,
                        container_numbers=["WHSU81072658"],
                        seal_numbers=["WHA257097"],
                        vgm_weight_kg=24500.0,
                    )
                ],
                cost_charges_data=[
                    BookingChargeItem(
                        charge_type="Sea Freight 40ft",
                        unit="Per Container",
                        quantity=1.0,
                        container_type="40HC",
                        currency="USD",
                        rate=6700.0,
                        total=6700.0,
                        charge_category="FREIGHT",
                        fx_rate_to_usd=1.0,
                        amount_usd=6700.0,
                    ),
                    BookingChargeItem(
                        charge_type="Origin Local & EXW Handling",
                        unit="Per Shipment",
                        quantity=1.0,
                        currency="USD",
                        rate=1080.0,
                        total=1080.0,
                        charge_category="ORIGIN_LOCAL",
                        fx_rate_to_usd=1.0,
                        amount_usd=1080.0,
                    ),
                ],
                status="Draft",
                owner="Kamal",
                notes="حجز مساحة الشحن لشحنة PET Stock - اختيار العرض الفائز من Wan Hai Lines",
            )
            booking = create_booking_service(db, create_payload, user="Kamal")
            print(f"Created booking draft: {booking.booking_code}")
        else:
            booking = existing_booking
            print(f"Existing booking found: {booking.booking_code} (Status: {booking.status})")

        # 4. Confirm Freight Booking (BK-01)
        if booking.status != "Confirmed":
            print("\n--- Step 3: Confirming Freight Booking & Fixing Confirmation No (BK-01) ---")
            confirm_payload = ShipmentBookingConfirm(
                booking_confirmation_no="THXJ2609015",
                vessel_name="WAN HAI 511",
                voyage_number="V.W112",
                etd=datetime(2026, 9, 25, 10, 0, tzinfo=timezone.utc),
                eta=datetime(2026, 10, 23, 18, 0, tzinfo=timezone.utc),
                free_demurrage_days=21,
                notes="تم تأكيد واختيار عرض الشحن الفائز مع الخط الملاحي Wan Hai Lines وتثبيت رقم الحجز THXJ2609015 وفترة سماح 21 يوماً",
            )
            confirmed = confirm_booking_service(db, booking.booking_id, confirm_payload, user="Kamal")
            print(f"Booking confirmed: {confirmed.booking_code} -> Confirmation No: {confirmed.booking_confirmation_no}")
        else:
            print(f"Booking {booking.booking_code} is already Confirmed.")

        # 5. Fulfill all 24 checklist items
        print("\n--- Step 4: Resolving & Fulfilling 24 Checklist Items ---")
        auto_sync_checklist(db, 5)
        summary = resolve_all_checklist_items_for_file(
            db,
            file_id=5,
            target_status="PASSED",
            verified_by="Logistics Officer",
            notes="استيفاء واعتماد كافة بنود مرحلة ما قبل الشحن وإعدادات البوليصة بالكامل",
        )
        print(f"Checklist Summary: total={summary.total_items}, passed={summary.passed_items}, pending={summary.pending_items}, readiness={summary.readiness_score_pct}%, blocked={summary.is_gate_blocked}")

        # 6. Verify Gatekeeper & Stage Progression
        gate = check_gatekeeper(db, 5, "IN_TRANSIT")
        print(f"Gatekeeper Check (IN_TRANSIT): can_advance={gate.can_advance}, blocking={gate.blocking_count}")

        db.refresh(imp_file)
        task20 = db.query(SmartTask).filter(SmartTask.task_code == "TSK-2026-0020").first()
        print("\n" + "=" * 70)
        print("Final Status Verification:")
        print(f"  Shipment: {imp_file.import_file_code}")
        print(f"  Current Step: {imp_file.current_step_code}")
        print(f"  Current Module: {imp_file.current_module}")
        print(f"  Booking No: {imp_file.booking_no}")
        print(f"  Progress: {imp_file.progress_percent}%")
        print(f"  Task TSK-2026-0020 Status: {task20.status if task20 else 'N/A'} (auto-closed: {task20.is_auto_closed if task20 else 'N/A'})")
        print("=" * 70)

    finally:
        db.close()


if __name__ == "__main__":
    run_session_4()
