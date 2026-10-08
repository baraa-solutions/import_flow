from typing import Any, Iterable, Optional

from fastapi import HTTPException

from modules.common import enum_codes
from modules.common.validators import ensure_file_open

# Legacy labels stored today (T3 enum codes come in a later wave: docs/plans/phase-08-10-quality-plan.md section 5).
WR_STATUS_LABELS = frozenset({
    "Goods Received",
    "GRN Audited",
    "Discrepancy Reported",
    "Closed",
    "Under Bond Quarantine",
    "Under Quarantine Inspection",
    "Inspection Passed / Clean Receipt",
    "Draft / Pending Warehouse Count",
})
WR_DISCREPANCY_TYPES = frozenset({
    "None",
    "Shortage",
    "Damage",
    "Excess",
    "Wrong Item",
    "Shortage & Damaged",
    "Quarantine Rejection",
    # labels sent by the report-discrepancy dialog / older clients
    "Shortage and Damage",
    "Damage & Shortage",
    "Shortage Only",
    "Damage Only",
    "Broken Seal Discrepancy",
})
WR_VERDICT_CODES = frozenset(enum_codes.LABELS_EN[enum_codes.WAREHOUSE_INSPECTION_VERDICT])
# A submitted inspection protocol always carries a decision: PENDING is only the initial state.
WR_SUBMIT_VERDICTS = WR_VERDICT_CODES - {"PENDING"}


def coded_error(status_code: int, code: str, message_ar: str, **params: Any) -> HTTPException:
    """Error with a language-neutral code (codes listed in docs/plans/review-shared-needs.md, not yet registered in
    system_messages): ``detail = {code, message, **params}``."""
    return HTTPException(status_code=status_code, detail={"code": code, "message": message_ar, **params})


def validate_seal_integrity(seal_intact: bool, seal_number: str) -> None:
    """Logs warning or enforces registration of seal number."""
    if not seal_intact and (not seal_number or not seal_number.strip()):
        raise HTTPException(
            status_code=400,
            detail="في حالة كسر أو تلف الرصاص الأمني (Seal Broken)، يلزم إدخال رقم الرصاص المسجل للمطابقة وتوثيق المحضر.",
        )


def validate_discrepancy_claim(discrepancy_type: str, discrepancy_notes: str) -> None:
    """Validates discrepancy report notes when shortage or damage exists."""
    if discrepancy_type != "None" and (not discrepancy_notes or not discrepancy_notes.strip()):
        raise HTTPException(
            status_code=400,
            detail="عند إثبات عجز أو تلفيات أو أصناف مخالفة، يلزم كتابة ملاحظات وتفاصيل محضر الفحص والدليل.",
        )


def _qty(item: Any, field: str) -> int:
    value = item.get(field, 0) if isinstance(item, dict) else getattr(item, field, 0)
    return int(value or 0)


def validate_grn_lines(items: Iterable[Any]) -> None:
    """Per GRN line: accepted + shortage + damaged == invoiced. The only exception is an excess delivery
    (no shortage, no damage, accepted > invoiced), which keeps the "Excess" discrepancy type (plan WR-04 / Q4)."""
    for item in items:
        invoiced = _qty(item, "invoiced_qty")
        accepted = _qty(item, "accepted_qty")
        shortage = _qty(item, "shortage_qty")
        damaged = _qty(item, "damaged_qty")
        if accepted + shortage + damaged == invoiced:
            continue
        if shortage == 0 and damaged == 0 and accepted > invoiced:
            continue
        item_code = (item.get("item_code") if isinstance(item, dict) else getattr(item, "item_code", None)) or ""
        raise coded_error(
            400,
            "WR_GRN_LINE_UNBALANCED",
            (
                f"كميات البند {item_code} غير متوازنة: المقبول ({accepted}) + العجز ({shortage}) + التالف ({damaged}) "
                f"يجب أن يساوي الكمية المفوترة ({invoiced})."
            ),
            item_code=item_code,
            invoiced_qty=invoiced,
            accepted_qty=accepted,
            shortage_qty=shortage,
            damaged_qty=damaged,
        )


def normalize_verdict(verdict: Optional[str], allowed: frozenset = WR_SUBMIT_VERDICTS) -> Optional[str]:
    """Verdict code (legacy labels accepted) or None when absent; anything else is a 400."""
    if verdict is None or not str(verdict).strip():
        return None
    code = enum_codes.normalize(enum_codes.WAREHOUSE_INSPECTION_VERDICT, str(verdict).strip())
    if code not in allowed:
        raise coded_error(
            400,
            "WR_VERDICT_INVALID",
            f"قرار الفحص '{verdict}' غير معروف.",
            verdict=str(verdict),
        )
    return code


def validate_verdict_consistency(verdict: Optional[str], shortage_qty: int, damaged_qty: int) -> None:
    """ACCEPTED_FULL cannot be recorded while the quantities show a shortage or damage, and
    ACCEPTED_WITH_DISCREPANCY cannot remain when quantities have no discrepancy (plan WR-03 / BE810-T05)."""
    if verdict == "ACCEPTED_FULL" and (shortage_qty or 0) + (damaged_qty or 0) > 0:
        raise coded_error(
            400,
            "WR_VERDICT_INCONSISTENT",
            "لا يمكن اعتماد قرار القبول الكامل مع وجود عجز أو تالف في الكميات.",
            verdict=verdict,
            shortage_qty=int(shortage_qty or 0),
            damaged_qty=int(damaged_qty or 0),
        )
    if verdict in ("ACCEPTED_WITH_DISCREPANCY", "DAMAGE_CLAIM_PENDING") and (shortage_qty or 0) + (damaged_qty or 0) == 0:
        raise coded_error(
            400,
            "WR_VERDICT_INCONSISTENT",
            f"قرار الفحص معتمد بوجود فروق ({verdict}) بينما الكميات الحالية لا يوجد بها عجز أو تالف. يلزم إعادة اعتماد محضر الفحص.",
            verdict=verdict,
            shortage_qty=int(shortage_qty or 0),
            damaged_qty=int(damaged_qty or 0),
        )


def validate_verdict_matches(verdict: Optional[str], expected: frozenset, derived: str) -> None:
    """A verdict the client sends must fit the outcome the quantities / quarantine give; it is never silently
    replaced (plan WR-03)."""
    if verdict is not None and verdict not in expected:
        raise coded_error(
            400,
            "WR_VERDICT_INCONSISTENT",
            f"قرار الفحص {verdict} لا يتفق مع نتيجة الفحص (المتوقع: {derived}).",
            verdict=verdict,
            expected_verdict=derived,
        )


def validate_status_label(status: Optional[str]) -> None:
    if status is not None and status not in WR_STATUS_LABELS:
        raise coded_error(400, "WR_STATUS_INVALID", f"حالة إذن الاستلام '{status}' غير معروفة.", status=status)


WR_ALLOWED_PUT_STATUS_TRANSITIONS = frozenset({
    ("Draft / Pending Warehouse Count", "Goods Received"),
    ("Goods Received", "GRN Audited"),
    ("GRN Audited", "Closed"),
})


def validate_grn_status_transition(current_status: str, target_status: Optional[str]) -> None:
    if target_status is None or target_status == current_status:
        return
    validate_status_label(target_status)
    if (current_status, target_status) not in WR_ALLOWED_PUT_STATUS_TRANSITIONS:
        raise coded_error(
            409,
            "WR_STATUS_CHANGE_NOT_ALLOWED",
            f"لا يمكن تغيير حالة إذن الاستلام من '{current_status}' إلى '{target_status}'.",
            current_status=current_status,
            target_status=target_status,
        )


def validate_grn_put_fields(schema: Any) -> None:
    fields_set = getattr(schema, "model_fields_set", None)
    if fields_set is not None:
        if "inspection_verdict" in fields_set:
            raise coded_error(
                400,
                "WR_FIELD_NOT_EDITABLE",
                "لا يمكن تعديل قرار الفحص مباشرة؛ يتم تحديد القرار من خلال محضر الفحص فقط.",
                field_name="inspection_verdict",
            )
    elif getattr(schema, "inspection_verdict", None) is not None:
        raise coded_error(
            400,
            "WR_FIELD_NOT_EDITABLE",
            "لا يمكن تعديل قرار الفحص مباشرة؛ يتم تحديد القرار من خلال محضر الفحص فقط.",
            field_name="inspection_verdict",
        )


def validate_discrepancy_type(discrepancy_type: Optional[str]) -> None:
    if discrepancy_type is not None and discrepancy_type not in WR_DISCREPANCY_TYPES:
        raise coded_error(
            400,
            "WR_DISCREPANCY_TYPE_INVALID",
            f"نوع الفرق '{discrepancy_type}' غير معروف.",
            discrepancy_type=discrepancy_type,
        )

def validate_customs_release(imp: Any, clearance: Any) -> None:
    """GRN create precondition (plan WR-F08 / BE810-T11).
    Shipment must have customs release or under-bond authorization, or customs clearance was skipped (STEP_17).
    """
    is_released = bool(getattr(imp, "is_customs_released", False))
    permit_no = bool(getattr(imp, "customs_release_permit_no", None))
    clearance_status = getattr(clearance, "status", None) if clearance else None
    clearance_released = (clearance_status == "Final Release Granted")
    under_bond = bool(getattr(clearance, "is_under_bond_release", False)) if clearance else False
    skipped = getattr(imp, "skipped_stages", None) or []
    step_17_skipped = "STEP_17" in skipped

    if is_released or permit_no or clearance_released or under_bond or step_17_skipped:
        return

    import_file_code = getattr(imp, "import_file_code", "")
    msg_ar = (
        f"لا يمكن إنشاء إذن استلام للملف {import_file_code}: يلزم وجود إفراج جمركي أو إذن إفراج تحت التحفظ."
        if import_file_code
        else "لا يمكن إنشاء إذن استلام: يلزم وجود إفراج جمركي أو إذن إفراج تحت التحفظ."
    )
    raise coded_error(
        400,
        "WR_CUSTOMS_NOT_RELEASED",
        msg_ar,
        import_file_code=import_file_code,
    )


def validate_grn_deletable(record: Any) -> None:
    """GRN delete guard (plan WR-F14 / BE810-T16).
    Raises 409 WR_GRN_LOCKED when inspection protocol exists, claims are filed, or quarantine lock is active.
    """
    if (
        getattr(record, "inspection_protocol_number", None)
        or getattr(record, "insurance_claim_filed", False)
        or getattr(record, "supplier_claim_filed", False)
        or getattr(record, "quarantine_lock_active", False)
    ):
        grn_code = getattr(record, "grn_code", "")
        reasons = []
        if getattr(record, "inspection_protocol_number", None):
            reasons.append("محضر الفحص معتمد")
        if getattr(record, "insurance_claim_filed", False) or getattr(record, "supplier_claim_filed", False):
            reasons.append("توجد مطالبات مسجلة")
        if getattr(record, "quarantine_lock_active", False):
            reasons.append("حظر التحفظ الجمركي نشط")
        reason_text = "، ".join(reasons)
        msg_ar = (
            f"لا يمكن حذف إذن الاستلام {grn_code}: {reason_text}."
            if grn_code
            else f"لا يمكن حذف إذن الاستلام: {reason_text}."
        )
        raise coded_error(
            409,
            "WR_GRN_LOCKED",
            msg_ar,
            grn_code=grn_code,
        )

