---
paths:
  - "frontend/lib/**/*.dart"
  - "frontend/test/**/*.dart"
---

# Flutter rules (Windows desktop, Riverpod)

- Screens / widgets: use the `ui-screen-standards` skill before building or refactoring a screen.
- Colours only from `frontend/lib/core/theme/app_theme.dart`; no raw hex in widgets.
- Every user-facing string goes into all three localization files:
  `frontend/lib/core/localization/app_localizations.dart` (abstract), `_ar.dart`, `_en.dart`. RTL-safe layouts
  (EdgeInsetsDirectional / AlignmentDirectional; `rtl_directional_guard_test` fails on physical left/right).
  New backend message codes / enum codes also go into `system_messages/system_message_catalog_{ar,en}.dart` and
  `domain_enum_labels.dart` (parity tests fail otherwise). In parallel waves edit l10n only inside your marker block.
- Unknown values stay unknown: no `?? 50.0` / `?? 1.0` rates or `?? 0.0` money shown as real numbers; null money
  renders as "—". Numeric inputs keep a stable controller (no Key/initialValue churn per keystroke).
- Reference-data pickers (HS code, country, port, company, supplier, incoterm, project, partner/bank,
  linked PO) use `SearchableDropdownField<T>` from `frontend/lib/core/widgets/searchable_dropdown_field.dart`.
- Forms: `Form` + real validators; show backend errors. Reload on screen mount; `ref.invalidate(...)` after
  every write. Loading indicator inside buttons during async actions.
- Endpoints come from `frontend/lib/core/constants/api_constants.dart`. Flutter never knows DB details.
- Do not grow multi-thousand-line screen files; extract widgets into the feature's `widgets/`.
- Mouse Drag-Selection: Every screen root, modal, dialog, calculator, and review sheet MUST be wrapped in `SelectionArea` to enable full mouse text and number highlighting and selection.
- Sanitized Clipboard: Zero direct `Clipboard.setData(...)` calls. All clipboard writes must pass through `CopyHelper.copy(context, text)` or `TableCopyHelper.copyTable(context, ...)` to strip invisible Bidi Unicode isolates (`\u2066`, `\u2067`, `\u2069`).
- Anti-Stacking & Pure Views: Zero parenthesized bilingual stacking (e.g. `(PO)`, `(Terminal / Depot)`). Pure Arabic in Arabic mode, pure English in English mode. Backend/DB constants remain in Tier 2 English (`PENDING`, `CUSTOMS_RELEASE`).

