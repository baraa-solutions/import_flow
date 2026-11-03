"""
Validation Rules for Refundable Deposits Ledger
"""

from typing import Optional
from fastapi import HTTPException, status
from modules.deposits_recovery.repository import RefundableDepositsRepository


def validate_deposit_code_unique(
    repo: RefundableDepositsRepository,
    code: str,
    current_id: Optional[int] = None,
) -> None:
    existing = repo.get_by_code(code)
    if existing and (current_id is None or existing.id != current_id):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Deposit code '{code}' already exists.",
        )


def validate_amounts(
    deposit_amount: float,
    refunded_amount: float,
    deduction_amount: float,
) -> None:
    if deposit_amount < 0 or refunded_amount < 0 or deduction_amount < 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Amounts cannot be negative.",
        )
    if (refunded_amount + deduction_amount) > (deposit_amount + 0.01):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Sum of refunded ({refunded_amount}) and deducted ({deduction_amount}) cannot exceed total deposit ({deposit_amount}).",
        )


def validate_bank_lg_requirements(deposit_type: str, lg_number: Optional[str]) -> None:
    if deposit_type == "BANK_LETTER_OF_GUARANTEE" and not lg_number:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Letter of Guarantee number is required for BANK_LETTER_OF_GUARANTEE deposit type.",
        )


def validate_eir_return_data(container_number: str, eir_number: str) -> None:
    if not container_number or not container_number.strip():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Container number is mandatory for EIR empty return registration.",
        )
    if not eir_number or not eir_number.strip():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="EIR document number is mandatory.",
        )
