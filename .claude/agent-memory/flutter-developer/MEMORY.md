# flutter-developer memory

- Localization is hand-maintained Dart (no .arb / l10n.yaml): add each key to `app_localizations.dart`,
  `app_localizations_ar.dart`, `app_localizations_en.dart` (each ~10.5k lines).
- No data-grid package in `pubspec.yaml`: ~91 files hand-roll tables. Prefer extracting a reusable table widget
  over copying another one. Exports: `frontend/lib/core/services/master_data_export_service.dart` (~4.3k lines);
  the backend already generates Excel with openpyxl for some modules.
- Several screens exceed 3,000 lines (e.g. shipping_scenarios, po_form_dialog). Extract widgets, do not grow them.
- [In-app update feature](app_update_feature.md) — features/app_update: backend owns install; host/pill/banner, per-user snooze, phase, test fakes
- [HTTP clients & auth](http_clients_auth.md) — only dioProvider/uploadDioProvider carry the JWT; /api/v1 path trap; no_bare_dio guard
- [Flutter 3.44 pitfalls](flutter_344_pitfalls.md) — SDK pin, widget asserts, test locale, perf tags, local Windows build + app-local MSVC CRT, heredoc escapes
- [Localization edit pitfalls](l10n_edit_pitfalls.md) — scripted key inserts: apostrophes, abstract `get`, dialogs need provider above MaterialApp
- [Production sync retired](production_sync_retired.md) — no dev->prod sync/pull/build/launch in the app; compare + backups only
- [Backend launcher](backend_launcher.md) — frontend.exe starts/recovers backend.exe; /health system marker; Win32 path match; gate Stack trap
- [Single-language storage](single_language_storage.md) — DomainEnums, storedText, clone suffixes, SystemMessageRenderer, phase C payload guard
- [Warehouse / inland / closure patterns](warehouse_inland_closure_patterns.md) — GRN line balance, server-owned closure checklist, rethrow lookups, test setup
- [Arabic RTL wiring](rtl_wiring.md) — AppLocales, localizedApp helper, DirectionalIcon rule, LTR islands, rtl guard ratchet, digits
- [Settlement form pitfalls](settlement_form_pitfalls.md) — create payload rules, approvedBy override trap, stub-Dio provider tests
- [Financial approval patterns](financial_approval_patterns.md) — no fallback FX rate, AsyncActionButton, 409 handling, dio fake adapter tests
- [Customs clearance FE](customs_clearance_fe_pitfalls.md) — provider refresh/filters, under-bond contract, ApiErrorText, save helper facts
- [Phase 4/5 FE pitfalls](phase04_05_fe_pitfalls.md) — CRLF inserts, heredoc backslashes, mock getters, flaky multi-file test runs
- [Idoc design pass](idoc_design_pass.md) — idoc_ui.dart helpers, sweep recipe, AppButton overflow fix, script pitfalls
- [Form 46 / COO no-fallback](form46_no_fallback.md) — calculator, missing markers, export guards, test overrides
- [Idoc package B design](idoc_package_b_design.md) — shared idoc_ui_b widgets, scripted sweeps, mobile overflow / test traps
- [Freight booking design](freight_booking_design.md) — Fbk widget split, no-sample-defaults, FormField staleness, ENOSPC / cross-agent compile breaks
- [Design tokens & theme](design_tokens_theme.md) — AppTheme semantic tokens, AppSeverity, snackBar helper, Arabic letterSpacing rule
