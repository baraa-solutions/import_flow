from datetime import date
from typing import Optional
from fastapi import HTTPException, status


def clean_container_number(container_number: str) -> str:
    if not container_number or not container_number.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Container number cannot be empty.",
        )
    return container_number.strip().upper()


def validate_deposit_amount(amount: float) -> None:
    if amount <= 0.0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Deposit amount in EGP must be greater than zero.",
        )


def validate_eir_submission(
    eir_number: str,
    eir_date: date,
    payment_date: date,
    condition: str,
    deduction_amount: float,
    deposit_amount: float,
) -> None:
    if not eir_number or not eir_number.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="EIR return number cannot be empty.",
        )

    if eir_date < payment_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="EIR empty return date cannot be earlier than deposit payment date.",
        )

    if condition == "SOUND_CLEAN" and deduction_amount > 0.0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Deduction amount cannot be applied when container condition is SOUND_CLEAN.",
        )

    if deduction_amount > deposit_amount:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Deduction amount cannot exceed the original deposit amount.",
        )


def validate_refund_submission(
    refund_amount: float,
    deposit_amount: float,
    deduction_amount: float,
    refund_date: date,
    eir_date: Optional[date],
) -> None:
    if refund_amount <= 0.0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Refund amount received in EGP must be greater than zero.",
        )

    if eir_date and refund_date < eir_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Refund received date cannot be earlier than EIR empty container return date.",
        )

    max_possible = deposit_amount - deduction_amount
    if refund_amount > deposit_amount + 0.01:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Refund amount ({refund_amount} EGP) cannot exceed original deposit ({deposit_amount} EGP).",
        )
