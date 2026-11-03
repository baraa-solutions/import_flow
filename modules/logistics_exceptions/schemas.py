"""
Pydantic Schemas for Logistics Exceptions & Disruptions
"""

from datetime import date, datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class LogisticsExceptionBase(BaseModel):
    import_file_id: Optional[int] = None
    shipment_id: Optional[int] = None
    exception_type: str = Field(..., description="VESSEL_ROLLOVER, BLANK_SAILING, PORT_CONGESTION, VALUATION_DISPUTE, CUSTOMS_HOLD, DEMURRAGE_RISK, OTHER")
    severity: str = Field("MEDIUM", description="LOW, MEDIUM, HIGH, CRITICAL")
    title_ar: str
    title_en: str
    description: Optional[str] = None
    delay_impact_days: int = Field(0, ge=0)
    acid_number: Optional[str] = None
    acid_original_expiry: Optional[date] = None
    acid_adjusted_expiry: Optional[date] = None
    acid_impact_status: str = Field("NOT_AFFECTED", description="NOT_AFFECTED, ACTION_REQUIRED, EXTENSION_REQUESTED, SUSPENDED, RESOLVED")
    delay_kpi_suspended: bool = False
    suspension_reason: Optional[str] = None
    valuation_dispute_amount: Optional[float] = None
    valuation_original_customs_val: Optional[float] = None
    valuation_declared_val: Optional[float] = None
    appeal_status: Optional[str] = None
    resolution_strategy: Optional[str] = None


class LogisticsExceptionCreate(LogisticsExceptionBase):
    exception_code: Optional[str] = None


class LogisticsExceptionUpdate(BaseModel):
    severity: Optional[str] = None
    title_ar: Optional[str] = None
    title_en: Optional[str] = None
    description: Optional[str] = None
    delay_impact_days: Optional[int] = None
    acid_number: Optional[str] = None
    acid_original_expiry: Optional[date] = None
    acid_adjusted_expiry: Optional[date] = None
    acid_impact_status: Optional[str] = None
    delay_kpi_suspended: Optional[bool] = None
    suspension_reason: Optional[str] = None
    valuation_dispute_amount: Optional[float] = None
    valuation_original_customs_val: Optional[float] = None
    valuation_declared_val: Optional[float] = None
    appeal_status: Optional[str] = None
    resolution_strategy: Optional[str] = None
    status: Optional[str] = None


class AcidImpactResolution(BaseModel):
    acid_adjusted_expiry: date
    acid_impact_status: str = Field(..., description="EXTENSION_REQUESTED, SUSPENDED, RESOLVED")
    notes: Optional[str] = None


class ValuationDisputeAppeal(BaseModel):
    valuation_original_customs_val: float
    valuation_declared_val: float
    valuation_dispute_amount: float
    appeal_status: str = Field("PENDING_APPEAL", description="PENDING_APPEAL, COMMITTEE_HEARING, APPEAL_ACCEPTED, APPEAL_REJECTED")
    appeal_grounds: str
    resolution_strategy: Optional[str] = None


class ExceptionResolveRequest(BaseModel):
    resolution_strategy: str
    status: str = Field("RESOLVED", description="RESOLVED or CLOSED")


class LogisticsExceptionOut(LogisticsExceptionBase):
    id: int
    exception_code: str
    status: str
    resolved_at: Optional[datetime] = None
    resolved_by_user_id: Optional[int] = None
    is_active: bool
    is_deleted: bool
    created_by_user_id: Optional[int] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class LogisticsExceptionListOut(BaseModel):
    items: List[LogisticsExceptionOut]
    total: int
    page: int
    size: int


class ExceptionMetricsOut(BaseModel):
    total_exceptions: int
    open_exceptions: int
    critical_exceptions: int
    acid_impacted_count: int
    kpi_suspended_count: int
    total_dispute_amount_egp: float
