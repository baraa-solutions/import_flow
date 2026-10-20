"""Unit tests for TokenRevocationManager and session revocation (BEX-T08)."""
import time
from datetime import datetime, timezone, timedelta
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

import main
from database.database import get_db, SessionLocal
from modules.users.model import User, Role
from modules.auth.security import (
    TokenRevocationManager,
    token_revocation_manager,
    create_access_token,
    decode_access_token,
    hash_password,
)
from modules.auth.service import AuthService
from modules.auth.revoked_token_model import RevokedToken


@pytest.fixture
def db():
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture
def client():
    return TestClient(main.app)



def _get_or_create_user(db: Session, username: str) -> User:
    user = db.query(User).filter(User.username == username).first()
    if not user:
        role = db.query(Role).filter(Role.role_code == "OPERATOR").first()
        user = User(
            username=username,
            email=f"{username}@test.local",
            hashed_password=hash_password("Pass1234"),
            full_name=f"Tester {username}",
            role="OPERATOR",
            role_id=role.role_id if role else None,
            is_active=True,
            token_version=0,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    return user


def test_revocation_loaded_on_restart(db: Session):
    """Simulate server restart with a fresh TokenRevocationManager: active revoked tokens are reloaded."""
    test_user = _get_or_create_user(db, "revocation_restart_user")
    service = AuthService(db)
    token = service.generate_user_token(test_user)

    # Revoke token directly to DB with future expiration
    mgr = token_revocation_manager
    mgr.revoke(token, test_user.user_id, datetime.now(timezone.utc) + timedelta(days=1), db)
    assert mgr.is_revoked(token) is True

    # Simulate fresh instance after restart
    fresh_mgr = TokenRevocationManager()
    assert fresh_mgr._initialized is False
    assert len(fresh_mgr._revoked_hashes) == 0

    # First is_revoked lookup triggers ensure_loaded from DB
    assert fresh_mgr.is_revoked(token) is True
    assert fresh_mgr._initialized is True


def test_refresh_revokes_old_token(client: TestClient, db: Session):
    """Calling /auth/refresh returns a new token and revokes the old token."""
    test_user = _get_or_create_user(db, "refresh_revoke_user")
    service = AuthService(db)
    t1 = service.generate_user_token(test_user)

    # Refresh using t1
    resp = client.post("/api/v1/auth/refresh", headers={"Authorization": f"Bearer {t1}"})
    assert resp.status_code == 200, resp.text
    t2 = resp.json()["access_token"]
    assert t2 != t1

    # Old token t1 is now revoked
    me_resp1 = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {t1}"})
    assert me_resp1.status_code == 401

    # New token t2 is valid
    me_resp2 = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {t2}"})
    assert me_resp2.status_code == 200
    assert me_resp2.json()["username"] == test_user.username


def test_logout_revokes_token(client: TestClient, db: Session):
    """Calling /auth/logout immediately revokes token on subsequent requests."""
    test_user = _get_or_create_user(db, "logout_revoke_user")
    service = AuthService(db)
    token = service.generate_user_token(test_user)

    # Authenticated before logout
    resp_before = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert resp_before.status_code == 200

    # Logout
    logout_resp = client.post("/api/v1/auth/logout", headers={"Authorization": f"Bearer {token}"})
    assert logout_resp.status_code == 200

    # Rejected after logout
    resp_after = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert resp_after.status_code == 401

