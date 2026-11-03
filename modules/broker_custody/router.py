from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.permissions import require_permission
from modules.broker_custody.schemas import (
    BrokerCustodyAdvanceCreate,
    BrokerCustodyAdvanceListResponse,
    BrokerCustodyAdvanceResponse,
    BrokerCustodyAdvanceUpdate,
    BrokerExpenseItemCreate,
    BrokerExpenseItemResponse,
    BrokerExpenseItemUpdate,
    BrokerSettlementReceiptCreate,
    BrokerSettlementReceiptResponse,
    BrokerSettlementReceiptUpdate,
    CustomsBrokerAdvanceCreate,
    CustomsBrokerAdvanceListResponse,
    CustomsBrokerAdvanceResponse,
    CustomsBrokerAdvanceUpdate,
    CustomsSettlementVarianceResponse,
    ExpenseItemApprovalRequest,
    SettlementReconciliationResponse,
)
from modules.broker_custody.service import BrokerCustodyService
from modules.users.model import User

router = APIRouter(
    prefix="/api/v1/broker-custody",
    tags=["Broker Custody & Customs Settlement"],
)

can_view = require_permission("broker_custody.view")
can_manage = require_permission("broker_custody.manage")


# ===========================================================================
# Wave 1 Customs Broker Advances Endpoints
# ===========================================================================
@router.post(
    "/customs-advances",
    response_model=CustomsBrokerAdvanceResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create Customs Broker Advance",
)
def create_customs_advance(
    payload: CustomsBrokerAdvanceCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = BrokerCustodyService(db)
    adv = service.create_customs_advance(payload, current_user=current_user.username)
    return CustomsBrokerAdvanceResponse.model_validate(adv)


@router.get(
    "/customs-advances",
    response_model=CustomsBrokerAdvanceListResponse,
    summary="List Customs Broker Advances with filtering",
)
def list_customs_advances(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    import_file_id: Optional[int] = Query(None),
    broker_id: Optional[int] = Query(None),
    status: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    service = BrokerCustodyService(db)
    items, total = service.list_customs_advances(
        skip=skip,
        limit=limit,
        import_file_id=import_file_id,
        broker_id=broker_id,
        status=status,
        search=search,
    )
    return CustomsBrokerAdvanceListResponse(
        total=total,
        items=[CustomsBrokerAdvanceResponse.model_validate(it) for it in items],
    )


@router.get(
    "/customs-advances/{adv_id}",
    response_model=CustomsBrokerAdvanceResponse,
    summary="Get Customs Broker Advance details",
)
def get_customs_advance(
    adv_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    service = BrokerCustodyService(db)
    adv = service.get_customs_advance(adv_id)
    return CustomsBrokerAdvanceResponse.model_validate(adv)


@router.put(
    "/customs-advances/{adv_id}",
    response_model=CustomsBrokerAdvanceResponse,
    summary="Update Customs Broker Advance",
)
def update_customs_advance(
    adv_id: int,
    payload: CustomsBrokerAdvanceUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = BrokerCustodyService(db)
    adv = service.update_customs_advance(adv_id, payload, current_user=current_user.username)
    return CustomsBrokerAdvanceResponse.model_validate(adv)


@router.delete(
    "/customs-advances/{adv_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft delete Customs Broker Advance",
)
def delete_customs_advance(
    adv_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = BrokerCustodyService(db)
    service.delete_customs_advance(adv_id, current_user=current_user.username)
    return None


# ===========================================================================
# Wave 1 Official Settlement Receipts Endpoints
# ===========================================================================
@router.post(
    "/customs-advances/{adv_id}/receipts",
    response_model=BrokerSettlementReceiptResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Add official settlement receipt (white, red, port, broker fee)",
)
def add_settlement_receipt(
    adv_id: int,
    payload: BrokerSettlementReceiptCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = BrokerCustodyService(db)
    receipt = service.add_settlement_receipt(adv_id, payload, current_user=current_user.username)
    return BrokerSettlementReceiptResponse.model_validate(receipt)


@router.put(
    "/receipts/{receipt_id}",
    response_model=BrokerSettlementReceiptResponse,
    summary="Update official settlement receipt",
)
def update_settlement_receipt(
    receipt_id: int,
    payload: BrokerSettlementReceiptUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = BrokerCustodyService(db)
    receipt = service.update_settlement_receipt(receipt_id, payload, current_user=current_user.username)
    return BrokerSettlementReceiptResponse.model_validate(receipt)


@router.delete(
    "/receipts/{receipt_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft delete settlement receipt",
)
def delete_settlement_receipt(
    receipt_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = BrokerCustodyService(db)
    service.delete_settlement_receipt(receipt_id, current_user=current_user.username)
    return None


@router.get(
    "/customs-advances/{adv_id}/reconciliation",
    response_model=CustomsSettlementVarianceResponse,
    summary="Get reconciliation summary & variance for customs broker advance",
)
def get_customs_advance_reconciliation(
    adv_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    service = BrokerCustodyService(db)
    return service.reconcile_customs_settlement(adv_id)


# ===========================================================================
# Legacy Endpoints (Preserved for backwards compatibility)
# ===========================================================================
@router.post(
    "/advances",
    response_model=BrokerCustodyAdvanceResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new Broker Custody Advance (Legacy)",
)
def create_advance(
    payload: BrokerCustodyAdvanceCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = BrokerCustodyService(db)
    advance = service.create_advance(payload, current_user=current_user.username)
    return BrokerCustodyAdvanceResponse.model_validate(advance)


@router.get(
    "/advances",
    response_model=BrokerCustodyAdvanceListResponse,
    summary="List Broker Custody Advances with filtering and pagination (Legacy)",
)
def list_advances(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    import_file_id: Optional[int] = Query(None),
    broker_id: Optional[int] = Query(None),
    status: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    service = BrokerCustodyService(db)
    items, total = service.list_advances(
        skip=skip,
        limit=limit,
        import_file_id=import_file_id,
        broker_id=broker_id,
        status=status,
        search=search,
    )
    return BrokerCustodyAdvanceListResponse(
        total=total,
        items=[BrokerCustodyAdvanceResponse.model_validate(item) for item in items],
    )


@router.get(
    "/advances/{advance_id}",
    response_model=BrokerCustodyAdvanceResponse,
    summary="Get Broker Custody Advance details (Legacy)",
)
def get_advance(
    advance_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    service = BrokerCustodyService(db)
    advance = service.get_advance(advance_id)
    return BrokerCustodyAdvanceResponse.model_validate(advance)


@router.put(
    "/advances/{advance_id}",
    response_model=BrokerCustodyAdvanceResponse,
    summary="Update Broker Custody Advance (Legacy)",
)
def update_advance(
    advance_id: int,
    payload: BrokerCustodyAdvanceUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = BrokerCustodyService(db)
    advance = service.update_advance(advance_id, payload, current_user=current_user.username)
    return BrokerCustodyAdvanceResponse.model_validate(advance)


@router.delete(
    "/advances/{advance_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft-delete Broker Custody Advance (Legacy)",
)
def delete_advance(
    advance_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = BrokerCustodyService(db)
    service.delete_advance(advance_id, current_user=current_user.username)
    return None


@router.post(
    "/advances/{advance_id}/expenses",
    response_model=BrokerExpenseItemResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Add an Expense Item to a Custody Advance (Legacy)",
)
def add_expense_item(
    advance_id: int,
    payload: BrokerExpenseItemCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = BrokerCustodyService(db)
    item = service.add_expense_item(advance_id, payload, current_user=current_user.username)
    return BrokerExpenseItemResponse.model_validate(item)


@router.put(
    "/expenses/{item_id}",
    response_model=BrokerExpenseItemResponse,
    summary="Update an Expense Item (Legacy)",
)
def update_expense_item(
    item_id: int,
    payload: BrokerExpenseItemUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = BrokerCustodyService(db)
    item = service.update_expense_item(item_id, payload, current_user=current_user.username)
    return BrokerExpenseItemResponse.model_validate(item)


@router.patch(
    "/expenses/{item_id}/approval",
    response_model=BrokerExpenseItemResponse,
    summary="Approve or Reject an Expense Item (Legacy)",
)
def approve_expense_item(
    item_id: int,
    payload: ExpenseItemApprovalRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = BrokerCustodyService(db)
    item = service.approve_expense_item(item_id, payload, current_user=current_user.username)
    return BrokerExpenseItemResponse.model_validate(item)


@router.delete(
    "/expenses/{item_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft-delete an Expense Item (Legacy)",
)
def delete_expense_item(
    item_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = BrokerCustodyService(db)
    service.delete_expense_item(item_id, current_user=current_user.username)
    return None


@router.get(
    "/advances/{advance_id}/reconciliation",
    response_model=SettlementReconciliationResponse,
    summary="Get Full Financial Settlement Reconciliation for an Advance (Legacy)",
)
def get_settlement_reconciliation(
    advance_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    service = BrokerCustodyService(db)
    return service.reconcile_settlement(advance_id)


@router.post(
    "/expenses/{item_id}/approve",
    response_model=BrokerExpenseItemResponse,
    summary="Approve or Reject an Expense Item (POST alias)",
)
def approve_expense_item_post(
    item_id: int,
    payload: ExpenseItemApprovalRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = BrokerCustodyService(db)
    item = service.approve_expense_item(item_id, payload, current_user=current_user.username)
    return BrokerExpenseItemResponse.model_validate(item)


@router.post(
    "/advances/{advance_id}/settle",
    response_model=SettlementReconciliationResponse,
    summary="Settle Advance and Reconcile (POST alias)",
)
def settle_advance_post(
    advance_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = BrokerCustodyService(db)
    return service.reconcile_and_settle(advance_id, current_user=current_user.username)
