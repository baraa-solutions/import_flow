"""
Production database safety helpers (docs/plans/update-system-plan.md section 0).

Kept dependency-free (stdlib only) so settings.py, database.py, scripts and the
installer tooling can all import it without pulling in FastAPI or SQLAlchemy.

- Runtime path anchoring (R11): in the frozen PyInstaller build every runtime file
  (.env, version.json, backups, the DB) lives next to the executable, never under
  ``sys._MEIPASS`` (a temp dir deleted on exit).
- Backup protection (R9): one shared ``is_protected_backup`` for every pruner.
- Verified online backups (A6, A9, A10): SQLite online backup API + integrity_check + sha256.
- Maintenance mode (R8, A11): a process-wide write block when startup upgrade fails.
"""
from __future__ import annotations

import hashlib
import logging
import os
import sqlite3
import sys
import threading
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Mapping, MutableMapping, Optional, Union

logger = logging.getLogger("db_safety")

PathLike = Union[str, Path]

REPO_ROOT = Path(__file__).resolve().parent.parent

# Backups that rollback depends on. No pruner may ever delete them (R9).
PRE_INSTALL_PREFIX = "pre_install_"
PRE_UPDATE_PREFIX = "pre_update_"
PRE_MIGRATION_PREFIX = "pre_migration_"
PRE_RESTORE_PREFIX = "pre_restore_"
PROTECTED_BACKUP_PREFIXES = (PRE_INSTALL_PREFIX, PRE_UPDATE_PREFIX, PRE_MIGRATION_PREFIX, PRE_RESTORE_PREFIX)
# Backup families owned by other tools; a pruner may only touch its own family.
DAILY_BACKUP_PREFIX = "daily_backup_"
AUTO_PRE_UPGRADE_PREFIX = "auto_pre_upgrade_"
PRODUCTION_SYNC_PREFIX = "psync_"
# Minimum number of newest files every pruner keeps in its own family (R9).
MIN_BACKUPS_KEPT = 7


# ----------------------------------------------------------------------------
# Runtime paths
# ----------------------------------------------------------------------------

def is_frozen_build() -> bool:
    """True inside the PyInstaller executable (the production laptop build). Not overridable by env."""
    return bool(getattr(sys, "frozen", False))


def app_base_dir() -> Path:
    """Directory holding runtime files: the executable's folder when frozen, the repo root otherwise."""
    if is_frozen_build():
        return Path(sys.executable).resolve().parent
    return REPO_ROOT


def env_file_path() -> Path:
    return app_base_dir() / ".env"


def version_file_path() -> Path:
    return app_base_dir() / "version.json"


# PyInstaller onefile bootloader state. A child that inherits these believes it is the second stage
# of OUR process and reuses our _MEI extraction folder, so a freshly installed backend.exe would run
# new Python code against the OLD bundled data files (alembic/versions) and skip its migrations.
_PYINSTALLER_ENV_PREFIXES = ("_PYI_", "_MEIPASS")
PYINSTALLER_RESET_ENV = "PYINSTALLER_RESET_ENVIRONMENT"


def reset_pyinstaller_environment(environ: Optional[MutableMapping[str, str]] = None) -> None:
    """
    In place (default ``os.environ``): drop every ``_PYI_*`` / ``_MEIPASS*`` key (case-insensitive, as
    Windows env names are) and set ``PYINSTALLER_RESET_ENVIRONMENT=1``, so any PyInstaller bootloader
    started from here (Setup -> frontend.exe -> backend.exe) runs as a fresh top-level process.
    The frozen backend calls this once at startup, before anything can spawn a child.
    """
    target = os.environ if environ is None else environ
    stale = [
        key for key in target
        if key.upper().startswith(_PYINSTALLER_ENV_PREFIXES) or key.upper() == PYINSTALLER_RESET_ENV
    ]
    for key in stale:
        del target[key]
    target[PYINSTALLER_RESET_ENV] = "1"


def clean_child_environment(base: Optional[Mapping[str, str]] = None) -> dict:
    """A cleaned copy of ``base`` (default ``os.environ``) for an explicit ``env=`` on a critical launch."""
    env = dict(os.environ if base is None else base)
    reset_pyinstaller_environment(env)
    return env


UNKNOWN_VERSION = "unknown"


def read_installed_version() -> str:
    """Installed version from version.json next to the executable (repo root in dev). Never raises:
    returns UNKNOWN_VERSION when the file is missing or malformed."""
    import json

    try:
        data = json.loads(version_file_path().read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        logger.warning("Cannot read installed version: %s", exc)
        return UNKNOWN_VERSION
    version = data.get("version") if isinstance(data, dict) else None
    return version.strip() if isinstance(version, str) and version.strip() else UNKNOWN_VERSION


def default_db_path() -> Path:
    return app_base_dir() / "sorour_logistics.db"


def backups_dir_for(db_path: PathLike) -> Path:
    """Backups always live next to the database they protect."""
    return Path(db_path).resolve().parent / "backups"


def same_file(a: object, b: object) -> bool:
    """True when both paths resolve to the same file (case-insensitive on Windows). False when either is
    empty/None or a path cannot be resolved: callers that must fail closed treat False as "different"."""
    if not a or not b:
        return False
    try:
        return os.path.normcase(str(Path(str(a)).resolve())) == os.path.normcase(str(Path(str(b)).resolve()))
    except (OSError, ValueError):
        return False


def unique_backup_name(stem: str, backups_dir: Optional[PathLike]) -> str:
    """``<stem>.db``, or ``<stem>_N.db`` (N = 1, 2, ...) when that name is already taken in ``backups_dir``."""
    name = f"{stem}.db"
    if backups_dir is None:
        return name
    counter = 1
    while (Path(backups_dir) / name).exists():
        name = f"{stem}_{counter}.db"
        counter += 1
    return name


# ----------------------------------------------------------------------------
# Backup protection
# ----------------------------------------------------------------------------

def is_protected_backup(path: PathLike) -> bool:
    """True for backups rollback depends on: protected prefix in the file name (as a prefix or a
    ``_<prefix>`` token) or inside a protected folder such as ``backups/pre_install_<ver>_<ts>/``."""
    p = Path(path)
    name = p.name.lower()
    for prefix in PROTECTED_BACKUP_PREFIXES:
        if name.startswith(prefix) or f"_{prefix}" in name:
            return True
    parent_name = p.parent.name.lower()
    return any(parent_name.startswith(prefix) for prefix in PROTECTED_BACKUP_PREFIXES)


def select_prunable(files: Iterable[Path], keep: int, sort_key=None) -> list:
    """Return the files a pruner may delete: never protected files, never the newest ``keep``
    (floored at MIN_BACKUPS_KEPT). ``files`` must already be limited to the pruner's own family."""
    keep = max(int(keep), MIN_BACKUPS_KEPT)
    candidates = [Path(f) for f in files if not is_protected_backup(f)]
    key = sort_key or (lambda f: (f.stat().st_mtime, f.name))
    candidates.sort(key=key, reverse=True)
    return candidates[keep:]


# ----------------------------------------------------------------------------
# Verified online backup
# ----------------------------------------------------------------------------

class BackupVerificationError(RuntimeError):
    """The backup copy failed PRAGMA integrity_check (or could not be verified)."""


@dataclass(frozen=True)
class BackupResult:
    path: Path
    sha256: str
    size_bytes: int
    integrity: str


def sha256_file(path: PathLike) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def check_integrity(db_path: PathLike) -> str:
    """Return the first row of PRAGMA integrity_check ('ok' when healthy). Never creates the file."""
    p = Path(db_path)
    if not p.exists():
        raise FileNotFoundError(str(p))
    conn = sqlite3.connect(str(p))
    try:
        row = conn.execute("PRAGMA integrity_check;").fetchone()
        return str(row[0]) if row else "no result"
    finally:
        conn.close()


def quick_check(db_path: PathLike) -> str:
    """First row of PRAGMA quick_check ('ok' when healthy). Never creates the file; FileNotFoundError if missing."""
    p = Path(db_path)
    if not p.exists():
        raise FileNotFoundError(str(p))
    conn = sqlite3.connect(f"{p.resolve().as_uri()}?mode=ro", uri=True)
    try:
        row = conn.execute("PRAGMA quick_check;").fetchone()
        return str(row[0]) if row else "no result"
    finally:
        conn.close()


def sqlite_online_backup(src: PathLike, dest: PathLike, *, overwrite: bool = False) -> BackupResult:
    """Copy ``src`` to ``dest`` with the SQLite online backup API (consistent even while the app
    writes in WAL mode), then verify ``dest`` with integrity_check and record its sha256.

    - ``overwrite=False`` (backups): refuses an existing ``dest``, stores the copy in rollback-journal
      mode so it is a single self-contained file, and deletes it again if verification fails.
    - ``overwrite=True`` (restore into an existing DB): the copy is one transaction on ``dest``, so a
      failure leaves ``dest`` unchanged; the caller must verify ``src`` first.
    """
    src_p = Path(src)
    dest_p = Path(dest)
    if not src_p.exists():
        raise FileNotFoundError(f"Source database not found: {src_p}")
    if dest_p.exists():
        if not overwrite:
            raise FileExistsError(f"Backup destination already exists: {dest_p}")
        if dest_p.resolve() == src_p.resolve():
            raise ValueError("Source and destination are the same database file.")
    dest_p.parent.mkdir(parents=True, exist_ok=True)

    created_new = not dest_p.exists()
    src_conn = sqlite3.connect(str(src_p), timeout=30)
    try:
        dst_conn = sqlite3.connect(str(dest_p), timeout=30)
        try:
            src_conn.backup(dst_conn)
            if created_new:
                dst_conn.execute("PRAGMA journal_mode=DELETE;")
            dst_conn.commit()
        finally:
            dst_conn.close()
    except Exception:
        if created_new:
            _unlink_quietly(dest_p)
        raise
    finally:
        src_conn.close()

    try:
        integrity = check_integrity(dest_p)
    except Exception as exc:
        if created_new:
            _unlink_quietly(dest_p)
        raise BackupVerificationError(f"Could not verify backup {dest_p.name}: {exc}") from exc
    if integrity != "ok":
        if created_new:
            _unlink_quietly(dest_p)
        raise BackupVerificationError(f"integrity_check failed for {dest_p.name}: {integrity}")

    return BackupResult(
        path=dest_p,
        sha256=sha256_file(dest_p),
        size_bytes=dest_p.stat().st_size,
        integrity=integrity,
    )


def _unlink_quietly(path: Path) -> None:
    for candidate in (path, Path(f"{path}-wal"), Path(f"{path}-shm"), Path(f"{path}-journal")):
        try:
            candidate.unlink(missing_ok=True)
        except OSError as exc:
            logger.warning("Could not remove failed backup file %s: %s", candidate, exc)


def checkpoint_wal(db_path: PathLike) -> bool:
    """Best-effort PRAGMA wal_checkpoint(PASSIVE) before a clean shutdown (A17)."""
    p = Path(db_path)
    if not p.exists():
        return False
    try:
        conn = sqlite3.connect(str(p), timeout=5)
        try:
            conn.execute("PRAGMA wal_checkpoint(PASSIVE);")
        finally:
            conn.close()
        return True
    except sqlite3.Error as exc:
        logger.warning("WAL checkpoint on shutdown failed: %s", exc)
        return False


# ----------------------------------------------------------------------------
# Maintenance mode (writes blocked after a failed startup upgrade)
# ----------------------------------------------------------------------------

MAINTENANCE_DETAIL = (
    "النظام في وضع الصيانة (قراءة فقط) بسبب فشل ترقية قاعدة البيانات عند التشغيل. "
    "لم يتم حفظ أي تعديل. برجاء التواصل مع الدعم الفني."
)
_READ_METHODS = frozenset({"GET", "HEAD", "OPTIONS"})
# Non-read requests still allowed while writes are blocked: session handling (no user/role writes),
# health, shutdown and the app-update flow (the way out of a failed upgrade).
_WRITE_ALLOWED_EXACT = frozenset({
    "/health",
    "/api/v1/health",
    "/shutdown",
    "/api/v1/shutdown",
    "/api/v1/auth/login",
    "/api/v1/auth/refresh",
    "/api/v1/auth/logout",
})
_WRITE_ALLOWED_PREFIXES = ("/api/v1/app-update/",)

_maintenance_lock = threading.Lock()
_maintenance_state = {"active": False, "reason": ""}


def enter_maintenance_mode(reason: str) -> None:
    with _maintenance_lock:
        _maintenance_state["active"] = True
        _maintenance_state["reason"] = reason
    logger.critical("MAINTENANCE MODE: database writes are blocked. Reason: %s", reason)


def clear_maintenance_mode() -> None:
    with _maintenance_lock:
        _maintenance_state["active"] = False
        _maintenance_state["reason"] = ""


def is_maintenance_mode() -> bool:
    return bool(_maintenance_state["active"])


def maintenance_reason() -> str:
    return str(_maintenance_state["reason"])


def is_request_allowed_in_maintenance(method: str, path: str) -> bool:
    if method.upper() in _READ_METHODS:
        return True
    if (path.rstrip("/") or "/") in _WRITE_ALLOWED_EXACT:
        return True
    return any(path.startswith(prefix) for prefix in _WRITE_ALLOWED_PREFIXES)
