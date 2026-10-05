---
name: customs-clearance-fe-pitfalls
description: customs_clearance / quotations FE conventions - provider refresh with kept filters, under-bond contract, ApiErrorText, SearchableDropdown swaps, save helper facts
metadata:
  type: reference
---

- `CustomsClearanceNotifier` keeps the last `fetchRecords` filters; every mutation ends with `_invalidateRelated()`
  (importFiles + smartTasks) then `refresh()`. New mutations should follow that, not call `fetchRecords()` bare.
- Under-bond / lab dialog goes through `releaseUnderBond` / `recordLabTestResult` (provider, not raw dio). Payload
  builders `buildUnderBondPayload` / `buildLabResultPayload` live in `under_bond_release_dialog.dart` (tested).
  Lab verdict codes are `CONFORMING` / `NON_CONFORMING`; backend route is `/lab-test-result`.
- `ApiErrorText.of(l10n, e)` already renders structured `detail {code,message}` and 403; use it in every SnackBar
  instead of `$e`.
- `FileSaveHelper.saveText` -> `saveBytes` -> `FilePicker.saveFile` (Save-As dialog, lockParentWindow) - it is compliant;
  exportAndSaveFile only adds the "[Stage] - [Code]" file naming. Quotation exports still use timestamp names.
- `SearchableDropdownField` is a FormField with `key` support; for small enum lists pass `isDense: false` + a
  `decoration` with OutlineInputBorder to keep the old look. `labelText` is the picker dialog title.
- Do not hard-code VAT/WHT/customs FX in dialogs (DOMAIN_RULES section 2): fields are manual and start empty.
- Scratchpad dir is shared by parallel agents: use a unique subfolder for helper scripts (a generic `addkeys.py`
  was overwritten by another agent). Bash heredocs with many quotes sometimes fail to parse: write the script
  with the Write tool instead.
- Full-suite-free test run of this feature: `flutter test test/features/customs_clearance* test/cl0*.dart test/cs0*.dart -j 1`
  takes > 10 min; run in background.
- Visual pass (phase06_07): feature-local helpers `customs_clearance/widgets/customs_ui.dart` (CcFormat money/date, CcStatusChip,
  CcSectionCard, CcStateView, CcMoneyText, CcDateField, CcUi.metrics) and `cc_dialog_shell.dart` (CcStageDialogShell header/body/footer,
  CcFormSection, CcField, CcFieldRow, ccInputDecoration). Quotations import the same helpers.
- Shell footerLeading must be a plain widget (shell wraps it in Expanded); a Flexible inside a Row footer collapses to ~0 width.
- MetricCard (core) overflows when value text is wide (chip padding not subtracted): keep metric values numeric, put currency in the title.
- Test fonts are Ahem (wide): amounts like '165,801.50 ج.م' use CcFormat.money; test finders expect grouped numbers.
- Dialogs in tests are pumped directly in a Scaffold (800x600 logical): footers must not rely on wide space.
