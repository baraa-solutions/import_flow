from typing import Iterable, List, Optional, Dict, Any, Set
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
import settings
from utils.db_safety import is_frozen_build
from modules.users.model import User, Role, Permission, RolePermission, UserPermission
from modules.audit_logs.service import AuditLogService
from .schemas import UserCreate, UserUpdate, UserPermissionsUpdatePayload
from .security import hash_password, verify_password, create_access_token, validate_password_strength
from .rate_limiter import login_limiter
from .permissions import (
    get_user_permissions_breakdown,
    get_user_effective_permissions,
    invalidate_permission_cache,
    is_admin_user,
    merge_role_and_overrides,
)

ADMIN_ROLE_CODE = "ADMIN"
USERS_MANAGE_PERMISSION = "users.manage"
MSG_ADMIN_ROLE_GRANT_FORBIDDEN = "لا يمكن منح دور مدير النظام إلا بواسطة مدير النظام."
MSG_ADMIN_ACCOUNT_EDIT_FORBIDDEN = "لا يمكن تعديل حساب مدير النظام إلا بواسطة مدير النظام."
MSG_PERMISSION_GRANT_FORBIDDEN = "لا يمكنك منح صلاحية لا تملكها."
MSG_WIDER_TARGET_FORBIDDEN = "لا يمكنك تعديل مستخدم يملك صلاحيات أوسع من صلاحياتك."
MANAGER_ROLE_CODES = {"MANAGER", "GENERAL_MANAGER"}
INITIAL_ADMIN_USERNAME = "admin"
MSG_CURRENT_PASSWORD_WRONG = "كلمة المرور الحالية غير صحيحة."
MSG_NEW_PASSWORD_SAME = "كلمة المرور الجديدة يجب أن تختلف عن كلمة المرور الحالية."
MSG_PASSWORD_CHANGE_NO_ACCOUNT = "لا يمكن تغيير كلمة المرور لهذا الحساب."


def change_password_limiter_key(user_id: int) -> str:
    """login_limiter key for POST /auth/me/change-password (never collides with the IP keys of /login)."""
    return f"change-password:user:{user_id}"


class AuthService:
    def __init__(self, db: Session):
        self.db = db

    # ─── Privilege-escalation guards (non-ADMIN actors) ──────────────────────

    @staticmethod
    def _forbid(detail: str) -> None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=detail)

    def _guard_admin_role_grant(self, actor: User, role_code: Optional[str]) -> None:
        """Only an ADMIN may give the ADMIN role (by role_id or legacy role string)."""
        if (role_code or "").strip().upper() == ADMIN_ROLE_CODE and not is_admin_user(actor):
            self._forbid(MSG_ADMIN_ROLE_GRANT_FORBIDDEN)

    def _guard_admin_target(self, actor: User, target: User) -> None:
        """Only an ADMIN may modify, re-password, toggle or re-permission an existing ADMIN account."""
        if is_admin_user(target) and not is_admin_user(actor):
            self._forbid(MSG_ADMIN_ACCOUNT_EDIT_FORBIDDEN)

    def _guard_permission_grant(self, actor: User, granted_codes: Iterable[str]) -> None:
        """A non-ADMIN may not grant users.manage nor any permission code they do not hold."""
        if is_admin_user(actor):
            return
        codes = {c for c in granted_codes if c}
        if not codes:
            return
        if USERS_MANAGE_PERMISSION in codes:
            self._forbid(MSG_PERMISSION_GRANT_FORBIDDEN)
        held = get_user_effective_permissions(self.db, actor.user_id) if actor.user_id is not None else set()
        if "*" in held:
            return
        if codes - held:
            self._forbid(MSG_PERMISSION_GRANT_FORBIDDEN)

    @staticmethod
    def _compute_effective_codes(role_obj: Optional[Role], overrides: Dict[str, bool]) -> Set[str]:
        """Same merge as get_user_effective_permissions for a non-ADMIN user, ignoring is_active."""
        return merge_role_and_overrides(role_obj, overrides.items())

    def _stored_overrides(self, user_id: int) -> Dict[str, bool]:
        rows = self.db.query(UserPermission).filter(UserPermission.user_id == user_id).all()
        return {up.permission.permission_code: bool(up.is_granted) for up in rows if up.permission}

    def _actor_effective_codes(self, actor: User) -> Set[str]:
        return get_user_effective_permissions(self.db, actor.user_id) if actor.user_id is not None else set()

    def _guard_wider_target(self, actor: User, target: User) -> None:
        """
        A non-ADMIN may only re-password, re-role, re-email or (de)activate users whose permissions are a
        subset of their own. Evaluated on the stored role + overrides, so an inactive target counts too.
        """
        if is_admin_user(actor):
            return
        self._guard_admin_target(actor, target)
        actor_codes = self._actor_effective_codes(actor)
        if "*" in actor_codes:
            return
        target_codes = self._compute_effective_codes(target.assigned_role, self._stored_overrides(target.user_id))
        # Legacy role strings grant manager-level access through require_manager_or_admin.
        target_is_manager = (target.role or "").strip().upper() in MANAGER_ROLE_CODES
        actor_is_manager = (actor.role or "").strip().upper() in MANAGER_ROLE_CODES or getattr(
            actor.assigned_role, "role_code", None
        ) in MANAGER_ROLE_CODES
        if (target_codes - actor_codes) or (target_is_manager and not actor_is_manager):
            self._forbid(MSG_WIDER_TARGET_FORBIDDEN)

    def _guard_role_assignment(self, actor: User, role_obj: Optional[Role], role_code: Optional[str]) -> None:
        """Assigning a role grants its permission set: apply the ADMIN-role and permission-subset rules."""
        self._guard_admin_role_grant(actor, role_obj.role_code if role_obj else role_code)
        if role_obj is not None:
            role_codes = [rp.permission.permission_code for rp in role_obj.role_permissions if rp.permission]
            self._guard_permission_grant(actor, role_codes)

    # ─── User management ─────────────────────────────────────────────────────

    def register_user(self, user_data: UserCreate, actor: User) -> User:
        # Check existing username or email
        existing_username = self.db.query(User).filter(User.username == user_data.username).first()
        if existing_username:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"اسم المستخدم '{user_data.username}' مستخدم بالفعل."
            )

        existing_email = self.db.query(User).filter(User.email == user_data.email).first()
        if existing_email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"البريد الإلكتروني '{user_data.email}' مسجل بالفعل."
            )

        is_valid, err_msg = validate_password_strength(user_data.password)
        if not is_valid:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=err_msg
            )

        # Resolve role_id and role_code
        role_obj: Optional[Role] = None
        if user_data.role_id:
            role_obj = self.db.query(Role).filter(Role.role_id == user_data.role_id).first()
            if not role_obj:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"معرف الدور '{user_data.role_id}' غير موجود."
                )
        elif user_data.role:
            role_input = user_data.role.strip().upper()
            # Map legacy names if needed
            if role_input == "MANAGER":
                role_input = "GENERAL_MANAGER"
            elif role_input == "OPERATOR":
                role_input = "LOGISTICS_OPERATOR"

            role_obj = self.db.query(Role).filter(Role.role_code == role_input).first()

        role_code = role_obj.role_code if role_obj else (user_data.role.strip().upper() if user_data.role else "LOGISTICS_OPERATOR")
        role_id = role_obj.role_id if role_obj else None
        self._guard_role_assignment(actor, role_obj, role_code)

        user = User(
            username=user_data.username,
            email=user_data.email,
            full_name=user_data.full_name,
            hashed_password=hash_password(user_data.password),
            role=role_code,
            role_id=role_id,
        )
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)

        AuditLogService(self.db).log_activity(
            entity_type="User",
            entity_id=user.user_id,
            entity_code=user.username,
            action="CREATE",
            performed_by=actor.username if actor else "SYSTEM",
            new_data={"username": user.username, "role": user.role, "role_id": user.role_id}
        )

        return user

    def update_user(self, user_id: int, update_data: UserUpdate, actor: User) -> User:
        user = self.db.query(User).filter(User.user_id == user_id).first()
        if not user:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="المستخدم غير موجود.")
        self._guard_admin_target(actor, user)
        touches_credentials_or_access = any(
            value is not None
            for value in (update_data.password, update_data.role, update_data.role_id, update_data.email)
        )
        if touches_credentials_or_access:
            self._guard_wider_target(actor, user)

        old_data = {"role": user.role, "role_id": user.role_id, "full_name": user.full_name, "email": user.email}

        if update_data.full_name is not None:
            user.full_name = update_data.full_name

        if update_data.email is not None:
            existing = self.db.query(User).filter(
                User.email == update_data.email,
                User.user_id != user_id
            ).first()
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"البريد الإلكتروني '{update_data.email}' مستخدم من مستخدم آخر."
                )
            user.email = update_data.email

        role_changed = False
        if update_data.role_id is not None:
            target_role = self.db.query(Role).filter(Role.role_id == update_data.role_id).first()
            if not target_role:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"معرف الدور '{update_data.role_id}' غير موجود."
                )
            self._guard_role_assignment(actor, target_role, target_role.role_code)
            if user.role_id != target_role.role_id or user.role != target_role.role_code:
                role_changed = True
            user.role_id = target_role.role_id
            user.role = target_role.role_code
        elif update_data.role is not None:
            role_input = update_data.role.strip().upper()
            if role_input == "MANAGER":
                role_input = "GENERAL_MANAGER"
            elif role_input == "OPERATOR":
                role_input = "LOGISTICS_OPERATOR"

            target_role = self.db.query(Role).filter(Role.role_code == role_input).first()
            if not target_role:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="AUTH_ROLE_UNKNOWN: Role does not exist."
                )
            self._guard_role_assignment(actor, target_role, role_input)
            if user.role_id != target_role.role_id or user.role != target_role.role_code:
                role_changed = True
            user.role_id = target_role.role_id
            user.role = target_role.role_code

        password_changed = False
        if update_data.password is not None:
            is_valid, err_msg = validate_password_strength(update_data.password)
            if not is_valid:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=err_msg
                )
            user.hashed_password = hash_password(update_data.password)
            password_changed = True

        if role_changed or password_changed:
            user.token_version = (user.token_version or 0) + 1

        self.db.commit()
        self.db.refresh(user)


        if update_data.password is not None:
            self._forget_admin_initial_password(user, update_data.password)

        AuditLogService(self.db).log_activity(
            entity_type="User",
            entity_id=user.user_id,
            entity_code=user.username,
            action="UPDATE",
            performed_by=actor.username if actor else "SYSTEM",
            old_data=old_data,
            new_data={"role": user.role, "role_id": user.role_id, "full_name": user.full_name, "email": user.email}
        )
        invalidate_permission_cache(user.user_id)

        return user

    def change_own_password(self, user: User, current_password: str, new_password: str) -> User:
        """Self-service password change (POST /auth/me/change-password). Verifies the current password,
        rejects an unchanged or weak new one, then stores the new hash and clears must_change_password."""
        db_user = self.db.get(User, user.user_id) if user is not None and user.user_id is not None else None
        if db_user is None:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=MSG_PASSWORD_CHANGE_NO_ACCOUNT)
        # Wrong current passwords are throttled per user with the login limiter (429 after 5 in 60 s).
        limiter_key = change_password_limiter_key(db_user.user_id)
        login_limiter.check_key(limiter_key)
        if not current_password or not verify_password(current_password, db_user.hashed_password, username=db_user.username):
            login_limiter.record_failure_key(limiter_key)
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=MSG_CURRENT_PASSWORD_WRONG)
        login_limiter.record_success_key(limiter_key)
        if new_password == current_password:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=MSG_NEW_PASSWORD_SAME)
        is_valid, err_msg = validate_password_strength(new_password)
        if not is_valid:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=err_msg)

        was_forced = bool(db_user.must_change_password)
        db_user.hashed_password = hash_password(new_password)
        db_user.must_change_password = False
        db_user.token_version = (db_user.token_version or 0) + 1
        self.db.commit()
        self.db.refresh(db_user)

        self._forget_admin_initial_password(db_user, new_password)
        AuditLogService(self.db).log_activity(
            entity_type="User",
            entity_id=db_user.user_id,
            entity_code=db_user.username,
            action="UPDATE",
            old_data={"must_change_password": was_forced},
            new_data={"password_changed": True, "must_change_password": False},
            performed_by=db_user.username,
            changes_summary="Password changed by the user (self-service).",
        )
        invalidate_permission_cache(db_user.user_id)
        return db_user

    @staticmethod
    def _forget_admin_initial_password(user: User, new_password: str) -> bool:
        """Production build only: once the seeded admin has a new password, drop the plaintext
        ADMIN_INITIAL_PASSWORD line from the .env next to backend.exe right away. The developer's .env is never touched."""
        if not is_frozen_build() or user.username != INITIAL_ADMIN_USERNAME:
            return False
        env_password = settings.env_admin_initial_password(settings.ENV_PATH)
        if env_password is None or new_password == env_password:
            return False  # unreadable line (fail closed), or the admin re-set the .env password itself
        return settings.remove_env_key(settings.ENV_PATH, "ADMIN_INITIAL_PASSWORD")

    def toggle_user_status(self, user_id: int, actor: User) -> User:
        user = self.db.query(User).filter(User.user_id == user_id).first()
        if not user:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="المستخدم غير موجود.")

        if actor.user_id is not None and user.user_id == actor.user_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="لا يمكن تعطيل حسابك الخاص."
            )

        self._guard_wider_target(actor, user)

        old_status = user.is_active
        user.is_active = not user.is_active
        user.token_version = (user.token_version or 0) + 1
        self.db.commit()
        self.db.refresh(user)

        AuditLogService(self.db).log_activity(
            entity_type="User",
            entity_id=user.user_id,
            entity_code=user.username,
            action="UPDATE",
            performed_by=actor.username if actor else "SYSTEM",
            old_data={"is_active": old_status},
            new_data={"is_active": user.is_active}
        )
        invalidate_permission_cache(user.user_id)

        return user

    def authenticate_user(self, username_or_email: str, password: str) -> Optional[User]:
        user = self.db.query(User).filter(
            (User.username == username_or_email) | (User.email == username_or_email)
        ).first()

        # S-003: guard against unknown username — avoid AttributeError and timing leak
        if not user:
            return None

        # R-001: check active status before any password work or DB writes
        if not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="حساب المستخدم معطّل. تواصل مع مدير النظام.",
            )

        if not verify_password(password, user.hashed_password, username=user.username):
            return None


        # Automatically upgrade legacy SHA-256 hashes to PBKDF2
        if not user.hashed_password.startswith("pbkdf2_sha256$"):
            user.hashed_password = hash_password(password)
            self.db.commit()

        return user

    def generate_user_token(self, user: User) -> str:
        payload = {
            "sub": str(user.user_id),
            "username": user.username,
            "role": user.role,
            "tv": user.token_version or 0,
        }
        return create_access_token(payload)

    def get_all_users(self) -> List[User]:
        return self.db.query(User).order_by(User.user_id).all()

    def get_user_by_id(self, user_id: int) -> Optional[User]:
        return self.db.query(User).filter(User.user_id == user_id).first()

    # ─── RBAC Management Methods ──────────────────────────────────────────────

    def get_all_permissions(self) -> List[Permission]:
        return self.db.query(Permission).order_by(Permission.module_name, Permission.permission_code).all()

    def get_permissions_grouped(self) -> List[Dict[str, Any]]:
        perms = self.get_all_permissions()
        module_titles_ar = {
            "import_files": "ملفات الاستيراد",
            "lifecycle_board": "لوحة دورة حياة الشحنات",
            "purchase_orders": "أوامر الشراء",
            "freight_booking": "حجوزات الشحن",
            "cargo_shipping": "حركة وتتبع الشحن",
            "customs_clearance": "التخليص الجمركي",
            "customs_tariff": "التعريفة والبنود الجمركية",
            "cargox_nafeza": "كارجو إكس ومنظومة نافذة",
            "import_documentation": "مستندات الشحن والمطابقة",
            "financial_approval": "الاعتمادات وطلبات الصرف",
            "financial_settlement": "التسويات وتكلفة الوصول",
            "warehouse_receiving": "استلام المستودعات",
            "demurrage_detention": "الأرضيات وغرامات التأخير",
            "quotations": "عروض أسعار الشحن والتخليص",
            "master_data": "البيانات المرجعية الأساسية",
            "users_and_security": "المستخدمين وإدارة الصلاحيات",
            "audit_logs": "سجل العمليات والرقابة",
            "reports_and_analytics": "التقارير الإدارية والتحليلات",
        }
        groups_dict: Dict[str, List[Permission]] = {}
        for p in perms:
            groups_dict.setdefault(p.module_name, []).append(p)

        result = []
        for mod, items in groups_dict.items():
            result.append({
                "module_name": mod,
                "module_name_ar": module_titles_ar.get(mod, mod),
                "permissions": items,
            })
        return result

    def get_all_roles(self) -> List[Dict[str, Any]]:
        roles = self.db.query(Role).order_by(Role.role_id).all()
        result = []
        for r in roles:
            perm_codes = [rp.permission.permission_code for rp in r.role_permissions if rp.permission]
            result.append({
                "role_id": r.role_id,
                "role_code": r.role_code,
                "name_en": r.name_en,
                "name_ar": r.name_ar,
                "description": r.description,
                "is_system_role": r.is_system_role,
                "is_active": r.is_active,
                "permissions": sorted(perm_codes),
            })
        return result

    def get_user_permissions(self, user_id: int) -> Dict[str, Any]:
        user = self.db.query(User).filter(User.user_id == user_id).first()
        if not user:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="المستخدم غير موجود.")

        breakdown = get_user_permissions_breakdown(self.db, user_id)
        return {
            "user_id": user.user_id,
            "username": user.username,
            "role": user.role,
            "role_id": user.role_id,
            "role_code": breakdown["role_code"],
            "effective_permissions": breakdown["effective_permissions"],
            "custom_grants": breakdown["custom_grants"],
            "custom_revocations": breakdown["custom_revocations"],
        }

    def update_user_permissions(
        self, user_id: int, payload: UserPermissionsUpdatePayload, actor: User
    ) -> Dict[str, Any]:
        user = self.db.query(User).filter(User.user_id == user_id).first()
        if not user:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="المستخدم غير موجود.")
        self._guard_admin_target(actor, user)
        self._guard_wider_target(actor, user)

        old_role_id = user.role_id
        old_role_code = user.role

        target_role: Optional[Role] = None
        if payload.role_id is not None:
            target_role = self.db.query(Role).filter(Role.role_id == payload.role_id).first()
            if not target_role:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="الدور المحدد غير موجود.")
            self._guard_role_assignment(actor, target_role, target_role.role_code)

        all_perms_map = {p.permission_code: p.permission_id for p in self.db.query(Permission).all()}

        # The payload replaces the whole override set: omitted overrides (including denies) are deleted.
        # For a non-ADMIN, everything the user would gain (explicit grants and removed denies) must be
        # held by the actor.
        if not is_admin_user(actor):
            before = self._compute_effective_codes(user.assigned_role, self._stored_overrides(user.user_id))
            after_overrides = {
                item.permission_code: bool(item.is_granted)
                for item in payload.permissions
                if item.permission_code in all_perms_map
            }
            after = self._compute_effective_codes(target_role or user.assigned_role, after_overrides)
            self._guard_permission_grant(actor, after - before)

        # 1. Update role if specified
        if target_role is not None:
            if user.role_id != target_role.role_id or user.role != target_role.role_code:
                user.token_version = (user.token_version or 0) + 1
            user.role_id = target_role.role_id
            user.role = target_role.role_code

        # 2. Update / replace UserPermission overrides
        existing_ups = {up.permission_id: up for up in self.db.query(UserPermission).filter(UserPermission.user_id == user_id).all()}
        new_requested_pids = set()

        for item in payload.permissions:
            pid = all_perms_map.get(item.permission_code)
            if not pid:
                continue
            new_requested_pids.add(pid)
            if pid in existing_ups:
                up = existing_ups[pid]
                up.is_granted = item.is_granted
                up.granted_by = actor.user_id
            else:
                up = UserPermission(
                    user_id=user.user_id,
                    permission_id=pid,
                    is_granted=item.is_granted,
                    granted_by=actor.user_id,
                )
                self.db.add(up)

        for pid, up in existing_ups.items():
            if pid not in new_requested_pids:
                self.db.delete(up)

        self.db.commit()
        self.db.refresh(user)

        # Audit log
        AuditLogService(self.db).log_activity(
            entity_type="UserPermissions",
            entity_id=user.user_id,
            entity_code=user.username,
            action="UPDATE",
            performed_by=actor.username if actor else "SYSTEM",
            old_data={"role_id": old_role_id, "role": old_role_code},
            new_data={
                "role_id": user.role_id,
                "role": user.role,
                "overrides_count": len(payload.permissions),
            },
        )
        invalidate_permission_cache(user.user_id)

        return self.get_user_permissions(user_id)
