"""
Input validation for Regulatory Matrix
"""

import re
from typing import Any, Dict
from fastapi import HTTPException, status
from modules.regulatory_matrix.schemas import HsCodeRegulatoryCreate, HsCodeRegulatoryUpdate

VALID_AGENCIES = {"NFSA", "GOEIC", "QUARANTINE", "NTRA", "EOS", "EDA", "PHARMACEUTICAL", "OTHER"}
VALID_STAGES = {"PRE_ACID", "PRE_ARRIVAL", "CUSTOMS_EXAMINATION", "POST_CLEARANCE"}
VALID_INSPECTIONS = {"PHYSICAL_INSPECTION", "DOCUMENTARY_CHECK", "LAB_SAMPLING", None}


def validate_hs_code_format(hs_code: str) -> str:
    cleaned = hs_code.strip()
    digits_only = re.sub(r"[.\s]", "", cleaned)
    if len(digits_only) < 4 or len(digits_only) > 12 or not digits_only.isdigit():
        raise HTTPException(
            status_code=422,
            detail=f"رمز البند الجمركي غير صالح ({hs_code}). يجب أن يتكون من 4 إلى 12 رقماً.",
        )
    return cleaned


def validate_requirement_create(data: HsCodeRegulatoryCreate) -> None:
    validate_hs_code_format(data.hs_code)

    if not data.agency_code or data.agency_code.strip().upper() not in VALID_AGENCIES:
        raise HTTPException(
            status_code=422,
            detail=f"رمز جهة العرض الرقابية غير صالح. الخيارات المتاحة: {', '.join(sorted(VALID_AGENCIES))}",
        )

    if not data.stage_timing or data.stage_timing.strip().upper() not in VALID_STAGES:
        raise HTTPException(
            status_code=422,
            detail=f"توقيت مرحلة العرض غير صالح. الخيارات المتاحة: {', '.join(sorted(VALID_STAGES))}",
        )

    if data.inspection_type and data.inspection_type.strip().upper() not in VALID_INSPECTIONS:
        raise HTTPException(
            status_code=422,
            detail="نوع الفحص غير صالح. يجب أن يكون كشف ظاهري، فحص مستندي، أو سحب عينات معملية.",
        )


def validate_requirement_update(data: HsCodeRegulatoryUpdate) -> Dict[str, Any]:
    updates: Dict[str, Any] = {}

    if data.agency_code is not None:
        if data.agency_code.strip().upper() not in VALID_AGENCIES:
            raise HTTPException(
                status_code=422,
                detail=f"رمز جهة العرض غير صالح ({data.agency_code}).",
            )
        updates["agency_code"] = data.agency_code.strip().upper()

    if data.stage_timing is not None:
        if data.stage_timing.strip().upper() not in VALID_STAGES:
            raise HTTPException(
                status_code=422,
                detail=f"توقيت المرحلة غير صالح ({data.stage_timing}).",
            )
        updates["stage_timing"] = data.stage_timing.strip().upper()

    if data.inspection_type is not None:
        if data.inspection_type and data.inspection_type.strip().upper() not in VALID_INSPECTIONS:
            raise HTTPException(
                status_code=422,
                detail="نوع الفحص غير صالح.",
            )
        updates["inspection_type"] = data.inspection_type.strip().upper() if data.inspection_type else None

    for field in ["agency_name_ar", "agency_name_en", "required_documents", "regulatory_notes", "is_mandatory", "is_active"]:
        val = getattr(data, field)
        if val is not None:
            updates[field] = val

    return updates
