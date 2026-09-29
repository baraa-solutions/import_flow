"""
Schema Upgrade Service (SchemaUpgradeService)
============================================
In-place database upgrade run on every backend start (update-system-phase2-5-spec.md A.3):
0. Preflight: classify the DB against the bundled Alembic scripts (read-only). A revision this build
   does not know (R10) enters maintenance mode before anything is written.
1. When the code version differs from the last version seen for this DB, takes a verified
   snapshot (SQLite online backup + integrity_check + sha256) into ``<DB folder>/backups``
   (``auto_pre_upgrade_v...``). No snapshot on ordinary restarts. Old ``auto_pre_upgrade_*``
   snapshots are pruned, always keeping the newest one and never touching protected backups (R9).
2. Unstamped or behind DBs with data: verified, protected ``pre_migration_*`` backup.
3. Behind: ``alembic upgrade head``.
4. Creates missing tables and adds missing columns (additive DDL only).
5. Fresh or unstamped: ``alembic stamp head`` (models == head schema).
6. Invokes MasterDataSyncService to insert newly introduced reference items, rotates mailbox
   passwords, records the last-seen version.

Failure policy (R8, A11): if a backup cannot be verified or the DDL / migration fails, nothing further
is written, the failure is logged loudly and the process enters maintenance mode (writes blocked).
There is never an automatic restore.
"""
import json
import logging
import re
from dataclasses import asdict
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

from sqlalchemy import Engine, inspect, text
from sqlalchemy.orm import sessionmaker

from database import migration_runner
from database.database import Base, DB_PATH, engine as default_engine
from database.master_data_sync_service import MasterDataSyncService
from database.migration_runner import DbState, MigrationResult
from utils.db_safety import (
    AUTO_PRE_UPGRADE_PREFIX,
    backups_dir_for,
    enter_maintenance_mode,
    same_file,
    select_prunable,
    sqlite_online_backup,
    unique_backup_name,
    version_file_path,
)

logger = logging.getLogger("schema_upgrade")

DEFAULT_VERSION_TAG = "1.0.52"
VERSION_STATE_FILENAME = ".last_seen_version.json"
_SNAPSHOT_TS_RE = re.compile(r"_(\d{8}_\d{6})(?:_\d+)?\.db$")
# SQLite refuses these as the DEFAULT of ADD COLUMN ("Cannot add a column with non-constant default").
_NON_CONSTANT_DEFAULT_RE = re.compile(r"^\s*(\(|CURRENT_TIME|CURRENT_DATE|CURRENT_TIMESTAMP)", re.IGNORECASE)


def _constant_server_default_sql(col: Any) -> Optional[str]:
    """SQL literal of a column's server_default when SQLite accepts it in ALTER TABLE ADD COLUMN,
    else None (no server_default, or a non-constant one)."""
    server_default = getattr(col, "server_default", None)
    arg = getattr(server_default, "arg", None)
    if arg is None:
        return None
    if isinstance(arg, str):
        return "'" + arg.replace("'", "''") + "'"
    sql = str(getattr(arg, "text", "")).strip()
    if not sql or _NON_CONSTANT_DEFAULT_RE.match(sql):
        return None
    return sql


def add_column_ddl(table_name: str, col: Any, dialect: Any) -> str:
    """ALTER TABLE ADD COLUMN for step 4b. A column with a constant server_default keeps it, plus NOT NULL
    when the model says so, so existing rows get the default instead of NULL (a NOT NULL model column with
    NULLs breaks response models). Without a usable default the column is added nullable, as before
    (SQLite cannot add a NOT NULL column without a default)."""
    ddl = f'ALTER TABLE "{table_name}" ADD COLUMN "{col.name}" {col.type.compile(dialect)}'
    default_sql = _constant_server_default_sql(col)
    if default_sql is None:
        return ddl
    if not col.nullable:
        ddl += " NOT NULL"
    return ddl + f" DEFAULT {default_sql}"


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
        dest = backups_dir / unique_backup_name(f"{AUTO_PRE_UPGRADE_PREFIX}v{version_str}_{timestamp}", backups_dir)
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
    def _rollback_pending_reason(db_file_path: Path) -> Optional[str]:
        """Reason to stay read-only because a rollback restored this DB for an older version whose installer
        never ran (owned by modules.app_update). Imported here, not at module level, to keep the startup
        import graph small; an import failure propagates and the caller fails closed."""
        from modules.app_update.repository import rollback_pending_reason

        return rollback_pending_reason(db_file_path)

    @staticmethod
    def _create_missing_indexes(
        engine_to_use: Engine, metadata_to_use: Any, columns_added: List[str], all_tables: bool = False
    ) -> List[str]:
        """CREATE INDEX IF NOT EXISTS for missing non-unique model indexes.

        ``all_tables=True`` (FRESH / UNSTAMPED: the DB is stamped at head next, so no revision will ever create
        them): every table of the metadata. Otherwise only indexes that reference a column added by step 4b.
        Unique indexes are never created here (existing rows may violate them), nor indexes whose columns are
        missing. A failure is logged and skipped: an index is a performance aid, not a correctness requirement.
        Returns the names of the indexes actually created."""
        added: Dict[str, set] = {}
        for entry in columns_added:
            table_name, _, col_name = entry.partition(".")
            added.setdefault(table_name, set()).add(col_name.lower())
        created: List[str] = []
        if not added and not all_tables:
            return created
        inspector = inspect(engine_to_use)
        existing_tables = set(inspector.get_table_names())
        targets = existing_tables if all_tables else set(added) & existing_tables
        with engine_to_use.connect() as conn:
            for table_name in sorted(targets):
                table = metadata_to_use.tables.get(table_name)
                if table is None:
                    continue
                present_indexes = {ix["name"] for ix in inspector.get_indexes(table_name)}
                present_cols = {c["name"].lower() for c in inspector.get_columns(table_name)}
                new_cols = added.get(table_name, set())
                for index in table.indexes:
                    if index.unique or not index.name or index.name in present_indexes:
                        continue
                    cols = [c.name for c in index.columns]
                    if not cols or not all(c.lower() in present_cols for c in cols):
                        continue
                    if not all_tables and not any(c.lower() in new_cols for c in cols):
                        continue
                    col_sql = ", ".join(f'"{c}"' for c in cols)
                    try:
                        conn.execute(text(f'CREATE INDEX IF NOT EXISTS "{index.name}" ON "{table_name}" ({col_sql})'))
                        conn.commit()
                        created.append(index.name)
                    except Exception as exc:
                        conn.rollback()
                        logger.error("Could not create index %s on %s: %s", index.name, table_name, exc)
        return created

    @staticmethod
    def _migration_dict(migration: MigrationResult) -> Dict[str, Any]:
        data = asdict(migration)
        data["state"] = migration.state.value
        return data

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
            "indexes_added": [],
            "master_data_summary": {},
            "migration": None,
        }

        # 0a. Rollback safety (update-system Phase 5): a pending or failed rollback blocks all writes.
        try:
            rollback_reason = cls._rollback_pending_reason(db_file_path)
        except Exception as exc:  # cannot tell whether a rollback is pending: fail closed
            return cls._fail(f"preflight failed: rollback state unreadable ({type(exc).__name__}: {exc})", result)
        if rollback_reason:
            return cls._fail(rollback_reason, result)

        # 0b. The file we snapshot/back up must be the file the engine migrates (DATABASE_URL may differ
        #     from DATABASE_PATH). In-memory SQLite has nothing to back up.
        backup_source_ok = True
        if engine_to_use.dialect.name == "sqlite":
            engine_file = migration_runner.sqlite_engine_file(engine_to_use)
            if engine_file is None:
                backup_source_ok = False
                logger.warning("In-memory SQLite engine: startup snapshots and pre_migration backups are skipped.")
            elif not same_file(engine_file, db_file_path):
                return cls._fail(
                    f"preflight failed: engine database {engine_file} differs from DATABASE_PATH {db_file_path}; "
                    "backups would protect the wrong file",
                    result,
                )

        # 0c. Preflight (read-only): where is this DB relative to the bundled migration scripts?
        try:
            report = migration_runner.inspect_db_state(engine_to_use)
        except Exception as exc:  # unreadable / corrupt DB or broken script dir: write nothing
            return cls._fail(f"preflight failed: cannot determine the database state ({type(exc).__name__}: {exc})", result)
        if report.state == DbState.UNKNOWN:
            # R10: a newer (or foreign) schema. No snapshot, no DDL, no master data, no version write.
            result["migration"] = cls._migration_dict(
                MigrationResult(report.state, "refused", report.current_revision, None, None)
            )
            return cls._fail(
                f"R10: database revision {report.current_revision} is unknown to this version "
                f"(head {report.head_revision})",
                result,
            )

        # 1. Verified snapshot, only when the code version changed since the last start.
        db_has_data = backup_source_ok and db_file_path.exists() and db_file_path.stat().st_size > 0
        previous_version = cls._read_last_seen_version(backups_dir, db_file_path) if backups_dir.exists() else None
        result["previous_version"] = previous_version
        # A FRESH DB (no user tables) holds nothing worth a snapshot.
        if db_has_data and report.state != DbState.FRESH and previous_version != version_str:
            try:
                backups_dir.mkdir(parents=True, exist_ok=True)
                snapshot = cls._take_snapshot(db_file_path, backups_dir, version_str)
                result["backup_created"] = snapshot.name
            except Exception as exc:  # any failure here must stop all further writes
                return cls._fail(f"pre-upgrade snapshot failed ({type(exc).__name__}: {exc})", result)
            result["backups_pruned"] = cls._prune_snapshots(
                backups_dir, max_auto_backups, keep_path=backups_dir / result["backup_created"]
            )

        # 2. Protected pre_migration backup before the first Alembic write (stamp or upgrade).
        backup_file: Optional[str] = None
        if report.state in (DbState.UNSTAMPED, DbState.BEHIND) and db_has_data:
            if engine_to_use.dialect.name != "sqlite":
                logger.warning(
                    "Skipping pre_migration backup: backups are SQLite-only (dialect %s).", engine_to_use.dialect.name
                )
            else:
                try:
                    backup = migration_runner.take_pre_migration_backup(db_file_path, backups_dir, report)
                except Exception as exc:  # no verified backup -> no migration
                    return cls._fail(f"pre-migration backup failed ({type(exc).__name__}: {exc})", result)
                backup_file = backup.path.name
        migration = MigrationResult(report.state, "none", report.current_revision, report.current_revision, backup_file)
        result["migration"] = cls._migration_dict(migration)

        # 3. Behind: apply the bundled revisions. A failure is never auto-restored (R8).
        if report.state == DbState.BEHIND:
            try:
                new_revision = migration_runner.upgrade_to_head(engine_to_use)
            except Exception as exc:
                return cls._fail(
                    f"migration {report.current_revision} -> {report.head_revision} failed "
                    f"({type(exc).__name__}: {exc}); backup: {backup_file or 'none'}",
                    result,
                )
            migration = MigrationResult(report.state, "upgraded", report.current_revision, new_revision, backup_file)
            result["migration"] = cls._migration_dict(migration)

        # 4. Create missing tables.
        try:
            inspector = inspect(engine_to_use)
            existing_tables = set(inspector.get_table_names())
            metadata_to_use.create_all(bind=engine_to_use)
        except Exception as exc:
            return cls._fail(f"create_all failed ({type(exc).__name__}: {exc})", result)

        # 4b. Additive column upgrade (ALTER TABLE ADD COLUMN).
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
                            conn.execute(text(add_column_ddl(table_name, col, engine_to_use.dialect)))
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

        # 4c. Missing non-unique model indexes (models == head: a FRESH / UNSTAMPED DB is stamped next, so the
        #     revisions that create indexes never run on it -> all tables; otherwise only 4b's new columns).
        result["indexes_added"] = cls._create_missing_indexes(
            engine_to_use,
            metadata_to_use,
            result["columns_added"],
            all_tables=report.state in (DbState.FRESH, DbState.UNSTAMPED),
        )

        # 5. Fresh / unstamped: the schema now equals the models, which equal head -> stamp head.
        if report.state in (DbState.FRESH, DbState.UNSTAMPED):
            try:
                new_revision = migration_runner.stamp_head(engine_to_use)
            except Exception as exc:
                return cls._fail(f"alembic stamp head failed ({type(exc).__name__}: {exc})", result)
            migration = MigrationResult(report.state, "stamped", report.current_revision, new_revision, backup_file)
            result["migration"] = cls._migration_dict(migration)

        # 6. Master data: insert-only seeds. A failure is logged loudly but does not block writes.
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

        # 6b. Move stored mailbox passwords to the current SECRET_KEY (idempotent, never destructive).
        result["email_passwords_rotated"] = cls._rotate_email_passwords(engine_to_use)

        # 6c. Remember the version only after a successful upgrade.
        if db_file_path.exists():
            try:
                backups_dir.mkdir(parents=True, exist_ok=True)
                cls._write_last_seen_version(backups_dir, db_file_path, version_str)
            except OSError as exc:
                logger.error("Could not record last-seen version (a snapshot will be retaken next start): %s", exc)

        return result
