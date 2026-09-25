"""
Router for Centralized Recalculation Engine (CRE-001)

Endpoints:
  POST /recalculation/preview    → Compare live values vs stored, no data changes
  POST /recalculation/apply      → Apply live values with permission/SoD/Hard Block enforcement
  GET  /recalculation/logs       → Audit log entries for an entity
  GET  /recalculation/dependencies → List all active dependency map entries
"""

from typing import List, Optional
from fastapi import APIRouter, Depends, Query
from modules.auth.router import get_current_user, require_manager_or_admin
from sqlalchemy.orm import Session
from database.database import get_db
from modules.users.model import User
import modules.recalculation.service as svc
import modules.recalculation.repository as repo
from modules.recalculation.schemas import (
    RecalculationPreviewResponse,
    RecalculationApplyRequest,
    RecalculationApplyResult,
    DependencyMapResponse,
    RecalculationLogResponse,
)

router = APIRouter(prefix="/api/v1/recalculation", tags=["Recalculation Engine"], dependencies=[Depends(get_current_user)])



@router.post(
    "/preview",
    response_model=RecalculationPreviewResponse,
    summary="Preview Recalculation (read-only variance check)",
)
def preview_recalculation(
    target_entity_type: str = Query(..., description="e.g. 'import_budget'"),
    target_entity_id: int = Query(...),
    source_page: str = Query("API", description="Originating UI page name for audit"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Returns live variance comparison for the target entity.
    Does NOT modify any data. Safe to call repeatedly.
    """
    return svc.preview(
        db=db,
        target_entity_type=target_entity_type,
        target_entity_id=target_entity_id,
        source_page=source_page,
        performed_by=current_user.username,
    )


@router.post(
    "/apply",
    response_model=RecalculationApplyResult,
    summary="Apply Recalculation (update target with live upstream values)",
)
def apply_recalculation(
    request: RecalculationApplyRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_manager_or_admin),
):
    """
    Applies live upstream values to the target entity.
    Enforces: permission check, SoD, Hard Block (requires justification), Immutability (Revision for Approved).
    """
    return svc.apply(db=db, request=request, current_user=current_user)


@router.get(
    "/logs",
    response_model=List[RecalculationLogResponse],
    summary="Audit logs for an entity",
)
def get_entity_logs(
    target_entity_type: str = Query(...),
    target_entity_id: int = Query(...),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Returns recalculation audit log entries for a given entity."""
    return repo.get_logs_for_entity(db, target_entity_type, target_entity_id, limit)


@router.get(
    "/dependencies",
    response_model=List[DependencyMapResponse],
    summary="List all active dependency map entries",
)
def get_dependencies(
    target_entity_type: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Returns all active dependency relationships. Optionally filtered by target_entity_type."""
    deps = repo.get_all_dependencies(db, include_inactive=False)
    if target_entity_type:
        deps = [d for d in deps if d.target_entity_type == target_entity_type]
    return [
        DependencyMapResponse(
            id=d.id,
            target_entity_type=d.target_entity_type,
            target_field=d.target_field,
            source_entity_type=d.source_entity_type,
            source_field=d.source_field,
            join_key=d.join_key,
            aggregation_function=d.aggregation_function,
            blocked_statuses=d.blocked_statuses_list,
            required_permission=d.required_permission,
            label_ar=d.label_ar,
            label_en=d.label_en,
            is_active=d.is_active,
        )
        for d in deps
    ]

