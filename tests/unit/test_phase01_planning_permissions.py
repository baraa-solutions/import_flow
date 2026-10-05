"""
Phase-1 planning routers (CBM calculator, shipping scenarios, customs consultation, import requirements,
freight quotations): every route carries a permission (CBM-01, SS-01, CC-02, IR-03, FQ-01).

Strict mode (no dev bypass): a read-only viewer can read but gets 403 on every mutating route; a role that
holds the manage code passes the auth check (an invalid body then gives 422, proving auth ran first).
"""

import importlib

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main  # noqa: F401  registers every SQLAlchemy model in Base.metadata
import modules.auth.permissions as auth_permissions
from database.database import Base, get_db
from modules.auth.permissions import invalidate_permission_cache
from modules.auth.security import create_access_token, hash_password
from modules.auth.seed_rbac import seed_rbac
from modules.users.model import Role, User

ROUTER_MODULES = [
    "modules.cbm_calculator.router",
    "modules.shipping_scenarios.router",
    "modules.customs_consultation.router",
    "modules.import_requirements.router",
    "modules.freight_quotations.router",
]


@pytest.fixture
def session_factory():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine)
    invalidate_permission_cache()
    session = factory()
    seed_rbac(session)
    session.close()
    yield factory
    invalidate_permission_cache()
    engine.dispose()


def _user(factory, username: str, role_code: str) -> dict:
    db = factory()
    try:
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
        token = create_access_token({"sub": str(user.user_id), "role": user.role})
        return {"Authorization": f"Bearer {token}"}
    finally:
        db.close()


@pytest.fixture
def client(session_factory, monkeypatch):
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", False)
    app = FastAPI()
    for name in ROUTER_MODULES:
        app.include_router(importlib.import_module(name).router)

    def override_get_db():
        session = session_factory()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_db] = override_get_db
    return TestClient(app, raise_server_exceptions=False)


@pytest.fixture
def viewer(session_factory):
    return _user(session_factory, "p1_viewer", "AUDITOR_VIEWER")


@pytest.fixture
def operator(session_factory):
    return _user(session_factory, "p1_operator", "LOGISTICS_OPERATOR")


@pytest.fixture
def customs_officer(session_factory):
    return _user(session_factory, "p1_customs", "CUSTOMS_OFFICER")


MUTATING_ROUTES = [
    ("POST", "/api/v1/cbm-calculator"),
    ("PUT", "/api/v1/cbm-calculator/1"),
    ("POST", "/api/v1/cbm-calculator/1/link"),
    ("DELETE", "/api/v1/cbm-calculator/1"),
    ("POST", "/api/v1/cbm-calculator/1/restore"),
    ("POST", "/api/v1/cbm-calculator/1/clone"),
    ("POST", "/api/v1/shipping-scenarios"),
    ("PUT", "/api/v1/shipping-scenarios/1"),
    ("DELETE", "/api/v1/shipping-scenarios/1"),
    ("POST", "/api/v1/shipping-scenarios/1/restore"),
    ("POST", "/api/v1/shipping-scenarios/1/clone"),
    ("POST", "/api/v1/customs-consultations"),
    ("PUT", "/api/v1/customs-consultations/1"),
    ("DELETE", "/api/v1/customs-consultations/1"),
    ("POST", "/api/v1/customs-consultations/1/restore"),
    ("POST", "/api/v1/customs-consultations/1/clone"),
    ("POST", "/api/v1/customs-consultations/price-lists"),
    ("PUT", "/api/v1/customs-consultations/price-lists/1"),
    ("DELETE", "/api/v1/customs-consultations/price-lists/1"),
    ("POST", "/api/v1/customs-consultations/price-lists/1/clone"),
    ("POST", "/api/v1/customs-consultations/expense-types"),
    ("PUT", "/api/v1/customs-consultations/expense-types/1"),
    ("DELETE", "/api/v1/customs-consultations/expense-types/1"),
    ("POST", "/api/v1/import-requirements"),
    ("PUT", "/api/v1/import-requirements/1"),
    ("DELETE", "/api/v1/import-requirements/1"),
    ("POST", "/api/v1/import-requirements/1/restore"),
    ("POST", "/api/v1/freight-quotations"),
    ("PUT", "/api/v1/freight-quotations/1"),
    ("POST", "/api/v1/freight-quotations/1/award/1"),
    ("DELETE", "/api/v1/freight-quotations/1"),
    ("POST", "/api/v1/freight-quotations/1/restore"),
]

READ_ROUTES = [
    "/api/v1/cbm-calculator",
    "/api/v1/shipping-scenarios",
    "/api/v1/customs-consultations",
    "/api/v1/customs-consultations/price-lists",
    "/api/v1/customs-consultations/expense-types",
    "/api/v1/import-requirements",
    "/api/v1/freight-quotations",
]


@pytest.mark.parametrize("method,path", MUTATING_ROUTES)
def test_viewer_gets_403_on_mutating_routes(client, viewer, method, path):
    response = client.request(method, path, headers=viewer, json={})
    assert response.status_code == 403, response.text


@pytest.mark.parametrize("path", READ_ROUTES)
def test_viewer_can_read(client, viewer, path):
    response = client.get(path, headers=viewer)
    assert response.status_code == 200, response.text


@pytest.mark.parametrize("path", READ_ROUTES)
def test_no_token_is_401(client, path):
    assert client.get(path).status_code == 401


def test_viewer_can_run_read_only_calculations(client, viewer):
    # quick-calculate and the customs re-estimation write nothing: view permission is enough.
    quick = client.post("/api/v1/cbm-calculator/quick-calculate", headers=viewer, json={"items": []})
    assert quick.status_code != 403
    recalc = client.post("/api/v1/customs-consultations/recalculate-from-reconciliation", headers=viewer, json={})
    assert recalc.status_code == 422  # auth passed, body invalid


@pytest.mark.parametrize(
    "path",
    [
        "/api/v1/cbm-calculator",
        "/api/v1/shipping-scenarios",
        "/api/v1/import-requirements",
        "/api/v1/freight-quotations",
    ],
)
def test_operator_with_manage_code_passes_auth(client, operator, path):
    # Invalid body -> 422 proves the permission check passed (it runs before body validation).
    response = client.post(path, headers=operator, json={"title": 1, "items": "x", "risk_level": []})
    assert response.status_code == 422, response.text


def test_customs_officer_manages_consultations_but_not_expense_types(client, customs_officer):
    assert client.post("/api/v1/customs-consultations", headers=customs_officer, json={}).status_code == 422
    # Expense types are master data: master_data.edit is required.
    assert client.post("/api/v1/customs-consultations/expense-types", headers=customs_officer, json={}).status_code == 403


def test_operator_cannot_manage_customs_consultations(client, operator):
    assert client.post("/api/v1/customs-consultations", headers=operator, json={}).status_code == 403
