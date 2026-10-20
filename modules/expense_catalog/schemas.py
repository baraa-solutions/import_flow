"""
Expense Catalog Schemas (AI-EXPENSE-CATALOG-002)
Pydantic schemas for Coded Reference Expense Catalog operations.
"""

from __future__ import annotations

from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class ExpenseCatalogBase(BaseModel):
    code: str = Field(..., max_length=30, description="Unique uppercase catalog code, e.g. CLR-LCL-INV")
    canonical_name_ar: str = Field(..., max_length=255, description="Standard Arabic name")
    canonical_name_en: Optional[str] = Field(None, max_length=255, description="Standard English name")
    category: str = Field(..., max_length=50, description="Clearance Fees | Procedures & Approvals | Inland Transport | Port & Handling | Other Fees")
    unit_type: str = Field("fixed", max_length=30, description="fixed | per_ton | per_container | per_vehicle | per_night | per_invoice | per_shipment | range")
    allow_composite: bool = Field(False, description="Whether this item is commonly part of multi-value cells")
    recognition_patterns: List[str] = Field(default_factory=list, description="Array of phrases/synonyms used across brokers")
    is_active: bool = Field(True, description="Active status")


class ExpenseCatalogCreate(ExpenseCatalogBase):
    pass


class ExpenseCatalogUpdate(BaseModel):
    canonical_name_ar: Optional[str] = Field(None, max_length=255)
    canonical_name_en: Optional[str] = Field(None, max_length=255)
    category: Optional[str] = Field(None, max_length=50)
    unit_type: Optional[str] = Field(None, max_length=30)
    allow_composite: Optional[bool] = None
    recognition_patterns: Optional[List[str]] = None
    is_active: Optional[bool] = None


class ExpenseCatalogResponse(ExpenseCatalogBase):
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class AddPatternRequest(BaseModel):
    pattern: str = Field(..., min_length=2, max_length=255, description="New phrasing or synonym to add to recognition_patterns")


class BrokerMappingCreate(BaseModel):
    broker_name: Optional[str] = Field(None, max_length=200, description="Broker name or empty for global")
    raw_item_name: str = Field(..., min_length=2, max_length=255, description="Extracted raw item name")
    catalog_code: str = Field(..., max_length=30, description="Canonical catalog code to map to")
    canonical_name_ar: Optional[str] = Field(None, max_length=255)
    canonical_name_en: Optional[str] = Field(None, max_length=255)
    category: Optional[str] = Field(None, max_length=50)
    unit_type: Optional[str] = Field(None, max_length=30)


class BrokerMappingResponse(BaseModel):
    broker_name: str
    broker_key: str
    raw_item_name: str
    item_key: str
    catalog_code: str
    code: str
    canonical_name_ar: str
    canonical_name_en: Optional[str] = None
    category: str
    unit_type: str = "fixed"
    confidence_score: float = 1.0
    match_confidence: str = "high"
    source: str = "broker_memory"
    updated_at: Optional[str] = None


class ExpenseCatalogSeedItem(BaseModel):
    code: str
    canonical_name_ar: str
    canonical_name_en: Optional[str] = None
    category: str
    unit_type: str = "fixed"
    allow_composite: bool = False
    recognition_patterns: List[str] = Field(default_factory=list)
