---
paths:
  - "frontend/lib/**/*.dart"
  - "frontend/test/**/*.dart"
---

# Flutter rules (Windows desktop, Riverpod)

- Screens / widgets: read `.agents/rules/UI_SCREEN_STANDARDS.md` before building or refactoring a screen.
- Colours only from `frontend/lib/core/theme/app_theme.dart`; no raw hex in widgets.
- Every user-facing string goes into all three localization files:
  `frontend/lib/core/localization/app_localizations.dart` (abstract), `_ar.dart`, `_en.dart`. RTL-safe layouts.
- Reference-data pickers (HS code, country, port, company, supplier, incoterm, project, partner/bank,
  linked PO) use `SearchableDropdownField<T>` from `frontend/lib/core/widgets/searchable_dropdown_field.dart`.
- Forms: `Form` + real validators; show backend errors. Reload on screen mount; `ref.invalidate(...)` after
  every write. Loading indicator inside buttons during async actions.
- Endpoints come from `frontend/lib/core/constants/api_constants.dart`. Flutter never knows DB details.
- Do not grow multi-thousand-line screen files; extract widgets into the feature's `widgets/`.
