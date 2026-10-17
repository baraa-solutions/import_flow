"""
modules/common/sequence_generator.py
Centralized business reference code generator for ImportFlow ERP.
Avoids race conditions by using max(id)+1 with proper fallback.
"""
from contextlib import contextmanager
from datetime import datetime
from typing import Any, Iterator, Optional, Type

from sqlalchemy import Integer, and_, cast, func
from sqlalchemy.orm import Session, SessionTransaction


@contextmanager
def savepoint(db: Session) -> Iterator[SessionTransaction]:
    """
    ``db.begin_nested()`` that stays inside the caller's transaction on SQLite too.

    pysqlite only opens a real transaction before the first write, so a SAVEPOINT taken after reads only is the
    outermost transaction and its RELEASE commits. The caller's later rollback then no longer drops the row.
    Opening the transaction first keeps the savepoint nested, as it already is on PostgreSQL.
    """
    connection = db.connection()
    if connection.dialect.name == "sqlite" and not connection.connection.dbapi_connection.in_transaction:
        connection.exec_driver_sql("BEGIN")
    with db.begin_nested() as nested:
        yield nested


def generate_reference_code(
    db: Session,
    model: Type,
    prefix: str,
    id_field: str = "id",
    zero_pad: int = 6,
) -> str:
    """
    Generate a sequential business reference code.
    Example: generate_reference_code(db, Supplier, "SUP") → "SUP-000017"

    Uses MAX(id) + 1 to avoid count() issues after deletions.
    Thread-safety note: unique DB constraint on code column is the final guard.
    """
    max_id = db.query(func.max(getattr(model, id_field))).scalar() or 0
    next_num = max_id + 1
    return f"{prefix}-{next_num:0{zero_pad}d}"


def next_yearly_code(
    db: Session,
    column: Any,
    prefix: str,
    pad: int = 3,
    year: Optional[int] = None,
) -> str:
    """
    Next ``<prefix>-<year>-<NNN>`` code for a String column (e.g. ``PurchaseOrder.po_number`` -> "PO-2026-004").

    The sequence restarts every year and continues from the highest numeric suffix already used that
    year, so user-typed codes in the same pattern are skipped and deletions never reuse a number.
    Suffixes that are not plain digits ("PO-2026-REF01", "PO-2026-001-COPY") are ignored. The unique
    constraint on the column stays the final guard: callers retry on IntegrityError.
    """
    year = year or datetime.now().year
    head = f"{prefix}-{year}-"
    suffix = func.substr(column, len(head) + 1)
    highest = (
        db.query(func.max(cast(suffix, Integer)))
        .filter(
            and_(
                column.like(f"{head}%"),
                suffix != "",
                suffix.op("NOT GLOB")("*[^0-9]*"),  # SQLite: digits only
            )
        )
        .scalar()
    )
    return f"{head}{(highest or 0) + 1:0{pad}d}"


def next_global_code(
    db: Session,
    column: Any,
    prefix: str,
    pad: int = 6,
) -> str:
    """
    Next ``<prefix>-<NNNNNN>`` code for a String column (e.g. ``Supplier.supplier_code`` -> "SUP-000017",
    ``ClearanceExpenseType.expense_code`` -> "EXP-001").

    Continues from the highest numeric suffix already used across all records,
    so user-typed codes in the same pattern are skipped and deletions never reuse a number.
    Suffixes that are not plain digits are ignored. The unique constraint on the column stays
    the final guard: callers retry on IntegrityError.
    """
    head = f"{prefix}-"
    suffix = func.substr(column, len(head) + 1)
    highest = (
        db.query(func.max(cast(suffix, Integer)))
        .filter(
            and_(
                column.like(f"{head}%"),
                suffix != "",
                suffix.op("NOT GLOB")("*[^0-9]*"),  # SQLite: digits only
            )
        )
        .scalar()
    )
    return f"{head}{(highest or 0) + 1:0{pad}d}"

