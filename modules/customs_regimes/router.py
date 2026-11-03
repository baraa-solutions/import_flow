"""
FastAPI Router for Customs Special & Suspended Duty Regimes
"""

from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.permissions import require_permission
from modules.customs_regimes.schemas import (
    CustomsRegimeCreate,
    CustomsRegimeListOut,
    CustomsRegimeOut,
    CustomsRegimeSettle,
    CustomsRegimeUpdate,
)
from modules.customs_regimes.service import CustomsRegimesService
from modules.users.model import User

router = APIRouter(
    prefix="/api/v1/customs-regimes",
    tags=["Customs Special Regimes"],
)

can_view = require_permission("customs_regimes.view")
can_manage = require_permission("customs_regimes.manage")
can_settle = require_permission("customs_regimes.settle")


@router.get("", response_model=CustomsRegimeListOut, summary="List customs special regimes")
def list_regimes(
    import_file_id: Optional[int] = Query(None, description="Filter by import file ID"),
    regime_type: Optional[str] = Query(None, description="Filter by regime type"),
    status: Optional[str] = Query(None, description="Filter by status"),
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    skip = (page - 1) * size
    service = CustomsRegimesService(db)
    items, total = service.list_regimes(
        import_file_id=import_file_id,
        regime_type=regime_type,
        status_filter=status,
        skip=skip,
        limit=size,
    )
    return CustomsRegimeListOut(items=items, total=total, page=page, size=size)


@router.get("/{regime_id}", response_model=CustomsRegimeOut, summary="Get customs regime by ID")
def get_regime(
    regime_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    service = CustomsRegimesService(db)
    return service.get_regime(regime_id)


@router.post("", response_model=CustomsRegimeOut, status_code=status.HTTP_201_CREATED, summary="Create new customs regime")
def create_regime(
    payload: CustomsRegimeCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = CustomsRegimesService(db)
    return service.create_regime(payload, user_id=current_user.user_id)


@router.put("/{regime_id}", response_model=CustomsRegimeOut, summary="Update customs regime")
def update_regime(
    regime_id: int,
    payload: CustomsRegimeUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = CustomsRegimesService(db)
    return service.update_regime(regime_id, payload, user_id=current_user.user_id)


@router.post("/{regime_id}/settle", response_model=CustomsRegimeOut, summary="Settle and reconcile customs regime")
def settle_regime(
    regime_id: int,
    payload: CustomsRegimeSettle,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_settle),
):
    service = CustomsRegimesService(db)
    return service.settle_regime(regime_id, payload, user_id=current_user.user_id)


@router.delete("/{regime_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Soft delete customs regime")
def delete_regime(
    regime_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = CustomsRegimesService(db)
    service.delete_regime(regime_id, user_id=current_user.user_id)
    return None
