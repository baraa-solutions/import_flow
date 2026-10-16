---
name: settlement-engine-total-contract
description: After BEW0-06 (PR #20) settlement total_expenses_egp is the engine sum of amount_egp; tests hand-summing net_payable_egp or rows without amount_egp fail
metadata:
  type: project
---

Since BEW0-06 (merged 2026-10, commit fed897cc/c9e0eaf4) `_sync_settlement_snapshot` calls
`recalculate_settlement_totals` -> `calculate_landed_cost_engine`, which counts each row at `amount_egp`
(fallback `amount_fx * exchange_rate`), never `net_payable_egp`. Clearance VAT is excluded (customs-rules-reviewer
ruling: recoverable input VAT; card be-09-review.md BE09-T04 step 3).

Symptom seen 2026-10-08: test_phase06_07_characterization T-7 expected 100 + 1368 = 1468, got 1200, because
(a) the engine used 1200 not 1368 and (b) the fixture Freight row had only `net_payable_egp` so it counted 0.
The test was wrong (old contract), not the code.

**Why:** characterization tests written before BEW0-06 pin the deleted hand-written sum.
**How to apply:** for any settlement-total mismatch, first check fixture rows carry `amount_egp` and expectations
use amount_egp, before suspecting the engine. See [[legacy-null-list-500]].
