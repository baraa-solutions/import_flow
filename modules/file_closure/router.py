from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from modules.auth.router import get_current_user
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.permissions import require_permission
from modules.users.model import User
from .schemas import (
    FileClosureCreate,
    FileClosureUpdate,
    FileClosureResponse,
    ComprehensiveShipmentDossierResponse,
    DossierExportConfirmRequest,
    DossierExportConfirmResponse,
    ClosurePrecheckResponse,
    OfficialClosureCertificateResponse,
)
from .service import (
    close_import_file_service,
    get_closure_service,
    list_closures_service,
    update_closure_service,
    soft_delete_closure_service,
    restore_closure_service,
    get_comprehensive_shipment_dossier_service,
    confirm_dossier_export_service,
    get_closure_precheck_service,
    official_close_import_file_service,
)

VIEW = "import_files.view"
EDIT = "import_files.edit"
CLOSE = "import_files.close"

router = APIRouter(prefix="/api/v1/file-closure", tags=["Phase 10 - Import File Closure & Historical Archival"], dependencies=[Depends(get_current_user)])

@router.get("", response_model=List[FileClosureResponse])
def list_closures(
    include_inactive: bool = Query(False, description="Include soft-deleted records"),
    import_file_id: Optional[int] = Query(None, description="Filter by import file ID"),
    search: Optional[str] = Query(None, description="Search term"),
    db: Session = Depends(get_db),
    _user: User = Depends(require_permission(VIEW)),
):
    return list_closures_service(db, include_inactive, import_file_id, search)

@router.post("", response_model=FileClosureResponse, status_code=status.HTTP_201_CREATED)
def close_import_file(
    schema: FileClosureCreate,
    db: Session = Depends(get_db),
    # The write permission depends on the payload: the service requires import_files.edit (or .close) for a
    # draft and import_files.close for a final close (403 otherwise).
    current_user: User = Depends(require_permission(VIEW)),
):
    return close_import_file_service(db, schema, user=current_user.username, actor=current_user)

@router.get("/{closure_id}", response_model=FileClosureResponse)
def get_closure(
    closure_id: int,
    db: Session = Depends(get_db),
    _user: User = Depends(require_permission(VIEW)),
):
    return get_closure_service(db, closure_id)

@router.put("/{closure_id}", response_model=FileClosureResponse)
def update_closure(
    closure_id: int,
    schema: FileClosureUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(EDIT)),
):
    return update_closure_service(db, closure_id, schema, user=current_user.username)

@router.delete("/{closure_id}", status_code=status.HTTP_204_NO_CONTENT)
def soft_delete_closure(
    closure_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(CLOSE)),
):
    soft_delete_closure_service(db, closure_id, user=current_user.username)
    return None

@router.patch("/{closure_id}/restore", response_model=FileClosureResponse)
def restore_closure(
    closure_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(CLOSE)),
):
    return restore_closure_service(db, closure_id, user=current_user.username)


# ==============================================================================
# CLO-03: Comprehensive Shipment Dossier Export Endpoints
# ==============================================================================

@router.get("/comprehensive-dossier/{import_file_id}", response_model=ComprehensiveShipmentDossierResponse)
def get_comprehensive_shipment_dossier(
    import_file_id: int,
    db: Session = Depends(get_db),
    _user: User = Depends(require_permission(VIEW)),
):
    """
    CLO-03: Retrieve aggregated comprehensive shipment dossier across all 10 phases.
    """
    return get_comprehensive_shipment_dossier_service(db, import_file_id)


@router.post("/confirm-dossier-export", response_model=DossierExportConfirmResponse)
def confirm_dossier_export(
    payload: DossierExportConfirmRequest,
    db: Session = Depends(get_db),
    # The service requires import_files.edit OR import_files.close (GENERAL_MANAGER exports and closes).
    current_user: User = Depends(require_permission(VIEW)),
):
    """
    CLO-03: Confirm the export of the comprehensive shipment dossier, advance progress to >=99.5%,
    close TSK-0903, dispatch TSK-0904, and post system notification.
    """
    return confirm_dossier_export_service(db, payload, user=current_user.username, actor=current_user)


# ==============================================================================
# CLO-04: Official File Closure & Digital Archive Endpoints
# ==============================================================================

@router.get("/closure-precheck/{import_file_id}", response_model=ClosurePrecheckResponse)
def get_closure_precheck(
    import_file_id: int,
    db: Session = Depends(get_db),
    _user: User = Depends(require_permission(VIEW)),
):
    """
    CLO-04: Perform pre-closure audit checks across all 6 core pillars.
    """
    return get_closure_precheck_service(db, import_file_id)


@router.post("/official-close", response_model=OfficialClosureCertificateResponse, status_code=status.HTTP_201_CREATED)
def official_close_import_file(
    schema: FileClosureCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(CLOSE)),
):
    """
    CLO-04: Issue official closure certificate, lock file to 100% closed, advance lifecycle board to STEP_21.
    """
    return official_close_import_file_service(db, schema, user=current_user.username, actor=current_user)


