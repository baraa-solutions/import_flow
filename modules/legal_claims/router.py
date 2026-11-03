"""
FastAPI Router for Cargo Claims, Time-Bars & Legal Reservations
"""

from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.permissions import require_permission
from modules.legal_claims.schemas import (
    LegalClaimCreate,
    LegalClaimListOut,
    LegalClaimOut,
    LegalClaimSettle,
    LegalClaimUpdate,
    ScheduleSurvey,
)
from modules.legal_claims.service import LegalClaimsService
from modules.users.model import User

router = APIRouter(
    prefix="/api/v1/legal-claims",
    tags=["Cargo Claims and Reservations"],
)

can_view = require_permission("legal_claims.view")
can_manage = require_permission("legal_claims.manage")
can_settle = require_permission("legal_claims.settle")


@router.get("", response_model=LegalClaimListOut, summary="List cargo claims and reservations")
def list_claims(
    import_file_id: Optional[int] = Query(None, description="Filter by import file ID"),
    claim_type: Optional[str] = Query(None, description="Filter by claim type"),
    status: Optional[str] = Query(None, description="Filter by status"),
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    skip = (page - 1) * size
    service = LegalClaimsService(db)
    items, total = service.list_claims(
        import_file_id=import_file_id,
        claim_type=claim_type,
        status_filter=status,
        skip=skip,
        limit=size,
    )
    return LegalClaimListOut(items=items, total=total, page=page, size=size)


@router.get("/{claim_id}", response_model=LegalClaimOut, summary="Get cargo claim by ID")
def get_claim(
    claim_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    service = LegalClaimsService(db)
    return service.get_claim(claim_id)


@router.post("", response_model=LegalClaimOut, status_code=status.HTTP_201_CREATED, summary="Create cargo claim or reservation")
def create_claim(
    payload: LegalClaimCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = LegalClaimsService(db)
    return service.create_claim(payload, user_id=current_user.user_id)


@router.put("/{claim_id}", response_model=LegalClaimOut, summary="Update cargo claim")
def update_claim(
    claim_id: int,
    payload: LegalClaimUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = LegalClaimsService(db)
    return service.update_claim(claim_id, payload, user_id=current_user.user_id)


@router.post("/{claim_id}/schedule-survey", response_model=LegalClaimOut, summary="Schedule joint survey")
def schedule_survey(
    claim_id: int,
    payload: ScheduleSurvey,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = LegalClaimsService(db)
    return service.schedule_survey(claim_id, payload, user_id=current_user.user_id)


@router.post("/{claim_id}/settle", response_model=LegalClaimOut, summary="Settle cargo claim")
def settle_claim(
    claim_id: int,
    payload: LegalClaimSettle,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_settle),
):
    service = LegalClaimsService(db)
    return service.settle_claim(claim_id, payload, user_id=current_user.user_id)


@router.delete("/{claim_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Soft delete cargo claim")
def delete_claim(
    claim_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = LegalClaimsService(db)
    service.delete_claim(claim_id, user_id=current_user.user_id)
    return None
