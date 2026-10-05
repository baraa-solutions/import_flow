"""
Break-glass admin (CTO decision 2026-10-05).

Old installs whose users table was not empty never got the seeded admin, and their only user is not an
ADMIN, so nobody could install updates (system.update = ADMIN only). sync_system_users now creates an
admin when users exist but none is an ACTIVE admin:
- "admin" when that username is free, otherwise "admin_recovery" / "admin_recovery2"...: a taken "admin"
  row (inactive or non-admin) is never elevated or reactivated;
- ADMIN_INITIAL_PASSWORD, role ADMIN, active, must_change_password=True; WARNING log + AuditLog row;
- existing users are never touched; idempotent once any active admin exists.

Also: the legacy `role` string is compared case-insensitively everywhere in modules/auth ("Admin" is admin).
"""
import logging

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

import database.master_data_sync_service as mds
import database.models  # noqa: F401 - registers every model in Base.metadata
import settings
from database.database import Base
from modules.audit_logs.model import AuditLog
from modules.auth.permissions import (
    _dev_bypass_fallback_user,
    get_user_effective_permissions,
    has_user_permission,
    invalidate_permission_cache,
)
from modules.auth.router import require_manager_or_admin
from modules.auth.security import hash_password, verify_password
from modules.auth.seed_rbac import seed_rbac
from modules.users.model import Role, User

DEFAULT_PASSWORD = "Admin@123"
OWN_PASSWORD = "Their-Own-Pass-77"


@pytest.fixture
def session(tmp_path, monkeypatch):
    env_file = tmp_path / ".env"
    env_file.write_text("SECRET_KEY=" + "s" * 40 + "\n", encoding="utf-8")
    monkeypatch.setattr(settings, "ENV_PATH", env_file)
    monkeypatch.setattr(mds, "ADMIN_INITIAL_PASSWORD", settings.DEFAULT_ADMIN_PASSWORD)
    engine = create_engine(f"sqlite:///{(tmp_path / 'users.db').as_posix()}")
    Base.metadata.create_all(bind=engine)  # seed_rbac also uses system_parameters
    db = sessionmaker(bind=engine)()
    invalidate_permission_cache()
    yield db
    db.close()
    engine.dispose()
    invalidate_permission_cache()


def _user(db, username, role="OPERATOR", is_active=True, email=None, role_id=None):
    user = User(
        username=username,
        email=email or f"{username}@example.com",
        full_name=username.title(),
        hashed_password=hash_password(OWN_PASSWORD),
        role=role,
        role_id=role_id,
        is_active=is_active,
    )
    db.add(user)
    db.commit()
    return user


def _snapshot(user):
    return (user.username, user.email, user.role, user.role_id, user.is_active,
            user.hashed_password, user.must_change_password, user.updated_at)


def _sync(db):
    return mds.MasterDataSyncService(db).sync_system_users()


# ── seeding ──────────────────────────────────────────────────────────────────────

def test_fresh_db_seeds_admin_as_before(session):
    assert _sync(session) == 1
    users = session.query(User).all()
    assert [u.username for u in users] == ["admin"]
    admin = users[0]
    assert admin.email == "admin@sorourlogistics.com"
    assert admin.role == "ADMIN" and admin.is_active is True and admin.must_change_password is True
    assert verify_password(DEFAULT_PASSWORD, admin.hashed_password)
    assert session.query(AuditLog).count() == 0  # a fresh install is not a break-glass event
    assert _sync(session) == 0


def test_users_without_admin_get_break_glass_admin(session, caplog):
    operator = _user(session, "ahmed", role="OPERATOR")
    before = _snapshot(operator)

    with caplog.at_level(logging.WARNING, logger=mds.__name__):
        assert _sync(session) == 1

    admin = session.query(User).filter(User.username == "admin").one()
    assert admin.role == "ADMIN" and admin.is_active is True and admin.must_change_password is True
    assert admin.email == "admin@sorourlogistics.com"
    assert verify_password(DEFAULT_PASSWORD, admin.hashed_password)
    session.refresh(operator)
    assert _snapshot(operator) == before
    assert any("break-glass" in r.getMessage() for r in caplog.records if r.levelno == logging.WARNING)

    log = session.query(AuditLog).one()
    assert log.action == mds.BREAK_GLASS_AUDIT_ACTION
    assert log.performed_by == "system"
    assert (log.entity_type, log.entity_id, log.entity_code) == ("User", admin.user_id, "admin")

    # idempotent: the new admin is an active admin
    assert _sync(session) == 0
    assert session.query(User).count() == 2
    assert session.query(AuditLog).count() == 1


@pytest.mark.parametrize("role,is_active", [("OPERATOR", True), ("ADMIN", False), ("MANAGER", False)])
def test_taken_admin_username_gets_admin_recovery_and_is_untouched(session, role, is_active):
    old_admin = _user(session, "admin", role=role, is_active=is_active, email="admin@sorourlogistics.com")
    before = _snapshot(old_admin)

    assert _sync(session) == 1

    session.refresh(old_admin)
    assert _snapshot(old_admin) == before
    recovery = session.query(User).filter(User.username == "admin_recovery").one()
    assert recovery.email == "admin_recovery@sorourlogistics.com"
    assert recovery.role == "ADMIN" and recovery.is_active is True and recovery.must_change_password is True
    assert verify_password(DEFAULT_PASSWORD, recovery.hashed_password)
    assert session.query(AuditLog).one().entity_code == "admin_recovery"
    assert _sync(session) == 0
    assert session.query(User).count() == 2


def test_next_free_recovery_name_when_recovery_names_are_taken(session):
    _user(session, "Admin", role="OPERATOR")  # case-insensitive: "admin" counts as taken
    _user(session, "admin_recovery", role="ADMIN", is_active=False)
    _user(session, "someone", role="OPERATOR", email="admin_recovery2@sorourlogistics.com")  # email taken

    assert _sync(session) == 1

    created = session.query(User).filter(User.must_change_password == True).one()  # noqa: E712
    assert created.username == "admin_recovery3"
    assert created.email == "admin_recovery3@sorourlogistics.com"
    assert created.role == "ADMIN"


@pytest.mark.parametrize("legacy_role", ["ADMIN", "Admin", "admin"])
def test_any_case_active_admin_means_nothing_created(session, legacy_role):
    _user(session, "boss", role=legacy_role)
    _user(session, "ahmed", role="OPERATOR")
    assert _sync(session) == 0
    assert session.query(User).count() == 2
    assert session.query(AuditLog).count() == 0


def test_assigned_admin_rbac_role_means_nothing_created(session):
    seed_rbac(session)
    admin_role = session.query(Role).filter(Role.role_code == "ADMIN").one()
    _user(session, "boss", role="LOGISTICS_OPERATOR", role_id=admin_role.role_id)
    assert _sync(session) == 0
    assert session.query(User).count() == 1


def test_inactive_admin_only_does_not_count(session):
    _user(session, "boss", role="ADMIN", is_active=False)
    assert _sync(session) == 1
    assert session.query(User).filter(User.username == "admin").one().must_change_password is True


def test_audit_failure_keeps_the_admin(session, monkeypatch, caplog):
    from sqlalchemy.exc import OperationalError

    def boom(self, **kwargs):
        raise OperationalError("INSERT INTO audit_logs", {}, Exception("no such table: audit_logs"))

    monkeypatch.setattr(mds.AuditLogService, "log_activity", boom)
    _user(session, "ahmed")
    with caplog.at_level(logging.WARNING, logger=mds.__name__):
        assert _sync(session) == 1
    assert session.query(User).filter(User.username == "admin").count() == 1
    assert any("audit row was not written" in r.getMessage() for r in caplog.records)


# ── case-insensitive admin checks ───────────────────────────────────────────────

@pytest.mark.parametrize("legacy_role", ["ADMIN", "Admin", "admin"])
def test_any_case_admin_passes_has_user_permission(session, legacy_role):
    seed_rbac(session)
    user = _user(session, "boss", role=legacy_role)
    assert has_user_permission(session, user, "system.update") is True
    perms = get_user_effective_permissions(session, user.user_id)
    assert "*" in perms and "system.update" in perms


def test_non_admin_does_not_pass_system_update(session):
    seed_rbac(session)
    user = _user(session, "ahmed", role="OPERATOR")
    assert has_user_permission(session, user, "system.update") is False


def test_inactive_admin_fails_has_user_permission(session):
    user = _user(session, "boss", role="Admin", is_active=False)
    assert has_user_permission(session, user, "system.update") is False


def test_require_manager_or_admin_is_case_insensitive(session):
    assert require_manager_or_admin(_user(session, "boss", role="Admin")).username == "boss"
    assert require_manager_or_admin(_user(session, "mgr", role="manager")).username == "mgr"
    with pytest.raises(HTTPException) as exc:
        require_manager_or_admin(_user(session, "op", role="OPERATOR"))
    assert exc.value.status_code == 403


def test_dev_bypass_fallback_prefers_any_case_admin(session):
    _user(session, "op", role="OPERATOR")
    _user(session, "boss", role="Admin")
    assert _dev_bypass_fallback_user(session).username == "boss"
    assert _dev_bypass_fallback_user(session, x_user_role="admin").username == "boss"


def test_seed_rbac_links_any_case_legacy_admin(session):
    user = _user(session, "boss", role="Admin")
    seed_rbac(session)
    session.refresh(user)
    assert user.assigned_role is not None and user.assigned_role.role_code == "ADMIN"
