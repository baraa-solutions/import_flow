"""
Schema Upgrade Service (SchemaUpgradeService)
============================================
In-place, additive database upgrade run on every backend start:
1. When the code version differs from the last version seen for this DB, takes a verified
   snapshot (SQLite online backup + integrity_check + sha256) into ``<DB folder>/backups``
   (``auto_pre_upgrade_v...``). No snapshot on ordinary restarts.
2. Prunes old ``auto_pre_upgrade_*`` snapshots, always keeping the newest one and never touching
   protected backups (R9).
3. Creates missing tables and adds missing columns (additive DDL only).
4. Invokes MasterDataSyncService to insert newly introduced reference items.

Failure policy (R8, A11): if the snapshot cannot be verified or the DDL fails, nothing further is
written, the failure is logged loudly and the process enters maintenance mode (writes blocked).
There is never an automatic restore.
"""
import json
import logging
import re
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

from sqlalchemy import Engine, inspect, text
from sqlalchemy.orm import sessionmaker

from database.database import Base, DB_PATH, engine as default_engine
from database.master_data_sync_service import MasterDataSyncService
from utils.db_safety import (
    AUTO_PRE_UPGRADE_PREFIX,
    backups_dir_for,
    enter_maintenance_mode,
    select_prunable,
    sqlite_online_backup,
    version_file_path,
)

logger = logging.getLogger("schema_upgrade")

DEFAULT_VERSION_TAG = "1.0.52"
VERSION_STATE_FILENAME = ".last_seen_version.json"
_SNAPSHOT_TS_RE = re.compile(r"_(\d{8}_\d{6})(?:_\d+)?\.db$")


class SchemaUpgradeService:
    @staticmethod
    def _get_version_tag() -> str:
        """Current code version from version.json next to the executable (frozen) or the repo root."""
        v_file = version_file_path()
        try:
            if v_file.exists():
                with open(v_file, "r", encoding="utf-8") as f:
                    return str(json.load(f).get("version", DEFAULT_VERSION_TAG))
        except (OSError, ValueError) as exc:
            logger.warning("Could not read %s: %s", v_file, exc)
        return DEFAULT_VERSION_TAG

    # ------------------------------------------------------------------
    # Last-seen version state (stored in the backups folder, keyed by DB file name)
    # ------------------------------------------------------------------
    @staticmethod
    def _read_last_seen_version(backups_dir: Path, db_file: Path) -> Optional[str]:
        state_file = backups_dir / VERSION_STATE_FILENAME
        if not state_file.exists():
            return None
        try:
            with open(state_file, "r", encoding="utf-8") as f:
                value = json.load(f).get(db_file.name)
            return str(value) if value else None
        except (OSError, ValueError, AttributeError) as exc:
            logger.warning("Unreadable version state %s (%s); treating as unknown.", state_file, exc)
            return None

    @staticmethod
    def _write_last_seen_version(backups_dir: Path, db_file: Path, version: str) -> None:
        state_file = backups_dir / VERSION_STATE_FILENAME
        state: Dict[str, Any] = {}
        try:
            if state_file.exists():
                with open(state_file, "r", encoding="utf-8") as f:
                    loaded = json.load(f)
                if isinstance(loaded, dict):
                    state = loaded
        except (OSError, ValueError) as exc:
            logger.warning("Rewriting unreadable version state %s: %s", state_file, exc)
        state[db_file.name] = version
        tmp_file = state_file.with_suffix(".tmp")
        with open(tmp_file, "w", encoding="utf-8") as f:
            json.dump(state, f, indent=2)
        tmp_file.replace(state_file)

    # ------------------------------------------------------------------
    # Snapshot + retention
    # ------------------------------------------------------------------
    @staticmethod
    def _snapshot_sort_key(path: Path):
        match = _SNAPSHOT_TS_RE.search(path.name)
        stamp = match.group(1) if match else ""
        return (stamp, path.stat().st_mtime, path.name)

    @classmethod
    def _take_snapshot(cls, db_file: Path, backups_dir: Path, version_str: str) -> Path:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        dest = backups_dir / f"{AUTO_PRE_UPGRADE_PREFIX}v{version_str}_{timestamp}.db"
        counter = 1
        while dest.exists():
            dest = backups_dir / f"{AUTO_PRE_UPGRADE_PREFIX}v{version_str}_{timestamp}_{counter}.db"
            counter += 1
        result = sqlite_online_backup(db_file, dest)
        logger.warning(
            "Pre-upgrade snapshot created: %s (sha256=%s, %d bytes)",
            result.path.name, result.sha256, result.size_bytes,
        )
        return result.path

    @classmethod
    def _prune_snapshots(cls, backups_dir: Path, max_auto_backups: int, keep_path: Optional[Path]) -> List[str]:
        """Delete only old auto_pre_upgrade_* files. The newest snapshot (the one taken before the
        latest version change) and protected backups are never deleted."""
        snapshots = list(backups_dir.glob(f"{AUTO_PRE_UPGRADE_PREFIX}*.db"))
        removed: List[str] = []
        for old_file in select_prunable(snapshots, keep=max_auto_backups, sort_key=cls._snapshot_sort_key):
            if keep_path is not None and old_file.resolve() == keep_path.resolve():
                continue
            try:
                old_file.unlink(missing_ok=True)
                removed.append(old_file.name)
            except OSError as exc:
                logger.warning("Could not prune snapshot %s: %s", old_file.name, exc)
        return removed

    @staticmethod
    def _rotate_email_passwords(engine_to_use: Engine) -> int:
        """Re-encrypt legacy-key / plaintext mailbox passwords with the current key. A failure is logged
        and never blocks startup; undecryptable values are left untouched."""
        try:
            if "email_settings" not in set(inspect(engine_to_use).get_table_names()):
                return 0
            from modules.smart_email_listener.repository import rotate_stored_email_passwords

            session = sessionmaker(autocommit=False, autoflush=False, bind=engine_to_use)()
            try:
                rotated = rotate_stored_email_passwords(session)
            finally:
                session.close()
            if rotated:
                logger.warning("Re-encrypted %d stored mailbox password(s) with the current key.", rotated)
            return rotated
        except Exception as exc:  # startup must continue; the old key still decrypts these values
            logger.error("Mailbox password rotation skipped: %s", exc, exc_info=True)
            return 0

    @staticmethod
    def _fail(reason: str, result: Dict[str, Any]) -> Dict[str, Any]:
        logger.critical("[SchemaUpgradeService] STARTUP UPGRADE FAILED: %s", reason)
        enter_maintenance_mode(reason)
        result["status"] = "maintenance_mode"
        result["error"] = reason
        return result

    # ------------------------------------------------------------------
    # Entry point
    # ------------------------------------------------------------------
    @classmethod
    def execute_safe_startup_upgrade(
        cls,
        db_path: Optional[str] = None,
        target_engine: Optional[Engine] = None,
        metadata: Optional[Any] = None,
        backups_dir: Optional[Path] = None,
        max_auto_backups: int = 15,
    ) -> Dict[str, Any]:
        """
        Startup database schema verification and incremental upgrade. Safe to call on every launch.
        Returns ``status`` = ``upgraded_successfully`` or ``maintenance_mode`` (writes blocked).
        """
        engine_to_use = target_engine or default_engine
        metadata_to_use = metadata or Base.metadata
        db_file_path = Path(db_path or DB_PATH)
        backups_dir = Path(backups_dir) if backups_dir is not None else backups_dir_for(db_file_path)

        version_str = cls._get_version_tag()
        result: Dict[str, Any] = {
            "status": "upgraded_successfully",
            "version": version_str,
            "previous_version": None,
            "backup_created": None,
            "backups_pruned": [],
            "tables_added": [],
            "columns_added": [],
            "master_data_summary": {},
        }

        # 1. Verified snapshot, only when the code version changed since the last start.
        db_has_data = db_file_path.exists() and db_file_path.stat().st_size > 0
        previous_version = cls._read_last_seen_version(backups_dir, db_file_path) if backups_dir.exists() else None
        result["previous_version"] = previous_version
        if db_has_data and previous_version != version_str:
            try:
                backups_dir.mkdir(parents=True, exist_ok=True)
                snapshot = cls._take_snapshot(db_file_path, backups_dir, version_str)
                result["backup_created"] = snapshot.name
            except Exception as exc:  # any failure here must stop all further writes
                return cls._fail(f"pre-upgrade snapshot failed ({type(exc).__name__}: {exc})", result)
            result["backups_pruned"] = cls._prune_snapshots(
                backups_dir, max_auto_backups, keep_path=backups_dir / result["backup_created"]
            )

        # 2. Create missing tables.
        try:
            inspector = inspect(engine_to_use)
            existing_tables = set(inspector.get_table_names())
            metadata_to_use.create_all(bind=engine_to_use)
        except Exception as exc:
            return cls._fail(f"create_all failed ({type(exc).__name__}: {exc})", result)

        # 3. Additive column upgrade (ALTER TABLE ADD COLUMN).
        failed_columns: List[str] = []
        try:
            inspector = inspect(engine_to_use)
            with engine_to_use.connect() as conn:
                for table_name, table in metadata_to_use.tables.items():
                    if table_name not in existing_tables:
                        result["tables_added"].append(table_name)
                        continue
                    # SQLite column names are case-insensitive: "Name" already satisfies "name".
                    existing_cols = {c["name"].lower() for c in inspector.get_columns(table_name)}
                    for col in table.columns:
                        if col.name.lower() in existing_cols:
                            continue
                        col_type = col.type.compile(engine_to_use.dialect)
                        try:
                            conn.execute(text(f'ALTER TABLE "{table_name}" ADD COLUMN "{col.name}" {col_type}'))
                            conn.commit()
                            result["columns_added"].append(f"{table_name}.{col.name}")
                            logger.warning("Added missing column: %s.%s (%s)", table_name, col.name, col_type)
                        except Exception as exc:
                            conn.rollback()
                            failed_columns.append(f"{table_name}.{col.name}: {exc}")
        except Exception as exc:
            return cls._fail(f"schema introspection failed ({type(exc).__name__}: {exc})", result)
        if failed_columns:
            return cls._fail("could not add columns: " + "; ".join(failed_columns), result)

        # 4. Master data: insert-only seeds. A failure is logged loudly but does not block writes.
        try:
            SessionMaker = sessionmaker(autocommit=False, autoflush=False, bind=engine_to_use)
            session = SessionMaker()
            try:
                result["master_data_summary"] = MasterDataSyncService(session).sync_all()
            finally:
                session.close()
        except Exception as exc:
            logger.error("[SchemaUpgradeService] Master data sync error: %s", exc, exc_info=True)
            result["master_data_error"] = str(exc)

        # 5. Move stored mailbox passwords to the current SECRET_KEY (idempotent, never destructive).
        result["email_passwords_rotated"] = cls._rotate_email_passwords(engine_to_use)

        # 6. Remember the version only after a successful upgrade.
        if db_file_path.exists():
            try:
                backups_dir.mkdir(parents=True, exist_ok=True)
                cls._write_last_seen_version(backups_dir, db_file_path, version_str)
            except OSError as exc:
                logger.error("Could not record last-seen version (a snapshot will be retaken next start): %s", exc)

        return result
