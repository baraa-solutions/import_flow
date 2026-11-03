"""
FastAPI Router for Preferential Trade Agreements & Origin Verifications
"""

from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.permissions import require_permission
from modules.trade_agreements.schemas import (
    TradeAgreementCreate,
    TradeAgreementListOut,
    TradeAgreementOut,
    TradeAgreementUpdate,
    TradeAgreementVerifyOriginal,
)
from modules.trade_agreements.service import TradeAgreementsService
from modules.users.model import User

router = APIRouter(
    prefix="/api/v1/trade-agreements",
    tags=["Preferential Trade Agreements"],
)

can_view = require_permission("trade_agreements.view")
can_manage = require_permission("trade_agreements.manage")
can_verify = require_permission("trade_agreements.verify")


@router.get("", response_model=TradeAgreementListOut, summary="List preferential origin verifications")
def list_verifications(
    import_file_id: Optional[int] = Query(None, description="Filter by import file ID"),
    agreement_name: Optional[str] = Query(None, description="Filter by agreement name"),
    submission_status: Optional[str] = Query(None, description="Filter by status"),
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    skip = (page - 1) * size
    service = TradeAgreementsService(db)
    items, total = service.list_verifications(
        import_file_id=import_file_id,
        agreement_name=agreement_name,
        submission_status=submission_status,
        skip=skip,
        limit=size,
    )
    return TradeAgreementListOut(items=items, total=total, page=page, size=size)


@router.get("/{item_id}", response_model=TradeAgreementOut, summary="Get origin verification by ID")
def get_verification(
    item_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    service = TradeAgreementsService(db)
    return service.get_verification(item_id)


@router.post("", response_model=TradeAgreementOut, status_code=status.HTTP_201_CREATED, summary="Create origin verification")
def create_verification(
    payload: TradeAgreementCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = TradeAgreementsService(db)
    return service.create_verification(payload, user_id=current_user.user_id)


@router.put("/{item_id}", response_model=TradeAgreementOut, summary="Update origin verification")
def update_verification(
    item_id: int,
    payload: TradeAgreementUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = TradeAgreementsService(db)
    return service.update_verification(item_id, payload, user_id=current_user.user_id)


@router.post("/{item_id}/verify-original", response_model=TradeAgreementOut, summary="Record original certificate receipt")
def verify_original(
    item_id: int,
    payload: TradeAgreementVerifyOriginal,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_verify),
):
    service = TradeAgreementsService(db)
    return service.verify_original(item_id, payload, user_id=current_user.user_id)


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Soft delete origin verification")
def delete_verification(
    item_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = TradeAgreementsService(db)
    service.delete_verification(item_id, user_id=current_user.user_id)
    return None
