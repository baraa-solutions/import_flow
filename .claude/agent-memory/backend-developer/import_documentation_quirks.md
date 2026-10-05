---
name: import-documentation-quirks
description: modules/import_documentation pitfalls found in Phase 3a (repository rules, NOT NULL expiry, test setup speed, characterizing while a peer edits service.py)
metadata:
  type: project
---

- Repository contract since Phase 3a: by-id lookups/updates see ACTIVE rows only and return None/False (service raises
  404); `update_*` never sets is_active (only `restore_acid_session` / `reactivate_po_reconciliation_session`);
  codes via `next_yearly_code`; create/update take `commit=False` (flush only). A test greps the source for this.
- `acid_registration_sessions.expiry_date` is NOT NULL: "leave expiry null" (plan DOC-15/C10) needs a migration;
  repository defaults to (generated or requested) + 90 days instead.
- `ImportFile` has no `total_amount` column: service code assigning it is silently not persisted.
- `po_packing_reconciliation_sessions.import_file_id` is unique (incl. deleted rows) -> recreate = reactivate.
- Router tests: one module-scoped seeded RBAC DB + users as SimpleNamespace snapshots (ORM users expire on the next
  commit -> DetachedInstanceError); `hash_password` + `seed_rbac` per test costs ~12 s. Replace service functions
  with recorders to pin the HTTP layer only. `_route_permissions` reads the permission code from the
  `require_permission` closure (`dep.call.__closure__`).
- When a peer is already editing service.py, prove characterization tests green on HEAD with
  `git worktree add --detach <scratch>/head HEAD` (copy the test in, run with SECRET_KEY + DATABASE_PATH), then
  `git worktree remove`. Shared worktree: `import main` can break from another module's half-written file; retry.
- Git Bash under load: long pytest runs sometimes die with exit 127 / fork errors; use run_in_background.
