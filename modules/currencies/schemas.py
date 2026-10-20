from datetime import date, datetime
from typing import Optional, List

from pydantic import BaseModel, Field, ConfigDict


# Currency Schemas
class CurrencyBase(BaseModel):
    currency_code: str = Field(..., min_length=3, max_length=3, description="ISO 4217 code e.g. USD, EUR, GBP, EGP, CNY")
    currency_name: str = Field(..., min_length=2, max_length=100)
    currency_symbol: str = Field(default="", max_length=10)
    is_base_currency: bool = Field(False)
    decimal_places: int = Field(2, ge=0, le=4)


class CurrencyCreate(CurrencyBase):
    pass


class CurrencyUpdate(BaseModel):
    currency_name: Optional[str] = Field(None, min_length=2, max_length=100)
    currency_symbol: Optional[str] = Field(None, max_length=10)
    is_base_currency: Optional[bool] = None
    decimal_places: Optional[int] = Field(None, ge=0, le=4)
    is_active: Optional[bool] = None


# Exchange Rate Schemas
class ExchangeRateBase(BaseModel):
    currency_id: int
    commercial_rate: float = Field(..., gt=0, description="Commercial Bank Rate to EGP")
    customs_rate: float = Field(..., gt=0, description="Official Egyptian Customs Exchange Rate to EGP")
    effective_date: date
    created_by: Optional[str] = Field(None, description="User or system who recorded the exchange rate")


class ExchangeRateCreate(ExchangeRateBase):
    replace: bool = Field(False, description="Replace existing active rate for same currency and effective date")


class ExchangeRateResponse(ExchangeRateBase):
    rate_id: int
    is_active: bool
    created_at: datetime
    created_by: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class CurrencyResponse(CurrencyBase):
    currency_id: int
    is_active: bool
    created_at: datetime
    updated_at: datetime
    latest_commercial_rate: Optional[float] = None
    latest_customs_rate: Optional[float] = None
    exchange_rates: Optional[List[ExchangeRateResponse]] = None

    model_config = ConfigDict(from_attributes=True)


# ─── Multi-Currency Conversion Engine Schemas ─────────────────────────────────

class CurrencyConversionRequest(BaseModel):
    amount: float = Field(..., gt=0, description="Amount to convert")
    from_currency_code: str = Field(..., min_length=3, max_length=3, description="Source currency ISO code")
    to_currency_code: str = Field("EGP", min_length=3, max_length=3, description="Target currency ISO code")
    rate_type: str = Field("commercial", description="'commercial' for Bank Rate or 'customs' for Customs Rate")
    as_of_date: Optional[date] = Field(None, description="Historical date for rate lookup; defaults to latest rate")


class CurrencyConversionResponse(BaseModel):
    amount: float
    from_currency_code: str
    to_currency_code: str
    rate_type: str
    applied_rate: float
    converted_amount: float
    base_currency_equivalent_egp: float
    rate_date: Optional[date] = None
    exchange_rate_id: Optional[int] = None
    summary_ar: str


# ─── Foreign Exchange (FX) Gain / Loss Engine Schemas ─────────────────────────

class ExchangeGainLossRequest(BaseModel):
    foreign_amount: float = Field(..., gt=0, description="Amount in foreign currency (e.g. 10000 USD)")
    currency_code: str = Field(..., min_length=3, max_length=3, description="Foreign currency code")
    initial_rate: float = Field(..., gt=0, description="Initial rate at PO/Invoice booking date (EGP per FX)")
    settlement_rate: float = Field(..., gt=0, description="Settlement rate at Payment/Closing date (EGP per FX)")
    initial_date: Optional[date] = Field(None, description="Booking date")
    settlement_date: Optional[date] = Field(None, description="Settlement date")


class ExchangeGainLossResponse(BaseModel):
    foreign_amount: float
    currency_code: str
    initial_rate: float
    settlement_rate: float
    initial_amount_egp: float
    settlement_amount_egp: float
    variance_egp: float
    is_gain: bool
    status_label: str  # "ربح فروق عملة" or "خسارة فروق عملة" or "تعادل"
    percentage_change: float
    summary_ar: str
