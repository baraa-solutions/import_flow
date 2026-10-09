"""Unit tests for customs tariff routes permissions and route ordering (BE67-T01).

Tests:
1. Strict RBAC enforcement across all customs tariff endpoints.
2. Unauthenticated access returns 401.
3. Users with `customs_tariff.view` (e.g. AUDITOR_VIEWER) can view but cannot edit or simulate.
4. Users with `customs_tariff.edit` and `customs_clearance.update` (e.g. CUSTOMS_OFFICER) pass permission checks.
5. Users without permissions (e.g. LOGISTICS_OPERATOR) get 403 Forbidden.
6. Route ordering: Static routes (/export-template, /fee-codes) are not shadowed by /{tariff_id}.
"""

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main  # noqa: F401 registers models
import modules.auth.permissions as auth_permissions
from database.database import Base, get_db
from modules.auth.permissions import invalidate_permission_cache
from modules.auth.security import create_access_token, hash_password
from modules.auth.seed_rbac import seed_rbac
from modules.customs_tariff.router import customs_tariff_router
from modules.users.model import Role, User


@pytest.fixture
def session_factory():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine)
    invalidate_permission_cache()
    session = factory()
    seed_rbac(session)
    session.close()
    yield factory
    invalidate_permission_cache()
    engine.dispose()


def _create_user_header(factory, username: str, role_code: str) -> dict:
    db = factory()
    try:
        role = db.query(Role).filter(Role.role_code == role_code).one()
        user = User(
            username=username,
            email=f"{username}@test.com",
            full_name=username,
            hashed_password=hash_password("Secret123!"),
            role=role.role_code,
            role_id=role.role_id,
            is_active=True,
        )
        db.add(user)
        db.commit()
        token = create_access_token({"sub": str(user.user_id), "role": user.role})
        return {"Authorization": f"Bearer {token}"}
    finally:
        db.close()


@pytest.fixture
def client(session_factory, monkeypatch):
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", False)
    app = FastAPI()
    app.include_router(customs_tariff_router)

    def override_get_db():
        session = session_factory()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_db] = override_get_db
    return TestClient(app, raise_server_exceptions=False)


@pytest.fixture
def viewer_headers(session_factory):
    return _create_user_header(session_factory, "tariff_viewer", "AUDITOR_VIEWER")


@pytest.fixture
def customs_officer_headers(session_factory):
    return _create_user_header(session_factory, "tariff_officer", "CUSTOMS_OFFICER")


@pytest.fixture
def operator_headers(session_factory):
    return _create_user_header(session_factory, "tariff_operator", "LOGISTICS_OPERATOR")


def test_unauthenticated_requests_return_401(client):
    """Requests without token must return 401 Unauthorized."""
    endpoints = [
        ("GET", "/api/v1/customs-tariff"),
        ("GET", "/api/v1/customs-tariff/export-template"),
        ("GET", "/api/v1/customs-tariff/fee-codes"),
        ("POST", "/api/v1/customs-tariff"),
        ("PUT", "/api/v1/customs-tariff/1"),
        ("DELETE", "/api/v1/customs-tariff/1"),
        ("POST", "/api/v1/customs-tariff/simulate-file/1"),
    ]
    for method, path in endpoints:
        res = client.request(method, path)
        assert res.status_code == 401, f"{method} {path} returned {res.status_code}, expected 401"


def test_static_routes_not_shadowed_by_dynamic_tariff_id(client, viewer_headers):
    """Route order verification: static routes must return 200 and not 422 from /{tariff_id}."""
    resp_template = client.get("/api/v1/customs-tariff/export-template", headers=viewer_headers)
    assert resp_template.status_code == 200
    assert "text/csv" in resp_template.headers.get("content-type", "")

    resp_fee_codes = client.get("/api/v1/customs-tariff/fee-codes", headers=viewer_headers)
    assert resp_fee_codes.status_code == 200
    assert isinstance(resp_fee_codes.json(), list)


def test_viewer_can_access_view_routes(client, viewer_headers):
    """User with customs_tariff.view can access read endpoints."""
    # List endpoints return 200
    r1 = client.get("/api/v1/customs-tariff", headers=viewer_headers)
    assert r1.status_code == 200

    r2 = client.get("/api/v1/customs-tariff/", headers=viewer_headers)
    assert r2.status_code == 200

    # Non-existent item returns 404 (not 403 Forbidden)
    r3 = client.get("/api/v1/customs-tariff/9999", headers=viewer_headers)
    assert r3.status_code == 404

    r4 = client.get("/api/v1/customs-tariff/hs/0000.00.00", headers=viewer_headers)
    assert r4.status_code == 404

    r5 = client.get("/api/v1/customs-tariff/hs/0000.00.00/agreements", headers=viewer_headers)
    assert r5.status_code == 200

    r6 = client.get("/api/v1/customs-tariff/history/0000.00.00", headers=viewer_headers)
    assert r6.status_code == 200


def test_viewer_cannot_mutate_or_simulate(client, viewer_headers):
    """User with only customs_tariff.view must receive 403 Forbidden on mutations and simulation."""
    forbidden_mutations = [
        ("POST", "/api/v1/customs-tariff", {}),
        ("POST", "/api/v1/customs-tariff/fee-codes", {}),
        ("PUT", "/api/v1/customs-tariff/1", {}),
        ("DELETE", "/api/v1/customs-tariff/1", None),
        ("PATCH", "/api/v1/customs-tariff/1/restore", None),
        ("POST", "/api/v1/customs-tariff/hs/1001.99.00/verify", {}),
        ("POST", "/api/v1/customs-tariff/agreements", {}),
        ("POST", "/api/v1/customs-tariff/with-agreements", {}),
        ("POST", "/api/v1/customs-tariff/simulate-file/1", {}),
    ]

    for method, path, body in forbidden_mutations:
        res = client.request(method, path, json=body, headers=viewer_headers)
        assert res.status_code == 403, f"{method} {path} returned {res.status_code}, expected 403"


def test_officer_can_pass_permission_checks_on_mutating_and_simulate_routes(client, customs_officer_headers):
    """Customs officer holding customs_tariff.edit and customs_clearance.update passes auth/permission check."""
    # Simulation route: invalid/missing import_file_id gives 404 (not 403)
    res_sim = client.post("/api/v1/customs-tariff/simulate-file/99999", headers=customs_officer_headers)
    assert res_sim.status_code in (404, 422), f"Expected 404/422 but got {res_sim.status_code}"

    # Mutating route with invalid payload triggers schema validation 422 (auth passed)
    res_create = client.post("/api/v1/customs-tariff", json={}, headers=customs_officer_headers)
    assert res_create.status_code == 422

    res_fee = client.post("/api/v1/customs-tariff/fee-codes", json={}, headers=customs_officer_headers)
    assert res_fee.status_code == 422


def test_unauthorized_operator_blocked_from_all_customs_tariff_routes(client, operator_headers):
    """Operator lacking customs_tariff.view/edit and customs_clearance.update gets 403 on all routes."""
    endpoints = [
        ("GET", "/api/v1/customs-tariff"),
        ("GET", "/api/v1/customs-tariff/export-template"),
        ("GET", "/api/v1/customs-tariff/fee-codes"),
        ("POST", "/api/v1/customs-tariff"),
        ("PUT", "/api/v1/customs-tariff/1"),
        ("DELETE", "/api/v1/customs-tariff/1"),
        ("POST", "/api/v1/customs-tariff/simulate-file/1"),
    ]
    for method, path in endpoints:
        res = client.request(method, path, headers=operator_headers)
        assert res.status_code == 403, f"{method} {path} returned {res.status_code}, expected 403"
