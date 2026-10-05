---
name: phase03b-support-modules
description: Quirks of original_documents_collection (ODC), docs_customs_approval (DCA) and smart_document_upload (SDU) after the 03b quality wave
metadata:
  type: project
---

- Bash heredocs containing f-strings / `{module}` / nested quotes can fail in this shell ("unexpected EOF while
  looking for matching '"): write edit scripts with the Write tool into the scratchpad and run them. The scratchpad
  is shared with other agents (their odc_*.py files exist): prefix own scripts (e.g. `b3_`).
- `bash script.sh` launched in the foreground and auto-moved to background after 600 s reports exit 127 and a
  truncated log: start long pytest runs with `run_in_background` from the start.
- `advance_lifecycle_step_service` / `transition_stage_activity_service` commit internally: a "single commit" flow
  cannot be fully atomic around them; run them last, then commit, then `best_effort` optional steps (each commits).
- DCA services accept `current_user_name=None` for internal callers and fall back to the payload names
  (`tests/unit/test_concurrency_control.py` asserts `attempted_by == payload.reviewer_name`). Routers always pass the user.
- DCA final session requires the five `*_status` fields in `payload.model_fields_set` (tests that certify a
  session must send all five). ODC `GET /sessions/by-file/{id}` returns 404 `ODC_SESSION_NOT_FOUND` (Flutter relies on it).
- Exit 127 / no junit = RAM watchdog killed a long multi-file pytest run: run files one at a time, no `timeout`.
- ODC status / date validation runs in the service (validators.py), NOT on the Pydantic models: the response model
  reuses `CourierEntry` / `OriginalDocumentItem`, so model validators would 500 on legacy rows.
- SDU `/apply/invoice` validates incoterms against the `incoterms` master table: tests must insert the row.
- New 03b codes are listed in `docs/plans/review-shared-needs.md` "03b shared needs" (unregistered: plain dicts only).
- DCA four-eyes: one user cannot sign both review tiers of an approval (409 DCA_SAME_REVIEWER, validators.validate_distinct_reviewers).
- SDU permissions (lead decision, overrides plan Q5): parse/upload/extract/cross-check = import_documentation.upload, session
  reads = import_documentation.view; /apply/* = target module codes + 409 SDU_FILE_CLOSED on Closed/Archived files.
  apply_extracted_*_service takes (db, payload=Apply*Request, user=); old-kwarg callers in extractor tests were updated.
- SmartTask has no completion_notes column: closing notes go to notes.
- Two devs may work the same 03b items at once: re-read files before every edit batch.
