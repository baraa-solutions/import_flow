"""
Unified audit-column stamping (GP-004): set_created_info / set_updated_info.

Services receive the acting username from the router (the user resolved by require_permission) and stamp
entities through these helpers instead of writing created_by / updated_by by hand in every module.
"""
from typing import Any, Optional

SYSTEM_ACTOR = "SYSTEM"


def actor_name(user: Any) -> str:
    """Username of the acting user, or SYSTEM_ACTOR for background / system calls."""
    username = getattr(user, "username", None) if user is not None else None
    return username or SYSTEM_ACTOR


def resolve_actor(actor: Optional[str]) -> str:
    """Normalises an optional actor string (None / blank -> SYSTEM_ACTOR)."""
    return (actor or "").strip() or SYSTEM_ACTOR


def set_created_info(entity: Any, actor: Optional[str]) -> Any:
    """Stamps created_by and updated_by on a new entity (only the columns the entity defines)."""
    name = resolve_actor(actor)
    if hasattr(entity, "created_by"):
        entity.created_by = name
    if hasattr(entity, "updated_by"):
        entity.updated_by = name
    return entity


def set_updated_info(entity: Any, actor: Optional[str]) -> Any:
    """Stamps updated_by on an existing entity (updated_at is maintained by the column onupdate)."""
    if hasattr(entity, "updated_by"):
        entity.updated_by = resolve_actor(actor)
    return entity
