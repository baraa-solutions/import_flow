from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.permissions import require_permission
from modules.auth.router import get_current_user
from modules.inspection_appeals.schemas import (
    AppealCommitteeDecisionSubmit,
    AppealTierProgression,
    InspectionAppealCreate,
    InspectionAppealListResponse,
    InspectionAppealResponse,
    InspectionAppealUpdate,
    TriplicateLabAssignSubmit,
)
from modules.inspection_appeals.service import InspectionAppealService
from modules.users.model import User

VIEW = "customs_clearance.view"
MANAGE = "customs_clearance.update"

router = APIRouter(
    prefix="/api/v1/inspection-appeals",
    tags=["Inspection & Laboratory Appeals"],
    dependencies=[Depends(get_current_user)],
)


@router.get(
    "",
    response_model=InspectionAppealListResponse,
    summary="List all inspection appeals with filtering and pagination",
)
def list_appeals(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    import_file_id: Optional[int] = Query(None, description="Filter by Import File ID"),
    clearance_id: Optional[int] = Query(None, description="Filter by Customs Clearance ID"),
    regulatory_authority: Optional[str] = Query(None, description="Filter by Authority (GOEIC, NFSA, EDA, NTRA, ATOMIC_ENERGY)"),
    appeal_tier: Optional[str] = Query(None, description="Filter by Tier (FIRST_APPEAL, SECOND_APPEAL, TRIPLICATE_SAMPLE)"),
    appeal_result: Optional[str] = Query(None, description="Filter by Result (PENDING, OVERTURNED_CONFORMING, UPHELD_REJECTED)"),
    include_inactive: bool = Query(False, description="Include soft-deleted records"),
    db: Session = Depends(get_db),
    _user: User = Depends(require_permission(VIEW)),
):
    items, total = InspectionAppealService(db).list_appeals(
        skip=skip,
        limit=limit,
        import_file_id=import_file_id,
        clearance_id=clearance_id,
        regulatory_authority=regulatory_authority,
        appeal_tier=appeal_tier,
        appeal_result=appeal_result,
        include_inactive=include_inactive,
    )
    return InspectionAppealListResponse(total=total, items=items)


@router.post(
    "",
    response_model=InspectionAppealResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Lodge a new laboratory inspection appeal",
)
def create_appeal(
    payload: InspectionAppealCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(MANAGE)),
):
    return InspectionAppealService(db).create_appeal(
        payload=payload,
        current_user=current_user.username,
    )


@router.get(
    "/{appeal_id}",
    response_model=InspectionAppealResponse,
    summary="Get inspection appeal details by ID",
)
def get_appeal(
    appeal_id: int,
    db: Session = Depends(get_db),
    _user: User = Depends(require_permission(VIEW)),
):
    return InspectionAppealService(db).get_appeal(appeal_id)


@router.put(
    "/{appeal_id}",
    response_model=InspectionAppealResponse,
    summary="Update inspection appeal details",
)
def update_appeal(
    appeal_id: int,
    payload: InspectionAppealUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(MANAGE)),
):
    return InspectionAppealService(db).update_appeal(
        appeal_id=appeal_id,
        payload=payload,
        current_user=current_user.username,
    )


@router.post(
    "/{appeal_id}/progress-tier",
    response_model=InspectionAppealResponse,
    summary="Escalate appeal to next tier (e.g., 2nd appeal or triplicate sample)",
)
def progress_appeal_tier(
    appeal_id: int,
    payload: AppealTierProgression,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(MANAGE)),
):
    return InspectionAppealService(db).progress_tier(
        appeal_id=appeal_id,
        payload=payload,
        current_user=current_user.username,
    )


@router.post(
    "/{appeal_id}/committee-decision",
    response_model=InspectionAppealResponse,
    summary="Record formal committee hearing decision / result",
)
def record_committee_decision(
    appeal_id: int,
    payload: AppealCommitteeDecisionSubmit,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(MANAGE)),
):
    return InspectionAppealService(db).record_committee_decision(
        appeal_id=appeal_id,
        payload=payload,
        current_user=current_user.username,
    )


@router.post(
    "/{appeal_id}/triplicate-lab",
    response_model=InspectionAppealResponse,
    summary="Assign neutral reference laboratory for triplicate sample testing",
)
def assign_triplicate_lab(
    appeal_id: int,
    payload: TriplicateLabAssignSubmit,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(MANAGE)),
):
    return InspectionAppealService(db).assign_triplicate_lab(
        appeal_id=appeal_id,
        payload=payload,
        current_user=current_user.username,
    )


@router.delete(
    "/{appeal_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft-delete an inspection appeal",
)
def delete_appeal(
    appeal_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(MANAGE)),
):
    InspectionAppealService(db).soft_delete(appeal_id=appeal_id, current_user=current_user.username)
    return None


@router.post(
    "/{appeal_id}/restore",
    response_model=InspectionAppealResponse,
    summary="Restore a soft-deleted inspection appeal",
)
def restore_appeal(
    appeal_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(MANAGE)),
):
    return InspectionAppealService(db).restore(appeal_id=appeal_id, current_user=current_user.username)
