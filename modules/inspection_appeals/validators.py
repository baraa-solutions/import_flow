from typing import Any, Optional
from fastapi import HTTPException, status

from modules.inspection_appeals.schemas import (
    APPEAL_RESULTS,
    APPEAL_TIERS,
    INITIAL_TEST_RESULTS,
    REGULATORY_AUTHORITIES,
    AppealCommitteeDecisionSubmit,
    AppealTierProgression,
    InspectionAppealCreate,
)


def _bad_request(detail: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=detail)


def _conflict(detail: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail)


def validate_regulatory_authority(authority: Any) -> None:
    if authority not in REGULATORY_AUTHORITIES:
        raise _bad_request(
            f"جهة الفحص الرقابي غير صحيحة: {authority}. الجهات المعتمدة: {', '.join(REGULATORY_AUTHORITIES)}"
        )


def validate_initial_test_result(result: Any) -> None:
    if result not in INITIAL_TEST_RESULTS:
        raise _bad_request(
            f"نتيجة الفحص المعملي الأولية غير صحيحة: {result}. النتائج المتاحة: {', '.join(INITIAL_TEST_RESULTS)}"
        )


def validate_appeal_tier(tier: Any) -> None:
    if tier not in APPEAL_TIERS:
        raise _bad_request(
            f"درجة التظلم غير صحيحة: {tier}. درجات التظلم المتاحة: {', '.join(APPEAL_TIERS)}"
        )


def validate_appeal_result(result: Any) -> None:
    if result not in APPEAL_RESULTS:
        raise _bad_request(
            f"قرار التظلم غير صحيح: {result}. القرارات المتاحة: {', '.join(APPEAL_RESULTS)}"
        )


def validate_appeal_create(payload: InspectionAppealCreate) -> None:
    if payload.import_file_id <= 0:
        raise _bad_request("معرّف ملف الاستيراد غير صحيح.")
    if payload.clearance_id is not None and payload.clearance_id <= 0:
        raise _bad_request("معرّف ملف التخليص الجمركي غير صحيح.")
    validate_regulatory_authority(payload.regulatory_authority)
    validate_initial_test_result(payload.initial_test_result)
    validate_appeal_tier(payload.appeal_tier)
    if payload.appeal_tier == "TRIPLICATE_SAMPLE" and not (payload.triplicate_lab_assigned and payload.triplicate_lab_assigned.strip()):
        raise _bad_request("يجب تحديد معمل فحص العينة الثلاثية عند تقديم التظلم على درجة العينة الثلاثية.")


def validate_tier_progression(
    current_tier: str,
    target_tier: str,
    triplicate_lab_assigned: Optional[str] = None,
    current_result: Optional[str] = None,
) -> None:
    validate_appeal_tier(target_tier)

    # Cannot progress if already overturned and conforming
    if current_result == "OVERTURNED_CONFORMING":
        raise _conflict("لا يمكن تصعيد التظلم حيث تم قبول التظلم وقبول الرسالة كمطابقة بالفعل.")

    # Valid progressions
    allowed_transitions = {
        "FIRST_APPEAL": ("SECOND_APPEAL", "TRIPLICATE_SAMPLE"),
        "SECOND_APPEAL": ("TRIPLICATE_SAMPLE",),
        "TRIPLICATE_SAMPLE": (),
    }

    allowed = allowed_transitions.get(current_tier, ())
    if target_tier not in allowed:
        if current_tier == "TRIPLICATE_SAMPLE":
            raise _conflict("وصل التظلم إلى مرحلة العينة الثلاثية النهائية، ولا يمكن التصعيد لدرجة أعلى.")
        raise _conflict(
            f"مسار تصعيد التظلم غير مسموح: من {current_tier} إلى {target_tier}. المراحل المتاحة: {', '.join(allowed) if allowed else 'لا يوجد'}"
        )

    if target_tier == "TRIPLICATE_SAMPLE" and not (triplicate_lab_assigned and triplicate_lab_assigned.strip()):
        raise _bad_request("يجب تحديد المعمل المعتمد لفحص العينة الثلاثية (triplicate_lab_assigned).")


def validate_committee_decision(payload: AppealCommitteeDecisionSubmit) -> None:
    validate_appeal_result(payload.appeal_result)
