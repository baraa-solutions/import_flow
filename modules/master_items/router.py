"""
Master Items Router (MD-ITEM-001)
REST API endpoints for Master Items, Supplier Catalogs, and Price Trend Analytics.
"""

from __future__ import annotations

from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.router import get_current_user
from modules.auth.permissions import require_permission
from modules.users.model import User
from modules.master_items.schemas import (
    MasterItemCreate,
    MasterItemUpdate,
    MasterItemResponse,
    MasterItemListResponse,
    ItemSupplierCatalogCreate,
    ItemSupplierCatalogResponse,
    ItemPriceHistoryCreate,
    ItemPriceHistoryResponse,
    ItemPriceTrendResponse,
)
from modules.master_items.service import MasterItemService


router = APIRouter(
    prefix="/api/v1/master-items",
    tags=["Master Items (MD-ITEM-001)"],
    dependencies=[Depends(get_current_user)],
)


# ==================================================
# 1. Master Items CRUD
# ==================================================

@router.get(
    "",
    response_model=MasterItemListResponse,
    summary="List master items with filtering and search",
    dependencies=[Depends(require_permission("master_data.view"))],
)
def list_master_items(
    search: Optional[str] = Query(None, description="Search by item code or Arabic/English description"),
    category: Optional[str] = Query(None, description="Filter by product category"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
):
    return MasterItemService.list_items(
        db, search=search, category=category, skip=skip, limit=limit
    )


@router.post(
    "",
    response_model=MasterItemResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new master item in the catalog",
    dependencies=[Depends(require_permission("master_data.edit"))],
)
def create_master_item(
    payload: MasterItemCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return MasterItemService.create_item(
        db, payload, current_username=current_user.username
    )


@router.get(
    "/{item_id}",
    response_model=MasterItemResponse,
    summary="Get single master item by ID",
    dependencies=[Depends(require_permission("master_data.view"))],
)
def get_master_item(
    item_id: int,
    db: Session = Depends(get_db),
):
    return MasterItemService.get_item(db, item_id)


@router.put(
    "/{item_id}",
    response_model=MasterItemResponse,
    summary="Update an existing master item",
    dependencies=[Depends(require_permission("master_data.edit"))],
)
def update_master_item(
    item_id: int,
    payload: MasterItemUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return MasterItemService.update_item(
        db, item_id, payload, current_username=current_user.username
    )


@router.delete(
    "/{item_id}",
    summary="Soft-delete a master item",
    dependencies=[Depends(require_permission("master_data.edit"))],
)
def delete_master_item(
    item_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return MasterItemService.delete_item(
        db, item_id, current_username=current_user.username
    )


# ==================================================
# 2. Supplier Catalog Linkages
# ==================================================

@router.post(
    "/supplier-link",
    response_model=ItemSupplierCatalogResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Link an item to an overseas supplier with part code and quoted price",
    dependencies=[Depends(require_permission("master_data.edit"))],
)
def link_item_supplier(
    payload: ItemSupplierCatalogCreate,
    db: Session = Depends(get_db),
):
    return MasterItemService.link_supplier(db, payload)


@router.get(
    "/{item_id}/suppliers",
    response_model=List[ItemSupplierCatalogResponse],
    summary="List all linked suppliers and quotes for an item",
    dependencies=[Depends(require_permission("master_data.view"))],
)
def list_item_suppliers(
    item_id: int,
    db: Session = Depends(get_db),
):
    return MasterItemService.list_suppliers_for_item(db, item_id)


# ==================================================
# 3. Price History & Trend Reports
# ==================================================

@router.post(
    "/price-history",
    response_model=ItemPriceHistoryResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Record historical purchase order price for an item",
    dependencies=[Depends(require_permission("master_data.edit"))],
)
def record_item_price_history(
    payload: ItemPriceHistoryCreate,
    db: Session = Depends(get_db),
):
    return MasterItemService.record_price_history(db, payload)


@router.get(
    "/{item_id}/price-trends",
    response_model=ItemPriceTrendResponse,
    summary="Analyze historical price trends and landed cost markup across deals",
    dependencies=[Depends(require_permission("master_data.view"))],
)
def get_item_price_trends(
    item_id: int,
    db: Session = Depends(get_db),
):
    return MasterItemService.get_price_trends(db, item_id)
