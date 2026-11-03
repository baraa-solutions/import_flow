"""
Business Validators for Cargo Claims, Time-Bars & Legal Reservations
"""

from datetime import date
from typing import Optional
from fastapi import HTTPException, status


class LegalClaimsValidator:
    @staticmethod
    def validate_delivery_and_time_bar(delivery_date: Optional[date], time_bar_date: date) -> None:
        if delivery_date and time_bar_date < delivery_date:
            raise HTTPException(
                status_code=422,
                detail="Time-bar statute of limitations date cannot be earlier than delivery date.",
            )

    @staticmethod
    def validate_survey(survey_date: date, delivery_date: Optional[date]) -> None:
        if delivery_date and survey_date < delivery_date:
            raise HTTPException(
                status_code=422,
                detail="Joint survey date cannot be earlier than cargo delivery date.",
            )

    @staticmethod
    def validate_settlement(claimed_amount: float, settled_amount: float, settlement_date: Optional[date]) -> None:
        if settled_amount < 0:
            raise HTTPException(
                status_code=422,
                detail="Settled amount cannot be negative.",
            )
        if not settlement_date:
            raise HTTPException(
                status_code=422,
                detail="Settlement date is required when settling a legal claim.",
            )
