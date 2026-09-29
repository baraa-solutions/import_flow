from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, EmailStr, field_validator


class UserBase(BaseModel):
    username: str
    email: EmailStr
    full_name: str
    role: str = "OPERATOR"  # ADMIN, MANAGER, OPERATOR (kept for legacy/token compatibility)
    role_id: Optional[int] = None


class UserCreate(UserBase):
    password: str


class UserUpdate(BaseModel):
    """Partial update schema — all fields optional for PATCH."""
    full_name: Optional[str] = None
    email: Optional[EmailStr] = None
    role: Optional[str] = None
    role_id: Optional[int] = None
    password: Optional[str] = None  # if provided, will be re-hashed


class UserResponse(UserBase):
    # Read models echo the stored value: strict EmailStr stays on UserCreate/UserUpdate only,
    # so a legacy or reserved-domain address (x@host.local) can never make login/me/lists 500.
    email: str
    user_id: int
    is_active: bool
    must_change_password: bool = False
    created_at: datetime
    updated_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)

    @field_validator("must_change_password", mode="before")
    @classmethod
    def _null_flag_is_false(cls, value):
        """A row whose column was added without a default reads NULL: that user was never forced."""
        return False if value is None else value


class LoginRequest(BaseModel):
    username_or_email: str
    password: str


class ChangeOwnPasswordRequest(BaseModel):
    """POST /api/v1/auth/me/change-password."""
    current_password: str
    new_password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


# ─── RBAC Schemas ─────────────────────────────────────────────────────────────

class PermissionResponse(BaseModel):
    permission_id: int
    permission_code: str
    module_name: str
    action: str
    name_en: str
    name_ar: str
    description: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class PermissionModuleGroup(BaseModel):
    module_name: str
    module_name_ar: str
    permissions: List[PermissionResponse]


class RoleResponse(BaseModel):
    role_id: int
    role_code: str
    name_en: str
    name_ar: str
    description: Optional[str] = None
    is_system_role: bool
    is_active: bool
    permissions: List[str] = []

    model_config = ConfigDict(from_attributes=True)


class UserPermissionItem(BaseModel):
    permission_code: str
    is_granted: bool = True


class UserPermissionsUpdatePayload(BaseModel):
    role_id: Optional[int] = None
    permissions: List[UserPermissionItem] = []


class UserEffectivePermissionsResponse(BaseModel):
    user_id: int
    username: str
    role: str
    role_id: Optional[int] = None
    role_code: Optional[str] = None
    effective_permissions: List[str] = []
    custom_grants: List[str] = []
    custom_revocations: List[str] = []
