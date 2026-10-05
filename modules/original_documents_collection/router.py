from typing import List, Optional
from urllib.parse import quote

from fastapi import APIRouter, Depends, status, Query
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
import io

from database.database import get_db
from modules.auth.permissions import require_permission
from modules.auth.router import get_current_user
from modules.users.model import User
from .service import OriginalDocumentsCollectionService
from .schemas import (
    OriginalDocumentsCollectionCreate,
    OriginalDocumentsCollectionResponse,
    OriginalDocumentsAutoPopulateResponse,
    CourierReceiptProofRequest,
    CourierAlertsResponse,
    CourierFlatItemResponse,
)

VIEW = "import_documentation.view"
UPLOAD = "import_documentation.upload"

router = APIRouter(
    prefix="/api/v1/original-documents-collection",
    tags=["Physical Original Documents Collection & Courier Tracking (BP-026 / DOC-ORIG-001)"],
    dependencies=[Depends(get_current_user)],
)


@router.get(
    "/auto-populate/{import_file_id}",
    response_model=OriginalDocumentsAutoPopulateResponse,
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(require_permission(VIEW))],
)
def auto_populate_documents(
    import_file_id: int,
    db: Session = Depends(get_db),
):
    """
    Auto-populates the required original documents matrix and couriers from Central Archive & Import File.
    """
    return OriginalDocumentsCollectionService.auto_populate_from_central_archive(db, import_file_id)


@router.post(
    "/sessions",
    response_model=OriginalDocumentsCollectionResponse,
    status_code=status.HTTP_200_OK,
)
def save_or_upsert_session(
    payload: OriginalDocumentsCollectionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(UPLOAD)),
):
    """
    Saves (as Draft or Final) or Upserts an original documents collection & multi-courier session.
    """
    return OriginalDocumentsCollectionService.save_or_upsert_collection_session(
        db, payload, username=current_user.username
    )


@router.get(
    "/sessions/by-file/{import_file_id}",
    response_model=OriginalDocumentsCollectionResponse,
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(require_permission(VIEW))],
)
def get_session_by_file(
    import_file_id: int,
    db: Session = Depends(get_db),
):
    """
    Retrieves the collection session for a specific Import File ID (404 ODC_SESSION_NOT_FOUND when none).
    """
    return OriginalDocumentsCollectionService.get_session_by_file(db, import_file_id)


@router.get(
    "/sessions/{collection_id}",
    response_model=OriginalDocumentsCollectionResponse,
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(require_permission(VIEW))],
)
def get_session_by_id(
    collection_id: int,
    db: Session = Depends(get_db),
):
    """
    Retrieves an active collection session by its Primary Key ID.
    """
    return OriginalDocumentsCollectionService.get_session_by_id(db, collection_id)


@router.get(
    "/sessions",
    response_model=List[OriginalDocumentsCollectionResponse],
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(require_permission(VIEW))],
)
def list_sessions(
    include_inactive: bool = False,
    status: Optional[str] = None,
    search: Optional[str] = None,
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    """
    Lists all original documents collection sessions with status and search filtering.
    """
    return OriginalDocumentsCollectionService.list_sessions(
        db,
        include_inactive=include_inactive,
        status=status,
        search=search,
        limit=limit,
        offset=offset,
    )


@router.get(
    "/export/excel/{import_file_id}",
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(require_permission(VIEW))],
)
def export_excel(
    import_file_id: int,
    db: Session = Depends(get_db),
):
    """
    Generates and downloads the formatted Excel (.xlsx) collection sheet of an import file.
    """
    excel_bytes = OriginalDocumentsCollectionService.export_collection_to_excel_bytes(db, import_file_id)
    filename = OriginalDocumentsCollectionService.export_filename(db, import_file_id)
    return StreamingResponse(
        io.BytesIO(excel_bytes),
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f"attachment; filename*=UTF-8''{quote(filename)}"},
    )


@router.post(
    "/couriers/confirm-receipt",
    response_model=OriginalDocumentsCollectionResponse,
    status_code=status.HTTP_200_OK,
)
def confirm_courier_receipt(
    request: CourierReceiptProofRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(UPLOAD)),
):
    """
    Formally certifies and records the physical delivery date, time, and recipient for a courier package.
    """
    return OriginalDocumentsCollectionService.confirm_courier_receipt(db, request, username=current_user.username)


@router.get(
    "/couriers/alerts",
    response_model=CourierAlertsResponse,
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(require_permission(VIEW))],
)
def get_courier_alerts(
    db: Session = Depends(get_db),
):
    """
    Retrieves all courier delivery alerts, transit days, and SLA breach warnings across all shipments.
    """
    return OriginalDocumentsCollectionService.get_courier_alerts(db)


@router.get(
    "/couriers/all",
    response_model=List[CourierFlatItemResponse],
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(require_permission(VIEW))],
)
def get_all_couriers(
    db: Session = Depends(get_db),
):
    """
    Retrieves all couriers across all shipments for the unified courier tracking and delivery proof registry.
    """
    return OriginalDocumentsCollectionService.get_all_couriers_flat(db)
