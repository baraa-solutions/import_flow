---
name: financial-approval-patterns
description: financial_approval feature - no fallback FX rate, AsyncActionButton, coded 409 handling, dio fake adapter for provider tests
metadata:
  type: project
---

- No client-side fallback exchange rate: `_getExchangeRateForCurrency` returns null, rate field empty + validator,
  save blocked with `faFxRateMissing(currency)`. Model defaults are 0.0; exports print "-" when rate <= 0.
- `widgets/async_action_button.dart` (AppButton + spinner + SnackBar via `ApiError.message`) for approve/pay actions in dialogs.
- Backend 409 is not always an optimistic-lock conflict: `_isVersionConflict` checks `current_version` in the detail;
  coded detail maps (`{code,message}`) go to a SnackBar (core `ErrorFormatter` ignores Map details).
- Provider notifiers remember the last list filters and `_refresh()` with them; lifecycle-moving mutations call
  `_invalidateImportFiles()`. Prefill / variance-log fetches rethrow (callers show the error).
- Supplier advance dialog payload must use `PaymentRequestCreate` keys (`requested_amount`, `currency_code`, `po_id`,
  `supplier_name`, `iban_account_no`); it used wrong keys before.
- Provider tests: Dio with a route-table `HttpClientAdapter`, override `dioProvider` + `uploadDioProvider`; settle with
  >=150 ms (slow machine) before counting refetches; Dart cascades swallow `=> expr` lambdas, use a method (`on(key, fn)`).
- Visual pass done: Colors/hex -> AppTheme tokens, AppButton everywhere, l10n keys `fa*` in the phase02 block.
  `widgets/financial_ui.dart` = FinancialUi (status chip via AppSeverity, `fit()` for AppButton, `metrics()`,
  payment type codes + `normalizePaymentType`, FinancialStateView). Deferred now only FE-10 (god files).
- AppButton's inner Row is not Flexible: in narrow Rows/Columns it overflows -> wrap with `FinancialUi.fit`.
  MetricCardStrip overflows below ~760px: use `FinancialUi.metrics` (1/2 column MetricCards when narrow).
- Bulk-edit via Python scripts: Dart `const` parents of newly non-const l10n calls break (`invalid_constant`);
  strip `const` from the flagged ancestors. Tests with bare MaterialApp need `localizedApp(locale: en)`.
- `launchUrlNative` = no shell, Uri.tryParse + http/https/mailto/tel allowlist, Process.start explorer.exe.
- Full screen10 widget test file can flake once under load ("did not complete"); rerun before suspecting code.
