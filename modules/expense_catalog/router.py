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

