"""
FastAPI Router for Trade Finance
"""

from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.permissions import require_permission
from modules.trade_finance.schemas import (
    FxHedgingAndVarianceCreate,
    FxHedgingAndVarianceResponse,
    FxHedgingAndVarianceUpdate,
    ImportFinanceInstrumentCreate,
    ImportFinanceInstrumentListResponse,
    ImportFinanceInstrumentResponse,
    ImportFinanceInstrumentUpdate,
    LcBankChargeCreate,
    LcBankChargeResponse,
)
from modules.trade_finance.service import TradeFinanceService
from modules.users.model import User

router = APIRouter(
    prefix="/api/v1/trade-finance",
    tags=["Trade Finance & Supplier Letters of Credit"],
)

can_view = require_permission("trade_finance.view")
can_manage = require_permission("trade_finance.manage")


# -------------------------------------------------------------
# Instruments Endpoints
# -------------------------------------------------------------
@router.post(
    "/instruments",
    response_model=ImportFinanceInstrumentResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create import finance instrument (LC / CAD / Advance)",
)
def create_finance_instrument(
    payload: ImportFinanceInstrumentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = TradeFinanceService(db)
    inst = service.create_instrument(payload, current_user=current_user.username)
    return ImportFinanceInstrumentResponse.model_validate(inst)


@router.get(
    "/instruments",
    response_model=ImportFinanceInstrumentListResponse,
    summary="List finance instruments with filtering",
)
def list_finance_instruments(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    import_file_id: Optional[int] = Query(None),
    instrument_type: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    service = TradeFinanceService(db)
    items, total = service.list_instruments(
        skip=skip,
        limit=limit,
        import_file_id=import_file_id,
        instrument_type=instrument_type,
        status=status,
        search=search,
    )
    return ImportFinanceInstrumentListResponse(
        total=total,
        items=[ImportFinanceInstrumentResponse.model_validate(it) for it in items],
    )


@router.get(
    "/instruments/{inst_id}",
    response_model=ImportFinanceInstrumentResponse,
    summary="Get finance instrument details",
)
def get_finance_instrument(
    inst_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    service = TradeFinanceService(db)
    inst = service.get_instrument(inst_id)
    return ImportFinanceInstrumentResponse.model_validate(inst)


@router.put(
    "/instruments/{inst_id}",
    response_model=ImportFinanceInstrumentResponse,
    summary="Update finance instrument",
)
def update_finance_instrument(
    inst_id: int,
    payload: ImportFinanceInstrumentUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = TradeFinanceService(db)
    inst = service.update_instrument(inst_id, payload, current_user=current_user.username)
    return ImportFinanceInstrumentResponse.model_validate(inst)


@router.delete(
    "/instruments/{inst_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft delete finance instrument",
)
def delete_finance_instrument(
    inst_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = TradeFinanceService(db)
    service.delete_instrument(inst_id, current_user=current_user.username)
    return None


# -------------------------------------------------------------
# Bank Charges Endpoints
# -------------------------------------------------------------
@router.post(
    "/instruments/{inst_id}/charges",
    response_model=LcBankChargeResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Add bank charge to finance instrument",
)
def add_bank_charge(
    inst_id: int,
    payload: LcBankChargeCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = TradeFinanceService(db)
    charge = service.add_bank_charge(inst_id, payload, current_user=current_user.username)
    return LcBankChargeResponse.model_validate(charge)


@router.delete(
    "/charges/{charge_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft delete bank charge",
)
def delete_bank_charge(
    charge_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = TradeFinanceService(db)
    service.delete_bank_charge(charge_id, current_user=current_user.username)
    return None


# -------------------------------------------------------------
# FX Hedging & Variance Endpoints
# -------------------------------------------------------------
@router.post(
    "/instruments/{inst_id}/fx",
    response_model=FxHedgingAndVarianceResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Add FX booking / hedging record",
)
def add_fx_record(
    inst_id: int,
    payload: FxHedgingAndVarianceCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = TradeFinanceService(db)
    fx = service.add_fx_record(inst_id, payload, current_user=current_user.username)
    return FxHedgingAndVarianceResponse.model_validate(fx)


@router.put(
    "/fx/{fx_id}",
    response_model=FxHedgingAndVarianceResponse,
    summary="Update FX settlement & calculate variance",
)
def update_fx_record(
    fx_id: int,
    payload: FxHedgingAndVarianceUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = TradeFinanceService(db)
    fx = service.update_fx_record(fx_id, payload, current_user=current_user.username)
    return FxHedgingAndVarianceResponse.model_validate(fx)


@router.delete(
    "/fx/{fx_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft delete FX record",
)
def delete_fx_record(
    fx_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = TradeFinanceService(db)
    service.delete_fx_record(fx_id, current_user=current_user.username)
    return None
