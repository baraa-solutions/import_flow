"""
/api/v1/app-update — end-user update routes (plan §6). HTTP only; logic lives in UpdateService.

No route accepts a URL: the update host is a code constant validated against an allow-list.
"""
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.app_update.schemas import (
    ApplyRequest,
    DownloadRequest,
    LastResultResponse,
    RollbackRequest,
    StageLocalRequest,
    UpdateCheckResponse,
    UpdateHistoryResponse,
    UpdateStatusResponse,
)
from modules.app_update.service import UpdateService, get_update_service
from modules.auth.permissions import require_permission
from modules.auth.router import get_current_user
from modules.users.model import User

router = APIRouter(
    prefix="/api/v1/app-update",
    tags=["Application Update"],
    dependencies=[Depends(get_current_user)],
)

require_system_update = require_permission("system.update")


@router.get("/check", response_model=UpdateCheckResponse)
def check_for_update(
    force: bool = Query(False, description="Bypass the 1 h manifest cache"),
    service: UpdateService = Depends(get_update_service),
):
    return service.check(force=force)


@router.get("/status", response_model=UpdateStatusResponse)
def get_update_status(service: UpdateService = Depends(get_update_service)):
    return service.get_status()


@router.post("/download", response_model=UpdateStatusResponse, status_code=status.HTTP_202_ACCEPTED)
def download_update(
    payload: DownloadRequest,
    current_user: User = Depends(require_system_update),
    db: Session = Depends(get_db),
    service: UpdateService = Depends(get_update_service),
):
    return service.start_download(payload.version, actor=current_user.username, db=db)


@router.post("/cancel", response_model=UpdateStatusResponse)
def cancel_update_download(
    current_user: User = Depends(require_system_update),
    service: UpdateService = Depends(get_update_service),
):
    return service.cancel(actor=current_user.username)


@router.post("/apply", status_code=status.HTTP_202_ACCEPTED)
def apply_update(
    payload: ApplyRequest,
    current_user: User = Depends(require_system_update),
    service: UpdateService = Depends(get_update_service),
):
    return service.apply(payload.version, actor=current_user.username)


@router.post("/stage-local", response_model=UpdateStatusResponse)
def stage_local_update(
    payload: StageLocalRequest,
    current_user: User = Depends(require_system_update),
    service: UpdateService = Depends(get_update_service),
):
    return service.stage_local(payload.manifest_path, payload.installer_path, actor=current_user.username)


@router.post("/rollback", status_code=status.HTTP_202_ACCEPTED)
def rollback_update(
    payload: RollbackRequest,
    current_user: User = Depends(require_system_update),
    service: UpdateService = Depends(get_update_service),
):
    return service.rollback(payload.backup_file, actor=current_user.username)


@router.get("/last-result", response_model=LastResultResponse)
def get_last_update_result(service: UpdateService = Depends(get_update_service)):
    return service.get_last_result()


@router.get("/history", response_model=UpdateHistoryResponse)
def get_update_history(
    limit: int = Query(50, ge=1, le=200),
    current_user: User = Depends(require_system_update),
    service: UpdateService = Depends(get_update_service),
):
    return service.get_history(limit)
