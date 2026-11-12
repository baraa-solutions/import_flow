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
