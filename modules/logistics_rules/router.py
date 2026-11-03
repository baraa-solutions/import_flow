"""
FastAPI Router for Logistics Operational Rules
"""

from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.permissions import require_permission
from modules.logistics_rules.schemas import (
    EffectiveRuleOut,
    FieldQuestionOut,
    LogisticsRuleCreate,
    LogisticsRuleListOut,
    LogisticsRuleOut,
    LogisticsRuleUpdate,
    LogisticsRuleVerify,
)
from modules.logistics_rules.service import LogisticsRulesService
from modules.users.model import User

router = APIRouter(
    prefix="/api/v1/logistics-rules",
    tags=["Logistics Operational Rules"],
)

can_view = require_permission("logistics_rules.view")
can_create = require_permission("logistics_rules.create")
can_verify = require_permission("logistics_rules.verify")
can_admin = require_permission("logistics_rules.admin")


@router.get("", response_model=LogisticsRuleListOut, summary="List operational rules")
def list_logistics_rules(
    scope_type: Optional[str] = Query(None, description="Filter by scope type"),
    verification_status: Optional[str] = Query(None, description="Filter by status"),
    is_latest: bool = Query(True, description="Only latest versions"),
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    skip = (page - 1) * size
    service = LogisticsRulesService(db)
    items, total = service.list_rules(
        scope_type=scope_type,
        verification_status=verification_status,
        is_latest=is_latest,
        skip=skip,
        limit=size,
    )
    return LogisticsRuleListOut(items=items, total=total, page=page, size=size)


@router.get(
    "/export/questions",
    response_model=List[FieldQuestionOut],
    summary="Export field questionnaire checklist for unverified rules",
)
def export_field_questions(
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    service = LogisticsRulesService(db)
    return service.get_rules_for_export()


@router.get(
    "/effective/{rule_key}",
    response_model=EffectiveRuleOut,
    summary="Get effective operational rule value with safety guards applied",
)
def get_effective_rule(
    rule_key: str,
    scope_type: str = Query("GLOBAL", description="Scope type (GLOBAL, SHIPPING_LINE, etc.)"),
    scope_id: Optional[int] = Query(None, description="Scope target identifier"),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    service = LogisticsRulesService(db)
    return service.get_effective_rule(
        rule_key=rule_key, scope_type=scope_type, scope_id=scope_id
    )


@router.get(
    "/{rule_id}",
    response_model=LogisticsRuleOut,
    summary="Get operational rule by ID",
)
def get_logistics_rule(
    rule_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    service = LogisticsRulesService(db)
    return service.get_rule_by_id(rule_id)


@router.post(
    "",
    response_model=LogisticsRuleOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new operational rule",
)
def create_logistics_rule(
    payload: LogisticsRuleCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_create),
):
    service = LogisticsRulesService(db)
    return service.create_rule(payload, current_user_id=current_user.user_id)


@router.put(
    "/{rule_id}",
    response_model=LogisticsRuleOut,
    summary="Update operational rule (creates a new version)",
)
def update_logistics_rule(
    rule_id: int,
    payload: LogisticsRuleUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_create),
):
    service = LogisticsRulesService(db)
    return service.update_rule(
        rule_id=rule_id, payload=payload, current_user_id=current_user.user_id
    )


@router.post(
    "/{rule_id}/verify",
    response_model=LogisticsRuleOut,
    summary="Verify operational rule with official proof (Maker-Checker enforced)",
)
def verify_logistics_rule(
    rule_id: int,
    payload: LogisticsRuleVerify,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_verify),
):
    service = LogisticsRulesService(db)
    return service.verify_rule(
        rule_id=rule_id, payload=payload, current_user_id=current_user.user_id
    )
