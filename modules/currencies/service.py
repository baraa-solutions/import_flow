import time
import threading
from datetime import date, datetime
from typing import List, Optional, Dict, Tuple

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.currencies.model import Currency, ExchangeRate
from modules.currencies.repository import CurrencyRepository
from modules.currencies.schemas import (
    CurrencyCreate,
    CurrencyResponse,
    CurrencyUpdate,
    ExchangeRateCreate,
    ExchangeRateResponse,
)
from modules.currencies.validators import CurrencyValidator

_CURRENCIES_CACHE: Dict[bool, Tuple[float, List[CurrencyResponse]]] = {}
_RATE_CACHE: Dict[Tuple[str, str, date], Tuple[float, float, Optional[date], Optional[int]]] = {}
_CURRENCY_CACHE_LOCK = threading.Lock()
_CURRENCY_CACHE_TTL = 300.0  # 5 minutes


def clear_currency_cache():
    """Invalidates the in-memory currency and exchange rate cache."""
    with _CURRENCY_CACHE_LOCK:
        _CURRENCIES_CACHE.clear()
        _RATE_CACHE.clear()


class CurrencyService:

    def __init__(self, db: Session):
        self.db = db
        self.repo = CurrencyRepository(db)
        self.validator = CurrencyValidator(db)

    def get_all_currencies(
        self, include_inactive: bool = False, search: Optional[str] = None
    ) -> List[CurrencyResponse]:
        now = time.time()
        # Fast-path cache for standard list fetches without ad-hoc search
        if not search:
            with _CURRENCY_CACHE_LOCK:
                cached = _CURRENCIES_CACHE.get(include_inactive)
                if cached is not None:
                    cached_time, cached_items = cached
                    if now - cached_time < _CURRENCY_CACHE_TTL:
                        return list(cached_items)

        currencies = self.repo.get_all_currencies(include_inactive=include_inactive, search=search)
        result = []
        for c in currencies:
            latest_rate = self.repo.get_latest_rate(c.currency_id)
            c_resp = CurrencyResponse(
                currency_id=c.currency_id,
                currency_code=c.currency_code,
                currency_name=c.currency_name,
                currency_symbol=c.currency_symbol,
                is_base_currency=c.is_base_currency,
                decimal_places=c.decimal_places,
                is_active=c.is_active,
                created_at=c.created_at,
                updated_at=c.updated_at,
                latest_commercial_rate=float(latest_rate.commercial_rate) if latest_rate else (1.0 if c.is_base_currency else None),
                latest_customs_rate=float(latest_rate.customs_rate) if latest_rate else (1.0 if c.is_base_currency else None),
            )
            result.append(c_resp)

        if not search:
            with _CURRENCY_CACHE_LOCK:
                _CURRENCIES_CACHE[include_inactive] = (now, list(result))

        return result

    def get_currency_by_id(self, currency_id: int) -> CurrencyResponse:
        c = self.validator.validate_currency_exists(currency_id)
        latest_rate = self.repo.get_latest_rate(c.currency_id)
        rates_history = self.repo.get_rates_history(c.currency_id)

        rates_resp = [
            ExchangeRateResponse(
                rate_id=r.rate_id,
                currency_id=r.currency_id,
                commercial_rate=float(r.commercial_rate),
                customs_rate=float(r.customs_rate),
                effective_date=r.effective_date,
                is_active=r.is_active,
                created_at=r.created_at,
                created_by=r.created_by,
            )
            for r in rates_history
        ]

        return CurrencyResponse(
            currency_id=c.currency_id,
            currency_code=c.currency_code,
            currency_name=c.currency_name,
            currency_symbol=c.currency_symbol,
            is_base_currency=c.is_base_currency,
            decimal_places=c.decimal_places,
            is_active=c.is_active,
            created_at=c.created_at,
            updated_at=c.updated_at,
            latest_commercial_rate=float(latest_rate.commercial_rate) if latest_rate else (1.0 if c.is_base_currency else None),
            latest_customs_rate=float(latest_rate.customs_rate) if latest_rate else (1.0 if c.is_base_currency else None),
            exchange_rates=rates_resp,
        )

    def create_currency(self, data: CurrencyCreate) -> Currency:
        self.validator.validate_no_duplicate_code(data.currency_code)
        created = self.repo.create_currency(data)
        clear_currency_cache()
        return created

    def update_currency(self, currency_id: int, data: CurrencyUpdate) -> Currency:
        currency = self.validator.validate_currency_exists(currency_id)
        updated = self.repo.update_currency(currency, data)
        clear_currency_cache()
        return updated

    def soft_delete_currency(self, currency_id: int) -> Currency:
        currency = self.validator.validate_currency_exists(currency_id)
        deleted = self.repo.soft_delete_currency(currency)
        clear_currency_cache()
        return deleted

    def restore_currency(self, currency_id: int) -> Currency:
        currency = self.validator.validate_currency_exists(currency_id)
        restored = self.repo.restore_currency(currency)
        clear_currency_cache()
        return restored

    def add_exchange_rate(self, data: ExchangeRateCreate) -> ExchangeRateResponse:
        self.validator.validate_currency_exists(data.currency_id)
        rate = self.repo.add_exchange_rate(data)
        clear_currency_cache()
        return ExchangeRateResponse(
            rate_id=rate.rate_id,
            currency_id=rate.currency_id,
            commercial_rate=float(rate.commercial_rate),
            customs_rate=float(rate.customs_rate),
            effective_date=rate.effective_date,
            is_active=rate.is_active,
            created_at=rate.created_at,
            created_by=rate.created_by,
        )

    # ─── Multi-Currency Conversion Engine Methods ─────────────────────────────

    def _get_rate_to_egp(
        self, currency_code: str, rate_type: str = "commercial", as_of_date: Optional[date] = None
    ) -> tuple[float, Optional[date], Optional[int]]:
        code = currency_code.upper().strip()
        ref_date = as_of_date or date.today()
        if code == "EGP":
            return 1.0, ref_date, None

        cache_key = (code, rate_type, ref_date)
        now = time.time()
        with _CURRENCY_CACHE_LOCK:
            cached_rate = _RATE_CACHE.get(cache_key)
            if cached_rate is not None:
                cached_time, rate_val, eff_date, rate_id = cached_rate
                if now - cached_time < _CURRENCY_CACHE_TTL:
                    return rate_val, eff_date, rate_id

        currency = self.repo.get_currency_by_code(code)
        if not currency:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "code": "CURRENCY_NOT_FOUND",
                    "message": f"العملة الكود '{code}' غير مسجلة في النظام.",
                    "currency": code,
                },
            )

        rate_obj = self.repo.get_latest_rate(currency.currency_id, target_date=ref_date)
        if not rate_obj:
            as_of_str = ref_date.isoformat() if isinstance(ref_date, (date, datetime)) else str(ref_date)
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "code": "CURRENCY_RATE_MISSING",
                    "message": f"لا يوجد سعر صرف مسجل للعملة '{code}' من نوع '{rate_type}' بتاريخ {ref_date}.",
                    "currency": code,
                    "rate_type": rate_type,
                    "as_of_date": as_of_str,
                },
            )

        rate_val = float(rate_obj.commercial_rate) if rate_type == "commercial" else float(rate_obj.customs_rate)
        with _CURRENCY_CACHE_LOCK:
            _RATE_CACHE[cache_key] = (now, rate_val, rate_obj.effective_date, rate_obj.rate_id)
        return rate_val, rate_obj.effective_date, rate_obj.rate_id

    def convert_currency(
        self,
        amount: float,
        from_currency_code: str,
        to_currency_code: str = "EGP",
        rate_type: str = "commercial",
        as_of_date: Optional[date] = None,
    ):
        from modules.currencies.schemas import CurrencyConversionResponse

        if amount <= 0:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="المبلغ المراد تحويله يجب أن يكون أكبر من صفر.",
            )

        from_code = from_currency_code.upper().strip()
        to_code = to_currency_code.upper().strip()

        from_rate_egp, from_date, from_rate_id = self._get_rate_to_egp(from_code, rate_type=rate_type, as_of_date=as_of_date)
        to_rate_egp, _, _ = self._get_rate_to_egp(to_code, rate_type=rate_type, as_of_date=as_of_date)

        base_egp = amount * from_rate_egp
        converted_amount = base_egp / to_rate_egp
        applied_rate = from_rate_egp / to_rate_egp

        rate_type_label = "البنك التجاري" if rate_type == "commercial" else "الجمارك الرسمي"
        summary_ar = (
            f"تم تحويل {amount:,.2f} {from_code} إلى {converted_amount:,.2f} {to_code} "
            f"بسعر صرف {applied_rate:.4f} ({rate_type_label})"
        )

        return CurrencyConversionResponse(
            amount=amount,
            from_currency_code=from_code,
            to_currency_code=to_code,
            rate_type=rate_type,
            applied_rate=round(applied_rate, 4),
            converted_amount=round(converted_amount, 2),
            base_currency_equivalent_egp=round(base_egp, 2),
            rate_date=from_date,
            exchange_rate_id=from_rate_id,
            summary_ar=summary_ar,
        )

    def calculate_gain_loss(
        self,
        foreign_amount: float,
        currency_code: str,
        initial_rate: float,
        settlement_rate: float,
        initial_date: Optional[date] = None,
        settlement_date: Optional[date] = None,
    ):
        from modules.currencies.schemas import ExchangeGainLossResponse

        if foreign_amount <= 0 or initial_rate <= 0 or settlement_rate <= 0:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="المبالغ وأسعار الصرف يجب أن تكون أكبر من صفر.",
            )

        code = currency_code.upper().strip()
        initial_egp = foreign_amount * initial_rate
        settlement_egp = foreign_amount * settlement_rate
        variance_egp = settlement_egp - initial_egp
        pct_change = ((settlement_rate - initial_rate) / initial_rate) * 100

        # For import liabilities: paying lower rate = GAIN (وفر), paying higher rate = LOSS (تكلفة أعلى)
        if variance_egp < 0:
            is_gain = True
            status_label = "ربح فروق عملة"
            summary_ar = f"انخفاض سعر الصرف حقق وفر / ربح فروق عملة بقيمة {abs(variance_egp):,.2f} جنيه مصري ({abs(pct_change):.2f}%-)"
        elif variance_egp > 0:
            is_gain = False
            status_label = "خسارة فروق عملة"
            summary_ar = f"ارتفاع سعر الصرف سبب زيادة تكلفة / خسارة فروق عملة بقيمة {variance_egp:,.2f} جنيه مصري ({pct_change:.2f}%+)"
        else:
            is_gain = False
            status_label = "تعادل"
            summary_ar = "تطابق سعر الربط مع سعر التسوية — لا توجد فروق أسعار عملات."

        return ExchangeGainLossResponse(
            foreign_amount=foreign_amount,
            currency_code=code,
            initial_rate=initial_rate,
            settlement_rate=settlement_rate,
            initial_amount_egp=round(initial_egp, 2),
            settlement_amount_egp=round(settlement_egp, 2),
            variance_egp=round(variance_egp, 2),
            is_gain=is_gain,
            status_label=status_label,
            percentage_change=round(pct_change, 2),
            summary_ar=summary_ar,
        )
