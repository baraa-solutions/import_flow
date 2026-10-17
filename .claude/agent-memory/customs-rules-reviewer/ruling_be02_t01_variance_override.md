---
name: ruling-be02-t01-variance-override
description: PR #55 BE02-T01 (2026-10-09, b54179e5) budget hard-block override reset; approve gated on pending hard logs only; stale fn02 test red
metadata:
  type: project
---

PR #55 BE02-T01 (head b54179e5), reviewed 2026-10-09: code matches the card exactly (override reason/by cleared in
Pending/Revalidation branch; approve decides on `repo.first_pending_hard_block` only). No money math changed.
Override/sync resolve ALL pending logs via `_resolve_pending_logs`, so the unconditional check is safe.

Finding: `tests/unit/test_fn02_budget_approval_swift_mt103.py::test_approve_import_budget_hard_block_variance`
(lines 315-319) still sets `variance_override_reason` directly and expects approve to pass -> red at PR head
(255/256 in the 6 financial_approval files). Gate skipped it. Ruled MAJOR (card says characterization stays green).

**Why:** same pattern as [[ruling-be45-t02-recalc-before-push]]: the gate runs only tests tied to changed files.
**How to apply:** on re-review, check that test now uses `override_budget_variance_service` (or marks the log overridden).
