"""
LifecycleAutoSyncEngine (TASK-BE-09)
Centralized 25-Stage Operational Timeline Synchronization Engine

Maintains, synchronizes, and audits real-time planned vs actual timelines,
SLA variances, bottleneck flags, and domain sub-event linkage in `shipment_timeline_snapshots`.
"""

from datetime import datetime, date, timedelta, timezone
import json
import logging
from typing import Any, Dict, List, Optional, Tuple

from sqlalchemy.orm import Session
from sqlalchemy import desc, or_

from modules.lifecycle_board.model import ShipmentTimelineSnapshot, ShipmentStageActivity
from modules.import_files.model import ImportFile

logger = logging.getLogger(__name__)

ORDERED_STAGES = [
    "STEP_01", "STEP_02", "STEP_03", "STEP_04", "STEP_05",
    "STEP_06", "STEP_07",
    "STEP_08_PO", "STEP_08_BL", "STEP_08_MATCH", "STEP_08_COO", "STEP_08_COC",
    "STEP_09", "STEP_10",
    "STEP_11", "STEP_12", "STEP_13", "STEP_14", "STEP_15",
    "STEP_16", "STEP_17", "STEP_18", "STEP_19", "STEP_20", "STEP_21",
]

STAGE_METADATA = {
    "STEP_01": {
        "phase_id": 1,
        "name_en": "Freight Studies",
        "name_ar": "دراسات ومفاضلة نولون الشحن",
        "sla_days": 3,
    },
    "STEP_02": {
        "phase_id": 1,
        "name_en": "Customs Studies",
        "name_ar": "الدراسات والاستشارات الجمركية",
        "sla_days": 2,
    },
    "STEP_03": {
        "phase_id": 1,
        "name_en": "Import Regulatory Requirements",
        "name_ar": "متطلبات واشتراطات الاستيراد للشحنة",
        "sla_days": 2,
    },
    "STEP_04": {
        "phase_id": 2,
        "name_en": "Finance Approvals & Budget",
        "name_ar": "اعتمادات الميزانية وسداد الموردين",
        "sla_days": 2,
    },
    "STEP_05": {
        "phase_id": 2,
        "name_en": "ACID Operations",
        "name_ar": "الرقم التعريفي المبدئي للشحنة ACID",
        "sla_days": 2,
    },
    "STEP_06": {
        "phase_id": 3,
        "name_en": "Freight Booking",
        "name_ar": "حجز النولون وتأكيد الخط الملاحي",
        "sla_days": 3,
    },
    "STEP_07": {
        "phase_id": 3,
        "name_en": "Freight Allocations",
        "name_ar": "تخصيص وتوزيع الحاويات والبضائع",
        "sla_days": 2,
    },
    "STEP_08_PO": {
        "phase_id": 3,
        "name_en": "PO & Packing Reconciliation",
        "name_ar": "مطابقة الفاتورة وقائمة التعبئة مع أمر الشراء",
        "sla_days": 2,
    },
    "STEP_08_BL": {
        "phase_id": 3,
        "name_en": "Draft B/L Review & Approval",
        "name_ar": "مراجعة واعتماد مسودة بوليصة الشحن",
        "sla_days": 2,
    },
    "STEP_08_MATCH": {
        "phase_id": 3,
        "name_en": "Smart Invoice vs B/L Match",
        "name_ar": "المطابقة الذكية بين الفاتورة والبوليصة",
        "sla_days": 1,
    },
    "STEP_08_COO": {
        "phase_id": 3,
        "name_en": "Draft COO & EUR.1 Review",
        "name_ar": "مسودة شهادة المنشأ و EUR.1",
        "sla_days": 2,
    },
    "STEP_08_COC": {
        "phase_id": 3,
        "name_en": "Draft Inspection Review",
        "name_ar": "شهادات الفحص والتفتيش والمطابقة",
        "sla_days": 2,
    },
    "STEP_09": {
        "phase_id": 3,
        "name_en": "Docs Customs Approval",
        "name_ar": "الاعتماد النهائي للمستندات الجمركية وتعديلات المورد",
        "sla_days": 2,
    },
    "STEP_10": {
        "phase_id": 4,
        "name_en": "CargoX Follow-up / Upload",
        "name_ar": "رفع ومتابعة مستندات CargoX",
        "sla_days": 3,
    },
    "STEP_11": {
        "phase_id": 4,
        "name_en": "Originals Collection",
        "name_ar": "تحصيل واستلام أصول المستندات",
        "sla_days": 5,
    },
    "STEP_12": {
        "phase_id": 4,
        "name_en": "Bank Form 4",
        "name_ar": "استخراج واعتماد نموذج 4 البنكي",
        "sla_days": 5,
    },
    "STEP_13": {
        "phase_id": 5,
        "name_en": "Customs Declaration 46",
        "name_ar": "قيد ومطابقة إقرار 46 ك.م",
        "sla_days": 2,
    },
    "STEP_14": {
        "phase_id": 5,
        "name_en": "Clearance Follow-up",
        "name_ar": "متابعة الكشف والتثمين",
        "sla_days": 3,
    },
    "STEP_15": {
        "phase_id": 5,
        "name_en": "Drawing Samples / Shortage",
        "name_ar": "سحب العينات / محاضر العجز",
        "sla_days": 3,
    },
    "STEP_16": {
        "phase_id": 5,
        "name_en": "Cargo Discrepancy / Damage",
        "name_ar": "محاضر المعاينة والأضرار",
        "sla_days": 2,
    },
    "STEP_17": {
        "phase_id": 5,
        "name_en": "Final Customs Calculation",
        "name_ar": "الحساب والسداد الجمركي النهائي",
        "sla_days": 1,
    },
    "STEP_18": {
        "phase_id": 5,
        "name_en": "Demurrage & Detention",
        "name_ar": "إدارة الغرامات وفترات السماح",
        "sla_days": 2,
    },
    "STEP_19": {
        "phase_id": 6,
        "name_en": "Warehouse Receiving GRN",
        "name_ar": "إذن الإضافة والاستلام المخزني",
        "sla_days": 2,
    },
    "STEP_20": {
        "phase_id": 6,
        "name_en": "Landed Cost Settlement",
        "name_ar": "تسوية التكلفة الاستيرادية الشاملة",
        "sla_days": 3,
    },
    "STEP_21": {
        "phase_id": 6,
        "name_en": "Import File Final Closure",
        "name_ar": "الإغلاق النهائي للملف الاستيرادي",
        "sla_days": 1,
    },
}


def _to_dt(val: Any) -> Optional[datetime]:
    """Gracefully normalize strings, dates, or datetimes to naive UTC datetime."""
    if val is None:
        return None
    if isinstance(val, datetime):
        return val.replace(tzinfo=None) if val.tzinfo else val
    if isinstance(val, date):
        return datetime(val.year, val.month, val.day)
    if isinstance(val, str):
        val = val.strip()
        if not val or val == "-":
            return None
        for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%d"):
            try:
                return datetime.strptime(val.split(".")[0], fmt)
            except ValueError:
                pass
    return None


class LifecycleAutoSyncEngine:
    """
    Centralized synchronization engine that binds domain data across all operational modules
    to the 25-stage master timeline snapshot table (`shipment_timeline_snapshots`).
    """

    @classmethod
    def _resolve_vessel_arrival_anchor(
        cls,
        db: Session,
        import_file_id: int,
        imp: Optional[ImportFile] = None,
        booking: Optional[Any] = None,
        clearance: Optional[Any] = None,
    ) -> Tuple[Optional[datetime], Optional[str], int]:
        """
        Determines the authoritative port/vessel arrival anchor date, source, and delay.
        Hierarchy:
        1. Confirmed Vessel ATA on booking (booking.is_ata_confirmed & booking.ata)
        2. Vessel ATA on booking (booking.ata)
        3. Latest ETA tracking log (ShipmentEtaTrackingLog.confirmed_ata or current_eta)
        4. Booking ETA (booking.eta)
        5. Customs clearance port arrival date (clearance.port_arrival_date)
        6. Import file actual arrival date (imp.actual_arrival_date)
        7. Import file arrival date / required ETA (imp.arrival_date / imp.required_eta)
        """
        if imp is None:
            imp = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
        if booking is None and import_file_id:
            booking = cls._get_model_safe(db, "modules.freight_booking.model", "ShipmentBooking", import_file_id)
        if clearance is None and import_file_id:
            clearance = cls._get_model_safe(db, "modules.customs_clearance.model", "CustomsClearanceRecord", import_file_id)

        # 1 & 2. Booking ATA
        if booking:
            ata = _to_dt(getattr(booking, "ata", None))
            if ata:
                if getattr(booking, "is_ata_confirmed", False):
                    return ata, "booking_ata_confirmed", getattr(booking, "departure_delay_days", 0) or 0
                return ata, "booking_ata", getattr(booking, "departure_delay_days", 0) or 0

        # 3. Latest ETA Tracking Log
        try:
            from modules.freight_booking.model import ShipmentEtaTrackingLog
            bkg_id = getattr(booking, "booking_id", None) if booking else None
            filter_conds = []
            if import_file_id:
                filter_conds.append(ShipmentEtaTrackingLog.import_file_id == import_file_id)
            if bkg_id:
                filter_conds.append(ShipmentEtaTrackingLog.booking_id == bkg_id)

            if filter_conds:
                latest_log = (
                    db.query(ShipmentEtaTrackingLog)
                    .filter(or_(*filter_conds))
                    .order_by(
                        desc(ShipmentEtaTrackingLog.tracking_date),
                        desc(ShipmentEtaTrackingLog.log_id),
                    )
                    .first()
                )
                if latest_log:
                    if getattr(latest_log, "is_ata_confirmed", False) and latest_log.confirmed_ata:
                        return _to_dt(latest_log.confirmed_ata), "tracking_log_ata_confirmed", latest_log.delay_days or 0
                    if latest_log.current_eta:
                        return _to_dt(latest_log.current_eta), "tracking_log_current_eta", latest_log.delay_days or 0
        except Exception as e:
            logger.debug("Failed querying tracking logs for file %s: %s", import_file_id, e)

        # 4. Booking ETA, pushed by the departure delay (BE45: a late ATD moves the planned ETA)
        if booking and getattr(booking, "eta", None):
            eta = _to_dt(booking.eta)
            if eta:
                delay = getattr(booking, "departure_delay_days", 0) or 0
                return eta + timedelta(days=delay), "booking_eta", delay

        # 5. Clearance Port Arrival Date
        if clearance and getattr(clearance, "port_arrival_date", None):
            arr = _to_dt(clearance.port_arrival_date)
            if arr:
                return arr, "clearance_port_arrival_date", 0

        # 6. Import File Actual Arrival Date
        if getattr(imp, "actual_arrival_date", None):
            arr = _to_dt(imp.actual_arrival_date)
            if arr:
                return arr, "imp_actual_arrival_date", 0

        # 7. Import File Arrival Date / Required ETA
        arr = _to_dt(getattr(imp, "arrival_date", None)) or _to_dt(getattr(imp, "required_eta", None))
        if arr:
            return arr, "imp_required_eta", 0

        return None, None, 0

    @classmethod
    def calculate_predicted_warehouse_eta(
        cls,
        db: Session,
        import_file_id: int,
        imp: Optional[ImportFile] = None,
        booking: Optional[Any] = None,
        clearance: Optional[Any] = None,
    ) -> Optional[Dict[str, Any]]:
        """
        Predicts warehouse arrival date using:
        1. Vessel arrival port anchor date (ATA or latest tracking ETA)
        2. Historical customs clearance duration from similar shipments (ExperienceGuideRepository)
        3. Inland transport transit days (booking.expected_warehouse_days or standard 2 days)
        Formula:
            predicted_date = port_anchor + timedelta(days=round(avg_clearance_days + inland_days))
        """
        if imp is None:
            imp = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
        if not imp:
            return None

        if booking is None:
            booking = cls._get_model_safe(db, "modules.freight_booking.model", "ShipmentBooking", import_file_id)
        if clearance is None:
            clearance = cls._get_model_safe(db, "modules.customs_clearance.model", "CustomsClearanceRecord", import_file_id)

        anchor_dt, anchor_source, delay_days = cls._resolve_vessel_arrival_anchor(
            db, import_file_id, imp, booking, clearance
        )
        if not anchor_dt:
            return None

        # Determine historical clearance duration from similar shipments
        similar_shipments: List[Dict[str, Any]] = []
        durations: List[float] = []

        try:
            from modules.experience_guide.repository import ExperienceGuideRepository
            repo = ExperienceGuideRepository(db)
            similar_shipments = repo.find_similar_shipments(import_file_id=import_file_id, limit=5)

            for sim in similar_shipments:
                sim_file_id = sim.get("import_file_id")
                # 1. Try empirical clearance duration from CustomsClearanceRecord
                if sim_file_id:
                    sim_clr = cls._get_model_safe(
                        db, "modules.customs_clearance.model", "CustomsClearanceRecord", sim_file_id
                    )
                    if sim_clr and getattr(sim_clr, "port_arrival_date", None):
                        rel_dt = getattr(sim_clr, "release_date", None) or getattr(sim_clr, "port_gate_out_date", None)
                        if rel_dt:
                            arr_dt = _to_dt(sim_clr.port_arrival_date)
                            r_dt = _to_dt(rel_dt)
                            if arr_dt and r_dt and r_dt >= arr_dt:
                                diff = (r_dt.date() - arr_dt.date()).days
                                if 1 <= diff <= 30:
                                    durations.append(float(diff))
                                    continue

                # 2. Fall back to similar shipment's calculated clearance days if valid
                sim_days = sim.get("clearance_duration_days")
                if sim_days is not None and 1 <= sim_days <= 20:
                    durations.append(float(sim_days))
        except Exception as e:
            logger.debug("Failed querying similar shipments for file %s: %s", import_file_id, e)

        if durations:
            avg_clearance_days = round(sum(durations) / len(durations), 1)
        else:
            # Standard Egyptian customs clearance duration benchmark (5 days)
            avg_clearance_days = 5.0

        # Inland transport transit days (standard 2 days or derived from booking)
        inland_days = 2
        if booking and getattr(booking, "expected_warehouse_days", None):
            wh_days = booking.expected_warehouse_days
            if wh_days > avg_clearance_days:
                inland_days = int(round(wh_days - avg_clearance_days))
            else:
                inland_days = max(1, int(wh_days))

        total_offset_days = max(1, int(round(avg_clearance_days + inland_days)))
        predicted_date = anchor_dt + timedelta(days=total_offset_days)

        # Update booking if present
        if booking and hasattr(booking, "expected_warehouse_arrival_date"):
            booking.expected_warehouse_arrival_date = predicted_date
            try:
                db.flush()
            except Exception:
                pass

        return {
            "predicted_date": predicted_date,
            "port_anchor_date": anchor_dt,
            "anchor_source": anchor_source,
            "historical_clearance_avg_days": avg_clearance_days,
            "inland_transport_days": inland_days,
            "total_offset_days": total_offset_days,
            "similar_shipments_count": len(durations) if durations else len(similar_shipments),
            "calculation_breakdown": (
                f"Port Anchor ({anchor_source}: {anchor_dt.strftime('%Y-%m-%d')}) + "
                f"Historical Clearance ({avg_clearance_days}d) + Inland Transport ({inland_days}d) = "
                f"{total_offset_days} days -> Predicted Warehouse Arrival: {predicted_date.strftime('%Y-%m-%d')}"
            ),
        }

    @classmethod
    def sync_file_timeline(
        cls,
        db: Session,
        import_file_id: int,
        commit: bool = True,
    ) -> Dict[str, Any]:
        """
        Calculates and upserts all 25 timeline stage snapshots for the given import file.
        Detects variances against planned dates and benchmarks SLA performance with
        SLA Cascade roll-forward and Predicted Warehouse ETA forecasting.
        """
        imp: Optional[ImportFile] = db.query(ImportFile).filter(
            ImportFile.import_file_id == import_file_id
        ).first()
        if not imp:
            raise ValueError(f"ImportFile with ID {import_file_id} not found.")

        # 1. Fetch domain-specific models safely
        clearance = cls._get_model_safe(db, "modules.customs_clearance.model", "CustomsClearanceRecord", import_file_id)
        booking = cls._get_model_safe(db, "modules.freight_booking.model", "ShipmentBooking", import_file_id)
        bdoc = cls._get_model_safe(db, "modules.import_documentation.model", "BankingDocumentSession", import_file_id)
        warehouse = cls._get_model_safe(db, "modules.warehouse_receiving.model", "WarehouseReceivingRecord", import_file_id)
        settlement = cls._get_model_safe(db, "modules.financial_settlement.model", "FinancialSettlementRecord", import_file_id)
        closure = cls._get_model_safe(db, "modules.file_closure.model", "FileClosureRecord", import_file_id)

        # 2. Resolve port/vessel arrival anchor & predicted warehouse ETA
        vessel_anchor_dt, vessel_anchor_source, vessel_delay_days = cls._resolve_vessel_arrival_anchor(
            db, import_file_id, imp, booking, clearance
        )
        pred_warehouse = cls.calculate_predicted_warehouse_eta(
            db, import_file_id, imp, booking, clearance
        )

        # 3. Fetch existing stage activities
        activities = db.query(ShipmentStageActivity).filter(
            ShipmentStageActivity.import_file_code == imp.import_file_code
        ).all()
        act_map: Dict[str, ShipmentStageActivity] = {a.step_code: a for a in activities}

        # 4. Fetch existing snapshots for this file
        existing_snapshots = db.query(ShipmentTimelineSnapshot).filter(
            ShipmentTimelineSnapshot.import_file_id == import_file_id
        ).all()
        snap_map: Dict[str, ShipmentTimelineSnapshot] = {s.stage_code: s for s in existing_snapshots}

        now_utc = datetime.now(timezone.utc).replace(tzinfo=None)
        today = now_utc.date()

        # Seed initial base date for sequential planned timeline
        base_date = _to_dt(getattr(imp, "contract_date", None)) or _to_dt(getattr(imp, "file_opening_date", None)) or _to_dt(getattr(imp, "created_at", None)) or now_utc
        running_planned_date = base_date

        completed_count = 0
        in_progress_count = 0
        pending_count = 0
        delayed_count = 0
        bottlenecks_count = 0
        updated_snapshots: List[ShipmentTimelineSnapshot] = []

        for stage_code in ORDERED_STAGES:
            meta = STAGE_METADATA.get(stage_code, {})
            sla_days = meta.get("sla_days", 1)
            phase_number = meta.get("phase_id", 1)
            name_en = meta.get("name_en", stage_code)
            name_ar = meta.get("name_ar", stage_code)

            act = act_map.get(stage_code)
            snap = snap_map.get(stage_code)

            # Operational phase anchors
            if stage_code == "STEP_13" and vessel_anchor_dt:
                # Customs clearance anchor: cannot start before port arrival
                if running_planned_date < vessel_anchor_dt:
                    running_planned_date = vessel_anchor_dt

            elif stage_code == "STEP_19" and pred_warehouse and pred_warehouse.get("predicted_date"):
                # Warehouse receiving anchor: aligns with predicted warehouse arrival date
                if running_planned_date < pred_warehouse["predicted_date"]:
                    running_planned_date = pred_warehouse["predicted_date"]

            # Resolve status, dates, and event details
            status_val, actual_dt, domain_planned_dt, event_details, completed_by = cls._resolve_stage_details(
                stage_code=stage_code,
                imp=imp,
                act=act,
                clearance=clearance,
                booking=booking,
                bdoc=bdoc,
                warehouse=warehouse,
                settlement=settlement,
                closure=closure,
                running_planned_date=running_planned_date,
            )

            # Preserve or establish baseline planned date
            existing_baseline = None
            if snap and snap.event_details_json and isinstance(snap.event_details_json, dict):
                existing_baseline = snap.event_details_json.get("baseline_planned_date")

            if existing_baseline:
                baseline_planned_dt = _to_dt(existing_baseline) or domain_planned_dt or running_planned_date
            else:
                baseline_planned_dt = domain_planned_dt or running_planned_date

            # Calculate cascaded planned date
            if status_val == "COMPLETED":
                # Completed stage locks its planned date to baseline
                planned_dt = snap.planned_date if (snap and snap.planned_date) else baseline_planned_dt
                cascade_delay_days = 0
            else:
                # Open stage cascades forward if predecessor delays pushed running_planned_date
                effective_planned_dt = max(baseline_planned_dt, running_planned_date)
                cascade_delay_days = max(0, (effective_planned_dt.date() - baseline_planned_dt.date()).days)
                planned_dt = effective_planned_dt

            # Audit metadata in event_details
            event_details["baseline_planned_date"] = str(baseline_planned_dt.date()) if baseline_planned_dt else None
            event_details["cascade_delay_days"] = cascade_delay_days

            if stage_code == "STEP_13" and vessel_anchor_dt:
                event_details["vessel_arrival_anchor"] = str(vessel_anchor_dt.date())
                event_details["vessel_anchor_source"] = vessel_anchor_source
                event_details["vessel_delay_days"] = vessel_delay_days

            if stage_code == "STEP_19" and pred_warehouse:
                event_details["predicted_warehouse_arrival_date"] = str(pred_warehouse["predicted_date"].date())
                event_details["port_anchor_date"] = str(pred_warehouse["port_anchor_date"].date())
                event_details["anchor_source"] = pred_warehouse["anchor_source"]
                event_details["historical_clearance_avg_days"] = pred_warehouse["historical_clearance_avg_days"]
                event_details["inland_transport_days"] = pred_warehouse["inland_transport_days"]
                event_details["similar_shipments_count"] = pred_warehouse["similar_shipments_count"]
                event_details["calculation_breakdown"] = pred_warehouse["calculation_breakdown"]

            # Variance and bottleneck calculation
            variance_days = 0
            is_bottleneck = False
            delay_reason = None

            if actual_dt:
                variance_days = (actual_dt.date() - planned_dt.date()).days
                if variance_days > 0:
                    is_bottleneck = True
                    delay_reason = f"تأخر الإنجاز بمقدار {variance_days} يوم عن التاريخ المخطط"
                # Advance running planned date for subsequent stages using cascade formula:
                # running_planned_date = max(current_planned, actual_dt) + timedelta(days=sla_days)
                running_planned_date = max(planned_dt, actual_dt) + timedelta(days=sla_days)
            else:
                # Still open
                if today > planned_dt.date():
                    days_overdue = (today - planned_dt.date()).days
                    variance_days = days_overdue
                    if days_overdue >= sla_days:
                        status_val = "DELAYED"
                        is_bottleneck = True
                        delay_reason = f"تجاوز المهلة المحددة (SLA: {sla_days} يوم) بمقدار {days_overdue} يوم والخطوة معلقة"
                    else:
                        delay_reason = f"تجاوز التاريخ المخطط بـ {days_overdue} يوم (ضمن هامش SLA)"
                elif cascade_delay_days > 0:
                    delay_reason = f"تم ترحيل الموعد المخطط تعاقبياً بمقدار {cascade_delay_days} يوم بسبب تأخر مراحل سابقة"

                running_planned_date = planned_dt + timedelta(days=sla_days)

            # Status KPI counts
            if status_val == "COMPLETED":
                completed_count += 1
            elif status_val == "IN_PROGRESS":
                in_progress_count += 1
            elif status_val == "DELAYED":
                delayed_count += 1
            else:
                pending_count += 1

            if is_bottleneck:
                bottlenecks_count += 1

            # Upsert snapshot
            if not snap:
                snap = ShipmentTimelineSnapshot(
                    import_file_id=import_file_id,
                    stage_code=stage_code,
                    stage_name_ar=name_ar,
                    stage_name_en=name_en,
                    phase_number=phase_number,
                    status=status_val,
                    planned_date=planned_dt,
                    actual_date=actual_dt,
                    variance_days=variance_days,
                    sla_days=sla_days,
                    is_bottleneck=is_bottleneck,
                    delay_reason=delay_reason,
                    event_details_json=event_details,
                    completed_by=completed_by,
                )
                db.add(snap)
            else:
                snap.stage_name_ar = name_ar
                snap.stage_name_en = name_en
                snap.phase_number = phase_number
                snap.status = status_val
                snap.planned_date = planned_dt
                snap.actual_date = actual_dt
                snap.variance_days = variance_days
                snap.sla_days = sla_days
                snap.is_bottleneck = is_bottleneck
                snap.delay_reason = delay_reason
                snap.event_details_json = event_details
                if completed_by:
                    snap.completed_by = completed_by

            updated_snapshots.append(snap)

        if commit:
            db.commit()
            for s in updated_snapshots:
                db.refresh(s)
        else:
            db.flush()

        progress_pct = round((completed_count / len(ORDERED_STAGES)) * 100.0, 1)
        if imp.progress_percent and imp.progress_percent > progress_pct:
            progress_pct = float(imp.progress_percent)

        critical_bottlenecks = [
            s for s in updated_snapshots if s.is_bottleneck and (s.variance_days or 0) > 0
        ]
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
            "vessel_arrival_anchor": {
                "anchor_date": vessel_anchor_dt,
                "anchor_source": vessel_anchor_source,
                "delay_days": vessel_delay_days,
            } if vessel_anchor_dt else None,
            "predicted_warehouse_eta": pred_warehouse,
            "snapshots": updated_snapshots,
        }

    @classmethod
    def _resolve_stage_details(
        cls,
        stage_code: str,
        imp: ImportFile,
        act: Optional[ShipmentStageActivity],
        clearance: Any,
        booking: Any,
        bdoc: Any,
        warehouse: Any,
        settlement: Any,
        closure: Any,
        running_planned_date: datetime,
    ) -> Tuple[str, Optional[datetime], Optional[datetime], Dict[str, Any], Optional[str]]:
        """Determines operational status, dates, and domain event snapshot details."""
        status_val = "PENDING"
        actual_dt: Optional[datetime] = None
        planned_dt: Optional[datetime] = None
        details: Dict[str, Any] = {}
        completed_by: Optional[str] = None

        if act:
            if act.status == "Completed":
                status_val = "COMPLETED"
                actual_dt = _to_dt(act.completed_at)
                completed_by = act.assigned_user or "Operations"
            elif act.status in ("In-Progress", "In Progress"):
                status_val = "IN_PROGRESS"
            elif act.status == "Skipped":
                status_val = "SKIPPED"

        # Domain-specific enrichment per stage
        if stage_code == "STEP_01":
            planned_dt = _to_dt(getattr(imp, "contract_date", None)) or _to_dt(getattr(imp, "file_opening_date", None)) or _to_dt(getattr(imp, "created_at", None))
            details = {"scenario": imp.selected_scenario or "Direct", "incoterm": imp.incoterm_code}
            if imp.selected_scenario and status_val != "COMPLETED":
                status_val = "COMPLETED"
                actual_dt = actual_dt or planned_dt

        elif stage_code == "STEP_02":
            details = {"hs_code": imp.hs_code, "category": imp.product_category}

        elif stage_code == "STEP_03":
            details = {"shipment_category": imp.shipment_category}

        elif stage_code == "STEP_04":
            details = {"estimated_cost": imp.estimated_cost, "currency": imp.estimated_cost_currency}

        elif stage_code == "STEP_05":
            planned_dt = _to_dt(imp.acid_request_date) or running_planned_date
            details = {
                "acid_number": imp.acid_number,
                "acid_expiry_date": str(imp.acid_expiry_date or ""),
            }
            if imp.acid_number:
                status_val = "COMPLETED"
                actual_dt = _to_dt(imp.acid_issue_date) or actual_dt or planned_dt

        elif stage_code == "STEP_06":
            planned_dt = _to_dt(getattr(imp, "departure_date", None)) or (_to_dt(getattr(booking, "etd", None)) if booking else None) or running_planned_date
            details = {
                "booking_no": getattr(imp, "booking_no", None) or (getattr(booking, "booking_code", None) if booking else None),
                "vessel_name": getattr(imp, "vessel_name", None) or (getattr(booking, "vessel_name", None) if booking else None),
                "etd": str(getattr(booking, "etd", "") if booking else ""),
                "eta": str(getattr(booking, "eta", "") if booking else ""),
            }
            if getattr(imp, "booking_no", None) or (booking and getattr(booking, "is_confirmed", False)):
                status_val = "COMPLETED"
                actual_dt = _to_dt(getattr(booking, "booking_date", None)) if booking else actual_dt or planned_dt

        elif stage_code == "STEP_07":
            details = {"container_count": getattr(imp, "invoices_count", 1)}

        elif stage_code == "STEP_08_PO":
            details = {"po_number": imp.po_number, "pi_number": imp.pi_number}

        elif stage_code == "STEP_08_BL":
            details = {"bl_number": imp.bl_number}
            if imp.bl_number and status_val == "PENDING":
                status_val = "COMPLETED"
                actual_dt = actual_dt or running_planned_date

        elif stage_code == "STEP_08_MATCH":
            details = {"bl_number": imp.bl_number, "po_number": imp.po_number}

        elif stage_code == "STEP_08_COO":
            details = {"country_of_origin": getattr(imp, "pickup_address", None)}

        elif stage_code == "STEP_08_COC":
            details = {"regulatory_inspection": "Standard"}

        elif stage_code == "STEP_09":
            details = {"approval_status": "Final Approved" if status_val == "COMPLETED" else "Pending Review"}

        elif stage_code == "STEP_10":
            planned_dt = _to_dt(getattr(imp, "actual_departure_date", None)) or running_planned_date
            details = {
                "cargox_envelope_id": imp.cargox_envelope_id,
                "cargox_status": imp.cargox_envelope_status,
                "transferred_at": str(imp.cargox_transferred_at or ""),
            }
            if imp.cargox_transferred_at or imp.cargox_envelope_id:
                status_val = "COMPLETED"
                actual_dt = _to_dt(imp.cargox_transferred_at) or actual_dt or planned_dt

        elif stage_code == "STEP_11":
            details = {
                "courier_no": imp.original_documents_courier_no,
                "status": imp.original_documents_status,
                "received_at": str(imp.original_documents_received_at or ""),
            }
            if imp.original_documents_received_at:
                status_val = "COMPLETED"
                actual_dt = _to_dt(imp.original_documents_received_at) or actual_dt

        elif stage_code == "STEP_12":
            planned_dt = _to_dt(imp.form4_request_date) or running_planned_date
            tariff_dt = getattr(clearance, "tariff_coding_date", None) if clearance else None
            bank_link_dt = getattr(clearance, "bank_link_accepted_date", None) if clearance else None
            details = {
                "form4_no": imp.form4_no,
                "swift_no": imp.swift_no,
                "tariff_coding_date": str(tariff_dt or ""),
                "bank_link_accepted_date": str(bank_link_dt or ""),
            }
            if imp.form4_no or imp.form4_received_date:
                status_val = "COMPLETED"
                actual_dt = _to_dt(imp.form4_received_date) or actual_dt or planned_dt
            elif tariff_dt or bank_link_dt or imp.form4_request_date:
                status_val = "IN_PROGRESS"

        elif stage_code == "STEP_13":
            dec_no = (getattr(clearance, "declaration_46_no", None) if clearance else None) or imp.form46_no
            dec_dt = (getattr(clearance, "declaration_46_date", None) if clearance else None) or _to_dt(imp.form46_date)
            planned_dt = dec_dt or _to_dt(getattr(imp, "actual_arrival_date", None)) or running_planned_date
            details = {
                "declaration_46_no": dec_no,
                "channel_type": getattr(clearance, "channel_type", None) if clearance else None,
                "customs_office": getattr(clearance, "customs_office_name", None) if clearance else None,
            }
            if dec_no:
                status_val = "COMPLETED"
                actual_dt = dec_dt or actual_dt or planned_dt

        elif stage_code == "STEP_14":
            details = {
                "inspector_name": getattr(clearance, "inspector_name", None) if clearance else None,
                "inspection_yard": getattr(clearance, "inspection_yard", None) if clearance else None,
            }
            if clearance and getattr(clearance, "inspection_date", None):
                status_val = "COMPLETED"
                actual_dt = _to_dt(clearance.inspection_date) or actual_dt

        elif stage_code == "STEP_15":
            details = {
                "is_sample_drawn": getattr(clearance, "is_sample_drawn", True) if clearance else True,
                "goeic_cert": getattr(clearance, "goeic_certificate_no", None) if clearance else None,
                "sample_status": getattr(clearance, "sample_test_status", "None") if clearance else "None",
            }
            if clearance and getattr(clearance, "sampling_date", None):
                actual_dt = _to_dt(clearance.sampling_date) or actual_dt

        elif stage_code == "STEP_16":
            details = {
                "inspection_result": getattr(clearance, "inspection_result", "Conforming") if clearance else "Conforming",
            }

        elif stage_code == "STEP_17":
            planned_dt = (
                _to_dt(getattr(clearance, "duty_payment_requested_date", None))
                if clearance else None
            ) or (_to_dt(getattr(clearance, "nafeza_claim_date", None)) if clearance else None) or running_planned_date
            details = {
                "claim_no": getattr(clearance, "nafeza_claim_number", None) if clearance else None,
                "duty_paid_amount": getattr(clearance, "duty_paid_amount", 0.0) if clearance else 0.0,
                "sadad_no": getattr(clearance, "sadad_number", None) if clearance else None,
                "receipt_no": getattr(clearance, "bank_receipt_no", None) if clearance else None,
                "payment_status": getattr(clearance, "payment_status", "Unpaid") if clearance else "Unpaid",
            }
            if clearance and getattr(clearance, "payment_date", None):
                status_val = "COMPLETED"
                actual_dt = _to_dt(clearance.payment_date) or actual_dt or planned_dt
            elif clearance and getattr(clearance, "payment_status", None) == "Paid & Verified":
                status_val = "COMPLETED"
                actual_dt = actual_dt or planned_dt

        elif stage_code == "STEP_18":
            details = {
                "free_days": getattr(clearance, "free_days_allowed", 14) if clearance else 14,
                "gate_out_date": str(getattr(clearance, "port_gate_out_date", "") if clearance else ""),
            }
            if clearance and getattr(clearance, "port_gate_out_date", None):
                status_val = "COMPLETED"
                actual_dt = _to_dt(clearance.port_gate_out_date) or actual_dt

        elif stage_code == "STEP_19":
            details = {
                "grn_number": getattr(warehouse, "grn_number", None) if warehouse else None,
                "received_status": getattr(warehouse, "status", None) if warehouse else None,
            }
            if warehouse and getattr(warehouse, "receiving_date", None):
                status_val = "COMPLETED"
                actual_dt = _to_dt(warehouse.receiving_date) or actual_dt

        elif stage_code == "STEP_20":
            details = {
                "settlement_code": getattr(settlement, "settlement_code", None) if settlement else None,
                "final_landed_cost": getattr(settlement, "actual_landed_cost_total_egp", 0.0) if settlement else 0.0,
            }
            if settlement and getattr(settlement, "is_locked", False):
                status_val = "COMPLETED"
                actual_dt = _to_dt(getattr(settlement, "settlement_date", None)) or actual_dt

        elif stage_code == "STEP_21":
            details = {
                "closure_code": getattr(closure, "closure_code", None) if closure else None,
                "archive_status": imp.status,
            }
            if (closure and getattr(closure, "is_closed", False)) or imp.status in ("Closed", "Archived"):
                status_val = "COMPLETED"
                actual_dt = _to_dt(getattr(closure, "closed_at", None)) or _to_dt(imp.dossier_exported_at) or actual_dt or running_planned_date

        return status_val, actual_dt, planned_dt, details, completed_by

    @classmethod
    def _get_model_safe(cls, db: Session, mod_path: str, cls_name: str, file_id: int) -> Optional[Any]:
        """Safely queries an optional related model for an import file without circular dependencies."""
        try:
            import importlib
            mod = importlib.import_module(mod_path)
            model_cls = getattr(mod, cls_name, None)
            if model_cls and hasattr(model_cls, "import_file_id"):
                query = db.query(model_cls).filter(model_cls.import_file_id == file_id)
                if hasattr(model_cls, "is_active"):
                    query = query.filter(model_cls.is_active == True)
                return query.first()
        except Exception as e:
            logger.debug("Failed querying optional model %s.%s: %s", mod_path, cls_name, e)
        return None
