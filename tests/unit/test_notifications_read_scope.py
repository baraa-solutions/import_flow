"""
Notification read flags are scoped to the caller's audience (Trello UOroUoqq review):
a non-admin user may only mark notifications addressed to ALL or to its own role as read,
and "mark all read" no longer clears every role's notifications.
"""
from types import SimpleNamespace

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.notifications.model import SystemNotification
from modules.notifications.service import NotificationService


@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    session = sessionmaker(bind=engine)()
    for role in ("ALL", "ADMIN", "MANAGER", "OPERATOR", "LOGISTICS_OPERATOR"):
        session.add(SystemNotification(title=f"for {role}", message="m", target_role=role))
    session.commit()
    yield session
    session.close()
    engine.dispose()


def _user(role, role_code=None):
    return SimpleNamespace(role=role, assigned_role=SimpleNamespace(role_code=role_code) if role_code else None)


def _unread_roles(db):
    return sorted(n.target_role for n in db.query(SystemNotification).filter(SystemNotification.is_read == False))


def test_audience_roles():
    assert NotificationService.audience_roles(_user("ADMIN")) is None
    assert NotificationService.audience_roles(_user("OPERATOR", "LOGISTICS_OPERATOR")) == {"OPERATOR", "LOGISTICS_OPERATOR"}
    assert NotificationService.audience_roles(None) == set()


def test_mark_all_read_by_operator_leaves_other_roles_unread(db):
    count = NotificationService(db).mark_all_read(user=_user("OPERATOR", "LOGISTICS_OPERATOR"))
    assert count == 3
    assert _unread_roles(db) == ["ADMIN", "MANAGER"]


def test_operator_cannot_widen_scope_with_target_role(db):
    NotificationService(db).mark_all_read(target_role="ADMIN", user=_user("OPERATOR"))
    # target_role=ADMIN narrows to ALL+ADMIN, the audience to ALL+OPERATOR: only ALL is cleared
    assert _unread_roles(db) == ["ADMIN", "LOGISTICS_OPERATOR", "MANAGER", "OPERATOR"]


def test_mark_all_read_by_admin_is_unrestricted(db):
    assert NotificationService(db).mark_all_read(user=_user("ADMIN")) == 5
    assert _unread_roles(db) == []


def test_mark_single_read_outside_audience_is_404(db):
    admin_only = db.query(SystemNotification).filter(SystemNotification.target_role == "ADMIN").one()
    with pytest.raises(HTTPException) as exc:
        NotificationService(db).mark_read(admin_only.notification_id, user=_user("OPERATOR"))
    assert exc.value.status_code == 404
    db.refresh(admin_only)
    assert admin_only.is_read is False


def test_mark_single_read_inside_audience(db):
    for_all = db.query(SystemNotification).filter(SystemNotification.target_role == "ALL").one()
    updated = NotificationService(db).mark_read(for_all.notification_id, user=_user("MANAGER"))
    assert updated.is_read is True
