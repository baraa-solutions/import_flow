"""
File closure business rules.

``evaluate_closure_gate`` is the ONE rule used by both the closure precheck and the final close (plan FC-01 / FC-03):
it decides from server-side facts only. Client checklist flags are stored for the record and never gate.
"""
from dataclasses import dataclass, field
from typing import Any, Dict, Iterable, List, Optional

from fastapi import HTTPException

# Mapping of checklist keys to stage step codes: a skipped (exempt) step satisfies the checklist item.
CHECKLIST_STAGE_MAPPING = {
    "docs_verified": ["STEP_08", "STEP_09", "docs_verified"],
    "customs_cleared": ["STEP_13", "STEP_14", "STEP_17", "customs_cleared"],
    "warehouse_received": ["STEP_19", "warehouse_received"],
    "landed_cost_settled": ["STEP_20", "landed_cost_settled"],
    "dossier_exported": ["STEP_20", "dossier_exported"],
    "empty_containers_returned": ["STEP_19", "empty_containers_returned"],
    "tasks_closed": ["STEP_21", "tasks_closed"],
}

SETTLED_SETTLEMENT_STATUSES = ("Calculated", "Approved", "Closed")
SETTLED_FILE_FIN_STATUSES = ("SETTLED", "COST_ALLOCATED")
PENDING_CONTAINER_RETURN_STATUSES = ("PARTIALLY_RETURNED", "PENDING_RETURN")
NO_CONTAINER_MODES = ("AIR", "LAND", "TRUCK")

CLOSURE_STATUS_DRAFT = "Draft"
CLOSURE_STATUS_CLOSED = "Closed"
FILE_STATUS_CLOSED = "Closed"

BLOCKING_MESSAGES_AR = {
    "customs_cleared": "لم يتم استخراج الإفراج الجمركي النهائي للرسالة (Customs Final Release Permit).",
    "warehouse_received": "لم يتم تسجيل استلام الشحنة بالمخزن وإصدار إذن إضافة (Warehouse GRN).",
    "warehouse_quarantine": "إذن الاستلام المخزني ما زال تحت قفل التحفظ / الحجر (Quarantine Lock) ولا يمكن إغلاق الملف قبل فكه.",
    "landed_cost_settled": "لم يتم احتساب واعتماد تسوية التكلفة الاستيرادية الشاملة (Actual Landed Cost Settled).",
    "dossier_exported": "لم يتم تصدير واعتماد الملف الشامل للرسالة (Comprehensive Shipment Dossier Export - CLO-03).",
    "already_closed": "ملف الشحنة مغلق رسمياً بالفعل ولا يمكن إعادة إغلاقه.",
}
WARNING_CONTAINERS_AR = "يوجد حاويات لم يتم تسجيل إيصال تسليمها الفارغ (EIR Return) — يرجى التأكد لتجنب غرامات التأخير."
WARNING_DOCS_AR = "مستندات الشحن الأصلية غير مكتملة أو لم يتم التحقق منها بالكامل."


def coded_error(status_code: int, code: str, message_ar: str, **params: Any) -> HTTPException:
    """Error with a language-neutral code (codes listed in docs/plans/review-shared-needs.md, not yet registered in
    system_messages): ``detail = {code, message, **params}``."""
    return HTTPException(status_code=status_code, detail={"code": code, "message": message_ar, **params})


def is_skipped(key: str, skipped: Iterable[str]) -> bool:
    skipped_set = set(skipped or [])
    return any(step in skipped_set for step in CHECKLIST_STAGE_MAPPING.get(key, [key]))


def open_tasks_warning_ar(count: int) -> str:
    # FC-11: final close completes only the closure tasks; other open tasks stay open.
    return (
        f"يوجد عدد {count} مهام تشغيلية لم تكتمل بعد. الإغلاق النهائي يُكمل مهام الإغلاق فقط "
        "ولن يغلق هذه المهام تلقائياً."
    )


@dataclass
class ClosureFacts:
    """Server-side facts the closure gate decides on (loaded by the service, no DB access here)."""
    skipped_stages: List[str] = field(default_factory=list)
    # customs
    has_final_release_clearance: bool = False
    is_customs_released: bool = False
    customs_release_permit_no: Optional[str] = None
    customs_released_at: Any = None
    # warehouse
    active_grn_count: int = 0
    locked_grn_count: int = 0
    # landed cost
    has_settled_settlement: bool = False
    actual_landed_cost_egp: float = 0.0
    financial_settlement_status: Optional[str] = None
    # dossier
    dossier_exported_at: Any = None
    # containers (warning only)
    shipment_mode: Optional[str] = None
    empty_containers_return_status: Optional[str] = None
    empty_containers_returned_at: Any = None
    empty_containers_eir_numbers: Optional[str] = None
    # documents (warning only)
    acid_number: Optional[str] = None
    form46_no: Optional[str] = None
    form4_no: Optional[str] = None
    cargox_envelope_id: Any = None
    # tasks (warning only)
    open_operational_task_count: int = 0


@dataclass
class ClosureGate:
    checklist: Dict[str, bool]
    blocking_keys: List[str]
    blocking_reasons: List[str]
    warnings: List[str]

    @property
    def can_close(self) -> bool:
        return not self.blocking_keys


def evaluate_closure_gate(facts: ClosureFacts) -> ClosureGate:
    skipped = facts.skipped_stages or []
    checklist: Dict[str, bool] = {}
    blocking: List[str] = []
    warnings: List[str] = []

    # 1. Customs: final release status, the file's release flag, permit or release date (Q2), or an exempt step.
    customs_ok = bool(
        facts.has_final_release_clearance
        or facts.is_customs_released
        or facts.customs_release_permit_no
        or facts.customs_released_at
    ) or is_skipped("customs_cleared", skipped)
    checklist["customs_cleared"] = customs_ok
    if not customs_ok:
        blocking.append("customs_cleared")

    # 2. Warehouse: an active GRN that is not under quarantine lock (Q2: a locked GRN blocks).
    if is_skipped("warehouse_received", skipped):
        warehouse_ok = True
    elif facts.active_grn_count == 0:
        warehouse_ok = False
        blocking.append("warehouse_received")
    elif facts.locked_grn_count > 0:
        warehouse_ok = False
        blocking.append("warehouse_quarantine")
    else:
        warehouse_ok = True
    checklist["warehouse_received"] = warehouse_ok

    # 3. Landed cost settlement (Calculated / Approved / Closed, or the file's settled cost).
    landed_ok = bool(
        facts.has_settled_settlement
        or (facts.actual_landed_cost_egp or 0.0) > 0
        or (facts.financial_settlement_status or "") in SETTLED_FILE_FIN_STATUSES
    ) or is_skipped("landed_cost_settled", skipped)
    checklist["landed_cost_settled"] = landed_ok
    if not landed_ok:
        blocking.append("landed_cost_settled")

    # 4. Comprehensive dossier export (CLO-03).
    dossier_ok = facts.dossier_exported_at is not None or is_skipped("dossier_exported", skipped)
    checklist["dossier_exported"] = dossier_ok
    if not dossier_ok:
        blocking.append("dossier_exported")

    # 5. Empty containers returned (warning only, Q2).
    containers_ok = True
    if (facts.shipment_mode or "SEA").upper() not in NO_CONTAINER_MODES:
        returned = bool(
            facts.empty_containers_returned_at
            or facts.empty_containers_eir_numbers
            or facts.empty_containers_return_status == "ALL_RETURNED"
        )
        pending = facts.empty_containers_return_status in PENDING_CONTAINER_RETURN_STATUSES
        containers_ok = returned or not pending
        if not containers_ok:
            warnings.append(WARNING_CONTAINERS_AR)
    checklist["empty_containers_returned"] = containers_ok

    # 6. Documentation (warning only).
    docs_ok = bool(facts.acid_number or facts.form46_no or facts.form4_no or facts.cargox_envelope_id)
    checklist["docs_verified"] = docs_ok
    if not docs_ok:
        warnings.append(WARNING_DOCS_AR)

    # 7. Open operational tasks (warning only).
    checklist["tasks_closed"] = facts.open_operational_task_count == 0
    if facts.open_operational_task_count > 0:
        warnings.append(open_tasks_warning_ar(facts.open_operational_task_count))

    return ClosureGate(
        checklist=checklist,
        blocking_keys=blocking,
        blocking_reasons=[BLOCKING_MESSAGES_AR[k] for k in blocking],
        warnings=warnings,
    )


def closure_blocked_error(gate: ClosureGate) -> HTTPException:
    return coded_error(
        400,
        "FC_CLOSURE_BLOCKED",
        "لا يمكن إغلاق الملف نهائياً — المتطلبات التالية غير مستوفاة:\n" + "\n".join(f"• {r}" for r in gate.blocking_reasons),
        blocking=list(gate.blocking_keys),
    )


def export_blocking_keys(gate: ClosureGate) -> List[str]:
    return [k for k in gate.blocking_keys if k != "dossier_exported"]


def export_blocked_error(gate: ClosureGate) -> HTTPException:
    keys = export_blocking_keys(gate)
    reasons = [BLOCKING_MESSAGES_AR[k] for k in keys if k in BLOCKING_MESSAGES_AR]
    return coded_error(
        400,
        "FC_EXPORT_BLOCKED",
        "لا يمكن تصدير واعتماد الملف الشامل — المتطلبات التالية غير مستوفاة:\n" + "\n".join(f"• {r}" for r in reasons),
        blocking=keys,
    )


def already_closed_error(import_file_code: Optional[str]) -> HTTPException:
    return coded_error(
        409,
        "FC_ALREADY_CLOSED",
        f"ملف الشحنة {import_file_code or ''} مغلق نهائياً بالفعل. يلزم إعادة فتحه أولاً.",
        import_file_code=import_file_code or "",
    )


def validate_update_status(status: Optional[str]) -> None:
    if status is not None and status != CLOSURE_STATUS_DRAFT:
        raise coded_error(
            400,
            "FC_STATUS_INVALID",
            "لا يمكن تعديل حالة سجل الإغلاق إلا إلى مسودة (Draft). الإغلاق النهائي يتم من شاشة الإغلاق الرسمي.",
            status=status,
        )


def closed_record_locked_error(closure_code: str) -> HTTPException:
    return coded_error(
        409,
        "FC_CLOSED_RECORD_LOCKED",
        f"سجل الإغلاق {closure_code} لملف مغلق نهائياً: لا يمكن حذفه أو تعديل بنوده. يلزم إعادة فتح الملف أولاً.",
        closure_code=closure_code,
    )


def closure_exists_error(closure_code: str) -> HTTPException:
    return coded_error(
        409,
        "FC_CLOSURE_EXISTS",
        f"يوجد بالفعل سجل إغلاق نشط لهذا الملف (رقم السجل: {closure_code}).",
        closure_code=closure_code,
    )
