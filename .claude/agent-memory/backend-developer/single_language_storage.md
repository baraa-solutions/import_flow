---
name: single-language-storage
description: Pitfalls and helpers for the single-language storage work (system message codes, T3 enum codes, hold fix) - read before touching stored system text
metadata:
  type: project
---

Plan: docs/plans/single-language-storage-plan.md. Phase A backend landed 2026-09-29 (uncommitted at first).

- Helpers: `modules/common/system_messages.py` (`msg`, `render_en` never raises, `*_enum_<type>` params render as
  English labels) and `modules/common/enum_codes.py` (`normalize`, `normalize_list`, `legacy_values` for filters that
  must also hit legacy rows, `normalize_currency`, `parse_stage_reference` for messy client stage codes like
  'PHASE-4: STEP_11', 'STEP-08', 'PHASE-3-INS'). `lifecycle_board.service.resolve_hold_stage` gives the English phase title.
- Contract `docs/system_message_codes.json` is generated: `python -m modules.common.system_messages` after ANY catalog
  edit, or `test_system_messages_catalog.py` fails. Flutter reads it; add codes, never rename.
- A template placeholder must exist for Flutter to localize a param: when a value is a code, use a separate
  `*_CODED` message whose placeholder is `x_enum_<type>` (see LC_STEP_ON_HOLD vs LC_STEP_ON_HOLD_CODED).
- `clearance_expense_invoices.expense_category` is aggregated by SUBSTRING (broker/port/storage/handling/clearance):
  codes must keep those English keywords (test_enum_codes checks bucket parity).
- Keyword classifiers over stored categories (financial_settlement `actual_expense_bucket`, odoo
  `classify_odoo_cost_category`) must run on `enum_codes.legacy_text(...)` so coded rows land where legacy text did
  (the Arabic part decides, e.g. نولون -> Freight). Settlement snapshot rows are `"Clearance / <label>"`.
- Second contract `docs/enum_codes.json` (`python -m modules.common.enum_codes`); filters over enum columns use
  `legacy_values(...)` + `.in_()` because seeds never rewrite existing rows.
- Hold/resume: never write `import_files.notes` (user text). System text -> activity notes (appended, code = latest
  event) + `AuditLogService.log_activity(action="HOLD"/"RESUME")` which also keeps hold_notes.
- Existing tests that pinned old literals: test_cl03 (payment_method, CIB label), test_import_files hold test.
- Deferred to Phase B: all T1 write sites (lifecycle advance/sync, next_action codes, notifications, tasks, guide),
  NotificationCreate msg_code validation, ShipmentStageCard/WS fields, CustomsBrokerQuoteItem category/unit.

Phase B (group 1, 2026-09-29):
- `modules/common/file_tracking.py`: `set_file_tracking(rec, *, step_code, phase_id, next_action, stage_code)` (None =
  column untouched; phase derived from step; legacy texts "STEP_xx <English name>" / "Phase n: <title>"),
  `step_tracking_columns(step)` for insert dicts. Lazy-imports lifecycle_board.service (avoid cycles).
- `advance_lifecycle_step_service` kwargs: `notes_msg`, `next_action_msg`, `stage_code`; custom_stage_title/module are
  ignored; `custom_next_action` still stored as text WITHOUT code. It overwrites next_action with NA_FOLLOW_UP_STEP by
  default, so a caller's earlier `set_file_tracking(next_action=...)` is lost: pass `next_action_msg=` instead.
- `lifecycle_board.repository.save_or_update_activity(msg_code=, msg_params=)`: writing notes always rewrites the code
  (user text clears it). `smart_tasks.repository.create_task(msg_code=, msg_params=, step_code=)` server-only.
- System task dedupe/auto-close: `step_code` first, legacy rows (step_code NULL) by title ilike. Phase-task dedupe by
  reminder_type + legacy Arabic suffix. `update_task_service` drops msg_code when title/description/notes change.
- Dashboard phase filter: `current_phase_id == n OR (NULL AND legacy ilike)`; "Phase 1" must not match "Phase 10".
- Not coded (no columns): inbound_email_logs.notes and email_settings.last_sync_message (Arabic, needs migration).

Phase B group-2 notes (2026-09-29):
- `NotificationCreate` accepts `msg_code`/`msg_params`; title/message optional when a code is given (filled by
  render_en title/body); unknown code -> 422 "رمز الرسالة غير معروف". Direct `SystemNotification(...)` writes in
  other modules must set msg_code/msg_params themselves.
- `AlertPayload(msg=SysMsg)` with title/message None -> English render. The persisted notification stores the
  alert's own code; uncoded payloads get `ALERT_DISPATCHED` (render == stored text). In alert_dispatcher the name
  `msg` is a local MIMEMultipart inside send_email: import the helper as `sys_msg` there.
- When the English text needs a different value than the stored param (month NAME for `month`, enum LABEL for a
  code param without an `_enum_` placeholder), render with an override dict: `guide_texts(m, month=...)` /
  customs_clearance `_render(m, part, inspection_yard=label)`. `render_en` does not map `month` to a name.
- Guide entries: a user edit of title/content (update/promote) clears msg_code (repository helper).
- `SmartTask` has NO `completion_notes`/`task_name`/`completed_at` columns: code in customs_clearance writes them
  as transient attributes (never persisted).
- Scratchpad is shared between parallel agents: use a unique subfolder for scripts.

Phase B (group 3 modules, 2026-09-29):
- `advance_lifecycle_step_service` takes `notes_msg=` / `next_action_msg=` / `stage_code=`; it OVERWRITES next_action
  (default NA_FOLLOW_UP_STEP), so a `set_file_tracking(...)` before the call is lost: pass `next_action_msg` instead.
  `custom_stage_title` / `custom_module_name` are ignored. `transition_stage_*_service` still take plain `notes` only.
- `smart_tasks.repository.create_task(db, schema, created_by, msg_code=, msg_params=, step_code=)`: codes are NOT on
  `SmartTaskCreate` (request schema stays user-only). Direct `SmartTask(...)` accepts the columns.
- `set_file_tracking(stage_code=...)` for non-phase stages (GOODS_RECEIVED, ARCHIVED_CLOSED, ...; list in
  enum_codes STAGE labels): stage text becomes the bare English label, so old tests asserting GRN/closure codes inside
  `current_stage` must move to `current_stage_code` / notifications.
- Dead code found: `modules.notifications.service.create_system_notification` does not exist (warehouse_receiving
  swallowed the ImportError, notifications were never created); now direct `SystemNotification`.
- Legacy text parsers must accept both prefixes (demurrage free-days note: English + Arabic prefix constants).
- Batch edits on CRLF files: scratchpad `repm.py` (dict of path -> exact (old, new) pairs, all-or-nothing per file);
  write the pairs file with the Write tool (bash heredocs with Arabic + quotes broke parsing).
- Mini guard for these modules: tests/unit/test_group3_stored_system_text.py (AST: known codes, no Arabic in tracking
  attrs / notification / task / advance notes).
- Backend-dev owns system_messages.py + enum_codes.py for Phase B+ (2026-09-29). Contract JSON now has metadata keys
  `_phases` / `_param_rules` (Flutter parity must skip keys starting with "_"). Number rule = NUMBER_PARAM_NAMES +
  NUMBER_PARAM_SUFFIXES; render_en renders `month` as a name, `phase_id` as the phase title, and comma lists in
  `*_enum_<type>`. Optional details = code variants (*_DETAILS/_FILE/_CLAIMS/_GENERIC), never English glue in params.
- Head revision since 2026-09-29: c8d3e4f5a6b7 (inbound_email_logs/email_settings msg_code+msg_params).
- Swallowed `try/except: pass` around SmartTask/notification writes hid broken code for months (inland_transport used
  non-existent SmartTask fields task_name/stage_name; SmartTask has no completed_at). When touching such a block, check
  the fields against the model and add a test that the row actually exists.
- The group-3 module tests + the CLO/FN/DC/BK/TR workflow tests (~35 files) take >10 min together: run them in background.
- `smart_tasks.repository.create_task(commit=False)` / `create_task_service(commit=False)` flush only: use it inside a
  service that commits once at the end (lifecycle next-step task, inland booking, FB/DOC/FA/WH task sites). Repos that
  commit mid-service (e.g. inland `create_transport_booking`, now flush) break "failure = nothing saved".

Phase C guard (2026-09-29):
- `tests/unit/test_no_arabic_in_stored_writes.py` + `tests/unit/fixtures/arabic_stored_writes_baseline.json` (per-file
  counts, only down; `UPDATE_STORED_ARABIC_BASELINE=1` regenerates). `python tests/unit/test_no_arabic_in_stored_writes.py`
  prints every site. One hit per string expression (an f-string counts once).
- Heuristics that keep false positives low (know them before "fixing" a hit): Pydantic models whose name does not end
  with Create/Update/Request/Payload/Input/In/Upsert/Patch/Base count as response-only; generic calls are opaque (only
  str/format/join/... propagate); dicts are followed backwards (return / response model / .append / local name) and a
  dict nested under a JSON-column key (comparison_matrix, checklist_data, ...) counts as stored even when returned.
- Known blind spot: response models later `model_dump()`ed into a JSON column (settlement `categories_breakdown`).
- Baseline is `{}` since the doc-comparison follow-up; scope also covers import_documentation/ai_document_parser.py
  and customs_tariff/nafeza_text_parser.py.
- JSON payload items (comparison matrices, header_discrepancies): `system_messages.coded_text(field, CODE, **params)`
  -> `{field, field_code, field_params}`; `enum_codes.Placeholder(code)` / `Measure(n, unit, decimals)` +
  `finalize_structured_values(item)` -> English text + `structured_values[key]` (VALUE_PLACEHOLDER / MEASURE_UNIT).
  Checklist `reason_code` is dropped when the user edits the reason (`service._drop_stale_reason_code`).
- Draft B/L `blocking_reasons` = English text + `blocking_reasons_coded` [{code, params}] (DOC_DRAFT_BLOCKING_*,
  param `field_enum_draft_bl_field` = DRAFT_BL_FIELD code = upper field_key). A client update of the text without
  codes clears them (`_drop_stale_blocking_codes`). `field_label_ar`/`field_name_ar` stay (bilingual pair, allowed).
- Search over an enum column: `enum_codes.codes_matching(type, term)` (substring of code / EN label / legacy) +
  `legacy_values` -> `.in_()` OR-ed with the old ilike (see customs_tariff `customs_category_search_values`). customs_category = enum CUSTOMS_CATEGORY, normalized in CustomsTariffCreate/Update.
