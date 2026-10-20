import unittest
from fastapi import FastAPI, Depends, status
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base, get_db
from modules.users.model import User, Role, Permission, RolePermission, UserPermission
from modules.auth.security import hash_password, create_access_token
from modules.auth.service import AuthService
from modules.auth.seed_rbac import seed_rbac
from modules.auth.permissions import (
    get_user_effective_permissions,
    get_user_permissions_breakdown,
    has_user_permission,
    require_permission,
)
from modules.auth.router import router as auth_router


class TestRBACPermissionsBackend(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine(
            "sqlite:///:memory:",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        Base.metadata.create_all(self.engine)
        self.SessionLocal = sessionmaker(bind=self.engine)
        self.db = self.SessionLocal()

        # Seed RBAC Catalog and Default Roles
        seed_rbac(self.db)

        # Create Test FastAPI App with Protected Endpoints
        self.app = FastAPI()
        self.app.include_router(auth_router)

        @self.app.get("/test-protected/view")
        def protected_view_route(user: User = Depends(require_permission("import_files.view"))):
            return {"status": "ok", "user": user.username}

        @self.app.get("/test-protected/approve")
        def protected_approve_route(user: User = Depends(require_permission("financial_approval.approve"))):
            return {"status": "approved", "user": user.username}

        @self.app.post("/test-protected/create-file")
        def protected_create_route(user: User = Depends(require_permission("import_files.create"))):
            return {"status": "created", "user": user.username}

        # Override get_db dependency
        def override_get_db():
            db = self.SessionLocal()
            try:
                yield db
            finally:
                db.close()

        self.app.dependency_overrides[get_db] = override_get_db
        self.client = TestClient(self.app)

        # Helper to generate Bearer auth headers
        self.auth_service = AuthService(self.db)

    def tearDown(self):
        self.app.dependency_overrides.clear()
        self.db.close()
        Base.metadata.drop_all(self.engine)

    def _create_token_header(self, user: User) -> dict:
        # BEX-T08: tokens carry the user's current token_version ("tv"); grants and role changes bump it.
        fresh = self.db.get(User, user.user_id)
        if fresh is not None:
            self.db.refresh(fresh)
        tv = (fresh.token_version if fresh is not None else user.token_version) or 0
        token = create_access_token({"sub": str(user.user_id), "username": user.username, "role": user.role, "tv": tv})
        return {"Authorization": f"Bearer {token}"}

    # ─── 1. Deny by Default Tests ─────────────────────────────────────────────

    def test_deny_by_default_unassigned_user(self):
        """Active user without any assigned role or permissions has 0 effective permissions."""
        user = User(
            username="newuser_blank",
            email="blank@test.com",
            full_name="Blank User",
            hashed_password=hash_password("pass123"),
            role="GUEST",
            role_id=None,
            is_active=True,
        )
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)

        effective = get_user_effective_permissions(self.db, user.user_id)
        self.assertEqual(len(effective), 0)
        self.assertFalse(has_user_permission(self.db, user, "import_files.view"))
        self.assertFalse(has_user_permission(self.db, user, "financial_approval.approve"))

    # ─── 2. Role-Based Inheritance Tests ──────────────────────────────────────

    def test_role_based_permissions_logistics_operator(self):
        """Logistics operator inherits operational permissions but lacks financial approval."""
        operator_role = self.db.query(Role).filter(Role.role_code == "LOGISTICS_OPERATOR").first()
        self.assertIsNotNone(operator_role)

        operator = User(
            username="op_user",
            email="op@test.com",
            full_name="Operations User",
            hashed_password=hash_password("pass123"),
            role=operator_role.role_code,
            role_id=operator_role.role_id,
            is_active=True,
        )
        self.db.add(operator)
        self.db.commit()
        self.db.refresh(operator)

        effective = get_user_effective_permissions(self.db, operator.user_id)
        self.assertIn("import_files.view", effective)
        self.assertIn("freight_booking.confirm", effective)
        self.assertNotIn("financial_approval.approve", effective)
        self.assertNotIn("users.manage", effective)

        self.assertTrue(has_user_permission(self.db, operator, "import_files.view"))
        self.assertFalse(has_user_permission(self.db, operator, "financial_approval.approve"))

    # ─── 3. Direct User Permission Grant Exception ────────────────────────────

    def test_direct_user_permission_grant_exception(self):
        """Direct UserPermission grant provides access to permission outside the role."""
        operator_role = self.db.query(Role).filter(Role.role_code == "LOGISTICS_OPERATOR").first()
        operator = User(
            username="op_promoted",
            email="promoted@test.com",
            full_name="Promoted Operator",
            hashed_password=hash_password("pass123"),
            role=operator_role.role_code,
            role_id=operator_role.role_id,
            is_active=True,
        )
        self.db.add(operator)
        self.db.commit()
        self.db.refresh(operator)

        # Before grant: No financial approval permission
        self.assertFalse(has_user_permission(self.db, operator, "financial_approval.approve"))

        # Add direct user grant
        perm_approval = self.db.query(Permission).filter(Permission.permission_code == "financial_approval.approve").first()
        self.assertIsNotNone(perm_approval)

        user_grant = UserPermission(
            user_id=operator.user_id,
            permission_id=perm_approval.permission_id,
            is_granted=True,
        )
        self.db.add(user_grant)
        self.db.commit()

        # After grant: Permission is now effective
        effective = get_user_effective_permissions(self.db, operator.user_id)
        self.assertIn("financial_approval.approve", effective)
        self.assertTrue(has_user_permission(self.db, operator, "financial_approval.approve"))

    # ─── 4. Direct User Permission Explicit Revocation ────────────────────────

    def test_direct_user_permission_explicit_revocation(self):
        """Direct UserPermission revocation (is_granted=False) overrides role-inherited permission."""
        operator_role = self.db.query(Role).filter(Role.role_code == "LOGISTICS_OPERATOR").first()
        operator = User(
            username="op_restricted",
            email="restricted@test.com",
            full_name="Restricted Operator",
            hashed_password=hash_password("pass123"),
            role=operator_role.role_code,
            role_id=operator_role.role_id,
            is_active=True,
        )
        self.db.add(operator)
        self.db.commit()
        self.db.refresh(operator)

        # Initially has import_files.create through role
        self.assertTrue(has_user_permission(self.db, operator, "import_files.create"))

        # Explicitly revoke import_files.create
        perm_create = self.db.query(Permission).filter(Permission.permission_code == "import_files.create").first()
        user_revoke = UserPermission(
            user_id=operator.user_id,
            permission_id=perm_create.permission_id,
            is_granted=False,  # Explicit Revocation
        )
        self.db.add(user_revoke)
        self.db.commit()

        # After revocation: Permission is removed from effective set
        effective = get_user_effective_permissions(self.db, operator.user_id)
        self.assertNotIn("import_files.create", effective)
        self.assertFalse(has_user_permission(self.db, operator, "import_files.create"))

    # ─── 5. Admin Superuser Bypass ────────────────────────────────────────────

    def test_admin_superuser_bypass(self):
        """Admin has unrestricted access to all permissions and bypasses explicit checks."""
        admin_role = self.db.query(Role).filter(Role.role_code == "ADMIN").first()
        admin = User(
            username="superadmin",
            email="superadmin@test.com",
            full_name="Super Admin",
            hashed_password=hash_password("pass123"),
            role="ADMIN",
            role_id=admin_role.role_id if admin_role else None,
            is_active=True,
        )
        self.db.add(admin)
        self.db.commit()
        self.db.refresh(admin)

        self.assertTrue(has_user_permission(self.db, admin, "import_files.view"))
        self.assertTrue(has_user_permission(self.db, admin, "financial_approval.approve"))
        self.assertTrue(has_user_permission(self.db, admin, "nonexistent.arbitrary.permission"))

    # ─── 6. Inactive User Blockage ────────────────────────────────────────────

    def test_inactive_user_denied_all(self):
        """Inactive user has 0 effective permissions, even if role or direct grants exist."""
        admin = User(
            username="disabled_admin",
            email="disabled@test.com",
            full_name="Disabled Admin",
            hashed_password=hash_password("pass123"),
            role="ADMIN",
            is_active=False,  # Deactivated
        )
        self.db.add(admin)
        self.db.commit()
        self.db.refresh(admin)

        effective = get_user_effective_permissions(self.db, admin.user_id)
        self.assertEqual(len(effective), 0)
        self.assertFalse(has_user_permission(self.db, admin, "import_files.view"))

    # ─── 7. Endpoint HTTP Enforcement & 403 / 401 Rejections ──────────────────

    def test_endpoint_rejection_missing_token_401(self):
        """Direct API call with missing token returns 401 Unauthorized (dev auth bypass disabled)."""
        from unittest.mock import patch
        with patch("modules.auth.permissions.ALLOW_DEV_AUTH_BYPASS", False):
            response = self.client.get("/test-protected/view")
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
        self.assertIn("Missing Authorization header", response.json()["detail"])

    def test_endpoint_rejection_invalid_token_401(self):
        """Direct API call with malformed/invalid token returns 401 Unauthorized."""
        headers = {"Authorization": "Bearer invalid_garbage_token"}
        response = self.client.get("/test-protected/view", headers=headers)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_endpoint_rejection_lacking_permission_403(self):
        """User possessing valid token but lacking required permission receives 403 Forbidden."""
        operator_role = self.db.query(Role).filter(Role.role_code == "LOGISTICS_OPERATOR").first()
        operator = User(
            username="op_no_finance",
            email="op_no_fin@test.com",
            full_name="Operator No Finance",
            hashed_password=hash_password("pass123"),
            role=operator_role.role_code,
            role_id=operator_role.role_id,
            is_active=True,
        )
        self.db.add(operator)
        self.db.commit()
        self.db.refresh(operator)

        headers = self._create_token_header(operator)

        # Allowed endpoint (import_files.view) -> 200
        res_ok = self.client.get("/test-protected/view", headers=headers)
        self.assertEqual(res_ok.status_code, status.HTTP_200_OK)

        # Disallowed endpoint (financial_approval.approve) -> 403 Forbidden
        res_forbidden = self.client.get("/test-protected/approve", headers=headers)
        self.assertEqual(res_forbidden.status_code, status.HTTP_403_FORBIDDEN)
        self.assertIn("financial_approval.approve", res_forbidden.json()["detail"])

    def test_endpoint_acceptance_with_direct_grant_200(self):
        """User with direct grant receives 200 OK on previously forbidden endpoint."""
        operator_role = self.db.query(Role).filter(Role.role_code == "LOGISTICS_OPERATOR").first()
        operator = User(
            username="op_with_grant",
            email="op_grant@test.com",
            full_name="Operator With Grant",
            hashed_password=hash_password("pass123"),
            role=operator_role.role_code,
            role_id=operator_role.role_id,
            is_active=True,
        )
        self.db.add(operator)
        self.db.commit()
        self.db.refresh(operator)

        perm_appr = self.db.query(Permission).filter(Permission.permission_code == "financial_approval.approve").first()
        user_grant = UserPermission(user_id=operator.user_id, permission_id=perm_appr.permission_id, is_granted=True)
        self.db.add(user_grant)
        self.db.commit()

        headers = self._create_token_header(operator)
        res = self.client.get("/test-protected/approve", headers=headers)
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.json()["status"], "approved")

    def test_endpoint_rejection_with_direct_revocation_403(self):
        """User whose role has permission receives 403 Forbidden after explicit revocation."""
        operator_role = self.db.query(Role).filter(Role.role_code == "LOGISTICS_OPERATOR").first()
        operator = User(
            username="op_revoked_api",
            email="op_revoked_api@test.com",
            full_name="Operator Revoked API",
            hashed_password=hash_password("pass123"),
            role=operator_role.role_code,
            role_id=operator_role.role_id,
            is_active=True,
        )
        self.db.add(operator)
        self.db.commit()
        self.db.refresh(operator)

        headers = self._create_token_header(operator)

        # Initially allowed to create file -> 200
        res1 = self.client.post("/test-protected/create-file", headers=headers)
        self.assertEqual(res1.status_code, status.HTTP_200_OK)

        # Apply revocation
        perm_create = self.db.query(Permission).filter(Permission.permission_code == "import_files.create").first()
        user_revoke = UserPermission(user_id=operator.user_id, permission_id=perm_create.permission_id, is_granted=False)
        self.db.add(user_revoke)
        self.db.commit()

        # Now rejected -> 403 Forbidden
        res2 = self.client.post("/test-protected/create-file", headers=headers)
        self.assertEqual(res2.status_code, status.HTTP_403_FORBIDDEN)
        self.assertIn("import_files.create", res2.json()["detail"])

    def test_endpoint_rejection_inactive_user_403(self):
        """Inactive user receives 403 Forbidden on all protected endpoints."""
        inactive_user = User(
            username="inactive_caller",
            email="inactive_caller@test.com",
            full_name="Inactive Caller",
            hashed_password=hash_password("pass123"),
            role="ADMIN",
            is_active=False,
        )
        self.db.add(inactive_user)
        self.db.commit()
        self.db.refresh(inactive_user)

        headers = self._create_token_header(inactive_user)
        res = self.client.get("/test-protected/view", headers=headers)
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    # ─── 8. RBAC Management Endpoints Tests ───────────────────────────────────

    def test_rbac_management_endpoints(self):
        """Test GET /permissions, GET /roles, GET/PUT /users/{id}/permissions, and GET /me/permissions."""
        admin = self.db.query(User).filter(User.username == "admin").first()
        if not admin:
            admin = User(
                username="admin",
                email="admin@importflow.com",
                full_name="Admin",
                hashed_password=hash_password("admin123"),
                role="ADMIN",
                is_active=True,
            )
            self.db.add(admin)
            self.db.commit()
            self.db.refresh(admin)

        admin_headers = self._create_token_header(admin)

        # 1. GET /permissions
        res_perms = self.client.get("/api/v1/auth/permissions", headers=admin_headers)
        self.assertEqual(res_perms.status_code, status.HTTP_200_OK)
        groups = res_perms.json()
        self.assertGreater(len(groups), 10)
        self.assertTrue(any(g["module_name"] == "import_files" for g in groups))

        # 2. GET /roles
        res_roles = self.client.get("/api/v1/auth/roles", headers=admin_headers)
        self.assertEqual(res_roles.status_code, status.HTTP_200_OK)
        roles = res_roles.json()
        self.assertEqual(len(roles), 6)
        role_codes = {r["role_code"] for r in roles}
        self.assertIn("ADMIN", role_codes)
        self.assertIn("GENERAL_MANAGER", role_codes)
        self.assertIn("LOGISTICS_OPERATOR", role_codes)

        # 3. Create target operator to assign permissions
        op = User(
            username="op_target",
            email="op_target@test.com",
            full_name="Target Operator",
            hashed_password=hash_password("pass123"),
            role="OPERATOR",
            is_active=True,
        )
        self.db.add(op)
        self.db.commit()
        self.db.refresh(op)

        # 4. PUT /users/{id}/permissions (Update Role and Grant Exception)
        finance_role = self.db.query(Role).filter(Role.role_code == "FINANCE_OFFICER").first()
        payload = {
            "role_id": finance_role.role_id,
            "permissions": [
                {"permission_code": "freight_booking.confirm", "is_granted": True},
                {"permission_code": "financial_approval.approve", "is_granted": False},
            ],
        }
        res_update = self.client.put(f"/api/v1/auth/users/{op.user_id}/permissions", json=payload, headers=admin_headers)
        self.assertEqual(res_update.status_code, status.HTTP_200_OK)
        data = res_update.json()
        self.assertEqual(data["role_code"], "FINANCE_OFFICER")
        self.assertIn("freight_booking.confirm", data["custom_grants"])
        self.assertIn("financial_approval.approve", data["custom_revocations"])
        self.assertIn("freight_booking.confirm", data["effective_permissions"])
        self.assertNotIn("financial_approval.approve", data["effective_permissions"])

        # 5. GET /users/{id}/permissions
        res_get_user = self.client.get(f"/api/v1/auth/users/{op.user_id}/permissions", headers=admin_headers)
        self.assertEqual(res_get_user.status_code, status.HTTP_200_OK)
        self.assertEqual(res_get_user.json()["user_id"], op.user_id)

        # 6. GET /me/permissions for the target operator
        op_headers = self._create_token_header(op)
        res_me = self.client.get("/api/v1/auth/me/permissions", headers=op_headers)
        self.assertEqual(res_me.status_code, status.HTTP_200_OK)
        self.assertEqual(res_me.json()["username"], "op_target")
        self.assertIn("freight_booking.confirm", res_me.json()["effective_permissions"])
        self.assertNotIn("financial_approval.approve", res_me.json()["effective_permissions"])
