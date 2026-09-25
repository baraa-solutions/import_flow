---
name: flutter-344-pitfalls
description: Flutter 3.44 pinned SDK; new debug asserts (ListTile, DataTable semantics), locale-in-tests trap, Riverpod AsyncError.value, perf-test flakiness
metadata:
  type: project
---

SDK is pinned: pubspec `flutter: '>=3.44.0 <3.45.0'`, CI `flutter-version: '3.44.6'` (decided 2026-09-24).
Web file saver uses `dart:js_interop` + `dart:js_interop_unsafe` (no `dart:html` / `dart:js_util`, no `package:web`
dependency); conditional export keys on `dart.library.js_interop`.

New framework asserts that fail widget tests:
- `ListTile` / `CheckboxListTile` / `SwitchListTile` directly inside a coloured `Container`/`DecoratedBox` ->
  "ListTile background color or ink splashes may be invisible". Wrap the tile in
  `Material(type: MaterialType.transparency, child: ...)`.
- `DataColumn(onSort: ...)` plus an `InkWell` in the label -> "A columnHeader must be a child or another cell".
  Use one tap target only.
- `ref.invalidate/read` in `ConsumerState.initState` can trip "dependOnInheritedWidgetOfExactType called before
  initState completed"; use `ProviderScope.containerOf(context, listen: false)` there.

Test traps:
- `MaterialApp(locale: Locale('ar'))` has no `supportedLocales`, so `Localizations.localeOf()` is `en_US` in
  tests AND in the real app (main.dart doesn't set supportedLocales either). Widgets that branch on
  `Localizations.localeOf(...).languageCode == 'ar'` render English; widgets using `Directionality` or
  `context.l10n` render Arabic. Assert accordingly.
- Riverpod 2 `AsyncValue.value` RETHROWS on AsyncError; in build use `valueOrNull`.
- `test/perf/*` assert wall-clock thresholds in debug mode. They carry `@Tags(['perf'])` and
  `frontend/dart_test.yaml` skips that tag by default (lead decision 2026-09-24). New perf tests must add the
  tag; run with `flutter test --run-skipped -t perf -j 1 test/perf`. Full suite with default concurrency once
  exhausted OS threads ("Could not start thread DartWorker") while a web build ran in parallel; use `-j 4`.
  Only timing tests are skipped: files mixing timing + functional tests use per-test `tags: ['perf']`
  (reviewer rule: functional assertions must never be skipped); fully functional files live outside test/perf.
- DedicatedStageScaffold header uses `AdaptiveStageHeaderLayout` (custom RenderBox in the same file): it
  measures the lifecycle controls + actions and falls back to two rows, so Skip Step / Hold & Stop are never
  clipped (reviewer blocker). `PageHeader` is always a `Scaffold.appBar` with a fixed preferredSize, so it
  can't wrap: actions scroll in a capped strip with a visible scrollbar. Toolbars with free height
  (bank_form4 registry) use `Wrap`. DataTable heading labels get UNBOUNDED width: no `Expanded` there.
  MetricCard values scale via `FittedBox(scaleDown)` in a capped box, never truncated.
- Titles in Type A / Dedicated headers truncate with ellipsis on purpose (83f71fc); tests assert that.
- VS 2026 (toolset v145, CMake 4.3) is installed at D:\vsc (2026-09-25): `flutter build windows --release` works
  locally (~6 min); dumpbin: D:\vsc\VC\Tools\MSVC\<ver>\bin\Hostx64\x64\dumpbin.exe. The MSVC CRT ships app-local
  via InstallRequiredSystemLibraries in windows/CMakeLists.txt (a clean Windows lacked MSVCP140.dll).
- Bash-tool heredocs collapse `\\` to `\` (and Python then turns `\b`/`\v` into control chars): write edit
  scripts with the Write tool, and check Dart path literals with `od -c`.

**Why:** 269 test files were silently failing to load before the pin; unmasking revealed these.
**How to apply:** check these before debugging a newly failing widget test.
