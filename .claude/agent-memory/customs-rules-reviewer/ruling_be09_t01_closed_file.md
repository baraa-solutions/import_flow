---
name: ruling-be09-t01-closed-file
description: BE09-T01 (PR #50, 2b62ecb0) closed import file -> settlement read-only; money lens review ruling 2026-10-09
metadata:
  type: project
---

PR #50 reviewed 2026-10-09 (money lens): approve_with_minor. No money math changed; guard only.
All 7 committing settlement services (create/recalc/PUT/delete/restore/confirm/approve) call
common.validators.ensure_file_open before any write; recalculation apply refuses before the write and preview sets can_apply=False.
11 new tests + 102 settlement/recalculation unit tests green in scratch worktree.

Minors: recalculation/service.py re-implements the closed check inline instead of ensure_file_open (duplicate logic);
apply_settlement_update `db` param is NOT a nit: main's caller (service.py:804) already passed db to a 3-arg signature, so PUT /settlements crashed with TypeError on main; PR #50 fixes it (re-checked 2026-10-09); validators.py mid-file import + unused IMPORT_FILE_CLOSED constant.

**Why:** keeps later reviews of settlement gates consistent with [[ruling-bew0-06-settlement-gate]].
**How to apply:** when a new settlement writer is added, check it calls ensure_file_open too.
