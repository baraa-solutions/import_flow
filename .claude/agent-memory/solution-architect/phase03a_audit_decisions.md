---
name: phase03a-audit-decisions
description: Phase 3a (import_documentation backend) audit decisions - permission mapping, server-owned review status, fabricated-default rule, D1/D2 file split
metadata:
  type: project
---

2026-10-05, plan `docs/plans/phase-03a-quality-plan.md` (proposed, not implemented).

- Permission mapping chosen: `import_documentation.view` for reads/compare, `.upload` for writes and upload/extract
  (OCR + optional external LLM), new `import_documentation.approve` for B/L approval. ACID kept under
  import_documentation (not cargox_nafeza) to avoid locking out the logistics role (Q1).
- Review sessions (draft B/L, COO, inspection): status/stage/approval fields are server-owned; client identity
  fields (approved_by "Kamal" defaults) ignored in favour of current_user.
- Rule: never substitute fabricated customs data (fake ACID, HS 560229, origin China/Italy, real third-party names)
  for missing system values; return None + `missing_fields`.
- Split for a 5k-line service: one owner for service.py (D2); router/validators/repository/schemas to D1, with
  signatures agreed in the plan. Parser files untouched because smart_document_upload imports them.

**Why:** module had zero require_permission and approval bypasses; parallel devs need disjoint files.
**How to apply:** Phase 3b/3c and later audits should reuse the same view/upload/approve pattern and the
"no fabricated defaults" rule. See [[phase01-audit-decisions]].
