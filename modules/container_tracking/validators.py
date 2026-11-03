"""
Validators for Container Tracking & Demurrage Charges
"""

import re
from datetime import date
from typing import Optional
from fastapi import HTTPException, status
from modules.container_tracking.schemas import (
    ContainerLifecycleUnitCreate,
    ContainerLifecycleUnitUpdate,
    ContainerDemurrageCreate,
    ContainerDemurrageUpdate,
)

# Standard ISO 6346 container number pattern (4 letters, 6 or 7 digits)
CONTAINER_REGEX = re.compile(r"^[A-Z]{3}[UJZ][0-9]{6,7}$", re.IGNORECASE)


def validate_container_number(container_number: str) -> str:
    cleaned = container_number.strip().upper()
    if len(cleaned) < 8 or len(cleaned) > 15:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid container number length: {cleaned}. Must be between 8 and 15 alphanumeric characters.",
        )
    return cleaned


def validate_container_dates(
    discharge_date: Optional[date],
    gate_out_held_date: Optional[date],
    empty_returned_date: Optional[date],
) -> None:
    """Ensure logical chronological sequence for container lifecycle milestones."""
    if discharge_date and gate_out_held_date:
        if gate_out_held_date < discharge_date:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Gate-out date (خروج تحت التحفظ) cannot be earlier than discharge date (تاريخ التفريغ).",
            )
    if gate_out_held_date and empty_returned_date:
        if empty_returned_date < gate_out_held_date:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Empty returned date (إرجاع الفارغ) cannot be earlier than gate-out date.",
            )
    if discharge_date and empty_returned_date:
        if empty_returned_date < discharge_date:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Empty returned date cannot be earlier than discharge date.",
            )


def validate_container_weights(
    tare_weight: Optional[float],
    payload_weight: Optional[float],
    gross_weight: Optional[float],
    vgm_weight: Optional[float],
) -> None:
    """Validate weight consistency if provided."""
    for val, name in [
        (tare_weight, "Tare weight"),
        (payload_weight, "Payload weight"),
        (gross_weight, "Gross weight"),
        (vgm_weight, "VGM weight"),
    ]:
        if val is not None and val < 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"{name} cannot be negative.",
            )

    if tare_weight is not None and payload_weight is not None and gross_weight is not None:
        calculated_gross = tare_weight + payload_weight
        # Allow minor 5% tolerance for weighing discrepancies
        if gross_weight < (calculated_gross * 0.95):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"Gross weight ({gross_weight} kg) cannot be less than tare + payload "
                    f"({calculated_gross} kg) beyond standard tolerance."
                ),
            )
