"""
DB safety (docs/plans/update-system-plan.md section 0): production_sync.

R7  - frozen build: sync-to-prod / pull-to-dev / restore return 403 "غير متاح في نسخة الإنتاج".
A6  - restore accepts only a bare file name inside the backups folder (no absolute path, no traversal),
      in every build.
A9  - backups use the SQLite online backup API and are verified.
R9/A8 - _cleanup_old_backups only prunes its own psync_* files.

Every test works on tmp_path databases: DEV_DB / PROD_DB / BACKUPS_DIR are monkeypatched.
"""
import os
import sqlite3
import sys
import time
from pathlib import Path

import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base, get_db
import modules.production_sync.service as sync_service
from modules.production_sync.router import router as production_sync_router
from modules.production_sync.service import ProductionSyncService
from modules.production_sync.validators import PRODUCTION_BUILD_BLOCKED_DETAIL
from modules.auth.router import get_current_user
from modules.users.model import User
from utils.db_safety import check_integrity

BLOCKED = PRODUCTION_BUILD_BLOCKED_DETAIL


def _make_db(path: Path, rows=(("alpha",), ("beta",)), wal: bool = False) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    if wal:
        conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("CREATE TABLE IF NOT EXISTS items (id INTEGER PRIMARY KEY, name TEXT)")
    conn.executemany("INSERT INTO items (name) VALUES (?)", rows)
    conn.commit()
    conn.close()
    return path


def _names(path: Path):
    conn = sqlite3.connect(path)
    try:
        return [r[0] for r in conn.execute("SELECT name FROM items ORDER BY id")]
    finally:
        conn.close()


@pytest.fixture
def sandbox(tmp_path, monkeypatch):
    dev_db = _make_db(tmp_path / "dev" / "sorour_logistics.db", rows=(("dev-row",),))
    prod_db = _make_db(tmp_path / "prod" / "sorour_logistics.db", rows=(("prod-row",),))
    backups = tmp_path / "dev" / "backups"
    backups.mkdir()
    monkeypatch.setattr(sync_service, "DEV_DB", dev_db)
    monkeypatch.setattr(sync_service, "PROD_DB", prod_db)
    monkeypatch.setattr(sync_service, "BACKUPS_DIR", backups)
    monkeypatch.setattr(sync_service, "STANDALONE_DIR", prod_db.parent)
    monkeypatch.setattr(sync_service, "ROOT_DIR", tmp_path)
    monkeypatch.setattr(sync_service, "DIST_DIR", tmp_path / "dist")

    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(bind=engine)()
    yield {"dev": dev_db, "prod": prod_db, "backups": backups, "session": session, "engine": engine}
    session.close()
    engine.dispose()


@pytest.fixture
def frozen(monkeypatch, tmp_path):
    monkeypatch.setattr(sys, "frozen", True, raising=False)
    monkeypatch.setattr(sys, "executable", str(tmp_path / "app" / "backend.exe"))


@pytest.fixture
def client(sandbox):
    app = FastAPI()
    app.include_router(production_sync_router)

    def _db():
        yield sandbox["session"]

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[get_current_user] = lambda: User(user_id=1, username="admin-t", role="ADMIN", is_active=True)
    return TestClient(app)


# ---------------------------------------------------------------- R7 (frozen build)

@pytest.mark.parametrize("path", [
    "/api/v1/production-sync/sync-to-prod",
    "/api/v1/production-sync/pull-to-dev",
    "/api/v1/production-sync/restore?filename=x.db&target=prod",
])
def test_frozen_build_blocks_destructive_routes_with_403(client, sandbox, frozen, path):
    before_dev, before_prod = _names(sandbox["dev"]), _names(sandbox["prod"])
    resp = client.post(path)
    assert resp.status_code == 403
    assert resp.json()["detail"] == BLOCKED
    assert _names(sandbox["dev"]) == before_dev
    assert _names(sandbox["prod"]) == before_prod
    assert list(sandbox["backups"].iterdir()) == []


def test_frozen_build_blocks_service_methods_directly(sandbox, frozen):
    service = ProductionSyncService(sandbox["session"])
    for call in (service.sync_dev_to_prod, service.pull_prod_to_dev, lambda: service.restore_backup("x.db", "dev")):
        with pytest.raises(HTTPException) as exc:
            call()
        assert exc.value.status_code == 403
        assert exc.value.detail == BLOCKED


def test_frozen_build_still_allows_verified_backup(client, sandbox, frozen):
    resp = client.post("/api/v1/production-sync/backup?target=dev")
    assert resp.status_code == 201, resp.text
    created = sandbox["backups"] / resp.json()["filename"]
    assert created.name.startswith("psync_")
    assert _names(created) == ["dev-row"]


def test_non_admin_cannot_call_destructive_routes(sandbox):
    app = FastAPI()
    app.include_router(production_sync_router)
    app.dependency_overrides[get_db] = lambda: (yield sandbox["session"])
    app.dependency_overrides[get_current_user] = lambda: User(user_id=2, username="op", role="OPERATOR", is_active=True)
    resp = TestClient(app).post("/api/v1/production-sync/restore?filename=x.db&target=dev")
    assert resp.status_code == 403
    assert resp.json()["detail"] != BLOCKED  # rejected by require_admin, before the service


def test_dev_build_is_not_blocked(sandbox, monkeypatch):
    monkeypatch.delattr(sys, "frozen", raising=False)
    service = ProductionSyncService(sandbox["session"])
    backup = service.create_safety_backup(sandbox["dev"], tag="src")
    result = service.restore_backup(backup.filename, target="dev")
    assert result.success is True


# ---------------------------------------------------------------- A6 restore path escape (all builds)

def test_restore_rejects_absolute_path_even_if_file_exists(sandbox, tmp_path):
    outside = _make_db(tmp_path / "elsewhere" / "evil.db", rows=(("evil",),))
    service = ProductionSyncService(sandbox["session"])
    with pytest.raises(HTTPException) as exc:
        service.restore_backup(str(outside), target="dev")
    assert exc.value.status_code == 400
    assert _names(sandbox["dev"]) == ["dev-row"]


@pytest.mark.parametrize("name", [
    "../prod/sorour_logistics.db",
    "..\\prod\\sorour_logistics.db",
    "C:evil.db",
    "sub/dir.db",
    "..",
    "",
    "backup.txt",
])
def test_restore_rejects_traversal_and_bad_names(sandbox, name):
    service = ProductionSyncService(sandbox["session"])
    with pytest.raises(HTTPException) as exc:
        service.restore_backup(name, target="dev")
    assert exc.value.status_code == 400
    assert _names(sandbox["dev"]) == ["dev-row"]


def test_restore_rejects_unknown_target(sandbox):
    service = ProductionSyncService(sandbox["session"])
    backup = service.create_safety_backup(sandbox["dev"], tag="src")
    with pytest.raises(HTTPException) as exc:
        service.restore_backup(backup.filename, target="../../somewhere")
    assert exc.value.status_code == 400


def test_restore_missing_backup_is_404_over_http(client):
    resp = client.post("/api/v1/production-sync/restore?filename=nope_123.db&target=dev")
    assert resp.status_code == 404


def test_restore_absolute_path_is_400_over_http(client, tmp_path):
    outside = _make_db(tmp_path / "elsewhere" / "evil.db")
    resp = client.post("/api/v1/production-sync/restore", params={"filename": str(outside), "target": "dev"})
    assert resp.status_code == 400


def test_restore_by_name_restores_content_and_takes_protected_safety_copy(sandbox):
    service = ProductionSyncService(sandbox["session"])
    backup = service.create_safety_backup(sandbox["dev"], tag="src")
    conn = sqlite3.connect(sandbox["dev"])
    conn.execute("INSERT INTO items (name) VALUES ('after-backup')")
    conn.commit()
    conn.close()

    result = service.restore_backup(backup.filename, target="dev")

    assert _names(sandbox["dev"]) == ["dev-row"]
    assert check_integrity(sandbox["dev"]) == "ok"
    safety = sandbox["backups"] / result.safety_backup_created
    assert "_pre_restore_" in safety.name
    assert _names(safety) == ["dev-row", "after-backup"]


def test_restore_refuses_corrupt_backup(sandbox):
    bad = sandbox["backups"] / "psync_corrupt.db"
    bad.write_bytes(b"SQLite format 3\x00" + b"\xff" * 4096)
    service = ProductionSyncService(sandbox["session"])
    with pytest.raises(HTTPException) as exc:
        service.restore_backup(bad.name, target="dev")
    assert exc.value.status_code == 400
    assert _names(sandbox["dev"]) == ["dev-row"]


# ---------------------------------------------------------------- A9 online backup

def test_backup_uses_online_api_and_includes_uncheckpointed_wal_data(sandbox):
    wal_db = _make_db(sandbox["dev"].parent / "wal.db", rows=(("one",),), wal=True)
    holder = sqlite3.connect(wal_db)
    holder.execute("PRAGMA wal_autocheckpoint=0;")
    holder.execute("INSERT INTO items (name) VALUES ('only-in-wal')")
    holder.commit()
    try:
        assert Path(f"{wal_db}-wal").stat().st_size > 0
        backup = ProductionSyncService(sandbox["session"]).create_safety_backup(wal_db, tag="manual_dev")
        copy = Path(backup.filepath)
        assert _names(copy) == ["one", "only-in-wal"]
        assert check_integrity(copy) == "ok"
        assert not Path(f"{copy}-wal").exists()
    finally:
        holder.close()


# ---------------------------------------------------------------- R9 / A8 retention

def _touch_db(path: Path, age_seconds: int) -> Path:
    path.write_bytes(b"x")
    ts = time.time() - age_seconds
    os.utime(path, (ts, ts))
    return path


def test_cleanup_never_deletes_other_families_or_protected(sandbox):
    backups = sandbox["backups"]
    foreign = [
        "daily_backup_20200101_000000.db",
        "auto_pre_upgrade_v1.0.0_20200101_000000.db",
        "pre_install_1.0.0_20200101.db",
        "pre_update_1.0.0_20200101.db",
        "pre_migration_1.0.0_20200101.db",
        "pre_restore_20200101.db",
        "sorour_logistics_manual_dev_20200101_000000.db",  # legacy un-prefixed name
    ]
    for i, name in enumerate(foreign):
        _touch_db(backups / name, age_seconds=10_000 + i)
    protected_own = _touch_db(backups / "psync_sorour_logistics_pre_restore_dev_20200101_000000.db", 9_000)
    own = [_touch_db(backups / f"psync_sorour_logistics_manual_dev_2020010{i}_000000.db", 1_000 + i) for i in range(9)]

    removed = ProductionSyncService(sandbox["session"])._cleanup_old_backups(max_keep=1)

    for name in foreign:
        assert (backups / name).exists(), name
    assert protected_own.exists()
    # max_keep=1 is floored at 7: only the 2 oldest own files go.
    assert sorted(removed) == sorted(p.name for p in own[-2:])
    assert sum(p.exists() for p in own) == 7
