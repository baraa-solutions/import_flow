"""
Customs clearance domain rules: payment / release guards, lab result codes, coded errors.
"""
from datetime import date, datetime
from typing import Any, Optional

from fastapi import HTTPException, status

from modules.common.validators import ensure_file_open

# Payment amounts are EGP with 2 decimals: a difference below one piastre is rounding noise.
MONEY_TOLERANCE = 0.01
PAID_PAYMENT_STATUSES = ("Paid & Verified", "Paid", "Duties Paid")
FINAL_RELEASE_STATUS = "Final Release Granted"

# The seven itemised CL-02 components; their rounded sum is total_duty_payable (one formula for every path).
DUTY_COMPONENT_FIELDS = (
    "import_duty_amount",
    "vat_amount",
    "schedule_tax_amount",
    "development_fee_amount",
    "customs_service_fees",
    "wht_amount",
    "lab_service_fees",
)

# LAB_TEST_RESULT codes (enum registration pending, see docs/plans/review-shared-needs.md).
LAB_CONFORMING = "CONFORMING"
LAB_NON_CONFORMING = "NON_CONFORMING"
_LAB_RESULT_LEGACY = {
    "conforming": LAB_CONFORMING,
    "approved": LAB_CONFORMING,
    "مطابق": LAB_CONFORMING,
    "مقبول": LAB_CONFORMING,
    "non-conforming": LAB_NON_CONFORMING,
    "non conforming": LAB_NON_CONFORMING,
    "nonconforming": LAB_NON_CONFORMING,
    "rejected": LAB_NON_CONFORMING,
    "غير مطابق": LAB_NON_CONFORMING,
    "مرفوض": LAB_NON_CONFORMING,
}

DUTY_NOT_PAID_MESSAGE = (
    "لا يمكن إصدار أمر الإفراج الجمركي النهائي قبل تأكيد وتوثيق سداد الرسوم الجمركية بنجاح عبر سداد (CL-03)."
)


def coded_error(status_code: int, code: str, message_ar: str, **params: Any) -> HTTPException:
    """``HTTPException`` with ``detail = {"code", "message" (Arabic), **params}`` (codes listed in
    docs/plans/review-shared-needs.md, "06-07 shared needs")."""
    return HTTPException(status_code=status_code, detail={"code": code, "message": message_ar, **params})


def normalize_lab_test_result(value: Any) -> str:
    """``CONFORMING`` / ``NON_CONFORMING`` from a code or a legacy label; anything else raises ``ValueError``."""
    text = str(value or "").strip()
    if text.upper() in (LAB_CONFORMING, LAB_NON_CONFORMING):
        return text.upper()
    code = _LAB_RESULT_LEGACY.get(text.lower())
    if code is None:
        raise ValueError("lab_test_result must be CONFORMING or NON_CONFORMING")
    return code


def assessed_duty_total(record) -> float:
    """The assessed duty a payment must cover: ``actual_duty_total`` (CL-02), else ``total_duty_payable``."""
    actual = float(record.actual_duty_total or 0.0)
    return actual if actual > 0 else float(record.total_duty_payable or 0.0)


def is_assessed(record) -> bool:
    """Assessed = ``assessment_status == "Assessed"``, assessed total > 0, AND nafeza_claim_number present
    (proving CL-02 actually ran, since assessment_status defaulted to "Assessed")."""
    return (
        record is not None
        and record.assessment_status == "Assessed"
        and assessed_duty_total(record) > 0
        and bool((record.nafeza_claim_number or "").strip())
    )


def is_duty_fully_paid(record) -> bool:
    """Paid status AND the paid amount covers the assessed total (a partial payment is not "paid")."""
    if record is None or record.payment_status not in PAID_PAYMENT_STATUSES:
        return False
    return float(record.duty_paid_amount or 0.0) >= assessed_duty_total(record) - MONEY_TOLERANCE


def validate_bank_receipt_no(receipt_no: str) -> None:
    """Validates bank receipt number is non-empty and has proper format."""
    if not receipt_no or not receipt_no.strip():
        raise HTTPException(status_code=400, detail="رقم إيصال السداد البنكي إجباري ومطلوب لتوثيق سداد الرسوم الجمركية.")


def validate_duty_payment_amount(record, paid_amount: float) -> None:
    """CL-05: a payment needs an assessed record (409) and must cover the assessed total (400, no partials)."""
    if not is_assessed(record):
        raise coded_error(
            status.HTTP_409_CONFLICT,
            "CC_DUTY_NOT_ASSESSED",
            "لا يمكن تسجيل السداد قبل احتساب الرسوم الجمركية النهائية (CL-02).",
        )
    assessed = assessed_duty_total(record)
    if float(paid_amount) < assessed - MONEY_TOLERANCE:
        raise coded_error(
            status.HTTP_400_BAD_REQUEST,
            "CC_DUTY_UNDERPAID",
            f"المبلغ المسدد ({round(float(paid_amount), 2)}) أقل من إجمالي الرسوم الجمركية المحتسبة ({round(assessed, 2)}).",
            paid_amount=round(float(paid_amount), 2),
            assessed_amount=round(assessed, 2),
        )


def validate_release_payment(record) -> None:
    """CL-06: release only for an existing record whose duty is fully paid."""
    if is_duty_fully_paid(record):
        return
    if record is not None and record.payment_status in PAID_PAYMENT_STATUSES:
        raise coded_error(
            status.HTTP_400_BAD_REQUEST,
            "CC_DUTY_UNDERPAID",
            "لا يمكن إصدار الإفراج الجمركي: المبلغ المسدد أقل من إجمالي الرسوم الجمركية المحتسبة.",
            paid_amount=round(float(record.duty_paid_amount or 0.0), 2),
            assessed_amount=round(assessed_duty_total(record), 2),
        )
    raise coded_error(status.HTTP_400_BAD_REQUEST, "CC_DUTY_NOT_PAID", DUTY_NOT_PAID_MESSAGE)


def validate_release_permit_no(permit_no: Optional[str]) -> str:
    text = (permit_no or "").strip()
    if not text:
        raise HTTPException(status_code=400, detail="رقم إذن/تصريح الإفراج الجمركي النهائي مطلوب ولا يمكن أن يكون فارغاً.")
    if len(text) < 3:
        raise HTTPException(status_code=400, detail="رقم إذن الإفراج الجمركي الأخضر يجب ألا يقل عن 3 أحرف أو أرقام.")
    return text


def validate_release_permit(permit_no: str, payment_status: str) -> None:
    """Legacy check kept for callers: paid status first, then a non-empty permit number."""
    if payment_status not in PAID_PAYMENT_STATUSES:
        raise HTTPException(status_code=400, detail="لا يمكن إصدار الإفراج الجمركي النهائي قبل تأكيد وتوثيق سداد الرسوم الجمركية بنجاح.")
    if not permit_no or not permit_no.strip():
        raise HTTPException(status_code=400, detail="رقم إذن/تصريح الإفراج الجمركي النهائي مطلوب ولا يمكن أن يكون فارغاً.")


def acid_expiry_date(imp_file) -> Optional[date]:
    """The file's ACID expiry as a date; an unparseable stored value is a 400, never silently ignored."""
    value = getattr(imp_file, "acid_expiry_date", None)
    if value is None or value == "":
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    try:
        return date.fromisoformat(str(value)[:10])
    except ValueError:
        raise coded_error(
            status.HTTP_400_BAD_REQUEST,
            "CC_ACID_EXPIRY_INVALID",
            "تاريخ انتهاء صلاحية رقم ACID المسجل على ملف الشحنة غير صالح. يرجى تصحيحه أولاً.",
            import_file_id=imp_file.import_file_id,
        )


def validate_acid_not_expired_for_release(imp_file) -> None:
    """DC-02 / ACID-002: hard block of the final release while the ACID is expired."""
    if imp_file.is_customs_released:
        return
    expiry = acid_expiry_date(imp_file)
    if expiry and expiry < date.today():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"حظر الإفراج الجمركي: رقم القيد الجمركي ACID ({imp_file.acid_number or 'غير محدد'}) "
                f"منتهي الصلاحية منذ {expiry}. "
                "لا يجوز إصدار إذن الإفراج الجمركي النهائي إلا بعد تجديد أو تمديد صلاحية الرقم التعريفي عبر منظومة نافذة."
            ),
        )


def validate_under_bond_allowed(record, imp_file) -> None:
    """CL-08: no under-bond release on a record already under bond or finally released."""
    released = record.status == FINAL_RELEASE_STATUS or bool(imp_file is not None and imp_file.is_customs_released)
    if record.is_under_bond_release or released:
        raise coded_error(
            status.HTTP_409_CONFLICT,
            "CC_UNDER_BOND_NOT_ALLOWED",
            "لا يمكن إصدار إفراج تحت التحفظ: الشحنة مفرج عنها تحت التحفظ أو إفراجاً نهائياً بالفعل.",
            clearance_status=record.status,
        )


def validate_release_not_quarantined(record) -> None:
    """No final release while the under-bond quarantine lock is active (lab result pending / non-conforming)."""
    if record is not None and record.quarantine_lock:
        raise coded_error(
            status.HTTP_409_CONFLICT,
            "CC_RELEASE_QUARANTINE_LOCKED",
            "لا يمكن إصدار الإفراج الجمركي النهائي والشحنة تحت التحفظ المعملي. يجب تسجيل نتيجة فحص مطابقة وفك التحفظ أولاً.",
            clearance_code=record.clearance_code,
        )


def validate_lab_result_open(record) -> None:
    """A lab result is recorded only while the quarantine lock is active and the record is not finally released."""
    if record.status == FINAL_RELEASE_STATUS or not record.quarantine_lock:
        raise coded_error(
            status.HTTP_409_CONFLICT,
            "CC_LAB_RESULT_ALREADY_FINAL",
            "تم تسجيل نتيجة الفحص المعملي وفك التحفظ أو الإفراج النهائي بالفعل لهذه الشحنة.",
            clearance_status=record.status,
        )


from modules.financial_settlement.validators import LOCKED_SETTLEMENT_STATUSES

SETTLEMENT_LOCKED_STATUSES = LOCKED_SETTLEMENT_STATUSES


def validate_settlement_open(
    db: Any, import_file_id: int, entity_label: str = "فواتير التخليص والرسوم الجمركية"
) -> None:
    """CL-05 / BEW0-06: clearance duties and invoices cannot be modified after the landed-cost settlement is approved."""
    from modules.financial_settlement.model import LandedCostSettlementRecord

    settlement = (
        db.query(LandedCostSettlementRecord)
        .filter(
            LandedCostSettlementRecord.import_file_id == import_file_id,
            LandedCostSettlementRecord.is_active == True,  # noqa: E712
        )
        .first()
    )
    if settlement and settlement.status in LOCKED_SETTLEMENT_STATUSES:
        raise coded_error(
            status.HTTP_409_CONFLICT,
            "CC_SETTLEMENT_LOCKED",
            f"لا يمكن تعديل {entity_label} بعد اعتماد تسوية تكلفة الوصول.",
            settlement_code=settlement.settlement_code,
            settlement_status=settlement.status,
        )


