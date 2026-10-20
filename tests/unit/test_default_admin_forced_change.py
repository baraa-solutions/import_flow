"""
Default admin on a new installation + forced password change on first login (CTO decision 2026-09-29).

- An empty users table is seeded with admin / settings.DEFAULT_ADMIN_PASSWORD ("Admin@123") and
  must_change_password=True. Nothing is seeded (or touched) when an active admin exists (users without any
  active admin get a break-glass admin: tests/unit/test_break_glass_admin.py).
- While must_change_password is true, every token-authenticated route answers
  403 {"code": "PASSWORD_CHANGE_REQUIRED", ...} except login / refresh / me / me/permissions / logout /
  me/change-password. The check lives in the shared auth dependencies (get_current_user and
  require_permission), so router-level and permission-only routes are both covered.
- POST /api/v1/auth/me/change-password verifies the current password, rejects same / weak passwords and
  clears the flag.
- Alembic f7a1c3e5b9d2 adds users.must_change_password (NOT NULL, default 0) to a DB at e1f2a3b4c5d6.
"""
import importlib
import sqlite3
from pathlib import Path

import pytest
from fastapi import APIRouter, Depends, FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import database.master_data_sync_service as mds
import database.models  # noqa: F401 - registers every model in Base.metadata
import database.schema_upgrade_service as sus
import modules.auth.permissions as auth_permissions
import settings
from database import migration_runner
from database.database import Base, get_db
from database.migration_runner import BASELINE_REVISION
from database.schema_upgrade_service import SchemaUpgradeService
from modules.audit_logs.model import AuditLog
from modules.auth.permissions import (
    MSG_PASSWORD_CHANGE_REQUIRED,
    PASSWORD_CHANGE_REQUIRED_CODE,
    invalidate_permission_cache,
)
from modules.auth.rate_limiter import login_limiter
from modules.auth.router import get_current_user, require_admin
from modules.auth.security import create_access_token, hash_password, verify_password
from modules.auth.seed_rbac import seed_rbac
from modules.auth.service import MSG_CURRENT_PASSWORD_WRONG, MSG_NEW_PASSWORD_SAME
from modules.users.model import Role, User
from utils import db_safety

auth_router_module = importlib.import_module("modules.auth.router")
currencies_router_module = importlib.import_module("modules.currencies.router")
purchase_orders_router_module = importlib.import_module("modules.purchase_orders.router")

HEAD_REVISION = "c9d0e1f2a3b4"  # current head (users.token_version BEX-T08)
DEFAULT_PASSWORD = "Admin@123"
NEW_PASSWORD = "Sorour-Admin-2026"
CHANGE_URL = "/api/v1/auth/me/change-password"
FORCED_DETAIL = {"code": "PASSWORD_CHANGE_REQUIRED", "message": "يجب تغيير كلمة المرور قبل المتابعة."}


# ─── Seeder ──────────────────────────────────────────────────────────────────

def test_default_admin_password_constant_and_env_override(monkeypatch):
    assert settings.DEFAULT_ADMIN_PASSWORD == DEFAULT_PASSWORD
    monkeypatch.delenv("ADMIN_INITIAL_PASSWORD", raising=False)
    assert settings.resolve_admin_initial_password(is_production_build=False) == DEFAULT_PASSWORD
    monkeypatch.setenv("ADMIN_INITIAL_PASSWORD", "")
    assert settings.resolve_admin_initial_password(is_production_build=False) == DEFAULT_PASSWORD
    monkeypatch.setenv("ADMIN_INITIAL_PASSWORD", "Override-Admin-1")
    assert settings.resolve_admin_initial_password(is_production_build=False) == "Override-Admin-1"


def test_frozen_build_always_seeds_the_default_despite_env(monkeypatch):
    """An old 2.1.x .env holds a random ADMIN_INITIAL_PASSWORD: the frozen build ignores it for seeding."""
    monkeypatch.setenv("ADMIN_INITIAL_PASSWORD", "Random-From-2.1.x-9")
    assert settings.resolve_admin_initial_password(is_production_build=True) == DEFAULT_PASSWORD
    monkeypatch.delenv("ADMIN_INITIAL_PASSWORD", raising=False)
    assert settings.resolve_admin_initial_password(is_production_build=True) == DEFAULT_PASSWORD


@pytest.fixture
def users_session(tmp_path, monkeypatch):
    env_file = tmp_path / ".env"
    env_file.write_text("SECRET_KEY=" + "s" * 40 + "\n", encoding="utf-8")
    monkeypatch.setattr(settings, "ENV_PATH", env_file)
    # The value an installation without ADMIN_INITIAL_PASSWORD in env/.env resolves to.
    monkeypatch.setattr(mds, "ADMIN_INITIAL_PASSWORD", settings.DEFAULT_ADMIN_PASSWORD)
    engine = create_engine(f"sqlite:///{(tmp_path / 'users.db').as_posix()}")
    Base.metadata.create_all(bind=engine, tables=[Role.__table__, User.__table__])
    session = sessionmaker(bind=engine)()
    yield session, env_file
    session.close()
    engine.dispose()


def test_empty_users_table_seeds_admin_with_default_password_and_forced_change(users_session):
    session, env_file = users_session
    env_before = env_file.read_text(encoding="utf-8")

    assert mds.MasterDataSyncService(session).sync_system_users() == 1

    users = session.query(User).all()
    assert [u.username for u in users] == ["admin"]
    admin = users[0]
    assert admin.must_change_password is True
    assert admin.role == "ADMIN" and admin.is_active is True
    assert verify_password(DEFAULT_PASSWORD, admin.hashed_password)
    assert env_file.read_text(encoding="utf-8") == env_before  # the password is never written to .env


def test_no_seed_and_no_change_when_any_user_exists(users_session):
    session, _ = users_session
    existing = User(username="real-admin", email="ra@example.com", full_name="Real Admin",
                    hashed_password=hash_password("Their-Own-99"), role="ADMIN", is_active=True)
    session.add(existing)
    session.commit()
    before = (existing.hashed_password, existing.must_change_password, existing.updated_at)

    assert mds.MasterDataSyncService(session).sync_system_users() == 0
    assert mds.MasterDataSyncService(session).sync_system_users() == 0

    assert session.query(User).count() == 1
    session.refresh(existing)
    assert (existing.hashed_password, existing.must_change_password, existing.updated_at) == before
    assert existing.must_change_password is False


def test_seeded_admin_is_not_reseeded_after_password_change(users_session):
    session, _ = users_session
    mds.MasterDataSyncService(session).sync_system_users()
    admin = session.query(User).one()
    admin.hashed_password = hash_password(NEW_PASSWORD)
    admin.must_change_password = False
    session.commit()

    assert mds.MasterDataSyncService(session).sync_system_users() == 0
    session.refresh(admin)
    assert admin.must_change_password is False
    assert verify_password(NEW_PASSWORD, admin.hashed_password)


# ─── API: enforcement and change-password ───────────────────────────────────

_probe_router = APIRouter(prefix="/api/v1/probe", dependencies=[Depends(get_current_user)])


@_probe_router.get("/admin-only")
def _admin_only(user: User = Depends(require_admin)):
    return {"ok": True}


@pytest.fixture
def api(monkeypatch):
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine)
    seed = factory()
    seed_rbac(seed)
    seed.close()

    def _get_db():
        session = factory()
        try:
            yield session
        finally:
            session.close()

    app = FastAPI()
    app.include_router(auth_router_module.router)
    app.include_router(currencies_router_module.router)
    app.include_router(purchase_orders_router_module.router)
    app.include_router(_probe_router)
    app.dependency_overrides[get_db] = _get_db

    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", False)
    invalidate_permission_cache()
    login_limiter.reset_all()
    yield app, factory
    login_limiter.reset_all()
    invalidate_permission_cache()
    engine.dispose()


def _seed_default_admin(factory) -> int:
    session = factory()
    try:
        role = session.query(Role).filter(Role.role_code == "ADMIN").one()
        admin = User(username="admin", email="admin@sorourlogistics.com", full_name="System Admin",
                     hashed_password=hash_password(DEFAULT_PASSWORD), role="ADMIN", role_id=role.role_id,
                     is_active=True, must_change_password=True)
        session.add(admin)
        session.commit()
        return admin.user_id
    finally:
        session.close()


def _login(client: TestClient, password: str = DEFAULT_PASSWORD):
    res = client.post("/api/v1/auth/login", json={"username_or_email": "admin", "password": password})
    assert res.status_code == 200, res.text
    return res.json()


@pytest.fixture
def forced_client(api):
    app, factory = api
    user_id = _seed_default_admin(factory)
    client = TestClient(app)
    body = _login(client)
    client.headers.update({"Authorization": f"Bearer {body['access_token']}"})
    return client, factory, user_id, body


def test_login_returns_the_flag(forced_client):
    _, _, _, body = forced_client
    assert body["user"]["must_change_password"] is True
    assert body["user"]["username"] == "admin"


@pytest.mark.parametrize("method,path", [
    ("GET", "/api/v1/currencies"),             # router-level get_current_user
    ("GET", "/api/v1/purchase-orders"),        # router-level get_current_user + require_permission
    ("GET", "/api/v1/auth/users"),             # require_permission only (auth router has no router dep)
    ("POST", "/api/v1/auth/register"),         # write route: blocked before body validation
    ("PATCH", "/api/v1/auth/users/1"),         # admin editing users (incl. itself) is blocked too
    ("GET", "/api/v1/probe/admin-only"),       # require_admin
])
def test_normal_routes_answer_403_password_change_required(forced_client, method, path):
    client = forced_client[0]
    res = client.request(method, path, json={} if method in ("POST", "PATCH") else None)
    assert res.status_code == 403, res.text
    assert res.json()["detail"] == FORCED_DETAIL


def test_forced_detail_constants():
    assert PASSWORD_CHANGE_REQUIRED_CODE == FORCED_DETAIL["code"]
    assert MSG_PASSWORD_CHANGE_REQUIRED == FORCED_DETAIL["message"]


def test_exempt_routes_work_while_change_is_required(forced_client):
    client, _, user_id, _ = forced_client
    me = client.get("/api/v1/auth/me")
    assert me.status_code == 200
    assert me.json()["must_change_password"] is True
    perms = client.get("/api/v1/auth/me/permissions")
    assert perms.status_code == 200 and perms.json()["user_id"] == user_id
    refreshed = client.post("/api/v1/auth/refresh")
    assert refreshed.status_code == 200
    assert refreshed.json()["user"]["must_change_password"] is True
    # BEX-T08: refresh revokes the old token, so logout uses the refreshed one.
    client.headers.update({"Authorization": f"Bearer {refreshed.json()['access_token']}"})
    assert client.post("/api/v1/auth/logout").status_code == 200


def test_change_password_success_clears_flag_and_unlocks_routes(forced_client):
    client, factory, user_id, _ = forced_client
    assert client.get("/api/v1/currencies").status_code == 403

    res = client.post(CHANGE_URL, json={"current_password": DEFAULT_PASSWORD, "new_password": NEW_PASSWORD})
    assert res.status_code == 200, res.text
    body = res.json()
    assert body["must_change_password"] is False
    assert body["user_id"] == user_id and body["username"] == "admin"

    # BEX-T08: the password change bumps token_version; the response carries the new token, which works everywhere.
    assert body["access_token"]
    client.headers.update({"Authorization": f"Bearer {body['access_token']}"})
    assert client.get("/api/v1/currencies").status_code == 200
    assert client.get("/api/v1/purchase-orders").status_code == 200
    assert client.get("/api/v1/auth/users").status_code == 200
    assert client.get("/api/v1/probe/admin-only").status_code == 200

    session = factory()
    try:
        admin = session.get(User, user_id)
        assert admin.must_change_password is False
        assert verify_password(NEW_PASSWORD, admin.hashed_password)
        assert not verify_password(DEFAULT_PASSWORD, admin.hashed_password)
        log = session.query(AuditLog).filter(AuditLog.entity_type == "User", AuditLog.entity_id == user_id).all()
        assert len(log) == 1
        dump = " ".join(str(v) for v in vars(log[0]).values())
        assert NEW_PASSWORD not in dump and DEFAULT_PASSWORD not in dump
        assert "hashed_password" not in dump
    finally:
        session.close()

    # A fresh login with the new password reports the flag cleared; the old one is refused.
    fresh = TestClient(client.app)
    assert _login(fresh, NEW_PASSWORD)["user"]["must_change_password"] is False
    old = fresh.post("/api/v1/auth/login", json={"username_or_email": "admin", "password": DEFAULT_PASSWORD})
    assert old.status_code == 401


@pytest.mark.parametrize("current,new,expected", [
    ("Wrong-Password-1", NEW_PASSWORD, MSG_CURRENT_PASSWORD_WRONG),
    ("", NEW_PASSWORD, MSG_CURRENT_PASSWORD_WRONG),
    (DEFAULT_PASSWORD, DEFAULT_PASSWORD, MSG_NEW_PASSWORD_SAME),
    (DEFAULT_PASSWORD, "short1", "كلمة المرور يجب أن تتكون من 8 أحرف على الأقل."),
    (DEFAULT_PASSWORD, "onlyletters", "كلمة المرور يجب أن تحتوي على رقم واحد على الأقل."),
    (DEFAULT_PASSWORD, "12345678", "كلمة المرور يجب أن تحتوي على حرف أبجدي واحد على الأقل."),
])
def test_change_password_rejections_keep_the_flag(forced_client, current, new, expected):
    client, factory, user_id, _ = forced_client
    res = client.post(CHANGE_URL, json={"current_password": current, "new_password": new})
    assert res.status_code == 400
    assert res.json()["detail"] == expected
    assert client.get("/api/v1/currencies").status_code == 403
    session = factory()
    try:
        admin = session.get(User, user_id)
        assert admin.must_change_password is True
        assert verify_password(DEFAULT_PASSWORD, admin.hashed_password)
    finally:
        session.close()


def test_change_password_body_is_validated(forced_client):
    client = forced_client[0]
    assert client.post(CHANGE_URL, json={"current_password": DEFAULT_PASSWORD}).status_code == 422


def test_change_password_requires_authentication(api):
    app, factory = api
    _seed_default_admin(factory)
    res = TestClient(app).post(CHANGE_URL, json={"current_password": DEFAULT_PASSWORD, "new_password": NEW_PASSWORD})
    assert res.status_code == 401


def test_regular_user_without_flag_is_unaffected_and_can_change_password(api):
    app, factory = api
    session = factory()
    role = session.query(Role).filter(Role.role_code == "LOGISTICS_OPERATOR").one()
    user = User(username="op", email="op@example.com", full_name="Op", hashed_password=hash_password("Operator-123"),
                role=role.role_code, role_id=role.role_id, is_active=True)
    session.add(user)
    session.commit()
    assert user.must_change_password is False
    token = create_access_token({"sub": str(user.user_id), "username": "op", "role": role.role_code})
    session.close()

    client = TestClient(app, headers={"Authorization": f"Bearer {token}"})
    assert client.get("/api/v1/currencies").status_code == 200
    assert client.get("/api/v1/auth/me").json()["must_change_password"] is False
    res = client.post(CHANGE_URL, json={"current_password": "Operator-123", "new_password": "Operator-456"})
    assert res.status_code == 200 and res.json()["must_change_password"] is False
    client.headers.update({"Authorization": f"Bearer {res.json()['access_token']}"})  # BEX-T08: new token version
    # No extra permission is needed, but a permission-gated route still checks the permission.
    assert client.get("/api/v1/auth/users").status_code == 403
    assert client.get("/api/v1/auth/users").json()["detail"] != FORCED_DETAIL


def test_dev_bypass_user_is_not_forced(api, monkeypatch):
    """No Authorization header + ALLOW_DEV_AUTH_BYPASS (dev only, forced off in the frozen build): the
    request is not authenticated, so the forced change does not apply (keeps the test seam working)."""
    app, factory = api
    _seed_default_admin(factory)
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", True)
    assert TestClient(app).get("/api/v1/currencies").status_code == 200


# ─── Migration ───────────────────────────────────────────────────────────────

class _NoMasterData:
    def __init__(self, session):
        pass

    def sync_all(self):
        return {"status": "stub"}


def _db_at_baseline_without_column(db_file: Path) -> None:
    engine = create_engine(f"sqlite:///{db_file.as_posix()}")
    try:
        Base.metadata.create_all(bind=engine)
    finally:
        engine.dispose()
    conn = sqlite3.connect(db_file)
    try:
        conn.execute("ALTER TABLE users DROP COLUMN must_change_password")
        conn.execute(
            "INSERT INTO users (username, email, hashed_password, full_name, role, is_active, created_at, updated_at) "
            "VALUES ('old-admin', 'old@example.com', 'x', 'Old Admin', 'ADMIN', 1, '2026-01-01', '2026-01-01')"
        )
        conn.execute("CREATE TABLE alembic_version (version_num VARCHAR(32) NOT NULL)")
        conn.execute("INSERT INTO alembic_version (version_num) VALUES (?)", (BASELINE_REVISION,))
        conn.commit()
    finally:
        conn.close()


def _users_columns(db_file: Path):
    conn = sqlite3.connect(db_file)
    try:
        return {row[1]: row for row in conn.execute("PRAGMA table_info(users)")}
    finally:
        conn.close()


def test_head_is_the_new_revision_after_the_baseline():
    assert BASELINE_REVISION == "e1f2a3b4c5d6"
    assert migration_runner.get_head_revision() == HEAD_REVISION


def test_upgrade_from_baseline_adds_column_with_false(tmp_path, monkeypatch):
    db_safety.clear_maintenance_mode()
    monkeypatch.setattr(sus, "MasterDataSyncService", _NoMasterData)
    monkeypatch.setattr(SchemaUpgradeService, "_get_version_tag", staticmethod(lambda: "9.9.9"))
    db_file = tmp_path / "sorour_logistics.db"
    _db_at_baseline_without_column(db_file)
    assert "must_change_password" not in _users_columns(db_file)

    engine = create_engine(f"sqlite:///{db_file.as_posix()}")
    try:
        res = SchemaUpgradeService.execute_safe_startup_upgrade(
            db_path=str(db_file), target_engine=engine, metadata=Base.metadata
        )
    finally:
        engine.dispose()
        db_safety.clear_maintenance_mode()

    assert res["status"] == "upgraded_successfully", res
    assert res["migration"]["action"] == "upgraded"
    assert res["migration"]["from_revision"] == BASELINE_REVISION
    assert res["migration"]["to_revision"] == HEAD_REVISION
    assert "users.must_change_password" not in res["columns_added"]  # Alembic added it, not the ALTER fallback
    column = _users_columns(db_file)["must_change_password"]
    assert column[3] == 1                      # NOT NULL
    assert str(column[4]).strip("'\"") == "0"  # server default
    conn = sqlite3.connect(db_file)
    try:
        assert conn.execute("SELECT must_change_password FROM users WHERE username='old-admin'").fetchone() == (0,)
        assert conn.execute("SELECT version_num FROM alembic_version").fetchall() == [(HEAD_REVISION,)]
    finally:
        conn.close()


def test_upgrade_is_a_no_op_when_the_column_already_exists(tmp_path):
    db_file = tmp_path / "created.db"
    engine = create_engine(f"sqlite:///{db_file.as_posix()}")
    try:
        Base.metadata.create_all(bind=engine)
        conn = sqlite3.connect(db_file)
        conn.execute("CREATE TABLE alembic_version (version_num VARCHAR(32) NOT NULL)")
        conn.execute("INSERT INTO alembic_version (version_num) VALUES (?)", (BASELINE_REVISION,))
        conn.commit()
        conn.close()
        before = _users_columns(db_file)
        assert migration_runner.upgrade_to_head(engine) == HEAD_REVISION
    finally:
        engine.dispose()
    assert _users_columns(db_file) == before



# ─── Review follow-ups ───────────────────────────────────────────────────────

def test_unstamped_legacy_db_gets_not_null_default_column_and_login_works(tmp_path, monkeypatch):
    """UNSTAMPED legacy DB (no alembic_version) whose users table lacks the column: step 4b adds it with
    NOT NULL DEFAULT 0, so existing users read False and login answers 200 (no NULL -> 500)."""
    db_safety.clear_maintenance_mode()
    monkeypatch.setattr(sus, "MasterDataSyncService", _NoMasterData)
    monkeypatch.setattr(SchemaUpgradeService, "_get_version_tag", staticmethod(lambda: "9.9.9"))
    db_file = tmp_path / "sorour_logistics.db"
    _db_at_baseline_without_column(db_file)
    conn = sqlite3.connect(db_file)
    conn.execute("DROP TABLE alembic_version")
    conn.execute("UPDATE users SET hashed_password = ? WHERE username = 'old-admin'", (hash_password("Legacy-Pass-1"),))
    conn.commit()
    conn.close()

    engine = create_engine(f"sqlite:///{db_file.as_posix()}", connect_args={"check_same_thread": False})
    try:
        res = SchemaUpgradeService.execute_safe_startup_upgrade(
            db_path=str(db_file), target_engine=engine, metadata=Base.metadata
        )
        assert res["status"] == "upgraded_successfully", res
        assert res["migration"]["state"] == "unstamped"
        assert "users.must_change_password" in res["columns_added"]
        column = _users_columns(db_file)["must_change_password"]
        assert column[3] == 1 and str(column[4]).strip("'\"") == "0"
        raw = sqlite3.connect(db_file)
        assert raw.execute("SELECT must_change_password FROM users WHERE username='old-admin'").fetchone() == (0,)
        raw.close()

        factory = sessionmaker(bind=engine)

        def _get_db():
            session = factory()
            try:
                yield session
            finally:
                session.close()

        app = FastAPI()
        app.include_router(auth_router_module.router)
        app.dependency_overrides[get_db] = _get_db
        login_limiter.reset_all()
        invalidate_permission_cache()
        login = TestClient(app).post(
            "/api/v1/auth/login", json={"username_or_email": "old-admin", "password": "Legacy-Pass-1"}
        )
        assert login.status_code == 200, login.text
        assert login.json()["user"]["must_change_password"] is False
    finally:
        engine.dispose()
        db_safety.clear_maintenance_mode()
        invalidate_permission_cache()


def test_add_column_ddl_rules():
    from sqlalchemy import Boolean, Column, DateTime, Integer, MetaData, String, Table, func, text
    from sqlalchemy.dialects import sqlite

    table = Table(
        "t", MetaData(),
        Column("id", Integer, primary_key=True),
        Column("flag", Boolean, nullable=False, server_default=text("0")),
        Column("opt_flag", Boolean, nullable=True, server_default=text("1")),
        Column("label", String(10), nullable=False, server_default="it's"),
        Column("plain", String(10), nullable=False),
        Column("stamp", DateTime, nullable=False, server_default=func.current_timestamp()),
        Column("stamp_text", DateTime, nullable=False, server_default=text("CURRENT_TIMESTAMP")),
        Column("expr", Integer, nullable=False, server_default=text("(1 + 1)")),
    )
    ddl = {c.name: sus.add_column_ddl("t", c, sqlite.dialect()) for c in table.columns if c.name != "id"}
    assert ddl["flag"] == 'ALTER TABLE "t" ADD COLUMN "flag" BOOLEAN NOT NULL DEFAULT 0'
    assert ddl["opt_flag"] == 'ALTER TABLE "t" ADD COLUMN "opt_flag" BOOLEAN DEFAULT 1'
    assert ddl["label"] == """ALTER TABLE "t" ADD COLUMN "label" VARCHAR(10) NOT NULL DEFAULT 'it''s'"""
    # No usable constant default: added nullable, exactly as before (SQLite would refuse NOT NULL).
    assert ddl["plain"] == 'ALTER TABLE "t" ADD COLUMN "plain" VARCHAR(10)'
    assert ddl["stamp"] == 'ALTER TABLE "t" ADD COLUMN "stamp" DATETIME'
    assert ddl["stamp_text"] == 'ALTER TABLE "t" ADD COLUMN "stamp_text" DATETIME'
    assert ddl["expr"] == 'ALTER TABLE "t" ADD COLUMN "expr" INTEGER'
    conn = sqlite3.connect(":memory:")
    conn.execute('CREATE TABLE "t" (id INTEGER PRIMARY KEY)')
    conn.execute('INSERT INTO "t" (id) VALUES (1)')
    for statement in ddl.values():
        conn.execute(statement)  # every generated statement is accepted by SQLite on a non-empty table
    assert conn.execute('SELECT flag, opt_flag, label FROM "t"').fetchone() == (0, 1, "it's")
    conn.close()


def test_user_response_reads_null_flag_as_false():
    from datetime import datetime

    from modules.auth.schemas import UserResponse

    base = dict(username="u", email="u@host.local", full_name="U", user_id=1, is_active=True,
                created_at=datetime(2026, 1, 1))
    assert UserResponse.model_validate({**base, "must_change_password": None}).must_change_password is False
    assert UserResponse.model_validate(base).must_change_password is False
    assert UserResponse.model_validate({**base, "must_change_password": True}).must_change_password is True


def test_change_password_wrong_current_is_rate_limited_per_user(forced_client):
    from modules.auth.service import change_password_limiter_key

    client, factory, user_id, _ = forced_client
    wrong = {"current_password": "Wrong-Password-1", "new_password": NEW_PASSWORD}
    for _ in range(login_limiter.max_attempts):
        assert client.post(CHANGE_URL, json=wrong).status_code == 400
    blocked = client.post(CHANGE_URL, json=wrong)
    assert blocked.status_code == 429
    # Locked out: even the right password is refused until the lockout ends.
    right = {"current_password": DEFAULT_PASSWORD, "new_password": NEW_PASSWORD}
    assert client.post(CHANGE_URL, json=right).status_code == 429
    # Keyed by user, not by IP: /login from the same client still works.
    assert client.post("/api/v1/auth/login",
                       json={"username_or_email": "admin", "password": DEFAULT_PASSWORD}).status_code == 200

    login_limiter.record_success_key(change_password_limiter_key(user_id))  # lockout over
    assert client.post(CHANGE_URL, json=right).status_code == 200
    assert change_password_limiter_key(user_id) not in login_limiter._failures


def test_success_resets_the_failure_counter(forced_client):
    from modules.auth.service import change_password_limiter_key

    client, _, user_id, _ = forced_client
    for _ in range(login_limiter.max_attempts - 1):
        client.post(CHANGE_URL, json={"current_password": "Wrong-Password-1", "new_password": NEW_PASSWORD})
    res = client.post(CHANGE_URL, json={"current_password": DEFAULT_PASSWORD, "new_password": NEW_PASSWORD})
    assert res.status_code == 200
    assert change_password_limiter_key(user_id) not in login_limiter._failures


def test_ws_token_of_flagged_user_is_rejected(api, monkeypatch):
    from modules.auth.permissions import authenticate_ws_token

    app, factory = api
    user_id = _seed_default_admin(factory)
    monkeypatch.setattr(auth_permissions, "SessionLocal", factory)
    token = create_access_token({"sub": str(user_id), "username": "admin", "role": "ADMIN"})
    assert authenticate_ws_token(token) is None

    session = factory()
    session.get(User, user_id).must_change_password = False
    session.commit()
    session.close()
    invalidate_permission_cache()
    resolved = authenticate_ws_token(token)
    assert resolved is not None and resolved.user_id == user_id


def test_ws_handshake_of_flagged_user_closes_with_1008(api, monkeypatch):
    import json

    from starlette.websockets import WebSocketDisconnect

    import main

    _, factory = api
    user_id = _seed_default_admin(factory)
    monkeypatch.setattr(auth_permissions, "SessionLocal", factory)
    token = create_access_token({"sub": str(user_id), "username": "admin", "role": "ADMIN"})
    with TestClient(main.app).websocket_connect("/api/v1/notifications/ws") as ws:
        ws.send_text(json.dumps({"type": "auth", "token": token}))
        with pytest.raises(WebSocketDisconnect) as exc:
            ws.receive_text()
        assert exc.value.code == 1008


@pytest.mark.parametrize("path", ["/shutdown", "/api/v1/shutdown"])
def test_flagged_admin_can_still_shut_the_app_down(api, monkeypatch, path):
    """The app-exit route stays reachable so the WAL is still checkpointed on exit."""
    import threading

    import main

    _, factory = api
    user_id = _seed_default_admin(factory)
    started = []

    class _NoThread:
        def __init__(self, target=None, daemon=None, **kwargs):
            self.target = target

        def start(self):
            started.append(self.target)  # never run: it would os._exit the test process

    monkeypatch.setattr(threading, "Thread", _NoThread)

    def _get_db():
        session = factory()
        try:
            yield session
        finally:
            session.close()

    main.app.dependency_overrides[get_db] = _get_db
    try:
        token = create_access_token({"sub": str(user_id), "username": "admin", "role": "ADMIN"})
        client = TestClient(main.app, headers={"Authorization": f"Bearer {token}"})
        assert client.get("/api/v1/currencies").json()["detail"] == FORCED_DETAIL  # guard active in main.app
        res = client.post(path)
        assert res.status_code == 200, res.text
        assert res.json()["status"] == "shutting down"
        assert len(started) == 1
    finally:
        main.app.dependency_overrides.pop(get_db, None)


@pytest.mark.parametrize("origin", ["null", "*", "https://evil.example", "http://localhost.evil.example",
                                    "file://", "http://192.168.1.5.evil.example"])
def test_cors_rejects_null_wildcard_and_foreign_origins(origin):
    import main

    assert main.is_cors_origin_allowed(origin) is False
    client = TestClient(main.app)
    preflight = client.options("/api/v1/auth/login", headers={
        "Origin": origin, "Access-Control-Request-Method": "POST",
        "Access-Control-Request-Private-Network": "true",
    })
    assert "access-control-allow-origin" not in preflight.headers
    assert "access-control-allow-credentials" not in preflight.headers
    assert "access-control-allow-private-network" not in preflight.headers
    res = client.post("/api/v1/auth/login", headers={"Origin": origin},
                      json={"username_or_email": "nobody", "password": "x"})
    assert "access-control-allow-origin" not in res.headers


@pytest.mark.parametrize("origin", ["http://localhost:5173", "http://127.0.0.1:28080", "http://localhost",
                                    "http://192.168.1.20:8080"])
def test_cors_still_allows_local_web_origins(origin):
    import main

    assert main.is_cors_origin_allowed(origin) is True
    preflight = TestClient(main.app).options("/api/v1/auth/login", headers={
        "Origin": origin, "Access-Control-Request-Method": "POST",
    })
    assert preflight.headers["access-control-allow-origin"] == origin
    assert preflight.headers["access-control-allow-credentials"] == "true"


def test_no_origin_header_gets_no_cors_headers():
    """The desktop client (dio) sends no Origin: it never needed CORS."""
    import main

    res = TestClient(main.app).get("/health")
    assert res.status_code == 200
    assert "access-control-allow-origin" not in res.headers


# ─── Leftover ADMIN_INITIAL_PASSWORD line from an old 2.1.x install ─────────

RANDOM_2_1_PASSWORD = "Rnd-2.1.x-Generated-7"


@pytest.fixture
def legacy_install(tmp_path, monkeypatch):
    """Frozen build, .env from 2.1.x with its random password, admin still using that password."""
    import sys

    env_file = tmp_path / ".env"
    env_file.write_text(f"SECRET_KEY={'s' * 40}\nADMIN_INITIAL_PASSWORD={RANDOM_2_1_PASSWORD}\nOTHER=keep\n",
                        encoding="utf-8")
    monkeypatch.setattr(settings, "ENV_PATH", env_file)
    monkeypatch.setattr(sys, "frozen", True, raising=False)
    # What the frozen build seeds with now; deliberately different from the .env value.
    monkeypatch.setattr(mds, "ADMIN_INITIAL_PASSWORD", DEFAULT_PASSWORD)
    monkeypatch.setattr(settings, "ADMIN_INITIAL_PASSWORD", DEFAULT_PASSWORD)
    monkeypatch.delenv("ADMIN_INITIAL_PASSWORD", raising=False)
    engine = create_engine(f"sqlite:///{(tmp_path / 'legacy.db').as_posix()}")
    Base.metadata.create_all(bind=engine, tables=[Role.__table__, User.__table__, AuditLog.__table__])
    session = sessionmaker(bind=engine)()
    admin = User(username="admin", email="admin@sorourlogistics.com", full_name="System Admin",
                 hashed_password=hash_password(RANDOM_2_1_PASSWORD), role="ADMIN", is_active=True)
    session.add(admin)
    session.commit()
    invalidate_permission_cache()
    yield session, env_file, admin
    session.close()
    engine.dispose()
    invalidate_permission_cache()


def test_env_admin_initial_password_reads_the_env_file(legacy_install, tmp_path, monkeypatch):
    _, env_file, _ = legacy_install
    assert settings.env_admin_initial_password(env_file) == RANDOM_2_1_PASSWORD
    missing = tmp_path / "none.env"
    assert settings.env_admin_initial_password(missing) == ""
    monkeypatch.setenv("ADMIN_INITIAL_PASSWORD", "From-Process-Env-1")
    assert settings.env_admin_initial_password(missing) == "From-Process-Env-1"


def test_unchanged_2_1_admin_keeps_the_env_line(legacy_install):
    session, env_file, _ = legacy_install
    assert mds.MasterDataSyncService(session).sync_system_users() == 0
    assert f"ADMIN_INITIAL_PASSWORD={RANDOM_2_1_PASSWORD}" in env_file.read_text(encoding="utf-8")


def test_changed_2_1_admin_loses_the_env_line_at_startup(legacy_install):
    session, env_file, admin = legacy_install
    admin.hashed_password = hash_password("Changed-By-Admin-9")
    session.commit()
    assert mds.MasterDataSyncService(session).sync_system_users() == 0
    text = env_file.read_text(encoding="utf-8")
    assert "ADMIN_INITIAL_PASSWORD=" not in text
    assert "OTHER=keep" in text and "SECRET_KEY=" in text


def test_self_service_change_removes_the_env_line(legacy_install):
    from modules.auth.service import AuthService

    session, env_file, admin = legacy_install
    AuthService(session).change_own_password(admin, RANDOM_2_1_PASSWORD, "Brand-New-Admin-7")
    assert "ADMIN_INITIAL_PASSWORD=" not in env_file.read_text(encoding="utf-8")


def test_unreadable_env_value_keeps_the_line(legacy_install, monkeypatch):
    session, env_file, admin = legacy_install
    admin.hashed_password = hash_password("Changed-By-Admin-9")
    session.commit()
    monkeypatch.setattr(settings, "env_admin_initial_password", lambda env_path: None)
    assert mds.MasterDataSyncService(session).sync_system_users() == 0
    assert "ADMIN_INITIAL_PASSWORD=" in env_file.read_text(encoding="utf-8")
