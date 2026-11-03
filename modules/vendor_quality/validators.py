"""
Validation rules for Pre-Shipment Inspection (PSI) and Vendor Quality
"""

from typing import Optional
from fastapi import HTTPException, status
from modules.vendor_quality.repository import VendorQualityRepository


def validate_assessment_code_unique(
    repo: VendorQualityRepository,
    code: str,
    current_id: Optional[int] = None,
) -> None:
    existing = repo.get_by_code(code)
    if existing and (current_id is None or existing.id != current_id):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Assessment code '{code}' already exists.",
        )


def validate_scores(
    quality: float,
    timeliness: float,
    docs: float,
    compliance: float,
) -> None:
    for name, val in [
        ("Quality", quality),
        ("Delivery timeliness", timeliness),
        ("Documentation accuracy", docs),
        ("Compliance", compliance),
    ]:
        if val < 0.0 or val > 100.0:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"{name} score must be between 0.0 and 100.0 (received {val}).",
            )


def validate_defects_count(defects: int, critical_defects: int) -> None:
    if defects < 0 or critical_defects < 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Defects count cannot be negative.",
        )
    if critical_defects > defects:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Critical defects ({critical_defects}) cannot exceed total defects count ({defects}).",
        )
