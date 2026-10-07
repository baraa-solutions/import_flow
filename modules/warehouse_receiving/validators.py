from typing import Any, Iterable, Optional, Tuple

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
    """ACCEPTED_FULL cannot be recorded while the quantities show a shortage or damage (plan WR-03)."""
    if verdict == "ACCEPTED_FULL" and (shortage_qty or 0) + (damaged_qty or 0) > 0:
        raise coded_error(
            400,
            "WR_VERDICT_INCONSISTENT",
            "لا يمكن اعتماد قرار القبول الكامل مع وجود عجز أو تالف في الكميات.",
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


def validate_discrepancy_type(discrepancy_type: Optional[str]) -> None:
    if discrepancy_type is not None and discrepancy_type not in WR_DISCREPANCY_TYPES:
        raise coded_error(
            400,
            "WR_DISCREPANCY_TYPE_INVALID",
            f"نوع الفرق '{discrepancy_type}' غير معروف.",
            discrepancy_type=discrepancy_type,
        )

def validate_claim_amount_and_currency(
    db: Any,
    amount: Optional[float],
    currency: Optional[str],
) -> Tuple[Optional[float], Optional[str]]:
    """Validate claim amount and currency for inspection and receiving updates (plan WR-F11 / BE810-T12).

    - If amount is None or == 0: returns (None, None).
    - If amount > 0: currency is required and must match an active currency in the currencies master.
      Raises 400 WR_CLAIM_CURRENCY_INVALID if currency is missing, unknown, or inactive.
      Returns (amount, normalized_currency_code).
    """
    if amount is None or amount == 0:
        return None, None

    norm = enum_codes.normalize_currency(currency)
    clean_currency = str(norm or "").strip().upper()
    if not clean_currency:
        raise coded_error(
            400,
            "WR_CLAIM_CURRENCY_INVALID",
            "يلزم تحديد عملة المطالبة عند تسجيل قيمة تقديرية للمطالبة.",
            currency_code="",
        )

    from modules.currencies.model import Currency
    row = (
        db.query(Currency)
        .filter(Currency.currency_code == clean_currency, Currency.is_active.is_(True))
        .first()
    )
    if not row:
        raise coded_error(
            400,
            "WR_CLAIM_CURRENCY_INVALID",
            f"عملة المطالبة '{clean_currency}' غير معروفة أو غير نشطة.",
            currency_code=clean_currency,
        )

    return float(amount), clean_currency


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

