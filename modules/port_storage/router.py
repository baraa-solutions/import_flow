from typing import List, Optional
from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.router import get_current_user
from modules.auth.permissions import require_permission
from modules.users.model import User

from .schemas import (
    PortStorageBreakdown,
    PortStorageCalculationRequest,
    PortTerminalRateCreate,
    PortTerminalRateUpdate,
    PortTerminalRateResponse,
    PortStorageAccrualCreate,
    PortStorageAccrualUpdate,
    PortStorageAccrualStatusUpdate,
    PortStorageAccrualResponse,
    PortStorageSummaryResponse,
)
from .service import (
    calculate_terminal_storage,
    create_terminal_rate_service,
    list_terminal_rates_service,
    get_terminal_rate_by_id_service,
    update_terminal_rate_service,
    delete_terminal_rate_service,
    create_storage_accrual_service,
    list_storage_accruals_service,
    get_storage_accrual_by_id_service,
    update_storage_accrual_service,
    update_storage_accrual_status_service,
    delete_storage_accrual_service,
    get_port_storage_summary_service,
)

router = APIRouter(
    prefix="/api/v1/port-storage",
    tags=["Port Storage Engine & Terminal Accruals"],
    dependencies=[Depends(get_current_user)],
)

can_view = require_permission("demurrage_detention.view")
can_manage = require_permission("demurrage_detention.manage")


# --- Core Calculator Endpoint ---

@router.post(
    "/calculate",
    response_model=PortStorageBreakdown,
    summary="Calculate port storage charges per container and Egyptian terminal",
)
def calculate_storage_endpoint(
    req: PortStorageCalculationRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    return calculate_terminal_storage(
        terminal_code=req.terminal_code,
        container_size=req.container_size,
        is_reefer=req.is_reefer,
        gate_in=req.gate_in_date,
        current_or_gate_out=req.current_or_gate_out_date,
        db=db,
        include_xray=req.include_xray,
        include_scale=req.include_scale,
    )


# --- Terminal Tariff Rates Endpoints ---

@router.get(
    "/rates",
    response_model=List[PortTerminalRateResponse],
    summary="List port terminal rate cards",
)
def list_terminal_rates_endpoint(
    response: Response,
    terminal_code: Optional[str] = Query(None, description="Filter by terminal code"),
    container_size: Optional[str] = Query(None, description="Filter by container size (20ft, 40ft)"),
    is_reefer: Optional[bool] = Query(None, description="Filter by reefer type"),
    is_active: bool = Query(True, description="Filter active records"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    rates, total = list_terminal_rates_service(
        db,
        terminal_code=terminal_code,
        container_size=container_size,
        is_reefer=is_reefer,
        is_active=is_active,
        skip=skip,
        limit=limit,
    )
    response.headers["X-Total-Count"] = str(total)
    return rates


@router.post(
    "/rates",
    response_model=PortTerminalRateResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create or register a port terminal rate card",
)
def create_terminal_rate_endpoint(
    req: PortTerminalRateCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    return create_terminal_rate_service(db, req, user=current_user.username)


@router.get(
    "/rates/{rate_id}",
    response_model=PortTerminalRateResponse,
    summary="Get single terminal rate card details",
)
def get_terminal_rate_endpoint(
    rate_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    return get_terminal_rate_by_id_service(db, rate_id)


@router.put(
    "/rates/{rate_id}",
    response_model=PortTerminalRateResponse,
    summary="Update terminal rate card",
)
def update_terminal_rate_endpoint(
    rate_id: int,
    req: PortTerminalRateUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    return update_terminal_rate_service(db, rate_id, req, user=current_user.username)


@router.delete(
    "/rates/{rate_id}",
    status_code=status.HTTP_200_OK,
    summary="Delete terminal rate card (Soft delete)",
)
def delete_terminal_rate_endpoint(
    rate_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    delete_terminal_rate_service(db, rate_id, user=current_user.username)
    return {"message": "Terminal rate card deleted successfully."}


# --- Accrual Records Endpoints ---

@router.get(
    "/accruals",
    response_model=List[PortStorageAccrualResponse],
    summary="List port storage container accruals",
)
def list_storage_accruals_endpoint(
    response: Response,
    import_file_id: Optional[int] = Query(None, description="Filter by import file ID"),
    terminal_code: Optional[str] = Query(None, description="Filter by terminal code"),
    container_number: Optional[str] = Query(None, description="Filter by container number"),
    accrual_status: Optional[str] = Query(None, alias="status", description="Filter by status (ESTIMATED, INVOICED, PAID)"),
    is_active: bool = Query(True, description="Filter active records"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    accruals, total = list_storage_accruals_service(
        db,
        import_file_id=import_file_id,
        terminal_code=terminal_code,
        container_number=container_number,
        status=accrual_status,
        is_active=is_active,
        skip=skip,
        limit=limit,
    )
    response.headers["X-Total-Count"] = str(total)
    return accruals


@router.get(
    "/accruals/summary",
    response_model=PortStorageSummaryResponse,
    summary="Get aggregated summary of port storage accruals and statuses",
)
def get_storage_summary_endpoint(
    import_file_id: Optional[int] = Query(None, description="Filter by import file ID"),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    return get_port_storage_summary_service(db, import_file_id=import_file_id)


@router.post(
    "/accruals",
    response_model=PortStorageAccrualResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create port storage container accrual record",
)
def create_storage_accrual_endpoint(
    req: PortStorageAccrualCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    return create_storage_accrual_service(db, req, user=current_user.username)


@router.get(
    "/accruals/{accrual_id}",
    response_model=PortStorageAccrualResponse,
    summary="Get port storage accrual details",
)
def get_storage_accrual_endpoint(
    accrual_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    return get_storage_accrual_by_id_service(db, accrual_id)


@router.put(
    "/accruals/{accrual_id}",
    response_model=PortStorageAccrualResponse,
    summary="Update port storage accrual record",
)
def update_storage_accrual_endpoint(
    accrual_id: int,
    req: PortStorageAccrualUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    return update_storage_accrual_service(db, accrual_id, req, user=current_user.username)


@router.delete(
    "/accruals/{accrual_id}",
    status_code=status.HTTP_200_OK,
    summary="Delete port storage accrual record (Soft delete)",
)
def delete_storage_accrual_endpoint(
    accrual_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    delete_storage_accrual_service(db, accrual_id, user=current_user.username)
    return {"message": "Storage accrual record deleted successfully."}


@router.post(
    "/accruals/{accrual_id}/status",
    response_model=PortStorageAccrualResponse,
    summary="Update accrual billing/payment status (ESTIMATED, INVOICED, PAID)",
)
def update_accrual_status_endpoint(
    accrual_id: int,
    req: PortStorageAccrualStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    return update_storage_accrual_status_service(db, accrual_id, req, user=current_user.username)
