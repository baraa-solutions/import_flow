import re
from datetime import date
from typing import Optional
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from .model import ShipmentContainer


def normalize_container_number(raw_number: str) -> str:
    """Cleans and standardizes a container number (uppercase, alphanumeric)."""
    if not raw_number or not raw_number.strip():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="رقم الحاوية لا يمكن أن يكون فارغاً.",
        )
    cleaned = re.sub(r"[^A-Za-z0-9]", "", raw_number).upper()
    if len(cleaned) < 4:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"رقم الحاوية '{raw_number}' قصير جداً وغير صالح.",
        )
    return cleaned


def validate_container_dates(
    discharge_date: Optional[date] = None,
    gate_out_date: Optional[date] = None,
    empty_return_date: Optional[date] = None,
) -> None:
    """Validates chronological ordering of container operational milestone dates."""
    if gate_out_date and discharge_date and gate_out_date < discharge_date:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="تاريخ خروج الحاوية من الميناء لا يمكن أن يسبق تاريخ التفريغ.",
        )

    if empty_return_date and gate_out_date and empty_return_date < gate_out_date:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="تاريخ إرجاع الحاوية الفارغة لا يمكن أن يسبق تاريخ خروجها من الميناء.",
        )

    if empty_return_date and discharge_date and empty_return_date < discharge_date:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="تاريخ إرجاع الحاوية الفارغة لا يمكن أن يسبق تاريخ التفريغ.",
        )


def validate_unique_container_number(
    db: Session,
    import_file_id: int,
    container_number: str,
    exclude_container_id: Optional[int] = None,
) -> None:
    """Guards against duplicate active container entries in the same import file."""
    query = db.query(ShipmentContainer).filter(
        ShipmentContainer.import_file_id == import_file_id,
        ShipmentContainer.container_number == container_number,
        ShipmentContainer.is_active == True,
    )
    if exclude_container_id is not None:
        query = query.filter(ShipmentContainer.container_id != exclude_container_id)

    if query.first():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"رقم الحاوية '{container_number}' مسجل مسبقاً في هذا الملف الاستيرادي.",
        )
