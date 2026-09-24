"""
Privilege-escalation guards in AuthService and the auth router:
a non-ADMIN holding users.manage must not create/promote ADMINs, touch existing ADMIN accounts,
or grant users.manage / permissions they do not hold. Plus resolve_user hardening.
"""

import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import modules.auth.permissions as auth_permissions
from database.database import Base, get_db
from modules.auth.permissions import (
    get_user_effective_permissions,
    has_user_permission,
    invalidate_permission_cache,
    is_admin_user,
    effective_role_code,
    resolve_user,
)
from modules.auth.router import router as auth_router, require_admin, require_manager_or_admin
from modules.auth.schemas import UserCreate, UserPermissionsUpdatePayload, UserUpdate
from modules.auth.security import create_access_token, hash_password
from modules.auth.seed_rbac import seed_rbac
from modules.auth.service import (
    AuthService,
    MSG_ADMIN_ACCOUNT_EDIT_FORBIDDEN,
    MSG_ADMIN_ROLE_GRANT_FORBIDDEN,
    MSG_PERMISSION_GRANT_FORBIDDEN,
    MSG_WIDER_TARGET_FORBIDDEN,
)
from modules.users.model import Permission, Role, User, UserPermission


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


def _role(db, code: str) -> Role:
    return db.query(Role).filter(Role.role_code == code).one()


def _make_user(db, username: str, role_code: str, extra_grants=()) -> User:
    role = _role(db, role_code)
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
    for code in extra_grants:
        perm = db.query(Permission).filter(Permission.permission_code == code).one()
        db.add(UserPermission(user_id=user.user_id, permission_id=perm.permission_id, is_granted=True))
    db.commit()
    invalidate_permission_cache()
    return user


@pytest.fixture
def admin(db) -> User:
    return _make_user(db, "root_admin", "ADMIN")


@pytest.fixture
def delegate(db) -> User:
    """A non-ADMIN user manager: GENERAL_MANAGER role plus a direct users.manage grant."""
    return _make_user(db, "hr_delegate", "GENERAL_MANAGER", extra_grants=("users.manage",))


@pytest.fixture
def operator(db) -> User:
    return _make_user(db, "plain_operator", "LOGISTICS_OPERATOR")


@pytest.fixture
def finance(db) -> User:
    """FINANCE_OFFICER permissions are a subset of GENERAL_MANAGER: the delegate may manage this user."""
    return _make_user(db, "finance_user", "FINANCE_OFFICER")


def _assert_403(exc_info, detail: str) -> None:
    assert exc_info.value.status_code == 403
    assert exc_info.value.detail == detail


def _new_user_payload(username: str, **kwargs) -> UserCreate:
    return UserCreate(
        username=username,
        email=f"{username}@test.com",
        full_name=username,
        password="Password123",
        **kwargs,
    )


# ─── Granting the ADMIN role ─────────────────────────────────────────────────

def test_non_admin_cannot_register_admin_by_role_string(db, delegate):
    with pytest.raises(HTTPException) as exc:
        AuthService(db).register_user(_new_user_payload("sneaky1", role="admin"), actor=delegate)
    _assert_403(exc, MSG_ADMIN_ROLE_GRANT_FORBIDDEN)
    assert db.query(User).filter(User.username == "sneaky1").first() is None


def test_non_admin_cannot_register_admin_by_role_id(db, delegate):
    admin_role = _role(db, "ADMIN")
    with pytest.raises(HTTPException) as exc:
        AuthService(db).register_user(_new_user_payload("sneaky2", role_id=admin_role.role_id), actor=delegate)
    _assert_403(exc, MSG_ADMIN_ROLE_GRANT_FORBIDDEN)


def test_non_admin_cannot_promote_to_admin_via_update_user(db, delegate, finance):
    service = AuthService(db)
    with pytest.raises(HTTPException) as exc:
        service.update_user(finance.user_id, UserUpdate(role=" admin "), actor=delegate)
    _assert_403(exc, MSG_ADMIN_ROLE_GRANT_FORBIDDEN)

    with pytest.raises(HTTPException) as exc:
        service.update_user(finance.user_id, UserUpdate(role_id=_role(db, "ADMIN").role_id), actor=delegate)
    _assert_403(exc, MSG_ADMIN_ROLE_GRANT_FORBIDDEN)


def test_non_admin_cannot_promote_to_admin_via_permissions_endpoint(db, delegate, finance):
    payload = UserPermissionsUpdatePayload(role_id=_role(db, "ADMIN").role_id, permissions=[])
    with pytest.raises(HTTPException) as exc:
        AuthService(db).update_user_permissions(finance.user_id, payload, actor=delegate)
    _assert_403(exc, MSG_ADMIN_ROLE_GRANT_FORBIDDEN)


# ─── Touching an existing ADMIN ──────────────────────────────────────────────

@pytest.mark.parametrize(
    "update",
    [UserUpdate(full_name="Renamed"), UserUpdate(password="NewPassword123"), UserUpdate(role="OPERATOR")],
    ids=["rename", "re-password", "demote"],
)
def test_non_admin_cannot_modify_admin_account(db, delegate, admin, update):
    old_hash = admin.hashed_password
    with pytest.raises(HTTPException) as exc:
        AuthService(db).update_user(admin.user_id, update, actor=delegate)
    _assert_403(exc, MSG_ADMIN_ACCOUNT_EDIT_FORBIDDEN)
    db.refresh(admin)
    assert admin.hashed_password == old_hash
    assert admin.role == "ADMIN"


def test_non_admin_cannot_toggle_admin(db, delegate, admin):
    with pytest.raises(HTTPException) as exc:
        AuthService(db).toggle_user_status(admin.user_id, actor=delegate)
    _assert_403(exc, MSG_ADMIN_ACCOUNT_EDIT_FORBIDDEN)
    db.refresh(admin)
    assert admin.is_active is True


def test_non_admin_cannot_change_admin_permissions(db, delegate, admin):
    payload = UserPermissionsUpdatePayload(permissions=[{"permission_code": "users.manage", "is_granted": False}])
    with pytest.raises(HTTPException) as exc:
        AuthService(db).update_user_permissions(admin.user_id, payload, actor=delegate)
    _assert_403(exc, MSG_ADMIN_ACCOUNT_EDIT_FORBIDDEN)


# ─── Granting permissions ────────────────────────────────────────────────────

def test_non_admin_cannot_grant_users_manage(db, delegate, finance):
    payload = UserPermissionsUpdatePayload(permissions=[{"permission_code": "users.manage", "is_granted": True}])
    with pytest.raises(HTTPException) as exc:
        AuthService(db).update_user_permissions(finance.user_id, payload, actor=delegate)
    _assert_403(exc, MSG_PERMISSION_GRANT_FORBIDDEN)
    assert "users.manage" not in get_user_effective_permissions(db, finance.user_id)


def test_non_admin_cannot_grant_permission_they_do_not_hold(db, delegate, finance):
    held = get_user_effective_permissions(db, delegate.user_id) | get_user_effective_permissions(db, finance.user_id)
    not_held = sorted(
        p.permission_code for p in db.query(Permission).all() if p.permission_code not in held
    )
    assert not_held, "seed catalog should contain permissions outside GENERAL_MANAGER"
    payload = UserPermissionsUpdatePayload(permissions=[{"permission_code": not_held[0], "is_granted": True}])
    with pytest.raises(HTTPException) as exc:
        AuthService(db).update_user_permissions(finance.user_id, payload, actor=delegate)
    _assert_403(exc, MSG_PERMISSION_GRANT_FORBIDDEN)


def test_non_admin_can_grant_held_permission_and_revoke(db, delegate, finance):
    held = get_user_effective_permissions(db, delegate.user_id)
    operator_has = get_user_effective_permissions(db, finance.user_id)
    grantable = sorted(held - operator_has - {"users.manage"})
    assert grantable
    revocable = sorted(operator_has)[0]
    payload = UserPermissionsUpdatePayload(permissions=[
        {"permission_code": grantable[0], "is_granted": True},
        {"permission_code": revocable, "is_granted": False},
    ])
    result = AuthService(db).update_user_permissions(finance.user_id, payload, actor=delegate)
    assert grantable[0] in result["effective_permissions"]
    assert revocable not in result["effective_permissions"]


def test_non_admin_cannot_assign_role_with_permissions_they_lack(db):
    """Role assignment grants the whole role permission set: a narrower delegate cannot hand out a wider role."""
    narrow_delegate = _make_user(db, "narrow_delegate", "AUDITOR_VIEWER", extra_grants=("users.manage",))
    auditor = _make_user(db, "auditor_target", "AUDITOR_VIEWER")
    with pytest.raises(HTTPException) as exc:
        AuthService(db).update_user(
            auditor.user_id, UserUpdate(role_id=_role(db, "GENERAL_MANAGER").role_id), actor=narrow_delegate
        )
    _assert_403(exc, MSG_PERMISSION_GRANT_FORBIDDEN)


def test_non_admin_cannot_self_promote_to_wider_role(db):
    narrow_delegate = _make_user(db, "self_promoter", "AUDITOR_VIEWER", extra_grants=("users.manage",))
    with pytest.raises(HTTPException) as exc:
        AuthService(db).update_user(narrow_delegate.user_id, UserUpdate(role="MANAGER"), actor=narrow_delegate)
    _assert_403(exc, MSG_PERMISSION_GRANT_FORBIDDEN)
    db.refresh(narrow_delegate)
    assert narrow_delegate.role == "AUDITOR_VIEWER"


def test_non_admin_cannot_register_role_wider_than_own(db, delegate):
    """LOGISTICS_OPERATOR carries edit codes (e.g. import_files.create) that GENERAL_MANAGER does not hold."""
    with pytest.raises(HTTPException) as exc:
        AuthService(db).register_user(_new_user_payload("wide_op", role="OPERATOR"), actor=delegate)
    _assert_403(exc, MSG_PERMISSION_GRANT_FORBIDDEN)


def test_non_admin_can_register_and_edit_regular_user(db, delegate, finance):
    service = AuthService(db)
    created = service.register_user(_new_user_payload("new_fin", role="FINANCE_OFFICER"), actor=delegate)
    assert created.role == "FINANCE_OFFICER"

    updated = service.update_user(
        finance.user_id, UserUpdate(full_name="Renamed Fin", password="NewPassword123"), actor=delegate
    )
    assert updated.full_name == "Renamed Fin"

    toggled = service.toggle_user_status(finance.user_id, actor=delegate)
    assert toggled.is_active is False


# ─── ADMIN success paths ─────────────────────────────────────────────────────

def test_admin_can_create_and_manage_admins(db, admin, operator):
    service = AuthService(db)
    new_admin = service.register_user(_new_user_payload("second_admin", role="ADMIN"), actor=admin)
    assert new_admin.role == "ADMIN"

    renamed = service.update_user(new_admin.user_id, UserUpdate(full_name="Second Admin"), actor=admin)
    assert renamed.full_name == "Second Admin"

    toggled = service.toggle_user_status(new_admin.user_id, actor=admin)
    assert toggled.is_active is False

    promoted = service.update_user(operator.user_id, UserUpdate(role_id=_role(db, "ADMIN").role_id), actor=admin)
    assert promoted.role == "ADMIN"


def test_admin_can_grant_users_manage(db, admin, operator):
    payload = UserPermissionsUpdatePayload(permissions=[{"permission_code": "users.manage", "is_granted": True}])
    result = AuthService(db).update_user_permissions(operator.user_id, payload, actor=admin)
    assert "users.manage" in result["custom_grants"]


def test_cannot_toggle_self(db, admin):
    with pytest.raises(HTTPException) as exc:
        AuthService(db).toggle_user_status(admin.user_id, actor=admin)
    assert exc.value.status_code == 400


# ─── HTTP layer ──────────────────────────────────────────────────────────────

@pytest.fixture
def client(session_factory, db):
    app = FastAPI()
    app.include_router(auth_router)

    def override_get_db():
        session = session_factory()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_db] = override_get_db
    return TestClient(app)


def _bearer(user: User) -> dict:
    return {"Authorization": f"Bearer {create_access_token({'sub': str(user.user_id), 'role': user.role})}"}


def test_http_non_admin_register_admin_is_403(client, delegate):
    body = {"username": "x_admin", "email": "x_admin@test.com", "full_name": "X", "password": "Password123", "role": "ADMIN"}
    response = client.post("/api/v1/auth/register", json=body, headers=_bearer(delegate))
    assert response.status_code == 403
    assert response.json()["detail"] == MSG_ADMIN_ROLE_GRANT_FORBIDDEN


def test_http_non_admin_toggle_admin_is_403(client, delegate, admin):
    response = client.patch(f"/api/v1/auth/users/{admin.user_id}/toggle-status", headers=_bearer(delegate))
    assert response.status_code == 403
    assert response.json()["detail"] == MSG_ADMIN_ACCOUNT_EDIT_FORBIDDEN


def test_http_non_admin_grant_users_manage_is_403(client, delegate, finance):
    body = {"permissions": [{"permission_code": "users.manage", "is_granted": True}]}
    response = client.put(f"/api/v1/auth/users/{finance.user_id}/permissions", json=body, headers=_bearer(delegate))
    assert response.status_code == 403
    assert response.json()["detail"] == MSG_PERMISSION_GRANT_FORBIDDEN


def test_http_admin_register_admin_is_201(client, admin):
    body = {"username": "y_admin", "email": "y_admin@test.com", "full_name": "Y", "password": "Password123", "role": "ADMIN"}
    response = client.post("/api/v1/auth/register", json=body, headers=_bearer(admin))
    assert response.status_code == 201, response.text
    assert response.json()["role"] == "ADMIN"


def test_http_operator_without_users_manage_is_403(client, operator):
    body = {"username": "z_user", "email": "z@test.com", "full_name": "Z", "password": "Password123"}
    response = client.post("/api/v1/auth/register", json=body, headers=_bearer(operator))
    assert response.status_code == 403


def test_http_deleted_user_token_is_401_even_with_bypass(client, db, admin, operator, monkeypatch):
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", True)
    headers = _bearer(operator)
    db.delete(operator)
    db.commit()
    invalidate_permission_cache()
    response = client.get("/api/v1/auth/me", headers=headers)
    assert response.status_code == 401
    assert response.json()["detail"] == "المستخدم غير موجود أو تم حذفه."


# ─── resolve_user / helpers ──────────────────────────────────────────────────

def test_resolve_user_deleted_user_does_not_fall_through_to_bypass(db, admin, monkeypatch):
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", True)
    token = create_access_token({"sub": "999999", "role": "ADMIN"})
    with pytest.raises(HTTPException) as exc:
        resolve_user(db, authorization=f"Bearer {token}")
    assert exc.value.status_code == 401
    assert exc.value.detail == "المستخدم غير موجود أو تم حذفه."


def test_resolve_user_non_numeric_sub_is_401(db):
    token = create_access_token({"sub": "not-a-number"})
    with pytest.raises(HTTPException) as exc:
        resolve_user(db, authorization=f"Bearer {token}")
    assert exc.value.status_code == 401


def test_resolve_user_missing_header_without_bypass_is_401(db, admin, monkeypatch):
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", False)
    with pytest.raises(HTTPException) as exc:
        resolve_user(db, x_user_role="ADMIN", x_user_name="root_admin")
    assert exc.value.status_code == 401
    assert exc.value.detail == "Missing Authorization header."


def test_dev_bypass_fallback_order(db, admin, operator):
    fallback = auth_permissions._dev_bypass_fallback_user
    assert fallback(db, None, "plain_operator").user_id == operator.user_id
    assert fallback(db, "LOGISTICS_OPERATOR", None).user_id == operator.user_id
    assert fallback(db, None, None).user_id == admin.user_id


def test_is_admin_and_effective_role_helpers(db, admin, operator):
    assert is_admin_user(admin) is True
    assert is_admin_user(operator) is False
    assert is_admin_user(None) is False
    assert effective_role_code(operator) == "LOGISTICS_OPERATOR"
    legacy = User(username="legacy", role="MANAGER", is_active=True)
    assert effective_role_code(legacy) == "MANAGER"
    assert effective_role_code(None) is None


def test_require_admin_rejects_non_admin(operator):
    with pytest.raises(HTTPException) as exc:
        require_admin(current_user=operator)
    assert exc.value.status_code == 403


def test_transient_test_admin_passes_role_and_permission_checks(db):
    """The conftest bypass seam returns an unsaved ADMIN (user_id None); every check must short-circuit on role."""
    transient = User(username="test-admin", role="ADMIN", is_active=True)
    assert require_admin(current_user=transient) is transient
    assert require_manager_or_admin(current_user=transient) is transient
    assert has_user_permission(db, transient, "users.manage") is True
    assert transient.user_id is None


# ─── Replacing the override set must not remove denies the actor could not grant ──

def _deny(db, user: User, code: str, admin: User) -> None:
    perm = db.query(Permission).filter(Permission.permission_code == code).one()
    db.add(UserPermission(user_id=user.user_id, permission_id=perm.permission_id, is_granted=False, granted_by=admin.user_id))
    db.commit()
    invalidate_permission_cache()


def test_non_admin_cannot_wipe_own_deny(db, delegate, admin):
    denied = sorted(get_user_effective_permissions(db, delegate.user_id) - {"users.manage"})[0]
    _deny(db, delegate, denied, admin)
    assert denied not in get_user_effective_permissions(db, delegate.user_id)
    # Keep users.manage explicitly; drop the deny by omitting it.
    payload = UserPermissionsUpdatePayload(permissions=[{"permission_code": "users.manage", "is_granted": True}])
    with pytest.raises(HTTPException) as exc:
        AuthService(db).update_user_permissions(delegate.user_id, payload, actor=delegate)
    _assert_403(exc, MSG_PERMISSION_GRANT_FORBIDDEN)
    invalidate_permission_cache()
    assert denied not in get_user_effective_permissions(db, delegate.user_id)


def test_non_admin_empty_payload_on_self_is_403(db, delegate, admin):
    denied = sorted(get_user_effective_permissions(db, delegate.user_id) - {"users.manage"})[0]
    _deny(db, delegate, denied, admin)
    with pytest.raises(HTTPException) as exc:
        AuthService(db).update_user_permissions(
            delegate.user_id, UserPermissionsUpdatePayload(permissions=[]), actor=delegate
        )
    _assert_403(exc, MSG_PERMISSION_GRANT_FORBIDDEN)


def _deny_codes_delegate_lacks(db, delegate: User, target: User, admin: User) -> set:
    lacking = get_user_effective_permissions(db, target.user_id) - get_user_effective_permissions(db, delegate.user_id)
    for code in sorted(lacking):
        _deny(db, target, code, admin)
    return lacking


def test_non_admin_cannot_wipe_deny_on_other_user_for_code_they_lack(db, delegate, operator, admin):
    """import_files.create comes from LOGISTICS_OPERATOR and is not held by GENERAL_MANAGER."""
    lacking = _deny_codes_delegate_lacks(db, delegate, operator, admin)
    assert "import_files.create" in lacking
    # With the denies in place the operator is no longer wider than the delegate: only the diff rule applies.
    with pytest.raises(HTTPException) as exc:
        AuthService(db).update_user_permissions(
            operator.user_id, UserPermissionsUpdatePayload(permissions=[]), actor=delegate
        )
    _assert_403(exc, MSG_PERMISSION_GRANT_FORBIDDEN)
    invalidate_permission_cache()
    assert "import_files.create" not in get_user_effective_permissions(db, operator.user_id)


def test_http_non_admin_wipe_deny_is_403(client, db, delegate, operator, admin):
    _deny_codes_delegate_lacks(db, delegate, operator, admin)
    response = client.put(
        f"/api/v1/auth/users/{operator.user_id}/permissions", json={"permissions": []}, headers=_bearer(delegate)
    )
    assert response.status_code == 403
    assert response.json()["detail"] == MSG_PERMISSION_GRANT_FORBIDDEN


def test_non_admin_can_wipe_deny_for_code_they_hold(db, delegate, finance, admin):
    held_by_finance = sorted(get_user_effective_permissions(db, finance.user_id))[0]
    _deny(db, finance, held_by_finance, admin)
    result = AuthService(db).update_user_permissions(
        finance.user_id, UserPermissionsUpdatePayload(permissions=[]), actor=delegate
    )
    assert held_by_finance in result["effective_permissions"]


def test_admin_can_wipe_any_deny(db, admin, operator):
    _deny(db, operator, "import_files.create", admin)
    result = AuthService(db).update_user_permissions(
        operator.user_id, UserPermissionsUpdatePayload(permissions=[]), actor=admin
    )
    assert "import_files.create" in result["effective_permissions"]
    assert result["custom_revocations"] == []


# ─── Users with wider permissions than the actor ──────────────────────────────

def test_non_admin_cannot_reset_password_of_wider_user(db, admin):
    narrow_delegate = _make_user(db, "narrow_hr", "FINANCE_OFFICER", extra_grants=("users.manage",))
    manager = _make_user(db, "the_gm", "GENERAL_MANAGER")
    old_hash = manager.hashed_password
    with pytest.raises(HTTPException) as exc:
        AuthService(db).update_user(manager.user_id, UserUpdate(password="Hijacked123"), actor=narrow_delegate)
    _assert_403(exc, MSG_WIDER_TARGET_FORBIDDEN)
    db.refresh(manager)
    assert manager.hashed_password == old_hash


@pytest.mark.parametrize("field", ["email", "role"])
def test_non_admin_cannot_change_email_or_role_of_wider_user(db, field):
    narrow_delegate = _make_user(db, "narrow_hr2", "FINANCE_OFFICER", extra_grants=("users.manage",))
    manager = _make_user(db, "the_gm2", "GENERAL_MANAGER")
    update = UserUpdate(email="attacker@test.com") if field == "email" else UserUpdate(role="FINANCE_OFFICER")
    with pytest.raises(HTTPException) as exc:
        AuthService(db).update_user(manager.user_id, update, actor=narrow_delegate)
    _assert_403(exc, MSG_WIDER_TARGET_FORBIDDEN)


def test_non_admin_cannot_reactivate_wider_user(db, admin):
    narrow_delegate = _make_user(db, "narrow_hr3", "FINANCE_OFFICER", extra_grants=("users.manage",))
    manager = _make_user(db, "disabled_gm", "GENERAL_MANAGER")
    AuthService(db).toggle_user_status(manager.user_id, actor=admin)
    db.refresh(manager)
    assert manager.is_active is False
    with pytest.raises(HTTPException) as exc:
        AuthService(db).toggle_user_status(manager.user_id, actor=narrow_delegate)
    _assert_403(exc, MSG_WIDER_TARGET_FORBIDDEN)
    db.refresh(manager)
    assert manager.is_active is False


def test_non_admin_cannot_touch_user_with_extra_direct_grant(db, admin):
    """Wider-ness includes direct grants, not only the role."""
    narrow_delegate = _make_user(db, "narrow_hr4", "FINANCE_OFFICER", extra_grants=("users.manage",))
    peer = _make_user(db, "peer_fin", "FINANCE_OFFICER", extra_grants=("import_files.create",))
    with pytest.raises(HTTPException) as exc:
        AuthService(db).update_user(peer.user_id, UserUpdate(password="Hijacked123"), actor=narrow_delegate)
    _assert_403(exc, MSG_WIDER_TARGET_FORBIDDEN)


def test_non_admin_cannot_touch_legacy_manager_role_string(db):
    """A free-text MANAGER role passes require_manager_or_admin, so it counts as wider than a non-manager actor."""
    narrow_delegate = _make_user(db, "narrow_hr5", "FINANCE_OFFICER", extra_grants=("users.manage",))
    legacy = User(
        username="legacy_mgr", email="legacy_mgr@test.com", full_name="Legacy",
        hashed_password=hash_password("Password123"), role="MANAGER", is_active=True,
    )
    db.add(legacy)
    db.commit()
    with pytest.raises(HTTPException) as exc:
        AuthService(db).toggle_user_status(legacy.user_id, actor=narrow_delegate)
    _assert_403(exc, MSG_WIDER_TARGET_FORBIDDEN)


def test_non_admin_can_manage_equal_and_narrower_users(db, delegate, finance):
    peer_gm = _make_user(db, "peer_gm", "GENERAL_MANAGER")
    service = AuthService(db)
    assert service.update_user(peer_gm.user_id, UserUpdate(password="Rotated123"), actor=delegate).user_id == peer_gm.user_id
    assert service.toggle_user_status(peer_gm.user_id, actor=delegate).is_active is False
    assert service.toggle_user_status(peer_gm.user_id, actor=delegate).is_active is True
    assert service.update_user(finance.user_id, UserUpdate(email="fin2@test.com"), actor=delegate).email == "fin2@test.com"


def test_non_admin_rename_only_is_not_blocked_by_wider_rule(db):
    narrow_delegate = _make_user(db, "narrow_hr6", "FINANCE_OFFICER", extra_grants=("users.manage",))
    manager = _make_user(db, "the_gm3", "GENERAL_MANAGER")
    updated = AuthService(db).update_user(manager.user_id, UserUpdate(full_name="Display Name"), actor=narrow_delegate)
    assert updated.full_name == "Display Name"


def test_http_non_admin_password_reset_of_wider_user_is_403(client, db):
    narrow_delegate = _make_user(db, "narrow_http", "FINANCE_OFFICER", extra_grants=("users.manage",))
    manager = _make_user(db, "gm_http", "GENERAL_MANAGER")
    response = client.patch(
        f"/api/v1/auth/users/{manager.user_id}", json={"password": "Hijacked123"}, headers=_bearer(narrow_delegate)
    )
    assert response.status_code == 403
    assert response.json()["detail"] == MSG_WIDER_TARGET_FORBIDDEN


def test_role_string_is_stripped(db, admin):
    created = AuthService(db).register_user(_new_user_payload("spaced_role", role="  finance_officer "), actor=admin)
    assert created.role == "FINANCE_OFFICER"
    assert created.role_id == _role(db, "FINANCE_OFFICER").role_id


def test_non_admin_cannot_repermission_wider_user(db):
    """PUT /users/{id}/permissions applies the same wider-target rule as PATCH /users/{id}."""
    narrow_delegate = _make_user(db, "narrow_perm", "FINANCE_OFFICER", extra_grants=("users.manage",))
    manager = _make_user(db, "gm_perm", "GENERAL_MANAGER")
    payload = UserPermissionsUpdatePayload(role_id=_role(db, "FINANCE_OFFICER").role_id, permissions=[])
    with pytest.raises(HTTPException) as exc:
        AuthService(db).update_user_permissions(manager.user_id, payload, actor=narrow_delegate)
    _assert_403(exc, MSG_WIDER_TARGET_FORBIDDEN)
    db.refresh(manager)
    assert manager.role == "GENERAL_MANAGER"


def test_http_non_admin_repermission_wider_user_is_403(client, db):
    narrow_delegate = _make_user(db, "narrow_perm_http", "FINANCE_OFFICER", extra_grants=("users.manage",))
    manager = _make_user(db, "gm_perm_http", "GENERAL_MANAGER")
    body = {"role_id": _role(db, "FINANCE_OFFICER").role_id, "permissions": []}
    response = client.put(f"/api/v1/auth/users/{manager.user_id}/permissions", json=body, headers=_bearer(narrow_delegate))
    assert response.status_code == 403
    assert response.json()["detail"] == MSG_WIDER_TARGET_FORBIDDEN


def test_effective_role_code_prefers_admin(db):
    """Legacy role="ADMIN" with a non-admin assigned role passes require_admin, so it must also read as ADMIN."""
    mixed = _make_user(db, "mixed_admin", "FINANCE_OFFICER")
    mixed.role = "ADMIN"
    db.commit()
    assert require_admin(current_user=mixed) is mixed
    assert effective_role_code(mixed) == "ADMIN"
