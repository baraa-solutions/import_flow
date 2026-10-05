---
name: warehouse-inland-closure-patterns
description: Patterns and pitfalls from the phase 8-10 FE fixes (GRN form, inland transport dialog, file closure dialogs)
metadata:
  type: project
---

- GRN form lives in `warehouse_receiving/widgets/warehouse_receiving_form_dialog.dart`; the pure per-line rule
  (accepted + shortage + damaged == invoiced, excess only without shortage/damage) is `models/grn_line_balance.dart`.
  A create always issues a real GRN server-side: there is no draft save, and `status` is never sent.
- Closure dialogs show the SERVER checklist (precheck `checklist_status`) read-only; missing keys count as not passed.
  Official close dialog switches to a "closed" view (certificate export + lesson dialog) instead of pop-then-showDialog.
- Lookups that gate a create form (`fetchBookingByFile`) must rethrow errors; the dialog shows error + retry, never the form.
- Backend `detail` dicts: `ApiErrorText.of(l10n, e)` renders the catalog text or the `message`; use it for every SnackBar.
- Provider mutations remember the last list filters (`_refetch`) and invalidate importFiles + smartTasks.
- Test pattern: fake `HttpClientAdapter` + `dioProvider.overrideWithValue`, `localizedApp(locale: AppLocales.english)`, open the
  dialog via a button (a root-route dialog cannot `Navigator.pop`). Import `app_localizations_en.dart` for `const AppLocalizationsEn()`.
- Tooling pitfall: in this shell a `python - <<'EOF'` heredoc containing many quotes can die with "unexpected EOF";
  write the script with the Write tool and run it. Files may be CRLF on disk but LF in the index: read with
  `newline=''`, normalise, write back with the original line ending.
- Marker-block l10n inserts: a small script that reads each file right before writing and skips existing keys is safe
  when another agent shares the block.
- Design pass kit: `warehouse_receiving/widgets/ops_ui_kit.dart` (OpsStatusChip, OpsSectionCard/Header, OpsInfoBanner, OpsStateView, OpsActionWrap/OpsFit,
  OpsTableStyle). Promote to core when stable. Pitfalls: `SwitchListTile` inside a coloured Container needs `Material(type: transparency)`;
  `IntrinsicHeight` cannot contain a `LayoutBuilder`; `Dialog.insetPadding` takes `EdgeInsets` (not Directional); core `AppButton` label is not
  Flexible (wrap in OpsFit on narrow layouts); `MetricCardStrip` swaps to short titles when tight (set `shortTitle: title` to keep texts).
- Use scratchpad python files (Write tool) + replace/splice scripts for edits; bash heredocs with quotes die.
