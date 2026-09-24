"""
Safety guard for maintenance scripts that change a SQLite database
(docs/plans/update-system-plan.md section 0: A13-A15, R9, R12).

Every script that writes to a database goes through this module:

- ONE explicit target (``--db``, alias ``--target``). No candidate loops, no hard-coded real paths.
- ``--confirm`` (alias ``--i-understand-this-destroys-data``) before anything is changed.
- The target must exist (unless the script creates a brand-new file) and must not be in use:
  a lock probe fails while the backend (backend.exe / uvicorn) holds a connection to it.
- A verified online backup (SQLite backup API + integrity_check + sha256, ``utils.db_safety``) is taken
  next to the target first, under a protected name (R9); if it fails, the script aborts.

Importable functions of those scripts take ``confirm=False`` by default. Without confirmation they
refuse the live database (``DATABASE_PATH`` / the app database) and any database in use, so a stray
import or helper call can never touch production data.

Stdlib + ``utils.db_safety`` only, so any script can import it cheaply.
"""
from __future__ import annotations

import argparse
import os
import sqlite3
import sys
from datetime import datetime
from pathlib import Path
from typing import Callable, Iterable, List, Optional, Sequence, Union

ROOT_DIR = Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from utils.db_safety import (  # noqa: E402
    BackupResult,
    backups_dir_for,
    default_db_path,
    sqlite_online_backup,
)

PathLike = Union[str, Path]

# Protected prefixes (utils.db_safety.PROTECTED_BACKUP_PREFIXES): no pruner ever deletes these.
PRE_CHANGE_BACKUP_PREFIX = "pre_migration_"
PRE_RESTORE_BACKUP_PREFIX = "pre_restore_"

EXIT_REFUSED = 2


class UnsafeTargetError(RuntimeError):
    """The requested database change was refused before anything was written."""


# ----------------------------------------------------------------------------
# CLI helpers
# ----------------------------------------------------------------------------

def add_target_arguments(parser: argparse.ArgumentParser, *, target_help: str, with_backups_dir: bool = True) -> None:
    parser.add_argument(
        "--db", "--target", dest="db", default=None, metavar="PATH",
        help=f"{target_help} (required; the only database this run may change)",
    )
    parser.add_argument(
        "--confirm", "--i-understand-this-destroys-data", dest="confirm", action="store_true",
        help="Required: confirm that the target database will be changed (a verified backup is taken first)",
    )
    if with_backups_dir:
        parser.add_argument(
            "--backups-dir", dest="backups_dir", default=None, metavar="DIR",
            help="Where the pre-change backup goes (default: <target folder>/backups)",
        )


def run_guarded(action: Callable[[], object]) -> int:
    """Run a CLI action; a refused target prints the reason and returns EXIT_REFUSED."""
    try:
        result = action()
    except UnsafeTargetError as exc:
        print(f"[REFUSED] {exc}", file=sys.stderr)
        return EXIT_REFUSED
    if result is False:
        return 1
    if isinstance(result, int) and not isinstance(result, bool):
        return result
    return 0


def run_cli_action(
    args: argparse.Namespace,
    action: Callable[[Path, Optional[Path]], object],
    *,
    must_exist: bool = True,
) -> int:
    """Standard CLI flow: explicit --db, --confirm required, then ``action(target, backups_dir)``.

    The action must call the script function with ``confirm=True`` so the full guard (in-use check +
    verified backup) runs before the first write.
    """
    def _run():
        target = require_target(getattr(args, "db", None), must_exist=must_exist)
        if not getattr(args, "confirm", False):
            raise UnsafeTargetError(
                f"Refusing to change {target} without --confirm (alias --i-understand-this-destroys-data)."
            )
        backups_dir = getattr(args, "backups_dir", None)
        return action(target, Path(backups_dir) if backups_dir else None)

    return run_guarded(_run)


# ----------------------------------------------------------------------------
# Checks
# ----------------------------------------------------------------------------

def _same_file(a: Path, b: Path) -> bool:
    try:
        return a.resolve() == b.resolve()
    except OSError:
        return os.path.normcase(os.path.abspath(a)) == os.path.normcase(os.path.abspath(b))


# installer/importflow_setup.iss: AppId={{D37B4254-...} (the doubled brace is Inno escaping) and
# DefaultDirName={autopf}\Sorour Logistics. tests pin both against the .iss.
INSTALLER_APP_ID = "{D37B4254-8B6A-4A73-B5DF-719584C8A69E}"
INSTALLED_APP_FOLDER = "Sorour Logistics"
DB_FILE_NAME = "sorour_logistics.db"
_UNINSTALL_KEY = rf"Software\Microsoft\Windows\CurrentVersion\Uninstall\{INSTALLER_APP_ID}_is1"
_UNINSTALL_VALUES = ("Inno Setup: App Path", "InstallLocation")


def _registry_app_dirs() -> List[Path]:
    """Install folders recorded by Inno Setup (HKCU and HKLM, 64- and 32-bit registry views)."""
    if sys.platform != "win32":
        return []
    try:
        import winreg
    except ImportError:
        return []
    found: List[Path] = []
    for hive in (winreg.HKEY_CURRENT_USER, winreg.HKEY_LOCAL_MACHINE):
        for view in (winreg.KEY_WOW64_64KEY, winreg.KEY_WOW64_32KEY):
            try:
                key = winreg.OpenKey(hive, _UNINSTALL_KEY, 0, winreg.KEY_READ | view)
            except OSError:
                continue
            try:
                for value_name in _UNINSTALL_VALUES:
                    try:
                        value, _kind = winreg.QueryValueEx(key, value_name)
                    except OSError:
                        continue
                    if isinstance(value, str) and value.strip():
                        found.append(Path(value.strip().strip('"')))
            finally:
                winreg.CloseKey(key)
    return found


def _default_install_dirs() -> List[Path]:
    """{autopf} for per-user ({userpf} = %LOCALAPPDATA%\\Programs) and admin installs (both views)."""
    dirs: List[Path] = []
    local_app_data = os.getenv("LOCALAPPDATA")
    if local_app_data:
        dirs.append(Path(local_app_data) / "Programs" / INSTALLED_APP_FOLDER)
    for env_name in ("ProgramFiles", "ProgramW6432", "ProgramFiles(x86)"):
        base = os.getenv(env_name)
        if base:
            dirs.append(Path(base) / INSTALLED_APP_FOLDER)
    return dirs


def installed_app_db_paths() -> List[Path]:
    """Databases of an installed (laptop) copy of the app: registry App Path + the default install folders."""
    paths: List[Path] = []
    for folder in _registry_app_dirs() + _default_install_dirs():
        candidate = folder / DB_FILE_NAME
        if not any(_same_file(candidate, known) for known in paths):
            paths.append(candidate)
    return paths


def live_db_paths() -> List[Path]:
    """Databases a script must never change without --confirm: the configured app database and the
    installed production copies."""
    paths = [default_db_path()]
    env_path = os.getenv("DATABASE_PATH")
    if env_path:
        paths.append(Path(env_path))
    database_module = sys.modules.get("database.database")
    configured = getattr(database_module, "DB_PATH", None) if database_module else None
    if configured:
        paths.append(Path(configured))
    paths.extend(installed_app_db_paths())
    return paths


def is_live_db(db_path: PathLike) -> bool:
    target = Path(db_path)
    return any(_same_file(target, live) for live in live_db_paths())


def is_db_in_use(db_path: PathLike) -> bool:
    """True when another connection holds the database (the running backend keeps WAL connections open).

    Probe: an EXCLUSIVE-locking-mode write transaction with a zero busy timeout. In WAL mode every open
    connection keeps a shared lock, so the probe fails while the backend runs even when it is idle.
    The probe rolls back and never changes the file.
    """
    path = Path(db_path)
    if not path.exists():
        return False
    try:
        conn = sqlite3.connect(f"file:{path.as_posix()}?mode=rw", uri=True, timeout=0, isolation_level=None)
    except sqlite3.Error as exc:
        raise UnsafeTargetError(f"Cannot open database {path}: {exc}") from exc
    try:
        conn.execute("PRAGMA locking_mode=EXCLUSIVE;")
        conn.execute("BEGIN EXCLUSIVE;")
        conn.execute("SELECT count(*) FROM sqlite_master;").fetchone()
        conn.execute("ROLLBACK;")
        return False
    except sqlite3.OperationalError as exc:
        message = str(exc).lower()
        if "locked" in message or "busy" in message:
            return True
        raise UnsafeTargetError(f"Cannot probe database {path}: {exc}") from exc
    except sqlite3.DatabaseError as exc:
        raise UnsafeTargetError(f"{path} is not a valid SQLite database: {exc}") from exc
    finally:
        conn.close()


def require_target(db_path: Optional[PathLike], *, must_exist: bool = True) -> Path:
    if db_path is None or str(db_path).strip() == "":
        raise UnsafeTargetError("No target database given. Pass exactly one explicit --db <path>.")
    target = Path(db_path)
    if must_exist and not target.is_file():
        raise UnsafeTargetError(f"Target database does not exist: {target}")
    return target


def take_verified_backup(
    db_path: PathLike,
    *,
    tag: str,
    prefix: str = PRE_CHANGE_BACKUP_PREFIX,
    backups_dir: Optional[PathLike] = None,
) -> BackupResult:
    """Verified online backup of ``db_path`` under a protected name. Raises UnsafeTargetError on failure."""
    source = Path(db_path)
    folder = Path(backups_dir) if backups_dir else backups_dir_for(source)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    safe_tag = "".join(ch if ch.isalnum() or ch in "-_" else "_" for ch in tag) or "script"
    base = f"{prefix}{safe_tag}_{source.stem}_{stamp}"
    dest = folder / f"{base}.db"
    counter = 1
    while dest.exists():
        dest = folder / f"{base}_{counter}.db"
        counter += 1
    try:
        result = sqlite_online_backup(source, dest)
    except Exception as exc:  # any failure (I/O, sqlite, integrity) aborts the change
        raise UnsafeTargetError(f"Backup of {source} failed, nothing was changed: {exc}") from exc
    print(f"[BACKUP] Verified backup: {result.path} ({result.size_bytes:,} bytes, sha256 {result.sha256[:16]}...)")
    return result


# ----------------------------------------------------------------------------
# Guards
# ----------------------------------------------------------------------------

def guard_destructive_target(
    db_path: Optional[PathLike],
    *,
    confirm: bool,
    tag: str,
    must_exist: bool = True,
    backup_prefix: str = PRE_CHANGE_BACKUP_PREFIX,
    backups_dir: Optional[PathLike] = None,
    forbid: Iterable[PathLike] = (),
) -> Optional[BackupResult]:
    """Full CLI guard. Returns the backup (None when the target does not exist yet)."""
    target = require_target(db_path, must_exist=must_exist)
    if not confirm:
        raise UnsafeTargetError(
            f"Refusing to change {target} without --confirm (alias --i-understand-this-destroys-data)."
        )
    for other in forbid:
        if other is not None and _same_file(target, Path(other)):
            raise UnsafeTargetError(f"Target {target} is the same file as the source database.")
    if not target.exists():
        return None
    _refuse_if_in_use(target)
    backup = take_verified_backup(target, tag=tag, prefix=backup_prefix, backups_dir=backups_dir)
    # Check-then-write race: the backup can take a while, so probe again right before the caller's
    # first write. Holding our own exclusive lock through the write is not possible because every
    # script (and the online backup) opens its own connection, which that lock would block.
    _refuse_if_in_use(target, after_backup=backup)
    return backup


def _refuse_if_in_use(target: Path, after_backup: Optional[BackupResult] = None) -> None:
    if not is_db_in_use(target):
        return
    note = f" Nothing was changed; the backup {after_backup.path} was kept." if after_backup else ""
    raise UnsafeTargetError(
        f"Target {target} is in use (backend.exe / uvicorn holds it). Close the application and retry.{note}"
    )


def guard_programmatic_target(db_path: Optional[PathLike], *, must_exist: bool = True) -> Path:
    """Guard for unconfirmed calls of an importable helper: never the live database, never one in use."""
    target = require_target(db_path, must_exist=must_exist)
    if is_live_db(target):
        raise UnsafeTargetError(
            f"Refusing to change the live database {target} without confirm=True "
            "(which also takes a verified backup first)."
        )
    if target.exists() and is_db_in_use(target):
        raise UnsafeTargetError(f"Target {target} is in use by another process.")
    return target


def guard_target(
    db_path: Optional[PathLike],
    *,
    confirm: bool,
    tag: str,
    must_exist: bool = True,
    backup_prefix: str = PRE_CHANGE_BACKUP_PREFIX,
    backups_dir: Optional[PathLike] = None,
    forbid: Sequence[PathLike] = (),
) -> Optional[BackupResult]:
    """confirm=True: full guard with verified backup. confirm=False: programmatic guard (no live DB)."""
    if confirm:
        return guard_destructive_target(
            db_path, confirm=True, tag=tag, must_exist=must_exist,
            backup_prefix=backup_prefix, backups_dir=backups_dir, forbid=forbid,
        )
    target = guard_programmatic_target(db_path, must_exist=must_exist)
    for other in forbid:
        if other is not None and _same_file(target, Path(other)):
            raise UnsafeTargetError(f"Target {target} is the same file as the source database.")
    return None
