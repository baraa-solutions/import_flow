from typing import Any
from fastapi import HTTPException, status

from modules.custody_release.model import CustodyReleaseDossier
from modules.custody_release.schemas import (
    CUSTODY_STATUSES,
    CustodyBreachReportSubmit,
    CustodyFinalClearanceSubmit,
    CustodyReleaseDossierCreate,
)


def _bad_request(detail: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=detail)


def _conflict(detail: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail)


def validate_custody_status(st: Any) -> None:
    if st not in CUSTODY_STATUSES:
        raise _bad_request(
            f"حالة ملف التحفظ الجمركي غير صحيحة: {st}. الحالات المتاحة: {', '.join(CUSTODY_STATUSES)}"
        )


def validate_custody_create(payload: CustodyReleaseDossierCreate) -> None:
    if payload.import_file_id <= 0:
        raise _bad_request("معرّف ملف الاستيراد غير صحيح.")
    if not payload.custody_undertaking_number or not payload.custody_undertaking_number.strip():
        raise _bad_request("رقم إقرار / تعهد التحفظ الجمركي مطلوب.")
    if payload.lead_seals_count < 0:
        raise _bad_request("عدد الرصاص الجمركي لا يمكن أن يكون سالباً.")
    validate_custody_status(payload.status)


def validate_final_clearance(payload: CustodyFinalClearanceSubmit) -> None:
    if not payload.final_clearance_letter_number or not payload.final_clearance_letter_number.strip():
        raise _bad_request("رقم خطاب الإفراج النهائي / شهادة المطابقة مطلوب لفك التحفظ الجمركي.")


def validate_breach_report(payload: CustodyBreachReportSubmit) -> None:
    if not payload.breach_reason or not payload.breach_reason.strip():
        raise _bad_request("تفاصيل وأسباب مخالفة التحفظ الجمركي مطلوبة.")


def validate_dispense_attempt(dossier: CustodyReleaseDossier) -> None:
    """
    Enforces warehouse dispatch prohibition if custody lock is active or breach reported.
    """
    if dossier.status == "BREACH_REPORTED":
        raise _conflict(
            f"صرف البضاعة محظور: تم الإبلاغ عن مخالفة فض أختام أو خرق للتحفظ الجمركي على الملف رقم {dossier.custody_code} والملف قيد الإجراءات القضائية."
        )

    if dossier.lock_active:
        raise _conflict(
            f"صرف البضاعة من المستودع محظور قطعيًا: الشحنة خاضعة للإفراج المؤقت تحت التحفظ بموجب التعهد رقم ({dossier.custody_undertaking_number}) ومغلقة بالرصاص الجمركي لحين صدور نتائج الفحص المعملي والإفراج النهائي."
        )
