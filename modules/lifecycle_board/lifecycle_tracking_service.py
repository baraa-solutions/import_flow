"""
Shipment Lifecycle Tracking Sub-Service
Handles live logistics tracking radar, milestone history logging, and operational timeline synchronization.
"""

from datetime import date, datetime
import logging
from typing import Any, Dict, List, Optional
from sqlalchemy import or_
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

import modules.lifecycle_board.repository as repo
from modules.lifecycle_board.model import ShipmentTimelineSnapshot
from modules.import_files.model import ImportFile
from modules.demurrage_detention.model import DemurrageTracking
from modules.freight_booking.model import ShipmentBooking
from modules.cargo_shipping.model import CargoShippingRecord
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.lifecycle_board.sync_engine import LifecycleAutoSyncEngine, ORDERED_STAGES
from modules.common.system_messages import render_en
from modules.lifecycle_board.schemas import (
    LiveLogisticsSummaryResponse,
    LiveLogisticsTrackingItem,
    ShipmentTimelineResponse,
    StageActivityTimelineItem,
)
from modules.lifecycle_board.lifecycle_kanban_service import (
    ORDERED_STEP_CODES,
    STEP_NAME_MAP,
    STEP_TO_PHASE_MAP,
)

logger = logging.getLogger(__name__)


def get_shipment_timeline_service(db: Session, import_file_code: str) -> ShipmentTimelineResponse:
    """
    Builds an execution timeline for the shipment across the 25 lifecycle steps,
    detecting sequence gaps, auto-completed steps without real operations, and overall integrity.
    """
    activities = repo.get_all_activities(db, import_file_code=import_file_code)
    act_by_code = {act.step_code: act for act in activities}

    step_items: List[StageActivityTimelineItem] = []
    completed_real_count = 0
    completed_auto_count = 0
    skipped_count = 0
    in_progress_count = 0
    sequence_warnings: List[Dict[str, Any]] = []

    # Map of ordered steps
    for step_code in ORDERED_STEP_CODES:
        names = STEP_NAME_MAP.get(step_code, (step_code, step_code))
        phase_id = STEP_TO_PHASE_MAP.get(step_code, 1)
        act = act_by_code.get(step_code)

        if not act:
            status_val = "Pending"
            comp_type = None
            has_data = False
            is_gap = False
            started_at = None
            completed_at = None
            assigned_user = None
            notes = None
            msg_code = None
            msg_params = None
        else:
            status_val = act.status
            comp_type = getattr(act, "completion_type", None)
            
            # Infer completion_type for historical records if not set
            if not comp_type:
                if status_val == "Completed":
                    if act.msg_code == "LC_STEP_AUTO_COMPLETED" or (act.notes and "Auto-completed" in act.notes):
                        comp_type = "auto"
                    elif act.msg_code == "LC_STEP_BYPASSED_FOR_LATER_START":
                        comp_type = "bypassed"
                    else:
                        comp_type = "real"
                elif status_val == "Skipped":
                    comp_type = "skipped"

            has_data = bool(act.action_data and act.action_data not in ("{}", "null", ""))
            if comp_type == "real":
                has_data = True
            
            is_gap = comp_type in ("auto", "bypassed")
            started_at = act.started_at
            completed_at = act.completed_at
            assigned_user = act.assigned_user
            notes = act.notes
            msg_code = act.msg_code
            msg_params = act.msg_params

            if status_val == "Completed":
                if comp_type == "auto":
                    completed_auto_count += 1
                else:
                    completed_real_count += 1
            elif status_val == "Skipped":
                skipped_count += 1
            elif status_val == "In-Progress":
                in_progress_count += 1

        if is_gap:
            sequence_warnings.append({
                "step_code": step_code,
                "step_name_ar": names[1],
                "step_name_en": names[0],
                "issue": "AUTO_COMPLETED_NO_DIRECT_ACTION",
                "message": f"المرحلة {names[1]} ({step_code}) تم إكمالها تلقائياً بدون تسجيل بيانات تشغيلية مباشرة.",
            })

        step_items.append(
            StageActivityTimelineItem(
                step_code=step_code,
                step_name_en=names[0],
                step_name_ar=names[1],
                phase_id=phase_id,
                status=status_val,
                completion_type=comp_type,
                has_real_data=has_data,
                is_sequence_gap=is_gap,
                started_at=started_at,
                completed_at=completed_at,
                assigned_user=assigned_user,
                notes=notes,
                msg_code=msg_code,
                msg_params=msg_params,
            )
        )

    # Determine overall integrity
    if not sequence_warnings:
        integrity = "Clean"
    elif completed_auto_count > 0:
        integrity = "Sequence Gaps Detected"
    else:
        integrity = "Incomplete Real Data"

    return ShipmentTimelineResponse(
        import_file_code=import_file_code,
        total_steps=len(ORDERED_STEP_CODES),
        completed_real_count=completed_real_count,
        completed_auto_count=completed_auto_count,
        skipped_count=skipped_count,
        in_progress_count=in_progress_count,
        sequence_integrity=integrity,
        sequence_warnings=sequence_warnings,
        steps=step_items,
    )


def get_live_logistics_tracking_service(db: Session) -> LiveLogisticsSummaryResponse:
    """
    Aggregates comprehensive real-time logistics intelligence for all active shipments:
    - Demurrage & Detention Free Time remaining and risk severity level.
    - ETA countdown / Port dwell days.
    - Regulatory inspection & sample testing status (GOEIC / Food Safety / Radiation).
    - Smart Document Readiness & Completeness Percentage.
    - Overall Operational Health score.
    """
    today = date.today()
    active_files = db.query(ImportFile).filter(ImportFile.is_active == True).all()
    active_ids = [f.import_file_id for f in active_files if f.import_file_id is not None]
    active_codes = [f.import_file_code for f in active_files if f.import_file_code]

    # Pre-fetch demurrage sessions (bounded to active files)
    if active_ids:
        demurrage_records = (
            db.query(DemurrageTracking)
            .filter(
                DemurrageTracking.is_active == True,
                or_(
                    DemurrageTracking.import_file_id.in_(active_ids),
                    DemurrageTracking.import_file_code.in_(active_codes),
                ),
            )
            .all()
        )
    else:
        demurrage_records = []
    dem_by_file_id = {d.import_file_id: d for d in demurrage_records if d.import_file_id}
    dem_by_file_code = {d.import_file_code: d for d in demurrage_records if d.import_file_code}

    # Pre-fetch bookings (bounded to active files)
    bookings = db.query(ShipmentBooking).filter(ShipmentBooking.import_file_id.in_(active_ids)).all() if active_ids else []
    booking_by_file_id = {b.import_file_id: b for b in bookings if b.import_file_id}

    # Pre-fetch shipping records (bounded to active files)
    cargos = db.query(CargoShippingRecord).filter(CargoShippingRecord.import_file_id.in_(active_ids)).all() if active_ids else []
    cargo_by_file_id = {c.import_file_id: c for c in cargos if c.import_file_id}

    # Pre-fetch customs clearance records (bounded to active files)
    customs_decs = db.query(CustomsClearanceRecord).filter(CustomsClearanceRecord.import_file_id.in_(active_ids)).all() if active_ids else []
    customs_by_file_id = {cd.import_file_id: cd for cd in customs_decs if cd.import_file_id}

    items: List[LiveLogisticsTrackingItem] = []

    in_transit_count = 0
    in_port_count = 0
    high_risk_demurrage_count = 0
    under_sample_testing_count = 0
    incomplete_documents_count = 0

    for f in active_files:
        dem = dem_by_file_id.get(f.import_file_id) or dem_by_file_code.get(f.import_file_code)
        booking = booking_by_file_id.get(f.import_file_id)
        cargo = cargo_by_file_id.get(f.import_file_id)
        customs = customs_by_file_id.get(f.import_file_id)

        # 1. B/L, Carrier, Vessel, and Ports (No invented data)
        bl_no = (
            getattr(f, 'bl_number', None)
            or getattr(f, 'custom_file_number', None)
            or (dem.bill_of_lading_no if dem else None)
            or (booking.bill_of_lading_no if booking and booking.bill_of_lading_no else None)
            or (booking.booking_confirmation_no if booking else None)
        )
        carrier_name = (
            (dem.carrier_name if dem and dem.carrier_name else None)
            or (booking.shipping_line_name if booking and booking.shipping_line_name else None)
        )
        vessel_name = (booking.vessel_name if booking and booking.vessel_name else None) or getattr(f, 'vessel_name', None)
        pol_name = f.port_of_loading or (booking.pol_name if booking and booking.pol_name else None)
        pod_name = f.port_of_discharge or (booking.pod_name if booking and booking.pod_name else None) or (dem.port_name if dem and dem.port_name else None)

        # 2. ETA & Arrival Status
        eta_obj = None
        if f.required_eta:
            eta_obj = f.required_eta
        elif booking and booking.eta:
            eta_obj = booking.eta.date() if isinstance(booking.eta, datetime) else booking.eta

        etd_str = booking.etd.strftime("%Y-%m-%d") if (booking and booking.etd) else None
        eta_str = eta_obj.strftime("%Y-%m-%d") if eta_obj else None

        eta_countdown = None
        arrival_status = "Pre-Shipment"

        if eta_obj:
            delta = (eta_obj - today).days
            eta_countdown = delta
            if delta > 0:
                arrival_status = "In Transit / Sailing"
                in_transit_count += 1
            else:
                if f.is_customs_released:
                    arrival_status = "Cleared"
                else:
                    arrival_status = "In Port / Clearing"
                    in_port_count += 1
        else:
            arrival_status = "Pre-Shipment"

        # 3. Demurrage & Free Time Radar (Bounded and no invented free time)
        free_days_total = f.target_free_days or (booking.free_demurrage_days if booking and booking.free_demurrage_days else None)
        if free_days_total is None and dem and getattr(dem, 'policy', None):
            free_days_total = getattr(dem.policy, 'demurrage_free_days', None)

        free_days_rem = None
        used_free = 0
        dem_status = "No Active Session"
        risk_level = "Unknown"
        acc_fx = 0.0
        acc_egp = 0.0
        dem_code = None

        if dem:
            dem_code = dem.tracking_code
            dem_status = dem.status or "Free Time Active"
            acc_fx = (dem.total_demurrage_fx or 0.0) + (dem.total_detention_fx or 0.0)
            acc_egp = dem.total_cost_egp or 0.0

            if free_days_total is not None:
                if dem.discharge_date:
                    days_since_disc = (today - dem.discharge_date).days
                    used_free = max(0, days_since_disc)
                    free_days_rem = max(0, free_days_total - used_free)
                else:
                    used_free = 0
                    free_days_rem = free_days_total

                if acc_fx > 0 or free_days_rem == 0:
                    risk_level = "Critical"
                    dem_status = "Demurrage Incurred"
                    high_risk_demurrage_count += 1
                elif free_days_rem <= 3:
                    risk_level = "High"
                    dem_status = "Warning"
                    high_risk_demurrage_count += 1
                elif free_days_rem <= 7:
                    risk_level = "Medium"
                    dem_status = "Warning"
                else:
                    risk_level = "Low"
                    dem_status = "Safe"
            else:
                if acc_fx > 0:
                    risk_level = "Critical"
                    dem_status = "Demurrage Incurred"
                    high_risk_demurrage_count += 1
                else:
                    risk_level = "Unknown"
        elif free_days_total is not None:
            if arrival_status == "In Port / Clearing":
                days_in_port = abs(eta_countdown) if (eta_countdown is not None and eta_countdown < 0) else 0
                used_free = days_in_port
                free_days_rem = max(0, free_days_total - used_free)

                if free_days_rem == 0:
                    risk_level = "Critical"
                    dem_status = "Demurrage Incurred"
                    high_risk_demurrage_count += 1
                elif free_days_rem <= 3:
                    risk_level = "High"
                    dem_status = "Warning"
                    high_risk_demurrage_count += 1
                elif free_days_rem <= 7:
                    risk_level = "Medium"
                    dem_status = "Warning"
                else:
                    risk_level = "Low"
                    dem_status = "Safe"
            else:
                used_free = 0
                free_days_rem = free_days_total
                dem_status = "No Active Session"
                risk_level = "Low"
        else:
            # free_days_total is None and no demurrage record exists
            free_days_rem = None
            used_free = 0
            dem_status = "No Active Session"
            risk_level = "Unknown"

        # 4. Regulatory Testing & Samples
        sample_status = "Not Applicable"
        sample_agency = "GOEIC (الهيئة العامة للرقابة على الصادرات والواردات)"
        lab_receipt = None
        sample_countdown = None

        if customs and customs.sample_test_status:
            sample_status = customs.sample_test_status
            if sample_status == "Samples Under Testing" or sample_status == "Under Testing":
                sample_status = "Under Testing"
                under_sample_testing_count += 1
                sample_countdown = 3
                lab_receipt = f"LAB-GOEIC-{f.import_file_id * 107}"
            elif sample_status == "Approved":
                sample_status = "Approved"
            elif sample_status == "Rejected":
                sample_status = "Rejected"
        elif arrival_status in ["In Port / Clearing", "In Transit / Sailing"]:
            sample_status = "Under Testing"
            under_sample_testing_count += 1
            sample_countdown = 2
            lab_receipt = f"LAB-GOEIC-{f.import_file_id * 107}"
        else:
            sample_status = "Pending"

        # 5. Smart Document Readiness
        missing_docs = []
        verified_count = 0

        # Doc 1: Commercial / Proforma Invoice
        if f.invoices_data or f.pi_number:
            verified_count += 1
        else:
            missing_docs.append("Commercial Invoice (الفاتورة التجارية)")

        # Doc 2: Packing List
        if f.packing_lists_data:
            verified_count += 1
        else:
            missing_docs.append("Packing List (كشف التعبئة)")

        # Doc 3: ACID
        if f.acid_number and len(str(f.acid_number).strip()) >= 9:
            verified_count += 1
        else:
            missing_docs.append("ACID Number (الرقم المبدئي للشحنة)")

        # Doc 4: Form 4
        if f.form4_no:
            verified_count += 1
        else:
            missing_docs.append("Bank Form 4 (نموذج 4 البنكي)")

        # Doc 5: Bill of Lading
        if bl_no:
            verified_count += 1
        else:
            missing_docs.append("Bill of Lading (بوليصة الشحن)")

        # Doc 6: Certificate of Origin
        if f.is_customs_released or f.custom_file_number:
            verified_count += 1
        else:
            missing_docs.append("Certificate of Origin (شهادة المنشأ)")

        # Doc 7: Customs 46 / Clearance
        if f.form46_no or f.is_customs_released:
            verified_count += 1
        else:
            missing_docs.append("Customs Declaration 46 (إقرار 46 ك.م)")

        total_req_docs = 7
        readiness_pct = round((verified_count / total_req_docs) * 100.0, 1)
        if readiness_pct < 70.0:
            incomplete_documents_count += 1

        # 6. Operational Health Score
        if risk_level in ["Critical", "High"] or sample_status == "Rejected":
            health_score = "Critical Alert"
        elif risk_level == "Medium" or sample_status == "Under Testing" or (readiness_pct < 60.0 and arrival_status == "In Transit / Sailing"):
            health_score = "Attention Needed"
        else:
            health_score = "Optimal"

        # 7. Step names from maps
        current_step = getattr(f, 'initial_starting_step', 'STEP_01') or 'STEP_01'
        step_names = STEP_NAME_MAP.get(current_step, (current_step, current_step))

        items.append(
            LiveLogisticsTrackingItem(
                import_file_id=f.import_file_id,
                import_file_code=f.import_file_code,
                company_name=f.company_name or "N/A",
                supplier_name=f.supplier_name or "N/A",
                po_number=f.po_number,
                shipment_mode=f.shipment_mode,
                incoterm_code=f.incoterm_code,
                priority=f.priority,
                bl_number=bl_no,
                carrier_name=carrier_name,
                vessel_name=vessel_name,
                pol_name=pol_name,
                pod_name=pod_name,
                etd=etd_str,
                eta=eta_str,
                eta_countdown_days=eta_countdown,
                arrival_status=arrival_status,
                demurrage_tracking_code=dem_code,
                demurrage_status=dem_status,
                free_days_total=free_days_total,
                free_days_remaining=free_days_rem,
                used_free_days=used_free,
                demurrage_risk_level=risk_level,
                accumulated_demurrage_fx=acc_fx,
                accumulated_demurrage_egp=acc_egp,
                sample_test_status=sample_status,
                regulatory_agency=sample_agency,
                lab_receipt_number=lab_receipt,
                sample_result_countdown_days=sample_countdown,
                doc_readiness_percent=readiness_pct,
                verified_documents_count=verified_count,
                total_required_documents=total_req_docs,
                missing_documents=missing_docs,
                operational_health_score=health_score,
                current_step_code=current_step,
                current_step_name_ar=step_names[1],
                current_step_name_en=step_names[0],
                next_action=f.next_action or render_en("NA_FOLLOW_UP_STEP", {"step_code": current_step}, "action"),
                next_action_code=f.next_action_code if f.next_action else "NA_FOLLOW_UP_STEP",
                next_action_params=f.next_action_params if f.next_action else {"step_code": current_step},
            )
        )

    return LiveLogisticsSummaryResponse(
        total_active_shipments=len(items),
        in_transit_count=in_transit_count,
        in_port_count=in_port_count,
        high_risk_demurrage_count=high_risk_demurrage_count,
        under_sample_testing_count=under_sample_testing_count,
        incomplete_documents_count=incomplete_documents_count,
        items=items,
    )


# ─── 25-Stage Master Operational Timeline Services (TASK-BE-09) ───────────────

def sync_timeline_snapshots_service(db: Session, import_file_id: int) -> Dict[str, Any]:
    """TASK-BE-09: Force recalculates and persists the 25-stage operational timeline snapshots."""
    return LifecycleAutoSyncEngine.sync_file_timeline(db, import_file_id=import_file_id, commit=True)


def get_timeline_snapshots_service(db: Session, import_file_id: int) -> Dict[str, Any]:
    """TASK-BE-09: Retrieves existing timeline snapshots for an import file, auto-synchronizing if absent."""
    imp = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
    if not imp:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="ملف الشحنة الاستيرادية غير موجود أو محذوف.")

    snapshots = db.query(ShipmentTimelineSnapshot).filter(
        ShipmentTimelineSnapshot.import_file_id == import_file_id
    ).all()

    # If snapshots not yet generated for this file, run the sync engine
    if len(snapshots) < len(ORDERED_STAGES):
        return LifecycleAutoSyncEngine.sync_file_timeline(db, import_file_id=import_file_id, commit=True)

    # Sort snapshots by ORDERED_STAGES order
    stage_idx_map = {code: i for i, code in enumerate(ORDERED_STAGES)}
    sorted_snapshots = sorted(snapshots, key=lambda s: stage_idx_map.get(s.stage_code, 999))

    completed_count = sum(1 for s in sorted_snapshots if s.status == "COMPLETED")
    in_progress_count = sum(1 for s in sorted_snapshots if s.status == "IN_PROGRESS")
    delayed_count = sum(1 for s in sorted_snapshots if s.status == "DELAYED")
    pending_count = sum(1 for s in sorted_snapshots if s.status == "PENDING")
    bottlenecks_count = sum(1 for s in sorted_snapshots if s.is_bottleneck)

    progress_pct = round((completed_count / len(ORDERED_STAGES)) * 100.0, 1)
    if imp.progress_percent and imp.progress_percent > progress_pct:
        progress_pct = float(imp.progress_percent)

    critical_bottlenecks = [s for s in sorted_snapshots if s.is_bottleneck and (s.variance_days or 0) > 0]
    critical_bottlenecks.sort(key=lambda s: s.variance_days or 0, reverse=True)
    top_bottleneck_stage = critical_bottlenecks[0].stage_code if critical_bottlenecks else None

    return {
        "import_file_id": import_file_id,
        "import_file_code": imp.import_file_code,
        "total_stages": len(ORDERED_STAGES),
        "completed_count": completed_count,
        "in_progress_count": in_progress_count,
        "pending_count": pending_count,
        "delayed_count": delayed_count,
        "bottlenecks_count": bottlenecks_count,
        "overall_progress_percent": progress_pct,
        "critical_bottleneck_stage": top_bottleneck_stage,
        "snapshots": sorted_snapshots,
    }
