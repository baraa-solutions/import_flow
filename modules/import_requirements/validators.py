from typing import Any, Dict, Optional

from sqlalchemy.orm import Session

from fastapi import HTTPException, status

from modules.common.errors import CodedHTTPException
from modules.common.validators import not_null_columns
from modules.import_requirements.model import ImportRequirementAssessment

# Error code (detail["code"]) for a second active assessment on the same import file.
IR_ASSESSMENT_EXISTS = "IR_ASSESSMENT_EXISTS"


VALID_STATUSES = {"Not Required", "Pending", "Obtained", "Waived", "Scheduled", "Completed", "Applied", "Approved", "Rejected", "In Progress"}
VALID_RISK_LEVELS = {"Low", "Medium", "High"}
VALID_OVERALL_STATUSES = {"Draft", "In Progress", "Complete", "Cleared"}


def validate_risk_level(risk_level: str):
    if risk_level not in VALID_RISK_LEVELS:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"Invalid risk_level '{risk_level}'. Must be one of: {VALID_RISK_LEVELS}"
        )


def validate_overall_status(overall_status: str):
    if overall_status not in VALID_OVERALL_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"Invalid overall_status '{overall_status}'. Must be one of: {VALID_OVERALL_STATUSES}"
        )


def validate_shipment_value(value: float):
    if value < 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="shipment_value_usd must be >= 0"
        )


def validate_no_active_assessment_for_file(existing: Optional[ImportRequirementAssessment], file_ref: str) -> None:
    """One active assessment per import file: a second one is a coded 409."""
    if existing is None:
        return
    raise CodedHTTPException(
        status.HTTP_409_CONFLICT,
        IR_ASSESSMENT_EXISTS,
        (
            f"يوجد بالفعل دراسة تقييم متطلبات استيرادية نشطة للملف الاستيرادي #{file_ref} "
            f"(كود التقييم: {existing.assessment_code}). يمكنك تعديل التقييم القائم بدلاً من إنشاء تقييم جديد."
        ),
        assessment_code=existing.assessment_code,
        assessment_id=existing.assessment_id,
    )


NOT_NULL_COLUMNS = not_null_columns(ImportRequirementAssessment)


def validate_required_fields_not_null(update_data: Dict[str, Any]) -> None:
    """An update may clear optional fields with null, but not a NOT NULL column (that would be a 500)."""
    cleared = sorted(k for k, v in update_data.items() if v is None and k in NOT_NULL_COLUMNS)
    if cleared:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"لا يمكن مسح قيمة الحقول الإلزامية: {', '.join(cleared)}",
        )


def validate_requirement_currency(db: Session, price: Optional[float], currency: Optional[str]) -> Optional[str]:
    """Validate currency for import requirement: required when price > 0, normalized to uppercase."""
    from modules.common.validators import validate_price_currency
    return validate_price_currency(db, price, currency, label_ar="عملة قيمة الشحنة")
