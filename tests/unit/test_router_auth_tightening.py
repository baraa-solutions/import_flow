"""
Router-level authentication and tightened dependencies (backend-B auth pass).

- Every owned router now carries a router-level get_current_user dependency: no token -> 401 when the dev
  bypass is off.
- Sensitive routes require ADMIN / MANAGER / a specific permission: a plain operator gets 403, and the auth
  check runs before the body is validated (an admin with an invalid body gets 422, not 403).
- Audit author for PUT routes comes from the authenticated user, never from the X-User-Name header.
"""

import importlib

import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import modules.auth.permissions as auth_permissions
from database.database import Base, get_db
from modules.auth.permissions import invalidate_permission_cache
from modules.auth.security import create_access_token, hash_password
from modules.auth.seed_rbac import seed_rbac
from modules.users.model import Role, User

currencies_router = importlib.import_module("modules.currencies.router")
docs_customs_approval_router = importlib.import_module("modules.docs_customs_approval.router")
import modules.docs_customs_approval.service as docs_customs_approval_service
financial_approval_router = importlib.import_module("modules.financial_approval.router")
import modules.financial_approval.service as financial_approval_service
import_files_router = importlib.import_module("modules.import_files.router")
integrations_router = importlib.import_module("modules.integrations.router")
production_sync_router = importlib.import_module("modules.production_sync.router")
purchase_orders_router = importlib.import_module("modules.purchase_orders.router")
recalculation_router = importlib.import_module("modules.recalculation.router")
smart_email_router = importlib.import_module("modules.smart_email_listener.router")
system_observability_router = importlib.import_module("modules.system_observability.router")
audit_logs_router = importlib.import_module("modules.audit_logs.router")
suppliers_router = importlib.import_module("modules.suppliers.router")


# ─── Fixtures ────────────────────────────────────────────────────────────────

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
    return _make_user(db, "rt_admin", "ADMIN")


@pytest.fixture
def manager(db):
    return _make_user(db, "rt_manager", "GENERAL_MANAGER")


@pytest.fixture
def operator(db):
    return _make_user(db, "rt_operator", "LOGISTICS_OPERATOR")


@pytest.fixture
def client(session_factory, monkeypatch):
    # Strict mode: no dev bypass, so missing tokens must be rejected.
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", False)
    app = FastAPI()
    for module in (
        currencies_router,
        docs_customs_approval_router,
        financial_approval_router,
        import_files_router,
        integrations_router,
        production_sync_router,
        purchase_orders_router,
        recalculation_router,
        system_observability_router,
        audit_logs_router,
    ):
        app.include_router(module.router)
    app.include_router(suppliers_router.supplier_router)
    app.include_router(smart_email_router.router)
    app.include_router(smart_email_router.compat_router)

    def override_get_db():
        session = session_factory()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_db] = override_get_db
    return TestClient(app, raise_server_exceptions=False)


def _bearer(user: User) -> dict:
    return {"Authorization": f"Bearer {create_access_token({'sub': str(user.user_id), 'role': user.role})}"}


# ─── Router-level authentication ─────────────────────────────────────────────

@pytest.mark.parametrize(
    "method,path",
    [
        ("GET", "/api/v1/audit-logs"),
        ("GET", "/api/v1/suppliers/"),
        ("GET", "/api/v1/currencies/"),
        ("GET", "/api/v1/financial-approval/payment-requests"),
        ("GET", "/api/v1/recalculation/dependencies"),
        ("GET", "/api/v1/smart-email/logs"),
        ("GET", "/smart-email/logs"),
        ("POST", "/api/v1/integrations/pki/sign-payload"),
    ],
)
def test_no_token_is_401(client, method, path):
    response = client.request(method, path)
    assert response.status_code == 401


def test_invalid_token_is_401(client):
    response = client.get("/api/v1/audit-logs", headers={"Authorization": "Bearer not-a-token"})
    assert response.status_code == 401


def test_x_user_name_header_alone_is_401_without_bypass(client, admin):
    response = client.get("/api/v1/audit-logs", headers={"X-User-Name": admin.username, "X-User-Role": "ADMIN"})
    assert response.status_code == 401


def test_operator_with_token_can_read_login_only_route(client, operator):
    response = client.get("/api/v1/recalculation/dependencies", headers=_bearer(operator))
    assert response.status_code == 200


# ─── Tightened routes: operator denied ───────────────────────────────────────

ADMIN_ONLY_ROUTES = [
    ("GET", "/api/v1/system/health/deep"),
    ("GET", "/api/v1/system/observability/export-bundle"),
    ("POST", "/api/v1/system/observability/alerts/test-trigger"),
    ("POST", "/api/v1/system/observability/alerts/reset-cooldown"),
    ("POST", "/api/v1/system/observability/daily-report/generate"),
    ("GET", "/api/v1/production-sync/compare"),
    ("GET", "/api/v1/production-sync/backups"),
    ("PUT", "/api/v1/financial-approval/settings/variance-threshold"),
    ("POST", "/api/v1/integrations/pki/sign-payload"),
    ("GET", "/api/v1/smart-email/settings"),
    ("POST", "/api/v1/smart-email/settings"),
    ("POST", "/api/v1/smart-email/test-connection"),
    ("POST", "/api/v1/smart-email/send-email"),
    ("GET", "/smart-email/settings"),
    ("POST", "/smart-email/settings"),
    ("POST", "/smart-email/test-connection"),
    ("POST", "/smart-email/send-email"),
]


@pytest.mark.parametrize("method,path", ADMIN_ONLY_ROUTES)
def test_admin_only_routes_deny_operator(client, operator, method, path):
    response = client.request(method, path, headers=_bearer(operator), json={})
    assert response.status_code == 403


@pytest.mark.parametrize("method,path", ADMIN_ONLY_ROUTES)
def test_admin_only_routes_deny_manager(client, manager, method, path):
    response = client.request(method, path, headers=_bearer(manager), json={})
    assert response.status_code == 403


@pytest.mark.parametrize(
    "path",
    [
        "/api/v1/integrations/pki/sign-payload",
        "/api/v1/smart-email/send-email",
        "/smart-email/test-connection",
        "/api/v1/financial-approval/settings/variance-threshold",
    ],
)
def test_admin_passes_auth_then_body_validation(client, admin, path):
    method = "PUT" if path.endswith("variance-threshold") else "POST"
    response = client.request(method, path, headers={**_bearer(admin), "Content-Type": "application/json"}, content="not json")
    assert response.status_code == 422


def test_recalculation_apply_denies_operator(client, operator):
    response = client.post("/api/v1/recalculation/apply", headers=_bearer(operator), json={})
    assert response.status_code == 403
    assert "Manager or Admin" in response.json()["detail"]


def test_recalculation_apply_allows_manager_past_auth(client, manager):
    response = client.post("/api/v1/recalculation/apply", headers=_bearer(manager), json={})
    assert response.status_code == 422


def test_currency_rates_requires_master_data_edit(client, operator):
    response = client.post("/api/v1/currencies/rates", headers=_bearer(operator), json={})
    assert response.status_code == 403
    assert "master_data.edit" in response.json()["detail"]


def test_currency_rates_admin_passes_auth(client, admin):
    response = client.post("/api/v1/currencies/rates", headers=_bearer(admin), json={})
    assert response.status_code == 422


def test_reopen_shipment_requires_close_permission(client, operator):
    # LOGISTICS_OPERATOR holds import_files.edit but not import_files.close.
    response = client.post("/api/v1/import-files/1/reopen-shipment", headers=_bearer(operator), json={})
    assert response.status_code == 403
    assert "import_files.close" in response.json()["detail"]


def test_reopen_shipment_general_manager_passes_auth(client, manager):
    response = client.post("/api/v1/import-files/1/reopen-shipment", headers=_bearer(manager), json={})
    assert response.status_code == 422


# ─── Audit author comes from the token, not X-User-Name ──────────────────────

def _capturing(store: dict):
    def fake(*args, **kwargs):
        store.update(kwargs)
        raise HTTPException(status_code=418, detail="captured")
    return fake


SPOOF = {"X-User-Name": "spoofed-user"}


def test_payment_request_update_author_is_token_user(client, admin, monkeypatch):
    captured = {}
    monkeypatch.setattr(financial_approval_service, "update_payment_request_service", _capturing(captured))
    response = client.put("/api/v1/financial-approval/payment-requests/1", headers={**_bearer(admin), **SPOOF}, json={})
    assert response.status_code == 418
    assert captured["current_user_name"] == admin.username


def test_import_budget_update_author_is_token_user(client, admin, monkeypatch):
    captured = {}
    monkeypatch.setattr(financial_approval_service, "update_import_budget_service", _capturing(captured))
    response = client.put("/api/v1/financial-approval/import-budgets/1", headers={**_bearer(admin), **SPOOF}, json={})
    assert response.status_code == 418
    assert captured["current_user_name"] == admin.username


def test_docs_customs_approval_update_author_is_token_user(client, operator, monkeypatch):
    captured = {}
    monkeypatch.setattr(docs_customs_approval_service, "update_approval_service", _capturing(captured))
    response = client.put("/api/v1/docs-customs-approval/1", headers={**_bearer(operator), **SPOOF}, json={})
    assert response.status_code == 418
    assert captured["current_user_name"] == operator.username


def test_purchase_order_update_author_is_token_user(client, admin, monkeypatch):
    captured = {}
    monkeypatch.setattr(purchase_orders_router.PurchaseOrderService, "update", _capturing(captured))
    response = client.put("/api/v1/purchase-orders/1", headers={**_bearer(admin), **SPOOF}, json={})
    assert response.status_code == 418
    assert captured["current_user_name"] == admin.username
