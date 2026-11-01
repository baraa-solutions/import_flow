"""
Shipment Lifecycle Kanban Sub-Service
Handles shipment board queries, Kanban phase grouping, and KPI metric aggregations.
"""

from datetime import date, datetime
import logging
from typing import Any, Dict, List, Optional, Tuple
from sqlalchemy.orm import Session

import modules.lifecycle_board.repository as repo
from modules.lifecycle_board.schemas import (
    LifecycleBoardSummaryResponse,
    PhaseSummary,
    ShipmentStageCard,
    ShipmentKpiMetrics,
)

logger = logging.getLogger(__name__)

PHASES_DEFINITION = [
    {
        "phase_id": 1,
        "title_en": "1. Pre-Planning & Studies",
        "title_ar": "المرحلة الأولى: التخطيط والدراسات المسبقة",
        "color_hex": "#D97706",
        "step_codes": ["STEP_01", "STEP_02", "STEP_03"],
        "step_names": {
            "STEP_01": ("Freight Studies", "دراسات ومفاضلة نولون الشحن"),
            "STEP_02": ("Customs Studies", "الدراسات والاستشارات الجمركية"),
            "STEP_03": ("Import Regulatory Requirements", "متطلبات واشتراطات الاستيراد للشحنة"),
        },
    },
    {
        "phase_id": 2,
        "title_en": "2. Shipment Initiation",
        "title_ar": "المرحلة الثانية: بداية الشحنة",
        "color_hex": "#3498DB",
        "step_codes": ["STEP_04", "STEP_05"],
        "step_names": {
            "STEP_04": ("Finance Approvals & Budget", "اعتمادات الميزانية وسداد الموردين"),
            "STEP_05": ("ACID Operations", "الرقم التعريفي المبدئي للشحنة ACID"),
        },
    },
    {
        "phase_id": 3,
        "title_en": "3. Booking & Doc Prep",
        "title_ar": "المرحلة الثالثة: حجز الشحن والتدقيق المستندي المبدئي",
        "color_hex": "#16A085",
        "step_codes": [
            "STEP_06",
            "STEP_07",
            "STEP_08_PO",
            "STEP_08_BL",
            "STEP_08_MATCH",
            "STEP_08_COO",
            "STEP_08_COC",
            "STEP_09",
        ],
        "step_names": {
            "STEP_06": ("Freight Booking", "حجز النولون وتأكيد الخط الملاحي"),
            "STEP_07": ("Freight Allocations", "تخصيص وتوزيع الحاويات والبضائع"),
            "STEP_08_PO": ("PO & Packing Reconciliation", "مطابقة الفاتورة وقائمة التعبئة مع أمر الشراء"),
            "STEP_08_BL": ("Draft B/L Review & Approval", "مراجعة واعتماد مسودة بوليصة الشحن"),
            "STEP_08_MATCH": ("Smart Invoice vs B/L Match", "المطابقة الذكية بين الفاتورة والبوليصة"),
            "STEP_08_COO": ("Draft COO & EUR.1 Review", "مسودة شهادة المنشأ و EUR.1"),
            "STEP_08_COC": ("Draft Inspection Review", "شهادات الفحص والتفتيش والمطابقة"),
            "STEP_09": ("Docs Customs Approval", "الاعتماد النهائي للمستندات الجمركية وتعديلات المورد"),
        },
    },
    {
        "phase_id": 4,
        "title_en": "4. Digital & Banking",
        "title_ar": "المرحلة الرابعة: التوثيق الرقمي والاعتماد البنكي",
        "color_hex": "#C0392B",
        "step_codes": ["STEP_10", "STEP_11", "STEP_12"],
        "step_names": {
            "STEP_10": ("CargoX Follow-up / Upload", "رفع ومتابعة مستندات CargoX"),
            "STEP_11": ("Originals Collection", "تحصيل واستلام أصول المستندات"),
            "STEP_12": ("Bank Form 4", "استخراج واعتماد نموذج 4 البنكي"),
        },
    },
    {
        "phase_id": 5,
        "title_en": "5. Port Operations & Clearance",
        "title_ar": "المرحلة الخامسة: عمليات الميناء والتخليص الجمركي",
        "color_hex": "#8E44AD",
        "step_codes": ["STEP_13", "STEP_14", "STEP_15", "STEP_16", "STEP_17", "STEP_18"],
        "step_names": {
            "STEP_13": ("Customs Declaration 46", "قيد ومطابقة إقرار 46 ك.م"),
            "STEP_14": ("Clearance Follow-up", "متابعة الكشف والتثمين"),
            "STEP_15": ("Drawing Samples / Shortage", "سحب العينات / محاضر العجز"),
            "STEP_16": ("Cargo Discrepancy / Damage", "محاضر المعاينة والأضرار"),
            "STEP_17": ("Final Customs Calculation", "الحساب والسداد الجمركي النهائي"),
            "STEP_18": ("Demurrage & Detention", "إدارة الغرامات وفترات السماح"),
        },
    },
    {
        "phase_id": 6,
        "title_en": "6. Inbound & Final Closure",
        "title_ar": "المرحلة السادسة: الاستلام المخزني والتسوية المالية",
        "color_hex": "#27AE60",
        "step_codes": ["STEP_19", "STEP_20", "STEP_21"],
        "step_names": {
            "STEP_19": ("Warehouse Receiving GRN", "إذن الإضافة والاستلام المخزني"),
            "STEP_20": ("Landed Cost Settlement", "تسوية التكلفة الاستيرادية الشاملة"),
            "STEP_21": ("Import File Final Closure", "الإغلاق النهائي للملف الاستيرادي"),
        },
    },
]

ORDERED_STEP_CODES = [
    "STEP_01", "STEP_02", "STEP_03", "STEP_04", "STEP_05",
    "STEP_06", "STEP_07",
    "STEP_08_PO", "STEP_08_BL", "STEP_08_MATCH", "STEP_08_COO", "STEP_08_COC",
    "STEP_09", "STEP_10",
    "STEP_11", "STEP_12", "STEP_13", "STEP_14", "STEP_15",
    "STEP_16", "STEP_17", "STEP_18", "STEP_19", "STEP_20", "STEP_21"
]

STEP_TO_PHASE_MAP: Dict[str, int] = {}
STEP_NAME_MAP: Dict[str, Tuple[str, str]] = {}
for p in PHASES_DEFINITION:
    for code, names in p["step_names"].items():
        STEP_TO_PHASE_MAP[code] = p["phase_id"]
        STEP_NAME_MAP[code] = names

# Legacy fallback for STEP_08
STEP_TO_PHASE_MAP["STEP_08"] = 3
STEP_NAME_MAP["STEP_08"] = ("Draft Docs Review", "مراجعة وتدقيق مسودات الشحن")


def get_step_neighbors(step_code: str) -> Tuple[Optional[str], Optional[str]]:
    """Returns (prev_code, next_code) based on standard sequential workflow."""
    if step_code == "STEP_08":
        return "STEP_07", "STEP_08_PO"
    if step_code not in ORDERED_STEP_CODES:
        return None, None
    idx = ORDERED_STEP_CODES.index(step_code)
    prev_code = ORDERED_STEP_CODES[idx - 1] if idx > 0 else None
    next_code = ORDERED_STEP_CODES[idx + 1] if idx < len(ORDERED_STEP_CODES) - 1 else None
    return prev_code, next_code


def _parse_datetime_safe(val: Any) -> Optional[datetime]:
    """Gracefully normalize strings, dates, or datetimes to naive UTC datetime."""
    if not val:
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
                continue
    return None


def get_board_summary_service(db: Session) -> LifecycleBoardSummaryResponse:
    from datetime import date
    from modules.demurrage_detention.model import DemurrageTracking
    from modules.lifecycle_board.model import ShipmentTimelineSnapshot, ShipmentStageActivity
    from modules.lifecycle_board.sync_engine import ORDERED_STAGES, STAGE_METADATA

    today = date.today()

    # 1. Fetch active shipments with details
    records = repo.get_active_shipments_with_details(db)
    all_shipment_cards: List[ShipmentStageCard] = []
    unique_files = set()

    file_codes = list({f.import_file_code for _, f in records if f and getattr(f, "import_file_code", None)})
    file_ids = [f.import_file_id for _, f in records if f and isinstance(getattr(f, "import_file_id", None), int)]

    # Batch fetch all activities for active files to eliminate N+1 roundtrips
    all_activities_map = repo.get_all_activities_for_files(db, file_codes)

    # Batch fetch demurrage tracking records
    demurrage_records = repo.get_demurrage_trackings_for_files(db, file_ids, file_codes)
    dem_by_file_id = {d.import_file_id: d for d in demurrage_records if d.import_file_id}
    dem_by_file_code = {d.import_file_code: d for d in demurrage_records if d.import_file_code}

    # Batch fetch timeline snapshots
    snapshots = repo.get_timeline_snapshots_for_files(db, file_ids)
    snaps_by_file_id: Dict[int, Dict[str, ShipmentTimelineSnapshot]] = {}
    for s in snapshots:
        snaps_by_file_id.setdefault(s.import_file_id, {})[s.stage_code] = s

    # 2. Build shipment stage cards and compute the 4 KPIs
    for act, file_rec in records:
        f_code = getattr(file_rec, "import_file_code", "")
        f_id = getattr(file_rec, "import_file_id", None)
        if not isinstance(f_id, int):
            f_id = None
        unique_files.add(f_code)
        names = STEP_NAME_MAP.get(act.step_code, (act.step_code, act.step_code))

        # Activities for this file
        file_acts = all_activities_map.get(f_code, [])

        # Step neighbors
        prev_code, next_code = get_step_neighbors(act.step_code)
        completed_acts = [a for a in file_acts if a.status == "Completed"]
        if completed_acts:
            latest_comp = completed_acts[-1]
            if latest_comp.step_code != act.step_code:
                prev_code = latest_comp.step_code

        prev_names = STEP_NAME_MAP.get(prev_code, (prev_code, prev_code)) if prev_code else (None, None)
        next_names = STEP_NAME_MAP.get(next_code, (next_code, next_code)) if next_code else (None, None)

        # Categorize step codes for this shipment
        completed_step_codes = {a.step_code for a in file_acts if a.status == "Completed"}
        skipped_step_codes = [
            c for c in ORDERED_STEP_CODES
            if any(a.step_code == c and (a.status in ["Skipped", "Exempted"] or getattr(a, "completion_type", None) == "skipped") for a in file_acts)
        ]
        in_progress_step_codes = {a.step_code for a in file_acts if a.status == "In-Progress"}

        # Legacy step 08 compatibility
        if "STEP_08" in completed_step_codes:
            completed_step_codes.update(["STEP_08_PO", "STEP_08_BL", "STEP_08_MATCH", "STEP_08_COO", "STEP_08_COC"])
        if any(a.step_code == "STEP_08" and (a.status in ["Skipped", "Exempted"] or getattr(a, "completion_type", None) == "skipped") for a in file_acts):
            for c in ["STEP_08_PO", "STEP_08_BL", "STEP_08_MATCH", "STEP_08_COO", "STEP_08_COC"]:
                if c not in skipped_step_codes:
                    skipped_step_codes.append(c)

        skipped_set = set(skipped_step_codes)
        pending_step_codes = [
            c for c in ORDERED_STEP_CODES
            if c not in completed_step_codes and c not in skipped_set and c not in in_progress_step_codes
        ]

        # Explicit pending activities
        explicit_pending_codes = {
            a.step_code for a in file_acts
            if a.status in ["Pending", "pending", "PENDING", "Pending Documentation"]
        }
        for ep in explicit_pending_codes:
            if ep in ORDERED_STEP_CODES and ep not in pending_step_codes:
                pending_step_codes.append(ep)

        # --- 4 KPIs Calculation ---
        # KPI 1: Health Score: (Completed + Skipped/Exempted) / 25 * 100
        total_done = len(completed_step_codes) + len(skipped_set)
        health_score_pct = round(min(100.0, max(0.0, (total_done / 25.0) * 100.0)), 1)

        # KPI 2: Free Time Burn: demurrage_trackings or discharge date & free days compared to today
        dem = (dem_by_file_id.get(f_id) if f_id else None) or dem_by_file_code.get(f_code)
        raw_target_free = getattr(file_rec, "target_free_days", None)
        free_days_total = raw_target_free if isinstance(raw_target_free, int) else None
        if free_days_total is None and dem and getattr(dem, "policy", None):
            pol_free = getattr(dem.policy, "demurrage_free_days", None)
            if isinstance(pol_free, int):
                free_days_total = pol_free
        if free_days_total is None:
            free_days_total = 21

        free_days_remaining: Optional[int] = None
        free_time_burn_pct: float = 0.0
        used_free_days = 0

        acc_dem_fx = (getattr(dem, "total_demurrage_fx", 0.0) or 0.0) + (getattr(dem, "total_detention_fx", 0.0) or 0.0) if dem else 0.0

        if dem and getattr(dem, "discharge_date", None):
            days_since_disc = (today - dem.discharge_date).days
            used_free_days = max(0, days_since_disc)
            free_days_remaining = max(0, free_days_total - used_free_days)
            if free_days_total > 0:
                free_time_burn_pct = round(min(100.0, max(0.0, (used_free_days / float(free_days_total)) * 100.0)), 1)
            if acc_dem_fx > 0:
                free_time_burn_pct = 100.0
                free_days_remaining = 0
        elif isinstance(getattr(file_rec, "required_eta", None), (date, datetime)):
            eta_val = file_rec.required_eta.date() if isinstance(file_rec.required_eta, datetime) else file_rec.required_eta
            delta_eta = (eta_val - today).days
            if delta_eta < 0 and not getattr(file_rec, "is_customs_released", False):
                used_free_days = abs(delta_eta)
                free_days_remaining = max(0, free_days_total - used_free_days)
                if free_days_total > 0:
                    free_time_burn_pct = round(min(100.0, max(0.0, (used_free_days / float(free_days_total)) * 100.0)), 1)
            else:
                free_days_remaining = free_days_total
                free_time_burn_pct = 0.0
        else:
            free_days_remaining = free_days_total
            free_time_burn_pct = 0.0

        # KPI 3: Cost Variance: actual_landed_cost_variance_pct in import_files
        raw_variance = getattr(file_rec, "actual_landed_cost_variance_pct", None)
        cost_variance_pct: Optional[float] = None
        if isinstance(raw_variance, (int, float)):
            cost_variance_pct = round(float(raw_variance), 2)

        # KPI 4: Overdue Steps Count & Risk Level
        overdue_steps_count = 0
        file_snaps = snaps_by_file_id.get(f_id, {}) if f_id else {}
        if file_snaps:
            for s in file_snaps.values():
                if s.status == "DELAYED" or (s.variance_days is not None and s.variance_days >= s.sla_days and s.status != "COMPLETED"):
                    overdue_steps_count += 1
        else:
            for a in file_acts:
                if a.status == "In-Progress" and a.started_at:
                    s_dt = _parse_datetime_safe(a.started_at)
                    if s_dt:
                        sla = STAGE_METADATA.get(a.step_code, {}).get("sla_days", 2)
                        if (today - s_dt.date()).days > sla:
                            overdue_steps_count += 1

        # Exact Worst-of Risk Level determination per KPI Master Contract
        # 1. Critical triggers: Free Time Burn > 75% (or <= 3d left / demurrage incurred),
        #    Cost Variance > +5.0%, or Overdue Steps >= 2
        is_critical = (
            (free_days_remaining is not None and free_days_remaining <= 3)
            or free_time_burn_pct > 75.0
            or overdue_steps_count >= 2
            or (cost_variance_pct is not None and cost_variance_pct > 5.0)
            or acc_dem_fx > 0
        )

        # 2. Warning triggers: Free Time Burn > 50% (51-75% / 4-6d left),
        #    Cost Variance > +3.0% (+3.1% to +5.0%), or Overdue Steps >= 1
        is_warning = (
            (free_days_remaining is not None and free_days_remaining <= 6)
            or free_time_burn_pct > 50.0
            or overdue_steps_count >= 1
            or (cost_variance_pct is not None and cost_variance_pct > 3.0)
        )

        if is_critical:
            risk_level = "CRITICAL"
        elif is_warning:
            risk_level = "WARNING"
        else:
            risk_level = "SAFE"

        kpi_metrics = ShipmentKpiMetrics(
            health_score_pct=health_score_pct,
            free_time_burn_pct=free_time_burn_pct,
            free_days_remaining=free_days_remaining,
            overdue_steps_count=overdue_steps_count,
            cost_variance_pct=cost_variance_pct,
            risk_level=risk_level,
        )

        all_shipment_cards.append(
            ShipmentStageCard(
                import_file_code=f_code,
                company_name=file_rec.company_name or "N/A",
                supplier_name=file_rec.supplier_name or "N/A",
                po_number=file_rec.po_number,
                shipment_mode=file_rec.shipment_mode,
                incoterm_code=file_rec.incoterm_code,
                priority=file_rec.priority,
                estimated_cost=file_rec.estimated_cost,
                estimated_cost_currency=file_rec.estimated_cost_currency,
                step_code=act.step_code,
                step_name_en=names[0],
                step_name_ar=names[1],
                previous_step_code=prev_code,
                previous_step_name_en=prev_names[0],
                previous_step_name_ar=prev_names[1],
                next_step_code=next_code,
                next_step_name_en=next_names[0],
                next_step_name_ar=next_names[1],
                status=act.status,
                started_at=act.started_at,
                notes=act.notes,
                msg_code=act.msg_code,
                msg_params=act.msg_params,
                completion_type=getattr(act, "completion_type", None),
                kpi_metrics=kpi_metrics,
                pending_step_codes=pending_step_codes,
                skipped_step_codes=skipped_step_codes,
            )
        )

    # 3. Query all activities for phase counts (In-Progress, Pending, Delayed per phase)
    stage_activities_db = (
        db.query(ShipmentStageActivity)
        .filter(ShipmentStageActivity.status.in_(["In-Progress", "Pending", "pending", "PENDING", "Pending Documentation"]))
        .all()
    )

    phases_res: List[PhaseSummary] = []
    for p in PHASES_DEFINITION:
        p_steps = set(p["step_codes"])
        
        # Step counts for In-Progress
        step_counts = {c: sum(1 for a in stage_activities_db if a.step_code == c and a.status == "In-Progress") for c in p["step_codes"]}
        
        # Total active shipments in this phase
        active_in_phase = {a.import_file_code for a in stage_activities_db if a.step_code in p_steps and a.status == "In-Progress"}
        total_p = len(active_in_phase)

        # Pending shipments count:
        # 1) Activities explicitly marked Pending in DB for steps in this phase
        explicit_pending_in_phase = {
            a.import_file_code for a in stage_activities_db
            if a.step_code in p_steps and a.status in ["Pending", "pending", "PENDING", "Pending Documentation"]
        }
        # 2) Active shipments on the board that have pending steps in this phase
        pipeline_pending_in_phase = {
            card.import_file_code for card in all_shipment_cards
            if card.step_code in p_steps and any(s in p_steps for s in card.pending_step_codes)
        }
        pending_in_phase = explicit_pending_in_phase | pipeline_pending_in_phase

        # Delayed shipments count past SLA for this phase
        delayed_in_phase = set()
        for card in all_shipment_cards:
            if card.step_code in p_steps:
                # Check if card itself is delayed past SLA
                if card.started_at:
                    s_dt = _parse_datetime_safe(card.started_at)
                    if s_dt:
                        sla = STAGE_METADATA.get(card.step_code, {}).get("sla_days", 2)
                        if (today - s_dt.date()).days > sla:
                            delayed_in_phase.add(card.import_file_code)
                # Or check timeline snapshots for this file in this phase
                if card.kpi_metrics and card.kpi_metrics.overdue_steps_count > 0:
                    delayed_in_phase.add(card.import_file_code)

        # Check DB activities for overdue in this phase
        for a in stage_activities_db:
            if a.step_code in p_steps and a.status == "In-Progress" and a.started_at:
                s_dt = _parse_datetime_safe(a.started_at)
                if s_dt:
                    sla = STAGE_METADATA.get(a.step_code, {}).get("sla_days", 2)
                    if (today - s_dt.date()).days > sla:
                        delayed_in_phase.add(a.import_file_code)

        phases_res.append(
            PhaseSummary(
                phase_id=p["phase_id"],
                title_en=p["title_en"],
                title_ar=p["title_ar"],
                color_hex=p["color_hex"],
                step_codes=p["step_codes"],
                total_active_shipments=total_p,
                step_counts=step_counts,
                pending_shipments_count=len(pending_in_phase),
                delayed_shipments_count=len(delayed_in_phase),
            )
        )

    return LifecycleBoardSummaryResponse(
        phases=phases_res,
        total_active_files=len(unique_files),
        all_shipments=all_shipment_cards,
    )


# Function alias
get_lifecycle_board_summary = get_board_summary_service
