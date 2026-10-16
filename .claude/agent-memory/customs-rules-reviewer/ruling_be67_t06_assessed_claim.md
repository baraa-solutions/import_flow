---
name: ruling-be67-t06-assessed-claim
description: BE67-T06 (PR #59, 2026-10-09) - is_assessed needs CL-02 claim; ge=0 money fields; characterization t4 fixture red
metadata:
  type: project
---

PR #59 (BE67-T06, head 20cda340), reviewed 2026-10-09.

- Money math OK: `validators.is_assessed` adds non-blank `nafeza_claim_number`; only CL-02 writes the claim
  (service ~953, min 3 chars). Create service never wrote claim/status anyway. ge=0 on money, gt=0 on customs rate.
- BLOCKER: `tests/unit/test_phase06_07_characterization.py::test_t4_cl03_variance_unrounded_amount_pct_rounded`
  seeds an "Assessed" record without a claim -> now 409 CC_DUTY_NOT_ASSESSED. Passes on main. Gate skipped it.
- test_t7 settlement snapshot red on PR head is the stale base (fixed on main by eff271ad), not the diff.
- Legacy rows assessed without a claim become unpayable until CL-02 is re-run (intended by the card).

**Why:** any change to is_assessed / payment gating hits fixtures that seed assessment_status directly.
**How to apply:** for customs_clearance gating changes run test_phase06_07_characterization.py and compare with main.
Related: [[ruling-cl03-duty-total-override]], [[ruling-be45-t02-recalc-before-push]].
