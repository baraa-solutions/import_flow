from fastapi import HTTPException
from datetime import datetime, timezone, timedelta
from typing import Optional, Dict, Any, List
from sqlalchemy.orm import Session

# Record status ladder (legacy labels). Users may set the first group by hand; the others come from the
# dual approval and CargoX workflow endpoints and are never downgraded by a PUT.
STATUS_CARGO_READY = "Cargo Ready"
STATUS_LOADED = "Loaded & Sealed"
STATUS_DUAL_APPROVED = "Dual Approved"
STATUS_DOCS_DISPATCHED = "Docs Dispatched"
STATUS_CARGOX_DONE = "CargoX Transfer Completed"
STATUS_COMPLETED = "Completed"
STATUS_LADDER = (STATUS_CARGO_READY, STATUS_LOADED, STATUS_DUAL_APPROVED, STATUS_DOCS_DISPATCHED, STATUS_CARGOX_DONE, STATUS_COMPLETED)
MANUAL_STATUSES = frozenset({STATUS_CARGO_READY, STATUS_LOADED, STATUS_DOCS_DISPATCHED})

# CargoX envelope stages: each target stage requires the previous one.
ENVELOPE_PREVIOUS_STAGE = {
    "Ready for Upload": "Checklist Passed",
    "Uploaded": "Ready for Upload",
    "Completed": "Uploaded",
}
# Keys of cargox_exchange_data owned by the server (checklist run / stage advance), never taken from a client.
SERVER_MANAGED_CARGOX_KEYS = ("verification_checklist", "envelope_status", "blockchain_tx_hash", "envelope_id")
MANUAL_CHECK_REQUIRED = "MANUAL_CHECK_REQUIRED"
MANUALLY_CONFIRMED = "MANUALLY_CONFIRMED"

RECORD_LABEL_AR = "سجل شحن وتجهيز البضاعة"


def _status_rank(value: Optional[str]) -> int:
    return STATUS_LADDER.index(value) if value in STATUS_LADDER else -1


def resolve_manual_status(requested: Optional[str], current: Optional[str]) -> Optional[str]:
    """The status a create / PUT may store, or ``None`` to keep the current one (silently, the field is
    optional): only manual statuses, and never a downgrade below a workflow status."""
    if not requested or requested not in MANUAL_STATUSES:
        return None
    if current in MANUAL_STATUSES or current is None or _status_rank(requested) > _status_rank(current):
        return requested
    return None


def parse_iso_datetime(val: Any, field_name: Optional[str] = None) -> Optional[datetime]:
    """Parses YYYY-MM-DD / ISO strings. With ``field_name`` (request input) a non-empty value that cannot be
    parsed is a 422; without it (stored data) it is read as ``None``."""
    if not val:
        return None
    if isinstance(val, datetime):
        return val if val.tzinfo else val.replace(tzinfo=timezone.utc)
    if isinstance(val, str):
        val = val.strip()
        if not val:
            return None
        try:
            # Handle YYYY-MM-DD
            if len(val) == 10:
                dt = datetime.strptime(val, "%Y-%m-%d")
                return dt.replace(tzinfo=timezone.utc)
            # Handle ISO format
            dt = datetime.fromisoformat(val.replace("Z", "+00:00"))
            return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)
        except ValueError:
            if field_name:
                raise HTTPException(status_code=422, detail=f"صيغة التاريخ غير صحيحة: {field_name}")
            return None
    if field_name:
        raise HTTPException(status_code=422, detail=f"صيغة التاريخ غير صحيحة: {field_name}")
    return None

def validate_crd_against_cutoff(crd_date: datetime, cargo_cutoff_date: datetime) -> bool:
    """
    BP-020: Validates Cargo Readiness Date (CRD) against Cargo Cut-off date.
    Returns True if valid (CRD <= Cutoff), False if CRD exceeds Cutoff date.
    """
    if crd_date and cargo_cutoff_date:
        if crd_date > cargo_cutoff_date:
            return False
    return True

def validate_dual_approval_sequence(level1_status: str, level2_status: str):
    """
    BP-022: Level 2 Approval (Management Review) cannot occur before Level 1 (Operational Review) is Approved.
    """
    if level2_status == "Approved" and level1_status != "Approved":
        raise HTTPException(
            status_code=400,
            detail="لا يمكن تنفيذ الاعتماد النهائي (Level 2 Approval) قبل إتمام واجتياز اعتماد مراجعة التشغيل (Level 1 Approval) بنجاح."
        )

def validate_cargox_ready_for_upload(checklist: list):
    """
    BP-024: Stage 3 Upload Preparation requires 100% pass on all CargoX verification rules.
    """
    if not checklist:
        raise HTTPException(
            status_code=400,
            detail="قائمة مراجعة التبادل الإلكتروني CargoX فارغة. يجب تنفيذ فحص القواعد أولاً."
        )
    
    unpassed = [rule for rule in checklist if not rule.get("passed", False)]
    if unpassed:
        failed_names = ", ".join([r.get("rule_name", "قاعدة غير معروفة") for r in unpassed])
        raise HTTPException(
            status_code=400,
            detail=f"لا يمكن تجهيز المظروف للرفع على CargoX حتى تجتاز جميع بنود الفحص بنسبة 100%. البنود المعلقة: {failed_names}"
        )

def validate_container_tracking_timestamps(
    container_assignment_date: Optional[str] = None,
    arrival_at_supplier_at: Optional[str] = None,
    loading_start_at: Optional[str] = None,
    loading_end_at: Optional[str] = None,
    port_gate_in_at: Optional[str] = None,
    field_names: tuple = ("container_assignment_date", "arrival_at_supplier_at", "loading_start_at", "loading_end_at", "port_gate_in_at"),
):
    """
    Section 5: Strict Sequential Timestamp Validation for Container Loading Follow-up
    1. arrival_at_supplier_at >= container_assignment_date
    2. loading_start_at >= arrival_at_supplier_at
    3. loading_end_at >= loading_start_at
    4. port_gate_in_at >= loading_end_at
    5. No subsequent date can be prior to container_assignment_date
    """
    dt_assign = parse_iso_datetime(container_assignment_date, field_names[0])
    dt_arrival = parse_iso_datetime(arrival_at_supplier_at, field_names[1])
    dt_start = parse_iso_datetime(loading_start_at, field_names[2])
    dt_end = parse_iso_datetime(loading_end_at, field_names[3])
    dt_gate_in = parse_iso_datetime(port_gate_in_at, field_names[4])

    if dt_assign:
        if dt_arrival and dt_arrival < dt_assign:
            raise HTTPException(
                status_code=400,
                detail="تاريخ ووقت وصول الحاوية لدى المورد/المخزن لا يمكن أن يكون قبل تاريخ ووقت تخصيص الحاوية (Container Assignment Date & Time)."
            )
        if dt_start and dt_start < dt_assign:
            raise HTTPException(
                status_code=400,
                detail="تاريخ ووقت بداية التحميل لا يمكن أن يكون قبل تاريخ ووقت تخصيص الحاوية."
            )
        if dt_end and dt_end < dt_assign:
            raise HTTPException(
                status_code=400,
                detail="تاريخ ووقت نهاية التحميل لا يمكن أن يكون قبل تاريخ ووقت تخصيص الحاوية."
            )
        if dt_gate_in and dt_gate_in < dt_assign:
            raise HTTPException(
                status_code=400,
                detail="تاريخ ووقت دخول الحاوية للميناء لا يمكن أن يكون قبل تاريخ ووقت تخصيص الحاوية."
            )

    if dt_arrival:
        if dt_start and dt_start < dt_arrival:
            raise HTTPException(
                status_code=400,
                detail="تاريخ ووقت بداية التحميل لا يمكن أن يكون قبل تاريخ ووقت وصول الحاوية لدى المورد/المخزن."
            )

    if dt_start:
        if dt_end and dt_end < dt_start:
            raise HTTPException(
                status_code=400,
                detail="تاريخ ووقت نهاية التحميل لا يمكن أن يكون قبل تاريخ ووقت بداية التحميل."
            )

    if dt_end:
        if dt_gate_in and dt_gate_in < dt_end:
            raise HTTPException(
                status_code=400,
                detail="تاريخ ووقت دخول الحاوية للميناء لا يمكن أن يكون قبل تاريخ ووقت إتمام التحميل."
            )

def calculate_container_sla_and_status(item_dict: Dict[str, Any], sla_hours: int = 48) -> Dict[str, Any]:
    """
    Section 4 & 5: Automatically computes SLA deadline, SLA breach flag, and status workflow.
    Status transitions:
    1) PENDING_ASSIGNMENT
    2) ASSIGNED
    3) ARRIVED_AT_SUPPLIER
    4) LOADING_IN_PROGRESS
    5) LOADING_COMPLETED
    6) GATED_IN_AT_PORT
    """
    updated = dict(item_dict)

    assign_val = updated.get("container_assignment_date") or updated.get("consolidation_scheduled_date")
    arrival_val = updated.get("arrival_at_supplier_at") or updated.get("arrival_at_cfs_at")
    start_val = updated.get("loading_start_at") or updated.get("stuffing_start_at")
    end_val = updated.get("loading_end_at") or updated.get("stuffing_end_at")
    gate_in_val = updated.get("port_gate_in_at")

    dt_assign = parse_iso_datetime(assign_val)
    dt_arrival = parse_iso_datetime(arrival_val)
    dt_start = parse_iso_datetime(start_val)
    dt_end = parse_iso_datetime(end_val)
    dt_gate_in = parse_iso_datetime(gate_in_val)

    # Calculate SLA Deadline
    if dt_assign:
        dt_deadline = dt_assign + timedelta(hours=sla_hours)
        updated["sla_deadline_at"] = dt_deadline.isoformat()
    else:
        dt_deadline = None

    # Calculate SLA Breach
    now = datetime.now(timezone.utc)
    is_breached = False
    if dt_deadline:
        if dt_gate_in:
            if dt_gate_in > dt_deadline:
                is_breached = True
        else:
            if now > dt_deadline:
                is_breached = True
    updated["is_sla_breached"] = is_breached

    # Auto Status Transition
    if dt_gate_in:
        status = "GATED_IN_AT_PORT"
    elif dt_end:
        status = "LOADING_COMPLETED"
    elif dt_start:
        status = "LOADING_IN_PROGRESS"
    elif dt_arrival:
        status = "ARRIVED_AT_SUPPLIER"
    elif dt_assign:
        status = "ASSIGNED"
    else:
        status = "PENDING_ASSIGNMENT"

    updated["tracking_status"] = status
    return updated

def validate_container_reuse_conflict(
    db: Session,
    containers_loading_data: List[Any],
    current_record_id: Optional[int] = None,
):
    """
    Validates that no container number is reused within a 15-day window from its assignment date
    unless there is a different seal number.
    """
    from .model import CargoShippingRecord
    
    query = db.query(CargoShippingRecord).filter(CargoShippingRecord.is_active == True)
    if current_record_id:
        query = query.filter(CargoShippingRecord.cargo_shipping_id != current_record_id)
    records = query.all()

    for c in containers_loading_data:
        c_dict = c if isinstance(c, dict) else (c.model_dump() if hasattr(c, "model_dump") else dict(c))
        c_no = (c_dict.get("container_no") or "").strip().upper()
        s_no = (c_dict.get("seal_no") or "").strip().upper()
        c_date_raw = c_dict.get("container_assignment_date")
        c_date = parse_iso_datetime(c_date_raw, "container_assignment_date")

        if not c_no or not c_date:
            continue

        for rec in records:
            rec_containers = rec.containers_loading_data or []
            for existing_c in rec_containers:
                ex_no = (existing_c.get("container_no") or "").strip().upper()
                ex_seal = (existing_c.get("seal_no") or "").strip().upper()
                ex_date_raw = existing_c.get("container_assignment_date")
                ex_date = parse_iso_datetime(ex_date_raw)

                if ex_no == c_no and ex_date:
                    diff_days = abs((c_date.date() - ex_date.date()).days)
                    if diff_days <= 15 and ex_seal == s_no:
                        raise HTTPException(
                            status_code=400,
                            detail=f"لا يمكن استخدام نفس رقم الحاوية ({c_no}) ونفس رقم السيل ({s_no}) في محيط زمني 15 يوماً (الفرق: {diff_days} يوم) من تاريخ التخصيص السابق ({str(ex_date.date())}) المسجل بالشحنة ({rec.cargo_shipping_code}). يرجى التحقق من رقم الحاوية أو إدخال رقم سيل مختلف في حال تدوير واستخدام نفس الحاوية."
                        )


def validate_level1_allowed(dual_approval_status: Optional[str], status_value: Optional[str]) -> None:
    """Level 1 cannot be resubmitted once the documents are dual approved (or the record went further)."""
    if dual_approval_status == STATUS_DUAL_APPROVED or _status_rank(status_value) >= _status_rank(STATUS_DUAL_APPROVED):
        raise HTTPException(
            status_code=409,
            detail="لا يمكن إعادة تقديم اعتماد المستوى الأول بعد إتمام الاعتماد المزدوج للمستندات.",
        )


def validate_level2_allowed(dual_approval_status: Optional[str], status_value: Optional[str]) -> None:
    if dual_approval_status == STATUS_DUAL_APPROVED or _status_rank(status_value) >= _status_rank(STATUS_DUAL_APPROVED):
        raise HTTPException(
            status_code=409,
            detail="تم إتمام الاعتماد المزدوج لهذه المستندات بالفعل.",
        )


def validate_envelope_stage_order(current_stage: Optional[str], target_stage: str) -> None:
    required = ENVELOPE_PREVIOUS_STAGE[target_stage]
    if current_stage != required:
        raise HTTPException(
            status_code=409,
            detail=f"لا يمكن نقل مظروف CargoX إلى مرحلة {target_stage} قبل مرحلة {required} (المرحلة الحالية: {current_stage or 'غير محددة'}).",
        )


# Envelope stages after the checklist: re-running it would rewrite a verified (or uploaded) envelope.
ENVELOPE_STAGES_AFTER_CHECKLIST = frozenset({"Ready for Upload", "Uploaded", "Completed"})
# Workflow statuses that make a record part of the approved / transferred trail: never soft-deleted.
UNDELETABLE_STATUSES = frozenset({STATUS_DUAL_APPROVED, STATUS_CARGOX_DONE, STATUS_COMPLETED})


def validate_checklist_rerun_allowed(envelope_status: Optional[str], record_code: str) -> None:
    if envelope_status in ENVELOPE_STAGES_AFTER_CHECKLIST:
        raise HTTPException(
            status_code=409,
            detail=f"لا يمكن إعادة فحص قائمة CargoX للسجل {record_code} بعد وصول المظروف لمرحلة {envelope_status}.",
        )


def validate_deletable(record_status: Optional[str], record_code: str) -> None:
    if record_status in UNDELETABLE_STATUSES:
        raise HTTPException(
            status_code=409,
            detail=f"لا يمكن حذف سجل الشحن {record_code} وهو في حالة {record_status}.",
        )


def validate_documents_editable(status: Optional[str], code: str) -> None:
    """BP-022: Locking rule - containers, seals, and weights cannot be modified once documents reach or pass Dual Approved."""
    if status == STATUS_DUAL_APPROVED or _status_rank(status) >= _status_rank(STATUS_DUAL_APPROVED):
        raise HTTPException(
            status_code=409,
            detail=f"لا يمكن تعديل بيانات الحاويات أو السيل أو أوزان الشحنة للسجل {code} بعد اعتماد المستندات (الحالة: {status}).",
        )


def validate_booking_link(db: Session, booking_id: Optional[int], import_file_id: int) -> None:
    """BP-020: Validates that a linked freight booking exists, is active, and belongs to the same import file."""
    if booking_id is None:
        return
    from modules.freight_booking.model import ShipmentBooking
    booking = db.query(ShipmentBooking).filter(ShipmentBooking.booking_id == booking_id).first()
    if not booking or not booking.is_active or booking.import_file_id != import_file_id:
        raise HTTPException(
            status_code=422,
            detail="الحجز لا يخص نفس ملف الاستيراد",
        )


def containers_or_seals_changed(
    existing: Optional[List[Any]],
    incoming: Optional[List[Any]],
) -> bool:
    """Returns True if container numbers, seal numbers, or weights differ between existing and incoming lists."""
    ex_list = existing or []
    in_list = incoming or []
    if len(ex_list) != len(in_list):
        return True

    def _extract(item: Any) -> Dict[str, Any]:
        if hasattr(item, "model_dump"):
            return item.model_dump()
        if isinstance(item, dict):
            return item
        return dict(item)

    ex_items = [_extract(x) for x in ex_list]
    in_items = [_extract(x) for x in in_list]

    ex_map = {(c.get("container_no") or "").strip().upper(): c for c in ex_items}
    in_map = {(c.get("container_no") or "").strip().upper(): c for c in in_items}

    if len(ex_map) != len(ex_items) or len(in_map) != len(in_items):
        for ex, nw in zip(ex_items, in_items):
            if (ex.get("container_no") or "").strip().upper() != (nw.get("container_no") or "").strip().upper():
                return True
            if (ex.get("seal_no") or "").strip() != (nw.get("seal_no") or "").strip():
                return True
            for w_key in ("tare_weight_kg", "net_weight_kg", "gross_weight_kg"):
                if abs(float(ex.get(w_key) or 0.0) - float(nw.get(w_key) or 0.0)) > 1e-4:
                    return True
        return False

    if set(ex_map.keys()) != set(in_map.keys()):
        return True

    for c_no, ex in ex_map.items():
        nw = in_map[c_no]
        ex_seal = (ex.get("seal_no") or "").strip()
        nw_seal = (nw.get("seal_no") or "").strip()
        if ex_seal != nw_seal:
            return True
        for w_key in ("tare_weight_kg", "net_weight_kg", "gross_weight_kg"):
            if abs(float(ex.get(w_key) or 0.0) - float(nw.get(w_key) or 0.0)) > 1e-4:
                return True

    return False


