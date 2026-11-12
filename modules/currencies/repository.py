from datetime import date
from modules.common.audit_stamp import SYSTEM_ACTOR, set_created_info
from typing import List, Optional

from sqlalchemy import or_
from sqlalchemy.orm import Session

from modules.common.clock import cairo_today
from modules.currencies.model import Currency, ExchangeRate
from modules.currencies.schemas import CurrencyCreate, CurrencyUpdate, ExchangeRateCreate


class CurrencyRepository:

    def __init__(self, db: Session):
        self.db = db

    def get_currency_by_id(self, currency_id: int) -> Optional[Currency]:
        return self.db.query(Currency).filter(Currency.currency_id == currency_id).first()

    def get_currency_by_code(self, currency_code: str) -> Optional[Currency]:
        return (
            self.db.query(Currency)
            .filter(Currency.currency_code == currency_code.upper().strip())
            .first()
        )

    def get_all_currencies(self, include_inactive: bool = False, search: Optional[str] = None) -> List[Currency]:
        query = self.db.query(Currency)

        if not include_inactive:
            query = query.filter(Currency.is_active.is_(True))

        if search:
            pattern = f"%{search.strip()}%"
            query = query.filter(
                or_(
                    Currency.currency_code.ilike(pattern),
                    Currency.currency_name.ilike(pattern),
                )
            )

        return query.order_by(Currency.is_base_currency.desc(), Currency.currency_code.asc()).all()

    def create_currency(self, data: CurrencyCreate, actor: str = SYSTEM_ACTOR) -> Currency:
        currency = Currency(
            currency_code=data.currency_code.upper().strip(),
            currency_name=data.currency_name.strip(),
            currency_symbol=data.currency_symbol.strip(),
            is_base_currency=data.is_base_currency,
            decimal_places=data.decimal_places,
            is_active=True,
        )
        set_created_info(currency, actor)
        self.db.add(currency)
        self.db.commit()
        self.db.refresh(currency)
        return currency

    def update_currency(self, currency: Currency, data: CurrencyUpdate) -> Currency:
        update_data = data.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            if value is not None and isinstance(value, str):
                value = value.strip()
            setattr(currency, field, value)

        self.db.commit()
        self.db.refresh(currency)
        return currency

    def soft_delete_currency(self, currency: Currency) -> Currency:
        currency.is_active = False
        self.db.commit()
        self.db.refresh(currency)
        return currency

    def restore_currency(self, currency: Currency) -> Currency:
        currency.is_active = True
        self.db.commit()
        self.db.refresh(currency)
        return currency

    # Exchange Rates
    def add_exchange_rate(self, data: ExchangeRateCreate) -> ExchangeRate:
        if data.replace:
            (
                self.db.query(ExchangeRate)
                .filter(
                    ExchangeRate.currency_id == data.currency_id,
                    ExchangeRate.effective_date == data.effective_date,
                    ExchangeRate.is_active.is_(True),
                )
                .update({"is_active": False})
            )
        rate = ExchangeRate(
            currency_id=data.currency_id,
            commercial_rate=data.commercial_rate,
            customs_rate=data.customs_rate,
            effective_date=data.effective_date,
            created_by=data.created_by or "System",
            is_active=True,
        )
        self.db.add(rate)
        self.db.commit()
        self.db.refresh(rate)
        return rate

    def get_rate_by_id(self, rate_id: int) -> Optional[ExchangeRate]:
        return self.db.query(ExchangeRate).filter(ExchangeRate.rate_id == rate_id).first()

    def get_latest_rate(self, currency_id: int, target_date: Optional[date] = None) -> Optional[ExchangeRate]:
        query = self.db.query(ExchangeRate).filter(
            ExchangeRate.currency_id == currency_id,
            ExchangeRate.is_active.is_(True),
        )
        ref_date = target_date or cairo_today()
        query = query.filter(ExchangeRate.effective_date <= ref_date)

        return query.order_by(ExchangeRate.effective_date.desc(), ExchangeRate.created_at.desc()).first()

    def get_rates_history(self, currency_id: int) -> List[ExchangeRate]:
        return (
            self.db.query(ExchangeRate)
            .filter(ExchangeRate.currency_id == currency_id)
            .order_by(ExchangeRate.effective_date.desc(), ExchangeRate.created_at.desc())
            .all()
        )
