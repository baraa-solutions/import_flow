"""
Pydantic Schemas for Trade Finance
"""

from datetime import date, datetime
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field
from modules.common.legacy_rows import LegacyRowTolerantModel, read_model


class InstrumentTypeEnum(str, Enum):
    LC = "LC"                              # اعتماد مستندي
    CAD = "CAD"                            # تحصيل مستندي / مستندات برسم التحصيل
    ADVANCE_PAYMENT = "ADVANCE_PAYMENT"    # دفعة مقدمة
    OPEN_ACCOUNT = "OPEN_ACCOUNT"          # حساب مفتوح / تسهيلات موردين


class InstrumentStatusEnum(str, Enum):
    DRAFT = "DRAFT"                        # مسودة
    ISSUED = "ISSUED"                      # تم الفتح / الإصدار
    ACCEPTED = "ACCEPTED"                  # مقبول
    SETTLED = "SETTLED"                    # مسدد بالكامل
    CANCELLED = "CANCELLED"                # ملغى


class BankChargeTypeEnum(str, Enum):
    ISSUANCE_COMMISSION = "ISSUANCE_COMMISSION"      # عمولة فتح الاعتماد
    AMENDMENT_FEE = "AMENDMENT_FEE"                  # مصاريف تعديل الاعتماد
    SWIFT_CHARGE = "SWIFT_CHARGE"                    # مصاريف سويفت
    PAYMENT_COMMISSION = "PAYMENT_COMMISSION"        # عمولة سداد
    CONFIRMATION_FEE = "CONFIRMATION_FEE"            # مصاريف تعزيز
    DISCREPANCY_FEE = "DISCREPANCY_FEE"              # مصاريف تحفظات مستندية


class VarianceNatureEnum(str, Enum):
    UNFAVORABLE_LOSS = "UNFAVORABLE_LOSS"  # خسارة فروق عملة
    FAVORABLE_GAIN = "FAVORABLE_GAIN"      # أرباح فروق عملة
    NEUTRAL = "NEUTRAL"                    # تعادل


# -------------------------------------------------------------
# Bank Charges Schemas
# -------------------------------------------------------------
class LcBankChargeCreate(BaseModel):
    charge_type: str = Field(..., description="Type of bank charge")
    currency: str = Field(default="EGP", description="Charge currency")
    amount: float = Field(..., gt=0.0, description="Charge amount in original currency")
    amount_egp: float = Field(..., gt=0.0, description="Charge amount equivalent in EGP")
    debit_date: date = Field(..., description="Date charged by bank")
    debit_account: Optional[str] = Field(None, description="Bank account debited")
    swift_reference: Optional[str] = Field(None, description="SWIFT transaction reference")
    notes: Optional[str] = None


class LcBankChargeUpdate(BaseModel):
    charge_type: Optional[str] = None
    currency: Optional[str] = None
    amount: Optional[float] = Field(None, gt=0.0)
    amount_egp: Optional[float] = Field(None, gt=0.0)
    debit_date: Optional[date] = None
    debit_account: Optional[str] = None
    swift_reference: Optional[str] = None
    notes: Optional[str] = None


@read_model
class LcBankChargeResponse(LegacyRowTolerantModel):
    id: int
    finance_instrument_id: int
    charge_type: str
    currency: str
    amount: float
    amount_egp: float
    debit_date: date
    debit_account: Optional[str] = None
    swift_reference: Optional[str] = None
    notes: Optional[str] = None
    is_active: bool = True
    created_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


# -------------------------------------------------------------
# FX Hedging & Variance Schemas
# -------------------------------------------------------------
class FxHedgingAndVarianceCreate(BaseModel):
    foreign_currency: str = Field(default="USD", description="Foreign currency")
    original_amount: float = Field(..., gt=0.0, description="Amount in foreign currency")
    booking_date: date = Field(..., description="LC opening / booking date")
    booking_rate: float = Field(..., gt=0.0, description="Exchange rate at booking")
    settlement_date: Optional[date] = Field(None, description="Actual settlement date")
    settlement_rate: Optional[float] = Field(None, gt=0.0, description="Exchange rate at settlement")
    hedging_contract_ref: Optional[str] = Field(None, description="Hedging contract reference")
    notes: Optional[str] = None


class FxHedgingAndVarianceUpdate(BaseModel):
    settlement_date: Optional[date] = None
    settlement_rate: Optional[float] = Field(None, gt=0.0)
    hedging_contract_ref: Optional[str] = None
    notes: Optional[str] = None


@read_model
class FxHedgingAndVarianceResponse(LegacyRowTolerantModel):
    id: int
    finance_instrument_id: int
    foreign_currency: str
    original_amount: float
    booking_date: date
    booking_rate: float
    booking_total_egp: float
    settlement_date: Optional[date] = None
    settlement_rate: Optional[float] = None
    settlement_total_egp: Optional[float] = None
    hedging_contract_ref: Optional[str] = None
    variance_amount_egp: float = 0.0
    variance_nature: str = "NEUTRAL"
    notes: Optional[str] = None
    is_active: bool = True
    created_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


# -------------------------------------------------------------
# Finance Instrument Schemas
# -------------------------------------------------------------
class ImportFinanceInstrumentCreate(BaseModel):
    instrument_type: str = Field(..., description="LC, CAD, ADVANCE_PAYMENT, OPEN_ACCOUNT")
    instrument_number: str = Field(..., description="LC or instrument reference number")
    import_file_id: int = Field(..., description="Import file ID")
    issuing_bank: str = Field(..., description="Issuing bank name")
    advising_bank: Optional[str] = Field(None, description="Advising bank name")
    currency: str = Field(default="USD", description="Currency")
    amount: float = Field(..., gt=0.0, description="Financial amount")
    issue_date: Optional[date] = Field(None, description="Issuance date")
    expiry_date: Optional[date] = Field(None, description="Expiry date")
    shipment_deadline: Optional[date] = Field(None, description="Latest shipment date")
    presentation_period_days: int = Field(default=21, ge=1, le=180, description="Presentation days")
    payment_terms: Optional[str] = None
    tolerance_percentage: float = Field(default=0.0, ge=0.0, le=100.0, description="Tolerance %")
    notes: Optional[str] = None


class ImportFinanceInstrumentUpdate(BaseModel):
    issuing_bank: Optional[str] = None
    advising_bank: Optional[str] = None
    currency: Optional[str] = None
    amount: Optional[float] = Field(None, gt=0.0)
    issue_date: Optional[date] = None
    expiry_date: Optional[date] = None
    shipment_deadline: Optional[date] = None
    presentation_period_days: Optional[int] = Field(None, ge=1, le=180)
    payment_terms: Optional[str] = None
    status: Optional[str] = None
    tolerance_percentage: Optional[float] = Field(None, ge=0.0, le=100.0)
    notes: Optional[str] = None


@read_model
class ImportFinanceInstrumentResponse(LegacyRowTolerantModel):
    id: int
    instrument_type: str
    instrument_number: str
    import_file_id: int
    issuing_bank: str
    advising_bank: Optional[str] = None
    currency: str
    amount: float
    issue_date: Optional[date] = None
    expiry_date: Optional[date] = None
    shipment_deadline: Optional[date] = None
    presentation_period_days: int = 21
    payment_terms: Optional[str] = None
    status: str = "DRAFT"
    tolerance_percentage: float = 0.0
    notes: Optional[str] = None
    is_active: bool = True
    created_by: Optional[str] = "system"
    updated_by: Optional[str] = "system"
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    charges: List[LcBankChargeResponse] = []
    fx_records: List[FxHedgingAndVarianceResponse] = []

    model_config = ConfigDict(from_attributes=True)


class ImportFinanceInstrumentListResponse(BaseModel):
    total: int
    items: List[ImportFinanceInstrumentResponse]
