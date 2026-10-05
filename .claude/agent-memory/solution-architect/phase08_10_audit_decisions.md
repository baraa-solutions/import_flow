---
name: phase08-10-audit-decisions
description: 2026-10-05 Phase 8/10 audit — non-obvious traps (fail-open closure gate, invalid SystemNotification kwargs, grn_number typo, reopen restores Phase 1) and the Q1-Q9 decisions
metadata:
  type: project
---

Plan: docs/plans/phase-08-10-quality-plan.md (proposed 2026-10-05; check git for status).

Traps that are hard to see in the code:
- SystemNotification has NO notification_code / import_file_id / created_by columns. Passing them raises TypeError, and callers inside try/except-pass never create the row (inland_transport). Grep other modules for the same kwargs.
- ImportFile has no `closed_at` column. Setting it is silently dropped. `closed_at_phase` is what reopen (import_files/service.py) uses, and file_closure never set it, so reopen always went back to Phase 1.
- The file_closure checklist schema defaults every flag to True, and its DB checks are try/except-pass, so the gate fails open. Precheck and close use different customs criteria.
- warehouse_receiving reads a non-existent `grn_number`, so its audit log was never written.
- Inland transport has no permission code in the catalog; the default is to reuse warehouse_receiving.*.

**Why:** these change how any later plan for closure, notifications or reopen should be designed.
**How to apply:** check the plan's Q1-Q9 answers before planning closure gates, GRN quantity rules or inland permissions.
