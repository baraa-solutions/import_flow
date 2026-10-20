"""
modules/common/validators.py
Shared domain validation utilities for ImportFlow ERP.
Reusable FK existence checks to avoid duplication across modules.
"""
from typing import Any, FrozenSet, Mapping, Optional, Type
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


CLOSED_FILE_STATUSES: FrozenSet[str] = frozenset({"Closed", "Archived"})


def ensure_file_open(db_or_imp: Any, import_file_id: Optional[Any] = None) -> None:
    """Validate that the import file is not Closed or Archived.

    Args:
        db_or_imp: An ImportFile instance, mapping, or SQLAlchemy Session (when import_file_id is passed).
        import_file_id: Optional import_file_id when passing db as first argument.

    Raises:
        CodedHTTPException (409): with code IMPORT_FILE_CLOSED when the file status is
        'Closed' or 'Archived'.
    """
    if db_or_imp is None:
        return

    if import_file_id is not None:
        from modules.import_files.model import ImportFile

        imp = db_or_imp.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
        if imp is None:
            return
    else:
        imp = db_or_imp

    if isinstance(imp, Mapping):
        status_val = str(imp.get("status") or "").strip()
        code = str(imp.get("import_file_code") or imp.get("code") or "")
        if not code:
            raw_id = imp.get("import_file_id") or imp.get("id")
            if raw_id:
                code = f"#{raw_id}"
    else:
        status_val = str(getattr(imp, "status", None) or "").strip()
        code = str(getattr(imp, "import_file_code", None) or getattr(imp, "code", None) or "")
        if not code:
            raw_id = getattr(imp, "import_file_id", getattr(imp, "id", None))
            if raw_id:
                code = f"#{raw_id}"

    if (
        status_val in CLOSED_FILE_STATUSES
        or status_val.capitalize() in CLOSED_FILE_STATUSES
        or status_val.upper() in {"CLOSED", "ARCHIVED"}
    ):
        from modules.common.errors import CodedHTTPException

        msg_ar = (
            f"ملف الشحنة {code} مغلق نهائياً ولا يمكن تعديل بياناته. يلزم إعادة فتحه أولاً."
            if code
            else "ملف الشحنة مغلق نهائياً ولا يمكن تعديل بياناته. يلزم إعادة فتحه أولاً."
        )
        raise CodedHTTPException(
            status_code=status.HTTP_409_CONFLICT,
            code="IMPORT_FILE_CLOSED",
            message_ar=msg_ar,
            import_file_code=code,
        )


def require_currency_code(
    db: Session,
    code: Optional[str],
    label_ar: str = "العملة",
) -> Optional[str]:
    """Validate that code is an active currency code in the currencies master table.

    Normalizes by stripping whitespace and uppercasing. If code is None or empty, returns None.
    Raises CodedHTTPException (400) with code CURRENCY_CODE_UNKNOWN if the currency is not
    found or is inactive.
    """
    if code is None:
        return None
    clean = str(code).strip().upper()
    if not clean:
        return None

    from modules.currencies.model import Currency
    currency = (
        db.query(Currency)
        .filter(Currency.currency_code == clean, Currency.is_active.is_(True))
        .first()
    )
    if not currency:
        from modules.common.errors import CodedHTTPException

        raise CodedHTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            code="CURRENCY_CODE_UNKNOWN",
            message_ar=f"رمز {label_ar} غير معروف أو غير نشط: {clean}.",
            currency_code=clean,
        )
    return clean

