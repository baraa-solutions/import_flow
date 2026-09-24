"""
Production Sync Validators
"""
from pathlib import Path

from fastapi import HTTPException, status

from utils.db_safety import is_frozen_build

PRODUCTION_BUILD_BLOCKED_DETAIL = "غير متاح في نسخة الإنتاج"
ALLOWED_RESTORE_TARGETS = ("prod", "dev")


def validate_db_exists(db_path: Path, db_label: str = "Database") -> None:
    if not db_path.exists():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ملف قاعدة البيانات ({db_label}) غير موجود في المسار: {db_path}",
        )


def validate_sync_action(action: str) -> None:
    allowed = ["PUSH_TO_PROD", "PULL_TO_DEV", "BACKUP_DEV", "BACKUP_PROD"]
    if action not in allowed:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"نوع عملية المزامنة غير مدعوم: {action}. العمليات المتاحة: {', '.join(allowed)}",
        )


def validate_not_production_build() -> None:
    """R7: sync-to-prod, pull-to-dev and restore overwrite the live DB; never allowed in the frozen build."""
    if is_frozen_build():
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=PRODUCTION_BUILD_BLOCKED_DETAIL)


def validate_restore_target(target: str) -> None:
    if target not in ALLOWED_RESTORE_TARGETS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="الوجهة غير صالحة. القيم المسموح بها: prod أو dev.",
        )


def resolve_backup_file(backups_dir: Path, filename: str) -> Path:
    """Return the backup file for a bare file name inside ``backups_dir``.

    Absolute paths, drive letters, separators and '..' are rejected (400). A valid name that does
    not exist raises FileNotFoundError.
    """
    raw = (filename or "").strip()
    if (
        not raw
        or raw in (".", "..")
        or "/" in raw
        or "\\" in raw
        or ":" in raw
        or ".." in raw
        or Path(raw).is_absolute()
        or Path(raw).name != raw
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="اسم ملف النسخة الاحتياطية غير صالح: يجب اختيار ملف من مجلد النسخ الاحتياطية بالاسم فقط.",
        )
    if not raw.lower().endswith(".db"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="ملف النسخة الاحتياطية يجب أن يكون بامتداد .db",
        )
    base = backups_dir.resolve()
    candidate = (base / raw).resolve()
    if candidate.parent != base:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="ملف النسخة الاحتياطية يجب أن يكون داخل مجلد النسخ الاحتياطية.",
        )
    if not candidate.is_file():
        raise FileNotFoundError(f"الملف الاحتياطي '{raw}' غير موجود في مجلد النسخ الاحتياطية.")
    return candidate
