"""
Business Validators for Customs Special & Suspended Duty Regimes
"""

from datetime import date
from typing import Optional
from fastapi import HTTPException, status

from modules.customs_regimes.schemas import CustomsRegimeCreate, CustomsRegimeSettle, CustomsRegimeUpdate


class CustomsRegimesValidator:
    @staticmethod
    def validate_guarantee_dates(issue_date: Optional[date], expiry_date: Optional[date]) -> None:
        if issue_date and expiry_date and expiry_date < issue_date:
            raise HTTPException(
                status_code=422,
                detail="Guarantee expiry date cannot be earlier than issue date.",
            )

    @staticmethod
    def validate_re_export_dates(release_date: Optional[date], deadline: Optional[date]) -> None:
        if release_date and deadline and deadline < release_date:
            raise HTTPException(
                status_code=422,
                detail="Re-export deadline cannot be earlier than customs release date.",
            )

    @staticmethod
    def validate_guarantee_completeness(guarantee_amount: float, guarantee_type: Optional[str]) -> None:
        if guarantee_amount > 0 and not guarantee_type:
            raise HTTPException(
                status_code=422,
                detail="Guarantee type is required when guarantee amount is greater than zero.",
            )

    @staticmethod
    def validate_settlement(payload: CustomsRegimeSettle, regime_type: str) -> None:
        if regime_type in ("TEMPORARY_ADMISSION", "CUSTOMS_WAREHOUSE", "TRANSIT"):
            if not payload.actual_re_export_date and not payload.re_export_export_declaration_no:
                raise HTTPException(
                    status_code=422,
                    detail="Settling a temporary admission or transit regime requires actual re-export date or export declaration number.",
                )
        elif regime_type == "DRAWBACK":
            if not payload.drawback_reconciliation_ref and payload.drawback_refund_amount <= 0:
                raise HTTPException(
                    status_code=422,
                    detail="Settling a drawback regime requires drawback reconciliation reference or refund amount.",
                )
