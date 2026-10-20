from datetime import date, datetime
from typing import Optional

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.currencies.model import Currency, ExchangeRate
from modules.currencies.repository import CurrencyRepository


class CurrencyValidator:

    def __init__(self, db: Session):
        self.repo = CurrencyRepository(db)

    def validate_no_duplicate_code(self, currency_code: str, exclude_id: int = None):
        existing = self.repo.get_currency_by_code(currency_code)
        if existing and (exclude_id is None or existing.currency_id != exclude_id):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Currency with ISO code '{currency_code.upper()}' already exists.",
            )

    def validate_currency_exists(self, currency_id: int):
        currency = self.repo.get_currency_by_id(currency_id)
        if not currency:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Currency with ID {currency_id} not found.",
            )
        return currency

    def validate_no_second_base_currency(self, is_base_currency: Optional[bool], exclude_id: Optional[int] = None):
        if not is_base_currency:
            return
        base_currencies = (
            self.repo.db.query(Currency)
            .filter(Currency.is_base_currency.is_(True), Currency.is_active.is_(True))
            .all()
        )
        for existing in base_currencies:
            if exclude_id is None or existing.currency_id != exclude_id:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail={
                        "code": "CURRENCY_BASE_EXISTS",
                        "message": f"A base currency ({existing.currency_code}) already exists; cannot set a second base currency.",
                        "base_currency": existing.currency_code,
                    },
                )

    def validate_no_active_rate(self, currency_id: int, effective_date: date, replace: bool = False) -> Optional[ExchangeRate]:
        existing = (
            self.repo.db.query(ExchangeRate)
            .filter(
                ExchangeRate.currency_id == currency_id,
                ExchangeRate.effective_date == effective_date,
                ExchangeRate.is_active.is_(True),
            )
            .first()
        )
        if existing and not replace:
            currency = self.repo.get_currency_by_id(currency_id)
            code = currency.currency_code if currency else str(currency_id)
            eff_str = effective_date.isoformat() if isinstance(effective_date, (date, datetime)) else str(effective_date)
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "code": "CURRENCY_RATE_EXISTS",
                    "message": f"An active exchange rate already exists for {code} on {eff_str}. Pass replace=true to overwrite.",
                    "currency": code,
                    "effective_date": eff_str,
                },
            )
        return existing
