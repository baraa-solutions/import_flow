# List Paging, Lookups & Export Standard Contract (BE-01 / FEX-T03)

This document defines the enterprise architecture and API contracts for paginated list endpoints, remote lookups, and full-dataset exports across ImportFlow ERP.

---

## 1. Executive Summary & Principles

1. **Single Standard Contract:** Every list in the ERP must follow one uniform HTTP contract for server paging, sorting, searching, and filtering. Ad-hoc query params (`skip/limit`, `offset`, custom JSON envelopes) are replaced by this standard.
2. **Lightweight Summaries (`<Entity>ListItem`):** List endpoints return only top-level summary columns (business codes, names, status, key amounts with currency, timestamps). Heavy nested relationships (e.g. PO line items, invoice lines, packing list items) are strictly excluded from list endpoints and fetched on demand via `GET /api/v1/<entity>/{id}`.
3. **Deterministic Pagination:** Sorting always enforces a primary key tie-breaker (`id DESC`) as the final sort clause to eliminate duplicate rows or skipped records across page boundaries.
4. **Whitelisted Sorting:** Sort columns are strictly validated against a server-side whitelist (`SORT_MAP`). Unknown columns yield a structured `400 Bad Request` with error code `LIST_SORT_FIELD_INVALID`.
5. **No Client Memory Exhaustion:** Large entities (customs tariffs, audit logs, purchase orders) must not be loaded wholesale into browser/desktop memory. Server paging slices records into bounded pages (`page_size ≤ 200`).
6. **Remote Lookups for Pickers:** Dropdown selectors must not download entire tables. Lookups use the lightweight `/lookup` contract with debounced search (`q`) and selected ID resolution (`ids`).

---

## 2. Paginated List Contract

### 2.1 Route Definition
All paginated endpoints MUST follow this URL path convention:
```http
GET /api/v1/<entity>/paginated
```

Existing plain list endpoints (e.g. `GET /api/v1/<entity>`) remain unchanged for backward compatibility during phased migration.

### 2.2 Query Parameters

Endpoints accept parameters via `PageParams = Depends()` from `modules.common.pagination`:

| Parameter | Type | Default | Constraints | Description |
|---|---|---|---|---|
| `page` | `int` | `1` | `ge=1` | 1-based page index. Values `< 1` yield `422 Unprocessable Entity`. |
| `page_size` | `int` | `50` | `ge=1, le=200` | Number of items per page. Values `< 1` or `> 200` yield `422`. |
| `sort` | `str` | `None` | `max_length=200` | Comma-separated sort keys (e.g. `-created_at,code`). Prefix `-` indicates descending; optional `+` or no prefix indicates ascending. |
| `q` | `str` | `None` | `max_length=100` | Free text search filter. Wildcard characters (`%`, `_`, `\`) are escaped on the backend to prevent wildcard injection. |
| `include_inactive` | `bool` | `false` | - | When true, includes soft-deleted or inactive records. Default is active records only. |
| `<entity filters>` | query params | `None` | - | Entity-specific filters: `status`, `company_id`, `supplier_id`, `import_file_id`, `date_from`, `date_to`, etc. |

Legacy alias `search` may be mapped to `q` when `q` is omitted.

### 2.3 Response Envelope

#### Response Body (JSON)
```json
{
  "items": [
    {
      "id": 101,
      "code": "PO-2026-0042",
      "supplier_name": "Global Chemical Corp",
      "status": "APPROVED",
      "total_amount": 125000.50,
      "currency": "USD",
      "created_at": "2026-03-15T10:30:00Z"
    }
  ],
  "total": 12450,
  "page": 1,
  "page_size": 50,
  "total_pages": 249
}
```

#### Envelope Rules:
- `items`: Array of lightweight summary objects (`<Entity>ListItem`).
- `total`: Total count of records matching all active filters (computed before `offset` and `limit`).
- `page`: Requested 1-based page index.
- `page_size`: Requested page size (between 1 and 200).
- `total_pages`: Total number of pages (`ceil(total / page_size)`). When `total == 0`, `total_pages = 1` and `items = []`.
- When requesting a page beyond `total_pages`, `items = []`, while `total` and `total_pages` reflect the accurate query count.

#### Response Headers:
- `X-Total-Count: <total>` is set on every successful `200 OK` response.

---

## 3. Sorting & Whitelisting Contract

Each backend module defines a `SORT_MAP: Dict[str, InstrumentedAttribute]` mapping public parameter names to SQLAlchemy model columns.

### 3.1 Sort Syntax
- Ascending: `column_name` or `+column_name`.
- Descending: `-column_name`.
- Multiple columns: comma-separated list evaluated in order: `-created_at,code`.

### 3.2 Primary Key Tie-Breaker
A deterministic tie-breaker (`<Model>.id.desc()`) is always appended automatically by `modules.common.pagination.apply_sort` unless the primary key was already explicitly included in `sort`. This guarantees deterministic order across pages when sorting on columns with duplicate values (e.g. `status`, `date`).

### 3.3 Invalid Sort Field Error (HTTP 400)
When an unrecognized or non-whitelisted sort field is supplied, the endpoint MUST raise an HTTP 400 Bad Request with the standard error structure:
```json
{
  "detail": {
    "code": "LIST_SORT_FIELD_INVALID",
    "message": "حقل الترتيب 'secret_col' غير مسموح به. الحقول المسموح بها: code, created_at, status.",
    "field": "secret_col",
    "allowed": "code, created_at, status"
  }
}
```

---

## 4. Remote Lookup Contract for Pickers (`/lookup`)

To prevent memory bloat in dropdown selectors (`SearchableDropdownField`), entities provide a lightweight lookup endpoint:

### 4.1 Route Definition
```http
GET /api/v1/<entity>/lookup
```

### 4.2 Query Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `q` | `str` | `None` | Search query matching code, name, or reference. |
| `limit` | `int` | `20` | Max items returned (bounded `ge=1, le=100`). |
| `ids` | `str` | `None` | Comma-separated primary keys (e.g. `1,2,3`) to resolve display labels of currently selected records regardless of `q` filter. |
| `include_inactive`| `bool`| `false`| Include inactive items (useful when displaying historic records). |

### 4.3 Response Structure
```json
[
  {
    "id": 101,
    "code": "IMP-2026-0004",
    "label": "PET Stock (IMP-2026-0004) — Global Chem",
    "is_active": true
  },
  {
    "id": 102,
    "code": "IMP-2026-0005",
    "label": "Raw Materials Batch B (IMP-2026-0005)",
    "is_active": true
  }
]
```

---

## 5. Server-Side Export Contract

Full dataset exports (Excel `.xlsx` or CSV) must never be performed by loading hundreds of thousands of rows in the client.

### 5.1 Route Definition
```http
GET /api/v1/<entity>/export-excel
```

### 5.2 Behavior:
- Accepts the exact same query parameters as the paginated endpoint (`q`, `sort`, `include_inactive`, and all entity-specific filters), excluding `page` and `page_size`.
- Streams an Excel workbook (`application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`) or CSV (`text/csv; charset=utf-8` with UTF-8 BOM `\ufeff`).
- Header `Content-Disposition: attachment; filename="[Stage Name] - [Entity Code].xlsx"`.
- Uses streaming response (`StreamingResponse`) with batched DB cursor iteration (`yield_per(1000)`) to maintain constant server memory usage.

---

## 6. Authorization & Security

- **Permission Requirement:** All `/paginated`, `/lookup`, and `/export-excel` endpoints enforce standard module-level view permissions:
  ```python
  current_user: User = Depends(require_permission("<module>.view"))
  ```
- **Tenant & Entity Scoping:** Multi-tenant boundaries and user project/company scopes are enforced at the query level before `paginate()` is invoked.
- **SQL Injection Prevention:** All search queries (`q`) pass through `like_term(q)` which escapes `%`, `_`, and `\`, applied exclusively via parameterized ORM filters (`col.ilike(...)`).

---

## 7. Backend Implementation Template

```python
from typing import Optional
from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.permissions import require_permission
from modules.common.pagination import Page, PageParams, paginate, like_term
from modules.users.model import User

from .model import PurchaseOrder
from .schemas import PurchaseOrderListItem

router = APIRouter(prefix="/api/v1/purchase-orders", tags=["Purchase Orders"])

PO_SORT_MAP = {
    "id": PurchaseOrder.po_id,
    "code": PurchaseOrder.po_number,
    "po_number": PurchaseOrder.po_number,
    "order_date": PurchaseOrder.order_date,
    "created_at": PurchaseOrder.created_at,
    "status": PurchaseOrder.status,
    "supplier_id": PurchaseOrder.supplier_id,
    "company_id": PurchaseOrder.company_id,
    "total_amount_fob": PurchaseOrder.total_amount_fob,
}

@router.get("/paginated", response_model=Page[PurchaseOrderListItem])
def list_purchase_orders_paginated(
    response: Response,
    params: PageParams = Depends(),
    status_filter: Optional[str] = Query(None, alias="status"),
    supplier_id: Optional[int] = Query(None),
    company_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("purchase_orders.view")),
):
    query = db.query(PurchaseOrder)

    if not params.include_inactive:
        query = query.filter(PurchaseOrder.is_active.is_(True))

    if status_filter:
        query = query.filter(PurchaseOrder.status == status_filter)
    if supplier_id:
        query = query.filter(PurchaseOrder.supplier_id == supplier_id)
    if company_id:
        query = query.filter(PurchaseOrder.company_id == company_id)

    if params.q:
        escaped = like_term(params.q)
        query = query.filter(
            PurchaseOrder.po_number.ilike(escaped)
            | PurchaseOrder.po_reference.ilike(escaped)
        )

    return paginate(
        query=query,
        params=params,
        sort_map=PO_SORT_MAP,
        default_sort=[PurchaseOrder.created_at.desc()],
        pk=PurchaseOrder.po_id,
        response=response,
    )
```

---

## 8. Frontend Integration Template (Flutter / Riverpod)

```dart
// 1. Feature Notifier backed by ServerPagedSource
final purchaseOrdersPagedProvider = StateNotifierProvider.autoDispose<
    PagedListNotifier<PurchaseOrderListItem>,
    PagedListState<PurchaseOrderListItem>>((ref) {
  final dio = ref.watch(dioProvider);
  return PagedListNotifier<PurchaseOrderListItem>(
    source: ServerPagedSource(
      dio: dio,
      path: '/api/v1/purchase-orders/paginated',
      fromJson: (json) => PurchaseOrderListItem.fromJson(json),
    ),
    initialQuery: const ListQuery(pageSize: 50, sort: '-created_at'),
  );
});

// 2. Screen Widget with PagedDataTable
PagedDataTable<PurchaseOrderListItem>(
  storageKey: 'purchase_orders_table',
  state: ref.watch(purchaseOrdersPagedProvider),
  onQueryChanged: (query) => ref.read(purchaseOrdersPagedProvider.notifier).setQuery(query),
  columns: [
    PagedTableColumn(
      id: 'po_number',
      label: (l) => l.poNumber,
      width: 140,
      pinned: true,
      sortKey: 'code',
      cell: (context, row) => Text(row.poNumber),
    ),
    // ...
  ],
  rowActions: (row) => [
    RowAction(
      kind: RowActionKind.view,
      permission: 'purchase_orders.view',
      run: (row) async => EntityDetailsRegistry.open(
        context,
        ref,
        EntityRef(type: EntityType.purchaseOrder, id: row.id, code: row.poNumber),
      ),
    ),
    RowAction(
      kind: RowActionKind.edit,
      permission: 'purchase_orders.manage',
      run: (row) async => _openEditDialog(row),
    ),
  ],
)
```

---

## 9. Per-Entity Specification Table

| Entity | Paginated Route | Lookup Route | Summary Schema (`items`) | Allowed Sort Fields (`sort`) | Filter Parameters | Searchable Columns (`q`) |
|---|---|---|---|---|---|---|
| **Customs Tariff** | `/customs-tariff/paginated` | `/customs-tariff/lookup` | `CustomsTariffListItem` (tariff_id, hs_code, hs_description, customs_category, customs_duty_rate, vat_rate, schedule_tax_rate, is_active) | `hs_code`, `customs_duty_rate`, `vat_rate`, `customs_category`, `created_at` | `customs_category`, `requires_coo`, `requires_inspection`, `include_inactive` | `hs_code`, `hs_description` |
| **Audit Logs** | `/audit-logs/paginated` | - | `AuditLogListItem` (log_id, entity_type, entity_id, entity_code, action, changes_summary, performed_at, performed_by) | `performed_at`, `action`, `entity_type`, `entity_code`, `performed_by` | `entity_type`, `action`, `entity_id`, `date_from`, `date_to` | `entity_code`, `performed_by`, `changes_summary` |
| **Purchase Orders** | `/purchase-orders/paginated` | `/purchase-orders/lookup` | `PurchaseOrderListItem` (po_id, po_number, po_reference, supplier_name, company_name, total_amount_fob, currency_code, status, order_date, created_at) | `code`, `po_number`, `order_date`, `created_at`, `total_amount_fob`, `status`, `supplier_id` | `status`, `company_id`, `supplier_id`, `project_id`, `currency_id`, `date_from`, `date_to` | `po_number`, `po_reference`, `proforma_invoice_number` |
| **Payment Requests** | `/financial-approval/payment-requests/paginated` | - | `PaymentRequestListItem` (payment_id, payment_code, title, import_file_id, po_id, supplier_name, payment_type, requested_amount, currency_code, requested_amount_egp, status, due_date, request_date) | `payment_code`, `request_date`, `due_date`, `requested_amount`, `requested_amount_egp`, `status`, `created_at` | `status`, `payment_type`, `import_file_id`, `po_id`, `supplier_id`, `currency_code`, `date_from`, `date_to` | `payment_code`, `title`, `supplier_name` |
| **Smart Tasks** | `/smart-tasks/paginated` | - | `SmartTaskListItem` (task_id, task_code, title, task_type, priority, import_file_code, phase_name, assigned_user, reminder_type, due_date, status, is_active, created_at) | `task_code`, `created_at`, `due_date`, `priority`, `status`, `assigned_user` | `priority`, `status`, `task_type`, `assigned_user`, `import_file_id`, `phase_name` | `task_code`, `title`, `description`, `import_file_code` |
| **Transport Locations** | `/transport-locations/paginated` | `/transport-locations/lookup` | `TransportLocationListItem` (location_id, un_locode, location_name, location_type, country, city, is_active) | `un_locode`, `location_name`, `location_type`, `country`, `city`, `created_at` | `location_type`, `country`, `city`, `include_inactive` | `un_locode`, `location_name`, `city`, `country` |
| **Partners (Providers)** | `/external-service-providers/paginated` | `/external-service-providers/lookup` | `PartnerListItem` (provider_id, partner_code, partner_name, partner_type, tax_id, commercial_register, is_active) | `partner_code`, `partner_name`, `partner_type`, `created_at` | `partner_type`, `include_inactive` | `partner_code`, `partner_name`, `tax_id`, `commercial_register` |
| **Projects** | `/projects/paginated` | `/projects/lookup` | `ProjectListItem` (project_id, project_code, project_name, project_owner, company_id, supplier_id, total_budget_usd, status, is_active) | `project_code`, `project_name`, `created_at`, `total_budget_usd`, `status` | `company_id`, `supplier_id`, `status`, `include_inactive` | `project_code`, `project_name`, `project_owner` |
| **Import Files** *(Ref Impl)* | `/import-files/paginated` | `/import-files/lookup` | `ImportFileListItem` (import_file_id, import_file_code, custom_file_number, company_name, supplier_name, status, current_stage, required_eta) | `import_file_code`, `created_at`, `required_eta`, `file_opening_date`, `status`, `progress_percent`, `company_name` | `status`, `company_id`, `supplier_id`, `owner`, `hs_code`, `incoterm_code`, `shipment_mode` | `import_file_code`, `custom_file_number`, `supplier_name`, `company_name` |
| **Warehouse Receiving** | `/warehouse-receiving/paginated` | - | `WarehouseReceivingListItem` (receiving_id, receiving_code, import_file_id, import_file_code, arrival_date, inspection_status, status) | `receiving_code`, `arrival_date`, `created_at`, `status` | `status`, `inspection_status`, `import_file_id`, `date_from`, `date_to` | `receiving_code`, `import_file_code`, `driver_name` |
| **Inland Transport** | `/inland-transport/paginated` | - | `InlandTransportListItem` (transport_id, booking_reference, import_file_id, import_file_code, driver_name, truck_plate, status) | `booking_reference`, `loading_date`, `delivery_date`, `created_at`, `status` | `carrier_partner_id`, `status`, `import_file_id`, `date_from`, `date_to` | `booking_reference`, `import_file_code`, `truck_plate`, `driver_name` |

---

## 10. Implementation Checklist for New Entities

When adding server pagination to any entity:
- [ ] Create or verify `<Entity>ListItem` Pydantic response schema (lightweight, no nested line items).
- [ ] Define `ENTITY_SORT_MAP` in module's router or service.
- [ ] Implement `GET /api/v1/<entity>/paginated` endpoint consuming `PageParams` and returning `Page[<Entity>ListItem]`.
- [ ] If entity is selectable in UI dropdowns, implement `GET /api/v1/<entity>/lookup` returning `List[LookupItem]`.
- [ ] Add unit test verifying sorting, filtering, search query escaping, and `LIST_SORT_FIELD_INVALID` on bad sort keys.
- [ ] Wire frontend screen to `PagedDataTable` using `ServerPagedSource`.
