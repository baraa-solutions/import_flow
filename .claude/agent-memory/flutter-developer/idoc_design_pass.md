---
name: idoc-design-pass
description: import_documentation package-A design pass - idoc_ui.dart helper, mechanical sweep recipe (colors/buttons/l10n), pitfalls
metadata:
  type: project
---

- `features/import_documentation/widgets/idoc_ui.dart`: IdocUi.fit/metrics/sectionTitle, IdocStatusChip(.fromStatus),
  IdocSectionCard, IdocFact, IdocBanner, IdocStateView.{empty,error,loading}, IdocDialogShell (charcoal header + action bar).
- Sweep recipe that worked on 25k lines: regex Colors->AppTheme with dynamic `*Of(context)` forms, run `flutter analyze`,
  revert only the lines reported as const errors to the const forms; same loop removes `const` for l10n calls.
- AppButton rows do not shrink: wrapping every AppButton in `IdocUi.fit` fixed 100-370px overflows in tablet/mobile tests.
  Tests that cast to OutlinedButton/ElevatedButton must use AppButton (keys stay on the AppButton).
- l10n keys with interpolation are generated as `String key(Object? a0, ...)`; never call `context.l10n` in initState.
- Shell heredocs mangle backslashes (`\b`, `\n`, `\'`): write python scripts with the Write tool, use chr(92)/chr(10).
- `idocA` keys live between the phase03 markers; B-agent keys (`idocB`) sit in a separate `phase03_ui_b` block.
