---
name: phase06-07-audit-decisions
description: 2026-10-05 Phase 6/7 customs audit: traps (lifecycle commits inside, best_effort rollback order, settlement reads actual_duty_total) and open CTO questions
metadata:
  type: project
---

Plan: docs/plans/phase-06-07-quality-plan.md (proposed 2026-10-05; check git for status).

Non-obvious facts:
- `lifecycle_board.advance_lifecycle_step_service` commits internally (l.375/480), so any service calling it mid-flow is not one transaction.
- `errors.best_effort` rolls back, so calling it before the main commit discards the business write: commit first, then side effects.
- financial_settlement uses clearance `actual_duty_total` (status "Final Release Granted") and `total_duty_payable`/`duty_paid_amount`, so clearance status labels and these fields are load-bearing.
- SmartTask has no `completion_notes` / `task_name` / `completed_at` columns; several modules assign them silently.
- Flutter under-bond/lab dialog never matched the backend contract (wrong path, missing required fields).

**Why:** these shape any later customs/landed-cost plan.
**How to apply:** check Q1-Q10 answers in the plan before touching duty payment, release, invoice VAT or quote currency logic.
