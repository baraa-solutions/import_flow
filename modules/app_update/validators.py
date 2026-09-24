"""
Domain rules for the application updater (plan §4.2, §4.8, §4.9).

Pure functions: version parsing, update host allow-list, relative installer path rules, dev-mode guard.
"""
import logging
import os
import re
from typing import Optional, Tuple
from urllib.parse import urlsplit

from fastapi import HTTPException, status

from utils.db_safety import app_base_dir, is_frozen_build

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

VERSION_RE = re.compile(r"^\d+\.\d+\.\d+$")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
INSTALLER_FILENAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*\.exe$")
_PATH_SEGMENT_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")

# User-facing error details (plan §6)
DETAIL_DEV_MODE = "التحديث التلقائي غير متاح في وضع التطوير"
DETAIL_NO_UPDATE_FOR_VERSION = "لا يوجد تحديث متاح لهذا الإصدار"
DETAIL_DOWNLOAD_IN_PROGRESS = "جاري تنزيل التحديث بالفعل"
DETAIL_SERVER_UNREACHABLE = "تعذّر الاتصال بخادم التحديثات"
DETAIL_NO_DOWNLOAD_RUNNING = "لا توجد عملية تنزيل جارية"
DETAIL_HASH_MISMATCH = "الملف الذي تم تنزيله غير مطابق للبصمة الرقمية وتم حذفه"
DETAIL_SIZE_EXCEEDED = "حجم الملف الذي تم تنزيله أكبر من المتوقع وتم حذفه"
DETAIL_DOWNLOAD_FAILED = "فشل تنزيل التحديث"
DETAIL_NOT_IMPLEMENTED = "غير متاح بعد"


class ManifestError(ValueError):
    """The manifest is unsigned, tampered, malformed, or violates a client rule."""


# ─── Versions ─────────────────────────────────────────────────────────────────

def is_valid_version(value: object) -> bool:
    return isinstance(value, str) and bool(VERSION_RE.match(value))


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
    if not all(_PATH_SEGMENT_RE.match(seg) for seg in segments):
        raise ManifestError("installer path contains forbidden characters")
    if not INSTALLER_FILENAME_RE.match(segments[-1]):
        raise ManifestError("installer path must end with an .exe file name")
    return path


def installer_filename(path: str) -> str:
    return validate_installer_path(path).rsplit("/", 1)[-1]


def build_installer_url(base_url: str, path: str) -> str:
    return validate_base_url(base_url) + validate_installer_path(path)


def validate_sha256(value: object) -> str:
    if not isinstance(value, str) or not SHA256_RE.match(value.lower()):
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
