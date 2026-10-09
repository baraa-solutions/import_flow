---
name: ruling-bew0-01-fx-resolver
description: PR #18 BEW0-01 shared FX resolver review (2026-10-07) - verdict, leftover 48.50 fallback, CI 401 flake not from the diff
metadata:
  type: project
---

PR #18 (BEW0-01) removed `fallback_rates` from `CurrencyService._get_rate_to_egp` (404 CURRENCY_NOT_FOUND, 409
CURRENCY_RATE_MISSING, misses not cached) and added `customs_tariff.service._customs_rate` (422 CT_CUSTOMS_RATE_MISSING).
Ruled approve_with_minor on 2026-10-07.

- Leftover invented FX: `modules/freight_data_connector/service.py:332` `req.exchange_rate_usd_egp or 48.50` (no task card covers it as of 2026-10-07).
- Resolver still caches/returns a 0.0 rate row (no `<= 0` check); `convert_currency` divides by the target rate.
- CI "401 instead of 200" on TestClient tests (test_customs_consultation_recalculation, test_clo04, test_bk01) appears on
  unrelated PRs (#17, #19, #39): test-isolation problem from main, not caused by FX diffs.

**Why:** keep later FX-related reviews (BE01-T01, ACC1-T01, BE67-T04...) consistent with this baseline.
**How to apply:** when a later PR touches FX, check whether it closes the 48.50 leftover and the zero-rate gap; don't blame a PR for the 401 flake without a diff link.
