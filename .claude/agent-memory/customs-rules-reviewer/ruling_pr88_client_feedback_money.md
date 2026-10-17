---
name: ruling-pr88-client-feedback-money
description: PR #88 client feedback (no task card) money lens - duty calculator rate, partner SOA equivalent EGP, free-days/credit terms
metadata:
  type: project
---

Ruling 2026-10-09, PR #88 (client-requested, judged vs PR description, not TASKS.md).

- duty_calculator_dialog.dart: 50.7917 removed; uses CurrencyModel.latestCustomsRate, empty when missing, blocks calc when rate<=0. Accepted for a what-if simulator (no declaration date). Leftover: `_numToDouble(multiResult!['exchange_rate'], 1.0)` in exports (MINOR); 2.5%/2% deemed factors pre-existing.
- external_service_providers/service.py SOA: BLOCKER invented FX fallback {USD 50, EUR 54.5, GBP 63.5}, unknown ccy -> 1.0; commercial rate labelled "Official"; CL-05 invoices added on top of settlement expense_invoices which already contain CL-05 rows (double count); ilike %name% substring match. No backend test.
- default_free_days: backend default dropped to None, but partners_screen.dart:2028 and extractor :810 still send `?? 14`; scorecard uses `or 14`. payment_terms is free text, no due-date calculation exists despite PR claim.

**Why:** consistent rulings when PR #88 is re-reviewed.
**How to apply:** on re-review, verify these exact spots; treat FX fallback dicts as BLOCKER always (see [[ruling-bew0-01-fx-resolver]]).
