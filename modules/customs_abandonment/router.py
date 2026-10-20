from typing import List, Optional
from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.router import get_current_user
from modules.auth.permissions import require_permission
from modules.users.model import User

from .schemas import (
    CustomsAbandonmentRadarCreate,
    CustomsAbandonmentRadarUpdate,
    CustomsAbandonmentRadarResponse,
    ExtensionRequestCreate,
    ExtensionGrantCreate,
    ExtensionLetterDraftResponse,
    CustomsAbandonmentSummaryResponse,
    RecalculateResponse,
)
from .service import (
    create_radar_service,
    list_radars_service,
    get_radar_by_id_service,
    update_radar_service,
    delete_radar_service,
    recalculate_open_files_service,
    request_extension_service,
    grant_extension_service,
    generate_extension_letter_draft,
    resolve_radar_service,
    get_customs_abandonment_summary_service,
)

router = APIRouter(
    prefix="/api/v1/customs-abandonment",
    tags=["Customs Abandonment Radar (Law 207/2020 Art. 67)"],
    dependencies=[Depends(get_current_user)],
)

can_view = require_permission("customs_clearance.view")
can_update = require_permission("customs_clearance.update")
can_release = require_permission("customs_clearance.release")


@router.get(
    "/radars",
    response_model=List[CustomsAbandonmentRadarResponse],
    summary="List customs abandonment radar items with filtering and pagination",
)
def list_radars_endpoint(
    response: Response,
    risk_level: Optional[str] = Query(None, description="Filter by risk level (NORMAL, WARNING_15_DAYS, CRITICAL_7_DAYS, UNDER_ABANDONMENT_INVENTORY)"),
    abandonment_status: Optional[str] = Query(None, description="Filter by status (ACTIVE_CLEARING, EXTENSION_PENDING, MOVED_TO_ABANDONED_WAREHOUSE, AUCTION_SCHEDULED, RESOLVED_RELEASED)"),
    port_type: Optional[str] = Query(None, description="Filter by port type (SEAPORT, DRY_PORT, AIRPORT)"),
    search: Optional[str] = Query(None, description="Search by file code, BL, declaration, or importer"),
    is_active: bool = Query(True, description="Filter active records"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    radars, total = list_radars_service(
        db,
        risk_level=risk_level,
        abandonment_status=abandonment_status,
        port_type=port_type,
        search=search,
        is_active=is_active,
        skip=skip,
        limit=limit,
    )
    response.headers["X-Total-Count"] = str(total)
    return radars


@router.get(
    "/radars/summary",
    response_model=CustomsAbandonmentSummaryResponse,
    summary="Get aggregated statistics of abandonment radar risks and statutory statuses",
)
def get_summary_endpoint(
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    return get_customs_abandonment_summary_service(db)


@router.post(
    "/radars",
    response_model=CustomsAbandonmentRadarResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a customs abandonment radar record",
)
def create_radar_endpoint(
    req: CustomsAbandonmentRadarCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_update),
):
    return create_radar_service(db, req, user=current_user.username)


@router.post(
    "/recalculate",
    response_model=RecalculateResponse,
    summary="Recalculate abandonment countdown and risk levels across open files and active radars",
)
def recalculate_radars_endpoint(
    db: Session = Depends(get_db),
    current_user: User = Depends(can_update),
):
    return recalculate_open_files_service(db)


@router.get(
    "/radars/{radar_id}",
    response_model=CustomsAbandonmentRadarResponse,
    summary="Get single customs abandonment radar record",
)
def get_radar_endpoint(
    radar_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    return get_radar_by_id_service(db, radar_id)


@router.put(
    "/radars/{radar_id}",
    response_model=CustomsAbandonmentRadarResponse,
    summary="Update customs abandonment radar record",
)
def update_radar_endpoint(
    radar_id: int,
    req: CustomsAbandonmentRadarUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_update),
):
    return update_radar_service(db, radar_id, req, user=current_user.username)


@router.delete(
    "/radars/{radar_id}",
    status_code=status.HTTP_200_OK,
    summary="Delete customs abandonment radar record (Soft delete)",
)
def delete_radar_endpoint(
    radar_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_update),
):
    delete_radar_service(db, radar_id, user=current_user.username)
    return {"message": "Customs abandonment radar record deleted successfully."}


@router.post(
    "/radars/{radar_id}/request-extension",
    response_model=CustomsAbandonmentRadarResponse,
    summary="Submit extension request to delay transfer to customs abandonment inventory",
)
def request_extension_endpoint(
    radar_id: int,
    req: ExtensionRequestCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_update),
):
    return request_extension_service(db, radar_id, req, user=current_user.username)


@router.post(
    "/radars/{radar_id}/grant-extension",
    response_model=CustomsAbandonmentRadarResponse,
    summary="Record approved extension granted by Egyptian Customs Authority",
)
def grant_extension_endpoint(
    radar_id: int,
    req: ExtensionGrantCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_release),
):
    return grant_extension_service(db, radar_id, req, user=current_user.username)


@router.get(
    "/radars/{radar_id}/extension-letter-draft",
    response_model=ExtensionLetterDraftResponse,
    summary="Generate official extension request letter draft to Customs Director (Art. 67 Law 207/2020)",
)
def generate_extension_letter_endpoint(
    radar_id: int,
    requested_days: int = Query(30, ge=1, le=90, description="Additional days requested"),
    reason: Optional[str] = Query(None, description="Custom operational reason to include in the petition"),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    return generate_extension_letter_draft(db, radar_id, requested_days=requested_days, reason=reason)


@router.post(
    "/radars/{radar_id}/resolve",
    response_model=CustomsAbandonmentRadarResponse,
    summary="Mark customs abandonment radar as resolved (customs released)",
)
def resolve_radar_endpoint(
    radar_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_release),
):
    return resolve_radar_service(db, radar_id, user=current_user.username)
