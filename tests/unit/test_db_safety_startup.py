"""
DB safety (docs/plans/update-system-plan.md section 0): startup schema upgrade.

A10 - snapshot next to the DB, only when the version changed, verified (online backup + integrity_check).
A11/R8 - a failed snapshot or DDL enters maintenance mode: nothing further is written and non-GET
         requests get 503 (except health / auth / system).
All tests use tmp_path databases.
"""
import os
import sqlite3
import subprocess
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import Column, Integer, MetaData, String, Table, create_engine

import database.schema_upgrade_service as sus
from database.schema_upgrade_service import SchemaUpgradeService
from utils import db_safety
from utils.db_safety import BackupVerificationError, MAINTENANCE_DETAIL

REPO_ROOT = Path(__file__).resolve().parents[2]


class _NoopMasterData:
    def __init__(self, session):
        pass

    def sync_all(self):
        return {"status": "stub"}


@pytest.fixture(autouse=True)
def _isolate(monkeypatch):
    db_safety.clear_maintenance_mode()
    monkeypatch.setattr(sus, "MasterDataSyncService", _NoopMasterData)
    yield
    db_safety.clear_maintenance_mode()


def _seed_db(path: Path) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    conn.execute("CREATE TABLE widgets (id INTEGER PRIMARY KEY, name TEXT)")
    conn.execute("INSERT INTO widgets (name) VALUES ('keep-me')")
    conn.commit()
    conn.close()
    return path


def _metadata_v2() -> MetaData:
    md = MetaData()
    Table("widgets", md, Column("id", Integer, primary_key=True), Column("name", String), Column("color", String))
    Table("gadgets", md, Column("id", Integer, primary_key=True))
    return md


def _run(db_file: Path, version: str, monkeypatch, metadata=None, **kwargs):
    monkeypatch.setattr(SchemaUpgradeService, "_get_version_tag", staticmethod(lambda: version))
    engine = create_engine(f"sqlite:///{db_file.as_posix()}")
    try:
        return SchemaUpgradeService.execute_safe_startup_upgrade(
            db_path=str(db_file), target_engine=engine, metadata=metadata or _metadata_v2(), **kwargs
        )
    finally:
        engine.dispose()


def _tables(db_file: Path):
    conn = sqlite3.connect(db_file)
    try:
        return {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}
    finally:
        conn.close()


def test_snapshot_goes_next_to_the_db(tmp_path, monkeypatch):
    db_file = _seed_db(tmp_path / "data" / "sorour_logistics.db")
    res = _run(db_file, "2.0.0", monkeypatch)
    assert res["status"] == "upgraded_successfully"
    snapshot = tmp_path / "data" / "backups" / res["backup_created"]
    assert snapshot.exists()
    assert db_safety.check_integrity(snapshot) == "ok"
    conn = sqlite3.connect(snapshot)
    assert conn.execute("SELECT name FROM widgets").fetchall() == [("keep-me",)]
    conn.close()


def test_snapshot_only_on_version_change(tmp_path, monkeypatch):
    db_file = _seed_db(tmp_path / "sorour_logistics.db")
    backups = tmp_path / "backups"
    first = _run(db_file, "2.0.0", monkeypatch)
    second = _run(db_file, "2.0.0", monkeypatch)
    third = _run(db_file, "2.0.1", monkeypatch)
    assert first["backup_created"] and first["previous_version"] is None
    assert second["backup_created"] is None and second["previous_version"] == "2.0.0"
    assert third["backup_created"] and third["previous_version"] == "2.0.0"
    assert len(list(backups.glob("auto_pre_upgrade_*.db"))) == 2


def test_no_snapshot_for_empty_or_missing_db(tmp_path, monkeypatch):
    db_file = tmp_path / "fresh.db"
    res = _run(db_file, "2.0.0", monkeypatch)
    assert res["status"] == "upgraded_successfully"
    assert res["backup_created"] is None


def test_additive_upgrade_preserves_rows(tmp_path, monkeypatch):
    db_file = _seed_db(tmp_path / "sorour_logistics.db")
    res = _run(db_file, "2.0.0", monkeypatch)
    assert "widgets.color" in res["columns_added"]
    assert "gadgets" in res["tables_added"]
    conn = sqlite3.connect(db_file)
    assert conn.execute("SELECT name FROM widgets").fetchall() == [("keep-me",)]
    conn.close()
    assert db_safety.is_maintenance_mode() is False


def test_snapshot_verification_failure_enters_maintenance_and_writes_nothing(tmp_path, monkeypatch):
    db_file = _seed_db(tmp_path / "sorour_logistics.db")

    def _bad_backup(src, dest, **kw):
        raise BackupVerificationError("integrity_check failed: simulated")

    monkeypatch.setattr(sus, "sqlite_online_backup", _bad_backup)
    res = _run(db_file, "2.0.0", monkeypatch)
    assert res["status"] == "maintenance_mode"
    assert db_safety.is_maintenance_mode() is True
    assert "gadgets" not in _tables(db_file)  # no DDL after a failed snapshot
    assert not (tmp_path / "backups" / ".last_seen_version.json").exists()


def test_corrupt_db_enters_maintenance(tmp_path, monkeypatch):
    db_file = tmp_path / "sorour_logistics.db"
    db_file.write_bytes(b"SQLite format 3\x00" + b"\xff" * 8192)
    res = _run(db_file, "2.0.0", monkeypatch)
    assert res["status"] == "maintenance_mode"
    assert db_safety.is_maintenance_mode() is True
    assert list((tmp_path / "backups").glob("auto_pre_upgrade_*.db")) == []


def test_column_differing_only_in_case_is_not_re_added(tmp_path, monkeypatch):
    db_file = tmp_path / "sorour_logistics.db"
    conn = sqlite3.connect(db_file)
    conn.execute("CREATE TABLE widgets (id INTEGER PRIMARY KEY, Name TEXT)")
    conn.commit()
    conn.close()
    md = MetaData()
    Table("widgets", md, Column("id", Integer, primary_key=True), Column("name", String))
    res = _run(db_file, "2.0.0", monkeypatch, metadata=md)
    assert res["status"] == "upgraded_successfully"
    assert res["columns_added"] == []
    assert db_safety.is_maintenance_mode() is False


def test_failed_alter_enters_maintenance(tmp_path, monkeypatch):
    """A genuinely failing ALTER: the engine opens the DB read-only, so ADD COLUMN is rejected by SQLite."""
    db_file = _seed_db(tmp_path / "sorour_logistics.db")
    md = MetaData()
    Table("widgets", md, Column("id", Integer, primary_key=True), Column("name", String), Column("color", String))
    monkeypatch.setattr(SchemaUpgradeService, "_get_version_tag", staticmethod(lambda: "2.0.0"))
    ro_engine = create_engine(f"sqlite:///file:{db_file.as_posix()}?mode=ro&uri=true")
    try:
        res = SchemaUpgradeService.execute_safe_startup_upgrade(
            db_path=str(db_file), target_engine=ro_engine, metadata=md
        )
    finally:
        ro_engine.dispose()
    assert res["status"] == "maintenance_mode"
    assert "widgets.color" in res["error"]
    assert db_safety.is_maintenance_mode() is True
    conn = sqlite3.connect(db_file)
    try:
        cols = [r[1] for r in conn.execute("PRAGMA table_info(widgets)")]
    finally:
        conn.close()
    assert "color" not in cols


def test_create_all_failure_enters_maintenance(tmp_path, monkeypatch):
    db_file = _seed_db(tmp_path / "sorour_logistics.db")

    class _BrokenMetadata:
        tables = {}

        def create_all(self, bind):
            raise RuntimeError("simulated DDL failure")

    res = _run(db_file, "2.0.0", monkeypatch, metadata=_BrokenMetadata())
    assert res["status"] == "maintenance_mode"
    assert "simulated DDL failure" in res["error"]


def test_master_data_failure_is_logged_but_does_not_block_writes(tmp_path, monkeypatch):
    class _Boom(_NoopMasterData):
        def sync_all(self):
            raise RuntimeError("seed failure")

    monkeypatch.setattr(sus, "MasterDataSyncService", _Boom)
    db_file = _seed_db(tmp_path / "sorour_logistics.db")
    res = _run(db_file, "2.0.0", monkeypatch)
    assert res["status"] == "upgraded_successfully"
    assert res["master_data_error"] == "seed failure"
    assert db_safety.is_maintenance_mode() is False


# ---------------------------------------------------------------- maintenance middleware

@pytest.mark.parametrize("method,path,allowed", [
    ("GET", "/api/v1/import-files", True),
    ("POST", "/api/v1/import-files", False),
    ("PUT", "/api/v1/suppliers/1", False),
    ("DELETE", "/api/v1/suppliers/1", False),
    ("POST", "/api/v1/auth/login", True),
    ("POST", "/api/v1/auth/refresh", True),
    ("POST", "/api/v1/auth/logout", True),
    ("POST", "/api/v1/auth/logout/", True),
    ("POST", "/api/v1/auth/register", False),
    ("PATCH", "/api/v1/auth/users/5", False),
    ("PATCH", "/api/v1/auth/users/5/toggle-status", False),
    ("PUT", "/api/v1/auth/users/5/permissions", False),
    ("POST", "/api/v1/auth/login-anything", False),
    ("POST", "/api/v1/system/version", False),
    ("POST", "/api/v1/system/anything", False),
    ("GET", "/api/v1/system/version", True),
    ("HEAD", "/api/v1/suppliers", True),
    ("OPTIONS", "/api/v1/suppliers", True),
    ("POST", "/health", True),
    ("POST", "/api/v1/health", True),
    ("POST", "/api/v1/shutdown", True),
    ("POST", "/api/v1/app-update/check", True),
    ("POST", "/api/v1/app-update-evil", False),
])
def test_maintenance_allow_list(method, path, allowed):
    assert db_safety.is_request_allowed_in_maintenance(method, path) is allowed


def test_main_app_returns_503_for_writes_in_maintenance():
    import main

    client = TestClient(main.app)
    db_safety.enter_maintenance_mode("test")
    blocked = client.post("/api/v1/production-sync/backup?target=dev")
    assert blocked.status_code == 503
    assert blocked.json()["detail"] == MAINTENANCE_DETAIL
    assert client.get("/api/v1/system/version").status_code == 200
    assert client.post("/api/v1/auth/login", json={}).status_code != 503
    assert client.post("/api/v1/auth/register", json={}).status_code == 503
    assert client.post("/api/v1/__no_such_route__").status_code == 503
    db_safety.clear_maintenance_mode()
    assert client.post("/api/v1/__no_such_route__").status_code == 404


def test_import_main_on_corrupt_db_boots_in_maintenance_mode(tmp_path):
    """End-to-end: `import main` on an unreadable DB must not crash nor continue writing."""
    db_file = tmp_path / "sorour_logistics.db"
    db_file.write_bytes(b"SQLite format 3\x00" + b"\xff" * 8192)
    before = db_file.read_bytes()
    env = {k: v for k, v in os.environ.items() if k not in ("DATABASE_URL",)}
    env["DATABASE_PATH"] = str(db_file)
    env["SECRET_KEY"] = "subprocess-secret-key-0123456789abcdef-xyz"
    env["ADMIN_INITIAL_PASSWORD"] = "Subprocess-Admin-1!"
    code = "import main; print('MAINT=' + str(main.is_maintenance_mode()))"
    proc = subprocess.run(
        [sys.executable, "-c", code], cwd=str(REPO_ROOT), env=env,
        capture_output=True, text=True, timeout=600,
    )
    assert "MAINT=True" in proc.stdout, proc.stdout[-2000:] + proc.stderr[-2000:]
    assert db_file.read_bytes() == before
