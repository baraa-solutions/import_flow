"""
Pydantic Schemas for Centralized Recalculation Engine (CRE-001)
"""
import json
from datetime import datetime
from typing import Dict, List, Optional, Any
from pydantic import BaseModel, Field, ConfigDict, field_validator



# ─── Preview (read-only comparison) ─────────────────────────────────────────

class RecalculationPreviewItem(BaseModel):
    """One line of variance between what is currently stored and what the live source says."""
    field_name: str                      # DB column name in target entity
    label_ar: str                        # Human-readable label in Arabic
    label_en: str                        # Human-readable label in English
    old_value: float                     # Current value stored in target entity
    new_value: float                     # Live value from source entity
    variance_amount: float               # new - old
    variance_percentage: float           # |(new - old)| / old * 100, or 100 if old == 0
    is_hard_block: bool                  # True if variance_pct > threshold
    threshold_percentage: float          # Configured threshold (e.g. 5.0%)
    source_entity_type: str
    dependency_id: int
    # Additive (phase 09): "OK", or "RATE_MISSING" when the source value has no exchange rate (never applied).
    status: str = "OK"
    message_code: Optional[str] = None
    params: Dict[str, Any] = {}


class RecalculationPreviewResponse(BaseModel):
    """Complete preview result returned by preview() endpoint."""
    target_entity_type: str
    target_entity_id: int
    items: List[RecalculationPreviewItem]
    has_any_variance: bool
    has_hard_block: bool
    max_variance_pct: float
    blocked_by_status: bool              # True if entity status is in blocked_statuses
    current_entity_status: str
    can_apply: bool                      # True if user has permission and no irreversible block
    message_ar: str                      # deprecated: render message_code + params
    message_code: Optional[str] = None   # RECALC_NO_VARIANCE / RECALC_SOFT_VARIANCE / RECALC_HARD_BLOCK
    params: Dict[str, Any] = {}


# ─── Apply Request ───────────────────────────────────────────────────────────

class RecalculationApplyRequest(BaseModel):
    """Sent by the client after the user reviews preview and confirms apply."""
    target_entity_type: str = Field(..., description="e.g. 'import_budget'")
    target_entity_id: int
    source_page: str = Field(..., description="Originating UI page name for audit")
    justification: Optional[str] = Field(None, description="Required if has_hard_block=True")


# ─── Apply Result ────────────────────────────────────────────────────────────

class RecalculationApplyResult(BaseModel):
    """Returned after apply() is executed."""
    target_entity_type: str
    target_entity_id: int
    action_taken: str                    # 'auto_updated', 'revalidation_required', 'revision_created', 'no_op'
    revision_created: bool = False
    new_entity_id: Optional[int] = None  # If revision was created
    new_entity_code: Optional[str] = None
    applied_changes: List[RecalculationPreviewItem] = []
    log_id: int
    message_ar: str                      # deprecated: render message_code + params
    message_code: Optional[str] = None   # RECALC_NO_VARIANCE / RECALC_APPLIED
    params: Dict[str, Any] = {}


# ─── Dependency Map ──────────────────────────────────────────────────────────

class DependencyMapResponse(BaseModel):
    id: int
    target_entity_type: str
    target_field: str
    source_entity_type: str
    source_field: str
    join_key: str
    aggregation_function: str
    blocked_statuses: List[str]
    required_permission: Optional[str]
    label_ar: Optional[str]
    label_en: Optional[str]
    is_active: bool

    model_config = ConfigDict(from_attributes=True)

    @field_validator("blocked_statuses", mode="before")
    @classmethod
    def parse_blocked_statuses(cls, v: Any) -> List[str]:
        if isinstance(v, str):
            try:
                return json.loads(v or "[]")
            except (json.JSONDecodeError, TypeError):
                return []
        return v or []



# ─── Recalculation Log ───────────────────────────────────────────────────────

class RecalculationLogResponse(BaseModel):
    id: int
    target_entity_type: str
    target_entity_id: int
    action: str
    performed_by: Optional[str]
    source_page: Optional[str]
    result_status: Optional[str]
    action_taken: Optional[str]
    new_entity_id: Optional[int]
    justification: Optional[str]
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
