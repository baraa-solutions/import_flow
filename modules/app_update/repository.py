"""
File storage for the updater (the "database" of this module).

Layout under the update data dir:
  last_manifest.json      raw signed envelope of the last verified manifest + fetched_at (re-verified on load)
  highest_seen.json       highest verified (version, build_number): older manifests are refused (replay/freeze)
  update_history.jsonl    one JSON event per line (survives a DB restore), capped at the newest 1000 lines
  staging/                installer downloads (<file>.part while streaming, <file> once verified)
"""
import json
import logging
import os
import re
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

logger = logging.getLogger(__name__)

LAST_MANIFEST_FILE = "last_manifest.json"
HIGHEST_SEEN_FILE = "highest_seen.json"
HISTORY_FILE = "update_history.jsonl"
HISTORY_MAX_LINES = 1000
HISTORY_DETAIL_MAX_CHARS = 500
_VERSION_RE = re.compile(r"^\d+\.\d+\.\d+$")
STAGING_DIR = "staging"
PART_SUFFIX = ".part"


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
            if not isinstance(version, str) or not _VERSION_RE.match(version):
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

    # ─── internals ────────────────────────────────────────────────────────
    def _atomic_write_text(self, path: Path, text: str) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        fd, tmp = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=str(path.parent))
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as fh:
                fh.write(text)
            os.replace(tmp, path)
        except BaseException:
            Path(tmp).unlink(missing_ok=True)
            raise
