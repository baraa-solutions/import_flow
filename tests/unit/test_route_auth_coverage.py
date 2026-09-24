"""
Route auth coverage harness.

Every HTTP route of main.app must require a valid JWT, except the explicit PUBLIC_ROUTES allow-list below.
The checks run with ALLOW_DEV_AUTH_BYPASS forced to False so the desktop bypass cannot mask a missing
dependency.

(a) static: each non-public APIRoute has an auth callable somewhere in its dependency tree
    (route, router-level or include-level dependencies).
(b) HTTP: each non-public route, called with no headers and no body, answers 401.
    Routes that fail (a) are NOT executed (an unprotected route could have side effects); they are
    reported as failures instead.
(c) /docs, /redoc and /openapi.json are not served by default.

WebSocket routes are not APIRoutes: /api/v1/notifications/ws authenticates through its first frame and
is covered by test_notifications_ws_auth.py.
"""

import re
from typing import Iterable, Iterator, List, Optional, Set, Tuple

import pytest
from fastapi.routing import APIRoute
from fastapi.testclient import TestClient

import main
import modules.auth.permissions as auth_permissions


# (method, path) pairs reachable without a token: pre-login and liveness calls only.
PUBLIC_ROUTES: Set[Tuple[str, str]] = {
    ("GET", "/"),
    ("GET", "/health"),
    ("GET", "/api/v1/health"),
    ("GET", "/api/v1/system/version"),
    ("GET", "/api/v1/system/version-check"),
    ("POST", "/api/v1/auth/login"),
    ("POST", "/api/v1/auth/refresh"),
}

AUTH_CALLABLE_NAMES = {
    "get_current_user",
    "require_admin",
    "require_manager_or_admin",
}

SKIPPED_METHODS = {"HEAD", "OPTIONS"}


def _is_auth_callable(call: object) -> bool:
    if call is None:
        return False
    name = getattr(call, "__name__", "")
    qualname = getattr(call, "__qualname__", "")
    return name in AUTH_CALLABLE_NAMES or qualname.startswith("require_permission.")


def _dependant_has_auth(dependant: object) -> bool:
    if _is_auth_callable(getattr(dependant, "call", None)):
        return True
    return any(_dependant_has_auth(sub) for sub in getattr(dependant, "dependencies", []) or [])


def _depends_list_has_auth(depends_list: Optional[Iterable[object]]) -> bool:
    return any(_is_auth_callable(getattr(d, "dependency", None)) for d in depends_list or [])


def _walk(routes: Iterable[object], prefix: str = "", inherited_auth: bool = False) -> Iterator[Tuple[APIRoute, str, bool]]:
    """Yields (route, full_path, protected) for every APIRoute, recursing into FastAPI 0.141 _IncludedRouter."""
    for route in routes:
        if type(route).__name__ == "_IncludedRouter":
            ctx = route.include_context
            yield from _walk(
                ctx.included_router.routes,
                prefix + (ctx.prefix or ""),
                inherited_auth or _depends_list_has_auth(ctx.dependencies),
            )
        elif isinstance(route, APIRoute):
            protected = inherited_auth or _dependant_has_auth(route.dependant)
            yield route, prefix + route.path, protected


def _all_endpoints() -> List[Tuple[str, str, str, bool]]:
    """(method, path, module, protected) for every HTTP endpoint of main.app."""
    rows = []
    for route, path, protected in _walk(main.app.routes):
        module = getattr(route.endpoint, "__module__", "?")
        for method in sorted(route.methods or []):
            if method in SKIPPED_METHODS:
                continue
            rows.append((method, path, module, protected))
    return rows


def _concrete_path(path: str) -> str:
    return re.sub(r"\{[^}]+\}", "1", path)


@pytest.fixture
def strict_auth(monkeypatch):
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", False)
    yield


def test_public_allow_list_routes_exist():
    """Every allow-listed public route is still served (catches typos in PUBLIC_ROUTES)."""
    endpoints = _all_endpoints()
    # Guard against a walker regression silently yielding nothing (e.g. a FastAPI routing change).
    assert len(endpoints) > 100, f"route walker found only {len(endpoints)} endpoints"
    served = {(m, p) for m, p, _mod, _prot in endpoints}
    missing = sorted(PUBLIC_ROUTES - served)
    assert not missing, f"Allow-listed routes not found in main.app: {missing}"


def test_every_non_public_route_declares_auth_dependency(strict_auth):
    """(a) static check over the dependency trees."""
    open_routes = sorted(
        f"{module}: {method} {path}"
        for method, path, module, protected in _all_endpoints()
        if (method, path) not in PUBLIC_ROUTES and not protected
    )
    assert not open_routes, (
        f"{len(open_routes)} route(s) without an auth dependency:\n" + "\n".join(open_routes)
    )


def test_every_non_public_route_returns_401_without_token(strict_auth):
    """(b) runtime check: no headers, no body -> 401."""
    client = TestClient(main.app, raise_server_exceptions=False)
    failures = []
    for method, path, module, protected in _all_endpoints():
        if (method, path) in PUBLIC_ROUTES:
            continue
        if not protected:
            failures.append(f"{module}: {method} {path} -> not requested (no auth dependency)")
            continue
        response = client.request(method, _concrete_path(path))
        if response.status_code != 401:
            failures.append(f"{module}: {method} {path} -> {response.status_code}")
    assert not failures, f"{len(failures)} route(s) not returning 401:\n" + "\n".join(sorted(failures))


def test_public_routes_answer_without_token(strict_auth):
    """The liveness / version endpoints stay reachable before login."""
    client = TestClient(main.app, raise_server_exceptions=False)
    # /health is left out on purpose: it opens the hard-coded sorour_logistics.db in the working directory.
    for path in ("/", "/api/v1/system/version", "/api/v1/system/version-check"):
        response = client.get(path)
        assert response.status_code == 200, f"{path} -> {response.status_code}"


@pytest.mark.parametrize("path", ["/docs", "/redoc", "/openapi.json"])
def test_api_docs_disabled_by_default(path):
    """(c) interactive docs are off unless ENABLE_API_DOCS is set."""
    client = TestClient(main.app, raise_server_exceptions=False)
    assert client.get(path).status_code == 404
