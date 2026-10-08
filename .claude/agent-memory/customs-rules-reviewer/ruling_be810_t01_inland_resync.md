---
name: ruling-be810-t01-inland-resync
description: PR #21 BE810-T01 (2026-10-07) - ImportFile.inland_transport_cost_egp = sum of active booking fares; settlement TR-IMP fallback safe; CI 401 not from diff
metadata:
  type: project
---

PR #21 (BE810-T01, 2026-10-07): `sync_file_inland_fields` sets `ImportFile.inland_transport_cost_egp` to
round(sum(active fares), 2), 0.0 when none. Ruled correct for money: settlement (`financial_settlement/service.py:1743`)
only uses the file cost as fallback when no active booking has fare > 0, and after resync that cost is 0 in that case,
so a deleted / corrected-to-0 fare can no longer produce a TR-IMP line. All amounts EGP, rate 1.0 is legitimate here.

- CI failure was `test_inland_transport_rest_api` 401: passes in isolation at PR head (10/10 in the file); same
  order-dependent ALLOW_DEV_AUTH_BYPASS leak seen on PRs #18/#20, see [[ruling-bew0-06-settlement-gate]].

**Why:** keeps later inland / settlement reviews consistent.
**How to apply:** any new writer of `inland_transport_cost_egp` (outside inland_transport service) would break the sum invariant - flag it.
