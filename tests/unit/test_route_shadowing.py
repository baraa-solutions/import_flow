"""Guard: no literal route may be unreachable behind an earlier parameterised route.

FastAPI matches routes in declaration order, so GET /logistics-invoices/{id} declared before
GET /logistics-invoices/advances made /advances answer 422 ("advances" is not an int) and the
Clearance Advances / Payment Vouchers tabs never loaded. The OpenAPI paths keep declaration order.
"""
import re

from main import app


def _pattern(path: str) -> re.Pattern:
    return re.compile("^" + re.sub(r"\\\{[^}]+\\\}", r"[^/]+", re.escape(path)) + "$")


def _shadowed_routes():
    ordered = [
        (index, method.upper(), path)
        for index, (path, operations) in enumerate(app.openapi()["paths"].items())
        for method in operations
    ]
    shadowed = []
    for index, method, path in ordered:
        if "{" in path:
            continue
        for earlier_index, earlier_method, earlier_path in ordered:
            if (
                earlier_index < index
                and earlier_method == method
                and "{" in earlier_path
                and _pattern(earlier_path).match(path)
            ):
                shadowed.append(f"{method} {path} is captured by {earlier_path}")
                break
    return shadowed


def test_no_literal_route_is_shadowed_by_an_earlier_path_parameter():
    assert _shadowed_routes() == []
