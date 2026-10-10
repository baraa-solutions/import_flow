from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field, ConfigDict


class ProjectBase(BaseModel):
    project_name: str = Field(..., min_length=2, max_length=200)
    project_owner: str = Field(..., min_length=2, max_length=100)
    company_id: int
    company_ids: List[int] = Field(default_factory=list, description="List of all selected importing company IDs")
    supplier_id: int
    incoterm_id: int
    import_type: str = Field("Direct Commercial", max_length=100)
    priority: str = Field("Medium", max_length=50)
    shipment_category: str = Field("FCL Container", max_length=100)
    allow_multi_shipment: bool = Field(True, description="يسمح بالشحن على أكثر من شحنة")
    allow_multi_company: bool = Field(True, description="يسمح بالربط مع أكثر من شركة أو خط شحن")
    total_budget_usd: Optional[float] = Field(None, ge=0)
    budget_currency: str = Field("USD", max_length=10)
    target_end_date: Optional[str] = Field(None, max_length=50, description="تاريخ الانتهاء المستهدف (YYYY-MM-DD)")
    notes: Optional[str] = None


class ProjectCreate(ProjectBase):
    project_code: Optional[str] = Field(None, max_length=50, description="Auto-generated if empty (PRJ-YYYY-XXX)")


class ProjectUpdate(BaseModel):
    project_name: Optional[str] = Field(None, min_length=2, max_length=200)
    project_owner: Optional[str] = Field(None, min_length=2, max_length=100)
    company_id: Optional[int] = None
    company_ids: Optional[List[int]] = None
    supplier_id: Optional[int] = None
    incoterm_id: Optional[int] = None
    import_type: Optional[str] = Field(None, max_length=100)
    priority: Optional[str] = Field(None, max_length=50)
    shipment_category: Optional[str] = Field(None, max_length=100)
    allow_multi_shipment: Optional[bool] = None
    allow_multi_company: Optional[bool] = None
    total_budget_usd: Optional[float] = Field(None, ge=0)
    budget_currency: Optional[str] = Field(None, max_length=10)
    target_end_date: Optional[str] = Field(None, max_length=50)
    status: Optional[str] = Field(None, max_length=50)  # Open, Closed, On Hold
    notes: Optional[str] = None
    is_active: Optional[bool] = None


class ProjectResponse(ProjectBase):
    project_id: int
    project_code: str
    status: str
    is_active: bool
    created_at: datetime
    updated_at: datetime
    company_name: Optional[str] = None
    supplier_name: Optional[str] = None
    incoterm_code: Optional[str] = None
    total_committed_usd: Optional[float] = 0.0
    po_count: Optional[int] = 0
    remaining_budget_usd: Optional[float] = None

    model_config = ConfigDict(from_attributes=True)
