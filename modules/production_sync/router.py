"""
Production Sync & System Updates API Router
Endpoints for live database comparison, updates check, and safety backups management.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.production_sync.service import ProductionSyncService
from modules.production_sync.schemas import (
    SyncComparisonResponseSchema,
    SyncActionResponseSchema,
    BackupsListResponseSchema,
    BackupItemSchema,
    RestoreBackupResponseSchema,
    RemoteUpdateCheckResponseSchema,
    SystemVersionInfoSchema,
    RemoteUpdateCheckSchema,
    InstallerInfoSchema,
)
from modules.auth.router import get_current_user, require_admin
from modules.users.model import User

router = APIRouter(
    prefix="/api/v1/production-sync",
    tags=["Production Synchronization & Deployment"],
    dependencies=[Depends(get_current_user)],
)


@router.get(
    "/version-info",
    response_model=SystemVersionInfoSchema,
    summary="استرجاع معلومات الإصدار الحالي وحالة النظام وقاعدة البيانات",
)
def get_system_version_info(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = ProductionSyncService(db)
    return service.get_system_version_info()


@router.get(
    "/check-updates",
    response_model=RemoteUpdateCheckSchema,
    summary="فحص وتدقيق توفر إصدارات جديدة من النظام سحابياً",
)
def check_for_system_updates(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Local version info only; no outbound request (updates come from /api/v1/app-update).
    service = ProductionSyncService(db)
    return service.check_for_updates()


@router.get(
    "/compare",
    response_model=SyncComparisonResponseSchema,
    summary="فحص ومقارنة قاعدة بيانات التطوير مع الإنتاج",
)
def compare_databases(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    service = ProductionSyncService(db)
    return service.get_comparison()


@router.post(
    "/sync-to-prod",
    response_model=SyncActionResponseSchema,
    status_code=status.HTTP_200_OK,
    summary="مزامنة قاعدة البيانات الحالية إلى الإنتاج (Dev -> Prod)",
)
def sync_dev_to_prod(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    service = ProductionSyncService(db)
    return service.sync_dev_to_prod()


@router.post(
    "/pull-to-dev",
    response_model=SyncActionResponseSchema,
    status_code=status.HTTP_200_OK,
    summary="سحب قاعدة بيانات الإنتاج إلى بيئة التطوير (Prod -> Dev)",
)
def pull_prod_to_dev(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    service = ProductionSyncService(db)
    return service.pull_prod_to_dev()


@router.post(
    "/backup",
    response_model=BackupItemSchema,
    status_code=status.HTTP_201_CREATED,
    summary="إنشاء نسخة احتياطية فورية من قاعدة البيانات",
)
def create_manual_backup(
    target: str = "dev",
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    service = ProductionSyncService(db)
    return service.create_manual_backup(target=target)


@router.get(
    "/backups",
    response_model=BackupsListResponseSchema,
    summary="استعراض قائمة النسخ الاحتياطية السابقة",
)
def list_backups(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    service = ProductionSyncService(db)
    return service.list_backups()


@router.post(
    "/restore",
    response_model=RestoreBackupResponseSchema,
    status_code=status.HTTP_200_OK,
    summary="استعادة نسخة احتياطية محددة إلى قاعدة بيانات الإنتاج أو التطوير",
)
def restore_backup(
    filename: str,
    target: str = "prod",
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    # Blocked (403) in the production build; only a bare file name inside the backups folder.
    service = ProductionSyncService(db)
    try:
        return service.restore_backup(filename=filename, target=target)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@router.get(
    "/check-update",
    response_model=RemoteUpdateCheckResponseSchema,
    summary="فحص وجود تحديثات جديدة للنظام من GitHub Releases",
)
def check_remote_update(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = ProductionSyncService(db)
    return service.check_remote_update()


@router.get(
    "/installer-info",
    response_model=InstallerInfoSchema,
    summary="استرجاع رابط وبيانات آخر Installer متاح للتنزيل التلقائي داخل التطبيق",
)
def get_latest_installer_info(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Returns the installer_url, installer_filename, and installer_size_mb
    for the latest production release. Used by the Flutter in-app auto-updater.
    """
    service = ProductionSyncService(db)
    return service.get_latest_installer_info()

