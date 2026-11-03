"""
Business Validators for Preferential Trade Agreements & Origin Verifications
"""

from datetime import date
from typing import Optional
from fastapi import HTTPException, status


class TradeAgreementsValidator:
    @staticmethod
    def validate_dates(issuing_date: date, expiry_date: Optional[date]) -> None:
        if expiry_date and expiry_date < issuing_date:
            raise HTTPException(
                status_code=422,
                detail="Certificate expiry date cannot be earlier than issuing date.",
            )

    @staticmethod
    def validate_escrow(
        provisional_escrow_required: bool,
        provisional_escrow_amount: float,
        provisional_escrow_deadline: Optional[date],
        issuing_date: Optional[date],
    ) -> None:
        if provisional_escrow_required:
            if provisional_escrow_amount <= 0:
                raise HTTPException(
                    status_code=422,
                    detail="Provisional escrow amount must be greater than zero when escrow is required.",
                )
            if provisional_escrow_deadline and issuing_date and provisional_escrow_deadline < issuing_date:
                raise HTTPException(
                    status_code=422,
                    detail="Provisional escrow deadline cannot be earlier than certificate issue date.",
                )

    @staticmethod
    def validate_original_verification(
        original_received_date: date,
        issuing_date: date,
        provisional_escrow_refunded: bool,
        refund_date: Optional[date],
    ) -> None:
        if original_received_date < issuing_date:
            raise HTTPException(
                status_code=422,
                detail="Original certificate receipt date cannot be earlier than issuing date.",
            )
        if provisional_escrow_refunded and not refund_date:
            raise HTTPException(
                status_code=422,
                detail="Refund date is required when provisional escrow is marked as refunded.",
            )
