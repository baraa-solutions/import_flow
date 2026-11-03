"""
Pydantic Schemas for Regulatory Matrix
"""

from datetime import datetime
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field
from modules.common.legacy_rows import LegacyRowTolerantModel, read_model


class RegulatoryAgencyEnum(str, Enum):
    NFSA = "NFSA"              # سلامة الغذاء
    GOEIC = "GOEIC"            # الرقابة على الصادرات والواردات
    QUARANTINE = "QUARANTINE"  # الحجر الزراعي / البيطري
    NTRA = "NTRA"              # تنظيم الاتصالات
    EOS = "EOS"                # المواصفات والجودة
    PHARMACEUTICAL = "EDA"     # هيئة الدواء المصرية
    OTHER = "OTHER"


class StageTimingEnum(str, Enum):
    PRE_ACID = "PRE_ACID"                        # قبل استخراج الرقم التعريفي المسبق
    PRE_ARRIVAL = "PRE_ARRIVAL"                  # قبل وصول البضاعة للميناء
    CUSTOMS_EXAMINATION = "CUSTOMS_EXAMINATION"  # أثناء الكشف والمعاينة الجمركية
    POST_CLEARANCE = "POST_CLEARANCE"            # إفراج تحت التحفظ / بعد الإفراج


class InspectionTypeEnum(str, Enum):
    PHYSICAL_INSPECTION = "PHYSICAL_INSPECTION"  # كشف ظاهري
    DOCUMENTARY_CHECK = "DOCUMENTARY_CHECK"      # فحص مستندي
    LAB_SAMPLING = "LAB_SAMPLING"                # سحب عينات وتحليل معملي


class HsCodeRegulatoryBase(BaseModel):
    hs_code: str = Field(..., description="HS Code (e.g. 8471.30.00)")
    agency_code: str = Field(..., description="Agency identifier (NFSA, GOEIC, etc.)")
    agency_name_ar: str = Field(..., description="Agency Arabic name")
    agency_name_en: str = Field(..., description="Agency English name")
    stage_timing: str = Field(default="PRE_ARRIVAL", description="Requirement stage timing")
    required_documents: Optional[str] = Field(None, description="Required documents list")
    inspection_type: Optional[str] = Field(None, description="Type of inspection")
    regulatory_notes: Optional[str] = Field(None, description="Regulatory compliance guidelines")
    is_mandatory: bool = Field(default=True, description="Whether regulatory check is mandatory")


class HsCodeRegulatoryCreate(HsCodeRegulatoryBase):
    pass


class HsCodeRegulatoryUpdate(BaseModel):
    agency_code: Optional[str] = None
    agency_name_ar: Optional[str] = None
    agency_name_en: Optional[str] = None
    stage_timing: Optional[str] = None
    required_documents: Optional[str] = None
    inspection_type: Optional[str] = None
    regulatory_notes: Optional[str] = None
    is_mandatory: Optional[bool] = None
    is_active: Optional[bool] = None


@read_model
class HsCodeRegulatoryResponse(LegacyRowTolerantModel):
    id: int
    hs_code: str
    agency_code: str
    agency_name_ar: str
    agency_name_en: str
    stage_timing: str
    required_documents: Optional[str] = None
    inspection_type: Optional[str] = None
    regulatory_notes: Optional[str] = None
    is_mandatory: bool = True
    is_active: bool = True
    created_by: Optional[str] = "system"
    updated_by: Optional[str] = "system"
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class HsCodeRegulatoryListResponse(BaseModel):
    total: int
    items: List[HsCodeRegulatoryResponse]
