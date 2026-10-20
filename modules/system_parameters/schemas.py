"""
Pydantic schemas for the System Parameters Settings API (BEX-T17).
"""
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field


class SystemParameterResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    param_key: str
    param_value: str
    description: Optional[str] = None
    is_active: bool
    updated_at: Optional[datetime] = None
    updated_by: Optional[str] = None


class SystemParameterUpdate(BaseModel):
    param_value: str = Field(..., description="Parameter value stored as text")
    justification: str = Field(..., min_length=5, description="Business justification for changing the parameter (min 5 chars)")
