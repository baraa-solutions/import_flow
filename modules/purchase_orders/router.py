from typing import List, Optional

from fastapi import APIRouter, Depends, Query, Response, status
from modules.auth.router import get_current_user
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.permissions import require_permission
from modules.common.pagination import PageParams
from modules.users.model import User
from modules.purchase_orders.schemas import (
    ClonePurchaseOrderRequest,
    PackingListValidationReport,
    PaginatedPurchaseOrdersResponse,
    PurchaseOrderCreate,
    PurchaseOrderListItem,
    PurchaseOrderResponse,
    PurchaseOrderUpdate,
    POAllocationCreate,
    POAllocationResponse,
    POShipmentAllocationCreate,
    POShipmentAllocationResponse,
    POBalanceSummaryResponse,
)
from modules.purchase_orders.service import PurchaseOrderService

router = APIRouter(
    prefix="/api/v1/purchase-orders",
    tags=["Purchase Orders"],
    dependencies=[Depends(get_current_user)],
)


@router.get("/paginated", response_model=PaginatedPurchaseOrdersResponse)
def list_purchase_orders_paginated(
    response: Response,
    params: PageParams = Depends(),
    status_filter: Optional[str] = Query(None, alias="status"),
    supplier_id: Optional[int] = Query(None),
    company_id: Optional[int] = Query(None),
    project_id: Optional[int] = Query(None),
    currency_id: Optional[int] = Query(None),
    search: Optional[str] = Query(None, description="Legacy alias for q"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("purchase_orders.view")),
):
    service = PurchaseOrderService(db)
    return service.get_paginated(
        params=params,
        response=response,
        status_filter=status_filter,
        supplier_id=supplier_id,
        company_id=company_id,
        project_id=project_id,
        currency_id=currency_id,
        search=search,
    )


@router.get("", response_model=List[PurchaseOrderResponse])
def get_purchase_orders(
    response: Response,
    include_inactive: bool = Query(False),
    status_filter: Optional[str] = Query(None, alias="status"),
    project_id: Optional[int] = Query(None),
    company_id: Optional[int] = Query(None),
    supplier_id: Optional[int] = Query(None),
    search: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: Optional[int] = Query(None, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("purchase_orders.view")),
):
    service = PurchaseOrderService(db)
    items, total = service.get_all(
        include_inactive=include_inactive,
        status_filter=status_filter,
        project_id=project_id,
        company_id=company_id,
        supplier_id=supplier_id,
        search=search,
        skip=skip,
        limit=limit,
        return_total=True,
    )
    response.headers["X-Total-Count"] = str(total)
    return items


@router.get("/{po_id}", response_model=PurchaseOrderResponse)
def get_purchase_order(
    po_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("purchase_orders.view")),
):
    service = PurchaseOrderService(db)
    return service.get_by_id(po_id)


@router.get("/{po_id}/packing-list-report", response_model=PackingListValidationReport)
def get_packing_list_report(
    po_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("purchase_orders.view")),
):
    service = PurchaseOrderService(db)
    return service.get_packing_list_report(po_id)


@router.post("", response_model=PurchaseOrderResponse, status_code=status.HTTP_201_CREATED)
def create_purchase_order(
    data: PurchaseOrderCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("purchase_orders.create")),
):
    service = PurchaseOrderService(db)
    return service.create(data, current_user_name=current_user.username)


@router.put("/{po_id}", response_model=PurchaseOrderResponse)
def update_purchase_order(
    po_id: int,
    data: PurchaseOrderUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("purchase_orders.edit")),
):
    service = PurchaseOrderService(db)
    return service.update(po_id, data, current_user_name=current_user.username)


@router.delete("/{po_id}", response_model=PurchaseOrderResponse)
def delete_purchase_order(
    po_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("purchase_orders.delete")),
):
    service = PurchaseOrderService(db)
    return service.soft_delete(po_id, current_user_name=current_user.username)


@router.post("/{po_id}/restore", response_model=PurchaseOrderResponse)
def restore_purchase_order(
    po_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("purchase_orders.delete")),
):
    service = PurchaseOrderService(db)
    return service.restore(po_id, current_user_name=current_user.username)


@router.post("/{po_id}/allocations", response_model=POShipmentAllocationResponse, status_code=status.HTTP_201_CREATED, summary="تسجيل شحن جزئي وتخصيص كمية لأمر الشراء")
def allocate_po_shipment(
    po_id: int,
    data: POShipmentAllocationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("purchase_orders.edit")),
):
    service = PurchaseOrderService(db)
    return service.allocate_shipment(po_id, data, current_user_name=current_user.username)


@router.get("/{po_id}/balance", response_model=POBalanceSummaryResponse, summary="استخراج ميزان أمر الشراء ونسبة الإنجاز والرصيد المتبقي")
@router.get("/{po_id}/balance-summary", response_model=POBalanceSummaryResponse, summary="استخراج ميزان رصيد أمر الشراء وموقف التوريد")
def get_po_balance(
    po_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("purchase_orders.view")),
):
    service = PurchaseOrderService(db)
    return service.compute_po_balance(po_id)


@router.post("/{po_id}/clone", response_model=PurchaseOrderResponse, status_code=status.HTTP_201_CREATED, summary="Clone a Purchase Order (Universal Clone Engine UX-CLONE-011)")
def clone_purchase_order(
    po_id: int,
    payload: ClonePurchaseOrderRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("purchase_orders.create")),
):
    service = PurchaseOrderService(db)
    return service.clone_purchase_order(po_id, payload, current_user_name=current_user.username)



