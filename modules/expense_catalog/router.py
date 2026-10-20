"""
Expense Catalog Router (AI-EXPENSE-CATALOG-002)
REST API endpoints for Coded Reference Expense Catalog.
"""

from __future__ import annotations

from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from modules.auth.router import get_current_user
from sqlalchemy.orm import Session

from database.database import get_db
from modules.expense_catalog.schemas import (
    ExpenseCatalogCreate,
    ExpenseCatalogUpdate,
    ExpenseCatalogResponse,
    AddPatternRequest,
    BrokerMappingCreate,
    BrokerMappingResponse,
)
from modules.expense_catalog.service import ExpenseCatalogService


router = APIRouter(
    prefix="/api/v1/expense-catalog",
    tags=["Expense Catalog (AI-EXPENSE-CATALOG-002)"],
    dependencies=[Depends(get_current_user)],
)


@router.get(
    "",
    response_model=List[ExpenseCatalogResponse],
    summary="List all reference expense items in the catalog",
)
def list_expense_catalog(
    category: Optional[str] = Query(None, description="Filter by category (Clearance Fees, Procedures & Approvals, etc.)"),
    search: Optional[str] = Query(None, description="Search by code or Arabic/English name"),
    active_only: bool = Query(True, description="Only return active items"),
    db: Session = Depends(get_db),
):
    return ExpenseCatalogService.list_items(
        db, category=category, search=search, active_only=active_only
    )


@router.post(
    "",
    response_model=ExpenseCatalogResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new permanent expense code in the catalog",
)
def create_expense_catalog_item(
    schema: ExpenseCatalogCreate,
    db: Session = Depends(get_db),
):
    return ExpenseCatalogService.create_item(db, schema)


@router.get(
    "/{code}",
    response_model=ExpenseCatalogResponse,
    summary="Get single expense catalog item by code",
)
def get_expense_catalog_item(
    code: str,
    db: Session = Depends(get_db),
):
    return ExpenseCatalogService.get_item(db, code)


@router.put(
    "/{code}",
    response_model=ExpenseCatalogResponse,
    summary="Update an existing expense catalog item",
)
def update_expense_catalog_item(
    code: str,
    schema: ExpenseCatalogUpdate,
    db: Session = Depends(get_db),
):
    return ExpenseCatalogService.update_item(db, code, schema)


@router.post(
    "/{code}/patterns",
    response_model=ExpenseCatalogResponse,
    summary="Add a new recognition pattern / synonym to an existing catalog code",
)
def add_recognition_pattern(
    code: str,
    payload: AddPatternRequest,
    db: Session = Depends(get_db),
):
    return ExpenseCatalogService.add_pattern(db, code, payload.pattern)


@router.delete(
    "/{code}",
    response_model=ExpenseCatalogResponse,
    summary="Deactivate / Soft delete expense catalog item",
)
def delete_expense_catalog_item(
    code: str,
    db: Session = Depends(get_db),
):
    return ExpenseCatalogService.deactivate_item(db, code)


# ── Broker Mapping Memory Endpoints (M1-4) ──

@router.get(
    "/broker-mappings/all",
    response_model=List[BrokerMappingResponse],
    summary="List remembered item mappings for customs brokers",
)
def list_broker_mappings(
    broker_name: Optional[str] = Query(None, description="Filter by broker name"),
):
    from modules.expense_catalog.broker_mapping_service import BrokerMappingMemoryService
    return BrokerMappingMemoryService.list_mappings(broker_name=broker_name)


@router.post(
    "/broker-mappings/remember",
    response_model=BrokerMappingResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Remember an extracted item mapping for a specific customs broker (M1-4)",
)
def create_broker_mapping(
    payload: BrokerMappingCreate,
):
    from modules.expense_catalog.broker_mapping_service import BrokerMappingMemoryService
    return BrokerMappingMemoryService.remember_mapping(
        broker_name=payload.broker_name,
        raw_item_name=payload.raw_item_name,
        catalog_code=payload.catalog_code,
        canonical_name_ar=payload.canonical_name_ar,
        canonical_name_en=payload.canonical_name_en,
        category=payload.category,
        unit_type=payload.unit_type,
    )


@router.delete(
    "/broker-mappings/forget",
    summary="Delete a remembered mapping for a customs broker",
)
def delete_broker_mapping(
    broker_name: Optional[str] = Query(None, description="Broker name"),
    raw_item_name: str = Query(..., description="Raw item name to delete"),
):
    from modules.expense_catalog.broker_mapping_service import BrokerMappingMemoryService
    success = BrokerMappingMemoryService.delete_mapping(broker_name=broker_name, raw_item_name=raw_item_name)
    return {"success": success}


