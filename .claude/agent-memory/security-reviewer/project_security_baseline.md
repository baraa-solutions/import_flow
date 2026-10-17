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

## v2.1.1 installer R2m migration review 2026-09-26 (release/2.1.1, uncommitted)
OK: old folder only read (CopyFile FailIfExists, RenameFile never overwrites, {app} db/-wal/-shm pre-check),
size+SHA-256 on both copies + source re-hash (db, wal, wal presence), .db placed last, undo = move back (no delete),
UninstallString confined to OldDir via ExtractFileDir + FileExists (quotes/args/.. fail), Rehearsal #ifdefs tested absent.
In-app apply always passes /DIR=app_base_dir, so migration only fires there when DATABASE_PATH is outside {app}.
OPEN (reported): MAJOR leftover old DB (never marked, {commonpf} scanned unconditionally) re-migrates a stale copy
on any later fresh per-user install / other Windows user; MAJOR silent mode still migrates + runas UAC (DATABASE_PATH
override case); MINOR uninstaller name not pinned to unins###.exe (user-writable custom all-users dir -> elevated
planted exe); MINOR bundle_guard reverse RenameFile (live -> pre_migrate_ + anything) allowed anywhere, can relocate
the live DB; MINOR no re-kill/recheck between rename and RetireOldInstall (old-app writes lost).

## Publish split review 2026-09-25 (uncommitted: publish_update.yml workflow_dispatch, build_and_release has no publish job)
Verified live via gh api: repo baraa-solutions/import_flow private, org plan free; env production-updates exists with
custom policies `main` (branch) + `v*` (tag); the 3 secrets are env-only (no repo/org secrets). Rulesets / branch & tag
protection are unavailable on Free private, so ANY writer can push main or a v* tag with an edited workflow and reach the
secrets: the guard step is a mistake-guard, not a boundary (only collaborator today: kamalsroor1 admin).
Open (MINOR): env allows `v*` tags (unprotectable) -> drop it, dispatch from main only; pip install -r requirements.txt
(no hashes, sudo runner) runs before SSH key is written -> split sign / verify / upload jobs; `commits/$TAG` and
build-run lookup should use refs/tags/ + filter event==push (branch named like the tag); verify step uses main's
ManifestVerifier when dispatched from main; upload-artifact runs before "Remove SSH Credentials".

## Default admin forced change review 2026-09-29 (feat/default-admin-forced-change, uncommitted)
Design (CTO-accepted): empty users table -> admin/Admin@123 + users.must_change_password; enforce_password_change
in get_current_user + require_permission (permissions.py) 403s everything but login/refresh/me/me-permissions/
logout/me/change-password. OK: every resolve_user call site is behind a router-level get_current_user; path exact-match
after rstrip, fails closed; flag read from DB each request; seeder only on count()==0; migration add-only ALTER,
server_default 0 (existing users never flagged); bypass ignored in frozen build; audit has no secrets; Flutter clean.
OPEN (reported): BLOCKER main.py:248 CORS allows Origin "null"/"*" with credentials + PNA -> any web page can log in
with the now-public Admin@123 on a fresh install and change the password (was harmless with a random password);
MAJOR reset_clean_production_db.py seed_core_users inserts admin/ADMIN_INITIAL_PASSWORD (now Admin@123) without
must_change_password=1; MAJOR if .env override is dropped in frozen builds, _forget_used_admin_initial_password must
still compare against the .env value or it deletes an unchanged 2.1.x admin's only password record; MINOR no rate
limit on change-password current_password; MINOR tokens not revoked on password change (no per-user iat cutoff);
MINOR WS authenticate_ws_token ignores the flag (flagged user gets broadcasts).
Re-check 2026-09-29 (same branch): RESOLVED - CORS only regex origins (no null/*); reset script admin
must_change_password=1 + DEFAULT_ADMIN_PASSWORD; frozen seed always Admin@123, both .env cleanups compare against
settings.env_admin_initial_password (None -> keep); WS rejects flagged; change-password throttled per user key
"change-password:user:<id>" (no collision with /login IP keys; /login behaviour unchanged, XFF-spoofable as before).
Accepted: /shutdown exempt for flagged admin (DoS only, less than the takeover the design already accepts).
Schema 4b add_column_ddl: NOT NULL only with a constant server_default (func/()/CURRENT_* -> nullable as before),
model-defined only. Still OPEN: MINOR tokens not revoked on password change.
Commit 9d0d0b1 (2026-10-05, desktop close crash): clean at BLOCKER/MAJOR. Frontend single-instance mutex
Local\SorourLogisticsFrontend (same-session squat = DoS by code already running as the user, accepted); restore
targets only a window whose process image path equals ours. Backend watchdog: Toolhelp snapshot handle closed in
finally, frontend handle held for life (prevents PID reuse), tasklist fallback is a fixed argv, no shell.
[InstallDelete] allow-list now also the 3 legacy launchers (exact names, lowercased compare). MINOR: test_bundle_guard
launcher tests use non-raw strings ('\b' in "{app}\backups\..." is a backspace) - tests pass for the wrong reason.

## Phase-1 planning RBAC review 2026-10-05 (feat/update-notice-rtl-p1, uncommitted on 8f776ae)
RESOLVED: Phase-2 item "handler-level resolve_user in customs_consultation" (now require_permission, no X-User left).
PO/CBM/shipping_scenarios/customs_consultation/import_requirements/freight_quotations: every route has a catalog code;
writes on *.manage / purchase_orders.delete; POST quick-calculate + customs recalculate on view codes are pure compute
(verified no commit/add). next_yearly_code fully bound (constant prefixes). seed_rbac DERIVED_GRANTS one-time copy
(roles + user overrides incl. revokes) only when new code inserted AND source pre-existed; no escalation vs before
(those routes were any-authenticated). OPEN (reported, MINOR): step 2 re-adds config codes to system roles every
sync_all (admin removal of purchase_orders.delete from GENERAL_MANAGER undone on restart; per-user revoke still wins);
step 1 commits before 1b, so a failed copy is never retried (fail-closed lockout of custom roles); no backfill tests.
Pre-existing NIT: ADMIN compare exact in get_user_effective_permissions/has_user_permission vs .upper() in is_admin_user.

## Phase 2 / 6-7 / 8-10 permission wave review 2026-10-05 (feat/update-notice-rtl-p1, 4d22473 + uncommitted)
OK: financial_approval, customs_clearance, customs_clearance_quotations, warehouse_receiving, inland_transport,
file_closure: every route has a catalog code matching the plans (FA-01, CL-01, CCQ-01, WR-01, IT-01, FC-06); all
require_permission codes exist in PERMISSIONS_CATALOG (scripted check); acting user always current_user (budget
approved_by query ignored, SWIFT user_name ignored). seed_rbac step 2 now links config codes only when the role is
created or the code is new (old MINOR "re-adds removed codes" RESOLVED); whole seed one commit (old "1b never
retried" RESOLVED). ONE_TIME_ROLE_GRANTS batch marker idempotent, never re-grants after removal. Carrier tracking:
explorer.exe argv + http/https check + encoded AWB (injection fixed).
OPEN (reported): MAJOR PUT payment Approved->Rejected (and Pending->Rejected) needs only financial_approval.manage,
now held by LOGISTICS_OPERATOR/CUSTOMS_OFFICER (un-approve with a non-approve code); MINOR lab-test-result CONFORMING
grants Final Release on customs_clearance.update (no seeded role has update without release); MINOR CUSTOMS_OFFICER
lacks quotations.manage but its consultation screen embeds the clearance RFQ/price-list screen (writes 403);
MINOR no maker-checker on payment/budget approve (no created_by, D1 deferred; payment approve records no approver);
MINOR financial_export_service.launchUrlNative still cmd /c start + runInShell with typed phone/email (| > not
escaped); MINOR no test that require_permission codes exist in the catalog; NIT file_closure _require_any_permission
skips when actor is None.

## Phase 3 / 4-5 / 9 wave review 2026-10-05 (same branch, uncommitted; turn-limited, partial)
Method: runtime inventory = import each modules.<m>.router, walk route.dependant deps, read permission_code from the
require_permission closure (catches constants; regex scans miss them). All codes in catalog at that time.
RESOLVED: launchUrlNative now explorer.exe argv + scheme allow-list; test_permission_codes_in_catalog exists (but see
below); cargo_shipping L1/L2, import_documentation, DCA reviewer identities now from login (old MINOR identity part).
OK: import_documentation 62 routes view/upload/approve, upload ext whitelist + bounded 20 MB read, no disk writes;
DCA/ODC/freight_booking/cargo_insurance/cargo_shipping/shipment_updates/demurrage/financial_settlement all per-route
codes; FS simulate/calculate-actual on view are pure compute; recalculation preview/logs/deps check target view perm
in service (TARGET_VIEW_PERMISSIONS); one-time grant batches idempotent (marker). Feature dirs: no cmd /c / runInShell.
OPEN (reported): MAJOR draft-bl POST /{id}/approve single-step override records one user as importer AND broker,
bypassing DOC-04 dual approval (LOGISTICS_OPERATOR + CUSTOMS_OFFICER hold .approve); MAJOR smart_document_upload
(3b WIP) upload/parse/parse-multi/parse-text/extract/cross-check/sessions login-only (sessions expose extracted fields
of all modules incl. financial-document); MAJOR demurrage push-to-settlement writes settlement expense rows on
demurrage_detention.manage (LOGISTICS_OPERATOR only) and honours req.import_file_id != tracking file (cross-file cost
injection) + client accountant_name; MINOR cargo_shipping L1==L2 log-only (Q6) and LOGISTICS_OPERATOR holds both
codes, no durable audit; MINOR DCA tier1/tier2 same user; MINOR FINAL draft B/L soft-deletable on upload; soft delete
of confirmed booking / dual-approved shipping / issued certificate on create/update/manage codes; MINOR catalog test
regex misses constant codes (10 routers); route coverage test counts router-level get_current_user as enough;
MINOR smart-upload apply services ignore `user` (no updated_by); NIT filename echoed unsanitized in 413/415 details.
Not reviewed (turn limit): import_documentation service internals beyond draft B/L, shipment_updates/insurance
services, financial_settlement approve SoD details, ODC verified_by source.

## PR guardrails CI review 2026-10-05 (pr_checks.yml, CODEOWNERS, scripts/ci/guardrails.py, .githooks; uncommitted)
Live gh api 2026-10-05: org plan free, repo private, allow_forking=false, branch protection + rulesets 403 (need paid
plan), default token read, fork-PR workflows off, sha_pinning_required=false, allowed_actions=all, collaborators
kamalsroor1 admin + ahmedsalahsorour88 read, 0 repo secrets, env production-updates policy = `main` branch only (old
`v*` tag MINOR RESOLVED).
OK: pull_request only (no _target), contents read, persist-credentials false, actions SHA-pinned, base_ref fixed by
branches:[main], module names passed via repr (no injection), PR caches are PR-ref scoped (tag builds cannot restore
them), no artifacts uploaded, CODEOWNERS read from the base branch.
OPEN (reported): CRITICAL on Free any Write collaborator can push main / v* tag and dispatch publish_update from main ->
signed malicious update (no branch/tag protection, no env reviewers, publish never checks tag is ancestor of main nor
triggering_actor); CODEOWNERS + required checks unenforceable on Free; HIGH same-repo PR can rewrite pr_checks.yml /
guardrails.py / guard tests so "Backend gate" passes trivially; MEDIUM repo-tracked .githooks run branch code on the
owner's machine at commit/push; MEDIUM Windows-minute burn (2x) via push/label spam; LOW scratch_env inherits
DATABASE_URL; LOW enable SHA-pinning policy + allowed-actions list.

## PR #17 BE810-T10 (acting user from token) 2026-10-07
Clean on the security side: auditor_name / exported_by / inspector_name in request bodies are now ignored on the
service side (closure create/official-close/update, dossier export, GRN create/update, inspection protocol). Routers
unchanged, and every route keeps require_permission. Leftovers (MINOR): dead `_resolve_user_name` + LEGACY_*_DEFAULTS
in file_closure/service.py; no tests for the WR or export paths. CI 401s in test_clo04 hit unchanged tests in that file
too, so the cause is shared test isolation (the dev-bypass seam is lost), not this diff. The same 401 failure appears in
other PRs on 2026-10-07. Pre-existing and not new: POST /file-closure and /confirm-dossier-export use the VIEW route
guard and rely on the service-side `_require_any_permission`.

## PR #15 BEW0-04 paging helper review 2026-10-07 (security lens)
OK: /import-files/paginated keeps require_permission("import_files.view"); sort is a dict allow-list (no injection);
page>=1, page_size 1..200, sort<=200, q<=100; LIKE wildcards escaped with escape="\\".
CI pattern to remember: scripts/ci/guardrails.py scratch_env forces ALLOW_DEV_AUTH_BYPASS=false, so any test that
relies on the conftest dev-bypass seam, or overrides modules.auth.router.get_current_user on a route guarded by
require_permission(...) (closure calls resolve_user directly; override is ignored), gets 401 in CI but passes locally.
test_import_files_hold_codes::test_hold_endpoint_contract has this bug on main (surfaces whenever import_files changes).

## PR #24 BE810-T18 GRN/IT paging 2026-10-07 (security lens): clean
New /warehouse-receiving/paginated, /inland-transport/bookings/paginated and /inland-transport/paginated keep the router-level
get_current_user plus require_permission(VIEW). Sort uses dict allow-lists, LIKE is escaped, and PageParams bounds apply. Pre-existing
and not new: inland_transport/router.py VIEW = "warehouse_receiving.view" (IT has no own view code); include_inactive
is exposed to VIEW holders on both legacy and paginated lists. MINOR: legacy list `limit` is optional, so it stays
unbounded by default, and the legacy `search` has no max_length. Tests do not cover 401/403 or invalid sort.

## PR #32 BE810-T15 IT restore 2026-10-07 (security lens)
OK: PATCH /inland-transport/bookings/{id}/restore has router-level get_current_user + require_permission("warehouse_receiving.receive")
(in catalog, same as delete); user from token. MAJOR: `_require_open_file_for_booking` wraps
`from modules.common.validators import ensure_file_open` in try/except ImportError -> silent no-op. ensure_file_open does not
exist at PR #32 head (only in T02 PRs #14/#22/...), so restore on a Closed file is allowed and resyncs inland cost (settlement input).
Pattern to watch: fail-open guards via optional import in stacked PRs. MINOR: no 403 test for VIEW-only user.

## PR #38 BE810-T20 (2026-10-07) clean
file_closure `_require_any_permission` now fail-closed (actor=None -> 403) unless `trusted=True`; only official-close passes
trusted=True (route already requires import_files.close). MINOR: `trusted` kwarg on confirm_dossier_export_service is a
test-only bypass knob with no production caller. No route/dependency changes; TR-03 assigned_user from token username.

## PR #51 BE45-T03 (2026-10-09) clean
Re-push of a pushed tracking (PUT tracking, PATCH container, BK-02, EIR) now needs financial_settlement.calculate
via `_require_settlement_permission` before any write; routers pass actor=current_user; all 4 `_repush_recalculated`
callers covered, no non-router callers. BK-02/EIR check any active pushed tracking of the file (broader than EIR's
.first(), fail-safe). Partly closes the 2026-10-05 MAJOR "push writes settlement on demurrage manage" (re-push side);
cross-file req.import_file_id / accountant_name part not re-checked here. MINOR: actor=None skips the guard
(fail-open seam, no prod caller); tests do not assert tracking/settlement unchanged after 403.

## PR #52 BE45-T02 (2026-10-09) — clean
Diff vs PR #51: service-only (recalc before push, live dual-clock values, additive `is_provisional`). No route
changes; new `calc_date` kwarg is not exposed by any router (server date only). Push still calls
`_require_settlement_permission` first; dual-clock GET stays on `demurrage_detention.view`, no commit.

## PR #63 BE67-T01 (2026-10-09) — clean, closes customs_tariff open-route backlog
All 25 customs_tariff routes now carry view / edit / customs_clearance.update (simulate-file) on top of the
router-level get_current_user; /export-template and /fee-codes moved above /{tariff_id}. Codes exist in catalog.
Pre-existing, left to later tasks: upload-excel has no size/type cap (BE67-T09), no created_by on tariff writes.

## PR #64 BEX-T01 lifecycle_board (2026-10-09) — closes BEX-F01/F10/F19 core
All 6 GETs now lifecycle_board.view, 5 POSTs lifecycle_board.advance (catalog codes), router-level get_current_user kept.
sync/advance go through http_advance_step_service: file 404/422/409, STEP_21 reserved, step must be In-Progress,
auto_complete_prior admin-only, assigned_user = token username. Open: MAJOR `/stages/set-active` (same advance perm)
can mark ANY step (incl. Completed ones, STEP_20) In-Progress with no actor/sequence check, so set-active + sync defeats
LC_STEP_NOT_ACTIVE; target_step_codes on sync lets non-admin jump the file forward past skip policy. PUT step-configs
still only get_current_user + service role check (deferred to BEX-T02). MINOR: advance_step_service(actor=None) legacy
path skips guards (no prod caller).

## PR #66 BEX-T03 lifecycle_board (2026-10-09) — clean
Branch stacks BEX-T01/T02 commits (reviewed in #64/#65); T03 = 0a2940a1 + docs 6486baa8. No router/permission change;
GET /summary (lifecycle_board.view) no longer writes (`_ensure_initial_stages` deleted). Live-tracking pre-fetches now
`IN (active ids)` (bound params, no interpolation). Live tracking still returns every active file unpaged (perf, not auth).

## PR #88 client feedback items 1-6 (2026-10-09) — request_changes
Client-requested, no task card; branch also carries FE06/FE07/FE08-T13 commits. OCR is local (RapidOCR/pytesseract),
no API key, images only go to own /smart-upload. Alembic single head c3d4e5f6a7b8, nullable columns.
- BLOCKER: import_companies.nafeza_token plaintext String(500); ImportCompanyResponse inherits Base -> full token on
  GET list/by-id to any authenticated user (router auth-only). Flutter masks only on display.
- MAJOR: smart_document_upload EXTRACT_CODES += 9 codes not in catalog (suppliers.*, import_companies.*, partners.*,
  master_data.manage) + master_data.view -> AUDITOR_VIEWER gains upload/session write, FINANCE_OFFICER gains session read.
- MAJOR: extractor dialog token field not obscured; "copy all" writes token plaintext to clipboard.
- MINOR: new export routes (currencies, customs_tariff, incoterms) auth-only, no master_data.view; partners/suppliers
  exports now carry credit limit / IBAN / account no. on auth-only routes (Phase-2 per-route backlog).

## PR #65 BEX-T02 lifecycle_board transactions (2026-10-09) - clean (MINORs)
- PUT /lifecycle-board/step-configs/{code} now users.manage (service role-string check kept only when actor is None);
  skip dual_approval -> 409 unless is_admin_user(actor); approver_roles validated vs roles table.
- MINOR: update_step_config_service calls seed_rbac(db) (commits) from the request path when roles table empty.
- Pre-existing, not this PR: skip hard-allows ADMIN/MANAGER/GENERAL_MANAGER regardless of approver_roles;
  set-active route passes no actor. PR branch also carries BEX-T01 commits (cbcf8443).

## PR #68 FEX-T13 (2026-10-09) — clean
- Flutter-only: currentPermissionsProvider (GET /auth/me/permissions, already get_current_user-protected, self only)
  + PermissionGate. '*' added client-side when role_code == ADMIN: UX only, backend still enforces. No backend change.
- Gate shows `.view` children while loading/error; mutations fail closed. No token logging.

## PR #69 FEX-T08 (2026-10-09) — clean
- Flutter-only RowAction/RowActionsBar/showConfirmDialog; diff vs #67 also carries #68 (T13) content.
- RowActionsBar._isPermitted mirrors PermissionGate: `.view` visible on loading/error, mutations fail closed. UX only.

## PR #73 FEX-T21 (2026-10-09) - clean
- Flutter-only ImportFilePickerDialog (core/widgets) + 5 l10n keys; no routes, no tokens. Default closed-file filter is UX only; backend closed-file guards must stay authoritative when FE06-T04/FE08-T04/FE09-T01 wire it.

## PR #74 FEX-T03 (2026-10-09) - docs only, MINOR
- docs/standards/list-paging-contract.md: Flutter RowAction example uses `purchase_orders.manage` (not in catalog; real code is `purchase_orders.edit`). Standard mandates `.view` on /paginated, /lookup, /export-excel.

## PR #84 FE06-T03 (2026-10-09) - clean
- Flutter-only (diff vs #83): removed random DO / delegation / decl-46 / MTS number generators, fees default 12500, hard-coded 14 free days.
  No routes, no tokens. free_days input is digitsOnly with no upper bound: backend schema must bound it (not security-relevant).

## PR #86 FE07-T02 (2026-10-09) - clean
- Flutter-only (diff vs #85): inspection dialog no longer defaults verdict/yard/GOEIC body or random SMP number; pre-fills from clearance record.
  No routes, no tokens, no backend files. Verdict is required only by the Flutter FormField; backend enforcement of a non-empty verdict is a domain, not security, concern.

## PR #87 FE07-T03 (2026-10-09) - clean
- Flutter-only (diff vs #86): samples tab reads real CustomsClearanceModel rows; session-only maps removed; new core ImportFilePickerDialog (reads importFilesProvider, hides Closed).
  Only write path is the existing CustomsInspectionSamplingDialog -> POST /record-inspection-sampling, backend-guarded by customs_clearance.update. No routes/tokens/logging changed.
