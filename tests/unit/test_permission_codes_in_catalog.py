"""Every permission code referenced by backend code must exist in the RBAC catalog.

A misspelled code in ``require_permission("...")`` still counts as "protected" for
``test_route_auth_coverage`` but silently makes the route admin-only, so guard it here.
"""
import re
from pathlib import Path

from modules.auth.seed_rbac import PERMISSIONS_CATALOG

ROOT = Path(__file__).resolve().parents[2]
_PATTERNS = (
    re.compile(r"require_permission\(\s*[\"']([a-z0-9_]+\.[a-z0-9_]+)[\"']"),
    re.compile(r"has_user_permission\([^)]*?[\"']([a-z0-9_]+\.[a-z0-9_]+)[\"']"),
)


def _referenced_codes():
    found = {}
    for path in (ROOT / "modules").rglob("*.py"):
        text = path.read_text(encoding="utf-8", errors="ignore")
        for pattern in _PATTERNS:
            for code in pattern.findall(text):
                found.setdefault(code, set()).add(str(path.relative_to(ROOT)))
    return found


def _route_permission_codes():
    """Permission codes actually bound to main.app routes (read from the require_permission closures).

    Catches codes held in module constants, which the text scan above cannot see.
    """
    from fastapi.routing import APIRoute

    import main

    def walk(dependant):
        for dep in dependant.dependencies:
            call = dep.call
            code = getattr(call, "__code__", None)
            if code is not None and "permission_code" in code.co_freevars and call.__closure__:
                value = call.__closure__[code.co_freevars.index("permission_code")].cell_contents
                if isinstance(value, str):
                    yield value
            yield from walk(dep)

    def routes(items, prefix=""):
        # FastAPI 0.141 wraps include_router() in _IncludedRouter (same walk as test_route_auth_coverage)
        for item in items:
            if type(item).__name__ == "_IncludedRouter":
                ctx = item.include_context
                yield from routes(ctx.included_router.routes, prefix + (ctx.prefix or ""))
            elif isinstance(item, APIRoute):
                yield item, prefix + item.path

    found = {}
    for route, path in routes(main.app.routes):
        for code in walk(route.dependant):
            found.setdefault(code, set()).add(f"{sorted(route.methods)} {path}")
    return found


def test_route_bound_permission_codes_exist_in_catalog():
    catalog = {entry["code"] for entry in PERMISSIONS_CATALOG}
    bound = _route_permission_codes()
    assert len(bound) >= 20, f"too few permission codes found on routes ({len(bound)}): introspection is broken"
    unknown = {code: sorted(routes)[:3] for code, routes in bound.items() if code not in catalog}
    assert not unknown, f"routes require permission codes missing from PERMISSIONS_CATALOG: {unknown}"


def test_referenced_permission_codes_exist_in_catalog():
    catalog = {entry["code"] for entry in PERMISSIONS_CATALOG}
    referenced = _referenced_codes()
    assert referenced, "no permission references found: the scan pattern is broken"
    unknown = {code: sorted(files) for code, files in referenced.items() if code not in catalog}
    assert not unknown, f"permission codes not in PERMISSIONS_CATALOG: {unknown}"
