"""
Domain rules for the application updater (plan §4.2, §4.8, §4.9; spec update-system-phase2-5 §B).

Pure functions: version parsing, update host allow-list, relative installer path rules, dev-mode guard,
pre-update backup naming, local-file rules, the installer command line and the post-update classification.
"""
import logging
import os
import re
from datetime import datetime
from pathlib import Path
from typing import Any, Mapping, Optional, Tuple
from urllib.parse import urlsplit

from fastapi import HTTPException, status

from utils.db_safety import (
    PRE_RESTORE_PREFIX,
    PRE_UPDATE_PREFIX,
    app_base_dir,
    is_frozen_build,
    unique_backup_name,
)

logger = logging.getLogger(__name__)

# ─── Constants ────────────────────────────────────────────────────────────────

DEFAULT_UPDATE_BASE_URL = "https://kamal-sroor.online/importflow/updates/"
ALLOWED_UPDATE_HOSTS = frozenset({"kamal-sroor.online"})
MANIFEST_FILENAME = "manifest.json"
MANIFEST_MAX_BYTES = 64 * 1024
HTTP_TIMEOUT_SECONDS = 10.0
MANIFEST_SCHEMA = 1
MANIFEST_APP = "sorour-logistics"
INSTALLER_PATH_PREFIX = "releases/"

VERSION_RE = re.compile(r"\d+\.\d+\.\d+\Z")
SHA256_RE = re.compile(r"[0-9a-f]{64}\Z")
INSTALLER_FILENAME_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*\.exe\Z")
_PATH_SEGMENT_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*\Z")

# User-facing error details (plan §6)
DETAIL_DEV_MODE = "التحديث التلقائي غير متاح في وضع التطوير"
DETAIL_NO_UPDATE_FOR_VERSION = "لا يوجد تحديث متاح لهذا الإصدار"
DETAIL_DOWNLOAD_IN_PROGRESS = "جاري تنزيل التحديث بالفعل"
DETAIL_SERVER_UNREACHABLE = "تعذّر الاتصال بخادم التحديثات"
DETAIL_NO_DOWNLOAD_RUNNING = "لا توجد عملية تنزيل جارية"
DETAIL_HASH_MISMATCH = "الملف الذي تم تنزيله غير مطابق للبصمة الرقمية وتم حذفه"
DETAIL_SIZE_EXCEEDED = "حجم الملف الذي تم تنزيله أكبر من المتوقع وتم حذفه"
DETAIL_DOWNLOAD_FAILED = "فشل تنزيل التحديث"

# apply (spec B.3)
DETAIL_UPDATE_BUSY = "توجد عملية تحديث جارية حالياً"
DETAIL_NOT_READY = "التحديث غير جاهز للتثبيت"
DETAIL_BACKUP_FAILED = "فشل النسخ الاحتياطي، تم إلغاء التحديث"
DETAIL_LAUNCH_FAILED = "تعذّر تشغيل برنامج التثبيت، تم إلغاء التحديث ولم يتغير أي شيء"

# rollback (spec B.5)
DETAIL_ROLLBACK_CONFIRM_REQUIRED = "يجب تأكيد التراجع أولاً"
DETAIL_NO_ROLLBACK_AVAILABLE = "لا توجد نسخة سابقة متاحة للتراجع"
DETAIL_ALREADY_ON_PREVIOUS = "البرنامج ما زال على الإصدار السابق، لا حاجة للتراجع"
DETAIL_BACKUP_NOT_OF_LAST_UPDATE = "النسخة الاحتياطية المطلوبة لا تخص آخر تحديث"
DETAIL_BACKUP_CORRUPT = "النسخة الاحتياطية تالفة"
DETAIL_PREVIOUS_INSTALLER_MISSING = "ملف تثبيت الإصدار السابق غير متوفر على الجهاز. استخدم خطة التراجع اليدوية"
DETAIL_ASIDE_FAILED = "تعذّر حفظ نسخة من قاعدة البيانات الحالية، تم إلغاء التراجع"
DETAIL_RESTORE_FAILED = "فشل استرجاع قاعدة البيانات. النظام في وضع القراءة فقط، تواصل مع الدعم الفني"
DETAIL_ROLLBACK_LAUNCH_FAILED = "تم استرجاع قاعدة البيانات لكن تعذّر تشغيل برنامج التثبيت السابق. شغّله يدوياً من: {path}"
DETAIL_ROLLBACK_INSTALLER_TAMPERED = (
    "تم استرجاع قاعدة البيانات لكن ملف تثبيت الإصدار السابق غير مطابق للبصمة الرقمية وتم حذفه. "
    "استخدم خطة التراجع اليدوية"
)

# stage-local (spec B.7)
DETAIL_FILE_NOT_FOUND = "الملف غير موجود أو لا يمكن استخدامه من هذا المسار"
DETAIL_UNSUPPORTED_FILE_TYPE = "نوع الملف غير مدعوم"
DETAIL_FILE_TOO_LARGE = "حجم الملف أكبر من المسموح"
DETAIL_INVALID_SIGNATURE = "توقيع ملف الإصدار غير صالح"
DETAIL_NOT_NEWER = "الإصدار ليس أحدث من المثبت"
DETAIL_LOCAL_HASH_MISMATCH = "بصمة ملف التثبيت غير مطابقة"
DETAIL_LOCAL_COPY_FAILED = "تعذّر نسخ ملف التثبيت"

# post-update health check (spec B.4)
DETAIL_POST_INSTALLER_NOT_COMPLETED = (
    "لم يكتمل تثبيت الإصدار {to}، والبرنامج ما زال على الإصدار {from_}. بياناتك لم تتغير. سجل التثبيت: {install_log}"
)
DETAIL_POST_UNEXPECTED_VERSION = "الإصدار المثبت {installed} غير المتوقع ({to})."
DETAIL_POST_MIGRATION_FAILED = (
    "تم تثبيت الإصدار {to} لكن ترقية قاعدة البيانات فشلت والنظام في وضع القراءة فقط. يمكنك التراجع للإصدار السابق."
)
DETAIL_POST_DB_CHECK_FAILED = "فحص سلامة قاعدة البيانات بعد التحديث فشل. يمكنك التراجع للإصدار السابق."
DETAIL_CLIENT_VERSION_MISMATCH = "واجهة البرنامج لم تتحدث (الإصدار {client}) بينما الخادم على الإصدار {to}."

# Local (USB) files: caps are read at call time so tests can patch them.
LOCAL_MANIFEST_MAX_BYTES = MANIFEST_MAX_BYTES
LOCAL_INSTALLER_MAX_BYTES = 1024 * 1024 * 1024

# Installers kept under updates/installers/ for rollback; only these names are ever pruned.
INSTALLER_FILE_RE = re.compile(r"Sorour_Logistics_Setup_v(\d+)\.(\d+)\.(\d+)\.exe\Z")
PRE_UPDATE_BACKUP_RE = re.compile(
    rf"{PRE_UPDATE_PREFIX}v\d+\.\d+\.\d+_to_v\d+\.\d+\.\d+_\d{{8}}_\d{{6}}(?:_\d+)?\.db\Z"
)
BACKUP_TIMESTAMP_FORMAT = "%Y%m%d_%H%M%S"


class ManifestError(ValueError):
    """The manifest is unsigned, tampered, malformed, or violates a client rule."""


# ─── Versions ─────────────────────────────────────────────────────────────────

def is_valid_version(value: object) -> bool:
    return isinstance(value, str) and bool(VERSION_RE.fullmatch(value))


def parse_version(value: str) -> Tuple[int, int, int]:
    """Strict semver 'X.Y.Z' -> tuple. Raises ValueError on anything else."""
    if not is_valid_version(value):
        raise ValueError(f"invalid version: {value!r}")
    major, minor, patch = (int(p) for p in value.split("."))
    return major, minor, patch


def is_newer(candidate: str, installed: str) -> bool:
    return parse_version(candidate) > parse_version(installed)


# ─── Base URL / host allow-list ───────────────────────────────────────────────

def validate_base_url(url: str) -> str:
    """https only, host in the allow-list, no credentials/query/fragment. Returns the URL with a trailing '/'."""
    parts = urlsplit(url or "")
    if parts.scheme != "https":
        raise ValueError("update base URL must use https")
    if (parts.hostname or "").lower() not in ALLOWED_UPDATE_HOSTS:
        raise ValueError("update host is not in the allow-list")
    if parts.username or parts.password or parts.query or parts.fragment:
        raise ValueError("update base URL must not carry credentials, query or fragment")
    if parts.port not in (None, 443):
        raise ValueError("update base URL must use the default https port")
    return url if url.endswith("/") else url + "/"


def resolve_base_url(override: Optional[str]) -> Optional[str]:
    """
    Code constant by default. An env override (UPDATE_BASE_URL) is honoured only when it passes the
    allow-list; an invalid override disables the updater (returns None) instead of silently falling back.
    """
    if not override:
        return DEFAULT_UPDATE_BASE_URL
    try:
        return validate_base_url(override.strip())
    except ValueError as exc:
        logger.warning("UPDATE_BASE_URL override rejected: %s", exc)
        return None


# ─── Installer path rules ─────────────────────────────────────────────────────

def validate_installer_path(path: object) -> str:
    """
    installer.path must be relative, under releases/, forward slashes only, no '..', no scheme,
    no leading slash, no drive letter, and end with a plain '.exe' file name.
    """
    if not isinstance(path, str) or not path:
        raise ManifestError("installer path missing")
    if "://" in path or "\\" in path or ":" in path or path.startswith("/"):
        raise ManifestError("installer path must be relative")
    if not path.startswith(INSTALLER_PATH_PREFIX):
        raise ManifestError("installer path must be under releases/")
    segments = path.split("/")
    if any(seg in ("", ".", "..") for seg in segments):
        raise ManifestError("installer path must not contain empty, '.' or '..' segments")
    if not all(_PATH_SEGMENT_RE.fullmatch(seg) for seg in segments):
        raise ManifestError("installer path contains forbidden characters")
    if not INSTALLER_FILENAME_RE.fullmatch(segments[-1]):
        raise ManifestError("installer path must end with an .exe file name")
    return path


def installer_filename(path: str) -> str:
    return validate_installer_path(path).rsplit("/", 1)[-1]


def build_installer_url(base_url: str, path: str) -> str:
    return validate_base_url(base_url) + validate_installer_path(path)


def validate_sha256(value: object) -> str:
    if not isinstance(value, str) or not SHA256_RE.fullmatch(value.lower()):
        raise ManifestError("sha256 must be 64 hex characters")
    return value.lower()


def validate_size(value: object) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        raise ManifestError("size_bytes must be a positive integer")
    return value


# ─── Dev-mode guard (plan §4.8) ───────────────────────────────────────────────

def is_apply_supported() -> bool:
    """Only a frozen, Inno-installed backend (unins000.exe next to backend.exe) may download/apply updates."""
    if not is_frozen_build():
        return False
    return (app_base_dir() / "unins000.exe").is_file()


def ensure_apply_supported(apply_supported: bool) -> None:
    if not apply_supported:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=DETAIL_DEV_MODE)


# ─── Environment helpers ──────────────────────────────────────────────────────

def env_value(name: str) -> Optional[str]:
    value = os.environ.get(name)
    return value.strip() if value and value.strip() else None


# ─── Pre-update / pre-restore backup names (spec B.3 step 5, B.5 steps 6 and 10) ─

def pre_update_backup_name(
    from_version: str, to_version: str, now: datetime, backups_dir: Optional[Path] = None
) -> str:
    """pre_update_v{from}_to_v{to}_{%Y%m%d_%H%M%S}.db (+ _N on collision). Protected by the pre_update_ prefix (R9)."""
    parse_version(from_version)
    parse_version(to_version)
    stem = f"{PRE_UPDATE_PREFIX}v{from_version}_to_v{to_version}_{now.strftime(BACKUP_TIMESTAMP_FORMAT)}"
    return unique_backup_name(stem, backups_dir)


def pre_restore_aside_name(installed_version: str, now: datetime, backups_dir: Optional[Path] = None) -> str:
    """pre_restore_failed_v{installed}_{ts}.db (+ _N): the live DB copied aside before a rollback restore."""
    parse_version(installed_version)
    stem = f"{PRE_RESTORE_PREFIX}failed_v{installed_version}_{now.strftime(BACKUP_TIMESTAMP_FORMAT)}"
    return unique_backup_name(stem, backups_dir)


def validate_backup_filename(backup_file: str, expected: Optional[str]) -> str:
    """
    The rollback source must be a bare pre_update_* file name (no separators, no traversal) and must be the
    backup recorded for the last update. Anything else -> 409.
    """
    ok = (
        isinstance(backup_file, str)
        and "/" not in backup_file
        and "\\" not in backup_file
        and bool(PRE_UPDATE_BACKUP_RE.fullmatch(backup_file))
        and backup_file == expected
    )
    if not ok:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=DETAIL_BACKUP_NOT_OF_LAST_UPDATE)
    return backup_file


# ─── Local (USB) files for stage-local (spec B.7) ─────────────────────────────

DRIVE_REMOVABLE = 2
DRIVE_FIXED = 3
ALLOWED_DRIVE_TYPES = frozenset({DRIVE_REMOVABLE, DRIVE_FIXED})
_LOCAL_DRIVE_PATH_RE = re.compile(r"[A-Za-z]:[\\/][^:]*\Z")


def get_drive_type(root: str) -> int:
    """GetDriveTypeW for 'X:\\' (0 = unknown when it cannot be asked, e.g. not on Windows). Tests patch this."""
    try:
        import ctypes

        return int(ctypes.windll.kernel32.GetDriveTypeW(root))  # type: ignore[attr-defined]
    except (AttributeError, OSError):
        return 0


def _is_local_drive_path(path: str) -> bool:
    """`X:\\...` on a fixed or removable drive; no UNC (\\\\server, \\\\?\\, \\\\.\\), no ':' after the drive (ADS)."""
    if not isinstance(path, str) or "\x00" in path or not _LOCAL_DRIVE_PATH_RE.fullmatch(path):
        return False
    return get_drive_type(path[0].upper() + ":\\") in ALLOWED_DRIVE_TYPES


def validate_local_file(path: str, suffix: str, max_bytes: int) -> Path:
    """
    Existing regular file (not a directory or symlink) on a local fixed/removable drive, with the right suffix and
    size. Network shares, device paths and alternate data streams are refused with the same generic 400 as a missing
    file, so the response does not reveal which rule failed. The resolved path must pass the drive rules too
    (a junction pointing at a share is refused).
    """
    candidate = Path(path or "")
    # checked first, on the string only: a wrong type never touches the file system
    if path and candidate.suffix.lower() != suffix.lower():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=DETAIL_UNSUPPORTED_FILE_TYPE)
    try:
        ok = (
            bool(path)
            and _is_local_drive_path(path)
            and candidate.is_absolute()
            and not candidate.is_symlink()
            and candidate.is_file()
            and _is_local_drive_path(str(candidate.resolve(strict=True)))
        )
    except (OSError, ValueError, RuntimeError):
        ok = False
    if not ok:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=DETAIL_FILE_NOT_FOUND)
    if candidate.stat().st_size > max_bytes:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=DETAIL_FILE_TOO_LARGE)
    return candidate


# ─── Installer command line (spec B.3 step 9) ─────────────────────────────────

def build_installer_command(installer: Path, app_dir: Path, log_path: Path) -> str:
    """
    "<installer>" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /RELAUNCH=1 /DIR="<app_dir>" /LOG="<log_path>"

    One string, every path quoted (the install path contains a space). /DIR pins the install to the folder the
    running backend and its DB live in. A path containing a double quote could break out of the quoting: refused.
    """
    parts = [str(installer), str(app_dir), str(log_path)]
    if any('"' in p for p in parts):
        raise ValueError("installer command paths must not contain a double quote")
    return (
        f'"{parts[0]}" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /RELAUNCH=1 '
        f'/DIR="{parts[1]}" /LOG="{parts[2]}"'
    )


def installer_sort_key(filename: str) -> Optional[Tuple[int, int, int]]:
    """Version tuple of a kept installer name, None for anything that is not ours (never pruned)."""
    match = INSTALLER_FILE_RE.fullmatch(filename)
    return tuple(int(g) for g in match.groups()) if match else None  # type: ignore[return-value]


# ─── Post-update health check (spec B.4) ──────────────────────────────────────

def classify_post_update(
    marker: Mapping[str, Any],
    installed_version: Optional[str],
    maintenance: bool,
    maintenance_reason: str,
    quick: str,
) -> Tuple[str, Optional[str], Optional[str]]:
    """(result, code, detail) for a pending update/rollback marker. First matching row wins."""
    from_version = marker.get("from_version")
    to_version = marker.get("to_version")
    if installed_version == from_version:
        return "failed", "installer_not_completed", DETAIL_POST_INSTALLER_NOT_COMPLETED.format(
            to=to_version, from_=from_version, install_log=marker.get("install_log") or ""
        )
    if installed_version != to_version:
        return "failed", "unexpected_version", DETAIL_POST_UNEXPECTED_VERSION.format(
            installed=installed_version or "unknown", to=to_version
        )
    if maintenance:
        logger.warning("Post-update check: maintenance mode is on (%s)", maintenance_reason)
        return "failed", "migration_failed", DETAIL_POST_MIGRATION_FAILED.format(to=to_version)
    if quick != "ok":
        return "failed", "db_check_failed", DETAIL_POST_DB_CHECK_FAILED
    return "success", None, None
