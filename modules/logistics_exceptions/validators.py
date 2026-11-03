"""
Validation rules for Logistics Exceptions
"""

from datetime import date
from typing import Optional
from fastapi import HTTPException, status
from modules.logistics_exceptions.repository import LogisticsExceptionsRepository


def validate_exception_code_unique(
    repo: LogisticsExceptionsRepository,
    code: str,
    current_id: Optional[int] = None,
) -> None:
    existing = repo.get_by_code(code)
    if existing and (current_id is None or existing.id != current_id):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Exception code '{code}' already exists.",
        )


def validate_acid_dates(
    original_expiry: Optional[date],
    adjusted_expiry: Optional[date],
) -> None:
    if original_expiry and adjusted_expiry:
        if adjusted_expiry < original_expiry:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Adjusted ACID expiry date cannot be earlier than the original expiry date.",
            )


def validate_valuation_dispute(
    customs_val: Optional[float],
    declared_val: Optional[float],
    dispute_amount: Optional[float],
) -> None:
    if customs_val is not None and declared_val is not None:
        if customs_val < declared_val:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Customs assessed value must typically exceed declared value in a valuation dispute.",
            )
    if dispute_amount is not None and dispute_amount < 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Valuation dispute amount must be non-negative.",
        )


def validate_resolution_requirements(resolution_strategy: str) -> None:
    if not resolution_strategy or len(resolution_strategy.strip()) < 5:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="A substantive resolution strategy description is mandatory before closing or resolving an exception.",
        )
