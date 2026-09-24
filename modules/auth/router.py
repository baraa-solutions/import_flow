from typing import List
from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from sqlalchemy.orm import Session
from database.database import get_db
from modules.users.model import User
from .rate_limiter import login_limiter
from .schemas import (
    LoginRequest,
    TokenResponse,
    UserCreate,
    UserResponse,
    UserUpdate,
    PermissionModuleGroup,
    RoleResponse,
    UserEffectivePermissionsResponse,
    UserPermissionsUpdatePayload,
)
from datetime import datetime, timezone, timedelta
from .security import decode_access_token, token_revocation_manager
from .service import AuthService
from .permissions import (
    require_permission,
    get_user_effective_permissions,
    get_user_permissions_breakdown,
    resolve_user,
    is_admin_user,
)

router = APIRouter(prefix="/api/v1/auth", tags=["Authentication & User Access Control (RBAC)"])


# ─── Dependency: Current User ─────────────────────────────────────────────────

def get_current_user(
    authorization: str = Header(None),
    x_user_role: str = Header(None),
    x_user_name: str = Header(None),
    db: Session = Depends(get_db)
) -> User:
    return resolve_user(
        db,
        authorization=authorization,
        x_user_role=x_user_role,
        x_user_name=x_user_name
    )


def require_admin(current_user: User = Depends(get_current_user)) -> User:
    """ADMIN role required."""
    if not is_admin_user(current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. Admin role required."
        )
    return current_user


def require_manager_or_admin(current_user: User = Depends(get_current_user)) -> User:
    """MANAGER or ADMIN role required."""
    allowed = ["ADMIN", "MANAGER", "GENERAL_MANAGER"]
    user_role = current_user.role
    assigned_role_code = getattr(current_user.assigned_role, "role_code", None)
    if user_role not in allowed and assigned_role_code not in allowed:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. Manager or Admin role required."
        )
    return current_user


# ─── Auth Endpoints ───────────────────────────────────────────────────────────

@router.post("/login", response_model=TokenResponse)
def login(request: Request, credentials: LoginRequest, db: Session = Depends(get_db)):
    login_limiter.check_rate_limit(request)
    service = AuthService(db)
    user = service.authenticate_user(credentials.username_or_email, credentials.password)
    if not user:
        login_limiter.record_failure(request)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="اسم المستخدم أو كلمة المرور غير صحيحة."
        )
    login_limiter.record_success(request)
    token = service.generate_user_token(user)
    return TokenResponse(access_token=token, user=user)


@router.post("/refresh", response_model=TokenResponse)
def refresh_token(
    authorization: str = Header(None),
    db: Session = Depends(get_db),
):
    """
    Refreshes an access token without requiring password re-entry.
    Accepts valid unexpired tokens, as well as recently expired tokens (within the 14-day refresh grace period),
    provided the cryptographic HMAC signature is valid and the token has not been revoked via logout.
    """
    token_revocation_manager.init_from_db(db)
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization header."
        )

    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Authorization header format. Expected 'Bearer <token>'."
        )

    token = parts[1]
    payload = decode_access_token(token, check_revocation=True, ignore_expiration=True)
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or revoked token."
        )

    user_id = int(payload.get("sub", 0))
    user = db.get(User, user_id)
    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User account is inactive or not found."
        )

    service = AuthService(db)
    new_token = service.generate_user_token(user)
    return TokenResponse(access_token=new_token, user=user)


@router.get("/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user


@router.post("/logout")
def logout(
    authorization: str = Header(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Terminates the user's active session and revokes the JWT token server-side.
    Subsequent requests with this token will be immediately rejected with HTTP 401.
    """
    token_revocation_manager.init_from_db(db)
    token = None
    if authorization and authorization.startswith("Bearer "):
        token = authorization[7:].strip()

    if token:
        payload = decode_access_token(token, check_revocation=False)
        exp_ts = payload.get("exp") if payload else None
        expires_at = datetime.fromtimestamp(exp_ts, tz=timezone.utc) if exp_ts else datetime.now(timezone.utc) + timedelta(days=1)
        token_revocation_manager.revoke(token, current_user.user_id, expires_at, db)

    return {
        "status": "success",
        "message": "تم تسجيل الخروج بنجاح وإلغاء صلاحية الجلسة.",
        "username": current_user.username,
    }


@router.get("/me/permissions", response_model=UserEffectivePermissionsResponse)
def get_my_permissions(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Retrieve current logged-in user's effective permissions and roles for client-side UI adjustments."""
    service = AuthService(db)
    return service.get_user_permissions(current_user.user_id)


# ─── User Management Endpoints ───────────────────────────────────────────────

@router.get("/users", response_model=List[UserResponse])
def get_all_users(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("users.view"))
):
    """Get all users — Requires 'users.view' permission or Admin."""
    service = AuthService(db)
    return service.get_all_users()


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register_user(
    user_data: UserCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("users.manage"))
):
    """Register a new user — Requires 'users.manage' permission or Admin."""
    service = AuthService(db)
    return service.register_user(user_data, actor=current_user)


@router.patch("/users/{user_id}", response_model=UserResponse)
def update_user(
    user_id: int,
    update_data: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("users.manage"))
):
    """Update user data (full_name, email, role, password) — Requires 'users.manage' permission or Admin."""
    service = AuthService(db)
    return service.update_user(user_id, update_data, actor=current_user)


@router.patch("/users/{user_id}/toggle-status", response_model=UserResponse)
def toggle_user_status(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("users.manage"))
):
    """Activate or deactivate a user — Requires 'users.manage' permission or Admin. Cannot deactivate yourself."""
    service = AuthService(db)
    return service.toggle_user_status(user_id, actor=current_user)


# ─── RBAC Permissions & Roles Endpoints ───────────────────────────────────────

@router.get("/permissions", response_model=List[PermissionModuleGroup])
def get_all_permissions(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("users.view"))
):
    """List all available system permissions grouped by functional module."""
    service = AuthService(db)
    return service.get_permissions_grouped()


@router.get("/roles", response_model=List[RoleResponse])
def get_all_roles(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("users.view"))
):
    """List all predefined and custom roles with their assigned permission codes."""
    service = AuthService(db)
    return service.get_all_roles()


@router.get("/users/{user_id}/permissions", response_model=UserEffectivePermissionsResponse)
def get_user_permissions(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("users.view"))
):
    """Get assigned role, effective permissions, and custom overrides for a specific user."""
    service = AuthService(db)
    return service.get_user_permissions(user_id)


@router.put("/users/{user_id}/permissions", response_model=UserEffectivePermissionsResponse)
def update_user_permissions(
    user_id: int,
    payload: UserPermissionsUpdatePayload,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("users.manage"))
):
    """Update user's assigned role and granular permission overrides with audit trail."""
    service = AuthService(db)
    return service.update_user_permissions(user_id, payload, actor=current_user)
