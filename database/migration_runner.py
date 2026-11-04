"""
Migration runner (docs/plans/update-system-phase2-5-spec.md section A.2).

Classifies the database against the bundled Alembic scripts and performs the three migration actions
used at startup by ``SchemaUpgradeService``:

- ``FRESH`` / ``UNSTAMPED`` -> ``stamp_head`` after ``create_all`` (models == head schema);
- ``BEHIND`` -> verified ``pre_migration_`` backup, then ``upgrade_to_head``;
- ``UNKNOWN`` (R10) -> refused: the caller enters maintenance mode before writing anything.

Rollback is always "restore a backup": ``downgrade()`` is never called by code.
"""
from __future__ import annotations

import logging
import sys
from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Literal, Optional

from alembic import command
from alembic.config import Config
from alembic.script import ScriptDirectory
from sqlalchemy import Connection, Engine, inspect, text

from utils.db_safety import PRE_MIGRATION_PREFIX, REPO_ROOT, BackupResult, sqlite_online_backup, unique_backup_name

logger = logging.getLogger("migration_runner")

BASELINE_REVISION = "e1f2a3b4c5d6"
VERSION_TABLE = "alembic_version"


class DbState(str, Enum):
    FRESH = "fresh"            # no user tables (sqlite_% ignored)
    UNSTAMPED = "unstamped"    # user tables, alembic_version missing or empty
    AT_HEAD = "at_head"        # exactly 1 row == head
    BEHIND = "behind"          # exactly 1 row, known to the script dir, != head
    UNKNOWN = "unknown"        # >1 row, or revision not in the bundled script dir (R10)


@dataclass(frozen=True)
class DbStateReport:
    state: DbState
    current_revision: Optional[str]
    head_revision: str


@dataclass(frozen=True)
class MigrationResult:
    state: DbState
    action: Literal["none", "upgraded", "stamped", "refused"]
    from_revision: Optional[str]
    to_revision: Optional[str]
    backup_file: Optional[str]      # pre_migration_* file name, if taken


# ----------------------------------------------------------------------------
# Alembic configuration
# ----------------------------------------------------------------------------

def alembic_script_location() -> Path:
    """Bundled migration scripts: ``sys._MEIPASS/alembic`` when frozen (they are bundled data, not
    runtime files next to the exe), the repo's ``alembic/`` folder otherwise."""
    if getattr(sys, "frozen", False) and getattr(sys, "_MEIPASS", None):
        return Path(sys._MEIPASS) / "alembic"
    return REPO_ROOT / "alembic"


def build_alembic_config(connection: Optional[Connection] = None) -> Config:
    """Alembic config without an ini file: ``alembic.ini`` (and its relative sqlalchemy.url) is never
    read at runtime. env.py uses the passed connection, or ``database.database.DATABASE_URL``."""
    cfg = Config()
    cfg.set_main_option("script_location", str(alembic_script_location()))
    cfg.attributes["connection"] = connection
    cfg.attributes["configure_logger"] = False
    return cfg


def _script_directory() -> ScriptDirectory:
    return ScriptDirectory.from_config(build_alembic_config())


def _single_head(script: ScriptDirectory) -> str:
    heads = script.get_heads()
    if len(heads) != 1:
        raise RuntimeError(f"Alembic script directory must have exactly one head, found {len(heads)}: {heads}")
    return heads[0]


def get_head_revision() -> str:
    return _single_head(_script_directory())


# ----------------------------------------------------------------------------
# State inspection (read-only)
# ----------------------------------------------------------------------------

def inspect_db_state(engine: Engine) -> DbStateReport:
    """Classify the database. Read-only; raises when the DB cannot be read (e.g. corrupt file)."""
    script = _script_directory()
    head = _single_head(script)

    with engine.connect() as conn:
        tables = inspect(conn).get_table_names()
        user_tables = [t for t in tables if not t.lower().startswith("sqlite_") and t != VERSION_TABLE]
        rows = []
        if VERSION_TABLE in tables:
            rows = [r[0] for r in conn.execute(text(f"SELECT version_num FROM {VERSION_TABLE}"))]

    if len(rows) > 1:
        return DbStateReport(DbState.UNKNOWN, ",".join(str(r) for r in rows), head)
    if not rows:
        state = DbState.UNSTAMPED if user_tables else DbState.FRESH
        return DbStateReport(state, None, head)

    current = rows[0]
    if current == head:
        return DbStateReport(DbState.AT_HEAD, current, head)
    try:
        resolved = script.get_revision(current) if current else None
        # Exact match only: Alembic also resolves unique prefixes, which is not a known revision.
        known = resolved is not None and resolved.revision == current
    except Exception as exc:  # any resolution failure means this build does not know the revision (R10)
        logger.warning("Database revision %r is not in the bundled scripts: %s", current, exc)
        known = False
    return DbStateReport(DbState.BEHIND if known else DbState.UNKNOWN, current, head)


# ----------------------------------------------------------------------------
# Actions
# ----------------------------------------------------------------------------

def sqlite_engine_file(engine: Engine) -> Optional[Path]:
    """The database file a SQLite engine really writes to (``sqlite:///file:...?uri=true`` included).
    None for in-memory databases and for non-SQLite engines."""
    if engine.dialect.name != "sqlite":
        return None
    database = engine.url.database or ""
    if database.startswith("file:"):
        database = database[len("file:"):].split("?", 1)[0]
        if "mode=memory" in (engine.url.database or "") or str(engine.url.query.get("mode", "")) == "memory":
            return None
    if not database or database == ":memory:":
        return None
    return Path(database)


def take_pre_migration_backup(db_path: Path, backups_dir: Path, report: DbStateReport) -> BackupResult:
    """Verified online backup (integrity_check + sha256) named
    ``pre_migration_<from|unstamped>_to_<head>_<ts>.db``. Protected from every pruner (R9).
    Raises on any failure; the caller must not migrate then."""
    backups_dir = Path(backups_dir)
    backups_dir.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    stem = f"{PRE_MIGRATION_PREFIX}{report.current_revision or 'unstamped'}_to_{report.head_revision}_{timestamp}"
    dest = backups_dir / unique_backup_name(stem, backups_dir)
    result = sqlite_online_backup(Path(db_path), dest)
    logger.warning(
        "Pre-migration backup created: %s (sha256=%s, %d bytes)", result.path.name, result.sha256, result.size_bytes
    )
    return result


def _current_revision(engine: Engine) -> str:
    with engine.connect() as conn:
        rows = [r[0] for r in conn.execute(text(f"SELECT version_num FROM {VERSION_TABLE}"))]
    if len(rows) != 1:
        raise RuntimeError(f"{VERSION_TABLE} has {len(rows)} rows after migration")
    return rows[0]


def _run_alembic(engine: Engine, fn, target: str) -> None:
    # A plain connection (no engine.begin()): Alembic then owns the transactions and, with
    # transaction_per_migration=True in env.py, commits each revision together with its
    # alembic_version update. A failing revision leaves the DB at the last successful one.
    #
    # SQLite FOREIGN KEY note: batch_alter_table (render_as_batch=True in env.py) creates a
    # new table, copies data, then DROPs the old one.  With PRAGMA foreign_keys=ON the DROP
    # fails whenever another table references the rebuilt table (IntegrityError: FOREIGN KEY
    # constraint failed).  We disable FK enforcement for the whole migration run and restore
    # it afterwards.  This is safe: Alembic never inserts FK-violating rows; it only
    # restructures the schema.  The pragma is a per-connection flag, so it does not affect
    # any other concurrent connections.
    is_sqlite = engine.dialect.name == "sqlite"
    with engine.connect() as conn:
        if is_sqlite:
            conn.exec_driver_sql("PRAGMA foreign_keys = OFF;")
        try:
            fn(build_alembic_config(conn), target)
            conn.commit()
        finally:
            if is_sqlite:
                conn.exec_driver_sql("PRAGMA foreign_keys = ON;")
                conn.commit()


def upgrade_to_head(engine: Engine) -> str:
    _run_alembic(engine, command.upgrade, "head")
    revision = _current_revision(engine)
    logger.warning("Database upgraded to Alembic revision %s", revision)
    return revision


def stamp_head(engine: Engine) -> str:
    _run_alembic(engine, command.stamp, "head")
    revision = _current_revision(engine)
    logger.warning("Database stamped at Alembic revision %s", revision)
    return revision
