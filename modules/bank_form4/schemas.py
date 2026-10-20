from datetime import date, datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field
from modules.common.legacy_rows import LegacyRowTolerantModel, read_model


class BankForm4Create(BaseModel):
    import_file_id: int = Field(..., description="ID of the associated import file")
    import_file_code: Optional[str] = Field(None, description="Import file business code e.g. IMP-2026-0001")
    bank_id: Optional[int] = Field(None, description="External service provider ID for the bank")
    bank_name: str = Field(..., min_length=2, max_length=200, description="Executing Egyptian bank name")
    bank_branch: Optional[str] = Field(None, max_length=150)
    bank_officer_name: Optional[str] = Field(None, max_length=150)
    financing_mode: str = Field("CAD", description="Financing mode: CAD, LC, ADVANCE, OPEN_ACCOUNT")
    currency: str = Field("USD", description="Currency code: USD, EUR, EGP")
    fx_amount: float = Field(..., gt=0.0, description="FX financing amount (must be positive)")
    fx_allotment_status: str = Field("PENDING", description="FX allotment status: PENDING, ALLOTTED, TRANSFERRED")
    swift_reference: Optional[str] = Field(None, description="SWIFT reference or message transaction ID")
    form4_number: Optional[str] = Field(None, description="Official Bank Form 4 registered number")
    form4_issue_date: Optional[date] = None
    nafeza_transmission_status: str = Field("AWAITING_BANK", description="Nafeza transmission status: AWAITING_BANK, TRANSMITTED, VALUE_MISMATCH, ACCEPTED")
    bank_delay_days: int = Field(0, ge=0, description="Days delayed by bank")
    daily_financing_cost: float = Field(0.0, ge=0.0, description="Financing delay cost per day")
    total_financing_delay_cost: Optional[float] = Field(None, ge=0.0)
    notes: Optional[str] = None


class BankForm4Update(BaseModel):
    bank_id: Optional[int] = None
    bank_name: Optional[str] = Field(None, min_length=2, max_length=200)
    bank_branch: Optional[str] = None
    bank_officer_name: Optional[str] = None
    financing_mode: Optional[str] = None
    currency: Optional[str] = None
    fx_amount: Optional[float] = Field(None, gt=0.0)
    fx_allotment_status: Optional[str] = None
    swift_reference: Optional[str] = None
    form4_number: Optional[str] = None
    form4_issue_date: Optional[date] = None
    nafeza_transmission_status: Optional[str] = None
    bank_delay_days: Optional[int] = Field(None, ge=0)
    daily_financing_cost: Optional[float] = Field(None, ge=0.0)
    total_financing_delay_cost: Optional[float] = Field(None, ge=0.0)
    notes: Optional[str] = None


class DelayCostCalculation(BaseModel):
    bank_delay_days: Optional[int] = Field(None, ge=0, description="Number of delay days")
    daily_financing_cost: Optional[float] = Field(None, ge=0.0, description="Direct daily financing cost")
    annual_interest_rate: Optional[float] = Field(None, ge=0.0, description="Annual interest/financing rate percentage e.g. 15.0 for 15%")


class DelayCostCalculationResult(BaseModel):
    form4_id: int
    fx_amount: float
    currency: str
    bank_delay_days: int
    daily_financing_cost: float
    total_financing_delay_cost: float


class NafezaTransmissionUpdate(BaseModel):
    nafeza_transmission_status: str = Field(..., description="AWAITING_BANK, TRANSMITTED, VALUE_MISMATCH, ACCEPTED")
    form4_number: Optional[str] = None
    form4_issue_date: Optional[date] = None
    notes: Optional[str] = None


@read_model
class BankForm4Response(LegacyRowTolerantModel):
    form4_id: int
    import_file_id: int
    import_file_code: str
    bank_id: Optional[int] = None
    bank_name: str
    bank_branch: Optional[str] = None
    bank_officer_name: Optional[str] = None
    financing_mode: str
    currency: str
    fx_amount: float
    fx_allotment_status: str
    swift_reference: Optional[str] = None
    form4_number: Optional[str] = None
    form4_issue_date: Optional[date] = None
    nafeza_transmission_status: str
    bank_delay_days: int = 0
    daily_financing_cost: float = 0.0
    total_financing_delay_cost: float = 0.0
    notes: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    created_by: Optional[str] = None
    updated_by: Optional[str] = None
    is_active: bool = True

    model_config = ConfigDict(from_attributes=True)


class BankForm4ListResponse(BaseModel):
    total: int
    items: List[BankForm4Response]
