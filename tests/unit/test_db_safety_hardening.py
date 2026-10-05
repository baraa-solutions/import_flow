"""
DB safety round 3 (docs/plans/update-system-plan.md section 0):

- installed version comes from version.json next to the executable ("unknown" fallback, never a crash);
  the public installer download route is gone.
- the startup seed creates ONLY the admin (no manager/operator accounts with well-known passwords) and
  never touches existing users.
- stored mailbox passwords are moved to the current key once at startup (idempotent, non-destructive).
- system_observability runtime paths follow app_base_dir() / the live DB (R11).
- /production-sync/check-updates is local-only: no remote_url, no outbound request.
"""
import importlib
import json
import sys
from pathlib import Path
from unittest.mock import patch

import pytest
from cryptography.fernet import Fernet
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import database.master_data_sync_service as mds
import settings
from database.database import Base, DB_PATH, get_db
from database.schema_upgrade_service import SchemaUpgradeService
from modules.auth.router import get_current_user
from modules.auth.security import hash_password, verify_password
from modules.smart_email_listener import crypto as email_crypto
from modules.users.model import User
from utils import db_safety

REPO_ROOT = Path(__file__).resolve().parents[2]
NEW_SECRET = "r" * 64


def _register_all_models() -> None:
    for model_file in sorted((REPO_ROOT / "modules").glob("*/model.py")):
        importlib.import_module(f"modules.{model_file.parent.name}.model")


_register_all_models()


@pytest.fixture
def full_engine(tmp_path):
    engine = create_engine(f"sqlite:///{(tmp_path / 'h.db').as_posix()}")
    Base.metadata.create_all(bind=engine)
    yield engine
    engine.dispose()


# ---------------------------------------------------------------- installed version

@pytest.fixture
def frozen_app(tmp_path, monkeypatch):
    app_dir = tmp_path / "app"
    app_dir.mkdir()
    monkeypatch.setattr(sys, "frozen", True, raising=False)
    monkeypatch.setattr(sys, "executable", str(app_dir / "backend.exe"))
    return app_dir


def test_installed_version_read_next_to_exe(frozen_app):
    (frozen_app / "version.json").write_text(json.dumps({"version": "3.1.4", "build_number": 7}), encoding="utf-8")
    assert db_safety.read_installed_version() == "3.1.4"


@pytest.mark.parametrize("content", [None, "{not json", json.dumps(["x"]), json.dumps({"version": 5}),
                                     json.dumps({"version": "  "})])
def test_installed_version_falls_back_to_unknown(frozen_app, content):
    if content is not None:
        (frozen_app / "version.json").write_text(content, encoding="utf-8")
    assert db_safety.read_installed_version() == db_safety.UNKNOWN_VERSION


def test_main_reports_installed_version_and_has_no_installer_download():
    import main

    client = TestClient(main.app)
    expected = db_safety.read_installed_version()
    assert client.get("/").json()["version"] == expected
    assert client.get("/health").json()["version"] == expected
    assert main.app.version == main.INSTALLED_VERSION
    assert client.get("/api/v1/system/download-installer", follow_redirects=False).status_code == 404
    source = (REPO_ROOT / "main.py").read_text(encoding="utf-8")
    assert '"2.0.3"' not in source


# ---------------------------------------------------------------- admin-only seed

@pytest.fixture
def seed_session(full_engine, tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "ENV_PATH", tmp_path / ".env")
    monkeypatch.setattr(mds, "ADMIN_INITIAL_PASSWORD", "Initial-Admin-1!")
    session = sessionmaker(bind=full_engine)()
    yield session
    session.close()


def test_empty_db_seeds_only_the_admin(seed_session):
    assert mds.MasterDataSyncService(seed_session).sync_system_users() == 1
    users = seed_session.query(User).all()
    assert [u.username for u in users] == ["admin"]
    assert verify_password("Initial-Admin-1!", users[0].hashed_password)
    for name, weak in (("manager", "manager123"), ("operator1", "operator123"), ("operator2", "operator123")):
        assert seed_session.query(User).filter(User.username == name).first() is None


def test_existing_users_are_never_touched_or_added_to(seed_session):
    # An active admin exists (any case): no break-glass admin (users without one: test_break_glass_admin.py).
    boss = User(username="real-boss", email="boss@example.com", full_name="Real Boss",
                hashed_password=hash_password("Their-Own-8"), role="Admin", is_active=True)
    op = User(username="real-operator", email="op@example.com", full_name="Real Op",
              hashed_password=hash_password("Their-Own-9"), role="OPERATOR", is_active=True)
    seed_session.add_all([boss, op])
    seed_session.commit()
    before = (op.user_id, op.hashed_password, op.role, op.email)

    assert mds.MasterDataSyncService(seed_session).sync_system_users() == 0

    assert seed_session.query(User).count() == 2
    seed_session.refresh(op)
    assert (op.user_id, op.hashed_password, op.role, op.email) == before
    assert seed_session.query(User).filter(User.username == "admin").first() is None


def test_seed_code_contains_no_well_known_passwords():
    source = (REPO_ROOT / "database" / "master_data_sync_service.py").read_text(encoding="utf-8")
    assert "manager123" not in source and "operator123" not in source


# ---------------------------------------------------------------- startup mailbox password rotation

def _add_email_rows(session, values):
    from modules.smart_email_listener.model import EmailSettings

    rows = []
    for i, value in enumerate(values):
        row = EmailSettings(email_address=f"m{i}@example.com", username=f"m{i}@example.com")
        row._password = value
        session.add(row)
        rows.append(row)
    session.commit()
    return [r.settings_id for r in rows]


def test_startup_rotation_moves_legacy_and_plaintext_only(full_engine, monkeypatch):
    from modules.smart_email_listener.model import EmailSettings

    monkeypatch.setenv("SECRET_KEY", NEW_SECRET)
    legacy = "enc:" + email_crypto._fernet_for(email_crypto.LEGACY_FALLBACK_SECRET).encrypt(b"legacy-pw").decode()
    current = email_crypto.encrypt_email_password("current-pw")
    foreign = "enc:" + Fernet(Fernet.generate_key()).encrypt(b"x").decode()
    session = sessionmaker(bind=full_engine)()
    ids = _add_email_rows(session, [legacy, "plain-pw", current, foreign, ""])
    session.close()

    assert SchemaUpgradeService._rotate_email_passwords(full_engine) == 2
    assert SchemaUpgradeService._rotate_email_passwords(full_engine) == 0  # idempotent

    session = sessionmaker(bind=full_engine)()
    try:
        rows = {r.settings_id: r for r in session.query(EmailSettings).all()}
        assert email_crypto.is_encrypted_with_current_key(rows[ids[0]]._password)
        assert rows[ids[0]].password == "legacy-pw"
        assert email_crypto.is_encrypted_with_current_key(rows[ids[1]]._password)
        assert rows[ids[1]].password == "plain-pw"
        assert rows[ids[2]]._password == current
        assert rows[ids[3]]._password == foreign  # undecryptable: never destroyed
        assert rows[ids[4]]._password == ""
    finally:
        session.close()


def test_startup_rotation_skips_db_without_email_table(tmp_path):
    engine = create_engine(f"sqlite:///{(tmp_path / 'empty.db').as_posix()}")
    try:
        assert SchemaUpgradeService._rotate_email_passwords(engine) == 0
    finally:
        engine.dispose()


def test_startup_upgrade_reports_rotation(full_engine, tmp_path, monkeypatch):
    class _Noop:
        def __init__(self, session):
            pass

        def sync_all(self):
            return {}

    import database.schema_upgrade_service as sus

    monkeypatch.setattr(sus, "MasterDataSyncService", _Noop)
    monkeypatch.setattr(SchemaUpgradeService, "_get_version_tag", staticmethod(lambda: "9.9.9"))
    monkeypatch.setenv("SECRET_KEY", NEW_SECRET)
    session = sessionmaker(bind=full_engine)()
    _add_email_rows(session, ["plain-pw"])
    session.close()
    db_file = tmp_path / "h.db"
    try:
        res = SchemaUpgradeService.execute_safe_startup_upgrade(
            db_path=str(db_file), target_engine=full_engine, metadata=Base.metadata
        )
    finally:
        db_safety.clear_maintenance_mode()
    assert res["status"] == "upgraded_successfully"
    assert res["email_passwords_rotated"] == 1


# ---------------------------------------------------------------- system_observability paths (R11)

def test_alert_dispatcher_and_daily_report_paths_follow_app_and_db():
    from modules.system_observability import alert_dispatcher, daily_report_service

    live = Path(DB_PATH)
    assert alert_dispatcher.ROOT_DIR == db_safety.app_base_dir()
    assert alert_dispatcher.BACKUPS_DIR == db_safety.backups_dir_for(live)
    assert alert_dispatcher.LOGS_DIR == db_safety.app_base_dir() / "logs"
    assert daily_report_service.ROOT_DIR == db_safety.app_base_dir()
    assert daily_report_service.BACKUPS_DIR == db_safety.backups_dir_for(live)


@pytest.mark.parametrize("rel", [
    "modules/system_observability/service.py",
    "modules/system_observability/alert_dispatcher.py",
    "modules/system_observability/daily_report_service.py",
])
def test_observability_has_no_file_relative_runtime_paths(rel):
    assert "Path(__file__)" not in (REPO_ROOT / rel).read_text(encoding="utf-8")


# ---------------------------------------------------------------- check-updates is local-only

def test_check_updates_ignores_remote_url_and_makes_no_request(full_engine):
    from modules.production_sync.router import router as production_sync_router

    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(bind=engine)()
    app = FastAPI()
    app.include_router(production_sync_router)
    app.dependency_overrides[get_db] = lambda: (yield session)
    app.dependency_overrides[get_current_user] = lambda: User(user_id=1, username="u", role="OPERATOR", is_active=True)
    try:
        with patch("urllib.request.urlopen") as mock_urlopen:
            resp = TestClient(app).get(
                "/api/v1/production-sync/check-updates",
                params={"remote_url": "https://raw.githubusercontent.com/evil/x/main/version.json"},
            )
        mock_urlopen.assert_not_called()
        assert resp.status_code == 200
        data = resp.json()
        assert data["has_update"] is False
        assert data["current_version"] == data["latest_version"]
        assert data["check_status"] == "UP_TO_DATE"
    finally:
        session.close()
        engine.dispose()


@pytest.mark.parametrize("path", ["/api/v1/production-sync/check-update", "/api/v1/production-sync/installer-info"])
def test_legacy_update_endpoints_are_local_only(path):
    from modules.production_sync.router import router as production_sync_router

    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(bind=engine)()
    app = FastAPI()
    app.include_router(production_sync_router)
    app.dependency_overrides[get_db] = lambda: (yield session)
    app.dependency_overrides[get_current_user] = lambda: User(user_id=1, username="u", role="OPERATOR", is_active=True)
    try:
        with patch("urllib.request.urlopen") as mock_urlopen:
            resp = TestClient(app).get(path)
        mock_urlopen.assert_not_called()
        assert resp.status_code == 200
        data = resp.json()
        if path.endswith("check-update"):
            assert data["update_available"] is False
            assert data["latest_version"] == data["current_version"]
            assert data["check_status"] == "no_update"
            assert data["installer_download_url"] is None
        else:
            assert data["is_available"] is False
            assert data["installer_url"] == ""
            assert data["version"]
    finally:
        session.close()
        engine.dispose()


def test_production_sync_service_has_no_outbound_http():
    source = (REPO_ROOT / "modules" / "production_sync" / "service.py").read_text(encoding="utf-8")
    for needle in ("urllib", "urlopen", "api.github.com", "raw.githubusercontent.com", "httpx", "requests."):
        assert needle not in source, needle
