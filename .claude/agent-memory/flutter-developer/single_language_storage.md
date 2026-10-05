---
name: single-language-storage
description: Single-language storage on Flutter - phase A (T3 codes, English defaults, clone suffixes) and phase B (SystemMessageRenderer, model helpers); pitfalls
metadata:
  type: project
---

Plan: docs/plans/single-language-storage-plan.md. Phase A Flutter landed on feat/update-notice-rtl-p1 (2026-09-29; check git).

- T3 enums: `core/localization/domain_enum_labels.dart` (`DomainEnumType`, `DomainEnums.codes/legacyToCode/label/
  englishLabel/initialCode`). Labels live in the l10n files as ONE method `String? domainEnumLabel(type, code)` backed by a
  `_domainEnumLabels` const map in ar/en (keys `'type.CODE'`), not ~100 getters. Dropdown value = code, label =
  `DomainEnums.label(l10n, type, code)`; legacy row -> `initialCode(...)`; keep an unknown legacy value as an extra item.
- English stored defaults: `core/localization/stored_text.dart` `storedText` (= const AppLocalizationsEn()). Use it instead
  of `context.l10n` for default titles/notes/names that get saved.
- Clone: `TableRowCloneHelper.copySuffix` ' (Copy)', `copyCodeSuffix` '-COPY', `withCopySuffix/withCodeSuffix`.
  Vessel name is never suffixed. Fake sample names -> `ref.read(authProvider).user?.fullName ?? ''` in initState.
- Hold: `buildHoldRequest` in hold_shipment_at_stage_dialog.dart; scaffolds pass `stageNameEn: titleEn` to
  ShipmentStageLifecycleControl (stage_name must never be the RTL-dependent title).
- Test pattern for request bodies: override `dioProvider` (core/network/api_client.dart) with a Dio whose interceptor
  `handler.resolve(...)`s every request and records POSTs; pump with `localizedApp(locale:)` for ar and en.
- Pitfall: scripted `\n`->CRLF replacement also rewrites `"\n"` inside Dart string literals; use sed for those lines.
- Backend owns the codes: `docs/enum_codes.json` ({TYPE: {codes, legacy}}) generated from modules/common/enum_codes.py;
  `test/enum_codes_parity_test.dart` asserts same codes + every backend legacy label maps identically. When it fails,
  add the codes/legacy rows to DomainEnums and ar/en labels (backend labels_en are the English source).

**Why:** CTO rule: DB values are codes/English, UI shows labels in the user's language, legacy rows untouched.
**How to apply:** any new fixed-list field or default text that is saved.

Phase B (T1 system messages, 2026-09-29):
- `core/localization/system_messages/`: catalog_en/ar (const maps generated from backend CATALOG + hand-written
  Arabic) and `SystemMessageRenderer.render/tryRender(code:, params:, part:, l10n:)`; isArabic comes from
  `l10n.isArabic`. Missing param / unknown code / missing part -> fallback (stored text). Empty-string param is valid.
- Models expose helpers instead of widgets calling the renderer: `SmartTaskModel.displayTitle/displayDescription`
  (cleanTaskTitle only in fallback), `NotificationModel.localizedTitle/Message`, `ImportFileModel.stepKeyOr/
  phaseKeyOr/displayNextAction`, `ShipmentStageCardModel.localizedNotes`, `GuideEntryModel.localizedTitle/...`.
- Arabic render wraps Latin/digit params in LRI/PDI; tests compare with `SystemMessageRenderer.stripIsolates`.
- intl is NOT a direct dependency: the renderer formats numbers/dates/months itself (Western digits).
- `resolveStepName('STEP_08_PO')` used to collapse to STEP_08; exact-key lookup now runs first.
- Parity test reads `../docs/system_message_codes.json`; regenerate catalogs with a script when backend adds codes.
- Bidi code points in Dart literals trigger `text_direction_code_point_in_literal`: write them as \u escapes
  (and remember heredocs eat backslashes - write escape scripts with the Write tool).
- Final contract (2026-09-29): 246 codes + top-level `_phases` / `_param_rules` (skip `_` keys). phase_id params use
  `SystemMessageRenderer.phaseTitles` (backend's 6 phases; ar = PHASES_DEFINITION title_ar), NOT DisplayNameResolver's
  10 phases. Number rules and `_phases` are asserted by the parity test. `*_enum_*` values may be comma lists.
- Regenerating: dump backend `CATALOG` to JSON, keep Arabic as `CODE.part: text` lines, generator checks
  parts/placeholders ar vs en vs contract before writing the two Dart maps.
- Review rules (2026-09-29): special `current_stage_code` (not PHASE_n) shows the STAGE enum label
  (`ImportFileModel.codedStageLabel` / `displayStage`), coded phase ids use the renderer's 6 phase titles, legacy
  text rows keep DisplayNameResolver. Bidi isolates are stripped centrally (`core/utils/bidi_text.dart`
  stripBidiIsolates in CopyHelper, TableCopyHelper.cleanCell, TableExportService CSV, FileSaveHelper.saveText,
  EnterpriseDataTable copy); model helpers take `forExport: true` in export services.

Phase C guard (2026-09-30 baseline: only ai_agent_tool_executor, 31 sites; everything else fixed): `test/no_locale_dependent_payload_test.dart` + `test/no_locale_dependent_payload_baseline.json`
(per-file ratchet, UPDATE_LOCALE_PAYLOAD_BASELINE=1 regenerates, DUMP_LOCALE_PAYLOAD_SITES=1 lists sites). Hand-rolled
lexer (comments blanked, string bodies masked, `${}` kept) + payload regions (data:/queryParameters:/toJson/payload vars/
snake_case-key maps/*suffix* assignments). Skips values of `*_ar` keys, Arabic literals in `.contains(`/`==`, code->label
maps, lib/core/localization, export/pdf/print files. Remaining baseline = backend-mirrored Arabic (po_reconciliation
fallback = import_documentation/service.py, tariff customs_category = nafeza_text_parser) + AI tool prompts.
Frontend-created stored defaults (task titles, tracking notes) are English constants.

Document-comparison items (2026-09-30): `core/localization/system_messages/coded_item_text.dart` `CodedItemText`:
`localizeRow/localizeRows(item, l10n, forExport:)` renders every `X_code`+`X_params` (needs the `X_params` key) and
`structured_values` ({placeholder} | {number,unit} | {number:null,raw,unit}); tabs read the localized COPY, saving/loading
keep the raw map; exports pass `forExport:true` (strips isolates). Writer side for client-built items: `coded()`,
`finalize()` with `CodedPlaceholder` / `CodedMeasure` (mirrors backend coded_text / finalize_structured_values).
New DomainEnumTypes: customsCategory, valuePlaceholder, measureUnit. Checklist `reason` is user-editable: the tab clears
reasonCode/params when the text is typed (backend also drops stale codes). Tariff `customs_category` is a code; use
`CustomsTariffModel.categoryLabel(l10n)` / `categoryLabelArabic` / `categorySearchText`, never the raw field.
Client fallback "could not read" warnings have no backend code (stored English text only): ask backend for DOC_CHK_*_NOT_EXTRACTED.

Review wave (2026-10-05): 106 `*_note` codes appended to both catalogs by a generator (backend `sm.CATALOG` for en, a
`CODE: arabic` text file for ar; Dart literal escaping `\ $ '`). Renderer joins JSON list params (`Iterable`) with ", " / "، ".
19 new DomainEnumTypes (paymentType ... fileClosureStatus) have codes+legacy in domain_enum_labels.dart; their labels live
in `DomainEnums._supplementalLabels` ([en, ar]) because the l10n `_domainEnumLabels` maps were off-limits that session;
`_labelOf` tries l10n first, so moving them into the l10n maps later is safe. `status`/`doc_kind` params of the new codes
render verbatim (no `_enum_` infix), i.e. as raw codes.
