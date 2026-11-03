"""
FastAPI Router for Logistics Exceptions & Disruptions
"""

from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.permissions import require_permission
from modules.logistics_exceptions.schemas import (
    AcidImpactResolution,
    ExceptionMetricsOut,
    ExceptionResolveRequest,
    LogisticsExceptionCreate,
    LogisticsExceptionListOut,
    LogisticsExceptionOut,
    LogisticsExceptionUpdate,
    ValuationDisputeAppeal,
)
from modules.logistics_exceptions.service import LogisticsExceptionsService
from modules.users.model import User

router = APIRouter(
    prefix="/api/v1/logistics-exceptions",
    tags=["Logistics Exceptions & Operational Disruptions"],
)

can_view = require_permission("cargo_shipping.view")
can_manage = require_permission("cargo_shipping.update")


@router.get("", response_model=LogisticsExceptionListOut, summary="List exceptions")
def list_exceptions(
    import_file_id: Optional[int] = Query(None, description="Filter by import file"),
    exception_type: Optional[str] = Query(None, description="Filter by exception type"),
    severity: Optional[str] = Query(None, description="Filter by severity"),
    status_filter: Optional[str] = Query(None, alias="status", description="Filter by status"),
    search: Optional[str] = Query(None, description="Search keyword"),
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    skip = (page - 1) * size
    service = LogisticsExceptionsService(db)
    items, total = service.list_exceptions(
        skip=skip,
        limit=size,
        import_file_id=import_file_id,
        exception_type=exception_type,
        severity=severity,
        status=status_filter,
        search=search,
    )
    return LogisticsExceptionListOut(items=items, total=total, page=page, size=size)


@router.get("/metrics", response_model=ExceptionMetricsOut, summary="Get operational disruption KPIs")
def get_metrics(
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    service = LogisticsExceptionsService(db)
    return service.get_metrics()


@router.get("/{exception_id}", response_model=LogisticsExceptionOut, summary="Get exception details")
def get_exception(
    exception_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    service = LogisticsExceptionsService(db)
    return service.get_by_id(exception_id)


@router.post("", response_model=LogisticsExceptionOut, status_code=status.HTTP_201_CREATED, summary="Log a new exception")
def log_exception(
    data: LogisticsExceptionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = LogisticsExceptionsService(db)
    return service.log_exception(data, current_user_id=current_user.user_id)


@router.put("/{exception_id}", response_model=LogisticsExceptionOut, summary="Update exception")
def update_exception(
    exception_id: int,
    data: LogisticsExceptionUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = LogisticsExceptionsService(db)
    return service.update_exception(exception_id, data, current_user_id=current_user.user_id)


@router.post("/{exception_id}/acid-resolve", response_model=LogisticsExceptionOut, summary="Align ACID expiry")
def resolve_acid_impact(
    exception_id: int,
    resolution: AcidImpactResolution,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = LogisticsExceptionsService(db)
    return service.resolve_acid_impact(exception_id, resolution, current_user_id=current_user.user_id)


@router.post("/{exception_id}/valuation-appeal", response_model=LogisticsExceptionOut, summary="File valuation dispute appeal")
def submit_valuation_appeal(
    exception_id: int,
    appeal: ValuationDisputeAppeal,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = LogisticsExceptionsService(db)
    return service.submit_valuation_appeal(exception_id, appeal, current_user_id=current_user.user_id)


@router.post("/{exception_id}/resolve", response_model=LogisticsExceptionOut, summary="Resolve and close exception")
def resolve_exception(
    exception_id: int,
    request: ExceptionResolveRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = LogisticsExceptionsService(db)
    return service.resolve_exception(exception_id, request, current_user_id=current_user.user_id)


@router.delete("/{exception_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Soft delete exception")
def delete_exception(
    exception_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = LogisticsExceptionsService(db)
    service.delete_exception(exception_id)
    return None
