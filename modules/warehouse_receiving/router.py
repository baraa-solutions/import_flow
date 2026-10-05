from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.permissions import require_permission
from modules.auth.router import get_current_user
from modules.users.model import User
from .schemas import (
    WarehouseReceivingCreate,
    WarehouseReceivingUpdate,
    WarehouseReceivingResponse,
    DiscrepancyReportSubmit,
    WarehouseDispatchValidationResponse,
    WarehouseInspectionSubmit,
    InspectionSummaryResponse,
)
from .service import (
    create_warehouse_receiving_service,
    get_warehouse_receiving_service,
    get_warehouse_receiving_by_file_service,
    list_warehouse_receivings_service,
    report_receiving_discrepancy_service,
    update_warehouse_receiving_service,
    soft_delete_warehouse_receiving_service,
    restore_warehouse_receiving_service,
    validate_dispatch_service,
    submit_warehouse_inspection_protocol_service,
    get_inspection_summary_service,
)

VIEW = "warehouse_receiving.view"
RECEIVE = "warehouse_receiving.receive"

router = APIRouter(prefix="/api/v1/warehouse-receiving", tags=["Phase 8 - Warehouse Receiving"], dependencies=[Depends(get_current_user)])

@router.get("", response_model=List[WarehouseReceivingResponse])
def list_warehouse_receivings(
    include_inactive: bool = Query(False, description="Include soft-deleted records"),
    import_file_id: Optional[int] = Query(None, description="Filter by import file ID"),
    status_filter: Optional[str] = Query(None, alias="status", description="Filter by operational status"),
    search: Optional[str] = Query(None, description="Search term"),
    db: Session = Depends(get_db),
    _user: User = Depends(require_permission(VIEW)),
):
    return list_warehouse_receivings_service(db, include_inactive, import_file_id, status_filter, search)

@router.post("", response_model=WarehouseReceivingResponse, status_code=status.HTTP_201_CREATED)
def create_warehouse_receiving(
    schema: WarehouseReceivingCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(RECEIVE)),
):
    return create_warehouse_receiving_service(db, schema, user=current_user.username)

@router.get("/by-file/{import_file_id}", response_model=Optional[WarehouseReceivingResponse])
def get_warehouse_receiving_by_file(
    import_file_id: int,
    db: Session = Depends(get_db),
    _user: User = Depends(require_permission(VIEW)),
):
    return get_warehouse_receiving_by_file_service(db, import_file_id)

@router.get("/{record_id}", response_model=WarehouseReceivingResponse)
def get_warehouse_receiving(
    record_id: int,
    db: Session = Depends(get_db),
    _user: User = Depends(require_permission(VIEW)),
):
    return get_warehouse_receiving_service(db, record_id)

@router.put("/{record_id}", response_model=WarehouseReceivingResponse)
def update_warehouse_receiving(
    record_id: int,
    schema: WarehouseReceivingUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(RECEIVE)),
):
    return update_warehouse_receiving_service(db, record_id, schema, user=current_user.username)

@router.post("/{record_id}/report-discrepancy", response_model=WarehouseReceivingResponse)
def report_receiving_discrepancy(
    record_id: int,
    payload: DiscrepancyReportSubmit,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(RECEIVE)),
):
    return report_receiving_discrepancy_service(db, record_id, payload, user=current_user.username)

@router.post("/{record_id}/inspection-protocol", response_model=WarehouseReceivingResponse, summary="اعتماد محضر الفحص الفني ومطابقة العجز والتالف بالمخازن (TR-04)")
def submit_inspection_protocol(
    record_id: int,
    payload: WarehouseInspectionSubmit,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(RECEIVE)),
):
    return submit_warehouse_inspection_protocol_service(db, record_id, payload, user_name=current_user.username)

@router.get("/{record_id}/inspection-protocol", response_model=InspectionSummaryResponse, summary="استعراض ملخص محضر الفحص والمطابقة (TR-04)")
def get_inspection_summary(
    record_id: int,
    db: Session = Depends(get_db),
    _user: User = Depends(require_permission(VIEW)),
):
    return get_inspection_summary_service(db, record_id)

@router.post("/{record_id}/validate-dispatch", response_model=WarehouseDispatchValidationResponse, summary="التحقق من تصريح صرف البضاعة من المخزن وخلوها من قفل التحفظ الجمركي")
def validate_dispatch(
    record_id: int,
    db: Session = Depends(get_db),
    _user: User = Depends(require_permission(VIEW)),
):
    return validate_dispatch_service(db, record_id)


@router.delete("/{record_id}", status_code=status.HTTP_204_NO_CONTENT)
def soft_delete_warehouse_receiving(
    record_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(RECEIVE)),
):
    soft_delete_warehouse_receiving_service(db, record_id, user=current_user.username)
    return None

@router.patch("/{record_id}/restore", response_model=WarehouseReceivingResponse)
def restore_warehouse_receiving(
    record_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(RECEIVE)),
):
    return restore_warehouse_receiving_service(db, record_id, user=current_user.username)
