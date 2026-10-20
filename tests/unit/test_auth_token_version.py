"""Unit tests for token versioning and session invalidation (BEX-T08)."""
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

import main
from database.database import get_db, SessionLocal
from modules.users.model import User, Role
from modules.auth.security import hash_password
from modules.auth.service import AuthService


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



@pytest.fixture
def admin_user(db: Session):
    admin = db.query(User).filter(User.username == "admin_token_test").first()
    if not admin:
        admin_role = db.query(Role).filter(Role.role_code == "ADMIN").first()
        admin = User(
            username="admin_token_test",
            email="admin_token@test.local",
            hashed_password=hash_password("AdminPass123"),
            full_name="Admin Token Tester",
            role="ADMIN",
            role_id=admin_role.role_id if admin_role else None,
            is_active=True,
            token_version=0,
        )
        db.add(admin)
        db.commit()
        db.refresh(admin)
    return admin


@pytest.fixture
def normal_user(db: Session):
    user = db.query(User).filter(User.username == "tv_normal_user").first()
    if not user:
        op_role = db.query(Role).filter(Role.role_code == "LOGISTICS_OPERATOR").first() or db.query(Role).filter(Role.role_code == "OPERATOR").first()
        user = User(
            username="tv_normal_user",
            email="tv_normal@test.local",
            hashed_password=hash_password("UserPass123"),
            full_name="TV Normal User",
            role=op_role.role_code if op_role else "LOGISTICS_OPERATOR",
            role_id=op_role.role_id if op_role else None,
            is_active=True,
            token_version=0,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    return user


def test_password_change_bumps_tv_and_returns_new_token(client: TestClient, db: Session, normal_user):
    """Self-service password change bumps token_version, returns access_token, and invalidates old token."""
    service = AuthService(db)
    old_token = service.generate_user_token(normal_user)
    initial_tv = normal_user.token_version or 0

    # Old token works
    resp1 = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {old_token}"})
    assert resp1.status_code == 200

    # Change password
    change_resp = client.post(
        "/api/v1/auth/me/change-password",
        headers={"Authorization": f"Bearer {old_token}"},
        json={"current_password": "UserPass123", "new_password": "NewUserPass456"},
    )
    assert change_resp.status_code == 200, change_resp.text
    data = change_resp.json()
    assert "access_token" in data
    new_token = data["access_token"]
    assert new_token != old_token

    # Verify db token_version was incremented
    db.refresh(normal_user)
    assert normal_user.token_version == initial_tv + 1

    # Old token is now rejected with 401
    old_resp = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {old_token}"})
    assert old_resp.status_code == 401

    # New token works
    new_resp = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {new_token}"})
    assert new_resp.status_code == 200

    # Cleanup password back
    normal_user.hashed_password = hash_password("UserPass123")
    db.commit()


def test_admin_update_password_invalidates_user_token(client: TestClient, db: Session, admin_user, normal_user):
    """Admin updating user's password bumps token_version and invalidates user's old token."""
    service = AuthService(db)
    admin_token = service.generate_user_token(admin_user)
    user_token = service.generate_user_token(normal_user)
    prev_tv = normal_user.token_version or 0

    # User's token works
    assert client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {user_token}"}).status_code == 200

    # Admin updates user's password
    update_resp = client.patch(
        f"/api/v1/auth/users/{normal_user.user_id}",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"password": "ResetByAdmin123"},
    )
    assert update_resp.status_code == 200

    db.refresh(normal_user)
    assert normal_user.token_version == prev_tv + 1

    # User's old token gets 401
    assert client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {user_token}"}).status_code == 401

    # Cleanup password
    normal_user.hashed_password = hash_password("UserPass123")
    db.commit()


def test_toggle_user_status_bumps_token_version(client: TestClient, db: Session, admin_user, normal_user):
    """Deactivating and reactivating a user increments token_version so past tokens are dead."""
    service = AuthService(db)
    admin_token = service.generate_user_token(admin_user)
    user_token = service.generate_user_token(normal_user)
    prev_tv = normal_user.token_version or 0

    # Toggle status to inactive
    t1 = client.patch(
        f"/api/v1/auth/users/{normal_user.user_id}/toggle-status",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert t1.status_code == 200
    db.refresh(normal_user)
    assert normal_user.is_active is False
    assert normal_user.token_version == prev_tv + 1

    # Toggle status back to active
    t2 = client.patch(
        f"/api/v1/auth/users/{normal_user.user_id}/toggle-status",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert t2.status_code == 200
    db.refresh(normal_user)
    assert normal_user.is_active is True
    assert normal_user.token_version == prev_tv + 2

    # Old token with old tv is rejected even though user is active again
    assert client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {user_token}"}).status_code == 401


def test_unknown_role_rejected_with_400(client: TestClient, db: Session, admin_user, normal_user):
    """Updating user with an unknown role string returns 400 AUTH_ROLE_UNKNOWN."""
    service = AuthService(db)
    admin_token = service.generate_user_token(admin_user)

    resp = client.patch(
        f"/api/v1/auth/users/{normal_user.user_id}",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"role": "SUPER_NONEXISTENT_ROLE_99"},
    )
    assert resp.status_code == 400
    assert "AUTH_ROLE_UNKNOWN" in str(resp.json())
