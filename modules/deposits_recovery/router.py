"""
FastAPI Router for Refundable Deposits & Guarantee Releases
"""

from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.permissions import require_permission
from modules.deposits_recovery.schemas import (
    BankLgReleaseRequest,
    DepositRecoveryMetricsOut,
    EirReturnLinkRequest,
    RefundClaimSubmitRequest,
    RefundSettlementRequest,
    RefundableDepositCreate,
    RefundableDepositListOut,
    RefundableDepositOut,
    RefundableDepositUpdate,
)
from modules.deposits_recovery.service import RefundableDepositsService
from modules.users.model import User

router = APIRouter(
    prefix="/api/v1/deposits-recovery",
    tags=["Refundable Deposits & Guarantee Releases"],
)

can_view = require_permission("customs_clearance.view")
can_manage = require_permission("customs_clearance.update")


@router.get("", response_model=RefundableDepositListOut, summary="List refundable deposits")
def list_deposits(
    import_file_id: Optional[int] = Query(None, description="Filter by import file"),
    deposit_type: Optional[str] = Query(None, description="Filter by deposit type"),
    beneficiary_type: Optional[str] = Query(None, description="Filter by beneficiary type"),
    recovery_status: Optional[str] = Query(None, description="Filter by recovery status"),
    search: Optional[str] = Query(None, description="Search keyword"),
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    skip = (page - 1) * size
    service = RefundableDepositsService(db)
    items, total = service.list_deposits(
        skip=skip,
        limit=size,
        import_file_id=import_file_id,
        deposit_type=deposit_type,
        beneficiary_type=beneficiary_type,
        recovery_status=recovery_status,
        search=search,
    )
    return RefundableDepositListOut(items=items, total=total, page=page, size=size)


@router.get("/metrics", response_model=DepositRecoveryMetricsOut, summary="Get deposit recovery metrics")
def get_metrics(
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    service = RefundableDepositsService(db)
    return service.get_metrics()


@router.get("/{deposit_id}", response_model=RefundableDepositOut, summary="Get deposit details")
def get_deposit(
    deposit_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    service = RefundableDepositsService(db)
    return service.get_by_id(deposit_id)


@router.post("", response_model=RefundableDepositOut, status_code=status.HTTP_201_CREATED, summary="Create a refundable deposit")
def create_deposit(
    data: RefundableDepositCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = RefundableDepositsService(db)
    return service.create_deposit(data, current_user_id=current_user.user_id)


@router.put("/{deposit_id}", response_model=RefundableDepositOut, summary="Update deposit record")
def update_deposit(
    deposit_id: int,
    data: RefundableDepositUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = RefundableDepositsService(db)
    return service.update_deposit(deposit_id, data, current_user_id=current_user.user_id)


@router.post("/{deposit_id}/link-eir", response_model=RefundableDepositOut, summary="Link container empty return EIR")
def link_eir(
    deposit_id: int,
    req: EirReturnLinkRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = RefundableDepositsService(db)
    return service.link_eir_return(deposit_id, req, current_user_id=current_user.user_id)


@router.post("/{deposit_id}/submit-claim", response_model=RefundableDepositOut, summary="Submit refund claim")
def submit_claim(
    deposit_id: int,
    req: RefundClaimSubmitRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = RefundableDepositsService(db)
    return service.submit_claim(deposit_id, req, current_user_id=current_user.user_id)


@router.post("/{deposit_id}/settle", response_model=RefundableDepositOut, summary="Settle refund payment or deduction")
def settle_refund(
    deposit_id: int,
    req: RefundSettlementRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = RefundableDepositsService(db)
    return service.settle_refund(deposit_id, req, current_user_id=current_user.user_id)


@router.post("/{deposit_id}/release-lg", response_model=RefundableDepositOut, summary="Record Bank Letter of Guarantee release")
def release_bank_lg(
    deposit_id: int,
    req: BankLgReleaseRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = RefundableDepositsService(db)
    return service.release_bank_lg(deposit_id, req, current_user_id=current_user.user_id)


@router.delete("/{deposit_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Soft delete deposit")
def delete_deposit(
    deposit_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = RefundableDepositsService(db)
    service.delete_deposit(deposit_id)
    return None
