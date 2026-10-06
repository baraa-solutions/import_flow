# Cross-cutting backend (auth, common, lifecycle, master data, settings, reports, list pagination): backend review

Status: 2026-10-05, static review only (grep / read; no pytest, no `import main`, no DB access).
Baseline: the fixes listed in `docs/plans/phase-*-quality-plan.md` and `docs/plans/backend-review/be-*.md` are not
re-reported. Items found there and still broken are marked "still open from <id>". `customs_tariff` is owned by
`be-06-07-review.md` (BE67-*): only the shared root cause in `modules/currencies` is reported here.
Severity: **BLOCKER** = wrong money / data corruption / security / auth bypass. **CRITICAL** = wrong result or 500 on a
normal path. **MAJOR** = rule violation, real risk. **MINOR** = hygiene.

| File | Lines | Depth |
|---|---|---|
| `modules/auth/security.py` | 215 | Full |
| `modules/auth/permissions.py` | 369 | Full |
| `modules/auth/router.py` | 284 | Full (every route) |
| `modules/auth/service.py` | 539 | Full |
| `modules/auth/rate_limiter.py` | 81 | Full |
| `modules/auth/schemas.py` | 114 | 1-60 |
| `modules/auth/seed_rbac.py` | 469 | Permission catalog and role grants (1-250), seed flow headers |
| `modules/audit_logs/{service,router}.py` | 85 | Full |
| `modules/lifecycle_board/router.py` | 195 | Full |
| `modules/lifecycle_board/service.py` | 1650 | 150-1420 line by line; 1420-1650 scanned (defaults, risk math) |
| `modules/lifecycle_board/{repository,validators,model}.py` | 302 | Full |
| `modules/lifecycle_board/schemas.py` | 248 | 1-140, request schemas |
| `modules/import_files/router.py` | 434 | Full |
| `modules/import_files/repository.py` | 436 | 1-380 |
| `modules/import_files/service.py` | 1285 | 241-620, 1018-1080, 1160-1285; 620-1018 scanned (RFQ defaults) |
| `modules/import_files/schemas.py`, `model.py` | 585 | Fields, defaults, response model |
| `modules/currencies/*` | 728 | router, service full; repository 60-114; schemas fields |
| `modules/projects/{router,service,repository}.py` | 520 | Routes, service 19-146, code generator |
| `modules/suppliers`, `import_companies`, `transport_locations`, `incoterms`, `expense_catalog`, `external_service_providers` | ~3,900 | Route/auth matrix (AST), Excel import routes, code generators, validators, delete paths |
| `modules/common/{sequence_generator,system_parameters,legacy_rows}.py` | 411 | Full / 1-120 / 1-60 |
| `modules/system_observability/router.py` | ~200 | Route/auth matrix, 60-120 |
| `modules/smart_tasks`, `notifications`, `experience_guide`, `smart_email_listener` routers | n/a | Route/auth matrix only (AST) |
| `database/database.py` | 95 | Full |
| `database/schema_upgrade_service.py` | 456 | Index of steps / exception handling |
| `utils/export_import_helper.py` | 289 | `parse_excel_file` limits |
| `main.py`, `settings.py` | 713 | Full |
| Context read | n/a | `be-02-review.md` (BE02-T08 paging), `be-06-07-review.md` (BE67-F01/F04/T03), `review-shared-needs.md`, `review-coverage.md`, FE reviews 01-03 (pagination asks), Flutter providers listed in section 4 |

---

## 1. Summary

| Severity | Count |
|---|---|
| BLOCKER | 6 |
| CRITICAL | 5 |
| MAJOR | 22 |
| MINOR | 9 |

Top points:
1. **Any logged-in user can move or close a shipment on the lifecycle board (BEX-F01).** The 12 board routes only check
   login. The permission `lifecycle_board.advance` exists but is never checked. A read-only `AUDITOR_VIEWER` can
   `POST /lifecycle-board/stages/sync {"completed_step_code":"STEP_21"}`. This marks all 25 steps Completed, sets the
   file to 100 % and "file closed", and skips the skip policy entirely.
2. **Master data has no write permission (BEX-F02).** Currencies, incoterms, projects, suppliers, importing companies,
   ports, the expense catalog and partners can be created, edited, deleted and bulk-imported by any user.
   `master_data.edit` exists, but only `POST /currencies/rates` checks it.
3. **Invented money and dates (BEX-F03, F05, F07).** `_get_rate_to_egp` returns a hard-coded USD 48.50 / EUR 52.80, or 1.0,
   when no rate exists. The customs engine still uses it (still open from BE67-F04 shared need). Project commitments add EUR
   and CNY purchase orders to a USD budget as if they were USD. The Excel import of importing companies stores
   **2027-12-31** as the expiry of the importer card, VAT card and commercial registry when the cell is empty.
4. **Logout does not survive a restart (BEX-F04).** The revoked-token list is loaded from the DB only by `/auth/refresh` and
   `/auth/logout`. After a backend restart, every logged-out token works again on all other routes. Password changes never
   revoke tokens (BEX-F14).
5. **Saving an import file rewinds its progress (BEX-F08).** `PUT /import-files/{id}` recomputes `progress_percent`,
   `current_module`, `current_stage` and `next_action` from four form fields. A file at STEP_19 (88 %) goes back to 15 % on
   any edit. `GET /import-files/{id}` can return a **different** file through a fuzzy `%term%` code match (BEX-F09).

---

## 2. Findings

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| BEX-F01 | BLOCKER | `lifecycle_board/router.py:29-33`, `140-146`, `149-166`, `187-193`, `93-108`; `service.py:350-376`, `425-428`, `451-453`; `seed_rbac.py:30-31` | Every board route has only the router-level `get_current_user`. `lifecycle_board.view` / `lifecycle_board.advance` are seeded but never checked. `/stages/sync` and `/stages/advance` accept any `completed_step_code` with `auto_complete_prior=True` (default): STEP_21 auto-completes every prior step, sets 100 % and `NA_FILE_CLOSED`, and bypasses `skip_step_service` (skip policy and approver roles). No file status check (Closed / On Hold / inactive files can be advanced). | GET routes: `require_permission("lifecycle_board.view")`. POST routes: `lifecycle_board.advance`. From HTTP, complete only a step that is In-Progress (or "Reference recorded") on that file, force `auto_complete_prior=False` for non-ADMIN, refuse STEP_21 (owned by file_closure), 409 for Closed/Archived/On Hold. Task BEX-T01. |
| BEX-F02 | BLOCKER | `currencies/router.py:25-109`; `incoterms/router.py:55-228`; `projects/router.py:15-178`; `suppliers/router.py:38-302`; `import_companies/router.py:42-289`; `transport_locations/router.py:20-202`; `expense_catalog/router.py:35-102`; `external_service_providers/router.py:20-224` | 92 master-data route registrations (counted with the trailing-slash duplicates), including create / PUT / DELETE / restore / `import-excel`, have only `get_current_user`. `AUDITOR_VIEWER` can rename a supplier, deactivate a currency, change an incoterm responsibility or the expense catalog that classifies clearance costs. `master_data.edit` is held by ADMIN only (`seed_rbac.py:150,176,197,214,240`), so enforcing it needs a grant decision (Q1). | GET: `master_data.view`; writes: `master_data.edit`; grant `master_data.edit` per Q1 through the seed's one-time grant mechanism. Tasks BEX-T04/T05/T06. |
| BEX-F03 | BLOCKER | `currencies/service.py:170-189`; callers `customs_tariff/service.py:596-601`, `1404-1407`; Flutter `currencies_provider.dart:114` | `_get_rate_to_egp` invents a rate: an unregistered USD/EUR/GBP/CNY/SAR/AED gets a hard-coded value (USD 48.50), a registered currency with no rate gets that value or **1.0**, and the result is cached for 5 min. `rate_id=None` is the only signal. `POST /currencies/convert` shows the fabricated result to the user. Still open from BE67-F04 (BE67-T03 explicitly left `fallback_rates` as a shared need). | Delete `fallback_rates`. No rate → 409 `CURRENCY_RATE_MISSING` (currency, rate_type, as_of_date). Never cache a miss. Task BEX-T07. |
| BEX-F04 | BLOCKER | `auth/security.py:162-213`; `auth/router.py:107`, `168`; `auth/permissions.py:241` | `token_revocation_manager.init_from_db` runs only inside `/auth/refresh` and `/auth/logout`. `resolve_user` checks the in-memory set only. After a restart the set is empty, so every token revoked by logout is accepted again on all routes until someone calls refresh/logout. | Load the revoked set at startup (after the schema upgrade) and lazily in `decode_access_token` on first use. Task BEX-T08. |
| BEX-F05 | BLOCKER | `projects/service.py:38-53`, `84-102`; `purchase_orders/model.py:38` | Project `total_committed_usd`, `remaining_budget_usd` and `budget_utilization_percent` add `PurchaseOrder.total_amount_fob` of every PO whatever its `currency_id`. A EUR 10,000 PO counts as USD 10,000. | Convert each PO to USD with the commercial rate (EGP pivot). A missing rate gives `None` totals plus `missing_rate_currencies`, never a guessed number. Task BEX-T10. |
| BEX-F06 | CRITICAL | `import_files/service.py:452`; `schemas.py:357` | Master report `total_estimated_cost = sum(f.estimated_cost)` adds USD, EUR and EGP amounts into one number. | Return `estimated_cost_by_currency: Dict[str, float]`; `total_estimated_cost` only when one currency, else `None`. Task BEX-T10. |
| BEX-F07 | BLOCKER | `import_companies/router.py:123-133`; `projects/router.py:128-139`; `suppliers/router.py:113-131`; `transport_locations/router.py:83-85` | Excel imports fabricate master data: missing importer-card / VAT / registry expiry becomes **2027-12-31**, which makes the expiry tracker report valid legal documents. A missing `company_id` becomes **1** (wrong company owns the project). Budget becomes 0, currency USD, supplier country "China"/"CN", address "Main Industrial Zone", city "Alexandria", type "Sea Port". | Required columns missing → row error, never a default. Move the row loop to each service. Task BEX-T09. |
| BEX-F08 | CRITICAL | `import_files/service.py:387-405`, `241-299` | `update_import_file_service` always merges `compute_file_formulas(...)` into the update. This overwrites `progress_percent` (15 / 25 / 50 / 65), `current_module`, `current_stage`, `next_action*` that the lifecycle engine set. Any PUT (for example a notes edit) rewinds a file at STEP_19 from 88 % to 15 % and resets its next action. | Recompute only on create. On update, never touch tracking fields; the lifecycle engine owns them. Task BEX-T11. |
| BEX-F09 | CRITICAL | `import_files/repository.py:275-285`; `router.py:270-276`, `296-301`; `service.py:1194-1199` | `get_import_file_by_code` matches `custom_file_number ILIKE '%term%'` and returns `.first()`. `GET /import-files/12` with file 12 soft-deleted returns another file whose custom number contains "12". Clone uniqueness uses the same lookup: false 409 on a substring hit, and an **inactive** file with the same code passes the check, then `INSERT` fails on the unique index with a 500. | Exact match on `import_file_code` or `custom_file_number` only; a numeric path param is an id only. Clone checks exact code across active + inactive. Task BEX-T11. |
| BEX-F10 | CRITICAL | `lifecycle_board/service.py:322-331`, `395-422`, `828-847`, `1002-1061`, `1149-1174` | Unknown `import_file_code`: advance/sync, set-active, pending-reference and skip all write `shipment_stage_activity` rows for a file that does not exist (no FK). Neither code nor id → `raise ValueError` → 500. | Resolve the file first; 404 `LC_FILE_NOT_FOUND`; 422 when neither is given. Task BEX-T01. |
| BEX-F11 | CRITICAL | `import_files/repository.py:15-20`; `suppliers/service.py:22-25`; `projects/repository.py:16-19`; `smart_tasks/repository.py:14-17` | Business codes are `count() + 1`. A clone with a typed code in the same pattern (`IMP-2026-0007`), a gap, or two concurrent creates produce a duplicate → `IntegrityError` → 500. `PRJ-<year>-` counts all projects of all years. | Use `modules/common/sequence_generator.next_yearly_code` (IMP, PRJ, TSK) or `generate_reference_code` (SUP), plus one retry on `IntegrityError`. Task BEX-T12. |
| BEX-F12 | MAJOR | `import_files/router.py:96-98`; `repository.py:240-242` | `/import-files/paginated` has no bounds: `page_size=0` → `ZeroDivisionError` (500); `page_size=-1` → SQLite `LIMIT -1` returns every row; `page=0` → negative offset. | Shared `PageParams` (`page ge=1`, `page_size 1..500`). Task BEX-T13. |
| BEX-F13 | MAJOR | `import_files/schemas.py:283`; `service.py:466-494`, `497-532`, `1018-1080` | Import file status is not guarded. `PUT` accepts any `status`, including "Closed" or "Archived", with `import_files.edit`, which bypasses `import_files.close`. Reopen writes `"Active"`, a value outside the Open / In Progress / On Hold / Closed / Archived vocabulary, so the master report counts the file nowhere. Close, hold and resume do not check the current status. | `status` removed from `ImportFileUpdate`. Reopen → "In Progress". Transition table in `validators.py` (409 `IF_STATUS_TRANSITION_INVALID`). Task BEX-T11. |
| BEX-F14 | MAJOR | `auth/service.py:242`, `282`, `325-327`, `368-374`; `auth/router.py:97-139`; `settings.py:149-150` | Tokens carry no version. An admin password reset, a self-service change and deactivate→reactivate leave every issued token valid. `/auth/refresh` accepts tokens up to 14 days after expiry and never revokes the old one, so a stolen token can be renewed forever. | `users.token_version` (Integer, server_default 0), `tv` claim, checked in `resolve_user` and refresh; bump on password change / reset / deactivate / role change; revoke the old token on refresh. Task BEX-T08. |
| BEX-F15 | MAJOR | `auth/rate_limiter.py:20-26`, `17-18` | The login limiter keys on `X-Forwarded-For` taken as-is: a client rotates the header and is never locked out. The failure dicts grow without bound (one key per spoofed value). | Use `request.client.host` unless a trusted-proxy setting lists the peer; also limit per username; prune keys older than the window. Task BEX-T08. |
| BEX-F16 | MAJOR | `audit_logs/service.py:20`; `auth/service.py:171-177`, `250-257`, `330-337`, `525-536`; `audit_logs/router.py:6`, `76-85`; `audit_logs/service.py:57-61` | `log_activity(performed_by="System Admin")` by default, and user create / update / toggle / permission changes never pass the actor: the user-management trail always says "System Admin". `/audit-logs` needs only login (`audit_logs.view` is never checked), so any user reads permission changes and emails. The entity timeline is unbounded. | `performed_by` required (no default); pass `actor.username`; `require_permission("audit_logs.view")`; paging on the timeline. Task BEX-T15. |
| BEX-F17 | MAJOR | `lifecycle_board/repository.py:76`, `139`, `146`, `160`; `service.py:375`, `480`, `813`, `880`, `953`, `975`, `1183`, `1326`, `1339`; `service.py:1083-1084`, `1209-1210` | One board request runs up to 25 commits: `save_or_update_activity` commits per row, and the service commits mid-loop. A failure halfway leaves half the prior steps Completed. Audit-log writes are wrapped in `except Exception: pass` with no rollback. Still open from CL-13 (phase-06-07). | Repository `flush` only; one `db.commit()` per use case (callers from other modules keep committing themselves); audit failure → `logger.exception` + rollback of the audit only. Task BEX-T02. |
| BEX-F18 | MAJOR | `lifecycle_board/service.py:1117-1136`, `913-926`; `schemas.py:69-71` | `skip_policy="dual_approval"` behaves exactly like `single_approval` (one approver, no second signature). `approver_roles` is a free-text list. `update_step_config` authorises on role strings (MANAGER / GENERAL_MANAGER / ADMIN), not on a permission. | Until dual approval exists (Q3), `dual_approval` → 409 `LC_SKIP_DUAL_APPROVAL_REQUIRED` unless ADMIN. Validate `approver_roles` against `roles.role_code`. Config update needs `users.manage` or a new `lifecycle_board.configure` (Q3). Task BEX-T02. |
| BEX-F19 | MAJOR | `lifecycle_board/schemas.py:64`; `router.py:154-166`; `service.py:401`, `476` | `/stages/sync` takes `assigned_user` from the body (the acting user must come from the token). `/stages/advance` records no user at all. | Router passes `current_user.username`; drop `assigned_user` from `LifecycleSyncRequest` (ignored if sent). Task BEX-T01. |
| BEX-F20 | MAJOR | `lifecycle_board/service.py:217-224`, `1416-1420`, `1451`, `1342-1359`; `schemas.py:89-93`, `132-134` | The board invents data. Cards default to "Sea FCL" / "FOB" / "High" / cost 0.0 "USD". Live tracking shows carrier "MSC Line", vessel "Ever Given / Vessel", POL "Shanghai Port", POD "El Dekheila Port", and 14 free days when none are recorded, so the demurrage risk level is computed on invented free time. `GET /summary` writes fabricated `STEP_0n` activities for up to 5 files when the table is empty. | `None` for unknown values (schemas `Optional`); risk level "Unknown" without free days; delete `_ensure_initial_stages`. Task BEX-T03. |
| BEX-F21 | MAJOR | `lifecycle_board/service.py:1382-1399`, `189`; `repository.py:91-99` | Live tracking loads **every** booking, cargo record and customs record (not filtered by the active files) on each poll (`live_polling_provider.dart`). The board summary returns every In-Progress card. | Filter the three pre-fetches with `import_file_id IN (active ids)`. Board summary: optional `phase_id` / `step_code` filters. Task BEX-T03. |
| BEX-F22 | MAJOR | `import_files/schemas.py:31-58`, `131-143`; `model.py:62`, `75`, `157`, `183` | Invented defaults on create: incoterm "FOB", mode "Sea FCL", priority "High", POD "El Dekheila Port (non TMT)", 21 free days, cost currency "USD", owner column default **"Kamal"**. `company_name` / `supplier_name` are required free text while `company_id` / `supplier_id` are optional (master data as text). | Required, with no default where business data is needed (incoterm, mode, currency when cost > 0). Names derived from the FK rows when an id is given. Task BEX-T11 (schema part) + Q4. |
| BEX-F23 | MAJOR | `import_files/schemas.py:315-338` | `ImportFileResponse(ImportFileBase)` keeps the input rules (`company_name min_length=2`, `estimated_cost ge=0`) and is not `@read_model` / `LegacyRowTolerantModel`. One legacy row fails validation and the whole list, the paginated list, the master report and the dashboard return 500. | `@read_model` + `LegacyRowTolerantModel`; money stays `Optional`. Task BEX-T11. |
| BEX-F24 | MAJOR | `import_files/service.py:348-358`, `407-426`; `repository.py:296-308` | `except Exception: pass` around the lifecycle seed, task generation and ACID propagation, with a `db.commit()` per assessment inside the loop. A failed lifecycle seed leaves a file with no board stage, silently. `update_import_file` never sets `updated_by` (the router does not pass the user). | Log + coded warning in the response; single commit; `updated_by=current_user.username`. Task BEX-T11. |
| BEX-F25 | MAJOR | `suppliers/router.py:101-147`; `import_companies/router.py:103-142`; `projects/router.py:112-150`; `transport_locations/router.py:69-107`; `external_service_providers/router.py:72-113`; `utils/export_import_helper.py:73-95` | Excel imports: `async def` with synchronous DB work (freezes the event loop), no permission, no extension / content-type check, the whole body is read before the 20 MB check, business logic and one commit per row in the router (a failure at row 300 leaves 299 rows), and errors return `str(e)` (internals). | Sync `def` + service method; `.xlsx` only; `master_data.edit`; validate all rows, then insert in one transaction (all-or-nothing, report row errors). Task BEX-T09. |
| BEX-F26 | MAJOR | `database/database.py:39-57` | SQLite never runs `PRAGMA foreign_keys = ON`, so every `ForeignKey` in the models is decorative: deleting or mistyping ids leaves orphans that later 500 on joins. The pragma block also swallows errors (`except: pass`). | Enable the pragma; run a one-off orphan report before enabling it in production (Q5). Task BEX-T16. |
| BEX-F27 | MAJOR | `projects/model.py`; `transport_locations/model.py`; `expense_catalog/model.py`; `currencies/model.py`; master-data routers (no `current_user`) | Audit columns are missing (`created_by` / `updated_by` on projects, transport locations, expense catalog, currencies). Where they exist (suppliers, companies, incoterms, exchange rates), they are never set from the token (`ExchangeRateCreate.created_by` comes from the body, `currencies/schemas.py:34`, `repository.py:87`). | Alembic migration adding nullable audit columns; services take `actor` from the router. Tasks BEX-T04..T06 (actor) + BEX-T16 (migration). |
| BEX-F28 | MAJOR | `incoterms/repository.py:162-168`; `router.py:222-231` | Incoterm responsibilities are hard-deleted (`db.delete`). | Soft delete (`is_active`) + restore, or 409 when referenced. Task BEX-T04. |
| BEX-F29 | MAJOR | `projects/service.py:19-60`, `131-146` | `GET /projects` runs 2 extra queries per project (company names + PO sum): N+1. | One grouped PO query per page and one company query. Task BEX-T10. |
| BEX-F30 | MAJOR | `smart_tasks/router.py:30-174`; `notifications/router.py:59-104`; `experience_guide/router.py:76-188`; `smart_email_listener/router.py:79-112`; `system_observability/router.py:101-116` | Other cross-cutting write routes with login only: create / update / delete tasks, `sync-all-active-files`, create notifications for any role, `trigger-expiry-check`, guide promote / reject / delete, read every inbound email log, `alerts/evaluate?force=true` (skips the cooldown, sends e-mails). | Map each to an existing code (`import_files.edit`, `reports.view`, `require_admin`) per the matrix in BEX-T14. |
| BEX-F31 | MAJOR | `import_files/router.py:54-93`; `smart_tasks/repository.py:110`; `suppliers/repository.py:30-42`; `projects/repository.py:59`; `external_service_providers/repository.py:18`; `transport_locations/router.py:26`; `audit_logs/service.py:57-61` | No common list contract: lists return whole tables (`import-files`, `smart-tasks`, suppliers, partners, projects, the audit timeline), `transport-locations` has an optional `limit` and no total, and `import-files/paginated` is the only envelope. FE reviews 01-03 ask for paging with two different shapes (header vs envelope). | One backward-compatible contract (section 4) + shared helper; first endpoints by table size. Tasks BEX-T13, BEX-T14. |
| BEX-F32 | MAJOR | `common/system_parameters.py:38-91`; no router | The 24 business parameters (insurance rates, demurrage tiers, settlement estimate defaults) have no API: changing a rate needs a direct DB edit, with no audit, no `updated_by`. | `GET /api/v1/system-parameters` (`reports.view`) and `PUT /{key}` (`require_admin`), with typed validation per key and an audit log. Task BEX-T17. |
| BEX-F33 | MAJOR | `import_files/router.py:185-256` | The export routes build rows in the router (business formatting in `router.py`). `f"{f.progress_percent:.0f}%"` raises on a NULL legacy value (500 for the whole export). Exports need only `import_files.view`, not `reports.export`. | Move the row building to `service.py`; `None`-safe formatting; `reports.export`. Task BEX-T15. |
| BEX-F34 | MINOR | `import_files/service.py:497-532` | Reopen does not mark the active closure record "Reopened" and writes no audit entry. Still open from the 08-10 shared need (`review-shared-needs.md:188`). | As described there. Task BEX-T11. |
| BEX-F35 | MINOR | `auth/security.py:72-75` | Every non-PBKDF2 hash is checked as legacy SHA-256 with a fixed salt, forever. | Count remaining legacy hashes; after the sunset date (Q6), refuse legacy and force a reset. Task BEX-T08. |
| BEX-F36 | MINOR | `auth/security.py:186-187`, `204-205` | `init_from_db` and `revoke` swallow every exception (`except: pass` / rollback without log). | `logger.exception`; revoke failure → 500 so the client knows logout did not persist. Task BEX-T08. |
| BEX-F37 | MINOR | `auth/service.py:220-233` | PATCH `role` with an unknown string stores it as free text and leaves `role_id` on the old role (permissions keep coming from the old role). | 400 for an unknown role code; always set `role_id` with `role`. Task BEX-T08. |
| BEX-F38 | MINOR | `auth/permissions.py:37-55`; `users/model.py` (Role) | The permission cache listens to User / UserPermission / RolePermission but not `Role` (deactivating a role keeps its users' permissions for up to 60 s). | Add the `Role` listener. Task BEX-T08. |
| BEX-F39 | MINOR | `main.py:495-533`, `434-463` | Version check invents values when `version.json` is missing (`1.0.198`, build 199, 198.04 MB, a GitHub URL). `/health` is public and exposes the DB size and table count. | Return `null` and `check_status="unknown"`; drop size/table count from the public health. Task BEX-T17. |
| BEX-F40 | MINOR | `suppliers/validators.py:21`; `import_companies/validators.py:22`; `external_service_providers/validators.py:22` | Each create loads the whole table to run fuzzy duplicate matching (O(n) per row, O(n²) in Excel import). | Pre-filter with normalised-name index / `LIKE` prefix, then fuzzy on the candidates. Task BEX-T09. |
| BEX-F41 | MINOR | `lifecycle_board/model.py:9-22` | `shipment_stage_activity` has no unique `(import_file_code, step_code)` and no FK: the get-then-insert in `save_or_update_activity` can create duplicates under concurrent advances. | Alembic: dedupe + unique index. Task BEX-T16. |
| BEX-F42 | MINOR | `system_observability/router.py:68-74` | `recent-traffic?limit=` has no bound. | `Query(50, ge=1, le=500)`. Task BEX-T14. |

---

## 3. Tasks

Conventions for every task:
- Coded errors are `HTTPException(status_code, detail={"code": ..., "message": <Arabic>, ...params})`, registered in the
  same change in `modules/common/system_messages.py` and `docs/system_message_codes.json` (else
  `tests/unit/test_review_wave_codes.py` fails). Flutter catalog entries are listed in section 4.
- Tests use a scratch `DATABASE_PATH` (see `tests/conftest.py`) and read results from `--junitxml`.
- Acting user = `current_user` from the auth dependency, never a body field or `X-User-*` header.

### BEX-T01: Lifecycle board: permissions, acting user, file and status guards
- **Severity**: BLOCKER (BEX-F01, F10, F19)
- **Depends on**: none
- **Schema/migration needed**: no
- **API contract change**: yes.
  - All GET routes need `lifecycle_board.view`; POST/PUT need `lifecycle_board.advance` (PUT step-configs: see BEX-T02).
  - `POST /stages/sync` and `/stages/advance`: `assigned_user` in the body is ignored. Now 404 `LC_FILE_NOT_FOUND`,
    422 `LC_FILE_REF_REQUIRED`, 409 `LC_FILE_NOT_ACTIVE` (Closed / Archived / On Hold / inactive), 409 `LC_STEP_NOT_ACTIVE`
    (completed step not In-Progress / pending-reference on that file), 409 `LC_CLOSURE_STEP_RESERVED` (STEP_21 from HTTP).
  - `auto_complete_prior` from HTTP is honoured only for ADMIN (else forced `False`).
  - Flutter: `frontend/lib/features/lifecycle_board/providers/lifecycle_board_provider.dart`,
    `step_config_provider.dart`, `frontend/lib/core/services/ai_agent_tool_executor.dart`.
- **Files to change**: `modules/lifecycle_board/router.py`, `modules/lifecycle_board/service.py`,
  `modules/lifecycle_board/schemas.py`, `modules/common/system_messages.py` (+ `docs/system_message_codes.json`),
  new `tests/unit/test_lifecycle_board_guards.py`
- **Steps**:
  1. Router: replace the per-route `get_current_user` with `Depends(require_permission("lifecycle_board.view"))` on the 6 GET
     routes and `require_permission("lifecycle_board.advance")` on `POST /stages/advance`, `/stages/sync`, `/stages/skip`,
     `/stages/set-active`, `/stages/register-pending-reference`. Keep the router-level `get_current_user`.
  2. New service entry `http_advance_step_service(db, *, completed_step_code, import_file_code, import_file_id,
     target_step_codes, auto_complete_prior, action_data, notes, actor: User)` used by both HTTP routes. It:
     a. resolves the file (`import_file_id` first, else exact `import_file_code`); none given → 422; not found or
        `is_active=False` → 404;
     b. `file.status in ("Closed", "Archived", "On Hold")` → 409 `LC_FILE_NOT_ACTIVE` (`status` param);
     c. `completed_step_code == "STEP_21"` → 409 `LC_CLOSURE_STEP_RESERVED` (closure goes through `file_closure`);
     d. the activity `(code, completed_step_code)` must exist with status `In-Progress` or
        `"Reference recorded – pending full documentation"`, else 409 `LC_STEP_NOT_ACTIVE`;
     e. `auto_complete_prior = auto_complete_prior and is_admin_user(actor)`;
     f. calls `advance_lifecycle_step_service(..., assigned_user=actor.username, source_module="Lifecycle Operations Board")`.
     Internal callers (`sync_*_lifecycle_stage`, `transition_stage_activity_service`) keep calling
     `advance_lifecycle_step_service` directly (unchanged behaviour).
  3. In `advance_lifecycle_step_service` replace `raise ValueError(...)` (`:331`) with the 422 coded error, and return 404
     when `file_rec` is None (no orphan rows).
  4. `set_multi_active_stages_service`, `register_pending_reference_service`, `skip_step_service`: resolve the file first
     (404 / 409 as in 2a-2b).
  5. `LifecycleSyncRequest.assigned_user`: keep the field (old clients) but ignore it; add `json_schema_extra` deprecation note.
- **Acceptance criteria**:
  - AUDITOR_VIEWER: `POST /stages/sync` → 403; `GET /summary` → 200.
  - LOGISTICS_OPERATOR on a file whose only In-Progress step is STEP_05: sync STEP_21 → 409 `LC_CLOSURE_STEP_RESERVED`;
    sync STEP_10 → 409 `LC_STEP_NOT_ACTIVE`; sync STEP_05 → 200, and STEP_01..04 are not touched when they were not
    In-Progress.
  - Unknown code `IMP-2099-9999` → 404 and `SELECT count(*) FROM shipment_stage_activity WHERE import_file_code='IMP-2099-9999'` = 0.
  - The completed activity's `assigned_user` = the token's username even if the body sends `"assigned_user":"ceo"`.
- **Tests to add**: `tests/unit/test_lifecycle_board_guards.py`: the four acceptance cases with TestClient + seeded users
  (AUDITOR_VIEWER, LOGISTICS_OPERATOR, ADMIN); ADMIN with `auto_complete_prior=true` on STEP_07 completes STEP_01..06.
- **Out of scope**: transactions (BEX-T02); dual approval (BEX-T02 / Q3).

### BEX-T02: Lifecycle board: one transaction per use case, skip policy, config authorisation
- **Severity**: MAJOR (BEX-F17, F18); still open from CL-13
- **Depends on**: BEX-T01
- **Schema/migration needed**: no
- **API contract change**: yes. `POST /stages/skip` on a `dual_approval` step → 409 `LC_SKIP_DUAL_APPROVAL_REQUIRED` for
  non-ADMIN (until Q3). `PUT /step-configs/{code}` needs `users.manage` (or the new code chosen in Q3) instead of a role name;
  `approver_roles` must be existing `roles.role_code` values (422 `LC_APPROVER_ROLE_UNKNOWN`). Flutter: `step_config_provider.dart`.
- **Files to change**: `modules/lifecycle_board/repository.py`, `modules/lifecycle_board/service.py`,
  `modules/lifecycle_board/router.py`, `modules/common/system_messages.py`, new `tests/unit/test_lifecycle_board_transactions.py`
- **Steps**:
  1. Repository: `save_or_update_activity`, `save_step_config`, `save_step_config_audit_log`, `save_pending_reference` call
     `db.flush()` instead of `commit()`/`refresh()`.
  2. Service: remove the commits at `:375`, `:813`, `:880`, `:953`, `:1183`; keep exactly one `db.commit()` at the end of
     each public service (`advance_lifecycle_step_service`, `skip_step_service`, `set_multi_active_stages_service`,
     `register_pending_reference_service`, `update_step_config_service`, `hold_*`, `resume_*`,
     `initialize_file_lifecycle_service`). Add a `commit: bool = True` keyword to `advance_lifecycle_step_service` so
     other modules can pass `commit=False` later (CL-13 callers are not changed here).
  3. Audit writes (`:1064-1084`, `:1196-1210`): add the `AuditLog` to the same transaction (no inner try). If you keep a
     best-effort audit, do it **after** the commit, in its own try with `logger.exception` and `db.rollback()`.
  4. Skip: `if skip_policy == "dual_approval" and not is_admin_user(actor)` → 409 `LC_SKIP_DUAL_APPROVAL_REQUIRED`
     (pass `actor` from the router instead of `current_user_role`).
  5. Step-config update: router uses `require_permission("users.manage")`; service drops the role-string check; validate
     each `approver_roles` entry with `db.query(Role).filter(Role.role_code == code.upper())`.
- **Acceptance criteria**: a forced exception after the 3rd prior-step update (monkeypatch `_close_step_tasks` to raise)
  leaves **no** activity changed (rollback). Skip on a `dual_approval` step by GENERAL_MANAGER → 409.
- **Tests to add**: `tests/unit/test_lifecycle_board_transactions.py`: the rollback case (count Completed activities
  before / after = equal); dual approval 409; `approver_roles=["NOPE"]` → 422.
- **Out of scope**: a real two-signature skip workflow (needs a table, Q3).

### BEX-T03: Lifecycle board: no invented data, bounded live tracking
- **Severity**: MAJOR (BEX-F20, F21)
- **Depends on**: none
- **Schema/migration needed**: no
- **API contract change**: yes (types only). `ShipmentStageCard` / `LiveLogisticsTrackingItem`: `shipment_mode`,
  `incoterm_code`, `priority`, `estimated_cost`, `estimated_cost_currency`, `carrier_name`, `vessel_name`, `pol_name`,
  `pod_name` become `Optional[...] = None` (no default text). New `demurrage_risk_level` value `"Unknown"` when free days
  are not recorded. Flutter: `lifecycle_board_provider.dart`, `live_polling_provider.dart` and their models.
- **Files to change**: `modules/lifecycle_board/service.py`, `modules/lifecycle_board/schemas.py`, `modules/common/enum_codes.py`
  (add `UNKNOWN` to the risk-level set if one exists), new `tests/unit/test_lifecycle_live_tracking.py`
- **Steps**:
  1. `get_board_summary_service` (`:217-224`): pass the raw values (`file_rec.shipment_mode`, ...) with no `or "..."`.
  2. `get_live_logistics_tracking_service`: remove the literals at `:1417-1420`; `free_days_total = f.target_free_days or
     (booking.free_demurrage_days if booking else None)`; when it is `None` and no demurrage record exists →
     `risk_level="Unknown"`, `free_days_remaining=None`, not counted in `high_risk_demurrage_count`.
  3. Pre-fetch only rows of active files: `active_ids = [f.import_file_id for f in active_files]`, then
     `ShipmentBooking.import_file_id.in_(active_ids)` (same for cargo and customs).
  4. Delete `_ensure_initial_stages` and its call at `:167` (a GET must not write).
- **Acceptance criteria**: an active file with no booking, no demurrage record and `target_free_days=NULL` → item with
  `carrier_name=None`, `vessel_name=None`, `pod_name=None` (when the file has none), `demurrage_risk_level="Unknown"`.
  With 3 files (1 active) and 3 bookings, the bookings query has an `IN (<1 id>)` filter (assert via `sqlalchemy` event
  counter or by checking the result only uses the active one).
- **Tests to add**: `tests/unit/test_lifecycle_live_tracking.py` with the case above; and `GET /summary` on an empty
  activity table creates 0 rows.
- **Out of scope**: rewriting the readiness percentage rules.

### BEX-T04: Master data permissions (A): RBAC grant, currencies, incoterms
- **Severity**: BLOCKER (BEX-F02 part, F27 actor part, F28)
- **Depends on**: Q1 answered (which roles get `master_data.edit`)
- **Schema/migration needed**: no
- **API contract change**: yes. GET `/currencies*`, `/incoterms*`, `/cost-items*`, `/incoterm-responsibilities*` need
  `master_data.view` (every seeded role has it). Writes need `master_data.edit` (403 otherwise). `POST /currencies/convert`
  and `/gain-loss` stay on `master_data.view`. `ExchangeRateCreate.created_by` is ignored (token user is stored).
  `DELETE /incoterm-responsibilities/{id}` becomes a soft delete (same response shape, `is_active=false`). Flutter:
  `frontend/lib/features/currencies/providers/currencies_provider.dart`, incoterms providers.
- **Files to change**: `modules/auth/seed_rbac.py`, `modules/currencies/router.py`, `modules/incoterms/router.py`,
  `modules/incoterms/repository.py`, new `tests/unit/test_master_data_permissions.py`
- **Steps**:
  1. `seed_rbac.py`: add `"master_data.edit"` to the roles chosen in Q1 in `ROLES_CONFIG` (new DBs), and an
     entry in the one-time grant mechanism (`ONE_TIME_ROLE_GRANTS`, read `:251-325` for its format) so existing DBs get it once.
  2. Currencies router: `master_data.view` on GET / convert / gain-loss; `master_data.edit` on POST / PUT / DELETE /
     restore / rates; pass `current_user.username` to `add_exchange_rate` and store it as `created_by` (ignore the body value).
  3. Incoterms router: same split for the 23 routes (the trailing-slash duplicates too).
  4. `delete_responsibility`: set `is_active=False` (the column exists? if not, return 409 when the responsibility is the
     last one of its incoterm; check `incoterms/model.py:80-121` first and pick the soft path when `is_active` exists).
- **Acceptance criteria**: AUDITOR_VIEWER: `PUT /currencies/1` → 403, `GET /currencies` → 200. Role from Q1:
  `POST /currencies/rates` → 201 with `created_by` = its username although the body says `"created_by":"x"`.
- **Tests to add**: `tests/unit/test_master_data_permissions.py`: parametrised over (method, path) of both routers × roles
  (viewer 403 on every write, 200 on reads).
- **Out of scope**: the other six master-data routers (BEX-T05, T06).

### BEX-T05: Master data permissions (B): projects, transport locations, expense catalog
- **Severity**: BLOCKER (BEX-F02 part)
- **Depends on**: BEX-T04 (grant)
- **Schema/migration needed**: no (audit columns are BEX-T16)
- **API contract change**: yes, 403 for callers without `master_data.view` / `master_data.edit` (same split as BEX-T04).
  Flutter: `frontend/lib/features/projects/...`, `transport_locations_provider.dart`, expense catalog provider.
- **Files to change**: `modules/projects/router.py`, `modules/transport_locations/router.py`,
  `modules/expense_catalog/router.py`, `tests/unit/test_master_data_permissions.py`
- **Steps**: add the dependencies route by route (GET / export / template → view; POST / PUT / DELETE / restore /
  import-excel / patterns → edit). Keep the cache keys unchanged.
- **Acceptance criteria / Tests**: extend the parametrised test of BEX-T04 with these three routers.
- **Out of scope**: Excel import rewrite (BEX-T09).

### BEX-T06: Master data permissions (C): suppliers, importing companies, partners
- **Severity**: BLOCKER (BEX-F02 part)
- **Depends on**: BEX-T04 (grant)
- **Schema/migration needed**: no
- **API contract change**: yes, as BEX-T05. Flutter: `import_companies_provider.dart`, suppliers / partners providers,
  `frontend/lib/core/widgets/universal_entity_extractor_dialog.dart` (creates suppliers / companies from extraction: the
  user needs `master_data.edit` or the dialog must show the 403 SnackBar).
- **Files to change**: `modules/suppliers/router.py`, `modules/import_companies/router.py`,
  `modules/external_service_providers/router.py`, `tests/unit/test_master_data_permissions.py`
- **Steps**: as BEX-T05; also pass `current_user.username` into the create / update services where the models have
  `created_by` / `updated_by` (suppliers `model.py:222-230`, companies `model.py:126-133`).
- **Acceptance criteria**: a supplier created by `op1` has `created_by="op1"`; viewer gets 403 on every write.
- **Tests to add**: extend the parametrised test; one assertion on `created_by`.
- **Out of scope**: statement-of-account / scorecard logic.

### BEX-T07: No fabricated exchange rates
- **Severity**: BLOCKER (BEX-F03; still open from BE67-F04 shared need)
- **Depends on**: BE67-T03 (customs engine treats a missing rate as 409) should land first or together; otherwise
  `customs_tariff` estimate routes start returning this 409 instead of a wrong number (acceptable, but coordinate).
- **Schema/migration needed**: no
- **API contract change**: yes. `POST /currencies/convert` with no registered rate → 409 `CURRENCY_RATE_MISSING`
  `{currency, rate_type, as_of_date}` (was 200 with an invented rate); unregistered code → 404 (unchanged message, now coded
  `CURRENCY_NOT_FOUND`). Flutter: `currencies_provider.dart:114` (show the message, offer "add rate").
- **Files to change**: `modules/currencies/service.py`, `modules/common/system_messages.py`
  (+ `docs/system_message_codes.json`), new `tests/unit/test_currency_rates.py`
- **Steps**:
  1. Delete `fallback_rates` (`:170`) and both branches that use it (`:173-178`, `:185-189`).
  2. No currency row → `HTTPException(404, {"code": "CURRENCY_NOT_FOUND", ...})`. No rate row →
     `HTTPException(409, {"code": "CURRENCY_RATE_MISSING", ...})`. Do not write misses to `_RATE_CACHE`.
  3. Keep the return tuple `(rate, effective_date, rate_id)` so `customs_consultation/service.py:876` and
     `financial_settlement/service.py:365` (which already catch 404 and check `rate_id`) keep working; they now also get the
     409 for "no rate": make sure both re-map it to their own coded 409 (they currently re-raise non-404 errors: acceptable,
     the code differs; note it in the PR).
- **Acceptance criteria / numeric example**:
  - Currency USD registered, no rate: `POST /currencies/convert {"amount":100,"from_currency_code":"USD"}` → 409
    `CURRENCY_RATE_MISSING` (today: 200, `converted_amount=4850.00`).
  - Add rate USD commercial 50.00 / customs 49.00 effective 2026-10-01: convert 100 USD (commercial, as of 2026-10-05) →
    `converted_amount=5000.00`, `applied_rate=50.0`, `exchange_rate_id=<new id>`; with `rate_type="customs"` → `4900.00`.
  - Convert 100 USD to EUR with EUR commercial 52.80: `converted_amount = 100*50.00/52.80 = 94.70`, `applied_rate=0.947`.
- **Tests to add**: `tests/unit/test_currency_rates.py` with the three cases; plus "miss is not cached": first call 409,
  add the rate, second call 200 within the same process.
- **Out of scope**: the customs engine callers (BE67-T03).

### BEX-T08: Auth hardening: revocation at startup, token version, limiter, small fixes
- **Severity**: BLOCKER (BEX-F04) + MAJOR (F14, F15) + MINOR (F35, F36, F37, F38)
- **Depends on**: none
- **Schema/migration needed**: yes: `users.token_version INTEGER NOT NULL server_default '0'` (Alembic migration in
  `alembic/versions/`, plus `server_default=text("0")` on the model).
- **API contract change**: yes, behavioural. After a password change / admin reset / deactivate / role change, the
  user's older tokens get 401 (the change-password response must carry a new token, see step 4). `/auth/refresh` revokes the
  token it received. `TokenResponse` unchanged. Flutter: `frontend/lib/core/network/api_client.dart` (refresh flow),
  `frontend/lib/features/auth/providers/auth_provider.dart` (store the new token after change-password).
- **Files to change**: `modules/auth/security.py`, `modules/auth/permissions.py`, `modules/auth/service.py`,
  `modules/auth/router.py`, `modules/auth/rate_limiter.py` (+ `modules/users/model.py` and the migration: 7 files; split
  into T08a = revocation + limiter + minor, T08b = token_version if needed)
- **Steps**:
  1. `TokenRevocationManager`: `ensure_loaded()` that runs `init_from_db` with its own `SessionLocal()` the first time
     `is_revoked` is called; log failures (`logger.exception`) and retry on the next call (do not mark initialised).
     `revoke`: on DB failure log and re-raise (logout returns 500, not a false success).
  2. `create_access_token`: add `"tv": user.token_version` (from `generate_user_token`). `resolve_user` and `/refresh`:
     `payload.get("tv", 0) != (user.token_version or 0)` → 401.
  3. Bump `token_version += 1` in `update_user` when `password`, `role` or `role_id` changes, in `toggle_user_status`,
     `change_own_password`, `update_user_permissions` (role change only).
  4. `change_my_password` returns `TokenResponse` (new token) **or** keep `UserResponse` and add `access_token` field; pick
     the additive option: new optional field `access_token` on a new `ChangeOwnPasswordResponse(UserResponse)`.
  5. `/refresh`: after issuing the new token, `token_revocation_manager.revoke(old_token, ...)`.
  6. Rate limiter: `_get_client_ip` ignores `X-Forwarded-For` unless `settings.TRUSTED_PROXY_IPS` (new, default empty)
     contains `request.client.host`. Add a second key `login:user:<lowercased username>` in the login route. Prune keys whose
     last failure is older than `window_seconds` on each `check_key`.
  7. `update_user` with a `role` string that matches no `Role` → 400 `AUTH_ROLE_UNKNOWN`; always set `role_id` and `role`
     together.
  8. Add `@event.listens_for(Role, "after_update")` → `invalidate_permission_cache()`.
  9. Legacy SHA-256: log a WARNING with the username when the legacy branch verifies (migration progress); behaviour
     unchanged until Q6.
- **Acceptance criteria**: logout token T; simulate restart (new `TokenRevocationManager()` instance, empty set); `GET
  /auth/me` with T → 401. Admin resets user U's password → U's old token → 401. 6 failed logins with 6 different
  `X-Forwarded-For` values from the same client → the 6th gets 429. `/refresh` with T1 → T2; T1 then → 401.
- **Tests to add**: `tests/unit/test_auth_revocation.py` (restart case, refresh revokes old), `tests/unit/test_auth_token_version.py`
  (reset / toggle / role change invalidate), `tests/unit/test_login_rate_limiter.py` (XFF spoofing, per-username key).
- **Out of scope**: moving to a standard JWT library.

### BEX-T09: Master-data Excel imports: no invented values, one transaction, permission, limits
- **Severity**: BLOCKER (BEX-F07) + MAJOR (F25) + MINOR (F40)
- **Depends on**: BEX-T05, BEX-T06 (permissions on the routes)
- **Schema/migration needed**: no
- **API contract change**: yes. `POST /{suppliers|import-companies|projects|transport-locations|external-service-providers}/import-excel`:
  rows missing a required value are reported in `errors` and **nothing** is inserted when any row fails
  (`{"message", "imported_count": 0, "errors": [...]}`); 415 `MD_IMPORT_FILE_TYPE` for non-`.xlsx`; 413 `MD_IMPORT_TOO_LARGE`
  above 5 MB. Required columns: companies `importer_id_expiry`, `vat_id_expiry`, `registration_expiry`, `country`;
  projects `company_id`, `currency` when `budget` > 0; suppliers `foreign_exporter_country_code`; locations
  `location_type`, `country`. Flutter: `frontend/lib/core/helpers/master_data_action_helper.dart`,
  `frontend/lib/core/widgets/master_data_toolbar.dart` (show the error list), Excel templates (mark required columns).
- **Files to change** (split per 2 entities if needed): `modules/import_companies/router.py` + `service.py`,
  `modules/projects/router.py` + `service.py`, `modules/suppliers/router.py` + `service.py`, `modules/transport_locations/router.py`
  + `service.py`, `utils/export_import_helper.py`, tests. Recommended split: T09a companies + projects, T09b suppliers +
  locations + partners.
- **Steps**:
  1. Router: `def` (not `async def`), read with a 5 MB cap (`file.file.read(MAX + 1)`, reject when longer), check the
     `.xlsx` suffix and the `PK` zip header; call `service.import_rows_from_excel(db, rows, actor)`.
  2. Service: build every schema first (collect `errors` with row numbers; never fill a default for a required business
     field: no `date(2027, 12, 31)`, no `company_id=1`, no `'China'`, `'CN'`, `'USD'`, `'Alexandria'`, `'Sea Port'`,
     `'Main Industrial Zone'`, `'Manufacturer'`, `'Factory Registration'`, `'Cairo, Egypt'`, `'Egypt'`); if `errors` → return
     without writing; else insert all and commit once (repositories flush).
  3. Error strings: Arabic message per row, never `str(e)` of an unexpected exception (log it, return "خطأ غير متوقع في السطر N").
  4. Duplicate detection: replace the full-table loads (`suppliers/validators.py:21`, `import_companies/validators.py:22`,
     `external_service_providers/validators.py:22`) with a normalised-name pre-filter (`func.lower(name).like(first 4 chars + '%')`)
     before the fuzzy check; inside the import, also check duplicates among the file's own rows.
- **Acceptance criteria**: companies file with 2 rows, row 3 missing `vat_id_expiry` → response `imported_count=0`,
  `errors=["Row 3: ..."]`, `import_companies` count unchanged. A valid 2-row file → both rows, one commit.
  Projects row without `company_id` → error (today: company 1).
- **Tests to add**: `tests/unit/test_master_data_excel_import.py`: build xlsx in memory with openpyxl; the three cases;
  a `.csv` upload → 415; 6 MB body → 413.
- **Out of scope**: the customs tariff upload (BE67-T09); PO import.

### BEX-T10: Money aggregates in one currency: project commitments, import-file master report
- **Severity**: BLOCKER (BEX-F05) + CRITICAL (F06) + MAJOR (F29)
- **Depends on**: BEX-T07 (rate lookup raises instead of inventing)
- **Schema/migration needed**: no
- **API contract change**: yes.
  - `ProjectResponse` / `GET /projects/{id}/financial-commitments`: `total_committed_usd`, `remaining_budget_usd`,
    `budget_utilization_percent` become `Optional[float]` (None when a PO currency has no rate); new
    `missing_rate_currencies: List[str] = []`; new `committed_by_currency: Dict[str, float]`.
    Flutter: `frontend/lib/features/projects/models/project_model.dart` (+ the projects screen).
  - `ImportMasterReportSummary`: `total_estimated_cost: Optional[float]` (None when more than one currency), new
    `estimated_cost_by_currency: Dict[str, float]`. Flutter: `frontend/lib/features/import_files/models/import_file_model.dart`,
    `import_files_provider.dart`.
- **Files to change**: `modules/projects/service.py`, `modules/projects/schemas.py`, `modules/import_files/service.py`,
  `modules/import_files/schemas.py`, new `tests/unit/test_money_aggregates.py`
- **Steps**:
  1. Projects: one grouped query `SELECT project_id, currency_id, SUM(total_amount_fob) ... WHERE is_active GROUP BY 1,2`
     for all projects of the page (fixes the N+1), and one company-name query for all company ids.
  2. USD conversion per currency: `amount_usd = amount * rate_to_egp(cur) / rate_to_egp("USD")`, commercial rate, as of today,
     using `CurrencyService._get_rate_to_egp`; catch the 404/409 of BEX-T07 → add the code to `missing_rate_currencies`
     and set the three totals to `None`. Round the totals to 2 decimals at the end only.
  3. Master report: group `estimated_cost` by `estimated_cost_currency` (treat `None` cost as 0, `None` currency as key
     `"UNKNOWN"`); `total_estimated_cost = sum` only if exactly one key.
- **Acceptance criteria / numeric example**:
  - Project budget USD 100,000. PO1 USD 10,000; PO2 EUR 10,000; rates commercial USD 48.50, EUR 52.80 (EGP per unit).
    EUR→USD = 10,000 × 52.80 / 48.50 = 10,886.597… → `total_committed_usd = 20,886.60`, `remaining_budget_usd = 79,113.40`,
    `budget_utilization_percent = 20.9`, `committed_by_currency = {"USD": 10000.0, "EUR": 10000.0}`.
  - Same project with no EUR rate → `total_committed_usd=None`, `missing_rate_currencies=["EUR"]`.
  - Master report with files USD 1,000, EUR 2,000, EGP 500 → `estimated_cost_by_currency={"USD":1000,"EUR":2000,"EGP":500}`,
    `total_estimated_cost=None`; with only USD 1,000 + USD 500 → `total_estimated_cost=1500.0`.
- **Tests to add**: `tests/unit/test_money_aggregates.py` with the three numeric cases; a query-count assertion that
  `GET /projects` with 10 projects runs a constant number of queries (≤ 4).
- **Out of scope**: budget currency other than USD (Q7).

### BEX-T11: Import files: tracking fields, exact lookup, status workflow, legacy-tolerant response
- **Severity**: CRITICAL (BEX-F08, F09) + MAJOR (F13, F22 partial, F23, F24) + MINOR (F34)
- **Depends on**: none (Q4 for the defaults)
- **Schema/migration needed**: no
- **API contract change**: yes.
  - `ImportFileUpdate.status` removed (ignored if sent; status changes only via close / reopen / hold / resume / file_closure).
  - `GET /import-files/{id_or_code}`: a numeric value is looked up only as id (404 if not found); a non-numeric value only by
    exact `import_file_code` or exact `custom_file_number`.
  - Reopen sets `status="In Progress"` (was "Active").
  - Close / hold on a Closed or Archived file → 409 `IF_STATUS_TRANSITION_INVALID {from, to}`; resume on a non-On-Hold file → 409.
  - Response may contain `None` for legacy NULLs (`estimated_cost`, `progress_percent` are already non-null columns; the
    `Optional` change is on fields inherited from the base).
  - Flutter: `frontend/lib/features/import_files/providers/import_files_provider.dart`, `import_file_model.dart`,
    `ai_agent_tool_executor.dart` (uses `/import-files/{code}`).
- **Files to change**: `modules/import_files/service.py`, `modules/import_files/repository.py`,
  `modules/import_files/schemas.py`, `modules/import_files/validators.py`, `modules/import_files/router.py`
  (+ new `tests/unit/test_import_files_workflow.py`)
- **Steps**:
  1. `update_import_file_service`: delete the formula block (`:389-403`); never write `progress_percent`, `current_module`,
     `current_stage`, `next_action*`, `current_step_code`, `current_phase_id`, `current_stage_code`. Set
     `updated_by=actor.username` (router passes `current_user`).
  2. `get_import_file_by_code`: `or_(ImportFile.import_file_code == term, ImportFile.custom_file_number == term)`; add
     `include_inactive: bool = False`. Router: `if import_file_id.isdigit(): by id only`.
  3. Clone: `exists = db.query(ImportFile.import_file_id).filter(ImportFile.import_file_code == target_code).first()`
     (active and inactive); same for `custom_file_number`; on `IntegrityError` rollback + 409. Call
     `initialize_file_lifecycle_service(db, new_code, "STEP_01")` in the same transaction.
  4. `validators.validate_status_transition(current, target)` with allowed: Open→In Progress/On Hold/Closed; In
     Progress→On Hold/Closed; On Hold→In Progress (resume)/Closed; Closed→In Progress (reopen); Archived→none. Use it in
     close / reopen / hold / resume.
  5. Reopen: mark the active `ImportFileClosureRecord` (if any) `status="Reopened"` and write an `AuditLog`
     (`action="REOPEN"`, `performed_by=actor.username`) in the same commit (08-10 shared need).
  6. `ImportFileResponse`: decorate with `@read_model` and inherit `LegacyRowTolerantModel` (see `common/legacy_rows.py`
     docstring); money fields `Optional[float]`.
  7. Replace the three `except Exception: pass` (`:351`, `:357`, `:410`, `:425`) with `logger.exception(...)`; ACID
     propagation: set all assessments then one commit, then call `sync_regulatory_tasks_and_alerts` per assessment.
- **Acceptance criteria**:
  - File at `progress_percent=88.0`, `current_step_code="STEP_19"`: `PUT {"notes":"x"}` → progress stays 88.0, step stays STEP_19.
  - Files id 12 (inactive) and custom number "6701120012": `GET /import-files/12` → 404 (today: returns the other file).
  - Clone to a code used by an inactive file → 409 (today: 500).
  - `PUT {"status":"Closed"}` leaves status unchanged; reopen → "In Progress".
  - A legacy row with `company_name="X"` (1 char) does not break `GET /import-files`.
- **Tests to add**: `tests/unit/test_import_files_workflow.py` with the five cases.
- **Out of scope**: removing the invented create defaults (needs Q4 and Flutter form changes, then a follow-up task).

### BEX-T12: Collision-safe business codes (IMP, SUP, PRJ, TSK)
- **Severity**: CRITICAL (BEX-F11)
- **Depends on**: none
- **Schema/migration needed**: no (unique indexes exist on `import_file_code`; verify `supplier_code`, `project_code`,
  `task_code` are unique in their models; if one is not, add an Alembic unique index after a duplicate check, Q8)
- **API contract change**: no (same formats: `IMP-YYYY-NNNN`, `SUP-NNNNNN`, `PRJ-YYYY-NNN`, `TSK-YYYY-NNNN`)
- **Files to change**: `modules/import_files/repository.py`, `modules/suppliers/service.py`, `modules/projects/repository.py`,
  `modules/smart_tasks/repository.py`, new `tests/unit/test_business_code_generators.py`
- **Steps**:
  1. IMP: `next_yearly_code(db, ImportFile.import_file_code, "IMP", pad=4)`; PRJ: `next_yearly_code(db, Project.project_code,
     "PRJ", pad=3)`; TSK: `next_yearly_code(db, SmartTask.task_code, "TSK", pad=4)`; SUP: max numeric suffix of
     `supplier_code LIKE 'SUP-%'` + 1 (add a `next_global_code(db, column, prefix, pad)` sibling in
     `modules/common/sequence_generator.py` with the same digits-only GLOB filter).
  2. Callers: wrap the insert in a loop of max 3 attempts: on `IntegrityError` → `db.rollback()`, regenerate, retry.
- **Acceptance criteria**: existing codes `IMP-2026-0001`, `IMP-2026-0002`, `IMP-2026-0007` (clone) and one soft-deleted
  `IMP-2026-0003` → next is `IMP-2026-0008` (today `0005`, then a collision at `0007`). Projects `PRJ-2025-001..010` and none
  in 2026 → `PRJ-2026-001` (today `PRJ-2026-011`).
- **Tests to add**: `tests/unit/test_business_code_generators.py` with these two cases plus SUP after a gap.
- **Out of scope**: renumbering existing rows.

### BEX-T13: Shared list pagination helper + harden `/import-files/paginated`
- **Severity**: MAJOR (BEX-F12, F31)
- **Depends on**: none
- **Schema/migration needed**: no
- **API contract change**: additive (contract in section 4). `/import-files/paginated` gains `sort` and `q` (alias of
  `search`), rejects `page<1` / `page_size` outside 1..500 with 422, and sets `X-Total-Count`. Same body shape. Flutter:
  `import_files_provider.dart` (no change needed; optional `sort`).
- **Files to change**: new `modules/common/pagination.py`, `modules/import_files/router.py`,
  `modules/import_files/repository.py`, `modules/common/system_messages.py`, new `tests/unit/test_pagination_contract.py`
- **Steps**:
  1. `modules/common/pagination.py`:
     - `class PageParams` (FastAPI dependency): `page: int = Query(1, ge=1)`, `page_size: int = Query(50, ge=1, le=500)`,
       `sort: Optional[str] = Query(None, max_length=200)`, `q: Optional[str] = Query(None, max_length=100)`.
     - `class Page(BaseModel, Generic[T])`: `items: List[T]`, `total: int`, `page: int`, `page_size: int`, `total_pages: int`.
     - `def apply_sort(query, sort: Optional[str], allowed: Dict[str, Column], default: List[ColumnElement], pk: Column)`:
       parse `"-created_at,code"`; unknown field → `HTTPException(422, {"code":"PAGE_SORT_FIELD_INVALID","field":...,
       "allowed":[...]})`; always append `pk.desc()` as tie-breaker.
     - `def like_term(q) -> Optional[str]`: strip, escape `%`, `_`, `\` and wrap in `%...%` (use `escape="\\"`).
     - `def paginate(query, params, *, sort_map, default_sort, pk, response: Response) -> dict`: `total =
       query.order_by(None).count()`, items with offset/limit, `total_pages = max(1, ceil(total / page_size))`, sets
       `response.headers["X-Total-Count"] = str(total)`. A page past the end returns `items=[]` with the real total.
  2. Import files: router uses `PageParams`; `search` stays as an alias (`q or search`); sort map:
     `{"import_file_code", "created_at", "required_eta", "file_opening_date", "status", "progress_percent", "company_name"}`.
  3. Register `PAGE_SORT_FIELD_INVALID` in the message catalogs.
- **Acceptance criteria**: `page_size=0` → 422 (today 500); `page_size=-1` → 422; `page=3&page_size=2` on 5 rows →
  `items=[1 row]`, `total=5`, `total_pages=3`, header `X-Total-Count: 5`; `sort=-progress_percent` orders descending,
  ties by id desc; `sort=hacker` → 422 `PAGE_SORT_FIELD_INVALID`; `q=50%` matches a literal "50%".
- **Tests to add**: `tests/unit/test_pagination_contract.py` with these cases on `/import-files/paginated`.
- **Out of scope**: the other endpoints (BEX-T14).

### BEX-T14: Paginated endpoints for the largest tables + remaining route permissions
- **Severity**: MAJOR (BEX-F30, F31, F42)
- **Depends on**: BEX-T13
- **Schema/migration needed**: no (check indexes on the sort columns; add only via Alembic if missing)
- **API contract change**: additive: new `GET .../paginated` routes (section 4 list, wave 1). Permission changes on
  smart_tasks / notifications / experience_guide / smart_email_listener / observability per the matrix below (403 for
  callers without the code). Flutter: per endpoint, see section 4.
- **Files to change** (do it in sub-tasks of ≤ 5 files, one per module): wave 1a `modules/smart_tasks/{router,repository,service}.py`
  + test; wave 1b `modules/audit_logs/{router,service}.py` + `modules/notifications/{router,repository}.py` + test;
  wave 1c `modules/transport_locations/{router,repository,service}.py` + test; wave 1d `modules/suppliers`,
  `modules/import_companies`, `modules/external_service_providers` (router + repository) + test.
- **Steps** (per endpoint): add `GET /<resource>/paginated` with `PageParams` + the resource's existing filters, a sort
  whitelist (code, name, created_at, status, due_date as relevant), `q` on the text columns already used by `search`. Keep
  the legacy list route unchanged. Permission matrix:
  | Route | Code |
  |---|---|
  | smart_tasks GET | `import_files.view` |
  | smart_tasks POST / PUT / DELETE / restore / phase-transition / sync-all-active-files | `import_files.edit` (`sync-all-active-files`: `require_admin`) |
  | notifications GET / summary / read / mark-all-read | login (own notifications) |
  | notifications POST create, trigger-expiry-check | `require_admin` |
  | experience_guide GET | `import_files.view`; writes / promote / reject / recalculate: `import_files.edit` (promote / reject: `require_manager_or_admin`) |
  | smart_email_listener GET logs, log detail | `import_files.view` |
  | system_observability `alerts/evaluate` | login; `force=true` only with `require_admin` |
  | system_observability `recent-traffic` | `Query(50, ge=1, le=500)` |
- **Acceptance criteria**: each new paginated route passes the contract checks of BEX-T13 (bounds, total, header, sort
  422); AUDITOR_VIEWER → 403 on task writes and on `notifications` POST.
- **Tests to add**: `tests/unit/test_pagination_endpoints.py` (parametrised over the new routes: 120 seeded rows, page 3
  of 50 → 20 items, total 120); `tests/unit/test_cross_module_permissions.py` for the matrix.
- **Out of scope**: purchase orders, financial approval, import documentation registries (their phase owners: FE01-T23
  / BE02-T08 / FE03-T?? must switch to this contract instead of a header-only or custom shape; see section 4).

### BEX-T15: Audit trail actor, audit-log access, report exports
- **Severity**: MAJOR (BEX-F16, F33)
- **Depends on**: BEX-T13 (paging for the timeline)
- **Schema/migration needed**: no
- **API contract change**: yes. `/audit-logs` and `/audit-logs/{type}/{id}` need `audit_logs.view`; the timeline gains
  `/audit-logs/{type}/{id}/paginated`. `/import-files/export-excel|export-pdf` need `reports.export`. Flutter:
  `frontend/lib/features/audit_logs/providers/audit_logs_provider.dart`, `step_config_provider.dart` (reads audit logs),
  `import_files_screen.dart` export buttons (hide without `reports.export`).
- **Files to change**: `modules/audit_logs/service.py`, `modules/audit_logs/router.py`, `modules/auth/service.py`,
  `modules/import_files/router.py` + `service.py`, new `tests/unit/test_audit_trail_actor.py`
- **Steps**:
  1. `log_activity(..., performed_by: str, ...)`: no default; grep every caller (`grep -rn "log_activity(" modules`) and pass
     the actor username (system jobs pass `"SYSTEM"` explicitly).
  2. `auth/service.py`: pass `performed_by=actor.username` at `:171`, `:250`, `:330`, `:525`.
  3. Router: `require_permission("audit_logs.view")` on both routes.
  4. Export rows built by `import_files/service.build_export_rows(files)` with `None`-safe formatting
     (`f"{(p or 0):.0f}%"` only for display, never in money columns).
- **Acceptance criteria**: admin `a1` deactivates user `u2` → the audit row `performed_by="a1"`. LOGISTICS_OPERATOR →
  403 on `/audit-logs`. Export with a legacy NULL `progress_percent` row → 200.
- **Tests to add**: `tests/unit/test_audit_trail_actor.py` (three cases).
- **Out of scope**: audit for master data (comes with BEX-T04..T06 actor wiring).

### BEX-T16: Database integrity: foreign keys pragma, audit columns, stage uniqueness
- **Severity**: MAJOR (BEX-F26, F27 schema part) + MINOR (F41)
- **Depends on**: Q5 (orphan cleanup policy); BEX-T02 (flush-based repository)
- **Schema/migration needed**: yes. One Alembic revision: (a) nullable `created_by`, `updated_by` (String 100) on
  `projects`, `transport_locations`, `expense_catalog`, `currencies` (legacy rows stay NULL: the response schemas must
  declare them `Optional[str]`); (b) dedupe `shipment_stage_activity` keeping the highest `id` per
  `(import_file_code, step_code)`, then a unique index `uq_shipment_stage_activity_file_step`.
- **API contract change**: additive (`created_by` / `updated_by` in those responses, nullable).
- **Files to change**: `database/database.py`, new `alembic/versions/<rev>_cross_integrity.py`, the four models
  (one line each; split if > 5 files: models in T16b), new `tests/unit/test_db_integrity.py`
- **Steps**:
  1. `_set_sqlite_pragma`: add `PRAGMA foreign_keys = ON;`; replace `except: pass` with `logger.exception`.
  2. Before enabling in a release, add `scripts/ci/fk_orphan_report.py` (read-only `PRAGMA foreign_key_check`) and run it
     on a copy of the production DB (CTO, Q5).
  3. Migration as above, with `server_default=None` (nullable, explained in the docstring) and the dedupe SQL.
- **Acceptance criteria**: inserting an `ImportFile` with `company_id=999999` (no such company) raises `IntegrityError`.
  Two concurrent `save_or_update_activity` calls for the same pair produce one row.
- **Tests to add**: `tests/unit/test_db_integrity.py` (FK enforced on a scratch DB; unique index present after upgrade).
- **Out of scope**: adding an FK from `shipment_stage_activity` to `import_files` (code-based link; later).

### BEX-T17: Settings API for system parameters + version-check hygiene
- **Severity**: MAJOR (BEX-F32) + MINOR (F39)
- **Depends on**: none
- **Schema/migration needed**: no (table exists)
- **API contract change**: new `GET /api/v1/system-parameters` (`reports.view`) → `[{param_key, param_value,
  description, is_active, updated_at, updated_by}]`; `PUT /api/v1/system-parameters/{key}` (`require_admin`) body
  `{param_value: str, justification: str (min 5)}` → 200 / 404 `SYSPARAM_UNKNOWN` / 422 `SYSPARAM_INVALID_VALUE`.
  `/api/v1/system/version-check` returns `null` fields instead of invented ones when `version.json` is missing.
  Flutter: new settings screen (frontend backlog), `frontend/lib/core/...` update check consumer.
- **Files to change**: new `modules/system_parameters/{router,service,schemas}.py` (module exception: model stays in
  `modules/common/system_parameters.py`), `main.py`, new `tests/unit/test_system_parameters_api.py`
- **Steps**:
  1. Validation per key: numeric keys parse as float ≥ 0 (rates ≤ 1 for `INSURANCE_RATE_*`, `INSURANCE_MARKUP`,
     `INSURANCE_TAX_RATE`); `*_TIERS` keys parse as JSON list of `{from_day:int≥1, to_day:int|null, rate_per_day:float≥0}`
     with contiguous days.
  2. PUT writes `updated_by=actor.username` and an `AuditLog(entity_type="SystemParameter", action="UPDATE",
     old/new values, changes_summary=justification)` in one commit.
  3. `main.py` version check: no literal fallbacks; `check_status="unknown"` when `version.json` is unreadable.
- **Acceptance criteria**: `PUT INSURANCE_RATE_ICC_A {"param_value":"0.003"}` by admin → 200, the next
  `load_insurance_rates` returns 0.003; `"1.5"` → 422; LOGISTICS_OPERATOR → 403.
- **Tests to add**: `tests/unit/test_system_parameters_api.py` (three cases + tiers JSON validation).
- **Out of scope**: the Flutter settings screen.

---

## 4. Frontend impact

### 4.1 List pagination contract (one shape for every large table)

```
GET /api/v1/<resource>/paginated?page=1&page_size=50&sort=-created_at,code&q=text&<resource filters>
200 {"items":[...], "total": 1234, "page": 1, "page_size": 50, "total_pages": 25}
Header: X-Total-Count: 1234
422 {"detail":{"code":"PAGE_SORT_FIELD_INVALID","field":"x","allowed":[...]}}   (also 422 for page<1, page_size ∉ 1..500)
```

- Backward compatible: the existing list route (`GET /<resource>`) is unchanged; the paginated route is a sibling
  `/paginated`, exactly like the shape already shipped in `PaginatedImportFilesResponse` and consumed by
  `paginatedImportFilesProvider` (`frontend/lib/features/import_files/providers/import_files_provider.dart`). This
  settles the two shapes proposed by the FE reviews: **use the envelope** (FE02-T12 / FE03 shape); the `X-Total-Count`
  header is also set so FE01-T23's header reader works, but Flutter should read `total` from the body.
- `page` starts at 1. `page_size` default 50, max 500 (500 is for "export all": loop pages until `page == total_pages`).
- `sort`: comma-separated whitelisted fields, `-` prefix = descending; the server always adds the primary key as the last
  tie-breaker, so paging is stable. The allowed fields are listed in the 422 body.
- `q`: free text, trimmed, max 100 chars, `%`/`_` matched literally, searched in the resource's text columns (same
  columns as today's `search`, which stays as an alias where it exists).
- A page past the end returns `items: []` with the real `total` (no 404): the widget should jump to the last page.
- Filters stay resource-specific query params (`status`, `company_id`, `import_file_id`, `date_from`, `date_to`, ...).

First endpoints (largest tables first):

| Wave | Endpoint | Why / table | Owner task | Flutter consumer |
|---|---|---|---|---|
| 0 | `GET /import-files/paginated` (exists; add `sort`, `q`, bounds) | main file list | BEX-T13 | `import_files_provider.dart` |
| 1 | `GET /smart-tasks/paginated` | system tasks per file × step (largest operational table) | BEX-T14 | `smart_tasks_provider.dart` |
| 1 | `GET /audit-logs/paginated` and `/audit-logs/{type}/{id}/paginated` | grows on every write | BEX-T14/T15 | `audit_logs_provider.dart`, `step_config_provider.dart` |
| 1 | `GET /notifications/paginated` | expiry checker writes many rows | BEX-T14 | notifications provider |
| 1 | `GET /transport-locations/paginated` | world ports (thousands) | BEX-T14 | `transport_locations_provider.dart` |
| 1 | `GET /suppliers/paginated`, `/import-companies/paginated`, `/external-service-providers/paginated` | master data registries | BEX-T14 | suppliers / companies / partners providers, `universal_entity_extractor_dialog.dart` (keep using a lookup) |
| 2 | `GET /customs-tariffs/paginated` | HS table | BE67-T15 must adopt this shape | customs tariff provider |
| 2 | `GET /purchase-orders/paginated` (summary rows, no line items) | FE01-T23 | phase 01 owner | `purchase_orders` providers |
| 2 | `GET /financial-approval/payment-requests/paginated`, `/import-budgets/paginated` | BE02-T08 should use this envelope instead of the header-only design | phase 02 owner | `financial_approval_provider.dart` |
| 2 | import documentation registries (ACID, bank, draft B/L, COO, inspection, invoice-B/L, PO reconciliation), `/shipment-updates/paginated`, `/smart-email-listener/logs/paginated` | FE03 | phase 03 / module owners | `import_documentation_provider.dart` |

### 4.2 Other changes Flutter must follow

- **403 everywhere RBAC is added** (BEX-T01, T04-T06, T14, T15): every list / form must show the backend `detail` in a
  SnackBar, and the UI should hide write buttons using `GET /auth/me/permissions` (`master_data.edit`,
  `lifecycle_board.advance`, `audit_logs.view`, `reports.export`).
- **Lifecycle board** (BEX-T01-T03): `lifecycle_board_provider.dart`, `step_config_provider.dart`,
  `live_polling_provider.dart`, `ai_agent_tool_executor.dart`: stop sending `assigned_user`; handle 404 `LC_FILE_NOT_FOUND`,
  409 `LC_FILE_NOT_ACTIVE`, `LC_STEP_NOT_ACTIVE`, `LC_CLOSURE_STEP_RESERVED`, `LC_SKIP_DUAL_APPROVAL_REQUIRED`, 422
  `LC_APPROVER_ROLE_UNKNOWN`; card / live fields `shipment_mode`, `incoterm_code`, `priority`, `estimated_cost*`,
  `carrier_name`, `vessel_name`, `pol_name`, `pod_name` can be `null` (show "-"); `demurrage_risk_level` can be `"Unknown"`.
- **Currencies** (BEX-T07): `currencies_provider.dart` convert: 409 `CURRENCY_RATE_MISSING` → message + "add rate" action.
- **Import files** (BEX-T10, T11): `import_file_model.dart`: `total_estimated_cost` nullable + `estimated_cost_by_currency`
  map; do not send `status` in the edit form; reopen returns "In Progress"; handle 409 `IF_STATUS_TRANSITION_INVALID`.
- **Projects** (BEX-T10): `project_model.dart`: `total_committed_usd`, `remaining_budget_usd`,
  `budget_utilization_percent` nullable; `missing_rate_currencies` (show a warning chip), `committed_by_currency`.
- **Auth** (BEX-T08): `api_client.dart` refresh: the old token is dead after refresh (always replace it); after
  change-password store `access_token` from the response; a 401 after a password reset must route to login.
- **Excel imports** (BEX-T09): `master_data_action_helper.dart` / `master_data_toolbar.dart`: show the `errors` list
  when `imported_count == 0`; handle 413 / 415; templates mark the newly required columns.
- **New message codes for the Flutter catalogs**: `LC_FILE_NOT_FOUND`, `LC_FILE_REF_REQUIRED`, `LC_FILE_NOT_ACTIVE`,
  `LC_STEP_NOT_ACTIVE`, `LC_CLOSURE_STEP_RESERVED`, `LC_SKIP_DUAL_APPROVAL_REQUIRED`, `LC_APPROVER_ROLE_UNKNOWN`,
  `CURRENCY_NOT_FOUND`, `CURRENCY_RATE_MISSING`, `IF_STATUS_TRANSITION_INVALID`, `PAGE_SORT_FIELD_INVALID`,
  `AUTH_ROLE_UNKNOWN`, `MD_IMPORT_FILE_TYPE`, `MD_IMPORT_TOO_LARGE`, `SYSPARAM_UNKNOWN`, `SYSPARAM_INVALID_VALUE`.

---

## 5. Open questions for the CTO

1. **Q1 Master-data editors**: today nobody but ADMIN holds `master_data.edit`, yet operators create suppliers and
   companies daily (also from the smart extractor). Which roles get it: GENERAL_MANAGER + LOGISTICS_OPERATOR (proposal),
   also CUSTOMS_OFFICER (ports / HS-linked data)? Should currencies / exchange rates stay ADMIN + FINANCE_OFFICER only?
2. **Q2 Lifecycle manual advance**: may an operator complete a step that is not currently In-Progress (catch-up of an
   old file), or only ADMIN (proposal: ADMIN only, through `auto_complete_prior`)? Should STEP_21 ever be set from the
   board, or only by the file-closure module (proposal: closure module only)?
3. **Q3 Dual-approval skip**: build the real two-signature flow (pending skip request table, second approver ≠ first),
   or remove `dual_approval` from the policy list? Who edits step configs: `users.manage` holders or a new
   `lifecycle_board.configure` code?
4. **Q4 Import-file create defaults**: confirm that incoterm, shipment mode, cost currency and POD must be chosen by the
   user (no "FOB" / "Sea FCL" / "USD" / "El Dekheila" / 21 free days / owner "Kamal" defaults), and that company / supplier
   must be selected from master data (FK required, name derived).
5. **Q5 Foreign keys**: enabling `PRAGMA foreign_keys` on the production DB can fail writes on existing orphan rows.
   Approve running the orphan report on a copy first, then a cleanup migration, then the pragma in the same release?
6. **Q6 Legacy SHA-256 passwords**: set a sunset date after which a legacy hash forces a password reset by the admin?
7. **Q7 Project budget currency**: project budgets are USD-only (`total_budget_usd`). Keep USD as the reporting currency
   (POs converted at today's commercial rate), or store a budget currency and convert at PO date?
8. **Q8 Code uniqueness**: are `supplier_code`, `project_code`, `task_code` unique at DB level on the production DB (needed
   for the retry-on-collision design)? If duplicates exist, renumber or keep and add the index only for new rows?
9. **Q9 Trusted proxy**: is the backend ever reached through a reverse proxy (Hostinger / LAN gateway)? If yes, list its
   IPs for `TRUSTED_PROXY_IPS`; otherwise `X-Forwarded-For` is ignored.
