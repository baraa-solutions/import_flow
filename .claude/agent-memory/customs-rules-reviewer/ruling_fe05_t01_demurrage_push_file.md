---
name: ruling-fe05-t01-demurrage-push-file
description: FE05-T01 (PR #80) 2026-10-09 ruling - demurrage push never defaults import file; confirm dialog displays backend totals only
metadata:
  type: project
---

PR #80 (FE05-T01), reviewed 2026-10-09: `?? 1` removed, unlinked tracking blocked (button disabled + SnackBar), payload omits import_file_id when null. Backend push already uses tracking.import_file_id first and posts amount_fx x tracking.exchange_rate, so dialog totals (stored total_cost_egp) match what is posted. Flutter computes no money.

**Why:** consistent rulings across demurrage reviews.
**How to apply:** model still coerces null totals to 0.0 and currency to 'USD' (pre-existing, MINOR, not the PR's scope); see [[ruling-be45-t04-nullable-free-days]].
