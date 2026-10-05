---
name: single-language-storage-decisions
description: CTO rule that DB stores only English or codes (2026-09-29): three tiers, message code + params with English render kept, traps (ilike task matching, packaging ships no JSON)
metadata:
  type: project
---

On 2026-09-29 the CTO decided that everything the system writes to the DB is language-independent.
The plan is in docs/plans/single-language-storage-plan.md (proposed; check git to see whether it was implemented).

Decisions:
- There are three tiers:
  - T1 system messages store `msg_code` + `msg_params` and still write the English render into the old text column. The columns are NOT NULL, and old clients, exports and search rely on them.
  - T2 system defaults inside user text use fixed English (` (Copy)`, `-COPY` for codes).
  - T3 fixed-list values use UPPER_SNAKE codes. A backend `normalize()` maps legacy labels to codes.
- Legacy rows have no code, so the UI renders the stored text.
- The contract between backend catalog and Flutter maps is `docs/system_message_codes.json`.

Traps found:
- The backend exe packages code only (build_backend_exe.py: no --add-data except alembic). A catalog must be a Python module, not a JSON data file.
- Lifecycle smart-task auto-close and dedupe match on `SmartTask.title.ilike('%STEP_xx%')`. Changing the title format breaks it, so use a `step_code` column.
- The operational dashboard phase filter uses an ilike on "Phase N" in current_stage/current_module. Arabic custom stage titles already break it.
- The Flutter app does not consume the notifications WebSocket, so WS payload changes are safe.
- The hold service overwrites import_files.notes (user text) with system text. This is a pre-existing bug.

**Why:** the CTO wants UI-language rendering without data migration.
**How to apply:** any new system-generated text must use msg(code) and render_en. Never store l10n output or `isAr ?` values.
