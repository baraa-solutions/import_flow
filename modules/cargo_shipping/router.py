from typing import List, Literal, Optional
from fastapi import APIRouter, Depends, Query, status
from modules.auth.router import get_current_user
from modules.auth.permissions import require_permission
from modules.users.model import User
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

CargoXTargetStage = Literal["Ready for Upload", "Uploaded", "Completed"]


@router.post("", response_model=CargoShippingResponse, status_code=status.HTTP_201_CREATED)
def create_cargo_shipping(
    payload: CargoShippingCreate,
    auto_upsert: bool = Query(True),
    auto_advance_lifecycle: bool = Query(True),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.update")),
):
    return create_cargo_shipping_service(
        db, payload, auto_upsert=auto_upsert, auto_advance_lifecycle=auto_advance_lifecycle, user=current_user.username
    )


@router.get("", response_model=List[CargoShippingResponse])
def list_cargo_shippings(
    include_inactive: bool = Query(False),
    import_file_id: Optional[int] = Query(None),
    status: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.view")),
):
    return list_cargo_shippings_service(db, include_inactive, import_file_id, status, search)


@router.get("/{record_id}", response_model=CargoShippingResponse)
def get_cargo_shipping(
    record_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.view")),
):
    return get_cargo_shipping_service(db, record_id, include_inactive=True)


@router.put("/{record_id}", response_model=CargoShippingResponse)
def update_cargo_shipping(
    record_id: int,
    payload: CargoShippingUpdate,
    auto_advance_lifecycle: bool = Query(True),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.update")),
):
    return update_cargo_shipping_service(
        db, record_id, payload, auto_advance_lifecycle=auto_advance_lifecycle, user=current_user.username
    )


@router.patch("/{record_id}/containers/{container_no}/loading-tracking", response_model=CargoShippingResponse)
def update_container_loading_tracking(
    record_id: int,
    container_no: str,
    payload: ContainerLoadingTrackingUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.update")),
):
    return update_container_loading_tracking_service(db, record_id, container_no, payload, user=current_user.username)


@router.post("/{record_id}/loading-tracking/lcl", response_model=CargoShippingResponse)
def update_lcl_loading_tracking(
    record_id: int,
    payload: LclLoadingTrackingItem,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.update")),
):
    return update_lcl_loading_tracking_service(db, record_id, payload, user=current_user.username)


@router.post("/{record_id}/approval/level1", response_model=CargoShippingResponse)
def submit_level1_approval(
    record_id: int,
    payload: DualApprovalLevel1Submit,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.update")),
):
    return submit_level1_approval_service(db, record_id, payload, user=current_user.username)


@router.post("/{record_id}/approval/level2", response_model=CargoShippingResponse)
def submit_level2_approval(
    record_id: int,
    payload: DualApprovalLevel2Submit,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.approve")),
):
    return submit_level2_approval_service(db, record_id, payload, user=current_user.username)


@router.post("/{record_id}/cargox/run-checklist", response_model=CargoShippingResponse)
def run_cargox_checklist(
    record_id: int,
    invoice_match_confirmed: bool = Query(False, description="The user confirms the invoice / consignee match (recorded with the user name)"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.update")),
):
    return execute_cargox_checklist_service(
        db, record_id, invoice_match_confirmed=invoice_match_confirmed, user=current_user.username
    )


@router.post("/{record_id}/cargox/advance-stage", response_model=CargoShippingResponse)
def advance_cargox_stage(
    record_id: int,
    target_stage: CargoXTargetStage = Query(...),
    tx_hash: Optional[str] = Query(None, max_length=200, description="Blockchain transaction hash reported by CargoX"),
    envelope_id: Optional[str] = Query(None, max_length=100, description="CargoX envelope id"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.approve")),
):
    return advance_cargox_stage_service(
        db, record_id, target_stage, tx_hash=tx_hash, envelope_id=envelope_id, user=current_user.username
    )


@router.delete("/{record_id}", status_code=status.HTTP_204_NO_CONTENT)
def soft_delete_cargo_shipping(
    record_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.update")),
):
    soft_delete_cargo_shipping_service(db, record_id, user=current_user.username)
    return None


@router.post("/{record_id}/restore", response_model=CargoShippingResponse)
@router.patch("/{record_id}/restore", response_model=CargoShippingResponse)
def restore_cargo_shipping(
    record_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.update")),
):
    return restore_cargo_shipping_service(db, record_id, user=current_user.username)
