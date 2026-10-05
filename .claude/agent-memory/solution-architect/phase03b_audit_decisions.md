---
name: phase03b-audit-decisions
description: 2026-10-05 Phase-3b audit (original_documents_collection, docs_customs_approval, smart_document_upload) — non-obvious traps and cross-module couplings
metadata:
  type: project
---

Plan: docs/plans/phase-03b-quality-plan.md (proposed 2026-10-05; check git for status).

Non-obvious facts:
- DCA matrix-check (`run_cross_document_matrix_check_service`) contains hard-coded demo rows (14,250 KG, 58.40 CBM, Shanghai, HS 8415.10) always "Match"; tests test_dc04 / test_docs_customs_approval rely on "Fully Compliant".
- ODC orchestration writes DCA rows directly (both tiers Approved, uuid code DCA-xxxx) on FULLY_RECEIVED; test_sh04 l.284-289 pins it.
- Cross-module: ODC -> DCA table + lifecycle STEP_11->12; DCA final session -> STEP_09->10.
- Flutter uses only `/smart-upload/parse/{module}` (also from master-data entity dialogs); extract/apply/cross-check and ODC excel export have no Flutter caller.
- `cairo_today()` lives in financial_settlement/service.py; proposed move to modules/common/dates.py.
- `require_permission` takes one code; conditional (draft vs final) checks need `has_user_permission` in the service.

**Why:** shapes any later Phase-3 plan, permission mapping, and expected test churn.
**How to apply:** check plan Q1-Q6 answers before touching DCA approvals, courier SLA, or smart-upload permissions.
