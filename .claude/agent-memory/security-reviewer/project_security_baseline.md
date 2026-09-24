---
name: project-security-baseline
description: Known-issue baseline for ImportFlow backend auth/security (fixed vs still open) as of 2026-09-24 incl. user-management escalation re-review; report deltas against this
metadata:
  type: project
---

Baseline after reviewing the router-auth closure diff (branch claude/project-feedback-e6bfde, uncommitted on
2026-09-24; verify it merged before trusting the "fixed" list).

**Why:** the lead wants only new or changed issues reported, not the same backlog every time.
**How to apply:** re-run the inventory script (scratchpad route_auth_inventory.py, DATABASE_PATH = scratch DB copy),
then diff against this list.

## Fixed (in that diff)
- 643 routes: 634 protected, 9 open, exactly the allow-list: `/`, `/health`, `/api/v1/health`, auth login/refresh,
  system version/version-check/download-installer, notifications WS (first-frame token auth, 10s timeout,
  registered only after auth, never bypass).
- Docs off unless ENABLE_API_DOCS. Startup warning when ALLOW_DEV_AUTH_BYPASS. `.env.example` and local `.env` have it false.
- resolve_user: an Authorization header never falls through to the bypass; bad sub, deleted user -> 401; inactive -> 403.
- Non-admin cannot grant ADMIN (role_id or string), cannot edit/toggle/re-permission ADMIN, cannot grant users.manage
  or unheld codes, cannot assign a role wider than their own permissions.
- lifecycle_board role/author from token; skip requires a role. Header-based authors removed (PO, DCA, fin approval).
- require_admin: /shutdown, observability admin actions, production_sync compare/backups, variance-threshold,
  pki/sign-payload, smart-email settings/test/send. recalculation/apply = manager-or-admin. currencies/rates =
  master_data.edit. import_files reopen = import_files.close.

- (re-review 2026-09-24) update_user_permissions guards the gained set (after - before, incl. removed denies);
  _guard_wider_target on update_user (password/role/role_id/email), toggle_user_status, update_user_permissions
  (covers demotion); effective_role_code returns ADMIN for any admin. Duplicate codes in the payload hit
  uq_user_permission (500, no bypass). 59 tests pass (test_auth_privilege_escalation + test_auth).

## Open (found 2026-09-24)
- MINOR: manager status (require_manager_or_admin, legacy role strings) is not a permission code, so a non-manager
  users.manage holder who holds every GENERAL_MANAGER permission can assign that role and create a manager.
- MINOR: legacy role strings with no Role row (e.g. "MANAGER " with a trailing space) are stored unvalidated; for
  role_id-less users this passes the lifecycle skip approver check.
- MINOR: WS token checked once only (expiry/logout/deactivation not re-checked); no cap on pending sockets.
- MINOR (pre-existing): approver names come from the request body in cargo_shipping level1/level2 approval, import_documentation
  approvals, DCA reviewer_name, and financial_settlement. One user can sign both dual-approval levels.
- MINOR (pre-existing): public /health exposes DB size and table count; download-installer is public.
- Phase 2 (lead's list): per-route permission catalog, restore path, check-updates SSRF, upload limits,
  handler-level resolve_user in customs_consultation/financial_approval.
- Carried over: updater has no SHA-256/signature; plain http on LAN.
- MINOR (pre-existing, CI): build_and_release.yml uses subosito/flutter-action@v2 by mutable tag, not commit SHA.
  (2026-09-24 scoped review: Flutter pinned to 3.44.6, pubspec.lock re-resolved to pub.dev only with no new packages,
  web_file_saver moved to dart:js_interop with the same behaviour. Nothing new found.)

## Review gotchas
- `import main` writes `backups/auto_pre_upgrade_*.db` into the worktree (gitignored) on every import.
- The project Bash guard blocks any command that merely names the Track-2 packaging script, even a read-only grep.
