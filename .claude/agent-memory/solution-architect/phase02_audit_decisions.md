---
name: phase02-audit-decisions
description: 2026-10-05 Phase-2 (financial_approval) audit traps — best_effort rolls back, no FA manage permission, tests pinning Draft->Paid, 50.0 FX default
metadata:
  type: project
---

Plan: docs/plans/phase-02-quality-plan.md (proposed 2026-10-05; check git for status).

Non-obvious facts:
- `modules.common.errors.best_effort` does `db.rollback()` on failure, so it is only safe AFTER the core commit (the customs_consultation post-commit pattern). Never wrap in-transaction side effects with it.
- RBAC has only financial_approval.view / .approve and budget.sync_variance; there is no create/edit code, so a new `financial_approval.manage` was proposed (Q1). The seeded roles have no "MANAGER" code (it is GENERAL_MANAGER), but the FA service checks "MANAGER".
- Existing tests pin bugs: test_financial_approval.py ~l.412 reconciles a Draft request to Paid; test_fn02 creates a request with status="Approved".
- `evaluate_and_record_budget_variance_service` is called by customs_consultation via best_effort and commits itself; keep its signature.
- `next_yearly_code` skips non-digit suffixes (GLOB), so the BGT `-REV2` codes are safe with it.
- `import_file_code` in the FA responses is never filled; Flutter falls back to IMP-{id}.

**Why:** these shape the Phase-2 fixes and any later finance work.
**How to apply:** check the plan's Q1-Q7 answers before touching FA permissions, statuses or FX fallbacks.
