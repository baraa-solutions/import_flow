"""
modules/common/validators.py
Shared domain validation utilities for ImportFlow ERP.
Reusable FK existence checks to avoid duplication across modules.
"""
from typing import Any, FrozenSet, Optional, Type
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import inspect as sa_inspect


def validate_foreign_key(
    db: Session,
    model: Type,
    entity_id: Any,
    field_name: str = "id",
    error_label: Optional[str] = None,
) -> object:
    """
    Validate that a foreign key references an existing record.
    Returns the found entity or raises ValueError.
    """
    if entity_id is None:
        return None
    label = error_label or model.__name__
    entity = db.query(model).filter(getattr(model, field_name) == entity_id).first()
    if not entity:
        raise ValueError(f"{label} with id={entity_id} not found.")
    return entity


def validate_active_foreign_key(
    db: Session,
    model: Type,
    entity_id: Any,
    field_name: str = "id",
    error_label: Optional[str] = None,
) -> object:
    """
    Validate that a foreign key references an existing AND active record.
    Returns the found entity or raises ValueError.
    """
    if entity_id is None:
        return None
    label = error_label or model.__name__
    query = db.query(model).filter(getattr(model, field_name) == entity_id)
    # Apply is_active filter only if the model has that column
    mapper = sa_inspect(model)
    col_names = [c.key for c in mapper.columns]
    if "is_active" in col_names:
        query = query.filter(model.is_active.is_(True))
    entity = query.first()
    if not entity:
        raise ValueError(f"{label} with id={entity_id} not found or is inactive.")
    return entity


def require_active(
    db: Session,
    model: Type,
    entity_id: Any,
    label_ar: str,
    field_name: Optional[str] = None,
    status_code: int = status.HTTP_400_BAD_REQUEST,
) -> object:
    """
    ``validate_active_foreign_key`` for request validation: returns the active entity (``None`` when
    ``entity_id`` is None) or raises ``HTTPException(status_code)`` with an Arabic detail
    ("<label_ar> رقم <id> غير موجود أو غير نشط."). ``field_name`` defaults to the model's primary key.
    """
    if entity_id is None:
        return None
    key = field_name or sa_inspect(model).primary_key[0].key
    try:
        return validate_active_foreign_key(db, model, entity_id, field_name=key)
    except ValueError:
        raise HTTPException(status_code=status_code, detail=f"{label_ar} رقم {entity_id} غير موجود أو غير نشط.")


def not_found(label_ar: str, entity_id: Any) -> HTTPException:
    """The shared 404: ``"<label_ar> رقم <id> غير موجود."`` (for services that load through their repository)."""
    return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"{label_ar} رقم {entity_id} غير موجود.")


def get_or_404(db: Session, model: Type, entity_id: Any, label_ar: str, *, active_only: bool = False) -> Any:
    """The row with primary key ``entity_id`` or ``HTTPException(404, "<label_ar> رقم <id> غير موجود.")``.
    ``active_only`` also rejects soft-deleted rows (models with ``is_active``)."""
    query = db.query(model).filter(sa_inspect(model).primary_key[0] == entity_id)
    if active_only and "is_active" in sa_inspect(model).columns:
        query = query.filter(model.is_active.is_(True))
    entity = query.first()
    if entity is None:
        raise not_found(label_ar, entity_id)
    return entity


def not_null_columns(model: Type) -> FrozenSet[str]:
    """Attribute keys of the NOT NULL, non primary-key columns of ``model`` (fields an update may never clear)."""
    return frozenset(c.key for c in sa_inspect(model).columns if not c.nullable and not c.primary_key)
