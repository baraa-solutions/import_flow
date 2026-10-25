"""
Production databases created before Alembic carry inland_transport_status DEFAULT "NOT_BOOKED" (double quotes,
from the old modules/inland_transport/migration.py). Migration f3a4b5c6d7e8 recreates import_files in batch mode;
without the fix Alembic re-emitted DEFAULT ("NOT_BOOKED"), SQLite refused it ("default value ... is not
constant"), the startup upgrade failed and the app entered maintenance mode. Found while testing v2.4.0 on a copy
of the production database (revision e2f3a4b5c6d7).
"""
import re
import sqlite3
from pathlib import Path

from sqlalchemy import create_engine

import database.schema_upgrade_service as sus
import main  # noqa: F401  (registers every model on Base.metadata)
from database import migration_runner
from database.database import Base
from database.schema_upgrade_service import SchemaUpgradeService
from utils import db_safety

PRODUCTION_REVISION = "e2f3a4b5c6d7"  # the revision installed clients are on before v2.4.0
PARTIAL_SHIPMENT_COLUMNS = ("parent_import_file_id", "parent_file_code", "is_partial_shipment")


class _NoMasterData:
    def __init__(self, session):
        pass

    def sync_all(self):
        return {"status": "stub"}


def _legacy_production_db(db_file: Path) -> None:
    """Full schema at PRODUCTION_REVISION: import_files without the partial-shipment columns, with the legacy
    double-quoted default, and one existing import file row."""
    engine = create_engine(f"sqlite:///{db_file.as_posix()}")
    try:
        Base.metadata.create_all(bind=engine)
    finally:
        engine.dispose()

    conn = sqlite3.connect(db_file)
    try:
        sql = conn.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name='import_files'").fetchone()[0]
        lines = [
            line for line in sql.splitlines()
            if not re.match(rf"\s*({'|'.join(PARTIAL_SHIPMENT_COLUMNS)})\b", line)
            and "fk_import_files_parent_import_file_id" not in line
        ]
        legacy_sql = re.sub(r",(\s*\))\s*$", r"\1", "\n".join(lines))
        legacy_sql = legacy_sql.replace(
            "inland_transport_status VARCHAR(50)", 'inland_transport_status VARCHAR(50) DEFAULT "NOT_BOOKED"'
        )
        assert 'DEFAULT "NOT_BOOKED"' in legacy_sql

        conn.execute("PRAGMA foreign_keys = OFF")
        conn.execute("DROP INDEX IF EXISTS idx_import_files_parent_id")
        conn.execute("DROP TABLE import_files")
        conn.execute(legacy_sql)

        columns = list(conn.execute("PRAGMA table_info(import_files)"))
        required = [c for c in columns if c[3] and c[4] is None and not c[5]]
        values = {c[1]: ("x" if re.search(r"CHAR|TEXT|CLOB", c[2] or "", re.I) else 0) for c in required}
        values["import_file_code"] = "IMP-LEGACY-1"
        conn.execute(
            f"INSERT INTO import_files ({', '.join(values)}) VALUES ({', '.join('?' * len(values))})",
            list(values.values()),
        )

        conn.execute("CREATE TABLE alembic_version (version_num VARCHAR(32) NOT NULL)")
        conn.execute("INSERT INTO alembic_version (version_num) VALUES (?)", (PRODUCTION_REVISION,))
        conn.commit()
    finally:
        conn.close()


def _startup(db_file: Path, monkeypatch):
    db_safety.clear_maintenance_mode()
    monkeypatch.setattr(sus, "MasterDataSyncService", _NoMasterData)
    monkeypatch.setattr(SchemaUpgradeService, "_get_version_tag", staticmethod(lambda: "9.9.9"))
    engine = create_engine(f"sqlite:///{db_file.as_posix()}")
    try:
        result = SchemaUpgradeService.execute_safe_startup_upgrade(
            db_path=str(db_file), target_engine=engine, metadata=Base.metadata
        )
        return result, db_safety.is_maintenance_mode()
    finally:
        engine.dispose()
        db_safety.clear_maintenance_mode()


def test_production_db_with_legacy_double_quoted_default_upgrades_to_head(tmp_path, monkeypatch):
    db_file = tmp_path / "sorour_logistics.db"
    _legacy_production_db(db_file)

    result, maintenance = _startup(db_file, monkeypatch)

    assert result["status"] == "upgraded_successfully", result
    assert result["migration"]["from_revision"] == PRODUCTION_REVISION
    assert result["migration"]["to_revision"] == migration_runner.get_head_revision()
    assert maintenance is False

    conn = sqlite3.connect(db_file)
    try:
        sql = conn.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name='import_files'").fetchone()[0]
        assert "DEFAULT 'NOT_BOOKED'" in sql
        assert '"NOT_BOOKED"' not in sql
        assert conn.execute(
            "SELECT import_file_code, inland_transport_status, is_partial_shipment FROM import_files"
        ).fetchall() == [("IMP-LEGACY-1", "NOT_BOOKED", 0)]
        columns = {row[1] for row in conn.execute("PRAGMA table_info(import_files)")}
        assert set(PARTIAL_SHIPMENT_COLUMNS) <= columns
        assert conn.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
    finally:
        conn.close()


def test_new_rows_still_get_the_not_booked_default_after_upgrade(tmp_path, monkeypatch):
    db_file = tmp_path / "sorour_logistics.db"
    _legacy_production_db(db_file)
    _startup(db_file, monkeypatch)

    conn = sqlite3.connect(db_file)
    try:
        conn.execute("UPDATE import_files SET import_file_code = 'IMP-LEGACY-2'")
        row = list(conn.execute("SELECT * FROM import_files"))[0]
        names = [c[1] for c in conn.execute("PRAGMA table_info(import_files)")]
        data = dict(zip(names, row))
        data.pop("import_file_id")
        data.pop("inland_transport_status")
        data["import_file_code"] = "IMP-NEW-1"
        conn.execute(
            f"INSERT INTO import_files ({', '.join(data)}) VALUES ({', '.join('?' * len(data))})", list(data.values())
        )
        assert conn.execute(
            "SELECT inland_transport_status FROM import_files WHERE import_file_code = 'IMP-NEW-1'"
        ).fetchone() == ("NOT_BOOKED",)
    finally:
        conn.close()


def test_detects_only_double_quoted_defaults():
    import importlib.util

    # Alembic revision files are not importable as a package: load the migration by path.
    path = Path(__file__).resolve().parents[2] / "alembic" / "versions" / "f3a4b5c6d7e8_partial_shipments_linkage.py"
    spec = importlib.util.spec_from_file_location("f3a4_migration", path)
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)

    found = migration._double_quoted_defaults([
        {"name": "inland_transport_status", "type": "VARCHAR(50)", "default": '"NOT_BOOKED"'},
        {"name": "status", "type": "VARCHAR(50)", "default": "'DRAFT'"},
        {"name": "is_partial_shipment", "type": "BOOLEAN", "default": "0"},
        {"name": "notes", "type": "TEXT", "default": None},
    ])
    assert found == {"inland_transport_status": ("VARCHAR(50)", "NOT_BOOKED")}
