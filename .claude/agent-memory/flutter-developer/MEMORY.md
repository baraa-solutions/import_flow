# flutter-developer memory

- Localization is hand-maintained Dart (no .arb / l10n.yaml): add each key to `app_localizations.dart`,
  `app_localizations_ar.dart`, `app_localizations_en.dart` (each ~10.5k lines).
- No data-grid package in `pubspec.yaml`: ~91 files hand-roll tables. Prefer extracting a reusable table widget
  over copying another one. Exports: `frontend/lib/core/services/master_data_export_service.dart` (~4.3k lines);
  the backend already generates Excel with openpyxl for some modules.
- Several screens exceed 3,000 lines (e.g. shipping_scenarios, po_form_dialog). Extract widgets, do not grow them.
- Auto-updater: `frontend/lib/features/production_sync/services/auto_updater_service.dart` launches the installer
  with `/SILENT` after only a size check (no hash verification).
- [HTTP clients & auth](http_clients_auth.md) — only dioProvider/uploadDioProvider carry the JWT; /api/v1 path trap; no_bare_dio guard
