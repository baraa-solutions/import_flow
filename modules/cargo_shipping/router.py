from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from modules.auth.router import get_current_user
from sqlalchemy.orm import Session

from database.database import get_db
from .schemas import (
    CargoShippingCreate,
    CargoShippingUpdate,
    CargoShippingResponse,
    ContainerLoadingTrackingUpdate,
    LclLoadingTrackingItem,
    DualApprovalLevel1Submit,
    DualApprovalLevel2Submit,
)
from .service import (
    create_cargo_shipping_service,
    get_cargo_shipping_service,
    list_cargo_shippings_service,
    update_container_loading_tracking_service,
    update_lcl_loading_tracking_service,
    submit_level1_approval_service,
    submit_level2_approval_service,
    execute_cargox_checklist_service,
    advance_cargox_stage_service,
    update_cargo_shipping_service,
    soft_delete_cargo_shipping_service,
    restore_cargo_shipping_service,
)

router = APIRouter(prefix="/api/v1/cargo-shipping", tags=["Cargo Preparation & Shipping (Phase 5)"], dependencies=[Depends(get_current_user)])

@router.post("", response_model=CargoShippingResponse, status_code=status.HTTP_201_CREATED)
def create_cargo_shipping(
    payload: CargoShippingCreate,
    auto_upsert: bool = Query(True),
    auto_advance_lifecycle: bool = Query(True),
    db: Session = Depends(get_db),
):
    return create_cargo_shipping_service(db, payload, auto_upsert=auto_upsert, auto_advance_lifecycle=auto_advance_lifecycle)

@router.get("", response_model=List[CargoShippingResponse])
def list_cargo_shippings(
    include_inactive: bool = Query(False),
    import_file_id: Optional[int] = Query(None),
    status: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    return list_cargo_shippings_service(db, include_inactive, import_file_id, status, search)

@router.get("/{record_id}", response_model=CargoShippingResponse)
def get_cargo_shipping(record_id: int, db: Session = Depends(get_db)):
    return get_cargo_shipping_service(db, record_id, include_inactive=True)

@router.put("/{record_id}", response_model=CargoShippingResponse)
def update_cargo_shipping(
    record_id: int,
    payload: CargoShippingUpdate,
    auto_advance_lifecycle: bool = Query(True),
    db: Session = Depends(get_db),
):
    return update_cargo_shipping_service(db, record_id, payload, auto_advance_lifecycle=auto_advance_lifecycle)

@router.patch("/{record_id}/containers/{container_no}/loading-tracking", response_model=CargoShippingResponse)
def update_container_loading_tracking(
    record_id: int,
    container_no: str,
    payload: ContainerLoadingTrackingUpdate,
    db: Session = Depends(get_db),
):
    return update_container_loading_tracking_service(db, record_id, container_no, payload)

@router.post("/{record_id}/loading-tracking/lcl", response_model=CargoShippingResponse)
def update_lcl_loading_tracking(
    record_id: int,
    payload: LclLoadingTrackingItem,
    db: Session = Depends(get_db),
):
    return update_lcl_loading_tracking_service(db, record_id, payload)

@router.post("/{record_id}/approval/level1", response_model=CargoShippingResponse)
def submit_level1_approval(record_id: int, payload: DualApprovalLevel1Submit, db: Session = Depends(get_db)):
    return submit_level1_approval_service(db, record_id, payload)

@router.post("/{record_id}/approval/level2", response_model=CargoShippingResponse)
def submit_level2_approval(record_id: int, payload: DualApprovalLevel2Submit, db: Session = Depends(get_db)):
    return submit_level2_approval_service(db, record_id, payload)

@router.post("/{record_id}/cargox/run-checklist", response_model=CargoShippingResponse)
def run_cargox_checklist(record_id: int, db: Session = Depends(get_db)):
    return execute_cargox_checklist_service(db, record_id)

@router.post("/{record_id}/cargox/advance-stage", response_model=CargoShippingResponse)
def advance_cargox_stage(record_id: int, target_stage: str = Query(...), db: Session = Depends(get_db)):
    return advance_cargox_stage_service(db, record_id, target_stage)

@router.delete("/{record_id}", status_code=status.HTTP_204_NO_CONTENT)
def soft_delete_cargo_shipping(record_id: int, db: Session = Depends(get_db)):
    soft_delete_cargo_shipping_service(db, record_id)
    return None

@router.post("/{record_id}/restore", response_model=CargoShippingResponse)
@router.patch("/{record_id}/restore", response_model=CargoShippingResponse)
def restore_cargo_shipping(record_id: int, db: Session = Depends(get_db)):
    return restore_cargo_shipping_service(db, record_id)
