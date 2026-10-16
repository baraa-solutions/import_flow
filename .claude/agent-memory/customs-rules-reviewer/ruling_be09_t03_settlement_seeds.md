---
name: ruling-be09-t03-settlement-seeds
description: BE09-T03 PR #49 (2026-10-09) review - settlement expense recalc seeds retired; run_seed is never called at boot
metadata:
  type: project
---

PR #49 (BE09-T03) retires the 3 financial_settlement expense seeds (freight/customs/clearance) into
RETIRED_DEPENDENCY_SEEDS and deactivates them in run_seed. The money logic is correct, and the 30 related tests pass.
Ruling: run_seed (modules/recalculation/seed_dependencies.py) is only reachable through `__main__`. Neither boot nor Alembic calls it,
so existing DBs keep the active expense rows until someone runs it by hand. I rated this MAJOR (deploy step), not BLOCKER.

**Why:** the card's acceptance criterion is phrased "after run_seed", so the PR meets the card as written.
**How to apply:** for later seed-only fixes, check how the seed reaches deployed DBs (a startup hook or a data migration).
Related: [[ruling-phase09-settlement]] (Q1 recalc gaps).
