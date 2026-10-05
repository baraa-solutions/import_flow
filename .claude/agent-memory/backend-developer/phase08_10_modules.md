---
name: phase08-10-modules
description: Pitfalls in warehouse_receiving / inland_transport / file_closure (closure gate, codes, test pinning when other devs break boot)
metadata:
  type: project
---

- File closure: ONE rule `file_closure.validators.evaluate_closure_gate(ClosureFacts)` used by precheck and close; facts
  loaded in `service._closure_facts` (no try/except: a failing query fails the close). Client checklist never gates.
  Final close needs dossier_exported_at (or STEP_20 skipped); a quarantine-locked GRN blocks (`warehouse_quarantine`).
- `modules.container_tracking` does NOT exist (old code imported it inside try/except). Container return state lives on
  ImportFile (`empty_containers_return_status` ALL_RETURNED / PARTIALLY_RETURNED / PENDING_RETURN, returned_at, eir).
- ImportFile has no `customs_broker` relationship (use broker_id / broker_name) and no `closed_at` column
  (`closed_at_phase` is the column reopen reads). SmartTask has no completed_at / resolution_notes / result_notes.
- POST /file-closure route requires only import_files.view; the service enforces edit|close (draft) or close (final) via
  `actor=` (GENERAL_MANAGER has close but not edit). Tests calling services without `actor` skip that check.
- Codes not in system_messages: module-local `coded_error()` (HTTPException detail dict). CodedHTTPException would 500.
  List in docs/plans/review-shared-needs.md "## 08-10 shared needs".
- Customs FX without fallback: `file_closure.repository.customs_rate_to_egp` (CurrencyRepository, None when missing).
- When another dev breaks `import main` mid-session, test in a pinned copy: `git archive HEAD ...` into scratch, overlay
  your modules + tests, run there. Long pytest runs in that copy sometimes died silently (exit 127): split into chunks.
