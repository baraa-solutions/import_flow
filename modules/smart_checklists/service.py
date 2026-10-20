"""
Business Service for Smart Import Checklist Engine
"""

from datetime import datetime, timezone
from typing import List, Optional, Dict, Any
from sqlalchemy.orm import Session
from sqlalchemy import select
from fastapi import HTTPException, status

import modules.smart_checklists.repository as repo
import modules.smart_checklists.validators as validators
from modules.smart_checklists.schemas import (
    ChecklistItemResponse,
    ChecklistSummaryResponse,
    ChecklistAutoSyncResponse,
    GatekeeperStatusResponse,
)
from modules.smart_checklists.model import ImportFileChecklistItem
from modules.import_files.model import ImportFile
from modules.audit_logs.model import AuditLog

# Referenced Models for Auto-Verification Cross-Checks
from modules.cargo_insurance.model import CargoInsuranceCertificate
from modules.cargox.model import CargoXEnvelope
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.customs_tariff.model import CustomsTariff
from modules.demurrage_detention.model import DemurrageTracking
from modules.financial_settlement.model import LandedCostSettlementRecord
from modules.freight_booking.model import ShipmentBooking
from modules.import_documentation.model import (
    AcidRegistrationSession,
    BankingDocumentSession,
    ShipmentDocumentItem,
)
from modules.import_requirements.model import ImportRequirementAssessment
from modules.warehouse_receiving.model import WarehouseReceivingRecord


def get_checklist_summary(
    db: Session,
    file_id: int,
    phase_code: Optional[str] = None,
    role: Optional[str] = None,
    status_filter: Optional[str] = None,
) -> ChecklistSummaryResponse:
    """Retrieve full checklist and readiness summary for an import file."""
    # Ensure file exists
    file_obj = db.scalar(select(ImportFile).where(ImportFile.import_file_id == file_id))
    if not file_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Import file #{file_id} not found.",
        )

    # Ensure questions are seeded
    all_items = repo.seed_checklist_for_file(db, file_id, file_obj.import_file_code)

    # Filter for display if requested
    filtered_items = repo.get_items_by_file(db, file_id, phase_code=phase_code, role=role, status=status_filter)

    # Calculate metrics across ALL items of this file
    total_items = len(all_items)
    passed_items = sum(1 for i in all_items if i.status == "PASSED")
    waived_items = sum(1 for i in all_items if i.status == "WAIVED")
    pending_items = total_items - passed_items - waived_items

    # Mandatory pending items
    blocking_questions = [
        f"{i.question_code}: {i.question_title_ar}"
        for i in all_items
        if i.is_mandatory and i.status == "PENDING"
    ]
    mandatory_pending_items = len(blocking_questions)
    is_gate_blocked = mandatory_pending_items > 0

    readiness_score_pct = int(round((passed_items + waived_items) / total_items * 100)) if total_items > 0 else 0

    return ChecklistSummaryResponse(
        import_file_id=file_id,
        import_file_code=file_obj.import_file_code,
        total_items=total_items,
        passed_items=passed_items,
        pending_items=pending_items,
        waived_items=waived_items,
        mandatory_pending_items=mandatory_pending_items,
        readiness_score_pct=readiness_score_pct,
        is_gate_blocked=is_gate_blocked,
        blocking_questions=blocking_questions,
        items=[ChecklistItemResponse.model_validate(itm) for itm in filtered_items],
    )


def auto_sync_checklist(db: Session, file_id: int) -> ChecklistAutoSyncResponse:
    """
    Intelligent Auto-Verification Engine.
    Cross-examines actual database tables and auto-passes matching checklist items.
    """
    file_obj = db.scalar(select(ImportFile).where(ImportFile.import_file_id == file_id))
    if not file_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Import file #{file_id} not found.",
        )

    # Ensure items exist
    items = repo.seed_checklist_for_file(db, file_id, file_obj.import_file_code)
    item_map = {i.question_code: i for i in items}
    newly_passed = []

    def mark_passed(code: str, audit_source: str):
        target = item_map.get(code)
        if target and target.status == "PENDING":
            target.status = "PASSED"
            target.verified_by = "System Auto-Sync"
            target.verified_at = datetime.now(timezone.utc)
            target.notes = f"Verified automatically from {audit_source}"
            target.updated_at = datetime.now(timezone.utc)
            newly_passed.append(code)

    # 1. Check Incoterm
    if file_obj.incoterm_code and len(file_obj.incoterm_code.strip()) > 0:
        mark_passed("CHK_PRE_01", f"import_files.incoterm_code ({file_obj.incoterm_code})")

    # 2. Check Import Requirements & Decree 43
    req = db.scalar(
        select(ImportRequirementAssessment).where(
            ImportRequirementAssessment.import_file_id == file_id,
            ImportRequirementAssessment.is_active == True,
        )
    )
    if req:
        if req.decree_43_applicable or req.white_list_verified or req.factory_registration_no:
            mark_passed("CHK_PRE_02", "import_requirement_assessments (Decree 43 / Factory Reg)")
        if req.inspection_status in ("Completed", "Waived", "Approved"):
            mark_passed("CHK_PRE_04", f"import_requirement_assessments.inspection_status ({req.inspection_status})")

    # 3. Check HS Code in Customs Tariffs
    if file_obj.hs_code:
        tariff = db.scalar(select(CustomsTariff).where(CustomsTariff.hs_code == file_obj.hs_code, CustomsTariff.is_active == True))
        if tariff:
            mark_passed("CHK_PRE_03", f"customs_tariffs (HS: {file_obj.hs_code}, Duty: {tariff.customs_duty_rate}%)")

    # 4. Check Cargo Ready Date
    if file_obj.cargo_ready_date:
        mark_passed("CHK_PRE_08", f"import_files.cargo_ready_date ({file_obj.cargo_ready_date})")

    # 5. Check Banking Docs (L/C or Form 4)
    bank_doc = db.scalar(
        select(BankingDocumentSession).where(
            BankingDocumentSession.import_file_id == file_id,
            BankingDocumentSession.is_active == True,
        )
    )
    if bank_doc and bank_doc.status in ("Approved by Bank", "Form Issued", "Received"):
        mark_passed("CHK_PRE_05", f"banking_document_sessions ({bank_doc.doc_type} - {bank_doc.status})")

    # 6. Check CargoX Envelope
    cargox_env = db.scalar(
        select(CargoXEnvelope).where(
            CargoXEnvelope.import_file_id == file_id,
            CargoXEnvelope.is_active == True,
        )
    )
    if cargox_env and cargox_env.status in ("SEALED_AND_TRANSFERRED", "ACCEPTED_BY_CUSTOMS", "UPLOADED_BY_SUPPLIER"):
        mark_passed("CHK_PRE_06", f"cargox_envelopes (Status: {cargox_env.status})")

    # 7. Check Marine Insurance
    ins = db.scalar(
        select(CargoInsuranceCertificate).where(
            CargoInsuranceCertificate.import_file_id == file_id,
            CargoInsuranceCertificate.is_active == True,
        )
    )
    if ins and ins.status in ("ISSUED", "DRAFT"):
        mark_passed("CHK_TRN_01", f"cargo_insurance_certificates (Policy: {ins.policy_number or ins.certificate_code})")

    # 8. Check Shipment Booking & ETA
    booking = db.scalar(
        select(ShipmentBooking).where(
            ShipmentBooking.import_file_id == file_id,
            ShipmentBooking.is_active == True,
        )
    )
    if booking and booking.eta:
        mark_passed("CHK_TRN_02", f"shipment_bookings (ETA: {booking.eta})")

    # 9. Check Original B/L & Endorsement
    bl_doc = db.scalar(
        select(ShipmentDocumentItem).where(
            ShipmentDocumentItem.import_file_id == file_id,
            ShipmentDocumentItem.doc_name.like("%Bill of Lading%"),
            ShipmentDocumentItem.is_active == True,
        )
    )
    if bl_doc and (bl_doc.is_bl_endorsed or bl_doc.status == "Approved"):
        mark_passed("CHK_TRN_03", f"shipment_document_items (B/L Endorsed: {bl_doc.is_bl_endorsed})")

    # 10. Check Demurrage & Free Time
    demurrage = db.scalar(
        select(DemurrageTracking).where(
            DemurrageTracking.import_file_id == file_id,
            DemurrageTracking.is_active == True,
        )
    )
    if demurrage:
        mark_passed("CHK_PRT_02", f"demurrage_trackings (Status: {demurrage.status})")

    # 11. Check Customs Clearance
    clr = db.scalar(
        select(CustomsClearanceRecord).where(
            CustomsClearanceRecord.import_file_id == file_id,
            CustomsClearanceRecord.is_active == True,
        )
    )
    if clr:
        if clr.port_arrival_date or clr.delivery_order_number or clr.delivery_order_status in ("Paid & Received", "PAID_AND_RECEIVED") or file_obj.delivery_order_no:
            mark_passed("CHK_PRT_01", f"customs_clearance_records (D/O: {clr.delivery_order_number or file_obj.delivery_order_no or 'Issued'})")
        if clr.channel_type:
            mark_passed("CHK_PRT_03", f"customs_clearance_records.channel_type ({clr.channel_type})")
        if clr.declaration_46_no or file_obj.acid_number:
            mark_passed("CHK_PRT_04", f"declaration_46 ({clr.declaration_46_no or 'ACID Validated'})")
        if (clr.actual_duty_total or 0) > 0:  # legacy rows may hold NULL
            mark_passed("CHK_CLR_01", f"customs_clearance_records (Actual Duty: {clr.actual_duty_total} EGP)")
        if clr.sample_test_status in ("Approved", "Conforming") or clr.is_under_bond_release:
            mark_passed("CHK_CLR_02", f"customs_clearance_records.sample_test_status ({clr.sample_test_status})")
        if clr.bank_receipt_no or clr.payment_status == "Paid & Verified":
            mark_passed("CHK_CLR_03", f"customs_clearance_records.bank_receipt_no ({clr.bank_receipt_no})")
        if (clr.import_duty_amount or 0) > 0:
            mark_passed("CHK_CLR_04", "customs_clearance_records (Itemized Duty Breakdown)")
        if clr.release_permit_no:
            mark_passed("CHK_PST_01", f"customs_clearance_records.release_permit_no ({clr.release_permit_no})")

    # 12. Check Step 09 / Draft Docs Dual Review
    if file_obj.current_phase_id and file_obj.current_phase_id >= 4:
        mark_passed("CHK_PRE_09", f"lifecycle_operations_board (Completed Phase {file_obj.current_phase_id - 1} Docs Approval)")

    # 13. Check Warehouse Receiving / GRN
    wh_rec = db.scalar(
        select(WarehouseReceivingRecord).where(
            WarehouseReceivingRecord.import_file_id == file_id,
            WarehouseReceivingRecord.is_active == True,
        )
    )
    if wh_rec and wh_rec.grn_code:
        mark_passed("CHK_PST_01", f"warehouse_receiving_records.grn_code ({wh_rec.grn_code})")

    # 14. Check Financial Settlement (Landed Cost)
    settle = db.scalar(
        select(LandedCostSettlementRecord).where(
            LandedCostSettlementRecord.import_file_id == file_id,
            LandedCostSettlementRecord.is_active == True,
        )
    )
    if settle and (settle.total_landed_cost_egp or 0) > 0:
        mark_passed("CHK_PST_02", f"financial_settlement_records (Total Landed Cost: {settle.total_landed_cost_egp} EGP)")
    elif (file_obj.actual_landed_cost_total_egp or 0) > 0:
        mark_passed("CHK_PST_02", f"import_files.actual_landed_cost_total_egp ({file_obj.actual_landed_cost_total_egp} EGP)")

    db.commit()

    # Recompute summary
    summary = get_checklist_summary(db, file_id)

    return ChecklistAutoSyncResponse(
        import_file_id=file_id,
        synced_items_count=len(items),
        newly_passed_codes=newly_passed,
        readiness_score_pct=summary.readiness_score_pct,
        is_gate_blocked=summary.is_gate_blocked,
        message=f"Auto-sync completed. {len(newly_passed)} questions verified automatically from database records.",
    )


def toggle_item(
    db: Session,
    file_id: int,
    item_id: int,
    new_status: str,
    notes: Optional[str] = None,
    verified_by: Optional[str] = "Kamal",
) -> ChecklistItemResponse:
    """Manually toggle an item's status (Passed, Pending, Waived)."""
    validators.validate_status(new_status)
    item = repo.get_item_by_id(db, item_id)
    if not item or item.import_file_id != file_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Checklist item #{item_id} for file #{file_id} not found.",
        )

    updated = repo.update_item_status(
        db=db,
        item_id=item_id,
        status=new_status,
        verified_by=verified_by,
        notes=notes,
    )
    return ChecklistItemResponse.model_validate(updated)


def override_item(
    db: Session,
    file_id: int,
    item_id: int,
    reason: str,
    authorized_by: Optional[str] = "Operations Manager",
) -> ChecklistItemResponse:
    """Grant conditional waiver / override for a mandatory item with audit logging."""
    item = repo.get_item_by_id(db, item_id)
    if not item or item.import_file_id != file_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Checklist item #{item_id} for file #{file_id} not found.",
        )

    validators.validate_override(item.is_mandatory, reason)

    updated = repo.update_item_status(
        db=db,
        item_id=item_id,
        status="WAIVED",
        verified_by=authorized_by,
        notes=f"Conditional Override Granted by {authorized_by}",
        override_reason=reason,
    )

    # Log into Audit Trail
    audit = AuditLog(
        entity_type="ImportFileChecklistItem",
        entity_id=item_id,
        entity_code=item.question_code,
        action="CONDITIONAL_OVERRIDE",
        performed_by=authorized_by or "Manager",
        changes_summary=f"Item {item.question_code} waived for File #{file_id}. Reason: {reason}",
    )
    db.add(audit)
    db.commit()

    return ChecklistItemResponse.model_validate(updated)


def check_gatekeeper(db: Session, file_id: int, target_phase: str) -> GatekeeperStatusResponse:
    """
    Evaluates whether an import file is legally and operationally clear to transition to target_phase.
    """
    summary = get_checklist_summary(db, file_id)

    # Map phases to relevant prerequisite phases
    PHASE_PREREQUISITES = {
        "IN_TRANSIT": ["PRE_SHIPMENT"],
        "PORT_ARRIVAL": ["PRE_SHIPMENT", "IN_TRANSIT"],
        "CLEARANCE": ["PRE_SHIPMENT", "IN_TRANSIT", "PORT_ARRIVAL"],
        "POST_CLEARANCE": ["PRE_SHIPMENT", "IN_TRANSIT", "PORT_ARRIVAL", "CLEARANCE"],
    }

    req_phases = PHASE_PREREQUISITES.get(target_phase, [])
    blocking = [
        f"{i.question_code}: {i.question_title_ar}"
        for i in summary.items
        if i.is_mandatory and i.status == "PENDING" and i.phase_code in req_phases
    ]

    can_advance = len(blocking) == 0

    msg = "All mandatory checklist requirements met. Gate clear for transition." if can_advance else f"Gatekeeper blocked: {len(blocking)} mandatory questions must be resolved or waived."

    return GatekeeperStatusResponse(
        import_file_id=file_id,
        current_phase="Active",
        target_phase=target_phase,
        can_advance=can_advance,
        blocking_count=len(blocking),
        blocking_questions=blocking,
        message=msg,
    )


def enforce_gatekeeper_transition(db: Session, file_id: int, target_phase: str) -> GatekeeperStatusResponse:
    """
    Enforces that all mandatory checklist requirements are satisfied before transitioning
    to target_phase. Raises HTTP 409 Conflict if blocked.
    """
    gate = check_gatekeeper(db, file_id=file_id, target_phase=target_phase)
    if not gate.can_advance:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "CHECKLIST_GATE_BLOCKED",
                "message": f"Gatekeeper blocked: {gate.blocking_count} mandatory checklist item(s) pending for phase {target_phase}.",
                "blocking_count": gate.blocking_count,
                "blocking_questions": gate.blocking_questions,
            },
        )
    return gate


def resolve_all_checklist_items_for_file(
    db: Session,
    file_id: int,
    target_status: str = "PASSED",
    verified_by: Optional[str] = "Operations Team",
    notes: Optional[str] = "All operational checklist items verified and cleared",
) -> ChecklistSummaryResponse:
    """
    Batch-verifies or waives all pending checklist items for an import file.
    Ensures that no pending checklist items remain for operational stage clearance.
    """
    validators.validate_status(target_status)
    file_obj = db.scalar(select(ImportFile).where(ImportFile.import_file_id == file_id))
    if not file_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Import file #{file_id} not found.",
        )
    items = repo.seed_checklist_for_file(db, file_id, file_obj.import_file_code)
    now = datetime.now(timezone.utc)
    for itm in items:
        if itm.status == "PENDING":
            itm.status = target_status
            itm.verified_by = verified_by or "Operations Team"
            itm.verified_at = now
            itm.notes = notes
            itm.updated_at = now
    db.commit()
    return get_checklist_summary(db, file_id)


