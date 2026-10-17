---
name: ruling-be45-t02-recalc-before-push
description: BE45-T02 (PR #52, 2026-10-09) review - push recalculates with stored rate, dual clock live; test_dd07 left stale and red
metadata:
  type: project
---

PR #52 (BE45-T02, diff vs company-pr/51 head 68e2ad70, head 811eb444), reviewed 2026-10-09.

- Money math OK: push recalculates via `_recalculate_containers` + `_apply_totals` with the tracking's stored rate
  (no new FX source); rows written from fresh totals; dual clock live total uses the same formula as `_apply_totals`.
  Card fixture (discharge 09-01, push 09-21, rate 50): carrier 240 USD / 12,000 EGP, storage 3,750 EGP, total 15,750.
- `is_provisional` also treats tracking-level empty_return_date as returned (matches recalc fallback) - accepted.
- BLOCKER: `tests/unit/test_phase04_05_fixes.py::test_dd07_push_uses_settlement_code_and_recalculates` still expects
  the stored totals (20.0 / 1000.0); with real today it gets 5690.0 / 284500.0. The CI gate did not run that file.

**Why:** the CI gate only runs tests mapped to changed files; older push tests seeded stored totals on purpose.
**How to apply:** for any "recalculate on push/read" change, run test_phase04_05_fixes.py and characterization tests too.
Related: [[ruling-phase04-05-insurance-demurrage]].
