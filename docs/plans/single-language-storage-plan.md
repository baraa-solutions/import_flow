# Single-language storage — plan (2026-09-29)

Status: proposed. Base: `feat/update-notice-rtl-p1` @ 24302f8 (RTL phase 1 landed).
Items marked **(verify)** were not fully read during planning. The implementer confirms them before coding.

## 1. Goal & business rules

CTO decisions (final):
1. Every value the system writes is language-independent: English text or codes. User-typed free text is left as typed. Paired bilingual master-data columns (`name_ar`/`name_en`) stay.
2. System-generated messages are stored as a message code plus params. The UI renders them in ar or en.
3. No data migration. Legacy rows (no code) show their stored text, as today.

HTTP error `detail` strings are out of scope. So are document parsers and extractors (`smart_document_upload/extractors/*`, `ai_document_parser.py`, `nafeza_*_parser.py`, `cross_checker.py`). Their Arabic literals are parsing keywords, not stored writes. Formal letters (`formal_letters/templates.py`) are official Arabic output documents and are also out of scope.

This is cross-cutting across all GP-002 stages. Most write sites belong to the lifecycle board (6 phases / 25 steps).

### Three tiers (the core decision)

| Tier | What | Storage | Render |
|---|---|---|---|
| T1 System messages | step-transition / activity notes, completion notes, smart-task title/description/notes, system notifications title/message, `next_action` / `current_module` / `current_stage`, experience-guide auto entries, alert-dispatcher / expiry-checker / daily-report notifications, email-listener tasks | `msg_code` + `msg_params` (JSON). The legacy text column is **still written with the English render**. | Flutter `SystemMessageRenderer` (ar/en) → falls back to the stored text |
| T2 System defaults inside user-editable text | clone suffixes, "Cloned from: X" default notes, archive notes, hold/resume notes, `(Copy)` on names/descriptions | Fixed English constant (no code) | As stored |
| T3 Enum-like values chosen from fixed lists | release_type, payment_method, duty bank name, expense_category, truck_type, regulatory_bodies, clearance-quotation service_category + currency, broker price-list category/default_unit, hold reason, skip reason categories | UPPER_SNAKE code (currency uses ISO `EGP`) | l10n label map. Legacy label → code reverse map, unknown → raw |

Why the English render is still written in T1:
- The legacy columns are NOT NULL.
- Older clients, server-side exports, logs, email, toast and text search keep working unchanged.
- The code only adds a localized view on top.

## 2. Existing patterns to follow

- Clone suffix: `frontend/lib/core/widgets/table_row_clone_helper.dart` (`copySuffix = ' (Copy)'`, documented as language-independent). All other clone sites converge on it.
- Step/phase name resolution plus legacy heuristics: `frontend/lib/core/services/display_name_resolver.dart` (`resolveStepName`, `resolvePhaseName`, `resolveStageBadge`, `cleanTaskTitle`). It stays as the legacy path.
- Existing label-by-code l10n function: `AppLocalizations.expenseCategoryName(String category)` (app_localizations*.dart ~5342/5498).
- Defensive additive migration: `alembic/versions/f7a1c3e5b9d2_add_users_must_change_password.py` (add-if-missing, batch_alter_table).
- Ratchet guard test: `frontend/test/no_bare_dio_test.dart` (per-file baseline).
- Step catalog source of truth (backend): `modules/lifecycle_board/service.py` `PHASES_DEFINITION` / `STEP_NAME_MAP` / `STEP_TO_PHASE_MAP`.

## 3. Data model — one Alembic migration

Revision `b7c1d2e3f4a5_system_message_codes`, revises `f7a1c3e5b9d2`. It is defensive like f7a1: per column, add only if missing and skip if the table is absent. All new columns are nullable with no server default. Downgrade drops them.

| Table | New columns | Index |
|---|---|---|
| `smart_tasks` | `msg_code` String(80), `msg_params` JSON, `step_code` String(50) | `idx_smart_tasks_step_code` (import_file_id, step_code) |
| `system_notifications` | `msg_code` String(80), `msg_params` JSON | — |
| `shipment_stage_activity` | `msg_code` String(80), `msg_params` JSON (for `notes`) | — |
| `import_files` | `current_step_code` String(50), `current_phase_id` Integer, `current_stage_code` String(50), `next_action_code` String(80), `next_action_params` JSON, `hold_reason_code` String(50) | `idx_import_files_current_phase_id` |
| `guide_entries` | `msg_code` String(80), `msg_params` JSON (renders title/content/evidence_summary/reason_why) | — |
| `shipment_updates` (verify table name) | `msg_code`, `msg_params` only if the service writes system text (verify) | — |

- `smart_tasks.step_code` replaces the `SmartTask.title.ilike('%STEP_xx%')` matching in `advance_lifecycle_step_service` and `_sync_file_tracking…`. Keep the ilike as a fallback for legacy rows where `step_code IS NULL`.
- `current_stage_code` holds special stages that are not a phase, for example `CUSTOMS_RELEASED`. Otherwise it is `PHASE_n`.
- Update each model file with the same columns. Confirm that `database/schema_upgrade_service.py` adds the missing columns at startup (additive, compatible) **(verify)**.
- Model column defaults that contain Arabic: `inland_transport/model.py` truck_type, and the `inland_transport/migration.py` DDL default, which becomes `FLATBED`. Also check the other 5 models flagged by the audit: purchase_orders, customs_clearance, import_files, projects, currencies, customs_consultation (**verify**). Changing a Python-side `default=` needs no migration. A `server_default` change is left alone; old rows are legacy.

## 4. Message catalog

### Backend: `modules/common/system_messages.py` (new; Python, because packaging ships code only, no JSON data)

```python
@dataclass(frozen=True)
class SysMsg:
    code: str
    params: dict  # JSON-safe primitives only

CATALOG: dict[str, dict[str, str]] = {
  # code -> {part: English template}; parts: title | body | note | action | stage | module
  "LC_STEP_AUTO_COMPLETED":   {"note": "Auto-completed on transition to {target_step_code}"},
  "LC_STEP_AUTO_CLOSED_PRIOR":{"note": "Auto-completed when {completed_step_code} was done"},
  "LC_STEP_COMPLETED":        {"note": "{step_code} completed"},
  "LC_STEP_ACTIVATED":        {"note": "Activated after {completed_step_code} completed"},
  "LC_STEP_ON_HOLD":          {"note": "On hold: {reason}"},
  "LC_TASK_NEXT_STEP": {
      "title": "[{import_file_code}] — {step_code}",
      "body":  "{completed_step_code} completed for {import_file_code}; moved to {step_code} in {phase_id}. Action: follow up and complete the stage requirements.",
      "note":  "Auto-generated after {completed_step_code}"},
  "LC_TASK_NEXT_STEP_SKIPPED": {...},          # adds {reason}
  "NA_FOLLOW_UP_STEP":  {"action": "Follow up {step_code}"},
  "NA_FILE_CLOSED":     {"action": "Import file closed"},
  "NA_CL_RECORD_INSPECTION": {"action": "Record inspection & sampling (CL-01)"},
  "NOTIF_COMPANY_IMPORTER_ID_EXPIRY": {
      "title": "Importer card expiring: {company_name}",
      "body":  "Importer card {importer_id} has {days_left} days left, expires {expiry_date}. Renew now."},
  "ALERT_BACKUP_OVERDUE": {"title": "Backup overdue", "body": "Last valid backup is {hours} h old (>26h)."},
  "GUIDE_SUPPLIER_DELAY": {"title": ..., "body": ..., "evidence": ..., "reason": ...},
}
def render_en(code, params, part) -> str      # missing param -> "{name}" left in place, never raises
def msg(code, **params) -> SysMsg             # asserts code in CATALOG (unit-tested)
```

Param conventions, shared with Flutter. The suffix decides how the UI formats the value:
- `*_step_code` / `step_code` → step name (DisplayNameResolver).
- `phase_id` / `*_phase_id` → phase name.
- `*_date` → ISO date → locale format.
- `*_amount` / `days_left` / `hours` / `*_pct` → number.
- `*_enum_<type>` → T3 label.
- Anything else (codes, company/supplier names, ACID, container no.) → verbatim, as an LTR island.

Params never contain translated text.

Next-action codes: one `NA_*` code per distinct `custom_next_action` string found in lifecycle_board / financial_approval / freight_booking / import_documentation / customs_clearance / warehouse_receiving, and per `next_action` in `import_files/service.py` `STEP_INITIAL_CONFIG` + `compute_file_formulas`. About 40 codes. The existing English texts become the templates. The Arabic `custom_stage_title` / `custom_module_name` args are dropped. Stage becomes `current_phase_id` / `current_stage_code`, and module becomes `current_step_code`. The English render comes from `PHASES_DEFINITION` `title_en` and `STEP_NAME_MAP[...][0]`.

Contract snapshot: `docs/system_message_codes.json` = `{code: {"parts": [...], "params": [...]}}`.
- It is generated and checked by a backend test (the test fails if the catalog and snapshot differ; a regenerate helper is in the test module).
- The Flutter parity test reads `../docs/system_message_codes.json`.
- This is the only cross-team contract file.

### Frontend: `frontend/lib/core/localization/system_messages/`

- `system_message_catalog_en.dart` / `_ar.dart`: `const Map<String, Map<String, String>>` (code → part → template). These are separate from AppLocalizations to avoid ~200 getters.
- `system_message_renderer.dart`:
  - `SystemMessageRenderer.render({required bool isArabic, String? code, Map<String, dynamic>? params, required String part, required String fallback})`.
  - Unknown/null code → `fallback`, the stored text. This covers legacy rows and a newer backend with an older catalog.
  - It formats params by the suffix convention.
- `domain_enum_labels.dart`: `DomainEnums.label(type, value, isArabic)` plus `legacyToCode(type, value)`. The reverse map contains the current Arabic/English/mixed labels, for example `'نهائي وبات (Final Green Release)' → FINAL_GREEN`, so legacy rows render and legacy values preselect correctly in dropdowns.

## 5. API contract changes (all additive; no field removed or renamed)

| Group | Change |
|---|---|
| Smart tasks `GET/POST/PUT /smart-tasks…` | Response adds `msg_code`, `msg_params`, `step_code` (nullable). Create/update request: unchanged. User tasks never carry a code. |
| Notifications `GET /notifications`, `POST /notifications`, `POST /notifications/trigger-expiry-check` | `NotificationResponse` adds `msg_code`, `msg_params`. `NotificationCreate` accepts optional `msg_code` (must exist in CATALOG → 422 `"رمز الرسالة غير معروف"`) and `msg_params` (dict). If only a code is given, the server fills `title`/`message` with the English render. |
| WebSocket `/notifications/ws` `NEW_NOTIFICATION` / `EXPIRY_ALERT` / `SYSTEM_ALERT` | `data` adds `msg_code`, `msg_params`. `title`/`message` = English render. Flutter does not consume the WS today, so this is harmless. |
| Lifecycle board summary / activities (`ShipmentStageCard`, activity lists) | Adds `msg_code`, `msg_params` next to `notes`. `advance`/`multi-stage` responses: the `message` key is an HTTP message (out of scope). They add `current_step_code`, `current_phase_id`, `next_action_code`, `next_action_params`. |
| Import files `ImportFileResponse`, operational dashboard | Adds `current_step_code`, `current_phase_id`, `current_stage_code`, `next_action_code`, `next_action_params`, `hold_reason_code`. Dashboard `phase` filter: `current_phase_id == n` OR legacy text ilike when `current_phase_id IS NULL`. `phase_counts` are computed the same way. |
| `POST /import-files/{id}/hold` | Request adds optional `hold_reason_code` (validated against the HOLD_REASON set → 422 `"رمز سبب الإيقاف غير معروف"`). `hold_reason` stays required (English label or user text). New clients send `stage_name` = English title and `step_name` = stage code. |
| Experience guide entries | Response adds `msg_code`, `msg_params`. |
| T3 endpoints (customs final release, duty payment, clearance expenses, inland transport, declaration 46 / sampling regulatory bodies, clearance quotations, broker price lists, step-config reason categories) | Request accepts the code **or** a legacy label. `modules/common/enum_codes.py` `normalize(type, value)` maps legacy labels → code before saving. Unknown value → stored as-is (these fields are open today; no new 422). Responses return what is stored. |
| Clone endpoints (financial_approval clone budget/request, customs_consultation clone price list/consultation, shipping_scenarios, purchase_orders, customs_tariff) | Default title suffix ` (Copy)`. Default notes `Cloned from: {code}`. Codes that must stay unique get `-COPY`. |

No new permission codes are needed. Existing router-level auth dependencies apply unchanged.

## 6. Phased plan

### Phase A — frontend locale-dependent writes + T3 codes, plus migration and foundations (backend + flutter in parallel, 4–5 d)

Backend:
- The migration and model columns (all of §3).
- `modules/common/system_messages.py` (catalog skeleton + render + `msg`).
- `modules/common/enum_codes.py` (enum sets + legacy label maps + `normalize`).
- `docs/system_message_codes.json`.
- Apply `normalize` in the services of: customs_clearance (release_type, payment_method, bank, regulatory_bodies, sampled_regulatory_bodies), clearance expenses (expense_category), inland_transport (truck_type + model default), demurrage_detention (depot name only if picked from the popular list; the free text stays), customs_clearance_quotations (service_category, currency → `EGP`), customs_consultation broker price lists (category, default_unit), lifecycle_board `DEFAULT_REASON_CATEGORIES` → `CLIENT_AGREEMENT | NOT_APPLICABLE_TO_MODE | REGULATORY_EXEMPTION | OTHER` (existing `step_configs` rows untouched; the UI maps legacy bilingual strings), import_files hold (`hold_reason_code`), expense_catalog / master_data_sync seeds **(verify file)**.
- Clone endpoints get the English suffix/notes.

Flutter:
- Every clone site uses `TableRowCloneHelper.copySuffix`. This covers customs_consultation_screen (2), saved_consultations_tab, price_list_form_dialog, broker_price_lists_tab, shipping_scenarios_screen (2), saved_scenarios_registry_tab, po_form_dialog, financial_approval_screen, bank_form4_screen, financial_settlement_screen, and po_reconciliation_tab (2). The helper's own snackbar stays localized.
- For code fields (`itemCode`, `poNumber`, `poReference`), use the new `TableRowCloneHelper.copyCodeSuffix = '-COPY'`.
- The dropdowns listed above hold codes as values and localized labels as items. Initial values come from `DomainEnums.legacyToCode`.
- Clearance quotation currency: send `'EGP'`, not `l10n.egpCurrency`.
- Hold dialog: the chips map to HOLD_REASON codes. Send `hold_reason_code` + the English label, or the user text with no code. `stage_name` = titleEn (never the RTL-dependent title).
- Default titles/names/notes set from `l10n` in payloads become English constants. There are about 31 sites in 22 files from the audit; the implementer lists them with the Phase C guard's first run.
- Display: every place that shows these fields goes through `DomainEnums.label`.

### Phase B — backend message codes by module (backend 7–9 d; flutter renderer wiring 3–4 d in parallel)

Backend order: each step lands with its tests and lowers the guard baseline.
1. lifecycle_board (advance, sync_*, skip/hold/resume, multi-stage).
2. import_files (`compute_file_formulas`, `STEP_INITIAL_CONFIG`, hold/resume notes → T2 English).
3. smart_tasks + smart_email_listener/repository.
4. notifications/expiry_checker (13 checks).
5. system_observability alert_dispatcher + daily_report_service.
6. experience_guide/autonomous_engine. Month names become the `month` int param, and default categories become codes.
7. customs_clearance.
8. import_documentation.
9. financial_approval, financial_settlement.
10. freight_booking, cargox, original_documents_collection, docs_customs_approval, import_requirements, inland_transport, warehouse_receiving, demurrage_detention, file_closure, shipment_updates.

Pattern at each write site:

```python
m = msg("LC_STEP_ACTIVATED", completed_step_code=code)
repo.save_or_update_activity(..., notes=render_en(m.code, m.params, "note"), msg_code=m.code, msg_params=m.params)
```

For import_files there is a helper `set_file_tracking(file_rec, step_code, phase_id, next_action: SysMsg, stage_code=None)` in lifecycle_board/service.py. It writes the structured columns plus the English text columns. Existing writes to appended activity notes (`notes + " [..]"`) are replaced by setting code/params to the latest event; the English text is still appended.

Flutter:
- Models parse the new fields: `smart_task_model.dart`, `notification_model.dart`, `lifecycle_board_model.dart`, `import_file_model.dart`, `guide_entry_model.dart`, and the shipment_updates model **(verify)**.
- Widgets call the renderer: notification bell, smart task list/cards (`cleanTaskTitle` is used only in the fallback path), lifecycle board cards/activity timeline, import-file header / dashboard next action and stage (use `current_step_code` / `current_phase_id` via DisplayNameResolver when present), experience guide banner/list.

### Phase C — guards (1–2 d)

- Backend `tests/unit/test_no_arabic_in_stored_writes.py`: an AST ratchet over `modules/**/{service,repository,model}.py`, `notifications/expiry_checker.py`, `system_observability/{alert_dispatcher,daily_report_service}.py`, and `experience_guide/autonomous_engine.py`. It flags Arabic (U+0600–06FF) `Constant`/`JoinedStr` when the literal is:
  - (a) a kwarg value whose name is in `STORED_FIELDS` (`notes, title, description, message, content, next_action, current_stage, current_module, custom_stage_title, custom_module_name, custom_next_action, hold_reason, evidence_summary, reason_why, remarks, status, default`), excluding kwargs of `HTTPException` / `detail=`;
  - (b) the right-hand side of an `Attribute` assignment to those names;
  - (c) the value of a dict literal key in those names, unless the dict is directly `return`ed from a router-facing function (an HTTP message);
  - (d) a `Column(default=...)` argument.

  The baseline `tests/unit/fixtures/arabic_stored_writes_baseline.json` stores per-file counts that may only decrease. The target after Phase B is `{}`.
- Backend `tests/unit/test_system_messages_catalog.py`: the snapshot equals the catalog; every `msg(...)` call site in `modules/` uses a known code (AST scan); `render_en` never raises.
- Flutter `test/no_locale_dependent_payload_test.dart`: a ratchet with a per-file baseline. It flags `isAr ? '…' : '…'` / `isArabic ?` whose result feeds a `copySuffix`/`suffix` variable, Arabic string literals inside map literals with `'snake_key':`, and `l10n.` / `context.l10n` expressions inside `toJson()` bodies or `data: {` payload maps.
- Flutter `test/system_message_catalog_parity_test.dart`: ar and en have every code/part in `../docs/system_message_codes.json`, with identical placeholder sets.

## 7. File ownership

**backend-developer**
- `alembic/versions/b7c1d2e3f4a5_system_message_codes.py`
- `modules/common/system_messages.py`, `modules/common/enum_codes.py`
- `docs/system_message_codes.json`
- The model / schemas / service / repository / validators files of: smart_tasks, notifications (incl. expiry_checker, router WS payload), lifecycle_board, import_files, experience_guide (autonomous_engine), system_observability (alert_dispatcher, daily_report_service), smart_email_listener, customs_clearance, customs_clearance_quotations, customs_consultation, import_documentation, financial_approval, financial_settlement, freight_booking, cargox, original_documents_collection, docs_customs_approval, import_requirements, inland_transport (+ migration.py), warehouse_receiving, demurrage_detention, file_closure, shipment_updates, shipping_scenarios, purchase_orders, customs_tariff, expense_catalog
- `database/schema_upgrade_service.py` (only if needed)
- `tests/unit/test_system_messages_catalog.py`, `test_enum_codes.py`, `test_no_arabic_in_stored_writes.py` + fixture, and per-module tests
- `history/2026-09-29.md` append (backend entry)

**flutter-developer**
- `frontend/lib/core/localization/system_messages/*` (new), `frontend/lib/core/localization/domain_enum_labels.dart` (new)
- `frontend/lib/core/widgets/table_row_clone_helper.dart`, `hold_shipment_at_stage_dialog.dart`, `shipment_stage_lifecycle_control.dart`, `resume_shipment_from_stage_dialog.dart`, `dedicated_stage_scaffold.dart`
- `frontend/lib/core/services/display_name_resolver.dart`
- All the `frontend/lib/features/**` screens/widgets/models/providers listed in Phases A/B
- `frontend/lib/core/localization/app_localizations*.dart` (new enum-label keys if used)
- `frontend/test/*` new tests

**Shared**
- `docs/system_message_codes.json`: backend writes it first, on day 1 of Phase A, with the full Phase-B code list. Flutter only reads it. If flutter needs a new code, it asks backend.
- `history/` append: each developer adds their own entry, backend first.

## 8. Test plan

Backend (pytest, `tests/unit/`; read `--junitxml` + exit code):
- `test_system_messages_catalog.py`: snapshot parity; unknown code raises in `msg`; `render_en` keeps missing params and never raises.
- `test_enum_codes.py`: every legacy label maps to its code; a code is idempotent; unknown values pass through.
- `test_lifecycle_message_codes.py`: advance writes `msg_code`/`msg_params` + English notes (no Arabic); import_file gets `current_step_code`/`current_phase_id`/`next_action_code`; smart task gets `step_code`; auto-close matches by `step_code` and by legacy title ilike; STEP_21 closure path.
- `test_notifications_message_codes.py`: one expiry check creates a notification with a code and English title; `NotificationCreate` with an unknown code → 422; create with a code only fills the title/message; WS payload includes `msg_code` (mock the manager).
- `test_import_files_hold_codes.py`: `hold_reason_code` stored; unknown code → 422; the dashboard phase filter works for coded and legacy rows.
- `test_migration_system_message_codes.py`: upgrade on a pre-migration SQLite copy adds the columns; it is idempotent on a `create_all` DB; downgrade removes them.
- Permission denied: unchanged routers. Add one 401 case for the hold endpoint with the new field.
- `test_no_arabic_in_stored_writes.py` (ratchet).

Flutter:
- `system_message_renderer_test.dart`: ar/en render, param formatting (step code → name, date, number), unknown code → fallback, null code → fallback.
- `system_message_catalog_parity_test.dart`.
- `domain_enum_labels_test.dart`: labels plus legacy reverse mapping.
- Model tests: parse the new nullable fields and old JSON without them (smart task, notification, import file, lifecycle card, guide entry).
- Clone tests: the suffix is identical under `Locale('ar')` and `Locale('en')` (po_form_dialog, financial_approval, shipping_scenarios).
- Hold dialog: payload has `hold_reason_code` and an English `stage_name` in the ar locale.
- `no_locale_dependent_payload_test.dart` (ratchet).

## 9. Risks & open points

- **Old clients on new backend:** title/message/notes/next_action still carry English text, so they display English instead of Arabic for new rows. T3 codes (e.g. `FINAL_GREEN`) show raw in old dropdowns and fall back to their defaults. Distribution is a single laptop where backend and client update together, so the window is short. Ship Phase A backend + flutter in one release.
- **Old clients writing to new backend:** they send Arabic labels. `enum_codes.normalize` converts them, and T1 is written by the server only, so this is safe.
- **Search:** server-side ilike over `title`/`notes` matches English only for new rows. Arabic search terms won't hit coded rows. Accepted. Client-side list filters should search the rendered text (flutter: filter on the rendered string).
- **Dashboard phase filter** was already broken for Arabic `custom_stage_title` rows. The new `current_phase_id` fixes new rows. Legacy rows keep the ilike path.
- **Exports/PDF:** Flutter exports render in the UI language via the renderer, which is consistent with the pending RTL phase-3 export decision. Server-side outputs (daily report, emails, toast, Odoo export, logs) use the English render.
- **Hold overwrites `import_files.notes`** (user text is lost). This is a pre-existing bug and is not fixed here. It is flagged for a separate task.
- **Bank names in duty payment** are a hard-coded list and should become an FK to the banks master (CORE rule). This plan stores short codes (NBE, BM, CIB…) as an interim step. A follow-up task should replace them.
- **`paused_at_stage`** will hold English text. Renders use `paused_at_step` via `resolveStageBadge` when present.
- **Performance:** the new `(import_file_id, step_code)` index replaces ilike scans. No new N+1: the renderer is pure and client-side.
- **Scope creep:** about 375 backend literals. The AST guard's first run gives the exact per-file list, which is the Phase B checklist. Parsers and HTTP details are excluded by design.

## Effort

| Phase | Backend | Flutter |
|---|---|---|
| A | 2–3 d | 3–4 d |
| B | 7–9 d | 3–4 d |
| C | 1 d | 1 d |
| Total | ~11–13 d | ~7–9 d (parallel) |
