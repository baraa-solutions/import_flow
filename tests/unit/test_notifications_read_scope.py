"""
Notification read flags are scoped to the caller's audience (Trello UOroUoqq review):
a non-admin user may only mark notifications addressed to ALL or to its own role as read, and
"mark all read" no longer clears every role's notifications. Producers address notifications with
business audience names (LOGISTICS_OFFICER, COORDINATOR, CUSTOMS_BROKER, legacy MANAGER / OPERATOR) that
notifications.utils maps to RBAC role codes.
"""
from types import SimpleNamespace

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.auth.seed_rbac import ROLES_CONFIG
from modules.notifications.model import SystemNotification
from modules.notifications.service import NotificationService
from modules.notifications.utils import (
    AUDIENCE_ROLE_ALIASES,
    audience_names_for_roles,
    canonical_role,
    is_addressed_to,
    normalize_audience,
)

# target_role values written by the producers on company/main (freight booking, ACID session, demurrage policy,
# expiry checker, banking documents, payment requests) plus the legacy strings.
PRODUCER_AUDIENCES = (
    "ALL", "ADMIN", "GENERAL_MANAGER", "FINANCE_OFFICER",
    "LOGISTICS_OFFICER", "COORDINATOR", "CUSTOMS_BROKER", "MANAGER", "OPERATOR",
)


@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    session = sessionmaker(bind=engine)()
    for audience in PRODUCER_AUDIENCES:
        session.add(SystemNotification(title=f"for {audience}", message="m", target_role=audience))
    session.commit()
    yield session
    session.close()
    engine.dispose()


def _user(role, role_code=None):
    return SimpleNamespace(role=role, assigned_role=SimpleNamespace(role_code=role_code) if role_code else None)


def _notification(db, audience):
    return db.query(SystemNotification).filter(SystemNotification.target_role == audience).one()


def _unread(db):
    return sorted(n.target_role for n in db.query(SystemNotification).filter(SystemNotification.is_read == False))


# ─── mapping ─────────────────────────────────────────────────────────────────

def test_aliases_point_to_real_role_codes():
    role_codes = {r["code"] for r in ROLES_CONFIG}
    assert set(AUDIENCE_ROLE_ALIASES.values()) <= role_codes


def test_every_producer_audience_resolves_to_all_or_a_role_code():
    role_codes = {r["code"] for r in ROLES_CONFIG}
    for audience in PRODUCER_AUDIENCES:
        assert canonical_role(audience) in role_codes | {"ALL"}, audience


def test_audience_names_include_aliases():
    names = audience_names_for_roles({"LOGISTICS_OPERATOR"})
    assert {"ALL", "LOGISTICS_OPERATOR", "LOGISTICS_OFFICER", "COORDINATOR", "OPERATOR"} <= names
    assert "CUSTOMS_BROKER" not in names
    assert is_addressed_to("CUSTOMS_BROKER", {"CUSTOMS_OFFICER"})
    assert not is_addressed_to("CUSTOMS_BROKER", {"LOGISTICS_OPERATOR"})


def test_audience_roles():
    assert NotificationService.audience_roles(_user("ADMIN")) is None
    assert NotificationService.audience_roles(_user("OPERATOR", "LOGISTICS_OPERATOR")) == {"LOGISTICS_OPERATOR"}
    assert NotificationService.audience_roles(_user("MANAGER")) == {"GENERAL_MANAGER"}
    assert NotificationService.audience_roles(None) == set()


# ─── mark one read ───────────────────────────────────────────────────────────

@pytest.mark.parametrize(
    "audience,user",
    [
        ("LOGISTICS_OFFICER", _user("LOGISTICS_OPERATOR", "LOGISTICS_OPERATOR")),
        ("COORDINATOR", _user("LOGISTICS_OPERATOR", "LOGISTICS_OPERATOR")),
        ("CUSTOMS_BROKER", _user("CUSTOMS_OFFICER", "CUSTOMS_OFFICER")),
        ("MANAGER", _user("GENERAL_MANAGER", "GENERAL_MANAGER")),
        ("FINANCE_OFFICER", _user("FINANCE_OFFICER", "FINANCE_OFFICER")),
        ("ALL", _user("AUDITOR_VIEWER", "AUDITOR_VIEWER")),
    ],
)
def test_mapped_audience_can_mark_read(db, audience, user):
    updated = NotificationService(db).mark_read(_notification(db, audience).notification_id, user=user)
    assert updated.is_read is True


@pytest.mark.parametrize(
    "audience,user",
    [
        ("LOGISTICS_OFFICER", _user("CUSTOMS_OFFICER", "CUSTOMS_OFFICER")),
        ("CUSTOMS_BROKER", _user("LOGISTICS_OPERATOR", "LOGISTICS_OPERATOR")),
        ("ADMIN", _user("OPERATOR")),
        ("FINANCE_OFFICER", _user("AUDITOR_VIEWER", "AUDITOR_VIEWER")),
    ],
)
def test_unrelated_role_gets_404(db, audience, user):
    notification = _notification(db, audience)
    with pytest.raises(HTTPException) as exc:
        NotificationService(db).mark_read(notification.notification_id, user=user)
    assert exc.value.status_code == 404
    db.refresh(notification)
    assert notification.is_read is False


# ─── mark all read ───────────────────────────────────────────────────────────

def test_mark_all_by_logistics_operator_clears_mapped_audiences_only(db):
    count = NotificationService(db).mark_all_read(user=_user("LOGISTICS_OPERATOR", "LOGISTICS_OPERATOR"))
    assert count == 4  # ALL, LOGISTICS_OFFICER, COORDINATOR, OPERATOR
    assert _unread(db) == ["ADMIN", "CUSTOMS_BROKER", "FINANCE_OFFICER", "GENERAL_MANAGER", "MANAGER"]


def test_mark_all_by_customs_officer_clears_customs_broker(db):
    NotificationService(db).mark_all_read(user=_user("CUSTOMS_OFFICER", "CUSTOMS_OFFICER"))
    assert "CUSTOMS_BROKER" not in _unread(db)
    assert "LOGISTICS_OFFICER" in _unread(db)


def test_operator_cannot_widen_scope_with_target_role(db):
    NotificationService(db).mark_all_read(target_role="ADMIN", user=_user("OPERATOR"))
    # target_role=ADMIN narrows to ALL+ADMIN, the audience to the logistics names: only ALL is cleared
    assert "ALL" not in _unread(db)
    assert len(_unread(db)) == len(PRODUCER_AUDIENCES) - 1


def test_mark_all_read_by_admin_is_unrestricted(db):
    assert NotificationService(db).mark_all_read(user=_user("ADMIN")) == len(PRODUCER_AUDIENCES)
    assert _unread(db) == []


# ─── normalisation of legacy / free-text audiences ───────────────────────────

def test_canonical_role_normalises_case_spaces_and_hyphens():
    assert canonical_role(" Customs Broker ") == "CUSTOMS_OFFICER"
    assert canonical_role("logistics-officer") == "LOGISTICS_OPERATOR"
    assert canonical_role("general manager") == "GENERAL_MANAGER"


def test_legacy_free_text_audience_is_cleared_by_mapped_role(db):
    legacy = SystemNotification(title="legacy", message="m", target_role="Customs Broker")
    db.add(legacy)
    db.commit()
    NotificationService(db).mark_all_read(user=_user("CUSTOMS_OFFICER", "CUSTOMS_OFFICER"))
    db.refresh(legacy)
    assert legacy.is_read is True


def test_legacy_free_text_audience_is_not_cleared_by_other_roles(db):
    legacy = SystemNotification(title="legacy", message="m", target_role="Customs Broker")
    db.add(legacy)
    db.commit()
    NotificationService(db).mark_all_read(user=_user("LOGISTICS_OPERATOR", "LOGISTICS_OPERATOR"))
    db.refresh(legacy)
    assert legacy.is_read is False
    with pytest.raises(HTTPException):
        NotificationService(db).mark_read(legacy.notification_id, user=_user("LOGISTICS_OPERATOR", "LOGISTICS_OPERATOR"))
    officer = _user("CUSTOMS_OFFICER", "CUSTOMS_OFFICER")
    assert NotificationService(db).mark_read(legacy.notification_id, user=officer).is_read is True


# ─── every producer in modules/ uses a known audience ────────────────────────

def _producer_audiences():
    """(file:line, value) for every string literal passed as a notification target_role in modules/:
    target_role= keywords, "target_role": dict entries, and positional arguments of local helpers whose
    parameter is named target_role (e.g. payment_request_service._notify(..., "FINANCE_OFFICER"))."""
    import ast
    from pathlib import Path

    root = Path(__file__).resolve().parents[2] / "modules"
    found = []
    for path in root.rglob("*.py"):
        tree = ast.parse(path.read_text(encoding="utf-8-sig"))  # some sources carry a UTF-8 BOM
        rel = path.relative_to(root.parent)
        positional = {}
        for node in ast.walk(tree):
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                names = [a.arg for a in node.args.args]
                if "target_role" in names:
                    bound = 1 if names and names[0] in ("self", "cls") else 0
                    positional[node.name] = names.index("target_role") - bound
        for node in ast.walk(tree):
            if isinstance(node, ast.Call):
                for kw in node.keywords:
                    if kw.arg == "target_role" and isinstance(kw.value, ast.Constant) and isinstance(kw.value.value, str):
                        found.append((f"{rel}:{node.lineno}", kw.value.value))
                func_name = getattr(node.func, "id", None) or getattr(node.func, "attr", None)
                idx = positional.get(func_name)
                if idx is not None and len(node.args) > idx:
                    arg = node.args[idx]
                    if isinstance(arg, ast.Constant) and isinstance(arg.value, str):
                        found.append((f"{rel}:{node.lineno}", arg.value))
            elif isinstance(node, ast.Dict):
                for key, value in zip(node.keys, node.values):
                    if (isinstance(key, ast.Constant) and key.value == "target_role"
                            and isinstance(value, ast.Constant) and isinstance(value.value, str)):
                        found.append((f"{rel}:{node.lineno}", value.value))
    return found


def test_producer_scan_finds_the_known_writers():
    values = {value for _where, value in _producer_audiences()}
    assert {"LOGISTICS_OFFICER", "CUSTOMS_BROKER", "FINANCE_OFFICER", "COORDINATOR"} <= values


def test_every_producer_audience_canonicalises_to_a_seeded_role():
    allowed = {r["code"] for r in ROLES_CONFIG} | {"ALL"}
    bad = [f"{where}: {value!r}" for where, value in _producer_audiences() if canonical_role(value) not in allowed]
    assert not bad, "notification target_role values that reach no role:\n" + "\n".join(bad)


def test_every_producer_audience_is_written_normalised():
    bad = [f"{where}: {value!r}" for where, value in _producer_audiences() if value != normalize_audience(value)]
    assert not bad, "write target_role in canonical form (UPPER_SNAKE):\n" + "\n".join(bad)


# ─── POST /notifications validates the audience ──────────────────────────────

def test_create_schema_rejects_unknown_audience():
    from pydantic import ValidationError

    from modules.notifications.schemas import NotificationCreate

    with pytest.raises(ValidationError):
        NotificationCreate(title="t", message="m", target_role="BOGUS_ROLE")
    assert NotificationCreate(title="t", message="m", target_role="Customs Broker").target_role == "CUSTOMS_BROKER"
    assert NotificationCreate(title="t", message="m").target_role == "ALL"
