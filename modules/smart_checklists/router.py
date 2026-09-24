"""
FastAPI Router for Smart Import Checklist Engine
"""

from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from modules.auth.router import get_current_user
from sqlalchemy.orm import Session

from database.database import get_db
import modules.smart_checklists.service as service
from modules.smart_checklists.schemas import (
    ChecklistSummaryResponse,
    ChecklistItemResponse,
    ChecklistToggleRequest,
    ChecklistOverrideRequest,
    ChecklistAutoSyncResponse,
    GatekeeperStatusResponse,
)

router = APIRouter(
    prefix="/api/v1/import-files",
    tags=["Smart Checklists"],
    dependencies=[Depends(get_current_user)],
)


@router.get("/{file_id}/checklist", response_model=ChecklistSummaryResponse)
def get_file_checklist(
    file_id: int,
    phase: Optional[str] = Query(None, description="Filter by phase code: PRE_SHIPMENT, IN_TRANSIT, PORT_ARRIVAL, CLEARANCE, POST_CLEARANCE"),
    role: Optional[str] = Query(None, description="Filter by role: COORDINATOR, SUPPLIER, CUSTOMS_BROKER, SHIPPING_LINE"),
    status_filter: Optional[str] = Query(None, alias="status", description="Filter by status: PASSED, PENDING, WAIVED"),
    db: Session = Depends(get_db),
):
    """Retrieve full checklist, questions, and readiness metrics for an import file."""
    return service.get_checklist_summary(
        db=db,
        file_id=file_id,
        phase_code=phase,
        role=role,
        status_filter=status_filter,
    )


@router.post("/{file_id}/checklist/auto-sync", response_model=ChecklistAutoSyncResponse)
def auto_sync_checklist(
    file_id: int,
    db: Session = Depends(get_db),
):
    """Trigger real-time auto-verification against all linked database tables."""
    return service.auto_sync_checklist(db=db, file_id=file_id)


@router.patch("/{file_id}/checklist/{item_id}/toggle", response_model=ChecklistItemResponse)
def toggle_checklist_item(
    file_id: int,
    item_id: int,
    payload: ChecklistToggleRequest,
    db: Session = Depends(get_db),
):
    """Manually toggle an item's status (PASSED, PENDING, WAIVED)."""
    return service.toggle_item(
        db=db,
        file_id=file_id,
        item_id=item_id,
        new_status=payload.status,
        notes=payload.notes,
        verified_by=payload.verified_by,
    )


@router.post("/{file_id}/checklist/{item_id}/override", response_model=ChecklistItemResponse)
def override_checklist_item(
    file_id: int,
    item_id: int,
    payload: ChecklistOverrideRequest,
    db: Session = Depends(get_db),
):
    """Grant conditional waiver for a mandatory item with justification & audit logging."""
    return service.override_item(
        db=db,
        file_id=file_id,
        item_id=item_id,
        reason=payload.reason,
        authorized_by=payload.authorized_by,
    )


@router.get("/{file_id}/checklist/gatekeeper-status", response_model=GatekeeperStatusResponse)
def get_gatekeeper_status(
    file_id: int,
    target_phase: str = Query(..., description="Target phase to check transition clear: IN_TRANSIT, PORT_ARRIVAL, CLEARANCE, POST_CLEARANCE"),
    db: Session = Depends(get_db),
):
    """Check if file has any blocking mandatory items preventing transition to target_phase."""
    return service.check_gatekeeper(
        db=db,
        file_id=file_id,
        target_phase=target_phase,
    )
