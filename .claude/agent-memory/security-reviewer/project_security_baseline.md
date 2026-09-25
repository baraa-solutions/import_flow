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
- MINOR (pre-existing): public /health exposes DB size and table count. (download-installer removed 2026-09-24)
- Phase 2 (lead's list): per-route permission catalog, restore path, check-updates SSRF, upload limits,
  handler-level resolve_user in customs_consultation/financial_approval.
- Carried over: updater has no SHA-256/signature; plain http on LAN.
- MINOR (pre-existing, CI): build_and_release.yml uses subosito/flutter-action@v2 by mutable tag, not commit SHA.
  (2026-09-24 scoped review: Flutter pinned to 3.44.6, pubspec.lock re-resolved to pub.dev only with no new packages,
  web_file_saver moved to dart:js_interop with the same behaviour. Nothing new found.)

## Update system / DB safety (Phase 0 + app_update check/download), reviewed 2026-09-24, uncommitted
Fixed: installer no longer ships .db (Excludes + PrepareToInstall kill->copy db/-wal/-shm->size check->abort,
fail-safe on unknown process state); all historic .iss versions had uninsneveruninstall on the DB, so uninstall is safe.
production_sync sync/pull/restore 403 when frozen, restore bare-name only (resolve_backup_file), online backup API,
pruning only psync_* with protected prefixes + floor 7. Startup snapshot next to DB, only on version change,
failure -> maintenance mode. Runtime paths anchored via utils/db_safety.app_base_dir. Incoterm sync insert-only.
app_update: no URL params, https + host allow-list, follow_redirects=False, 64 KB manifest cap, Ed25519 over
`signed` utf-8, strict relative installer path, streaming sha256 + size cap, placeholder key -> "disabled",
download/cancel/apply/stage-local/rollback/history need system.update. Actions pinned by SHA.
Re-review 2026-09-24 (still uncommitted): ALL prior MAJORs fixed - bypass forced off when frozen
(settings.resolve_dev_auth_bypass), highest_seen.json anti-replay + required expires_at, verify() wraps all errors,
installed version fails closed, /check force throttled 60 s, history capped 1000, signed `previous` block; CI build job
read-only + persist-credentials false, separate `release` write job, stand-alone signer (hash-pinned venv, python -I,
key only in the sign step), resign_update_manifest.yml; maintenance allow-list = health/shutdown/login/refresh/logout +
/app-update/*; installer: no override dialog, other-folder DB abort, [InstallDelete] of 3 exact scripts, guard scans
[Code]/[Run]/[UninstallRun]. Legacy Flutter auto_updater deleted (C6 closed). 11 maintenance scripts use
scripts/db_script_guard.py (--db + --confirm + in-use probe + verified pre_migration_/pre_restore_ backup).
Round-3 re-check 2026-09-24 (uncommitted): ALL items below RESOLVED -
seed = admin only on empty users table (random ADMIN_INITIAL_PASSWORD, written to .env, removed in frozen build once
changed), reset_clean_production_db admin only; download-installer gone (404) and PUBLIC_ROUTES = 7 HTTP routes in
tests/unit/test_route_auth_coverage.py; startup rotate_stored_email_passwords (idempotent, never destroys undecryptable);
alert_dispatcher/daily_report anchored via app_base_dir; production_sync check-updates/check-update/installer-info are
local-only; db_script_guard.live_db_paths incl. registry + {autopf} installs, re-probe after backup; restore decrypts
into mkdtemp + rmtree; workflows: no Python after "Prepare SSH", release job tag-only, publish v*-tag guard, resign
main-only guard; bundle_guard checks [Code] write destinations + Exec verbs.
Remaining NITs (not worth re-reporting unless touched):
- main.py system_version_check re-reads version.json with stale fallback 1.0.198 + default GitHub installer_url
  (not read_installed_version); production_sync get_system_version_info fallback 1.0.55.
- Flutter production_sync_service.dart still sends remote_url (backend ignores it).
- crypto.encrypt_email_password treats plaintext starting with "enc:" as ciphertext.
- bundle_guard Exec regex cannot see commands built in variables (static-guard limit); probe TOCTOU inherent.
- (superseded 2026-09-24: apply/stage-local/rollback + R10 now built, see below)

## Phase 2 (migrations) + Phase 5 (apply/rollback/stage-local), reviewed 2026-09-24, uncommitted on c1530f0
OK: R10 preflight refuses before any write; migration failure never restores; pre_migration backup before
stamp/upgrade; env.py ignores alembic.ini url (DATABASE_URL/DATABASE_PATH); tests use tmp DBs + repo-DB mtime check;
apply R5 gate (disk + online backup + sidecar) before marker/launch; re-hash #1/#2; /DIR /LOG quoted, `"` refused;
detached + breakaway retry; rollback 8 checks before any change, bare-name regex + == last.backup_file + resolved
parent, sha + integrity, aside pre_restore_ first; all 3 new routes system.update; .iss no /T.
Re-check 2026-09-25 (still uncommitted): RESOLVED - maintenance snapshot/_restore_maintenance on every apply +
rollback pre-restore failure, _enter_maintenance never overwrites; restore/marker/launch failure keeps maintenance +
rollback_blocked.json; validate_local_file drive regex + GetDriveType fixed/removable + resolved-path re-check, one 400;
rollback installed == to_version == manifest.version; /last-result flip only with system.update; backup copied to
private file + re-verified before restore; share-deny-write handle held through Popen (apply + rollback); audit
wrapped, UPDATE_APPLY after launch, *_FAILED entries; engine-file == DATABASE_PATH else maintenance; regexes \Z +
fullmatch; conftest mkdtemp DB; /cancel only with a live download event (apply/_claim null it under the lock).
RESOLVED (seen 2026-09-25): rollback_pending_reason now fails closed (lexists + unreadable/malformed ->
ROLLBACK_BLOCK_UNREADABLE_REASON); schema_upgrade no longer swallows ImportError of the hook (-> maintenance).
Cleanup pass 2026-09-25 (uncommitted): shared helpers utils/db_safety.same_file (False on error; used only where
False = refuse or no-op) + unique_backup_name; db_script_guard.same_file_fail_closed (old _same_file renamed,
body same; prepare_uat now resolves symlinks = stricter); auth merge_role_and_overrides (RBAC identical);
rollback post-restore integrity now inside sqlite_online_backup(overwrite=True) (real duplicate). Nothing new.
Re-verified 2026-09-25 (same pass, second look): _forget_used_admin_initial_password early return == old
remove_env_key no-op; settings ENV_PATH/DATABASE_PATH defaults unchanged (env_file_path/default_db_path);
schema_upgrade engine-file check now fails closed on resolve error; restore_database verify keeps missing-file=False
(check_integrity never creates). Nothing new.
OPEN:
- NIT (pre-existing): rollback_pending_reason returns None when same_file cannot resolve a path (theoretical).
- MINOR: tests/conftest.py forces DATABASE_PATH but not DATABASE_URL; an exported DATABASE_URL makes create_all +
  stamp_head hit that DB. Fix: os.environ.pop("DATABASE_URL", None) before importing database.
- NIT: validate_local_file suffix/size 400s come after the existence check (local-file oracle, system.update only);
  UPDATE_ROLLBACK audited before the launch (a failed launch logs both); save_rollback_block has no fsync.
- Carried: in-flight writes between aside and restore; restart after failed rollback launch (now blocked if block
  file is sound).

## Review gotchas
- `import main` writes `backups/auto_pre_upgrade_*.db` into the worktree (gitignored) on every import.
- The project Bash guard blocks any command that merely names the Track-2 packaging script, even a read-only grep.

## Publish split review 2026-09-25 (uncommitted: publish_update.yml workflow_dispatch, build_and_release has no publish job)
Verified live via gh api: repo baraa-solutions/import_flow private, org plan free; env production-updates exists with
custom policies `main` (branch) + `v*` (tag); the 3 secrets are env-only (no repo/org secrets). Rulesets / branch & tag
protection are unavailable on Free private, so ANY writer can push main or a v* tag with an edited workflow and reach the
secrets: the guard step is a mistake-guard, not a boundary (only collaborator today: kamalsroor1 admin).
Open (MINOR): env allows `v*` tags (unprotectable) -> drop it, dispatch from main only; pip install -r requirements.txt
(no hashes, sudo runner) runs before SSH key is written -> split sign / verify / upload jobs; `commits/$TAG` and
build-run lookup should use refs/tags/ + filter event==push (branch named like the tag); verify step uses main's
ManifestVerifier when dispatched from main; upload-artifact runs before "Remove SSH Credentials".
