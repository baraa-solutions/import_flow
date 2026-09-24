"""
File storage for the updater (the "database" of this module).

Layout under the update data dir:
  last_manifest.json      raw signed envelope of the last verified manifest + fetched_at (re-verified on load)
  highest_seen.json       highest verified (version, build_number): older manifests are refused (replay/freeze)
  update_history.jsonl    one JSON event per line (survives a DB restore), capped at the newest 1000 lines
  staging/                installer downloads (<file>.part while streaming, <file> once verified)
  staging/staged_manifest.json  raw signed envelope that verified the staged installer
  installers/             verified installers kept for rollback (newest 3 by version)
  logs/                   Inno Setup logs: install_<version>.log, rollback_<version>.log
  pending_update.json     marker written just before the installer is launched (evaluated after restart)
  last_result.json        outcome of the last update / rollback (post-update health check)
  rollback_blocked.json   the DB was restored to an older version but the older installer did not run: the newer
                          binary must stay in maintenance mode at startup (read by rollback_pending_reason)

All JSON writes are atomic (temp file + os.replace).
"""
import json
import logging
import os
import re
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple, Union

from modules.app_update.validators import installer_sort_key
from utils.db_safety import read_installed_version

logger = logging.getLogger(__name__)

LAST_MANIFEST_FILE = "last_manifest.json"
HIGHEST_SEEN_FILE = "highest_seen.json"
HISTORY_FILE = "update_history.jsonl"
HISTORY_MAX_LINES = 1000
HISTORY_DETAIL_MAX_CHARS = 500
_VERSION_RE = re.compile(r"\d+\.\d+\.\d+\Z")
STAGING_DIR = "staging"
PART_SUFFIX = ".part"
STAGED_MANIFEST_FILE = "staged_manifest.json"
INSTALLERS_DIR = "installers"
LOGS_DIR = "logs"
PENDING_FILE = "pending_update.json"
LAST_RESULT_FILE = "last_result.json"
ROLLBACK_BLOCK_FILE = "rollback_blocked.json"
INSTALLERS_KEPT = 3


def default_update_data_dir() -> Path:
    """UPDATE_DATA_DIR env, else %LOCALAPPDATA%\\SorourLogistics\\updates."""
    override = os.environ.get("UPDATE_DATA_DIR", "").strip()
    if override:
        return Path(override)
    local_app_data = os.environ.get("LOCALAPPDATA", "").strip()
    base = Path(local_app_data) if local_app_data else Path.home() / "AppData" / "Local"
    return base / "SorourLogistics" / "updates"


class UpdateFileRepository:
    def __init__(self, data_dir: Path):
        self.data_dir = Path(data_dir)

    # ─── paths ────────────────────────────────────────────────────────────
    @property
    def staging_dir(self) -> Path:
        return self.data_dir / STAGING_DIR

    def staged_file(self, filename: str) -> Path:
        return self.staging_dir / filename

    def part_file(self, filename: str) -> Path:
        return self.staging_dir / (filename + PART_SUFFIX)

    def ensure_staging_dir(self) -> Path:
        self.staging_dir.mkdir(parents=True, exist_ok=True)
        return self.staging_dir

    # ─── last manifest ────────────────────────────────────────────────────
    def save_last_manifest(self, raw_manifest: bytes, fetched_at: datetime) -> None:
        payload = {
            "fetched_at": fetched_at.isoformat(),
            "raw": raw_manifest.decode("utf-8"),
        }
        self._atomic_write_text(self.data_dir / LAST_MANIFEST_FILE, json.dumps(payload, ensure_ascii=False))

    def load_last_manifest(self) -> Optional[Dict[str, Any]]:
        """Returns {'raw': bytes, 'fetched_at': datetime} or None. The caller must re-verify 'raw'."""
        path = self.data_dir / LAST_MANIFEST_FILE
        if not path.is_file():
            return None
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
            fetched_at = datetime.fromisoformat(payload["fetched_at"])
            if fetched_at.tzinfo is None:
                fetched_at = fetched_at.replace(tzinfo=timezone.utc)
            return {"raw": payload["raw"].encode("utf-8"), "fetched_at": fetched_at}
        except (OSError, ValueError, KeyError, TypeError, AttributeError) as exc:
            logger.warning("Ignoring unreadable %s: %s", path, exc)
            return None

    # ─── highest verified manifest (anti-rollback / anti-freeze) ──────────
    def save_highest_seen(self, version: str, build_number: int) -> None:
        """Monotonic: never lowers the stored (version, build_number)."""
        current = self.load_highest_seen()
        candidate = (tuple(int(p) for p in version.split(".")), build_number)
        if current and candidate <= (tuple(int(p) for p in current[0].split(".")), current[1]):
            return
        payload = {
            "version": version,
            "build_number": build_number,
            "recorded_at": datetime.now(timezone.utc).isoformat(),
        }
        self._atomic_write_text(self.data_dir / HIGHEST_SEEN_FILE, json.dumps(payload))

    def load_highest_seen(self) -> Optional[Tuple[str, int]]:
        path = self.data_dir / HIGHEST_SEEN_FILE
        if not path.is_file():
            return None
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
            version, build = payload["version"], payload["build_number"]
            if not isinstance(version, str) or not _VERSION_RE.fullmatch(version):
                raise ValueError("bad version")
            if isinstance(build, bool) or not isinstance(build, int) or build < 0:
                raise ValueError("bad build_number")
            return version, build
        except (OSError, ValueError, KeyError, TypeError) as exc:
            logger.warning("Ignoring unreadable %s: %s", path, exc)
            return None

    # ─── history ──────────────────────────────────────────────────────────
    def append_history(self, event: str, version: Optional[str] = None, detail: Optional[str] = None) -> None:
        entry = {
            "ts": datetime.now(timezone.utc).isoformat(),
            "event": event,
            "version": version,
            "detail": (detail or None) and detail[:HISTORY_DETAIL_MAX_CHARS],
        }
        path = self.data_dir / HISTORY_FILE
        try:
            self.data_dir.mkdir(parents=True, exist_ok=True)
            with open(path, "a", encoding="utf-8") as fh:
                fh.write(json.dumps(entry, ensure_ascii=False) + "\n")
            self._trim_history(path)
        except OSError as exc:
            logger.warning("Could not append update history (%s): %s", event, exc)

    def _trim_history(self, path: Path) -> None:
        """Keep the newest HISTORY_MAX_LINES lines (rewritten atomically once the file grows past the cap)."""
        with open(path, "r", encoding="utf-8") as fh:
            lines = fh.readlines()
        if len(lines) <= HISTORY_MAX_LINES:
            return
        self._atomic_write_text(path, "".join(lines[-HISTORY_MAX_LINES:]))

    def read_history(self, limit: int) -> List[Dict[str, Any]]:
        """Newest first, at most `limit` entries; malformed lines are skipped."""
        path = self.data_dir / HISTORY_FILE
        if not path.is_file():
            return []
        items: List[Dict[str, Any]] = []
        with open(path, "r", encoding="utf-8") as fh:
            lines = fh.readlines()
        for line in reversed(lines):
            if len(items) >= limit:
                break
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            if isinstance(entry, dict) and isinstance(entry.get("event"), str):
                items.append(entry)
        return items

    # ─── staging files ────────────────────────────────────────────────────
    def remove_file(self, path: Path) -> None:
        try:
            path.unlink(missing_ok=True)
        except OSError as exc:
            logger.warning("Could not delete %s: %s", path, exc)

    def clear_staging(self) -> None:
        """Delete every file in staging/ (stale .part files and older installers)."""
        if not self.staging_dir.is_dir():
            return
        for child in self.staging_dir.iterdir():
            if child.is_file():
                self.remove_file(child)

    # ─── staged manifest (the envelope that verified staging/<file>) ──────
    def save_staged_manifest(self, raw_manifest: bytes) -> None:
        self._atomic_write_text(self.staging_dir / STAGED_MANIFEST_FILE, raw_manifest.decode("utf-8"))

    def load_staged_manifest(self) -> Optional[bytes]:
        """Raw envelope bytes or None. The caller must re-verify them."""
        path = self.staging_dir / STAGED_MANIFEST_FILE
        if not path.is_file():
            return None
        try:
            return path.read_bytes()
        except OSError as exc:
            logger.warning("Ignoring unreadable %s: %s", path, exc)
            return None

    # ─── pending marker / last result ─────────────────────────────────────
    def save_pending(self, marker: Dict[str, Any]) -> None:
        self._atomic_write_text(self.data_dir / PENDING_FILE, json.dumps(marker, ensure_ascii=False, indent=1))

    def load_pending(self) -> Optional[Dict[str, Any]]:
        return self._load_json_object(self.data_dir / PENDING_FILE)

    def clear_pending(self) -> None:
        self.remove_file(self.data_dir / PENDING_FILE)

    def save_last_result(self, result: Dict[str, Any]) -> None:
        self._atomic_write_text(self.data_dir / LAST_RESULT_FILE, json.dumps(result, ensure_ascii=False, indent=1))

    def load_last_result(self) -> Optional[Dict[str, Any]]:
        return self._load_json_object(self.data_dir / LAST_RESULT_FILE)

    # ─── rollback block (restored DB, previous installer not run) ────────
    def save_rollback_block(self, block: Dict[str, Any]) -> None:
        self._atomic_write_text(self.data_dir / ROLLBACK_BLOCK_FILE, json.dumps(block, ensure_ascii=False, indent=1))

    def load_rollback_block(self) -> Optional[Dict[str, Any]]:
        return self._load_json_object(self.data_dir / ROLLBACK_BLOCK_FILE)

    def clear_rollback_block(self) -> None:
        self.remove_file(self.data_dir / ROLLBACK_BLOCK_FILE)

    # ─── installers kept for rollback ─────────────────────────────────────
    @property
    def installers_dir(self) -> Path:
        return self.data_dir / INSTALLERS_DIR

    def installer_path(self, filename: str) -> Path:
        return self.installers_dir / filename

    def installer_part_file(self, filename: str) -> Path:
        return self.installers_dir / (filename + PART_SUFFIX)

    def ensure_installers_dir(self) -> Path:
        self.installers_dir.mkdir(parents=True, exist_ok=True)
        return self.installers_dir

    def promote_installer(self, filename: str) -> Path:
        """Move the verified staging/<file> into installers/ (same volume: os.replace), then prune."""
        target = self.ensure_installers_dir() / filename
        os.replace(self.staged_file(filename), target)
        self.prune_installers(keep=INSTALLERS_KEPT)
        return target

    def prune_installers(self, keep: int = INSTALLERS_KEPT) -> List[Path]:
        """Keep the newest `keep` installers by version. Files not named like our installers are never touched."""
        if not self.installers_dir.is_dir():
            return []
        ours = []
        for child in self.installers_dir.iterdir():
            key = installer_sort_key(child.name)
            if key is not None and child.is_file():
                ours.append((key, child))
        ours.sort(key=lambda item: item[0], reverse=True)
        removed = [path for _, path in ours[max(keep, 0):]]
        for path in removed:
            self.remove_file(path)
        return removed

    # ─── installer logs ───────────────────────────────────────────────────
    def install_log_path(self, kind: str, version: str) -> Path:
        """logs/<kind>_<version>.log; the folder is created here because Inno's /LOG does not create folders."""
        if kind not in ("install", "rollback") or not _VERSION_RE.fullmatch(version or ""):
            raise ValueError("invalid install log kind or version")
        logs = self.data_dir / LOGS_DIR
        logs.mkdir(parents=True, exist_ok=True)
        return logs / f"{kind}_{version}.log"

    # ─── internals ────────────────────────────────────────────────────────
    def _load_json_object(self, path: Path) -> Optional[Dict[str, Any]]:
        if not path.is_file():
            return None
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError) as exc:
            logger.warning("Ignoring unreadable %s: %s", path, exc)
            return None
        if not isinstance(payload, dict):
            logger.warning("Ignoring %s: not a JSON object", path)
            return None
        return payload

    def _atomic_write_text(self, path: Path, text: str) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        fd, tmp = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=str(path.parent))
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as fh:
                fh.write(text)
                fh.flush()
                os.fsync(fh.fileno())  # the content is on disk before the rename makes it visible
            os.replace(tmp, path)
        except BaseException:
            Path(tmp).unlink(missing_ok=True)
            raise


def _same_file_path(a: object, b: object) -> bool:
    if not a or not b:
        return False
    try:
        return os.path.normcase(str(Path(str(a)).resolve())) == os.path.normcase(str(Path(str(b)).resolve()))
    except (OSError, ValueError):
        return False


ROLLBACK_BLOCK_UNREADABLE_REASON = (
    "ملف حالة التراجع تالف — راجع الدعم الفني / "
    "rollback state file unreadable (rollback_blocked.json): contact support before using the system"
)


def rollback_pending_reason(
    db_path: Union[str, Path],
    installed_version: Optional[str] = None,
    data_dir: Optional[Path] = None,
) -> Optional[str]:
    """
    Startup guard (called by the schema upgrade before any migration). Returns a maintenance reason when a rollback
    restored this DB to an older version's schema but the older installer never ran, so this (newer) binary must not
    migrate or write the restored DB.

    None only when there is no block file, the block names another DB (K4: a source run sharing the update dir), or
    the older version is installed now (the manual rollback finished). Fails CLOSED: a block file that exists but
    cannot be read, is not a JSON object or has no db_path returns ROLLBACK_BLOCK_UNREADABLE_REASON.
    """
    path = Path(data_dir or default_update_data_dir()) / ROLLBACK_BLOCK_FILE
    try:
        if not os.path.lexists(path):
            return None
        block = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:  # ValueError covers JSON and Unicode decode errors
        logger.critical("rollback_blocked.json exists but cannot be read: %s", exc)
        return ROLLBACK_BLOCK_UNREADABLE_REASON
    if not isinstance(block, dict) or not isinstance(block.get("db_path"), str) or not block["db_path"].strip():
        logger.critical("rollback_blocked.json is malformed (not an object or no db_path)")
        return ROLLBACK_BLOCK_UNREADABLE_REASON
    if not _same_file_path(block["db_path"], db_path):
        return None
    installed = installed_version or read_installed_version()
    if installed == block.get("to_version"):
        return None
    return (  # English first: startup callers match the "rollback pending" prefix
        f"rollback pending: the database was restored for v{block.get('to_version')} but the installer of that "
        f"version did not run ({block.get('reason')}). Run it manually: {block.get('installer_path')} / "
        f"تم استرجاع قاعدة البيانات للإصدار {block.get('to_version')} لكن برنامج تثبيته لم يعمل — شغّله يدوياً"
    )
