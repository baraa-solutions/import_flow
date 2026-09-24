"""
/api/v1/app-update router (plan §6, §11): 401 without a token, 403 without system.update, 200 for any
authenticated user on check/status/last-result, ADMIN-only system.update, no endpoint accepts a URL.
Strict auth (dev bypass off), in-memory DB, mocked update host, tmp update dir.
"""
import base64
import hashlib
import importlib
import inspect
import json

import httpx
import pytest
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
from fastapi import FastAPI
from fastapi.routing import APIRoute
from fastapi.testclient import TestClient
from pydantic import BaseModel
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import modules.app_update.service as update_service
import modules.auth.permissions as auth_permissions
from database.database import Base, get_db
from modules.app_update.service import UpdateService, get_update_service
from modules.app_update.validators import DETAIL_NO_DOWNLOAD_RUNNING, DETAIL_NOT_IMPLEMENTED
from modules.audit_logs.model import AuditLog
from modules.auth.permissions import invalidate_permission_cache
from modules.auth.security import create_access_token, hash_password
from modules.auth.seed_rbac import PERMISSIONS_CATALOG, ROLES_CONFIG, seed_rbac
from modules.users.model import Role, User

app_update_router = importlib.import_module("modules.app_update.router")

KEY_ID = "ktest"
INSTALLER_BYTES = b"MZ-router-test-installer" * 100
PREFIX = "/api/v1/app-update"


def _manifest(private_key) -> bytes:
    payload = {
        "schema": 1,
        "app": "sorour-logistics",
        "channel": "stable",
        "version": "2.1.0",
        "build_number": 210,
        "released_at": "2026-10-01T10:00:00Z",
        "expires_at": "2099-01-01T00:00:00Z",
        "min_supported_version": "2.0.0",
        "mandatory": False,
        "release_notes": {"ar": ["جديد"], "en": ["New"]},
        "installer": {
            "path": "releases/2.1.0/Sorour_Logistics_Setup_v2.1.0.exe",
            "size_bytes": len(INSTALLER_BYTES),
            "sha256": hashlib.sha256(INSTALLER_BYTES).hexdigest(),
        },
    }
    signed = json.dumps(payload, separators=(",", ":"))
    signature = base64.b64encode(private_key.sign(signed.encode("utf-8"))).decode()
    return json.dumps({"key_id": KEY_ID, "signature": signature, "signed": signed}).encode()


# ─── Fixtures ────────────────────────────────────────────────────────────────

@pytest.fixture
def session_factory():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine)
    invalidate_permission_cache()
    yield factory
    invalidate_permission_cache()
    engine.dispose()


@pytest.fixture
def db(session_factory):
    session = session_factory()
    seed_rbac(session)
    yield session
    session.close()


def _make_user(db, username: str, role_code: str) -> User:
    role = db.query(Role).filter(Role.role_code == role_code).one()
    user = User(
        username=username,
        email=f"{username}@test.com",
        full_name=username,
        hashed_password=hash_password("Password123"),
        role=role.role_code,
        role_id=role.role_id,
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture
def admin(db):
    return _make_user(db, "upd_admin", "ADMIN")


@pytest.fixture
def manager(db):
    return _make_user(db, "upd_manager", "GENERAL_MANAGER")


@pytest.fixture
def operator(db):
    return _make_user(db, "upd_operator", "LOGISTICS_OPERATOR")


@pytest.fixture
def update_svc(tmp_path, monkeypatch):
    monkeypatch.setenv("UPDATE_DATA_DIR", str(tmp_path / "env-updates"))
    monkeypatch.delenv("UPDATE_BASE_URL", raising=False)
    key = Ed25519PrivateKey.generate()
    public = base64.b64encode(key.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)).decode()
    monkeypatch.setattr(update_service, "UPDATE_SIGNING_PUBLIC_KEYS", {KEY_ID: public})
    manifest = _manifest(key)

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/manifest.json"):
            return httpx.Response(200, content=manifest)
        if request.url.path.endswith(".exe"):
            return httpx.Response(200, content=INSTALLER_BYTES)
        return httpx.Response(404)

    return UpdateService(
        data_dir=tmp_path / "updates",
        transport=httpx.MockTransport(handler),
        installed_version_provider=lambda: ("2.0.3", 205),
        apply_supported_provider=lambda: True,
        run_in_background=lambda fn: fn(),
    )


@pytest.fixture
def client(session_factory, update_svc, monkeypatch):
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", False)
    app = FastAPI()
    app.include_router(app_update_router.router)

    def override_get_db():
        session = session_factory()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_update_service] = lambda: update_svc
    return TestClient(app, raise_server_exceptions=False)


def _bearer(user: User) -> dict:
    return {"Authorization": f"Bearer {create_access_token({'sub': str(user.user_id), 'role': user.role})}"}


VALID_BODIES = {
    "/download": {"version": "2.1.0"},
    "/apply": {"version": "2.1.0"},
    "/stage-local": {"manifest_path": "D:/usb/manifest.json", "installer_path": "D:/usb/setup.exe"},
    "/rollback": {"confirm": True, "backup_file": "pre_update_2.0.3.db"},
}

ALL_ROUTES = [
    ("GET", "/check"),
    ("GET", "/status"),
    ("POST", "/download"),
    ("POST", "/cancel"),
    ("POST", "/apply"),
    ("POST", "/stage-local"),
    ("POST", "/rollback"),
    ("GET", "/last-result"),
    ("GET", "/history"),
]
SYSTEM_UPDATE_ROUTES = [r for r in ALL_ROUTES if r[1] not in ("/check", "/status", "/last-result")]


# ─── Permission catalog ──────────────────────────────────────────────────────

def test_system_update_permission_is_in_catalog_and_admin_only():
    codes = {p["code"]: p for p in PERMISSIONS_CATALOG}
    assert codes["system.update"]["module"] == "system"
    assert codes["system.update"]["action"] == "update"
    for role in ROLES_CONFIG:
        if role["code"] != "ADMIN":
            assert "system.update" not in role["permissions"]


def test_admin_role_is_linked_to_system_update(db):
    from modules.auth.permissions import has_user_permission

    admin_user = _make_user(db, "linked_admin", "ADMIN")
    manager_user = _make_user(db, "linked_manager", "GENERAL_MANAGER")
    assert has_user_permission(db, admin_user, "system.update") is True
    assert has_user_permission(db, manager_user, "system.update") is False


# ─── 401 / 403 / 200 ─────────────────────────────────────────────────────────

@pytest.mark.parametrize("method,path", ALL_ROUTES)
def test_no_token_is_401(client, method, path):
    response = client.request(method, PREFIX + path, json=VALID_BODIES.get(path))
    assert response.status_code == 401


@pytest.mark.parametrize("method,path", SYSTEM_UPDATE_ROUTES)
def test_operator_without_system_update_is_403(client, operator, method, path):
    response = client.request(method, PREFIX + path, headers=_bearer(operator), json=VALID_BODIES.get(path))
    assert response.status_code == 403


@pytest.mark.parametrize("method,path", SYSTEM_UPDATE_ROUTES)
def test_general_manager_without_system_update_is_403(client, manager, method, path):
    response = client.request(method, PREFIX + path, headers=_bearer(manager), json=VALID_BODIES.get(path))
    assert response.status_code == 403


@pytest.mark.parametrize("path", ["/check", "/status", "/last-result"])
def test_operator_can_read(client, operator, path):
    response = client.get(PREFIX + path, headers=_bearer(operator))
    assert response.status_code == 200


def test_check_contract(client, operator):
    body = client.get(PREFIX + "/check", headers=_bearer(operator)).json()
    assert set(body) == {
        "current_version", "current_build", "latest_version", "latest_build", "update_available", "mandatory",
        "release_notes", "released_at", "installer_size_bytes", "check_status", "last_checked_at",
        "apply_supported",
    }
    assert body["check_status"] == "update_available"
    assert body["latest_version"] == "2.1.0"
    assert body["release_notes"] == {"ar": ["جديد"], "en": ["New"]}
    assert body["installer_size_bytes"] == len(INSTALLER_BYTES)


def test_status_contract(client, operator):
    body = client.get(PREFIX + "/status", headers=_bearer(operator)).json()
    assert body == {
        "state": "idle", "version": None, "downloaded_bytes": 0, "total_bytes": 0,
        "error_code": None, "error_detail": None,
    }


def test_last_result_contract(client, operator):
    body = client.get(PREFIX + "/last-result", headers=_bearer(operator)).json()
    assert body == {"result": "none", "from_version": None, "to_version": None, "finished_at": None, "detail": None}


# ─── ADMIN flows ─────────────────────────────────────────────────────────────

def test_admin_download_is_202_and_audited(client, admin, session_factory):
    response = client.post(PREFIX + "/download", headers=_bearer(admin), json={"version": "2.1.0"})
    assert response.status_code == 202
    body = response.json()
    assert body["state"] == "ready"
    assert body["total_bytes"] == len(INSTALLER_BYTES)

    session = session_factory()
    try:
        log = session.query(AuditLog).filter(AuditLog.entity_type == "AppUpdate").one()
        assert log.action == "UPDATE_DOWNLOAD"
        assert log.performed_by == "upd_admin"
        assert log.entity_code == "2.1.0"
    finally:
        session.close()

    history = client.get(PREFIX + "/history", headers=_bearer(admin)).json()
    assert [i["event"] for i in history["items"]][:2] == ["download_verified", "download_started"]
    assert set(history["items"][0]) == {"ts", "event", "version", "detail"}


@pytest.mark.parametrize("version", ["2.1", "v2.1.0", "2.1.0-beta", "https://evil.example/x.exe", ""])
def test_download_rejects_bad_version_format(client, admin, version):
    response = client.post(PREFIX + "/download", headers=_bearer(admin), json={"version": version})
    assert response.status_code == 422


def test_download_unknown_version_is_409(client, admin):
    response = client.post(PREFIX + "/download", headers=_bearer(admin), json={"version": "3.0.0"})
    assert response.status_code == 409
    assert response.json()["detail"] == "لا يوجد تحديث متاح لهذا الإصدار"


def test_cancel_without_download_is_409(client, admin):
    response = client.post(PREFIX + "/cancel", headers=_bearer(admin))
    assert response.status_code == 409
    assert response.json()["detail"] == DETAIL_NO_DOWNLOAD_RUNNING


@pytest.mark.parametrize("path", ["/apply", "/stage-local", "/rollback"])
def test_later_phase_routes_are_501_for_admin(client, admin, path):
    response = client.post(PREFIX + path, headers=_bearer(admin), json=VALID_BODIES[path])
    assert response.status_code == 501
    assert response.json()["detail"] == DETAIL_NOT_IMPLEMENTED


@pytest.mark.parametrize("limit", [0, 201])
def test_history_limit_bounds(client, admin, limit):
    response = client.get(PREFIX + "/history", headers=_bearer(admin), params={"limit": limit})
    assert response.status_code == 422


def test_dev_mode_download_is_400(client, admin, update_svc):
    update_svc._apply_supported_provider = lambda: False
    response = client.post(PREFIX + "/download", headers=_bearer(admin), json={"version": "2.1.0"})
    assert response.status_code == 400
    assert response.json()["detail"] == "التحديث التلقائي غير متاح في وضع التطوير"


# ─── No endpoint accepts a URL ───────────────────────────────────────────────

def _model_field_names(model: type) -> set:
    return set(model.model_fields) if inspect.isclass(model) and issubclass(model, BaseModel) else set()


def test_no_endpoint_accepts_a_url_parameter():
    allowed_query = {"force", "limit"}
    for route in app_update_router.router.routes:
        assert isinstance(route, APIRoute)
        dependant = route.dependant
        names = set()
        stack = [dependant]
        while stack:
            dep = stack.pop()
            names |= {p.name for p in dep.query_params}
            names |= {p.name for p in dep.path_params}
            for body in dep.body_params:
                names |= _model_field_names(body.field_info.annotation) or {body.name}
            stack.extend(dep.dependencies)
        header_free = {n for n in names if n not in {"authorization", "x_user_role", "x_user_name"}}
        assert not any("url" in n.lower() or "host" in n.lower() for n in header_free), (route.path, header_free)
        query = {p.name for p in dependant.query_params}
        assert query <= allowed_query, (route.path, query)


def test_every_route_has_router_level_auth():
    from modules.auth.router import get_current_user

    router_deps = [d.dependency for d in app_update_router.router.dependencies]
    assert get_current_user in router_deps
    paths = {r.path for r in app_update_router.router.routes}
    assert paths == {PREFIX + p for _, p in ALL_ROUTES}
