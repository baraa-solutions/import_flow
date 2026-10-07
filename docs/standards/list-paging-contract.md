# List Paging & Sorting Standard Contract

This document defines the standard contract and convention for paginated and sorted list endpoints across ImportFlow ERP.

## 1. Route Definition

All paginated endpoints MUST follow this URL path convention:
```http
GET /api/v1/<entity>/paginated
```

Examples:
- `GET /api/v1/import-files/paginated`
- `GET /api/v1/warehouse-receiving/paginated`
- `GET /api/v1/inland-transport/paginated`

---

## 2. Query Parameters

Endpoints accept query parameters via `PageParams = Depends()` from `modules.common.pagination`:

| Parameter | Type | Default | Constraints | Description |
|---|---|---|---|---|
| `page` | `int` | `1` | `ge=1` | 1-based page index. Values `< 1` yield `422`. |
| `page_size` | `int` | `50` | `ge=1, le=200` | Number of items per page. Values `< 1` or `> 200` yield `422`. |
| `sort` | `str` | `None` | `max_length=200` | Comma-separated sort keys (e.g. `-created_at,code`). Prefix `-` indicates descending. |
| `q` | `str` | `None` | `max_length=100` | Search text filter. `%`, `_`, and `\` are escaped to prevent wildcard injection. |
| `include_inactive` | `bool` | `false` | - | When true, includes soft-deleted / inactive records. |

Legacy alias `search` may be accepted and mapped to `q` when `q` is not supplied.

---

## 3. Response Structure

### Response Body (JSON Envelope)
```json
{
  "items": [ ... ],
  "total": 120,
  "page": 1,
  "page_size": 50,
  "total_pages": 3
}
```

- When total = 0, `total_pages = 0` and `items = []`.
- When requesting a page past the end, `items = []`, while `total` and `total_pages` reflect the true count.

### Response Headers
- `X-Total-Count: <total>` is set on every successful response.

---

## 4. Sorting & Error Handling

Each module defines a `SORT_MAP: Dict[str, InstrumentedAttribute]` mapping allowed external field names to SQLAlchemy model columns.

- Valid sort format: `field` (ascending) or `-field` (descending). Multiple fields can be separated by commas: `-created_at,code`.
- A deterministic tie-breaker by primary key (descending) is always appended if not already sorted by PK.
- If an unknown sort field is requested, the endpoint MUST raise HTTP 400 with system message `LIST_SORT_FIELD_INVALID`:
```json
{
  "detail": {
    "code": "LIST_SORT_FIELD_INVALID",
    "params": {
      "field": "invalid_column",
      "allowed": "created_at, code, status, ..."
    }
  }
}
```

---

## 5. Implementation Helper

All modules should utilize `modules.common.pagination`:
```python
from fastapi import APIRouter, Depends, Response
from modules.common.pagination import PageParams, paginate

@router.get("/paginated", response_model=PaginatedEntityResponse)
def list_paginated_entities(
    response: Response,
    params: PageParams = Depends(),
    db: Session = Depends(get_db),
):
    query = db.query(MyModel).filter(...)
    return paginate(
        query,
        params,
        sort_map=ENTITY_SORT_MAP,
        default_sort=[MyModel.id.desc()],
        pk=MyModel.id,
        response=response,
    )
```
