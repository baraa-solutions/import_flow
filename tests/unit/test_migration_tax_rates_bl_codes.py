"""Alembic d9e4f5a6b7c8: tax_rates table + draft B/L blocking_reasons_coded.

Additive and defensive, schema only: a BEHIND DB gets the table and the column, a create_all DB is left as
is, downgrade removes both. The 1% WHT rows come from MasterDataSyncService.sync_tax_rates, which the startup
runs right after the upgrade.
"""
import sqlite3
from pathlib import Path

from alembic import command
from sqlalchemy import create_engine

import main  # noqa: F401  (registers every model on Base.metadata)
from database import migration_runner
from database.database import Base
from database.schema_upgrade_service import SchemaUpgradeService
from utils import db_safety

PREVIOUS = "c8d3e4f5a6b7"
HEAD = "a1b2c3d4e5f6"  # current head; d9e4f5a6b7c8 is the revision under test


def _db(db_file: Path, *, drop_new: bool) -> None:
    engine = create_engine(f"sqlite:///{db_file.as_posix()}")
    try:
        Base.metadata.create_all(bind=engine)
    finally:
        engine.dispose()
    conn = sqlite3.connect(db_file)
    try:
        if drop_new:
            conn.execute("DROP TABLE tax_rates")
            conn.execute('ALTER TABLE "draft_bl_review_sessions" DROP COLUMN "blocking_reasons_coded"')
        conn.execute("CREATE TABLE alembic_version (version_num VARCHAR(32) NOT NULL)")
        conn.execute("INSERT INTO alembic_version (version_num) VALUES (?)", (PREVIOUS,))
        conn.commit()
    finally:
        conn.close()


def _query(db_file: Path, sql: str):
    conn = sqlite3.connect(db_file)
    try:
        return conn.execute(sql).fetchall()
    finally:
        conn.close()


def _tables(db_file: Path):
    return {r[0] for r in _query(db_file, "SELECT name FROM sqlite_master WHERE type='table'")}


def _bl_columns(db_file: Path):
    return {r[1] for r in _query(db_file, 'PRAGMA table_info("draft_bl_review_sessions")')}


def _upgrade(db_file: Path) -> str:
    engine = create_engine(f"sqlite:///{db_file.as_posix()}")
    try:
        return migration_runner.upgrade_to_head(engine)
    finally:
        engine.dispose()


def test_head_is_d9e4():
    # d9e4f5a6b7c8 is no longer the head: e5f6a7b8c9d0 (system_parameters) and f6a7b8c9d0e1 build on it.
    assert migration_runner.get_head_revision() == HEAD


def test_behind_db_gets_table_seed_and_column_then_downgrade_removes_them(tmp_path):
    db_file = tmp_path / "behind.db"
    _db(db_file, drop_new=True)
    assert "tax_rates" not in _tables(db_file)
    assert "blocking_reasons_coded" not in _bl_columns(db_file)

    assert _upgrade(db_file) == HEAD

    assert "blocking_reasons_coded" in _bl_columns(db_file)
    assert "tax_rates" in _tables(db_file)
    assert _query(db_file, "SELECT COUNT(*) FROM tax_rates") == [(0,)]  # schema only

    engine = create_engine(f"sqlite:///{db_file.as_posix()}")
    try:
        with engine.connect() as connection:
            command.downgrade(migration_runner.build_alembic_config(connection), PREVIOUS)
            connection.commit()
    finally:
        engine.dispose()
    assert "tax_rates" not in _tables(db_file)
    assert "blocking_reasons_coded" not in _bl_columns(db_file)


def test_create_all_db_upgrade_keeps_existing_rates(tmp_path):
    db_file = tmp_path / "created.db"
    _db(db_file, drop_new=False)
    conn = sqlite3.connect(db_file)
    try:
        conn.execute(
            "INSERT INTO tax_rates (tax_code, rate_percent, effective_from, is_active) "
            "VALUES ('WHT_CLEARANCE_SERVICES', 3, '2026-01-01', 1)"
        )
        conn.commit()
    finally:
        conn.close()

    assert _upgrade(db_file) == HEAD

    rows = _query(db_file, "SELECT tax_code, rate_percent FROM tax_rates")
    assert [(r[0], float(r[1])) for r in rows] == [("WHT_CLEARANCE_SERVICES", 3.0)]


def test_startup_on_a_behind_db_seeds_the_one_percent_rates(tmp_path, monkeypatch):
    db_file = tmp_path / "sorour_logistics.db"
    _db(db_file, drop_new=True)
    db_safety.clear_maintenance_mode()
    monkeypatch.setattr(SchemaUpgradeService, "_get_version_tag", staticmethod(lambda: "9.9.9"))
    engine = create_engine(f"sqlite:///{db_file.as_posix()}")
    try:
        res = SchemaUpgradeService.execute_safe_startup_upgrade(
            db_path=str(db_file), target_engine=engine, metadata=Base.metadata
        )
    finally:
        engine.dispose()
        db_safety.clear_maintenance_mode()

    assert res["status"] == "upgraded_successfully", res
    assert res["migration"]["to_revision"] == HEAD
    assert res["master_data_summary"]["tax_rates_added"] == 2
    rows = _query(db_file, "SELECT tax_code, rate_percent, effective_from, effective_to FROM tax_rates ORDER BY tax_code")
    assert [(r[0], float(r[1]), r[2][:10], r[3]) for r in rows] == [
        ("WHT_CLEARANCE_SERVICES", 1.0, "2000-01-01", None),
        ("WHT_TRANSPORT_SERVICES", 1.0, "2000-01-01", None),
    ]
