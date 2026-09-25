"""
Application update service (plan §4.2, §4.5 steps 1-3, §4.6, §4.8, §4.9).

- ManifestVerifier: Ed25519 over the exact UTF-8 bytes of the envelope's `signed` string, then the client rules
  (relative installer path, strict versions, sha256/size shape).
- UpdateService: check (1 h cache in memory + last_manifest.json on disk, re-verified on load), download
  (background thread, streams to staging/<file>.part hashing as it goes, aborts on size overflow, deletes on
  mismatch, then pre-fetches the previous installer for rollback), cancel, status, history, stage-local (USB),
  apply (R5 pre-update backup gate + detached installer launch), post-update health check, last-result and
  rollback (restore the pre-update backup + launch the previous installer). A single lock guards the state machine.

K1 (spec §0): backend_runner kills this process ~3 s after the frontend exits, and the frontend exits 800 ms after
the 202 of /apply or /rollback. Every step of apply/rollback, including launching Setup, therefore finishes before
the response is returned; nothing runs in the background afterwards.

No route accepts a URL: the manifest URL is the code constant (or an allow-listed https override) and the
installer URL is BASE_URL + the signed relative path.
"""
import base64
import binascii
import hashlib
import json
import logging
import os
import shutil
import subprocess
import threading
import time
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, BinaryIO, Callable, Dict, List, Optional, Tuple

import httpx
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
from fastapi import HTTPException, status
from pydantic import ValidationError
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from database.database import DB_PATH, SessionLocal, engine
from modules.app_update import validators as update_rules
from modules.audit_logs.service import AuditLogService
from utils.db_safety import (
    app_base_dir,
    clean_child_environment,
    backups_dir_for,
    check_integrity,
    clear_maintenance_mode,
    enter_maintenance_mode,
    is_maintenance_mode,
    maintenance_reason,
    quick_check,
    same_file,
    sha256_file,
    sqlite_online_backup,
    version_file_path,  # frozen: next to backend.exe; source run: repo root
)
from modules.app_update.repository import UpdateFileRepository, default_update_data_dir
from modules.app_update.schemas import (
    ApplyResponse,
    LastResultResponse,
    RollbackResponse,
    ReleaseNotes,
    UpdateCheckResponse,
    UpdateHistoryItem,
    UpdateHistoryResponse,
    UpdateStatusResponse,
)
from modules.app_update.validators import (
    DETAIL_ALREADY_ON_PREVIOUS,
    DETAIL_ASIDE_FAILED,
    DETAIL_BACKUP_CORRUPT,
    DETAIL_BACKUP_FAILED,
    DETAIL_CLIENT_VERSION_MISMATCH,
    DETAIL_DOWNLOAD_FAILED,
    DETAIL_DOWNLOAD_IN_PROGRESS,
    DETAIL_HASH_MISMATCH,
    DETAIL_INVALID_SIGNATURE,
    DETAIL_LAUNCH_FAILED,
    DETAIL_LOCAL_COPY_FAILED,
    DETAIL_LOCAL_HASH_MISMATCH,
    DETAIL_NO_DOWNLOAD_RUNNING,
    DETAIL_NO_ROLLBACK_AVAILABLE,
    DETAIL_NO_UPDATE_FOR_VERSION,
    DETAIL_NOT_NEWER,
    DETAIL_NOT_READY,
    DETAIL_PREVIOUS_INSTALLER_MISSING,
    DETAIL_RESTORE_FAILED,
    DETAIL_ROLLBACK_CONFIRM_REQUIRED,
    DETAIL_ROLLBACK_INSTALLER_TAMPERED,
    DETAIL_ROLLBACK_LAUNCH_FAILED,
    DETAIL_SERVER_UNREACHABLE,
    DETAIL_SIZE_EXCEEDED,
    DETAIL_UPDATE_BUSY,
    HTTP_TIMEOUT_SECONDS,
    MANIFEST_APP,
    MANIFEST_FILENAME,
    MANIFEST_MAX_BYTES,
    MANIFEST_SCHEMA,
    ManifestError,
    build_installer_command,
    build_installer_url,
    classify_post_update,
    ensure_apply_supported,
    env_value,
    installer_filename,
    is_apply_supported,
    is_newer,
    is_valid_version,
    parse_version,
    pre_restore_aside_name,
    pre_update_backup_name,
    resolve_base_url,
    validate_backup_filename,
    validate_installer_path,
    validate_local_file,
    validate_sha256,
    validate_size,
)

logger = logging.getLogger(__name__)

# ─── Trusted signing keys ─────────────────────────────────────────────────────
# key_id -> base64 of the raw 32-byte Ed25519 public key. Two slots allow rotation (plan §4.2).
# !!! PLACEHOLDER !!! The real public key is added when the CTO generates the signing key
# (plan §9 step 5: `scripts/release/build_manifest.py --generate-key`). Until then no manifest can verify,
# and /check reports check_status="disabled" without touching the network.
UPDATE_SIGNING_PUBLIC_KEYS: Dict[str, str] = {
    "k2026a": "PyOCq8jGaONNNAdRRt8/h141hqb+qJ17aETLwCo8XFY=",
}

CACHE_TTL = timedelta(hours=1)
FORCE_MIN_INTERVAL_SECONDS = 60.0  # at most one network check per minute, even with ?force=true
UNKNOWN_VERSION = "unknown"
DOWNLOAD_CHUNK_BYTES = 64 * 1024
BUSY_STATES = frozenset({"downloading", "verifying", "backing_up", "installing"})
DOWNLOAD_STATES = frozenset({"downloading", "verifying"})
MARKER_SCHEMA = 1
BACKUP_DISK_MARGIN_BYTES = 50 * 1024 * 1024  # R5: free >= 2 * db_size + 50 MB
LOCAL_COPY_CHUNK_BYTES = 1024 * 1024


# ─── Verified manifest ────────────────────────────────────────────────────────

@dataclass(frozen=True)
class InstallerInfo:
    path: str
    filename: str
    size_bytes: int
    sha256: str


@dataclass(frozen=True)
class PreviousRelease:
    version: str
    installer: InstallerInfo


@dataclass(frozen=True)
class VerifiedManifest:
    key_id: str
    version: str
    build_number: int
    released_at: Optional[datetime]
    expires_at: datetime
    min_supported_version: Optional[str]
    mandatory: bool
    release_notes: Dict[str, List[str]]
    installer: InstallerInfo
    previous: Optional[PreviousRelease] = None
    db_schema_revision: Optional[str] = None
    channel: str = "stable"
    raw: bytes = field(default=b"", repr=False, compare=False)


def _parse_installer(data: object) -> InstallerInfo:
    if not isinstance(data, dict):
        raise ManifestError("installer block missing")
    path = validate_installer_path(data.get("path"))
    return InstallerInfo(
        path=path,
        filename=installer_filename(path),
        size_bytes=validate_size(data.get("size_bytes")),
        sha256=validate_sha256(data.get("sha256")),
    )


def _parse_release_notes(data: object) -> Dict[str, List[str]]:
    if data is None:
        return {"ar": [], "en": []}
    if not isinstance(data, dict):
        raise ManifestError("release_notes must be an object")
    notes: Dict[str, List[str]] = {}
    for lang in ("ar", "en"):
        items = data.get(lang, [])
        if not isinstance(items, list) or not all(isinstance(i, str) for i in items):
            raise ManifestError(f"release_notes.{lang} must be a list of strings")
        notes[lang] = list(items)
    return notes


def _parse_datetime(value: object, name: str) -> Optional[datetime]:
    """ISO-8601; a value without an offset is read as UTC. Returned in UTC."""
    if value in (None, ""):
        return None
    if not isinstance(value, str):
        raise ManifestError(f"{name} must be an ISO-8601 string")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ManifestError(f"{name} is not ISO-8601") from exc
    parsed = parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


class ManifestVerifier:
    """Verifies the signed envelope {key_id, signature, signed} and returns the parsed payload."""

    def __init__(self, public_keys: Optional[Dict[str, str]] = None):
        self._explicit_keys = public_keys

    def _key_map(self) -> Dict[str, str]:
        # Looked up at call time so tests (and a later key rotation) can replace the module constant.
        return self._explicit_keys if self._explicit_keys is not None else UPDATE_SIGNING_PUBLIC_KEYS

    @staticmethod
    def _load_key(encoded: str) -> Optional[Ed25519PublicKey]:
        try:
            raw = base64.b64decode(encoded, validate=True)
            if len(raw) != 32:
                return None
            return Ed25519PublicKey.from_public_bytes(raw)
        except (binascii.Error, ValueError, TypeError):
            return None

    def has_usable_key(self) -> bool:
        return any(self._load_key(v) is not None for v in self._key_map().values())

    def verify(self, raw: bytes) -> VerifiedManifest:
        """
        Any failure (including UnicodeEncodeError on lone surrogates, RecursionError on deeply nested JSON, or any
        other unexpected error) is reported as ManifestError: a hostile manifest must never crash the caller.
        """
        try:
            return self._verify(raw)
        except ManifestError:
            raise
        except RecursionError as exc:
            raise ManifestError("manifest nesting is too deep") from exc
        except Exception as exc:
            raise ManifestError(f"manifest rejected: {type(exc).__name__}") from exc

    def _verify(self, raw: bytes) -> VerifiedManifest:
        if not isinstance(raw, (bytes, bytearray)):
            raise ManifestError("manifest must be bytes")
        if len(raw) > MANIFEST_MAX_BYTES:
            raise ManifestError("manifest exceeds the size cap")
        try:
            envelope = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, ValueError) as exc:
            raise ManifestError("manifest is not valid JSON") from exc
        if not isinstance(envelope, dict):
            raise ManifestError("manifest envelope must be an object")
        key_id, signature, signed = envelope.get("key_id"), envelope.get("signature"), envelope.get("signed")
        if not all(isinstance(v, str) and v for v in (key_id, signature, signed)):
            raise ManifestError("manifest envelope requires key_id, signature and signed strings")

        encoded_key = self._key_map().get(key_id)
        public_key = self._load_key(encoded_key) if encoded_key else None
        if public_key is None:
            raise ManifestError(f"unknown signing key_id {key_id!r}")
        try:
            sig_bytes = base64.b64decode(signature, validate=True)
        except (binascii.Error, ValueError) as exc:
            raise ManifestError("signature is not valid base64") from exc
        try:
            public_key.verify(sig_bytes, signed.encode("utf-8"))
        except InvalidSignature as exc:
            raise ManifestError("signature does not match") from exc

        # Only now is the payload trusted enough to parse.
        try:
            payload = json.loads(signed)
        except ValueError as exc:
            raise ManifestError("signed payload is not valid JSON") from exc
        if not isinstance(payload, dict):
            raise ManifestError("signed payload must be an object")
        return self._parse_payload(payload, key_id, raw)

    @staticmethod
    def _parse_payload(payload: Dict[str, object], key_id: str, raw: bytes) -> VerifiedManifest:
        if payload.get("schema") != MANIFEST_SCHEMA:
            raise ManifestError("unsupported manifest schema")
        if payload.get("app") != MANIFEST_APP:
            raise ManifestError("manifest is for another application")
        channel = payload.get("channel", "stable")
        if channel != "stable":
            raise ManifestError("unsupported channel")
        version = payload.get("version")
        if not is_valid_version(version):
            raise ManifestError("invalid version")
        build = payload.get("build_number", 0)
        if isinstance(build, bool) or not isinstance(build, int) or build < 0:
            raise ManifestError("invalid build_number")
        min_supported = payload.get("min_supported_version")
        if min_supported is not None and not is_valid_version(min_supported):
            raise ManifestError("invalid min_supported_version")
        mandatory = payload.get("mandatory", False)
        if not isinstance(mandatory, bool):
            raise ManifestError("mandatory must be a boolean")
        db_rev = payload.get("db_schema_revision")
        if db_rev is not None and not isinstance(db_rev, str):
            raise ManifestError("db_schema_revision must be a string")

        released_at = _parse_datetime(payload.get("released_at"), "released_at")
        expires_at = _parse_datetime(payload.get("expires_at"), "expires_at")
        if expires_at is None:
            raise ManifestError("expires_at is required")
        if released_at is not None and expires_at <= released_at:
            raise ManifestError("expires_at must be after released_at")

        previous = None
        prev_data = payload.get("previous")
        if prev_data is not None:
            if not isinstance(prev_data, dict) or not is_valid_version(prev_data.get("version")):
                raise ManifestError("invalid previous release block")
            if not is_newer(version, prev_data["version"]):
                raise ManifestError("previous.version must be older than version")
            previous = PreviousRelease(
                version=prev_data["version"],
                installer=_parse_installer(prev_data.get("installer")),
            )

        return VerifiedManifest(
            key_id=key_id,
            version=version,
            build_number=build,
            released_at=released_at,
            expires_at=expires_at,
            min_supported_version=min_supported,
            mandatory=mandatory,
            release_notes=_parse_release_notes(payload.get("release_notes")),
            installer=_parse_installer(payload.get("installer")),
            previous=previous,
            db_schema_revision=db_rev,
            channel=channel,
            raw=raw,
        )


# ─── Installed version ────────────────────────────────────────────────────────

def get_installed_version(path: Optional[Path] = None) -> Optional[Tuple[str, int]]:
    """
    (version, build_number) from version.json, or None when it is missing or malformed. Fails closed: callers
    disable the updater instead of guessing a low version (a '0.0.0' guess would make any old build look newer).
    """
    target = path or version_file_path()
    try:
        data = json.loads(Path(target).read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        logger.warning("Cannot read installed version from %s: %s", target, exc)
        return None
    if not isinstance(data, dict):
        logger.warning("Installed version file %s is not a JSON object", target)
        return None
    version, build = data.get("version"), data.get("build_number")
    if not is_valid_version(version) or isinstance(build, bool) or not isinstance(build, int) or build < 0:
        logger.warning("Installed version file %s has an invalid version/build_number", target)
        return None
    return version, build


# ─── Internal signals ─────────────────────────────────────────────────────────

class _FetchError(Exception):
    """Network / HTTP failure talking to the update host."""


class _Cancelled(Exception):
    pass


class _SizeExceeded(Exception):
    pass


class _HashMismatch(Exception):
    pass


class _StaleManifest(Exception):
    """Validly signed but not acceptable now: expired, or older than a manifest already seen (replay/freeze)."""


class _LowDiskSpace(Exception):
    """R5: not enough free space next to the DB for the pre-update backup."""


def _start_daemon_thread(fn: Callable[[], None]) -> None:
    threading.Thread(target=fn, name="app-update-download", daemon=True).start()


# ─── Installer launch (spec B.3 step 9) ───────────────────────────────────────

_DETACHED_PROCESS = getattr(subprocess, "DETACHED_PROCESS", 0x00000008)
_CREATE_NEW_PROCESS_GROUP = getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0x00000200)
_CREATE_BREAKAWAY_FROM_JOB = getattr(subprocess, "CREATE_BREAKAWAY_FROM_JOB", 0x01000000)
_ERROR_ACCESS_DENIED = 5


def launch_installer_detached(command: str, cwd: Path) -> int:
    """
    Start Setup detached from this process (no console, own process group, outside our job object) so it
    survives backend.exe being killed, first by the frontend watchdog and then by Setup's own StopRunningApp.
    When the job forbids breakaway (winerror 5), retry once without CREATE_BREAKAWAY_FROM_JOB. Returns the pid.
    The environment drops our PyInstaller bootloader state (_PYI_*, _MEIPASS*): Setup relaunches frontend.exe,
    which starts the NEW backend.exe, and an inherited _PYI_* would make it reuse our old _MEI data files.
    """
    base_flags = _DETACHED_PROCESS | _CREATE_NEW_PROCESS_GROUP

    def _spawn(flags: int) -> int:
        proc = subprocess.Popen(
            command,
            cwd=str(cwd),
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            close_fds=True,
            creationflags=flags,
            env=clean_child_environment(),
        )
        return proc.pid

    try:
        return _spawn(base_flags | _CREATE_BREAKAWAY_FROM_JOB)
    except OSError as exc:
        if getattr(exc, "winerror", None) != _ERROR_ACCESS_DENIED:
            raise
        logger.warning("Job object forbids breakaway; launching the installer without CREATE_BREAKAWAY_FROM_JOB")
        return _spawn(base_flags)


def _dispose_default_engine() -> None:
    engine.dispose()


def _default_disk_free(path: Path) -> int:
    return shutil.disk_usage(path).free


def _utc_iso(value: datetime) -> str:
    return value.astimezone(timezone.utc).isoformat()


MaintenanceSnapshot = Tuple[bool, str]


def _maintenance_snapshot() -> MaintenanceSnapshot:
    return is_maintenance_mode(), maintenance_reason()


def _enter_maintenance(reason: str) -> None:
    """Enter maintenance mode unless it is already on: a startup reason (R8/R10) is never overwritten."""
    if not is_maintenance_mode():
        enter_maintenance_mode(reason)


def _restore_maintenance(snapshot: MaintenanceSnapshot) -> None:
    """Put maintenance mode back exactly as it was before the operation (on with its old reason, or off)."""
    was_on, reason = snapshot
    if was_on:
        enter_maintenance_mode(reason)
    else:
        clear_maintenance_mode()


_GENERIC_READ = 0x80000000
_FILE_SHARE_READ = 0x00000001
_OPEN_EXISTING = 3
_FILE_ATTRIBUTE_NORMAL = 0x80
_create_file_w = None


def _open_share_deny_write(path: Path) -> BinaryIO:
    """
    Open `path` for reading while denying write/delete/rename to everybody else (Windows share mode FILE_SHARE_READ
    only), so the bytes that were hashed are the bytes CreateProcess starts. Reading and executing stay allowed.
    Elsewhere (tests on other OSes) a plain read handle.
    """
    if os.name != "nt":
        return open(path, "rb")
    import ctypes
    import msvcrt
    from ctypes import wintypes

    global _create_file_w
    if _create_file_w is None:
        fn = ctypes.WinDLL("kernel32", use_last_error=True).CreateFileW
        fn.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, wintypes.LPVOID,
                       wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
        fn.restype = wintypes.HANDLE
        _create_file_w = fn
    handle = _create_file_w(str(path), _GENERIC_READ, _FILE_SHARE_READ, None, _OPEN_EXISTING,
                            _FILE_ATTRIBUTE_NORMAL, None)
    if handle is None or handle == wintypes.HANDLE(-1).value:
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        fd = msvcrt.open_osfhandle(handle, os.O_RDONLY | getattr(os, "O_BINARY", 0))
    except OSError:
        ctypes.windll.kernel32.CloseHandle(wintypes.HANDLE(handle))
        raise
    return os.fdopen(fd, "rb")


def _hash_and_hold(path: Path, size_bytes: int, sha256: str) -> Optional[BinaryIO]:
    """
    Verify size + sha256 through a share-deny-write handle and return it still open (the caller closes it after
    the launch), or None when the file is missing, locked by someone else, or does not match.
    """
    try:
        fh = _open_share_deny_write(path)
    except OSError as exc:
        logger.warning("Could not open %s for verification: %s", path, exc)
        return None
    try:
        if os.fstat(fh.fileno()).st_size != size_bytes:
            fh.close()
            return None
        digest = hashlib.sha256()
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
        if digest.hexdigest() != sha256:
            fh.close()
            return None
        return fh
    except OSError as exc:
        fh.close()
        logger.warning("Could not hash %s: %s", path, exc)
        return None


def _close_quietly(fh: Optional[BinaryIO]) -> None:
    if fh is None:
        return
    try:
        fh.close()
    except OSError as exc:
        logger.warning("Could not close a verified installer handle: %s", exc)


def _file_matches(path: Path, size_bytes: int, sha256: str) -> bool:
    """True when `path` is a regular file with exactly this size and sha256."""
    try:
        return path.is_file() and path.stat().st_size == size_bytes and sha256_file(path) == sha256
    except OSError as exc:
        logger.warning("Could not hash %s: %s", path, exc)
        return False


# ─── Service ──────────────────────────────────────────────────────────────────

class UpdateService:
    def __init__(
        self,
        data_dir: Optional[Path] = None,
        transport: Optional[httpx.BaseTransport] = None,
        verifier: Optional[ManifestVerifier] = None,
        installed_version_provider: Optional[Callable[[], Optional[Tuple[str, int]]]] = None,
        apply_supported_provider: Optional[Callable[[], bool]] = None,
        base_url_provider: Optional[Callable[[], Optional[str]]] = None,
        run_in_background: Optional[Callable[[Callable[[], None]], None]] = None,
        monotonic: Optional[Callable[[], float]] = None,
        utcnow: Optional[Callable[[], datetime]] = None,
        db_path: Optional[Path] = None,
        backups_dir: Optional[Path] = None,
        app_dir_provider: Optional[Callable[[], Path]] = None,
        launcher: Optional[Callable[[str, Path], int]] = None,
        dispose_engine: Optional[Callable[[], None]] = None,
        disk_free: Optional[Callable[[Path], int]] = None,
        session_factory: Optional[Callable[[], Session]] = None,
    ):
        self._data_dir = Path(data_dir) if data_dir else None
        self._transport = transport
        self._verifier = verifier or ManifestVerifier()
        self._installed_version_provider = installed_version_provider or get_installed_version
        self._apply_supported_provider = apply_supported_provider or is_apply_supported
        self._base_url_provider = base_url_provider or (lambda: resolve_base_url(env_value("UPDATE_BASE_URL")))
        self._run_in_background = run_in_background or _start_daemon_thread
        self._monotonic = monotonic or time.monotonic
        self._utcnow = utcnow or (lambda: datetime.now(timezone.utc))
        self._db_path = Path(db_path) if db_path else Path(DB_PATH)
        self._backups_dir = Path(backups_dir) if backups_dir else backups_dir_for(self._db_path)
        self._app_dir_provider = app_dir_provider or app_base_dir
        self._launcher = launcher or launch_installer_detached
        self._dispose_engine = dispose_engine or _dispose_default_engine
        self._disk_free = disk_free or _default_disk_free
        self._session_factory = session_factory or SessionLocal
        self._pending_evaluated = False
        self._recovery_attempted = False

        self._lock = threading.RLock()
        self._state = "idle"
        self._version: Optional[str] = None
        self._downloaded = 0
        self._total = 0
        self._error_code: Optional[str] = None
        self._error_detail: Optional[str] = None
        self._job_id = 0
        self._cancel_event: Optional[threading.Event] = None

        self._manifest: Optional[VerifiedManifest] = None
        self._manifest_fetched_at: Optional[datetime] = None
        self._disk_cache_loaded = False
        self._last_fetch_mono: Optional[float] = None
        self._last_fetch_failure: Optional[str] = None  # check_status of the last failed network check

    # ─── plumbing ─────────────────────────────────────────────────────────
    def _repo(self) -> UpdateFileRepository:
        return UpdateFileRepository(self._data_dir or default_update_data_dir())

    def _client(self) -> httpx.Client:
        installed_info = self._installed_version_provider()
        installed = installed_info[0] if installed_info else UNKNOWN_VERSION
        return httpx.Client(
            transport=self._transport,
            timeout=HTTP_TIMEOUT_SECONDS,
            follow_redirects=False,
            headers={"User-Agent": f"SorourLogistics-Updater/{installed}", "Cache-Control": "no-cache"},
        )

    def _fetch_manifest_bytes(self, base_url: str) -> bytes:
        url = base_url + MANIFEST_FILENAME
        try:
            with self._client() as client:
                with client.stream("GET", url, params={"t": str(int(time.time()))}) as resp:
                    if resp.status_code != 200:
                        raise _FetchError(f"manifest HTTP {resp.status_code}")
                    declared = resp.headers.get("content-length")
                    if declared and declared.isdigit() and int(declared) > MANIFEST_MAX_BYTES:
                        raise ManifestError("manifest exceeds the size cap")
                    buf = bytearray()
                    for chunk in resp.iter_bytes():
                        buf.extend(chunk)
                        if len(buf) > MANIFEST_MAX_BYTES:
                            raise ManifestError("manifest exceeds the size cap")
                    return bytes(buf)
        except httpx.HTTPError as exc:
            raise _FetchError(f"{type(exc).__name__}: {exc}") from exc

    def _freshness_problem(self, manifest: VerifiedManifest, repo: UpdateFileRepository) -> Optional[str]:
        """Reason to refuse a validly signed manifest (expired / replay of an older one); None when acceptable."""
        if manifest.expires_at <= self._utcnow():
            return f"expired at {manifest.expires_at.isoformat()}"
        highest = repo.load_highest_seen()
        if highest and (parse_version(manifest.version), manifest.build_number) < (
            parse_version(highest[0]),
            highest[1],
        ):
            return f"replay: {manifest.version}+{manifest.build_number} is older than {highest[0]}+{highest[1]}"
        return None

    def _fetch_verified(self, base_url: str, repo: UpdateFileRepository) -> VerifiedManifest:
        """Fetch + verify + freshness (expiry, anti-rollback). Raises _FetchError / ManifestError / _StaleManifest."""
        manifest = self._verifier.verify(self._fetch_manifest_bytes(base_url))
        problem = self._freshness_problem(manifest, repo)
        if problem:
            raise _StaleManifest(problem)
        self._record_highest_seen(repo, manifest)
        self._remember_manifest(manifest, self._utcnow())
        return manifest

    @staticmethod
    def _record_highest_seen(repo: UpdateFileRepository, manifest: VerifiedManifest) -> None:
        try:
            repo.save_highest_seen(manifest.version, manifest.build_number)
        except OSError as exc:
            logger.warning("Could not persist highest_seen.json: %s", exc)

    def _remember_manifest(self, manifest: VerifiedManifest, fetched_at: datetime) -> None:
        with self._lock:
            self._manifest = manifest
            self._manifest_fetched_at = fetched_at
            self._disk_cache_loaded = True
        try:
            self._repo().save_last_manifest(manifest.raw, fetched_at)
        except OSError as exc:
            logger.warning("Could not persist last_manifest.json: %s", exc)

    def _cached_manifest(self, max_age: Optional[timedelta]) -> Optional[Tuple[VerifiedManifest, datetime]]:
        """Memory cache, else last_manifest.json re-verified once per process. None when stale/missing."""
        with self._lock:
            if self._manifest is None and not self._disk_cache_loaded:
                self._disk_cache_loaded = True
                stored = self._repo().load_last_manifest()
                if stored:
                    try:
                        self._manifest = self._verifier.verify(stored["raw"])
                        self._manifest_fetched_at = stored["fetched_at"]
                    except ManifestError as exc:
                        logger.warning("Cached manifest failed verification, ignoring it: %s", exc)
            if self._manifest is None or self._manifest_fetched_at is None:
                return None
            if max_age is not None and self._utcnow() - self._manifest_fetched_at > max_age:
                return None
            return self._manifest, self._manifest_fetched_at

    def _last_success_at(self) -> Optional[datetime]:
        cached = self._cached_manifest(max_age=None)
        return cached[1] if cached else None

    # ─── check ────────────────────────────────────────────────────────────
    def check(self, force: bool = False) -> UpdateCheckResponse:
        apply_supported = bool(self._apply_supported_provider())
        installed_info = self._installed_version_provider()
        if installed_info is None:
            # Fail closed: without a trustworthy installed version any manifest could look like an upgrade.
            return UpdateCheckResponse(
                current_version=UNKNOWN_VERSION,
                current_build=0,
                check_status="disabled",
                apply_supported=apply_supported,
            )
        installed, build = installed_info
        base = UpdateCheckResponse(
            current_version=installed,
            current_build=build,
            check_status="disabled",
            apply_supported=apply_supported,
        )

        base_url = self._base_url_provider()
        if base_url is None or not self._verifier.has_usable_key():
            base.last_checked_at = self._last_success_at()
            return base

        repo = self._repo()
        now_mono = self._monotonic()
        throttled = (
            self._last_fetch_mono is not None and now_mono - self._last_fetch_mono < FORCE_MIN_INTERVAL_SECONDS
        )
        cached = self._cached_manifest(max_age=CACHE_TTL)
        if force and not throttled:
            cached = None

        if cached is None and throttled and self._last_fetch_failure:
            # The last network check (under a minute ago) failed: repeat its outcome without touching the network.
            base.check_status = self._last_fetch_failure
            base.last_checked_at = self._last_success_at()
            return base

        if cached is None:
            self._last_fetch_mono = now_mono
            try:
                manifest = self._fetch_verified(base_url, repo)
            except _FetchError as exc:
                logger.info("Update check offline: %s", exc)
                return self._check_failed(base, repo, "offline", f"offline: {exc}")
            except _StaleManifest as exc:
                logger.warning("Update manifest refused: %s", exc)
                return self._check_failed(base, repo, "offline", str(exc))
            except ManifestError as exc:
                logger.warning("Update manifest rejected: %s", exc)
                return self._check_failed(base, repo, "invalid_signature", f"invalid_signature: {exc}")
            self._last_fetch_failure = None
            repo.append_history("check_ok", manifest.version, None)
            cached = (manifest, self._manifest_fetched_at or self._utcnow())
        else:
            problem = self._freshness_problem(cached[0], repo)
            if problem:
                logger.info("Cached update manifest no longer usable: %s", problem)
                base.check_status = "offline"
                base.last_checked_at = cached[1]
                return base

        manifest, fetched_at = cached
        return self._check_response(base, manifest, fetched_at, installed)

    def _check_failed(
        self, base: UpdateCheckResponse, repo: UpdateFileRepository, check_status: str, detail: str
    ) -> UpdateCheckResponse:
        self._last_fetch_failure = check_status
        repo.append_history("check_failed", None, detail)
        base.check_status = check_status
        base.last_checked_at = self._last_success_at()
        return base

    @staticmethod
    def _check_response(
        base: UpdateCheckResponse, manifest: VerifiedManifest, fetched_at: datetime, installed: str
    ) -> UpdateCheckResponse:
        base.latest_version = manifest.version
        base.latest_build = manifest.build_number
        base.last_checked_at = fetched_at
        # Never offer a version at or below the installed one (no downgrade / freeze via the manifest).
        if not is_newer(manifest.version, installed):
            base.check_status = "up_to_date"
            return base
        below_min = bool(
            manifest.min_supported_version
            and parse_version(installed) < parse_version(manifest.min_supported_version)
        )
        base.check_status = "update_available"
        base.update_available = True
        base.mandatory = manifest.mandatory or below_min
        base.release_notes = ReleaseNotes(**manifest.release_notes)
        base.released_at = manifest.released_at
        base.installer_size_bytes = manifest.installer.size_bytes
        return base

    # ─── status ───────────────────────────────────────────────────────────
    def get_status(self) -> UpdateStatusResponse:
        self._recover_staged_state()
        return self._status_snapshot()

    def _status_snapshot(self) -> UpdateStatusResponse:
        with self._lock:
            return UpdateStatusResponse(
                state=self._state,
                version=self._version,
                downloaded_bytes=self._downloaded,
                total_bytes=self._total,
                error_code=self._error_code,
                error_detail=self._error_detail,
            )

    # ─── download ─────────────────────────────────────────────────────────
    def _manifest_for_download(self, version: str, base_url: str) -> VerifiedManifest:
        repo = self._repo()
        cached = self._cached_manifest(max_age=None)
        if cached and cached[0].version == version and self._freshness_problem(cached[0], repo) is None:
            return cached[0]
        # The cache is empty, expired or advertises another version: refresh once from the server.
        try:
            return self._fetch_verified(base_url, repo)
        except _FetchError as exc:
            logger.info("Update server unreachable for download: %s", exc)
            raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=DETAIL_SERVER_UNREACHABLE)
        except (ManifestError, _StaleManifest) as exc:
            logger.warning("Update manifest refused during download: %s", exc)
            repo.append_history("download_refused", version, str(exc))
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=DETAIL_NO_UPDATE_FOR_VERSION)

    def start_download(self, version: str, actor: str, db: Optional[Session] = None) -> UpdateStatusResponse:
        ensure_apply_supported(bool(self._apply_supported_provider()))
        with self._lock:
            if self._state in BUSY_STATES:
                raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=DETAIL_DOWNLOAD_IN_PROGRESS)

        base_url = self._base_url_provider()
        if base_url is None or not self._verifier.has_usable_key():
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=DETAIL_NO_UPDATE_FOR_VERSION)
        installed_info = self._installed_version_provider()
        if installed_info is None:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=DETAIL_NO_UPDATE_FOR_VERSION)
        installed = installed_info[0]
        manifest = self._manifest_for_download(version, base_url)
        if manifest.version != version or not is_newer(version, installed):
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=DETAIL_NO_UPDATE_FOR_VERSION)

        repo = self._repo()
        with self._lock:  # cheap early exit before the previous installer is hashed below
            if self._already_staged(version, repo, manifest):
                return self._status_snapshot()
        # B.6: the previous installer is pre-fetched for rollback when it is the installed version and missing.
        fetch_previous = self._needs_previous_installer(manifest, installed, repo)
        with self._lock:
            if self._state in BUSY_STATES:
                raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=DETAIL_DOWNLOAD_IN_PROGRESS)
            if self._already_staged(version, repo, manifest):
                return self._status_snapshot()
            self._job_id += 1
            job_id = self._job_id
            cancel_event = threading.Event()
            self._cancel_event = cancel_event
            self._state = "downloading"
            self._version = version
            self._downloaded = 0
            self._total = manifest.installer.size_bytes + (
                manifest.previous.installer.size_bytes if fetch_previous and manifest.previous else 0
            )
            self._error_code = None
            self._error_detail = None

        repo.append_history("download_started", version, f"by {actor}")
        self._audit(db, actor, "UPDATE_DOWNLOAD", version)
        self._run_in_background(
            lambda: self._download_worker(job_id, cancel_event, manifest, base_url, fetch_previous)
        )
        return self._status_snapshot()

    def _already_staged(self, version: str, repo: UpdateFileRepository, manifest: VerifiedManifest) -> bool:
        """Caller holds the lock: this version is already downloaded and verified."""
        return (
            self._state == "ready"
            and self._version == version
            and repo.staged_file(manifest.installer.filename).is_file()
        )

    @staticmethod
    def _needs_previous_installer(manifest: VerifiedManifest, installed: str, repo: UpdateFileRepository) -> bool:
        previous = manifest.previous
        if previous is None or previous.version != installed:
            return False
        kept = repo.installer_path(previous.installer.filename)
        return not _file_matches(kept, previous.installer.size_bytes, previous.installer.sha256)

    def _is_current(self, job_id: int, cancel_event: threading.Event) -> bool:
        return job_id == self._job_id and not cancel_event.is_set()

    def _set_progress(self, job_id: int, cancel_event: threading.Event, received: int) -> None:
        with self._lock:
            if self._is_current(job_id, cancel_event):
                self._downloaded = received

    def _fail(self, job_id: int, cancel_event: threading.Event, code: str, detail: str) -> None:
        with self._lock:
            if self._is_current(job_id, cancel_event):
                self._state = "failed"
                self._error_code = code
                self._error_detail = detail

    def _stream_installer(
        self,
        client: httpx.Client,
        url: str,
        part: Path,
        info: InstallerInfo,
        job_id: int,
        cancel_event: threading.Event,
        progress_offset: int,
    ) -> None:
        """Stream `url` into `part` with the size cap and sha256 check. Raises _SizeExceeded/_HashMismatch/_Cancelled."""
        digest = hashlib.sha256()
        received = 0
        with client.stream("GET", url) as resp:
            if resp.status_code != 200:
                raise _FetchError(f"installer HTTP {resp.status_code}")
            declared = resp.headers.get("content-length")
            if declared and declared.isdigit() and int(declared) > info.size_bytes:
                raise _SizeExceeded()
            with open(part, "wb") as fh:
                for chunk in resp.iter_bytes(DOWNLOAD_CHUNK_BYTES):
                    if cancel_event.is_set():
                        raise _Cancelled()
                    received += len(chunk)
                    if received > info.size_bytes:
                        raise _SizeExceeded()
                    fh.write(chunk)
                    digest.update(chunk)
                    self._set_progress(job_id, cancel_event, progress_offset + received)
        if received != info.size_bytes or digest.hexdigest() != info.sha256:
            raise _HashMismatch()

    def _download_worker(
        self,
        job_id: int,
        cancel_event: threading.Event,
        manifest: VerifiedManifest,
        base_url: str,
        fetch_previous: bool = False,
    ) -> None:
        repo = self._repo()
        installer = manifest.installer
        part = repo.part_file(installer.filename)
        final = repo.staged_file(installer.filename)
        version = manifest.version
        try:
            repo.ensure_staging_dir()
            repo.clear_staging()
            url = build_installer_url(base_url, installer.path)
            with self._client() as client:
                self._stream_installer(client, url, part, installer, job_id, cancel_event, 0)
                with self._lock:
                    if not self._is_current(job_id, cancel_event):
                        raise _Cancelled()
                    self._state = "verifying"
                os.replace(part, final)
                repo.append_history("download_verified", version, installer.sha256)
                if fetch_previous and manifest.previous is not None:
                    self._prefetch_previous(client, base_url, manifest, repo, job_id, cancel_event)

            repo.save_staged_manifest(manifest.raw)
            with self._lock:
                if not self._is_current(job_id, cancel_event):
                    raise _Cancelled()
                self._state = "ready"
                self._downloaded = self._total
        except _Cancelled:
            repo.remove_file(part)
            repo.remove_file(final)
        except _SizeExceeded:
            repo.remove_file(part)
            self._fail(job_id, cancel_event, "size_exceeded", DETAIL_SIZE_EXCEEDED)
            repo.append_history("download_size_exceeded", version, f"expected {installer.size_bytes} bytes")
        except _HashMismatch:
            repo.remove_file(part)
            self._fail(job_id, cancel_event, "hash_mismatch", DETAIL_HASH_MISMATCH)
            repo.append_history("hash_mismatch", version, None)
        except (_FetchError, httpx.HTTPError, OSError, ManifestError) as exc:
            repo.remove_file(part)
            repo.remove_file(final)
            logger.warning("Update download failed: %s", exc)
            self._fail(job_id, cancel_event, "download_failed", DETAIL_DOWNLOAD_FAILED)
            repo.append_history("download_failed", version, f"{type(exc).__name__}: {exc}")
        except Exception as exc:  # the worker thread must always leave a terminal state
            repo.remove_file(part)
            repo.remove_file(final)
            logger.exception("Unexpected error in update download worker")
            self._fail(job_id, cancel_event, "download_failed", DETAIL_DOWNLOAD_FAILED)
            repo.append_history("download_failed", version, f"{type(exc).__name__}: {exc}")
        finally:
            # /cancel must only ever reach a running download, never a later apply/stage-local in `verifying`.
            with self._lock:
                if self._cancel_event is cancel_event:
                    self._cancel_event = None

    def _prefetch_previous(
        self,
        client: httpx.Client,
        base_url: str,
        manifest: VerifiedManifest,
        repo: UpdateFileRepository,
        job_id: int,
        cancel_event: threading.Event,
    ) -> None:
        """
        B.6: download the installer of the version installed now into installers/ so a rollback never needs the
        network (K1). Failure never blocks the update (Decision 3): history `previous_download_failed`, and a later
        rollback answers 409 with the manual-rollback detail. Cancellation still cancels the whole job.
        """
        previous = manifest.previous
        assert previous is not None
        info = previous.installer
        repo.ensure_installers_dir()
        part = repo.installer_part_file(info.filename)
        try:
            url = build_installer_url(base_url, info.path)
            self._stream_installer(
                client, url, part, info, job_id, cancel_event, manifest.installer.size_bytes
            )
            os.replace(part, repo.installer_path(info.filename))
        except _Cancelled:
            repo.remove_file(part)
            raise
        except (_FetchError, _SizeExceeded, _HashMismatch, httpx.HTTPError, OSError, ManifestError) as exc:
            repo.remove_file(part)
            logger.warning("Pre-fetching the previous installer v%s failed: %s", previous.version, exc)
            repo.append_history("previous_download_failed", previous.version, type(exc).__name__)
            return
        repo.append_history("previous_downloaded", previous.version, info.sha256)

    # ─── cancel ───────────────────────────────────────────────────────────
    def cancel(self, actor: str) -> UpdateStatusResponse:
        """Only a running download can be cancelled; apply/stage-local/rollback (no cancel event) -> 409."""
        with self._lock:
            if self._state not in DOWNLOAD_STATES or self._cancel_event is None or self._cancel_event.is_set():
                raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=DETAIL_NO_DOWNLOAD_RUNNING)
            self._cancel_event.set()
            version = self._version
            self._job_id += 1
            self._reset("idle")
        self._repo().append_history("download_cancelled", version, f"by {actor}")
        return self.get_status()

    # ─── history ──────────────────────────────────────────────────────────
    def get_history(self, limit: int) -> UpdateHistoryResponse:
        items: List[UpdateHistoryItem] = []
        for entry in self._repo().read_history(limit):
            try:
                items.append(UpdateHistoryItem(**{k: entry.get(k) for k in ("ts", "event", "version", "detail")}))
            except ValidationError as exc:
                logger.warning("Skipping malformed update history entry: %s", exc)
        return UpdateHistoryResponse(items=items)

    # ─── shared helpers for apply / rollback / stage-local ───────────────
    def _installed_version(self) -> Optional[str]:
        info = self._installed_version_provider()
        return info[0] if info else None

    def _set_failed(self, code: str, detail: str) -> None:
        with self._lock:
            self._job_id += 1
            self._state = "failed"
            self._error_code = code
            self._error_detail = detail

    def _claim(self, allowed: Tuple[str, ...], new_state: str) -> Dict[str, Any]:
        """Atomically move from an allowed state to `new_state`; returns the previous fields. 409 when busy."""
        with self._lock:
            if self._state in BUSY_STATES or self._state not in allowed:
                raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=DETAIL_UPDATE_BUSY)
            previous = {
                "state": self._state,
                "version": self._version,
                "downloaded": self._downloaded,
                "total": self._total,
                "error_code": self._error_code,
                "error_detail": self._error_detail,
            }
            self._job_id += 1
            self._cancel_event = None
            self._state = new_state
            self._error_code = None
            self._error_detail = None
            return previous

    def _reset(self, state: str, version: Optional[str] = None, size_bytes: int = 0) -> None:
        """Caller holds the lock: `state` without an error, downloaded = total = `size_bytes`."""
        self._state = state
        self._version = version
        self._downloaded = self._total = size_bytes
        self._error_code = self._error_detail = None

    def _ensure_not_busy(self) -> None:
        with self._lock:
            if self._state in BUSY_STATES:
                raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=DETAIL_UPDATE_BUSY)

    # ─── recovery of a staged installer after a restart (spec B.2) ───────
    def _recover_staged_state(self) -> None:
        """
        Once per process: an idle service with a staged installer whose staged_manifest.json re-verifies, is newer
        than the installed version and has the signed size becomes `ready` again (the hash is checked at apply).
        Only where apply is supported, so a source run sharing the update dir (K4) never shows a frozen app's file.
        """
        with self._lock:
            if self._recovery_attempted or self._state != "idle":
                return
            self._recovery_attempted = True
        if not self._apply_supported_provider():
            return
        repo = self._repo()
        raw = repo.load_staged_manifest()
        if not raw:
            return
        try:
            manifest = self._verifier.verify(raw)
        except ManifestError as exc:
            logger.warning("Staged manifest failed verification, ignoring the staged installer: %s", exc)
            return
        installed = self._installed_version()
        if installed is None or not is_newer(manifest.version, installed):
            return
        staged = repo.staged_file(manifest.installer.filename)
        try:
            if not staged.is_file() or staged.stat().st_size != manifest.installer.size_bytes:
                return
        except OSError:
            return
        with self._lock:
            if self._state != "idle":
                return
            self._reset("ready", manifest.version, manifest.installer.size_bytes)
        logger.info("Recovered staged update v%s after restart", manifest.version)

    # ─── apply (spec B.3) ─────────────────────────────────────────────────
    def apply(self, version: str, actor: str, db: Optional[Session] = None) -> ApplyResponse:
        """
        Synchronous by design (K1): re-verify, R5 pre-update backup, promote, marker, launch Setup, and only then
        return 202. Maintenance mode stays on until Setup stops this process; on any failure it goes back to exactly
        what it was before (a startup R8/R10 maintenance is never lifted).
        """
        ensure_apply_supported(bool(self._apply_supported_provider()))
        self._recover_staged_state()
        self.evaluate_pending_update()  # consume a stale marker before writing a new one
        repo = self._repo()

        with self._lock:
            if self._state in BUSY_STATES:
                raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=DETAIL_UPDATE_BUSY)
            if self._state != "ready" or self._version != version:
                raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=DETAIL_NOT_READY)
            self._job_id += 1
            self._cancel_event = None
            self._state = "verifying"

        # 3. the staged manifest must still verify and still be an upgrade
        installed = self._installed_version()
        try:
            raw = repo.load_staged_manifest()
            if raw is None:
                raise ManifestError("no staged manifest")
            manifest = self._verifier.verify(raw)
            if manifest.version != version or installed is None or not is_newer(version, installed):
                raise ManifestError("staged manifest does not match the requested upgrade")
        except ManifestError as exc:
            logger.warning("Apply refused: %s", exc)
            self._set_failed("not_ready", DETAIL_NOT_READY)
            repo.append_history("apply_refused", version, str(exc))
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=DETAIL_NOT_READY)
        info = manifest.installer

        # 4. re-hash #1 of the staged installer
        staged = repo.staged_file(info.filename)
        if not _file_matches(staged, info.size_bytes, info.sha256):
            repo.remove_file(staged)
            self._set_failed("hash_mismatch", DETAIL_HASH_MISMATCH)
            repo.append_history("hash_mismatch", version, "staged installer changed before apply")
            self._audit(db, actor, "UPDATE_APPLY_FAILED", version, "hash_mismatch")
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=DETAIL_HASH_MISMATCH)

        # 5. R5 gate: verified pre-update backup, or nothing happens
        with self._lock:
            self._state = "backing_up"
        maintenance_before = _maintenance_snapshot()
        _enter_maintenance("update: pre-update backup and install")
        try:
            backup_name, backup_sha, backup_created_at = self._take_pre_update_backup(installed, version)
        except Exception as exc:  # R5: any failure (incl. low disk space) cancels the update, nothing is launched
            logger.exception("Pre-update backup failed; the update is cancelled")
            _restore_maintenance(maintenance_before)
            self._set_failed("backup_failed", DETAIL_BACKUP_FAILED)
            repo.append_history("backup_failed", version, type(exc).__name__)
            self._audit(db, actor, "UPDATE_APPLY_FAILED", version, "backup_failed")
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=DETAIL_BACKUP_FAILED)
        repo.append_history("backup_ok", version, backup_name)  # detail = file name only (Flutter RollbackCandidate)

        installer: Optional[Path] = None
        held: Optional[BinaryIO] = None
        marker_written = False
        try:
            # 6. keep the verified installer for a later rollback
            installer = repo.promote_installer(info.filename)
            # 7. marker for the post-update health check
            log_path = repo.install_log_path("install", version)
            now = self._utcnow()
            repo.save_pending(self._marker(
                "update", installed, version, backup_name, backup_sha, backup_created_at, info, log_path,
                raw.decode("utf-8"), None, now, actor,
            ))
            marker_written = True

            # 8. re-hash #2 just before launch (TOCTOU guard over the backup window). The handle stays open with
            # write/delete denied until Setup has started, so the verified bytes are the launched bytes.
            held = _hash_and_hold(installer, info.size_bytes, info.sha256)
            if held is None:
                repo.remove_file(installer)
                repo.clear_pending()
                _restore_maintenance(maintenance_before)
                self._set_failed("hash_mismatch", DETAIL_HASH_MISMATCH)
                repo.append_history("hash_mismatch", version, "installer changed during the pre-update backup")
                self._audit(db, actor, "UPDATE_APPLY_FAILED", version, "hash_mismatch")
                raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=DETAIL_HASH_MISMATCH)

            # 9. launch Setup, detached
            command = build_installer_command(installer, Path(self._app_dir_provider()), log_path)
            pid = self._launcher(command, installer.parent)
        except HTTPException:
            raise
        except Exception as exc:  # launch (or its preparation) failed: nothing was installed, undo the marker
            logger.exception("Could not launch the installer; the update is cancelled")
            if marker_written:
                repo.clear_pending()
            _restore_maintenance(maintenance_before)
            self._set_failed("launch_failed", DETAIL_LAUNCH_FAILED)
            repo.append_history("launch_failed", version, type(exc).__name__)
            self._audit(db, actor, "UPDATE_APPLY_FAILED", version, "launch_failed")
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=DETAIL_LAUNCH_FAILED)
        finally:
            _close_quietly(held)

        # 10. Setup now owns the process lifetime; maintenance mode stays on until it stops us.
        with self._lock:
            self._state = "installing"
        repo.append_history("install_launched", version, f"pid={pid}")
        self._audit(db, actor, "UPDATE_APPLY", version)
        return ApplyResponse(
            state="installing",
            backup_file=backup_name,
            backup_created_at=datetime.fromisoformat(backup_created_at),
        )

    def _marker(
        self,
        kind: str,
        from_version: Optional[str],
        to_version: str,
        backup_file: str,
        backup_sha256: Any,
        backup_created_at: Any,
        installer: InstallerInfo,
        log_path: Path,
        manifest_raw: str,
        aside_file: Optional[str],
        started_at: datetime,
        actor: str,
    ) -> Dict[str, Any]:
        """pending_update.json content (same layout for update and rollback), read by evaluate_pending_update."""
        return {
            "schema": MARKER_SCHEMA,
            "kind": kind,
            "from_version": from_version,
            "to_version": to_version,
            "app_dir": str(self._app_dir_provider()),
            "db_path": str(self._db_path),
            "backup_file": backup_file,
            "backup_sha256": backup_sha256,
            "backup_created_at": backup_created_at,
            "installer_file": installer.filename,
            "installer_sha256": installer.sha256,
            "install_log": str(log_path),
            "manifest_raw": manifest_raw,
            "aside_file": aside_file,
            "started_at": _utc_iso(started_at),
            "actor": actor,
        }

    def _take_pre_update_backup(self, installed: str, version: str) -> Tuple[str, str, str]:
        """R5: disk-space check, verified online backup (integrity_check inside), JSON sidecar. Raises on failure."""
        db_path = self._db_path
        if not db_path.is_file():
            raise FileNotFoundError(str(db_path))
        db_size = db_path.stat().st_size
        wal = Path(f"{db_path}-wal")
        if wal.is_file():
            db_size += wal.stat().st_size
        self._backups_dir.mkdir(parents=True, exist_ok=True)
        free = self._disk_free(self._backups_dir)
        needed = 2 * db_size + BACKUP_DISK_MARGIN_BYTES
        if free < needed:
            raise _LowDiskSpace(f"{free} bytes free, {needed} needed")

        now = self._utcnow()
        name = pre_update_backup_name(installed, version, now.astimezone(), self._backups_dir)  # local time, like other backups
        result = sqlite_online_backup(db_path, self._backups_dir / name)
        created_at = _utc_iso(now)
        sidecar = {
            "sha256": result.sha256,
            "size_bytes": result.size_bytes,
            "integrity": result.integrity,
            "created_at": created_at,
            "from_version": installed,
            "to_version": version,
        }
        self._repo().save_backup_sidecar(self._backups_dir / name, sidecar)
        return name, result.sha256, created_at

    # ─── post-update health check (spec B.4) ─────────────────────────────
    def evaluate_pending_update(self) -> Optional[Dict[str, Any]]:
        """
        Once per process: turn pending_update.json (written just before Setup ran) into last_result.json.
        Ignored (and kept) when apply is not supported here or the marker belongs to another install (K4).
        """
        with self._lock:
            if self._pending_evaluated:
                return None
            self._pending_evaluated = True
        if not self._apply_supported_provider():
            return None
        repo = self._repo()
        self._clear_resolved_rollback_block(repo)
        marker = repo.load_pending()
        if not marker:
            return None
        if not (
            same_file(marker.get("app_dir"), self._app_dir_provider())
            and same_file(marker.get("db_path"), self._db_path)
        ):
            logger.warning("pending_update.json belongs to another install (%s); leaving it untouched",
                           marker.get("app_dir"))
            return None

        installed = self._installed_version()
        try:
            quick = quick_check(self._db_path)
        except Exception as exc:  # a missing/unreadable DB is a failed check, not a crash
            logger.warning("Post-update quick_check failed: %s", exc)
            quick = f"error: {type(exc).__name__}"
        result, code, detail = classify_post_update(
            marker, installed, is_maintenance_mode(), maintenance_reason(), quick
        )
        last = dict(marker)
        last.update({
            "result": result,
            "code": code,
            "detail": detail,
            "finished_at": _utc_iso(self._utcnow()),
            "client_checked": False,
        })
        repo.save_last_result(last)  # written first: the marker is deleted only once the result is on disk
        repo.clear_pending()
        prefix = "rollback" if marker.get("kind") == "rollback" else "post_update"
        repo.append_history(f"{prefix}_{'ok' if result == 'success' else 'failed'}", marker.get("to_version"), code)
        return last

    def _clear_resolved_rollback_block(self, repo: UpdateFileRepository) -> None:
        """The block ends once the older version is installed (the manual rollback finished)."""
        block = repo.load_rollback_block()
        if not block or not same_file(block.get("db_path"), self._db_path):
            return
        if self._installed_version() == block.get("to_version"):
            repo.clear_rollback_block()
            repo.append_history("rollback_block_cleared", block.get("to_version"), block.get("reason"))

    def get_last_result(
        self, client_version: Optional[str] = None, can_acknowledge: bool = True
    ) -> LastResultResponse:
        """
        `can_acknowledge` (the caller holds system.update): only such a caller may persist the one-time client check
        (and its possible flip to client_version_mismatch). Everybody else just reads the stored result.
        """
        self.evaluate_pending_update()
        repo = self._repo()
        last = repo.load_last_result()
        if not last:
            return LastResultResponse(result="none")
        if (
            can_acknowledge
            and last.get("result") == "success"
            and last.get("kind") == "update"
            and not last.get("client_checked")
            and client_version
            and is_valid_version(client_version)
        ):
            last["client_checked"] = True
            if client_version != last.get("to_version"):
                last["result"] = "failed"
                last["code"] = "client_version_mismatch"
                last["detail"] = DETAIL_CLIENT_VERSION_MISMATCH.format(client=client_version, to=last.get("to_version"))
                repo.append_history("client_version_mismatch", last.get("to_version"), client_version)
            repo.save_last_result(last)
        try:
            return LastResultResponse(
                result=last.get("result") or "none",
                from_version=last.get("from_version"),
                to_version=last.get("to_version"),
                finished_at=last.get("finished_at"),
                detail=last.get("detail"),
                kind=last.get("kind"),
                backup_file=last.get("backup_file"),
                backup_created_at=last.get("backup_created_at"),
            )
        except ValidationError as exc:
            logger.warning("Ignoring malformed last_result.json: %s", exc)
            return LastResultResponse(result="none")

    # ─── rollback (spec B.5) ──────────────────────────────────────────────
    def rollback(
        self, backup_file: str, confirm: bool, actor: str, db: Optional[Session] = None
    ) -> RollbackResponse:
        """
        Checks 1-8 change nothing. Then: maintenance on, copy the live DB aside, re-verify a private copy of the
        pre-update backup and restore from it, marker, launch the kept previous installer. Synchronous (K1).
        """
        # 1.
        ensure_apply_supported(bool(self._apply_supported_provider()))
        if confirm is not True:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=DETAIL_ROLLBACK_CONFIRM_REQUIRED)
        # 2.
        self._ensure_not_busy()
        self.evaluate_pending_update()
        repo = self._repo()
        no_rollback = HTTPException(status_code=status.HTTP_409_CONFLICT, detail=DETAIL_NO_ROLLBACK_AVAILABLE)

        # 3. the last update, with a manifest whose signature still verifies (expiry/highest_seen ignored)
        last = repo.load_last_result()
        if not last or last.get("kind") != "update" or not isinstance(last.get("manifest_raw"), str):
            raise no_rollback
        try:
            manifest = self._verifier.verify(last["manifest_raw"].encode("utf-8"))
        except ManifestError as exc:
            logger.warning("Rollback refused, stored manifest does not verify: %s", exc)
            raise no_rollback
        # 4. only from exactly the version that update installed, with the manifest of that version
        installed = self._installed_version()
        if installed is None:
            raise no_rollback
        if installed == last.get("from_version"):
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=DETAIL_ALREADY_ON_PREVIOUS)
        if installed != last.get("to_version") or manifest.version != last.get("to_version"):
            raise no_rollback
        # 5.
        previous = manifest.previous
        if previous is None or previous.version != last.get("from_version"):
            raise no_rollback
        # 6.
        validate_backup_filename(backup_file, last.get("backup_file"))
        backups_dir = self._backups_dir.resolve()
        backup_path = (self._backups_dir / backup_file).resolve()
        if backup_path.parent != backups_dir:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT,
                                detail=update_rules.DETAIL_BACKUP_NOT_OF_LAST_UPDATE)
        # 7.
        expected_sha = last.get("backup_sha256")
        if not self._backup_is_sound(backup_path, expected_sha):
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=DETAIL_BACKUP_CORRUPT)
        # 8. the previous installer must already be on disk: no download inside this request (K1)
        prev_info = previous.installer
        prev_installer = repo.installer_path(prev_info.filename)
        if not _file_matches(prev_installer, prev_info.size_bytes, prev_info.sha256):
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=DETAIL_PREVIOUS_INSTALLER_MISSING)

        # ── changes start here ──
        # 9.
        self._claim(("idle", "failed", "ready"), "backing_up")
        with self._lock:
            self._version = previous.version
        maintenance_before = _maintenance_snapshot()
        _enter_maintenance("rollback in progress")
        if db is not None:
            db.close()  # release this request's connection before the restore
        self._dispose_engine()

        def fail(
            code: str, detail: str, http_status: int, history_event: str, exc: BaseException, audit: bool = True
        ) -> HTTPException:
            self._set_failed(code, detail)
            repo.append_history(history_event, previous.version, type(exc).__name__)
            if audit:  # never write into a DB whose state is uncertain (failed restore)
                self._audit_in_fresh_session(actor, "UPDATE_ROLLBACK_FAILED", previous.version, code)
            return HTTPException(status_code=http_status, detail=detail)

        # 10. copy the (failed) live DB aside; pre_restore_ keeps it protected (R9)
        now = self._utcnow()
        try:
            aside_name = pre_restore_aside_name(installed, now.astimezone(), self._backups_dir)
            sqlite_online_backup(self._db_path, self._backups_dir / aside_name)
        except Exception as exc:  # nothing was restored yet: the DB is unchanged, maintenance back as it was
            logger.exception("Could not copy the live database aside; rollback cancelled")
            _restore_maintenance(maintenance_before)
            raise fail("aside_failed", DETAIL_ASIDE_FAILED, 500, "rollback_aside_failed", exc)

        # 11. restore from a private, re-verified copy of the backup (closes the window after check 7)
        source = self._backups_dir / f".rollback_source_{uuid.uuid4().hex}.db"
        try:
            try:
                shutil.copyfile(backup_path, source)
                sound = self._backup_is_sound(source, expected_sha)
            except OSError as exc:
                logger.warning("Could not copy the backup for re-verification: %s", exc)
                sound = False
            if not sound:
                _restore_maintenance(maintenance_before)  # the live DB was not touched
                raise fail("backup_corrupt", DETAIL_BACKUP_CORRUPT, 422, "rollback_backup_changed",
                           RuntimeError("backup changed before restore"))
            try:
                # integrity_check of the restored DB runs inside (BackupVerificationError when it is not "ok")
                sqlite_online_backup(source, self._db_path, overwrite=True)
            except Exception as exc:  # the DB state is uncertain: stay read-only, also after a restart
                logger.exception("Restoring the pre-update backup failed")
                _enter_maintenance("rollback: restore failed")
                self._block_after_restore(repo, "restore_failed", installed, previous.version, backup_file,
                                          aside_name, prev_installer)
                raise fail("restore_failed", DETAIL_RESTORE_FAILED, 500, "restore_failed", exc, audit=False)
        finally:
            for leftover in (source, Path(f"{source}-journal")):
                repo.remove_file(leftover)

        # From here the DB holds the older schema: whatever happens, this (newer) binary must not write to it,
        # now or after a restart (rollback_blocked.json, read by rollback_pending_reason at startup).
        launch_failed_detail = DETAIL_ROLLBACK_LAUNCH_FAILED.format(path=str(prev_installer))
        try:
            # 12. marker
            log_path = repo.install_log_path("rollback", previous.version)
            repo.save_pending(self._marker(
                "rollback", installed, previous.version, backup_file, expected_sha, last.get("backup_created_at"),
                prev_info, log_path, last["manifest_raw"], aside_name, now, actor,
            ))
        except Exception as exc:  # restored DB, but no launch: stay read-only, point to the manual path
            logger.exception("Could not write the rollback marker")
            self._block_after_restore(repo, "marker_failed", installed, previous.version, backup_file,
                                      aside_name, prev_installer)
            raise fail("launch_failed", launch_failed_detail, 500, "rollback_launch_failed", exc)

        # 13. history + audit never decide the outcome
        try:
            repo.append_history("rollback_restored", previous.version, backup_file)
            self._audit_in_fresh_session(actor, "UPDATE_ROLLBACK", previous.version)
        except Exception:
            logger.exception("Could not record the rollback restore")

        # 14. re-hash the previous installer through a share-deny-write handle held until Setup has started, then
        # launch it. Maintenance stays on in every outcome.
        held = _hash_and_hold(prev_installer, prev_info.size_bytes, prev_info.sha256)
        if held is None:
            repo.remove_file(prev_installer)
            repo.clear_pending()
            self._block_after_restore(repo, "installer_tampered", installed, previous.version, backup_file,
                                      aside_name, prev_installer)
            raise fail("hash_mismatch", DETAIL_ROLLBACK_INSTALLER_TAMPERED, 500, "hash_mismatch",
                       RuntimeError("previous installer changed before launch"))
        try:
            command = build_installer_command(prev_installer, Path(self._app_dir_provider()), log_path)
            pid = self._launcher(command, prev_installer.parent)
        except Exception as exc:
            logger.exception("Could not launch the previous installer")
            repo.clear_pending()
            self._block_after_restore(repo, "launch_failed", installed, previous.version, backup_file,
                                      aside_name, prev_installer)
            raise fail("launch_failed", launch_failed_detail, 500, "rollback_launch_failed", exc)
        finally:
            _close_quietly(held)

        # 15.
        repo.clear_rollback_block()  # an earlier failed attempt is superseded by this launch
        with self._lock:
            self._state = "installing"
        repo.append_history("rollback_launched", previous.version, f"pid={pid}")
        return RollbackResponse(state="installing", restored_from=backup_file, aside_file=aside_name)

    def _block_after_restore(
        self,
        repo: UpdateFileRepository,
        reason: str,
        installed: str,
        previous_version: str,
        backup_file: str,
        aside_name: str,
        prev_installer: Path,
    ) -> None:
        """Persist 'restored DB, older installer not run' so a restart of this binary stays in maintenance mode."""
        try:
            repo.save_rollback_block({
                "schema": MARKER_SCHEMA,
                "reason": reason,
                "from_version": installed,
                "to_version": previous_version,
                "app_dir": str(self._app_dir_provider()),
                "db_path": str(self._db_path),
                "backup_file": backup_file,
                "aside_file": aside_name,
                "installer_path": str(prev_installer),
                "created_at": _utc_iso(self._utcnow()),
            })
        except OSError:
            logger.exception("Could not persist rollback_blocked.json")

    @staticmethod
    def _backup_is_sound(path: Path, expected_sha256: object) -> bool:
        try:
            if not path.is_file() or not isinstance(expected_sha256, str):
                return False
            if sha256_file(path) != expected_sha256:
                return False
            return check_integrity(path) == "ok"
        except Exception as exc:  # unreadable / not a database: treated as corrupt
            logger.warning("Backup %s failed verification: %s", path.name, exc)
            return False

    # ─── stage-local / USB (spec B.7) ─────────────────────────────────────
    def stage_local(
        self, manifest_path: str, installer_path: str, actor: str, db: Optional[Session] = None
    ) -> UpdateStatusResponse:
        """
        Offline update from files on this machine. Signature, schema, sha256/size and "newer than installed" are
        enforced; expiry and highest_seen are not (Decision 1). The staged copy is what gets hashed.
        """
        ensure_apply_supported(bool(self._apply_supported_provider()))
        self._ensure_not_busy()

        manifest_file = validate_local_file(manifest_path, ".json", update_rules.LOCAL_MANIFEST_MAX_BYTES)
        installer_file = validate_local_file(installer_path, ".exe", update_rules.LOCAL_INSTALLER_MAX_BYTES)
        try:
            raw = manifest_file.read_bytes()
        except OSError:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=update_rules.DETAIL_FILE_NOT_FOUND)
        try:
            manifest = self._verifier.verify(raw)
        except ManifestError as exc:
            logger.warning("Local manifest rejected: %s", exc)
            self._repo().append_history("stage_local_refused", None, str(exc))
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=DETAIL_INVALID_SIGNATURE)
        installed = self._installed_version()
        if installed is None or not is_newer(manifest.version, installed):
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=DETAIL_NOT_NEWER)

        prior = self._claim(("idle", "failed", "ready"), "verifying")
        with self._lock:
            self._version = manifest.version
            self._downloaded = 0
            self._total = manifest.installer.size_bytes
        repo = self._repo()
        info = manifest.installer
        part = repo.part_file(info.filename)
        final = repo.staged_file(info.filename)
        try:
            repo.ensure_staging_dir()
            repo.clear_staging()
            if not self._copy_verified(installer_file, part, info):
                repo.remove_file(part)
                raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                                    detail=DETAIL_LOCAL_HASH_MISMATCH)
            os.replace(part, final)
            repo.save_staged_manifest(raw)
        except HTTPException:
            self._restore_after_stage_failure(prior)
            repo.append_history("hash_mismatch", manifest.version, "local installer")
            self._audit(db, actor, "UPDATE_STAGE_LOCAL_FAILED", manifest.version, "hash_mismatch")
            raise
        except OSError as exc:
            logger.warning("Copying the local installer failed: %s", exc)
            repo.remove_file(part)
            repo.remove_file(final)
            self._restore_after_stage_failure(prior)
            repo.append_history("stage_local_failed", manifest.version, type(exc).__name__)
            self._audit(db, actor, "UPDATE_STAGE_LOCAL_FAILED", manifest.version, "copy_failed")
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=DETAIL_LOCAL_COPY_FAILED)

        self._remember_manifest(manifest, self._utcnow())
        self._record_highest_seen(repo, manifest)
        with self._lock:
            self._state = "ready"
            self._downloaded = self._total = info.size_bytes
        repo.append_history("staged_local", manifest.version, info.filename)
        self._audit(db, actor, "UPDATE_STAGE_LOCAL", manifest.version)
        return self._status_snapshot()

    @staticmethod
    def _copy_verified(source: Path, part: Path, info: InstallerInfo) -> bool:
        """Copy with the size cap, hashing exactly the bytes written to the staged copy."""
        digest = hashlib.sha256()
        written = 0
        with open(source, "rb") as src, open(part, "wb") as dst:
            while True:
                chunk = src.read(LOCAL_COPY_CHUNK_BYTES)
                if not chunk:
                    break
                written += len(chunk)
                if written > info.size_bytes:
                    return False
                dst.write(chunk)
                digest.update(chunk)
            dst.flush()
            os.fsync(dst.fileno())
        return written == info.size_bytes and digest.hexdigest() == info.sha256

    def _restore_after_stage_failure(self, prior: Dict[str, Any]) -> None:
        """Back to the prior state; staging was cleared, so a prior `ready` becomes `idle`."""
        with self._lock:
            self._job_id += 1
            if prior["state"] == "ready":
                self._reset("idle")
            else:
                self._state = prior["state"]
                self._version = prior["version"]
                self._downloaded = prior["downloaded"]
                self._total = prior["total"]
                self._error_code = prior["error_code"]
                self._error_detail = prior["error_detail"]

    # ─── audit ────────────────────────────────────────────────────────────
    def _audit_in_fresh_session(self, actor: str, action: str, version: str, reason: Optional[str] = None) -> None:
        """After a restore the request's session belongs to the replaced DB: write the entry into the restored one."""
        try:
            session = self._session_factory()
        except Exception:  # auditing must never change the outcome of the operation
            logger.exception("Could not open a session for the %s audit entry", action)
            return
        try:
            self._audit(session, actor, action, version, reason)
        finally:
            session.close()

    @staticmethod
    def _audit(
        db: Optional[Session], actor: str, action: str, version: str, reason: Optional[str] = None
    ) -> None:
        if db is None:
            return
        summary = f"{action} v{version}" + (f" ({reason})" if reason else "")
        try:
            AuditLogService(db).log_activity(
                entity_type="AppUpdate",
                entity_id=0,
                entity_code=version,
                action=action,
                performed_by=actor,
                changes_summary=summary,
            )
        except Exception:  # auditing must never change the outcome of the operation
            logger.exception("Could not write the audit log entry for %s v%s", action, version)
            try:
                db.rollback()
            except SQLAlchemyError:
                logger.exception("Rollback after a failed audit write failed")


# ─── Process-wide singleton (the state machine must be shared by all requests) ─

_service: Optional[UpdateService] = None
_service_lock = threading.Lock()


def get_update_service() -> UpdateService:
    global _service
    with _service_lock:
        created = _service is None
        if created:
            _service = UpdateService()
        service = _service
    if created:
        # B.4: the post-update health check runs once, right after the process-wide service exists.
        try:
            service.evaluate_pending_update()
        except Exception:  # never block the update routes; get_last_result() retries as a safety net
            logger.exception("Post-update evaluation failed")
            with service._lock:
                service._pending_evaluated = False
    return service
