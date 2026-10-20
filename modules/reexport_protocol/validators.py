from datetime import date, timedelta
from typing import List, Optional, Tuple, Dict, Any
from fastapi import HTTPException, status


ALLOWED_STATUSES = {
    "MANDATED",
    "BOOKING_CONFIRMED",
    "CUSTOMS_INSPECTED",
    "LADEN_ON_BOARD",
    "COMPLETED_CLOSED",
}

STATUS_HIERARCHY = [
    "MANDATED",
    "BOOKING_CONFIRMED",
    "CUSTOMS_INSPECTED",
    "LADEN_ON_BOARD",
    "COMPLETED_CLOSED",
]


def validate_legal_deadline(rejection_date: date, legal_deadline: Optional[date] = None) -> date:
    """
    Under Article 37 of Egyptian Customs Law 207/2020, rejected cargo has a strict
    statutory re-export deadline of 30 calendar days from the issuance of the rejection decree.
    """
    if legal_deadline is None:
        return rejection_date + timedelta(days=30)
    
    if legal_deadline < rejection_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Legal re-export deadline cannot be earlier than rejection decree date.",
        )
    return legal_deadline


def clean_container_numbers(containers: Optional[List[str]]) -> List[str]:
    """Clean and normalize container numbers."""
    if not containers:
        return []
    cleaned = []
    seen = set()
    for c in containers:
        if not c:
            continue
        normalized = str(c).strip().upper()
        if normalized and normalized not in seen:
            seen.add(normalized)
            cleaned.append(normalized)
    return cleaned


def validate_amounts(duty_refundable_egp: float, credit_note_usd: float) -> None:
    if duty_refundable_egp < 0.0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Duty drawback refundable amount in EGP cannot be negative.",
        )
    if credit_note_usd < 0.0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Supplier credit note amount in USD cannot be negative.",
        )


def calculate_destruction_countdown(
    legal_deadline: date, as_of_date: Optional[date] = None
) -> Tuple[int, str]:
    """
    Computes days remaining until statutory destruction under Law 207/2020.
    Returns (days_remaining, alert_level)
    """
    if as_of_date is None:
        as_of_date = date.today()
    days_remaining = (legal_deadline - as_of_date).days
    
    if days_remaining <= 0:
        alert_level = "CRITICAL"
    elif days_remaining <= 7:
        alert_level = "URGENT"
    elif days_remaining <= 14:
        alert_level = "WARNING"
    else:
        alert_level = "NORMAL"
        
    return days_remaining, alert_level


def validate_status_transition(
    current_status: str, target_status: str, dossier_data: Dict[str, Any]
) -> None:
    """
    Validates state machine transitions for the statutory re-export process.
    """
    if target_status not in ALLOWED_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid re-export status: {target_status}",
        )
    
    if current_status == target_status:
        return

    # Check forward order
    try:
        curr_idx = STATUS_HIERARCHY.index(current_status)
        target_idx = STATUS_HIERARCHY.index(target_status)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unknown status: current={current_status}, target={target_status}",
        )

    if target_status == "BOOKING_CONFIRMED":
        if not dossier_data.get("return_booking_number"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot advance to BOOKING_CONFIRMED without return_booking_number.",
            )

    elif target_status == "CUSTOMS_INSPECTED":
        if not dossier_data.get("supervision_committee_formed"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot advance to CUSTOMS_INSPECTED: Customs supervision committee must be formed.",
            )
        if not dossier_data.get("customs_outbound_declaration_no"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot advance to CUSTOMS_INSPECTED without customs_outbound_declaration_no.",
            )

    elif target_status == "LADEN_ON_BOARD":
        if not dossier_data.get("outbound_bl_number"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot advance to LADEN_ON_BOARD without outbound_bl_number.",
            )

    elif target_status == "COMPLETED_CLOSED":
        if current_status != "LADEN_ON_BOARD":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot close dossier directly: Cargo must be LADEN_ON_BOARD first.",
            )
