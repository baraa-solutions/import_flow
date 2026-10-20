from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.permissions import require_permission
from modules.auth.router import get_current_user
from modules.custody_release.schemas import (
    CustodyBreachReportSubmit,
    CustodyFinalClearanceSubmit,
    CustodyReleaseDossierCreate,
    CustodyReleaseDossierListResponse,
    CustodyReleaseDossierResponse,
    CustodyReleaseDossierUpdate,
    CustodyWarehouseFreezeSubmit,
    WarehouseDispenseValidationResult,
)
from modules.custody_release.service import CustodyReleaseService
from modules.users.model import User

VIEW = "customs_clearance.view"
UPDATE = "customs_clearance.update"
RELEASE = "customs_clearance.release"

router = APIRouter(
    prefix="/api/v1/custody-release",
    tags=["Warehouse Custody & Under-Bond Release"],
    dependencies=[Depends(get_current_user)],
)


@router.get(
    "",
    response_model=CustodyReleaseDossierListResponse,
    summary="List all custody release dossiers with filtering and pagination",
)
def list_dossiers(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    import_file_id: Optional[int] = Query(None, description="Filter by Import File ID"),
    warehouse_id: Optional[int] = Query(None, description="Filter by Warehouse ID"),
    status: Optional[str] = Query(None, description="Filter by status (RELEASED_UNDER_CUSTODY, FROZEN_IN_WAREHOUSE, SAMPLE_CLEAR_FINAL_RELEASE, BREACH_REPORTED)"),
    lock_active: Optional[bool] = Query(None, description="Filter by lock state (True/False)"),
    include_inactive: bool = Query(False, description="Include soft-deleted records"),
    db: Session = Depends(get_db),
    _user: User = Depends(require_permission(VIEW)),
):
    items, total = CustodyReleaseService(db).list_dossiers(
        skip=skip,
        limit=limit,
        import_file_id=import_file_id,
        warehouse_id=warehouse_id,
        status_filter=status,
        lock_active=lock_active,
        include_inactive=include_inactive,
    )
    return CustodyReleaseDossierListResponse(total=total, items=items)


@router.post(
    "",
    response_model=CustodyReleaseDossierResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new custody release dossier (Under-Bond / Undertaking)",
)
def create_dossier(
    payload: CustodyReleaseDossierCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(UPDATE)),
):
    return CustodyReleaseService(db).create_dossier(
        payload=payload,
        current_user=current_user.username,
    )


@router.get(
    "/validate-dispense/{import_file_id}",
    response_model=WarehouseDispenseValidationResult,
    summary="Verify whether warehouse goods can be dispensed or are locked under custody",
)
def validate_warehouse_dispense(
    import_file_id: int,
    db: Session = Depends(get_db),
    _user: User = Depends(require_permission(VIEW)),
):
    return CustodyReleaseService(db).validate_warehouse_dispense(import_file_id)


@router.get(
    "/{custody_id}",
    response_model=CustodyReleaseDossierResponse,
    summary="Get custody release dossier by ID",
)
def get_dossier(
    custody_id: int,
    db: Session = Depends(get_db),
    _user: User = Depends(require_permission(VIEW)),
):
    return CustodyReleaseService(db).get_dossier(custody_id)


@router.put(
    "/{custody_id}",
    response_model=CustodyReleaseDossierResponse,
    summary="Update custody release dossier details",
)
def update_dossier(
    custody_id: int,
    payload: CustodyReleaseDossierUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(UPDATE)),
):
    return CustodyReleaseService(db).update_dossier(
        custody_id=custody_id,
        payload=payload,
        current_user=current_user.username,
    )


@router.post(
    "/{custody_id}/freeze",
    response_model=CustodyReleaseDossierResponse,
    summary="Confirm warehouse arrival and freeze goods in storage",
)
def freeze_in_warehouse(
    custody_id: int,
    payload: CustodyWarehouseFreezeSubmit,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(UPDATE)),
):
    return CustodyReleaseService(db).freeze_in_warehouse(
        custody_id=custody_id,
        payload=payload,
        current_user=current_user.username,
    )


@router.post(
    "/{custody_id}/final-clearance",
    response_model=CustodyReleaseDossierResponse,
    summary="Approve final laboratory conformity and lift warehouse custody lock",
)
def approve_final_clearance(
    custody_id: int,
    payload: CustodyFinalClearanceSubmit,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(RELEASE)),
):
    return CustodyReleaseService(db).approve_final_clearance(
        custody_id=custody_id,
        payload=payload,
        current_user=current_user.username,
    )


@router.post(
    "/{custody_id}/report-breach",
    response_model=CustodyReleaseDossierResponse,
    summary="Report breach of customs seals or unauthorized movement",
)
def report_breach(
    custody_id: int,
    payload: CustodyBreachReportSubmit,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(UPDATE)),
):
    return CustodyReleaseService(db).report_breach(
        custody_id=custody_id,
        payload=payload,
        current_user=current_user.username,
    )


@router.delete(
    "/{custody_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft-delete a custody release dossier",
)
def delete_dossier(
    custody_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(UPDATE)),
):
    CustodyReleaseService(db).soft_delete(custody_id=custody_id, current_user=current_user.username)
    return None


@router.post(
    "/{custody_id}/restore",
    response_model=CustodyReleaseDossierResponse,
    summary="Restore a soft-deleted custody release dossier",
)
def restore_dossier(
    custody_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(UPDATE)),
):
    return CustodyReleaseService(db).restore(custody_id=custody_id, current_user=current_user.username)
