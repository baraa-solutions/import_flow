"""
Stored users whose email is not a valid EmailStr (reserved domains such as .invalid / .local, legacy rows)
must still be able to log in, refresh and read /me: read models echo the stored value. Create/update inputs
keep strict EmailStr validation (422).
"""

import importlib

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import modules.auth.permissions as auth_permissions
from database.database import Base, get_db
from modules.auth.permissions import invalidate_permission_cache
from modules.auth.rate_limiter import login_limiter
from modules.auth.security import create_access_token, hash_password
from modules.auth.seed_rbac import seed_rbac
from modules.users.model import Role, User

auth_router = importlib.import_module("modules.auth.router")

INVALID_STORED_EMAILS = ["a@b.invalid", "x@host.local"]
PASSWORD = "Password123"


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


@pytest.fixture
def client(session_factory, monkeypatch):
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", False)
    login_limiter._failures.clear()
    login_limiter._lockouts.clear()
    app = FastAPI()
    app.include_router(auth_router.router)

    def _get_db():
        session = session_factory()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_db] = _get_db
    return TestClient(app)


def _make_user(db, username: str, email: str, role_code: str = "ADMIN") -> User:
    role = db.query(Role).filter(Role.role_code == role_code).one()
    user = User(
        username=username,
        email=email,
        full_name=username,
        hashed_password=hash_password(PASSWORD),
        role=role.role_code,
        role_id=role.role_id,
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _bearer(user: User) -> dict:
    token = create_access_token({"sub": str(user.user_id), "role": user.role, "username": user.username})
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.parametrize("email", INVALID_STORED_EMAILS)
def test_login_refresh_me_succeed_for_stored_invalid_email(db, client, email):
    user = _make_user(db, "legacy_user", email)

    login = client.post("/api/v1/auth/login", json={"username_or_email": "legacy_user", "password": PASSWORD})
    assert login.status_code == 200, login.text
    body = login.json()
    assert body["user"]["email"] == email
    assert body["user"]["username"] == "legacy_user"
    headers = {"Authorization": f"Bearer {body['access_token']}"}

    refresh = client.post("/api/v1/auth/refresh", headers=headers)
    assert refresh.status_code == 200, refresh.text
    assert refresh.json()["user"]["email"] == email
    new_headers = {"Authorization": f"Bearer {refresh.json()['access_token']}"}

    # Old token is revoked per BEX-T08
    old_me = client.get("/api/v1/auth/me", headers=headers)
    assert old_me.status_code == 401

    me = client.get("/api/v1/auth/me", headers=new_headers)
    assert me.status_code == 200, me.text
    assert me.json()["email"] == email
    assert me.json()["user_id"] == user.user_id



def test_login_by_stored_invalid_email_itself(db, client):
    _make_user(db, "legacy_mail_login", "x@host.local")
    resp = client.post("/api/v1/auth/login", json={"username_or_email": "x@host.local", "password": PASSWORD})
    assert resp.status_code == 200, resp.text
    assert resp.json()["user"]["email"] == "x@host.local"


def test_user_list_tolerates_stored_invalid_email(db, client):
    admin = _make_user(db, "list_admin", "list_admin@test.com")
    _make_user(db, "legacy_listed", "a@b.invalid", role_code="LOGISTICS_OPERATOR")
    resp = client.get("/api/v1/auth/users", headers=_bearer(admin))
    assert resp.status_code == 200, resp.text
    emails = {u["username"]: u["email"] for u in resp.json()}
    assert emails["legacy_listed"] == "a@b.invalid"


def test_toggle_status_tolerates_stored_invalid_email(db, client):
    admin = _make_user(db, "toggle_admin", "toggle_admin@test.com")
    target = _make_user(db, "legacy_toggled", "x@host.local", role_code="LOGISTICS_OPERATOR")
    resp = client.patch(f"/api/v1/auth/users/{target.user_id}/toggle-status", headers=_bearer(admin))
    assert resp.status_code == 200, resp.text
    assert resp.json()["email"] == "x@host.local"


@pytest.mark.parametrize("email", INVALID_STORED_EMAILS + ["not-an-email"])
def test_register_rejects_invalid_email(db, client, email):
    admin = _make_user(db, "reg_admin", "reg_admin@test.com")
    resp = client.post(
        "/api/v1/auth/register",
        headers=_bearer(admin),
        json={
            "username": "new_user",
            "email": email,
            "full_name": "New User",
            "password": PASSWORD,
            "role": "OPERATOR",
        },
    )
    assert resp.status_code == 422, resp.text
    assert db.query(User).filter(User.username == "new_user").first() is None


@pytest.mark.parametrize("email", INVALID_STORED_EMAILS + ["not-an-email"])
def test_update_rejects_invalid_email(db, client, email):
    admin = _make_user(db, "upd_admin", "upd_admin@test.com")
    target = _make_user(db, "upd_target", "upd_target@test.com", role_code="LOGISTICS_OPERATOR")
    resp = client.patch(f"/api/v1/auth/users/{target.user_id}", headers=_bearer(admin), json={"email": email})
    assert resp.status_code == 422, resp.text
    db.expire_all()
    assert db.get(User, target.user_id).email == "upd_target@test.com"


def test_register_with_valid_email_still_works(db, client):
    admin = _make_user(db, "ok_admin", "ok_admin@test.com")
    resp = client.post(
        "/api/v1/auth/register",
        headers=_bearer(admin),
        json={
            "username": "valid_user",
            "email": "valid_user@example.com",
            "full_name": "Valid User",
            "password": PASSWORD,
            "role": "OPERATOR",
        },
    )
    assert resp.status_code == 201, resp.text
    assert resp.json()["email"] == "valid_user@example.com"


def test_me_without_token_is_401(client):
    assert client.get("/api/v1/auth/me").status_code == 401
