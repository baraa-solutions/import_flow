# flutter-developer memory

- Localization is hand-maintained Dart (no .arb / l10n.yaml): add each key to `app_localizations.dart`,
  `app_localizations_ar.dart`, `app_localizations_en.dart` (each ~10.5k lines).
- No data-grid package in `pubspec.yaml`: ~91 files hand-roll tables. Prefer extracting a reusable table widget
  over copying another one. Exports: `frontend/lib/core/services/master_data_export_service.dart` (~4.3k lines);
  the backend already generates Excel with openpyxl for some modules.
- Several screens exceed 3,000 lines (e.g. shipping_scenarios, po_form_dialog). Extract widgets, do not grow them.
- [In-app update feature](app_update_feature.md) — features/app_update: backend does download/verify/install; banner, dialogs, exit guard, test fakes
- [HTTP clients & auth](http_clients_auth.md) — only dioProvider/uploadDioProvider carry the JWT; /api/v1 path trap; no_bare_dio guard
- [Flutter 3.44 pitfalls](flutter_344_pitfalls.md) — SDK pin, ListTile/DataTable asserts, en_US locale in tests, AsyncError.value, perf flakiness
- [Localization edit pitfalls](l10n_edit_pitfalls.md) — scripted key inserts: apostrophes, abstract `get`, dialogs need provider above MaterialApp
- [Production sync retired](production_sync_retired.md) — no dev->prod sync/pull/build/launch in the app; compare + backups only
- [Backend launcher](backend_launcher.md) — frontend.exe starts/recovers backend.exe; /health system marker; Win32 path match; gate Stack trap
