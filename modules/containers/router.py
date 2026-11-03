from typing import Optional, List
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.router import get_current_user
from modules.auth.permissions import require_permission
from modules.users.model import User

from .schemas import (
    ContainerCreate,
    ContainerUpdate,
    ContainerGateOutRequest,
    ContainerEirReturnRequest,
    ContainerEmptyReturnRequest,
    ContainerResponse,
    ContainerListResponse,
    ContainerSyncResponse,
    ContainerLedgerResponse,
)
from .service import (
    create_container_service,
    get_container_by_id_service,
    get_containers_service,
    update_container_service,
    gate_out_container_service,
    empty_return_eir_service,
    empty_return_container_service,
    get_container_ledger_service,
    delete_container_service,
    sync_containers_from_file_service,
)

router = APIRouter(
    prefix="/api/v1/containers",
    tags=["Shipment Containers Management"],
    dependencies=[Depends(get_current_user)],
)


@router.post(
    "/",
    response_model=ContainerResponse,
    status_code=status.HTTP_201_CREATED,
    summary="إضافة حاوية جديدة لشحنة استيرادية",
)
def create_container_endpoint(
    req: ContainerCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.update")),
):
    return create_container_service(db, req, user=current_user.username)


@router.get(
    "/",
    response_model=ContainerListResponse,
    summary="استعراض قائمة الحاويات مع التصفية",
)
def get_containers_endpoint(
    import_file_id: Optional[int] = Query(None, description="تصفية برقم الملف الاستيرادي"),
    status: Optional[str] = Query(None, description="تصفية بالحالة التشغيلية"),
    container_number: Optional[str] = Query(None, description="بحث برقم الحاوية"),
    carrier_name: Optional[str] = Query(None, description="تصفية باسم الخط الملاحي"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.view")),
):
    items, total = get_containers_service(
        db,
        import_file_id=import_file_id,
        status=status,
        container_number=container_number,
        carrier_name=carrier_name,
        skip=skip,
        limit=limit,
    )
    return ContainerListResponse(total=total, items=items)


@router.get(
    "/{container_id}",
    response_model=ContainerResponse,
    summary="جلب تفاصيل حاوية محددة",
)
def get_container_by_id_endpoint(
    container_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.view")),
):
    return get_container_by_id_service(db, container_id)


@router.put(
    "/{container_id}",
    response_model=ContainerResponse,
    summary="تعديل بيانات حاوية تشغيلية",
)
def update_container_endpoint(
    container_id: int,
    req: ContainerUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.update")),
):
    return update_container_service(db, container_id, req, user=current_user.username)


@router.post(
    "/{container_id}/gate-out",
    response_model=ContainerResponse,
    summary="تسجيل خروج الحاوية من بوابة الميناء (Gate-Out)",
)
def gate_out_container_endpoint(
    container_id: int,
    req: ContainerGateOutRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.update")),
):
    return gate_out_container_service(db, container_id, req, user=current_user.username)


@router.post(
    "/{container_id}/empty-return-eir",
    response_model=ContainerResponse,
    summary="توثيق إيصال إرجاع الحاوية الفارغة EIR وإيقاف احتساب الغرامة",
)
def empty_return_eir_endpoint(
    container_id: int,
    req: ContainerEirReturnRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("demurrage_detention.manage")),
):
    return empty_return_eir_service(db, container_id, req, user=current_user.username)


@router.post(
    "/{container_id}/return-empty",
    response_model=ContainerResponse,
    summary="تسجيل إرجاع الحاوية الفارغة للمستودع وإيصال EIR (TR-05)",
)
def empty_return_container_endpoint(
    container_id: int,
    req: ContainerEmptyReturnRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("demurrage_detention.manage")),
):
    return empty_return_container_service(db, container_id, req, user=current_user.username)


@router.get(
    "/import-file/{file_id}/ledger",
    response_model=ContainerLedgerResponse,
    summary="كشف حساب الحاويات وتتبع الغرامات الموقوفة والنشطة لكل حاوية",
)
def get_container_ledger_endpoint(
    file_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.view")),
):
    return get_container_ledger_service(db, import_file_id=file_id)


@router.delete(
    "/{container_id}",
    response_model=ContainerResponse,
    summary="حذف حاوية من الملف (Soft Delete)",
)
def delete_container_endpoint(
    container_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.update")),
):
    return delete_container_service(db, container_id, user=current_user.username)


@router.post(
    "/sync-from-file/{import_file_id}",
    response_model=ContainerSyncResponse,
    summary="مزامنة وجلب بيانات الحاويات من حجز الشحن ومتابعة البواخر والغرامات",
)
def sync_containers_endpoint(
    import_file_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.update")),
):
    synced = sync_containers_from_file_service(db, import_file_id, user=current_user.username)
    return ContainerSyncResponse(
        import_file_id=import_file_id,
        synced_count=len(synced),
        containers=synced,
    )
