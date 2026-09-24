"""
Application update service (plan §4.2, §4.5 steps 1-3, §4.6, §4.8, §4.9).

- ManifestVerifier: Ed25519 over the exact UTF-8 bytes of the envelope's `signed` string, then the client rules
  (relative installer path, strict versions, sha256/size shape).
- UpdateService: check (1 h cache in memory + last_manifest.json on disk, re-verified on load), download
  (background thread, streams to staging/<file>.part hashing as it goes, aborts on size overflow, deletes on
  mismatch), cancel, status, history. A single lock guards the state machine.

No route accepts a URL: the manifest URL is the code constant (or an allow-listed https override) and the
installer URL is BASE_URL + the signed relative path.
"""
import base64
import binascii
import hashlib
import json
import logging
import os
import threading
import time
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Callable, Dict, List, Optional, Tuple

import httpx
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
from fastapi import HTTPException, status
from pydantic import ValidationError
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from modules.audit_logs.service import AuditLogService
from utils.db_safety import version_file_path  # frozen: next to backend.exe; source run: repo root
from modules.app_update.repository import UpdateFileRepository, default_update_data_dir
from modules.app_update.schemas import (
    LastResultResponse,
    ReleaseNotes,
    UpdateCheckResponse,
    UpdateHistoryItem,
    UpdateHistoryResponse,
    UpdateStatusResponse,
)
from modules.app_update.validators import (
    DETAIL_DOWNLOAD_FAILED,
    DETAIL_DOWNLOAD_IN_PROGRESS,
    DETAIL_HASH_MISMATCH,
    DETAIL_NO_DOWNLOAD_RUNNING,
    DETAIL_NO_UPDATE_FOR_VERSION,
    DETAIL_NOT_IMPLEMENTED,
    DETAIL_SERVER_UNREACHABLE,
    DETAIL_SIZE_EXCEEDED,
    HTTP_TIMEOUT_SECONDS,
    MANIFEST_APP,
    MANIFEST_FILENAME,
    MANIFEST_MAX_BYTES,
    MANIFEST_SCHEMA,
    ManifestError,
    build_installer_url,
    ensure_apply_supported,
    env_value,
    installer_filename,
    is_apply_supported,
    is_newer,
    is_valid_version,
    parse_version,
    resolve_base_url,
    validate_installer_path,
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
    "k2026a": "REPLACE_WITH_REAL_ED25519_PUBLIC_KEY_BASE64",
}

CACHE_TTL = timedelta(hours=1)
FORCE_MIN_INTERVAL_SECONDS = 60.0  # at most one network check per minute, even with ?force=true
UNKNOWN_VERSION = "unknown"
DOWNLOAD_CHUNK_BYTES = 64 * 1024
BUSY_STATES = frozenset({"downloading", "verifying", "backing_up", "installing"})
DOWNLOAD_STATES = frozenset({"downloading", "verifying"})


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


def _start_daemon_thread(fn: Callable[[], None]) -> None:
    threading.Thread(target=fn, name="app-update-download", daemon=True).start()


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
        try:
            repo.save_highest_seen(manifest.version, manifest.build_number)
        except OSError as exc:
            logger.warning("Could not persist highest_seen.json: %s", exc)
        self._remember_manifest(manifest, self._utcnow())
        return manifest

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
        with self._lock:
            if self._state in BUSY_STATES:
                raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=DETAIL_DOWNLOAD_IN_PROGRESS)
            if (
                self._state == "ready"
                and self._version == version
                and repo.staged_file(manifest.installer.filename).is_file()
            ):
                return self.get_status()
            self._job_id += 1
            job_id = self._job_id
            cancel_event = threading.Event()
            self._cancel_event = cancel_event
            self._state = "downloading"
            self._version = version
            self._downloaded = 0
            self._total = manifest.installer.size_bytes
            self._error_code = None
            self._error_detail = None

        repo.append_history("download_started", version, f"by {actor}")
        self._audit(db, actor, "UPDATE_DOWNLOAD", version)
        self._run_in_background(lambda: self._download_worker(job_id, cancel_event, manifest, base_url))
        return self.get_status()

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

    def _download_worker(
        self, job_id: int, cancel_event: threading.Event, manifest: VerifiedManifest, base_url: str
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
            digest = hashlib.sha256()
            received = 0
            with self._client() as client, client.stream("GET", url) as resp:
                if resp.status_code != 200:
                    raise _FetchError(f"installer HTTP {resp.status_code}")
                declared = resp.headers.get("content-length")
                if declared and declared.isdigit() and int(declared) > installer.size_bytes:
                    raise _SizeExceeded()
                with open(part, "wb") as fh:
                    for chunk in resp.iter_bytes(DOWNLOAD_CHUNK_BYTES):
                        if cancel_event.is_set():
                            raise _Cancelled()
                        received += len(chunk)
                        if received > installer.size_bytes:
                            raise _SizeExceeded()
                        fh.write(chunk)
                        digest.update(chunk)
                        self._set_progress(job_id, cancel_event, received)

            with self._lock:
                if not self._is_current(job_id, cancel_event):
                    raise _Cancelled()
                self._state = "verifying"
            if received != installer.size_bytes or digest.hexdigest() != installer.sha256:
                raise _HashMismatch()
            os.replace(part, final)
            with self._lock:
                if not self._is_current(job_id, cancel_event):
                    repo.remove_file(final)
                    return
                self._state = "ready"
            repo.append_history("download_verified", version, installer.sha256)
        except _Cancelled:
            repo.remove_file(part)
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
            logger.warning("Update download failed: %s", exc)
            self._fail(job_id, cancel_event, "download_failed", DETAIL_DOWNLOAD_FAILED)
            repo.append_history("download_failed", version, f"{type(exc).__name__}: {exc}")
        except Exception as exc:  # the worker thread must always leave a terminal state
            repo.remove_file(part)
            logger.exception("Unexpected error in update download worker")
            self._fail(job_id, cancel_event, "download_failed", DETAIL_DOWNLOAD_FAILED)
            repo.append_history("download_failed", version, f"{type(exc).__name__}: {exc}")

    # ─── cancel ───────────────────────────────────────────────────────────
    def cancel(self, actor: str) -> UpdateStatusResponse:
        with self._lock:
            if self._state not in DOWNLOAD_STATES or self._cancel_event is None:
                raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=DETAIL_NO_DOWNLOAD_RUNNING)
            self._cancel_event.set()
            version = self._version
            self._job_id += 1
            self._state = "idle"
            self._version = None
            self._downloaded = 0
            self._total = 0
            self._error_code = None
            self._error_detail = None
        self._repo().append_history("download_cancelled", version, f"by {actor}")
        return self.get_status()

    # ─── last result / history ────────────────────────────────────────────
    def get_last_result(self) -> LastResultResponse:
        # Post-update result tracking (pending_update.json) arrives with /apply in a later phase.
        return LastResultResponse(result="none")

    def get_history(self, limit: int) -> UpdateHistoryResponse:
        items: List[UpdateHistoryItem] = []
        for entry in self._repo().read_history(limit):
            try:
                items.append(UpdateHistoryItem(**{k: entry.get(k) for k in ("ts", "event", "version", "detail")}))
            except ValidationError as exc:
                logger.warning("Skipping malformed update history entry: %s", exc)
        return UpdateHistoryResponse(items=items)

    # ─── later phases (contract only) ─────────────────────────────────────
    def apply(self, version: str, actor: str) -> None:
        raise HTTPException(status_code=status.HTTP_501_NOT_IMPLEMENTED, detail=DETAIL_NOT_IMPLEMENTED)

    def stage_local(self, manifest_path: str, installer_path: str, actor: str) -> None:
        raise HTTPException(status_code=status.HTTP_501_NOT_IMPLEMENTED, detail=DETAIL_NOT_IMPLEMENTED)

    def rollback(self, backup_file: str, actor: str) -> None:
        raise HTTPException(status_code=status.HTTP_501_NOT_IMPLEMENTED, detail=DETAIL_NOT_IMPLEMENTED)

    # ─── audit ────────────────────────────────────────────────────────────
    @staticmethod
    def _audit(db: Optional[Session], actor: str, action: str, version: str) -> None:
        if db is None:
            return
        try:
            AuditLogService(db).log_activity(
                entity_type="AppUpdate",
                entity_id=0,
                entity_code=version,
                action=action,
                performed_by=actor,
                changes_summary=f"{action} v{version}",
            )
        except SQLAlchemyError:
            db.rollback()
            logger.exception("Could not write the audit log entry for %s v%s", action, version)


# ─── Process-wide singleton (the state machine must be shared by all requests) ─

_service: Optional[UpdateService] = None
_service_lock = threading.Lock()


def get_update_service() -> UpdateService:
    global _service
    with _service_lock:
        if _service is None:
            _service = UpdateService()
        return _service
