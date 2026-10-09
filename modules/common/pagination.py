"""
modules/common/pagination.py
Shared pagination helper and contract for ImportFlow ERP list endpoints (BEW0-04).
Implements standard pagination contract:
- Query parameters: page (ge=1), page_size (1..200), sort, q
- Response envelope: {items, total, page, page_size, total_pages}
- Header: X-Total-Count: <total>
- Deterministic ordering with primary key tie-breaker
- SQL LIKE / ILIKE wildcard escaping helper
"""
import math
from typing import Any, Dict, Generic, List, Optional, Sequence, TypeVar

from fastapi import HTTPException, Query, Response, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy.orm import Query as SAQuery

from modules.common.errors import CodedHTTPException

T = TypeVar("T")


class PageParams:
    """FastAPI dependency for list pagination parameters."""

    def __init__(
        self,
        page: int = Query(1, ge=1, description="Page number (1-indexed)"),
        page_size: int = Query(50, ge=1, le=200, description="Page size (1..200)"),
        sort: Optional[str] = Query(None, max_length=200, description="Sort expression, e.g. -created_at,code"),
        q: Optional[str] = Query(None, max_length=100, description="Search term across default text columns"),
        include_inactive: bool = Query(False, description="Include soft-deleted records"),
    ):
        self.page = page if isinstance(page, int) else 1
        self.page_size = page_size if isinstance(page_size, int) else 50
        self.sort = sort if isinstance(sort, str) else None
        self.q = q if isinstance(q, str) else None
        self.include_inactive = include_inactive if isinstance(include_inactive, bool) else False


class Page(BaseModel, Generic[T]):
    """Standard pagination envelope."""

    items: List[T]
    total: int
    page: int
    page_size: int
    total_pages: int

    model_config = ConfigDict(from_attributes=True)


def like_term(q: Optional[str]) -> Optional[str]:
    """Sanitize and wrap search query for SQL LIKE/ILIKE with escape='\\\\'.

    Escapes '%', '_', and '\\' characters to prevent wildcard injection.
    Returns None if input is None or empty.
    """
    if q is None:
        return None
    clean = str(q).strip()
    if not clean:
        return None
    escaped = clean.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    return f"%{escaped}%"


def apply_sort(
    query: SAQuery,
    sort: Optional[str],
    allowed: Dict[str, Any],
    default: Optional[Sequence[Any]] = None,
    pk: Optional[Any] = None,
) -> SAQuery:
    """Parse comma-separated sort tokens, validate fields, and apply order_by.

    - Tokens may have '-' prefix for descending or optional '+' for ascending.
    - Unrecognized field raises 400 LIST_SORT_FIELD_INVALID.
    - pk is always appended as tie-breaker (if provided and not already included).
    """
    clauses: List[Any] = []
    if sort:
        tokens = [t.strip() for t in str(sort).split(",") if t.strip()]
        for token in tokens:
            descending = False
            field_name = token
            if token.startswith("-"):
                descending = True
                field_name = token[1:].strip()
            elif token.startswith("+"):
                field_name = token[1:].strip()

            if field_name not in allowed:
                allowed_str = ", ".join(sorted(allowed.keys()))
                raise CodedHTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    code="LIST_SORT_FIELD_INVALID",
                    message_ar=f"حقل الترتيب '{field_name}' غير مسموح به. الحقول المسموح بها: {allowed_str}.",
                    field=field_name,
                    allowed=allowed_str,
                )

            col = allowed[field_name]
            clauses.append(col.desc() if descending else col.asc())

    if not clauses and default:
        clauses.extend(default)

    if pk is not None:
        pk_desc = pk.desc()
        # Avoid duplicate tie-breaker if pk is already in order clauses
        already_ordered_by_pk = any(
            c is pk_desc or getattr(c, "element", None) is pk for c in clauses
        )
        if not already_ordered_by_pk:
            clauses.append(pk_desc)

    if clauses:
        query = query.order_by(*clauses)
    return query


def paginate(
    query: SAQuery,
    params: PageParams,
    *,
    sort_map: Dict[str, Any],
    default_sort: Optional[Sequence[Any]] = None,
    pk: Optional[Any] = None,
    response: Optional[Response] = None,
) -> Dict[str, Any]:
    """Execute pagination on a SQLAlchemy query.

    - Computes total matching rows.
    - Applies sorting and tie-breaker.
    - Applies offset and limit bounds.
    - Sets X-Total-Count header on response (if provided).
    - Returns dictionary matching Page envelope.
    """
    total = query.order_by(None).count()
    sorted_query = apply_sort(query, params.sort, allowed=sort_map, default=default_sort, pk=pk)

    offset = (params.page - 1) * params.page_size
    items = sorted_query.offset(offset).limit(params.page_size).all()

    total_pages = math.ceil(total / params.page_size) if total > 0 else 1
    if total_pages < 1:
        total_pages = 1

    if response is not None:
        response.headers["X-Total-Count"] = str(total)

    return {
        "items": items,
        "total": total,
        "page": params.page,
        "page_size": params.page_size,
        "total_pages": total_pages,
    }
