from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.router import get_current_user
from modules.auth.permissions import require_permission
from modules.users.model import User

from .schemas import (
    ContainerDepositCreate,
    ContainerDepositUpdate,
    ContainerDepositResponse,
    ContainerDepositListResponse,
    RecordEIRReturnRequest,
    RecordDepositRefundRequest,
    DisputeDeductionRequest,
    ContainerDepositOverviewResponse,
)
from .service import ContainerDepositService

router = APIRouter(
    prefix="/api/v1/container-deposit",
    tags=["Shipping Line Container Deposit & EIR Empty Return Ledger"],
    dependencies=[Depends(get_current_user)],
)


@router.post(
    "",
    response_model=ContainerDepositResponse,
    status_code=status.HTTP_201_CREATED,
    summary="تسجيل تأمين حاوية جديد مدفوع للخط الملاحي",
)
def create_container_deposit_endpoint(
    payload: ContainerDepositCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.update")),
):
    return ContainerDepositService.create_deposit(db, payload, user=current_user.username)


@router.get(
    "/alerts/overdue",
    response_model=ContainerDepositOverviewResponse,
    summary="لوحة متابعة تأمينات الحاويات المتأخرة عن مهلة الاسترداد (30 يوماً بعد الـ EIR)",
)
def get_container_deposit_alerts_endpoint(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.view")),
):
    return ContainerDepositService.get_overview_and_alerts(db)


@router.get(
    "",
    response_model=ContainerDepositListResponse,
    summary="استعراض سجل تأمينات الحاويات مع البحث والتصفية",
)
def list_container_deposits_endpoint(
    include_inactive: bool = Query(False, description="تضمين السجلات المحذوفة"),
    import_file_id: Optional[int] = Query(None, description="تصفية برقم الملف الاستيرادي"),
    carrier_name: Optional[str] = Query(None, description="تصفية باسم التوكيل أو الخط الملاحي"),
    refund_status: Optional[str] = Query(None, description="تصفية بحالة الاسترداد"),
    container_number: Optional[str] = Query(None, description="بحث برقم الحاوية"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.view")),
):
    items, total = ContainerDepositService.list_deposits(
        db,
        include_inactive=include_inactive,
        import_file_id=import_file_id,
        carrier_name=carrier_name,
        refund_status=refund_status,
        container_number=container_number,
        skip=skip,
        limit=limit,
    )
    return ContainerDepositListResponse(total=total, items=items)


@router.get(
    "/{deposit_id}",
    response_model=ContainerDepositResponse,
    summary="جلب تفاصيل تأمين حاوية محدد",
)
def get_container_deposit_endpoint(
    deposit_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.view")),
):
    return ContainerDepositService.get_deposit(db, deposit_id)


@router.put(
    "/{deposit_id}",
    response_model=ContainerDepositResponse,
    summary="تحديث بيانات تأمين حاوية",
)
def update_container_deposit_endpoint(
    deposit_id: int,
    payload: ContainerDepositUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.update")),
):
    return ContainerDepositService.update_deposit(db, deposit_id, payload, user=current_user.username)


@router.delete(
    "/{deposit_id}",
    response_model=ContainerDepositResponse,
    summary="حذف ناعم لسجل تأمين الحاوية",
)
def delete_container_deposit_endpoint(
    deposit_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.update")),
):
    return ContainerDepositService.soft_delete_deposit(db, deposit_id, user=current_user.username)


@router.post(
    "/{deposit_id}/record-eir",
    response_model=ContainerDepositResponse,
    summary="تسجيل إيصال استرجاع الحاوية الفارغة (EIR) وحالة الحاوية",
)
def record_eir_return_endpoint(
    deposit_id: int,
    payload: RecordEIRReturnRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.update")),
):
    return ContainerDepositService.record_eir_return(db, deposit_id, payload, user=current_user.username)


@router.post(
    "/{deposit_id}/record-refund",
    response_model=ContainerDepositResponse,
    summary="تسجيل استلام شيك أو تحويل استرداد التأمين من الخط الملاحي",
)
def record_deposit_refund_endpoint(
    deposit_id: int,
    payload: RecordDepositRefundRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.update")),
):
    return ContainerDepositService.record_refund(db, deposit_id, payload, user=current_user.username)


@router.post(
    "/{deposit_id}/dispute-deduction",
    response_model=ContainerDepositResponse,
    summary="تسجيل اعتراض على خصومات الأضرار أو النظافة وتعديلها أو إعفائها",
)
def dispute_deduction_endpoint(
    deposit_id: int,
    payload: DisputeDeductionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.update")),
):
    return ContainerDepositService.dispute_deduction(db, deposit_id, payload, user=current_user.username)
