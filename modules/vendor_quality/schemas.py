"""
Pydantic Schemas for Pre-Shipment Inspection (PSI) and Vendor Quality Rating
"""

from datetime import date, datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class VendorQualityBase(BaseModel):
    vendor_id: Optional[int] = None
    vendor_name: str
    purchase_order_id: Optional[int] = None
    import_file_id: Optional[int] = None
    inspection_agency: str = Field(..., description="SGS, BUREAU_VERITAS, COTECNA, TUV, INTERTEK, INTERNAL_QA, OTHER")
    psi_certificate_number: Optional[str] = None
    inspection_date: Optional[date] = None
    psi_result: str = Field("PENDING", description="PENDING, PASSED, PASSED_WITH_CONDITIONS, FAILED, WAIVED")
    defects_count: int = Field(0, ge=0)
    critical_defects_count: int = Field(0, ge=0)
    inspection_certificate_file: Optional[str] = None
    quality_score: float = Field(100.0, ge=0.0, le=100.0)
    delivery_timeliness_score: float = Field(100.0, ge=0.0, le=100.0)
    documentation_accuracy_score: float = Field(100.0, ge=0.0, le=100.0)
    compliance_score: float = Field(100.0, ge=0.0, le=100.0)
    corrective_action_required: bool = False
    corrective_action_plan: Optional[str] = None
    inspector_notes: Optional[str] = None


class VendorQualityCreate(VendorQualityBase):
    assessment_code: Optional[str] = None


class VendorQualityUpdate(BaseModel):
    vendor_name: Optional[str] = None
    inspection_agency: Optional[str] = None
    psi_certificate_number: Optional[str] = None
    inspection_date: Optional[date] = None
    psi_result: Optional[str] = None
    defects_count: Optional[int] = None
    critical_defects_count: Optional[int] = None
    inspection_certificate_file: Optional[str] = None
    quality_score: Optional[float] = None
    delivery_timeliness_score: Optional[float] = None
    documentation_accuracy_score: Optional[float] = None
    compliance_score: Optional[float] = None
    corrective_action_required: Optional[bool] = None
    corrective_action_plan: Optional[str] = None
    inspector_notes: Optional[str] = None


class PsiCertificateUploadRequest(BaseModel):
    psi_certificate_number: str
    inspection_date: date
    psi_result: str = Field(..., description="PASSED, PASSED_WITH_CONDITIONS, FAILED, WAIVED")
    inspection_certificate_file: str
    defects_count: int = 0
    critical_defects_count: int = 0
    inspector_notes: Optional[str] = None


class VendorScorecardRadarOut(BaseModel):
    quality: float
    delivery_timeliness: float
    documentation_accuracy: float
    compliance: float
    overall_rating: float
    grade: str


class VendorQualityOut(VendorQualityBase):
    id: int
    assessment_code: str
    overall_vendor_rating: float
    rating_grade: str
    is_active: bool
    is_deleted: bool
    created_by_user_id: Optional[int] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class VendorQualityListOut(BaseModel):
    items: List[VendorQualityOut]
    total: int
    page: int
    size: int


class VendorHistoricalRankingItem(BaseModel):
    vendor_id: Optional[int] = None
    vendor_name: str
    inspections_count: int
    passed_count: int
    failed_count: int
    avg_quality_score: float
    avg_delivery_timeliness: float
    avg_documentation_accuracy: float
    avg_compliance: float
    avg_overall_rating: float
    current_grade: str


class VendorHistoricalRankingOut(BaseModel):
    rankings: List[VendorHistoricalRankingItem]
    total_vendors: int
