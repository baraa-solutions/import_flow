---
name: ruling-bex-t10-money-aggregates
description: BEX-T10 PR #62 review 2026-10-09 - project USD commitments via EGP pivot, master report per currency; projects screen hides null totals
metadata:
  type: project
---

PR #62 (22a63111), reviewed 2026-10-09: approve_with_minor.
- Card numeric cases reproduce (20,886.60 / 79,113.40 / 20.9; EUR missing -> None; master report per currency). 23 tests green
  (test_money_aggregates, test_import_files, test_pl03).
- Accepted: `_get_rate_to_egp` commercial, as of today (card says so); per-currency subtotals rounded to 2dp before
  conversion is harmless (PO amounts are Numeric(14,2)).
- Findings: projects_screen.dart ~718 hides commitments when total_committed_usd is None (no "—", no missing_rate_currencies);
  `usd_rate_to_egp > 0` guard (service.py:67) silently drops non-USD amounts if USD rate is 0; inner join on Currency
  drops POs with dangling currency_id (FK not enforced, BEX-F26).

**Why:** keep later projects/report reviews consistent.
**How to apply:** treat EGP-pivot commercial conversion for budget views as the agreed pattern (see [[ruling-bew0-01-fx-resolver]]).
