import os
from typing import Any, Dict, Iterable, List, Optional, Set, Tuple
from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session
from database.database import get_db, SessionLocal
from modules.users.model import User, Role, Permission, UserPermission, RolePermission
from modules.auth.security import decode_access_token
from settings import ALLOW_DEV_AUTH_BYPASS
from utils.cache_manager import memory_cache


import time
import threading
from sqlalchemy import event

_PERMISSION_CACHE: Dict[Tuple[int, int], tuple] = {}
_CACHE_LOCK = threading.Lock()
_CACHE_TTL_SECONDS = 60.0


def invalidate_permission_cache(user_id: Optional[int] = None) -> None:
    """
    Invalidates the permission cache for a specific user or all users.
    Called when roles, permissions, or user active statuses are updated.
    """
    with _CACHE_LOCK:
        if user_id is not None:
            keys_to_del = [k for k in _PERMISSION_CACHE if k[1] == user_id]
            for k in keys_to_del:
                _PERMISSION_CACHE.pop(k, None)
            memory_cache.delete(f"auth_user:{user_id}")
        else:
            _PERMISSION_CACHE.clear()
            memory_cache.clear_prefix("auth_user:")


@event.listens_for(UserPermission, "after_insert")
@event.listens_for(UserPermission, "after_update")
@event.listens_for(UserPermission, "after_delete")
def _on_user_permission_change(mapper, connection, target):
    invalidate_permission_cache()


@event.listens_for(RolePermission, "after_insert")
@event.listens_for(RolePermission, "after_update")
@event.listens_for(RolePermission, "after_delete")
def _on_role_permission_change(mapper, connection, target):
    invalidate_permission_cache()


@event.listens_for(User, "after_update")
@event.listens_for(User, "after_insert")
@event.listens_for(User, "after_delete")
def _on_user_change(mapper, connection, target):
    invalidate_permission_cache()


def merge_role_and_overrides(role: Optional[Role], overrides: Iterable[Tuple[str, bool]]) -> Set[str]:
    """Non-ADMIN effective codes: the active role's permissions, then each (code, is_granted) override in order
    (True adds the code, False removes it). Shared by get_user_effective_permissions and AuthService."""
    effective: Set[str] = set()
    if role is not None and role.is_active:
        effective = {rp.permission.permission_code for rp in role.role_permissions if rp.permission}
    for code, is_granted in overrides:
        if is_granted:
            effective.add(code)
        else:
            effective.discard(code)
    return effective


def get_user_effective_permissions(db: Session, user_id: int) -> Set[str]:
    """
    Computes effective permissions for a given user according to the Hybrid RBAC algorithm:
    1. If user is inactive -> Empty set (Deny all).
    2. If user is ADMIN -> All permissions in catalog + "*".
    3. Inherit base permissions from assigned Role (if role is active).
    4. Apply custom UserPermission overrides:
       - is_granted == True: Add to effective set (grant exception).
       - is_granted == False: Remove from effective set (explicit revocation).
    
    Optimized with a 60-second in-memory TTL cache to eliminate redundant DB query waterfalls
    during high concurrent user loads.
    """
    bind_id = id(db.get_bind())
    cache_key = (bind_id, user_id)
    now = time.time()
    with _CACHE_LOCK:
        cached = _PERMISSION_CACHE.get(cache_key)
        if cached is not None:
            cached_time, cached_perms = cached
            if now - cached_time < _CACHE_TTL_SECONDS:
                return set(cached_perms)

    user = db.query(User).filter(User.user_id == user_id).first()
    if not user or not user.is_active:
        return set()

    # Admin superuser check
    is_admin = (user.role == "ADMIN")
    if user.assigned_role and user.assigned_role.role_code == "ADMIN":
        is_admin = True

    if is_admin:
        all_perms = {p.permission_code for p in db.query(Permission).all()}
        all_perms.add("*")
        with _CACHE_LOCK:
            _PERMISSION_CACHE[cache_key] = (now, set(all_perms))
        return all_perms

    user_perms = db.query(UserPermission).filter(UserPermission.user_id == user_id).all()
    effective = merge_role_and_overrides(
        user.assigned_role,
        ((up.permission.permission_code, bool(up.is_granted)) for up in user_perms if up.permission),
    )

    with _CACHE_LOCK:
        _PERMISSION_CACHE[cache_key] = (now, set(effective))

    return effective


def get_user_permissions_breakdown(db: Session, user_id: int) -> Dict[str, Any]:
    """Returns detailed role permissions, custom grants, custom revocations, and effective permissions."""
    user = db.query(User).filter(User.user_id == user_id).first()
    if not user:
        return {
            "role_code": None,
            "role_permissions": [],
            "custom_grants": [],
            "custom_revocations": [],
            "effective_permissions": [],
        }

    role_code = user.assigned_role.role_code if user.assigned_role else user.role
    role_perms: List[str] = []
    if user.assigned_role and user.assigned_role.is_active:
        role_perms = [rp.permission.permission_code for rp in user.assigned_role.role_permissions if rp.permission]

    user_perms = db.query(UserPermission).filter(UserPermission.user_id == user_id).all()
    custom_grants: List[str] = []
    custom_revocations: List[str] = []

    for up in user_perms:
        if up.permission:
            if up.is_granted:
                custom_grants.append(up.permission.permission_code)
            else:
                custom_revocations.append(up.permission.permission_code)

    effective = get_user_effective_permissions(db, user_id)

    return {
        "role_code": role_code,
        "role_permissions": sorted(role_perms),
        "custom_grants": sorted(custom_grants),
        "custom_revocations": sorted(custom_revocations),
        "effective_permissions": sorted(list(effective)),
    }


def has_user_permission(db: Session, user: User, permission_code: str) -> bool:
    """Check if the user possesses the specified permission."""
    if not user or not user.is_active:
        return False

    if user.role == "ADMIN":
        return True

    if user.assigned_role and user.assigned_role.role_code == "ADMIN":
        return True

    effective = get_user_effective_permissions(db, user.user_id)
    return ("*" in effective) or (permission_code in effective)


def is_admin_user(user: Optional[User]) -> bool:
    """True when the user is an ADMIN, either by legacy role string or by assigned RBAC role."""
    if user is None:
        return False
    if (user.role or "").upper() == "ADMIN":
        return True
    assigned_role = getattr(user, "assigned_role", None)
    return getattr(assigned_role, "role_code", None) == "ADMIN"


def effective_role_code(user: Optional[User]) -> Optional[str]:
    """
    Role code for role-based checks: "ADMIN" for any admin (legacy role string or assigned role, same rule as
    require_admin), otherwise the assigned RBAC role code, falling back to the legacy `role` column.
    """
    if user is None:
        return None
    if is_admin_user(user):
        return "ADMIN"
    assigned_role = getattr(user, "assigned_role", None)
    role_code = getattr(assigned_role, "role_code", None)
    return role_code or user.role


def _dev_bypass_fallback_user(
    db: Session,
    x_user_role: Optional[str] = None,
    x_user_name: Optional[str] = None,
) -> Optional[User]:
    """
    Desktop/dev-only user resolution used when no Authorization header is sent.
    Only called by resolve_user when ALLOW_DEV_AUTH_BYPASS is true.
    Order: X-User-Name, X-User-Role, first active ADMIN, first active user.
    """
    if x_user_name:
        user = db.query(User).filter(User.username == x_user_name, User.is_active == True).first()
        if user:
            return user

    if x_user_role:
        user = db.query(User).filter(User.role == x_user_role.upper(), User.is_active == True).first()
        if user:
            return user

    admin = db.query(User).filter(User.is_active == True, User.role == "ADMIN").first()
    if admin:
        return admin

    return db.query(User).filter(User.is_active == True).first()


def resolve_user(
    db: Session,
    authorization: Optional[str] = None,
    x_user_role: Optional[str] = None,
    x_user_name: Optional[str] = None,
) -> User:
    """
    Resolves the authenticated user:
    1. If an Authorization header is sent it must be a valid Bearer token of an existing, active user
       (401 otherwise; 403 for a deactivated account). It never falls through to the dev bypass.
    2. Without an Authorization header: 401, unless ALLOW_DEV_AUTH_BYPASS is true, in which case
       _dev_bypass_fallback_user resolves a user from X-User-Name / X-User-Role or the first ADMIN / user.
    """
    if authorization:
        parts = authorization.split()
        if len(parts) != 2 or parts[0].lower() != "bearer":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid Authorization header format. Expected 'Bearer <token>'."
            )
        payload = decode_access_token(parts[1])
        if not payload:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired access token."
            )
        try:
            user_id = int(payload.get("sub", 0))
        except (TypeError, ValueError):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired access token."
            )
        cache_key = f"auth_user:{user_id}"
        cached = memory_cache.get(cache_key)
        if cached is not None and not cached.get("is_active", True):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="حساب المستخدم معطّل. تواصل مع مدير النظام."
            )
        user = db.get(User, user_id)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="المستخدم غير موجود أو تم حذفه."
            )
        if not user.is_active:
            memory_cache.set(cache_key, {"is_active": False}, ttl_seconds=30)
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="حساب المستخدم معطّل. تواصل مع مدير النظام."
            )
        memory_cache.set(cache_key, {"is_active": True, "role": user.role, "username": user.username}, ttl_seconds=30)
        return user

    if ALLOW_DEV_AUTH_BYPASS:
        user = _dev_bypass_fallback_user(db, x_user_role, x_user_name)
        if user is not None:
            return user

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Missing Authorization header.",
    )


def authenticate_ws_token(token: Optional[str]) -> Optional[User]:
    """
    Validates a raw JWT for a WebSocket handshake. Returns the active user or None.
    Uses a short-lived session and never applies the dev auth bypass.
    """
    if not token or not isinstance(token, str) or not token.strip():
        return None
    db = SessionLocal()
    try:
        return resolve_user(db, authorization=f"Bearer {token.strip()}")
    except HTTPException:
        return None
    finally:
        db.close()


def require_permission(permission_code: str):
    """
    FastAPI dependency factory enforcing granular RBAC permissions.
    Supports JWT Bearer authorization and desktop client headers.
    """
    def dependency(
        authorization: Optional[str] = Header(None),
        x_user_role: Optional[str] = Header(None),
        x_user_name: Optional[str] = Header(None),
        db: Session = Depends(get_db)
    ) -> User:
        user = resolve_user(
            db,
            authorization=authorization,
            x_user_role=x_user_role,
            x_user_name=x_user_name
        )

        if not has_user_permission(db, user, permission_code):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied. Permission '{permission_code}' required."
            )

        return user

    return dependency
