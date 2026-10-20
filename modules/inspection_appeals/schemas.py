from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field

from modules.common.legacy_rows import LegacyRowTolerantModel, read_model

# Standard Domain Constants
REGULATORY_AUTHORITIES = ("GOEIC", "NFSA", "EDA", "NTRA", "ATOMIC_ENERGY")
INITIAL_TEST_RESULTS = ("CONFORMING", "NON_CONFORMING_VISUAL", "NON_CONFORMING_CHEMICAL", "NON_CONFORMING_MICROBIAL")
APPEAL_TIERS = ("FIRST_APPEAL", "SECOND_APPEAL", "TRIPLICATE_SAMPLE")
APPEAL_RESULTS = ("PENDING", "OVERTURNED_CONFORMING", "UPHELD_REJECTED")


# -------------------------------------------------------------
# Input Schemas
# -------------------------------------------------------------

class InspectionAppealCreate(BaseModel):
    import_file_id: int = Field(..., gt=0, description="Associated Import File ID")
    clearance_id: Optional[int] = Field(None, gt=0, description="Optional Customs Clearance Record ID")
    regulatory_authority: str = Field(..., description="Regulatory Authority: GOEIC, NFSA, EDA, NTRA, ATOMIC_ENERGY")
    sample_number: Optional[str] = Field(None, max_length=100, description="Drawn laboratory sample tracking number")
    sample_draw_date: Optional[datetime] = Field(None, description="Date & time when the physical sample was drawn")
    initial_test_result: str = Field(..., description="Initial lab verdict: CONFORMING, NON_CONFORMING_VISUAL, NON_CONFORMING_CHEMICAL, NON_CONFORMING_MICROBIAL")
    rejection_reason: Optional[str] = Field(None, description="Technical or regulatory non-conformance reason")
    appeal_tier: str = Field("FIRST_APPEAL", description="Tier of appeal: FIRST_APPEAL, SECOND_APPEAL, TRIPLICATE_SAMPLE")
    appeal_submission_date: Optional[datetime] = Field(None, description="Date when the appeal was lodged")
    appeal_committee_date: Optional[datetime] = Field(None, description="Scheduled or actual committee review date")
    triplicate_lab_assigned: Optional[str] = Field(None, max_length=150, description="Reference laboratory for triplicate sample testing")
    official_letter_ref: Optional[str] = Field(None, max_length=100, description="Official letter/resolution reference number")
    notes: Optional[str] = Field(None, description="Operational notes or committee directives")


class InspectionAppealUpdate(BaseModel):
    clearance_id: Optional[int] = None
    regulatory_authority: Optional[str] = None
    sample_number: Optional[str] = None
    sample_draw_date: Optional[datetime] = None
    initial_test_result: Optional[str] = None
    rejection_reason: Optional[str] = None
    appeal_tier: Optional[str] = None
    appeal_submission_date: Optional[datetime] = None
    appeal_committee_date: Optional[datetime] = None
    triplicate_lab_assigned: Optional[str] = None
    appeal_result: Optional[str] = None
    official_letter_ref: Optional[str] = None
    notes: Optional[str] = None


class AppealTierProgression(BaseModel):
    target_tier: str = Field(..., description="Next appeal tier: SECOND_APPEAL or TRIPLICATE_SAMPLE")
    triplicate_lab_assigned: Optional[str] = Field(None, max_length=150, description="Required when target_tier is TRIPLICATE_SAMPLE")
    official_letter_ref: Optional[str] = Field(None, max_length=100, description="Official escalation letter reference")
    notes: Optional[str] = Field(None, description="Justification and notes for tier advancement")


class AppealCommitteeDecisionSubmit(BaseModel):
    appeal_committee_date: Optional[datetime] = Field(None, description="Date committee met and decided")
    appeal_result: str = Field(..., description="Verdict: OVERTURNED_CONFORMING, UPHELD_REJECTED, PENDING")
    official_letter_ref: Optional[str] = Field(None, max_length=100, description="Committee formal decision letter number")
    notes: Optional[str] = Field(None, description="Committee minutes or findings")


class TriplicateLabAssignSubmit(BaseModel):
    triplicate_lab_assigned: str = Field(..., min_length=2, max_length=150, description="Reference neutral lab name")
    official_letter_ref: Optional[str] = Field(None, max_length=100, description="Referral letter number")
    notes: Optional[str] = Field(None, description="Testing scope or instructions")


# -------------------------------------------------------------
# Read & Response Schemas
# -------------------------------------------------------------

@read_model
class InspectionAppealResponse(LegacyRowTolerantModel):
    appeal_id: int
    appeal_code: str
    import_file_id: int
    clearance_id: Optional[int] = None
    regulatory_authority: str
    sample_number: Optional[str] = None
    sample_draw_date: Optional[datetime] = None
    initial_test_result: str
    rejection_reason: Optional[str] = None
    appeal_tier: str = "FIRST_APPEAL"
    appeal_submission_date: Optional[datetime] = None
    appeal_committee_date: Optional[datetime] = None
    triplicate_lab_assigned: Optional[str] = None
    appeal_result: str = "PENDING"
    official_letter_ref: Optional[str] = None
    notes: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    created_by: Optional[str] = None
    updated_by: Optional[str] = None
    is_active: bool = True

    model_config = ConfigDict(from_attributes=True)


class InspectionAppealListResponse(BaseModel):
    total: int
    items: List[InspectionAppealResponse]
