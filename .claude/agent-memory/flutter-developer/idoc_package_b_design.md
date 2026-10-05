---
name: idoc-package-b-design
description: Phase 03c package B design pass (ACID, Form 46, COO, inspection, bank form 4) - shared widgets, scripted sweeps, test traps
metadata:
  type: project
---

- Shared pieces live in `import_documentation/widgets/idoc_ui_b.dart` (IdocBSectionCard, IdocBNotice, IdocBStatusChip,
  IdocBStateView, IdocBMoneyTable/Line, IdocBDialogShell, IdocBActionBar, IdocBUi.metrics/fit) and
  `form46_figures_panel.dart` (itemised editable money table, keeps decl46* keys and the decl46FiguresBanner key).
- Scripted sweeps (python with a paren-matching parser) converted Elevated/Outlined/TextButton -> AppButton and
  Colors/hex -> AppTheme. After AppButton conversion mobile (390px) tests overflow because AppButton cannot shrink:
  wrap long-label buttons in `IdocBUi.fit(...)` (FittedBox scaleDown; no effect in unbounded Rows).
- `MetricCardStrip` overflows long Arabic labels when each card is < ~300px: `IdocBUi.metrics` falls back to a wrapped grid.
- Dialog shells opened from a screen must be wrapped in `AppLocalizationsProvider` (tests have no provider above MaterialApp).
- Stored default text (clone notes) uses `storedText` (English), not `context.l10n`.
- responsive_and_clone_screen12 test 4 asserts a fabricated ACID in the MTS sample text; the sample was neutralised in the
  correctness pass, so that assertion is stale (not a design regression).
- In bash heredocs avoid a bare `cat > file` without input (hangs); write large Dart/python edits with the Write tool
  and splice with a small script.

**Why:** hit during the package-B design pass (2026-10-05).
**How to apply:** reuse the widgets; for more AppButton conversions rerun the mobile responsive tests.
