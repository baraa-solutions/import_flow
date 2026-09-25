---
name: l10n-edit-pitfalls
description: Traps when bulk-inserting keys into the hand-maintained localization files and when testing dialogs that use context.l10n
metadata:
  type: project
---

- Scripted inserts: English strings with apostrophes (What's, Don't) break single-quoted Dart literals; emit
  those as double-quoted strings. Abstract getters must be `String get key;` (a bare `String key;` is a field
  and produces ~30 "non-final field / must be initialized" errors on the const constructor).
- The three files are ~11k lines; `flutter analyze lib/core/localization` takes ~2 min. Keep edits small (a long
  single edit once stalled the run).
- `AppLocalizationsProvider` sits ABOVE `MaterialApp` in main.dart. Widget tests that open dialogs must wrap
  `MaterialApp` in it too; wrapping only `home:` makes `context.l10n` fail inside dialog routes.
- A source-scan test (`test/update_localization_test.dart`) checks every declared `update*` key has an
  `@override` in ar and en; copy that pattern for new sections.

**Why:** hit on the app_update task (2026-09-24).
**How to apply:** before adding a batch of keys or a dialog test.
