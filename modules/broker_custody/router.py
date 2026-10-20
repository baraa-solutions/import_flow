from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.router import get_current_user
from modules.broker_custody.schemas import (
    BrokerCustodyAdvanceCreate,
    BrokerCustodyAdvanceUpdate,
    BrokerCustodyAdvanceResponse,
    BrokerCustodyAdvanceListResponse,
    BrokerExpenseItemCreate,
    BrokerExpenseItemUpdate,
    BrokerExpenseItemResponse,
    ExpenseItemApprovalRequest,
    SettlementReconciliationResponse,
)
from modules.broker_custody.service import BrokerCustodyService
from modules.users.model import User

router = APIRouter(
    prefix="/api/v1/broker-custody",
    tags=["Broker Custody & Settlement"],
    dependencies=[Depends(get_current_user)],
)


# ---------------------------------------------------------------------------
# Custody Advance Endpoints
# ---------------------------------------------------------------------------
@router.post(
    "/advances",
    response_model=BrokerCustodyAdvanceResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new Broker Custody Advance",
)
def create_advance(
    payload: BrokerCustodyAdvanceCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = BrokerCustodyService(db)
    advance = service.create_advance(payload, current_user=current_user.username)
    return BrokerCustodyAdvanceResponse.model_validate(advance)


@router.get(
    "/advances",
    response_model=BrokerCustodyAdvanceListResponse,
    summary="List Broker Custody Advances with filtering and pagination",
)
def list_advances(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    import_file_id: Optional[int] = Query(None),
    broker_id: Optional[int] = Query(None),
    status: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
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
    summary="Get single Broker Custody Advance details with expense items",
)
def get_advance(
    advance_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = BrokerCustodyService(db)
    advance = service.get_advance(advance_id)
    return BrokerCustodyAdvanceResponse.model_validate(advance)


@router.put(
    "/advances/{advance_id}",
    response_model=BrokerCustodyAdvanceResponse,
    summary="Update Broker Custody Advance details",
)
def update_advance(
    advance_id: int,
    payload: BrokerCustodyAdvanceUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = BrokerCustodyService(db)
    advance = service.update_advance(advance_id, payload, current_user=current_user.username)
    return BrokerCustodyAdvanceResponse.model_validate(advance)


@router.delete(
    "/advances/{advance_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft delete Broker Custody Advance",
)
def delete_advance(
    advance_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = BrokerCustodyService(db)
    service.delete_advance(advance_id, current_user=current_user.username)
    return None


# ---------------------------------------------------------------------------
# Expense Items Endpoints
# ---------------------------------------------------------------------------
@router.post(
    "/advances/{advance_id}/expenses",
    response_model=BrokerExpenseItemResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Add an Expense Item to a Custody Advance (calculates 1% WHT)",
)
def add_expense_item(
    advance_id: int,
    payload: BrokerExpenseItemCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = BrokerCustodyService(db)
    item = service.add_expense_item(advance_id, payload, current_user=current_user.username)
    return BrokerExpenseItemResponse.model_validate(item)


@router.get(
    "/advances/{advance_id}/expenses",
    response_model=List[BrokerExpenseItemResponse],
    summary="List all Expense Items for a Custody Advance",
)
def list_expense_items(
    advance_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = BrokerCustodyService(db)
    items = service.list_expense_items(advance_id)
    return [BrokerExpenseItemResponse.model_validate(item) for item in items]


@router.get(
    "/expenses/{item_id}",
    response_model=BrokerExpenseItemResponse,
    summary="Get single Expense Item details",
)
def get_expense_item(
    item_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = BrokerCustodyService(db)
    item = service.get_expense_item(item_id)
    return BrokerExpenseItemResponse.model_validate(item)


@router.put(
    "/expenses/{item_id}",
    response_model=BrokerExpenseItemResponse,
    summary="Update Expense Item details and recalculate WHT",
)
def update_expense_item(
    item_id: int,
    payload: BrokerExpenseItemUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = BrokerCustodyService(db)
    item = service.update_expense_item(item_id, payload, current_user=current_user.username)
    return BrokerExpenseItemResponse.model_validate(item)


@router.post(
    "/expenses/{item_id}/approve",
    response_model=BrokerExpenseItemResponse,
    summary="Approve or reject petty cash or sundry expense item",
)
def approve_expense_item(
    item_id: int,
    payload: ExpenseItemApprovalRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = BrokerCustodyService(db)
    item = service.approve_petty_cash(item_id, payload, current_user=current_user.username)
    return BrokerExpenseItemResponse.model_validate(item)


@router.delete(
    "/expenses/{item_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft delete Expense Item",
)
def delete_expense_item(
    item_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = BrokerCustodyService(db)
    service.delete_expense_item(item_id, current_user=current_user.username)
    return None


# ---------------------------------------------------------------------------
# Settlement Reconciliation (/settle)
# ---------------------------------------------------------------------------
@router.post(
    "/advances/{advance_id}/settle",
    response_model=SettlementReconciliationResponse,
    summary="Reconcile and Settle Custody Advance against approved expense items",
)
def settle_advance(
    advance_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = BrokerCustodyService(db)
    return service.reconcile_and_settle(advance_id, current_user=current_user.username)
