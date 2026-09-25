import unittest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from database.database import Base
from modules.auth.schemas import UserCreate
from modules.auth.security import hash_password, verify_password, create_access_token, decode_access_token
from modules.auth.service import AuthService
from modules.users.model import User


class TestAuthAndRBAC(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        TestingSessionLocal = sessionmaker(bind=self.engine)
        self.db = TestingSessionLocal()
        self.auth_service = AuthService(self.db)
        # Transient ADMIN actor: user management calls require the acting user (privilege-escalation guards).
        self.actor = User(username="actor-admin", role="ADMIN", is_active=True)

    def tearDown(self):
        self.db.close()

    def test_password_hashing_and_verification(self):
        raw = "secret123"
        hashed = hash_password(raw)
        self.assertNotEqual(raw, hashed)
        self.assertTrue(verify_password("secret123", hashed))
        self.assertFalse(verify_password("wrongpass", hashed))

    def test_jwt_token_generation_and_decoding(self):
        token = create_access_token({"sub": "42", "role": "MANAGER"})
        payload = decode_access_token(token)
        self.assertIsNotNone(payload)
        self.assertEqual(payload["sub"], "42")
        self.assertEqual(payload["role"], "MANAGER")

    def test_register_and_authenticate_user(self):
        user_in = UserCreate(
            username="testmanager",
            email="testmanager@importflow.com",
            full_name="Test Manager",
            password="managerpass123",
            role="MANAGER",
        )
        user = self.auth_service.register_user(user_in, actor=self.actor)
        self.assertIsNotNone(user.user_id)
        self.assertEqual(user.role, "MANAGER")

        authenticated = self.auth_service.authenticate_user("testmanager", "managerpass123")
        self.assertIsNotNone(authenticated)
        self.assertEqual(authenticated.user_id, user.user_id)

    def test_duplicate_username_raises_exception(self):
        user_in1 = UserCreate(
            username="dupuser",
            email="dup1@importflow.com",
            full_name="User 1",
            password="Password123",
            role="OPERATOR",
        )
        self.auth_service.register_user(user_in1, actor=self.actor)

        user_in2 = UserCreate(
            username="dupuser",
            email="dup2@importflow.com",
            full_name="User 2",
            password="Password123",
            role="OPERATOR",
        )
        with self.assertRaises(Exception):
            self.auth_service.register_user(user_in2, actor=self.actor)

    def test_weak_password_rejected(self):
        from fastapi import HTTPException
        # Too short (< 8 chars)
        short_user = UserCreate(
            username="shortpass",
            email="short@importflow.com",
            full_name="Short Pass",
            password="Pass1",
            role="OPERATOR",
        )
        with self.assertRaises(HTTPException) as ctx:
            self.auth_service.register_user(short_user, actor=self.actor)
        self.assertEqual(ctx.exception.status_code, 400)

        # No digits
        no_digits_user = UserCreate(
            username="nodigitspass",
            email="nodigits@importflow.com",
            full_name="No Digits",
            password="PasswordOnly",
            role="OPERATOR",
        )
        with self.assertRaises(HTTPException) as ctx:
            self.auth_service.register_user(no_digits_user, actor=self.actor)
        self.assertEqual(ctx.exception.status_code, 400)

    def test_resolve_user_with_token_and_headers_fallback(self):
        from modules.auth.permissions import resolve_user

        # Create admin and operator
        admin_in = UserCreate(
            username="mainadmin",
            email="mainadmin@importflow.com",
            full_name="Main Admin",
            password="AdminPassword123",
            role="ADMIN",
        )
        admin = self.auth_service.register_user(admin_in, actor=self.actor)

        op_in = UserCreate(
            username="op_user",
            email="op@importflow.com",
            full_name="Operator User",
            password="OperatorPassword123",
            role="OPERATOR",
        )
        op = self.auth_service.register_user(op_in, actor=self.actor)

        # 1. Resolve with valid Bearer token
        token = create_access_token({"sub": str(op.user_id), "role": "OPERATOR"})
        resolved = resolve_user(self.db, authorization=f"Bearer {token}")
        self.assertEqual(resolved.user_id, op.user_id)

        # 2. Resolve via x-user-name header
        resolved_name = resolve_user(self.db, x_user_name="op_user")
        self.assertEqual(resolved_name.user_id, op.user_id)

        # 3. Resolve via x-user-role header
        resolved_role = resolve_user(self.db, x_user_role="ADMIN")
        self.assertEqual(resolved_role.user_id, admin.user_id)

        # 4. Fallback to active ADMIN when no auth headers are provided (Desktop app support)
        fallback = resolve_user(self.db)
        self.assertEqual(fallback.role, "ADMIN")

        # 5. A valid token whose user was deleted is rejected; it never falls through to the dev bypass
        from fastapi import HTTPException
        ghost_token = create_access_token({"sub": "999999", "role": "ADMIN"})
        with self.assertRaises(HTTPException) as ctx:
            resolve_user(self.db, authorization=f"Bearer {ghost_token}")
        self.assertEqual(ctx.exception.status_code, 401)

    def test_login_rate_limiter(self):
        from unittest.mock import MagicMock
        from modules.auth.rate_limiter import LoginRateLimiter
        from fastapi import HTTPException

        limiter = LoginRateLimiter(max_attempts=3, window_seconds=60, lockout_seconds=10)
        req = MagicMock()
        req.client.host = "192.168.1.100"
        req.headers = {}

        # 1st and 2nd failed attempts
        limiter.check_rate_limit(req)
        limiter.record_failure(req)
        limiter.check_rate_limit(req)
        limiter.record_failure(req)

        # 3rd failed attempt reaches limit
        limiter.record_failure(req)

        # Next check must raise 429 Too Many Requests
        with self.assertRaises(HTTPException) as ctx:
            limiter.check_rate_limit(req)
        self.assertEqual(ctx.exception.status_code, 429)
        self.assertIn("Retry-After", ctx.exception.headers)

        # Success clears lockouts
        limiter.record_success(req)
        # Should now pass without raising
        limiter.check_rate_limit(req)

    def test_token_refresh_and_grace_period(self):
        from modules.auth.router import refresh_token
        from fastapi import HTTPException

        user_in = UserCreate(
            username="refreshuser",
            email="refresh@importflow.com",
            full_name="Refresh User",
            password="Password123",
            role="OPERATOR",
        )
        user = self.auth_service.register_user(user_in, actor=self.actor)

        # 1. Test unexpired token refresh
        token = self.auth_service.generate_user_token(user)
        res = refresh_token(authorization=f"Bearer {token}", db=self.db)
        self.assertIsNotNone(res.access_token)
        self.assertEqual(res.user.username, "refreshuser")

        # 2. Test expired token within grace period (e.g. expired 100 seconds ago)
        expired_token = create_access_token({"sub": str(user.user_id), "role": user.role}, expires_in_seconds=-100)
        # Standard decode should fail (expired)
        self.assertIsNone(decode_access_token(expired_token))
        # Refresh decode should succeed because it's within grace period
        res_expired = refresh_token(authorization=f"Bearer {expired_token}", db=self.db)
        self.assertIsNotNone(res_expired.access_token)
        # New token is fresh and decodable without ignore_expiration
        new_payload = decode_access_token(res_expired.access_token)
        self.assertIsNotNone(new_payload)
        self.assertEqual(new_payload["sub"], str(user.user_id))

        # 3. Test token expired beyond grace period (e.g. expired 30 days ago)
        way_too_old = create_access_token({"sub": str(user.user_id), "role": user.role}, expires_in_seconds=-(86400 * 30))
        with self.assertRaises(HTTPException) as ctx:
            refresh_token(authorization=f"Bearer {way_too_old}", db=self.db)
        self.assertEqual(ctx.exception.status_code, 401)


if __name__ == "__main__":
    unittest.main()
