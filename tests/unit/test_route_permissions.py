"""
RBAC endpoint lockdown (Trello UOroUoqq).

1. Static: every data-changing route (POST/PUT/PATCH/DELETE) of main.app carries an explicit RBAC permission
   dependency (require_permission / require_admin / require_manager_or_admin). The only exceptions are the
   self-service routes in SELF_SERVICE_WRITE_ROUTES (login / refresh / logout / own password / own inbox).
2. Runtime: the read-only AUDITOR_VIEWER role gets 403 on every write route of the routers that used to accept
   any logged-in user (cargox, incoterms, integrations, suppliers, import companies, partners, bank form 4,
   freight data, smart checklists, simulation, formal letters, container loader, route intelligence, currencies).
3. Audit columns: created_by / updated_by carry the authenticated user on suppliers, import companies,
   currencies and incoterms.
"""
import uuid
from datetime import date, timedelta
from typing import Iterable, Iterator, List, Optional, Set, Tuple

import pytest
from fastapi.routing import APIRoute
from fastapi.testclient import TestClient

import main
import modules.auth.permissions as auth_permissions
from database.database import SessionLocal
from modules.auth.permissions import invalidate_permission_cache
from modules.auth.security import create_access_token, hash_password
from modules.auth.seed_rbac import PERMISSIONS_CATALOG, ROLES_CONFIG, seed_rbac
from modules.users.model import Role, User

WRITE_METHODS = {"POST", "PUT", "PATCH", "DELETE"}

# Write routes reachable with a plain authenticated session: they only act on the caller's own session,
# password or notification inbox, so no RBAC permission applies.
SELF_SERVICE_WRITE_ROUTES: Set[Tuple[str, str]] = {
    ("POST", "/api/v1/auth/login"),
    ("POST", "/api/v1/auth/refresh"),
    ("POST", "/api/v1/auth/logout"),
    ("POST", "/api/v1/auth/me/change-password"),
    ("PATCH", "/api/v1/notifications/{notification_id}/read"),
    ("POST", "/api/v1/notifications/mark-all-read"),
}

PERMISSION_CALLABLE_NAMES = {"require_admin", "require_manager_or_admin"}

# Routers locked down by this card: every write route must refuse the read-only role.
LOCKED_DOWN_MODULES = {
    "modules.cargox.router",
    "modules.incoterms.router",
    "modules.integrations.router",
    "modules.suppliers.router",
    "modules.import_companies.router",
    "modules.external_service_providers.router",
    "modules.bank_form4.router",
    "modules.freight_data_connector.router",
    "modules.smart_checklists.router",
    "modules.simulation.router",
    "modules.formal_letters.router",
    "modules.container_loader.router",
    "modules.route_intelligence.router",
    "modules.currencies.router",
}
# Pure calculators of a locked-down router that only need the matching view permission.
READ_ONLY_CALCULATORS = {
    ("POST", "/api/v1/currencies/convert"),
    ("POST", "/api/v1/currencies/gain-loss"),
}


def _is_permission_callable(call: object) -> bool:
    if call is None:
        return False
    if getattr(call, "__name__", "") in PERMISSION_CALLABLE_NAMES:
        return True
    qualname = getattr(call, "__qualname__", "")
    # require_any_permission (smart upload) enforces "one of" several RBAC codes + a per-module check.
    return qualname.startswith("require_permission.") or qualname.startswith("require_any_permission.")


def _dependant_has_permission(dependant: object) -> bool:
    if _is_permission_callable(getattr(dependant, "call", None)):
        return True
    return any(_dependant_has_permission(sub) for sub in getattr(dependant, "dependencies", []) or [])


def _walk(routes: Iterable[object], prefix: str = "", inherited: bool = False) -> Iterator[Tuple[APIRoute, str, bool]]:
    for route in routes:
        if type(route).__name__ == "_IncludedRouter":
            ctx = route.include_context
            include_has = any(_is_permission_callable(getattr(d, "dependency", None)) for d in ctx.dependencies or [])
            yield from _walk(ctx.included_router.routes, prefix + (ctx.prefix or ""), inherited or include_has)
        elif isinstance(route, APIRoute):
            yield route, prefix + route.path, inherited or _dependant_has_permission(route.dependant)


def _write_routes() -> List[Tuple[str, str, str, bool]]:
    rows = []
    for route, path, protected in _walk(main.app.routes):
        for method in sorted((route.methods or set()) & WRITE_METHODS):
            rows.append((method, path, route.endpoint.__module__, protected))
    return rows


def _concrete(path: str) -> str:
    import re

    return re.sub(r"\{[^}]+\}", "1", path)


# ─── 1. Static coverage ──────────────────────────────────────────────────────

def test_self_service_allow_list_routes_exist():
    served = {(m, p) for m, p, _mod, _prot in _write_routes()}
    assert len(served) > 200, f"route walker found only {len(served)} write routes"
    assert not (SELF_SERVICE_WRITE_ROUTES - served), SELF_SERVICE_WRITE_ROUTES - served


def test_every_write_route_requires_a_permission():
    missing = sorted(
        f"{module}: {method} {path}"
        for method, path, module, protected in _write_routes()
        if not protected and (method, path) not in SELF_SERVICE_WRITE_ROUTES
    )
    assert not missing, f"{len(missing)} write route(s) without an RBAC permission dependency:\n" + "\n".join(missing)


def test_business_partners_permission_is_seeded_for_operational_roles():
    catalog = {entry["code"] for entry in PERMISSIONS_CATALOG}
    assert "business_partners.manage" in catalog
    roles = {r["code"]: r["permissions"] for r in ROLES_CONFIG}
    assert "business_partners.manage" in roles["GENERAL_MANAGER"]
    assert "business_partners.manage" in roles["LOGISTICS_OPERATOR"]
    assert "business_partners.manage" not in roles["AUDITOR_VIEWER"]


# ─── 2. Read-only role gets 403 ──────────────────────────────────────────────

def _make_user(role_code: str) -> User:
    db = SessionLocal()
    try:
        seed_rbac(db)
        role = db.query(Role).filter(Role.role_code == role_code).one()
        username = f"rbac_{role_code.lower()}_{uuid.uuid4().hex[:8]}"
        user = User(
            username=username,
            email=f"{username}@test.local",
            full_name=username,
            hashed_password=hash_password("Password123"),
            role=role.role_code,
            role_id=role.role_id,
            is_active=True,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        db.expunge(user)
        return user
    finally:
        db.close()


def _bearer(user: User) -> dict:
    token = create_access_token({"sub": str(user.user_id), "username": user.username, "role": user.role, "tv": 0})
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture(scope="module")
def auditor() -> User:
    invalidate_permission_cache()
    return _make_user("AUDITOR_VIEWER")


@pytest.fixture
def strict_client(monkeypatch):
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", False)
    invalidate_permission_cache()
    return TestClient(main.app, raise_server_exceptions=False)


def _locked_down_routes() -> List[Tuple[str, str]]:
    return sorted(
        (method, path)
        for method, path, module, _prot in _write_routes()
        if module in LOCKED_DOWN_MODULES and (method, path) not in READ_ONLY_CALCULATORS
    )


def test_locked_down_route_inventory_covers_the_audited_endpoints():
    # The audit counted 74 write endpoints in 13 routers plus the currency CRUD; both incoterm create routes
    # and the slash aliases are served, so the inventory is at least that large.
    assert len(_locked_down_routes()) >= 74


@pytest.mark.parametrize("method,path", _locked_down_routes())
def test_read_only_role_is_forbidden(strict_client, auditor, method, path):
    response = strict_client.request(method, _concrete(path), headers=_bearer(auditor))
    assert response.status_code == 403, f"{method} {path} -> {response.status_code}: {response.text[:200]}"


def test_read_only_role_may_use_currency_calculators(strict_client, auditor):
    # Calculators require master_data.view, which the auditor holds: anything but 401/403 proves the gate.
    response = strict_client.post("/api/v1/currencies/convert", json={}, headers=_bearer(auditor))
    assert response.status_code not in (401, 403)


# ─── 3. Audit columns carry the acting user ──────────────────────────────────

@pytest.fixture(scope="module")
def operator() -> User:
    return _make_user("LOGISTICS_OPERATOR")


@pytest.fixture(scope="module")
def admin() -> User:
    return _make_user("ADMIN")


def test_supplier_create_update_records_actor(strict_client, operator):
    suffix = uuid.uuid4().hex[:6].upper()
    created = strict_client.post(
        "/api/v1/suppliers",
        json={
            "company_name": f"Audit Supplier {suffix}",
            "supplier_type": "Manufacturer",
            "registration_type": "Factory",
            "foreign_exporter_id": f"EXP-AUD-{suffix}",
            "foreign_exporter_country": "China",
            "foreign_exporter_country_code": "CN",
            "address": "Hangzhou",
            "created_by": "spoofed",
        },
        headers=_bearer(operator),
    )
    assert created.status_code == 201, created.text
    body = created.json()
    assert body["created_by"] == operator.username
    updated = strict_client.put(
        f"/api/v1/suppliers/{body['supplier_id']}",
        json={"notes": "checked", "updated_by": "spoofed"},
        headers=_bearer(operator),
    )
    assert updated.status_code == 200, updated.text
    assert updated.json()["updated_by"] == operator.username


def test_import_company_create_records_actor(strict_client, operator):
    suffix = uuid.uuid4().hex[:6].upper()
    future = (date.today() + timedelta(days=200)).isoformat()
    created = strict_client.post(
        "/api/v1/import-companies",
        json={
            "importer_name": f"Audit Importer {suffix}",
            "address": "Cairo",
            "country": "Egypt",
            "importer_id": f"IMP-{suffix}",
            "importer_id_expiry": future,
            "vat_id": f"VAT-{suffix}",
            "vat_id_expiry": future,
            "registration_number": f"REG-{suffix}",
            "registration_expiry": future,
        },
        headers=_bearer(operator),
    )
    assert created.status_code in (200, 201), created.text
    company_id = created.json()["company_id"]
    from modules.import_companies.model import ImportCompany

    db = SessionLocal()
    try:
        assert db.get(ImportCompany, company_id).created_by == operator.username
    finally:
        db.close()


def test_currency_create_records_actor(strict_client, admin):
    code = "Q" + uuid.uuid4().hex[:2].upper()
    created = strict_client.post(
        "/api/v1/currencies",
        json={"currency_code": code, "currency_name": f"Audit Coin {code}", "currency_symbol": code, "decimal_places": 2},
        headers=_bearer(admin),
    )
    assert created.status_code == 201, created.text
    from modules.currencies.model import Currency

    db = SessionLocal()
    try:
        currency = db.get(Currency, created.json()["currency_id"])
        assert currency.created_by == admin.username
    finally:
        db.close()


def test_incoterm_create_and_delete_record_actor(strict_client, admin):
    code = "Z" + uuid.uuid4().hex[:2].upper()
    created = strict_client.post(
        "/api/v1/incoterms",
        json={"incoterm_code": code, "incoterm_name": f"Audit Term {code}"},
        headers=_bearer(admin),
    )
    assert created.status_code == 200, created.text
    body = created.json()
    assert body["created_by"] == admin.username
    deleted = strict_client.delete(f"/api/v1/incoterms/{body['incoterm_id']}", headers=_bearer(admin))
    assert deleted.status_code == 200, deleted.text
    assert deleted.json()["updated_by"] == admin.username


def test_operator_cannot_edit_reference_master_data(strict_client, operator):
    """Incoterms / currencies stay admin-level master data (master_data.edit)."""
    response = strict_client.post(
        "/api/v1/incoterms", json={"incoterm_code": "ZZZ", "incoterm_name": "x"}, headers=_bearer(operator)
    )
    assert response.status_code == 403
