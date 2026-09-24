# backend-developer memory

- `import main` runs `SchemaUpgradeService.execute_safe_startup_upgrade` at import time (result in
  `main.STARTUP_UPGRADE_RESULT`). For smoke checks set `DATABASE_PATH` to a temp file in an EXISTING folder and
  `SECRET_KEY` (32+ chars); a missing folder makes create_all fail -> the app boots in maintenance mode.
- `settings.py` appends a generated `SECRET_KEY` to `<app_base_dir>/.env` when none is set.
- tests: `tests/conftest.py` sets `DATABASE_PATH` to a temp DB and `ALLOW_DEV_AUTH_BYPASS=true`.
- Undefined-name sweep that works: `python -m pyflakes modules database utils main.py` (install pyflakes to a
  scratch dir with `pip install --target`). String annotations with function-local imports are false positives.
- `modules/import_documentation/{router,service}.py` use `from ...schemas import *` — pyflakes cannot check
  them; import models explicitly there (e.g. `CustomsDeclarationDraft` from `.model`).

## Auth (since 2026-09-24)
- Every route except `/`, `/health`, `/api/v1/health`, `/api/v1/system/{version,version-check,download-installer}`,
  POST `/api/v1/auth/{login,refresh}` must carry an auth dependency. `tests/unit/test_route_auth_coverage.py`
  enforces it (static dependency walk + runtime 401) - add new public routes to its `PUBLIC_ROUTES` only on purpose.
- FastAPI 0.141: `app.routes` holds `_IncludedRouter` wrappers; recurse via `route.include_context.included_router.routes`
  and add `include_context.prefix` / `.dependencies`. `[r.path for r in app.routes]` misses almost everything.
- conftest seam: `_dev_bypass_fallback_user` is wrapped to return a transient `User(username="test-admin", role="ADMIN")`
  (user_id None) when the test DB has no user. Tests that need a real 401 must
  `monkeypatch.setattr(modules.auth.permissions, "ALLOW_DEV_AUTH_BYPASS", False)` (the seam sits behind that flag).
- Auth caches leak across tests using separate in-memory DBs: `memory_cache["auth_user:{id}"]` and
  `_PERMISSION_CACHE[(id(bind), user_id)]`. Call `invalidate_permission_cache()` in fixtures.
- `authenticate_ws_token` opens `modules.auth.permissions.SessionLocal` itself: patch that name in WS tests.
- `AuthService.register_user/update_user/toggle_user_status/update_user_permissions` require `actor=`; non-ADMIN
  actors cannot assign a role whose permission set exceeds their own (GM + users.manage cannot create
  LOGISTICS_OPERATOR: that role has edit codes GM lacks).
- Non-ADMIN user managers are also blocked (403) from touching users wider than themselves (`_guard_wider_target`,
  stored role + overrides, legacy MANAGER strings count as wider). `update_user_permissions` guards the diff
  `after - before`, because the payload replaces the override set (omitted denies get deleted).
- CRLF files: Edit tool preserves CRLF; Python edits read/write bytes. Heredoc-embedded Python mangles backslash
  escapes (and can fail to parse, running nothing): write scripts to the scratchpad. Never put a bare `cat > file` before a heredoc (hangs on stdin).

## Running tests
- Full `tests/unit` takes more than 10 minutes: start it with `run_in_background` and wait for the notification.
- Windows console is cp1252: call `sys.stdout.reconfigure(encoding="utf-8")` before printing Arabic junit messages.
- Other agents may edit routers in the same worktree concurrently; attribute full-suite failures by module before fixing.
- Auth deps: `modules.auth.router` exports `get_current_user`, `require_admin`, `require_manager_or_admin`;
  `require_permission(code)` lives in `modules.auth.permissions` and calls `resolve_user` itself, so
  `dependency_overrides[get_current_user]` does NOT affect it. Importing `modules.auth.router` from module routers
  causes no circular import. Standard pattern: `APIRouter(..., dependencies=[Depends(get_current_user)])`.
- Strict auth tests: small app + in-memory StaticPool engine + `seed_rbac`, real-role users, `create_access_token`
  bearer, `auth_permissions.ALLOW_DEV_AUTH_BYPASS=False`. Auth deps run before body validation: allowed user +
  invalid body = 422 proves auth passed. Example: `tests/unit/test_router_auth_tightening.py`.
- `import modules.x.router as r` can yield the APIRouter object (package `__init__` re-exports `router`); use
  `importlib.import_module("modules.x.router")` in tests.
- `modules/import_companies/router.py` contains a stray bare `\r` (git marks it -text): edit it byte-wise.

## Release / installer (Phase 0b, 2026-09-24)
- The bash guard hook blocks ANY Bash command whose text contains `package_production.py` (even `cat`/`grep`). Read it
  with the Read/Grep tools; to hand the CTO a diff, build it with a scratchpad script + `difflib`, then
  `git apply --check <patch>` (read-only). It is CRLF; LF patches apply fine (autocrlf).
- `installer/importflow_setup.iss` is UTF-8 **with BOM** + CRLF (BOM needed for Arabic strings in `[Code]`).
  `version_manager.py` regex-rewrites `#define MyAppVersion "..."` and the whole `OutputBaseFilename=` line on bumps,
  so keep both as literal single lines. `tests/unit/test_installer_safety.py` pins the R1-R3 invariants.
- `scripts/release/bundle_guard.py` (`--iss/--dir/--zip`) is the one place that lists forbidden bundle content;
  CI and `/release-check` call it. `dist/Sorour_Logistics_Standalone/` in the worktree holds a stale `sorour_logistics.db`
  from old packaging, so release-check's bundle guard FAILs locally until the CTO removes it.
- ISCC 6.7.3 per-user at `%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe`. Compile/run-test in a scratch copy with a
  test AppId GUID and `/VERYSILENT /NOICONS /DIR=<scratch>`. Never run the real-AppId setup on this machine.
  Git Bash path-converts `/Q`-style flags: prefix `MSYS_NO_PATHCONV=1`.
- This dev machine has an old ADMIN install in `C:\Program Files (x86)\Sorour Logistics` (with a DB). The per-user
  installer therefore aborts here by design (the "DB in another install folder" check).
- Production laptop (Q1, 2026-09-24): per-user install at `C:\Users\Hp\AppData\Local\Programs\Sorour Logistics\` with
  the live DB (+ -wal/-shm), `backups\`, `data\` (= Flutter runtime: app.so, icudtl.dat, flutter_assets - [Files]
  must overwrite these on update) and `dist\` (unknown, never touch). Legacy scripts incl. `seed.py` are removed by
  exact-name `[InstallDelete]`.
- Inno `Excludes`: a leading backslash anchors to the source root (`\dist\*` skips `<root>\dist\` but keeps
  `data\...\dist\`), verified by compiling. `sed -i` in the Bash tool rewrites CRLF files to LF - re-normalize.
- Inno Pascal: `{...{app}...}` comments end at the first `}`: use `//`. Use `CopyFile`, not deprecated `FileCopy`.
- `.github/workflows/build_and_release.yml` is owned by the release-tooling dev (separate `release`/`publish` jobs that
  `needs: build-and-release`); keep workflow tests structural, not tied to one job layout.

## app_update module (update core, 2026-09-24)
- No tables: state is files under `UPDATE_DATA_DIR` (default `%LOCALAPPDATA%\SorourLogistics\updates`); tests MUST set
  it to tmp. `get_update_service` singleton: router tests override it with a service built from `httpx.MockTransport`,
  `data_dir=tmp`, `run_in_background=lambda fn: fn()`, `apply_supported_provider=lambda: True`, `installed_version_provider`.
- `UPDATE_SIGNING_PUBLIC_KEYS` is a placeholder until the CTO's key lands (`/check` -> `disabled`, no network). Tests
  monkeypatch it with their own Ed25519 key (read at call time). Signed `expires_at` required; `highest_seen.json`
  refuses older manifests (`offline`). Bad version.json -> `disabled`. Checks throttled 1/60 s (advance a FakeClock).
- Download is async (202 + poll `/status`): a hash mismatch is `state=failed, error_code=hash_mismatch`, not HTTP 422.

## Release tooling / publish job (Phase 6, 2026-09-24)
- Security rule (lead decision): ALL private-key code lives in `scripts/release/sign_manifest.py` (stdlib + cryptography,
  AST test forbids app imports), run with `-I` from a `--require-hashes` venv (`requirements-sign.txt`, hashes from
  the PyPI JSON API). `build_manifest.py` / `verify_manifest.py` (no secrets) may import the app.
- Manifest contract: `expires_at` REQUIRED (default released_at + 90 d; re-sign = now + 90 d via
  `.github/workflows/resign_update_manifest.yml`), `previous` optional nested `{version, installer{path,size_bytes,sha256}}`.
- `verify_manifest.main(argv, transport=)` takes an httpx transport for tests; hash with `iter_bytes` (MockTransport +
  `iter_raw` -> StreamConsumed). Build job is read-only; only the `release` job (tags only) has `contents: write`.
- Workflow rule: no `python` in any step from "Prepare SSH Credentials" on (tests enforce it). First step of
  publish/resign is a ref guard (v* tag / refs/heads/main).
- `test_bundle_guard.py` hard-codes job id `build-and-release`. Action SHAs: `gh api repos/<o>/<r>/git/ref/tags/<tag>`
  (gh is logged in here); tests enforce SHA pins + `# vX.Y.Z` comments on every `uses:`.
- Release notes required at `docs/release_notes/<version>.{ar,en}.txt`. CI always signs as `k2026a`. Keep
  `docs/UPDATE_DISTRIBUTION_RUNBOOK.md` + `docs/plans/cto_first_release_checklist.md` in step with the workflows.

## DB safety (Phase 0a-runtime, 2026-09-24)
- `utils/db_safety.py` (stdlib only) is the single place for: `is_frozen_build()`, `app_base_dir()` (exe dir when
  frozen, never `_MEIPASS`), `version_file_path()`, `backups_dir_for(db)` (backups sit next to the DB),
  `is_protected_backup` / `select_prunable` (R9, keep floor 7), `sqlite_online_backup` (+integrity_check+sha256),
  maintenance flag + `is_request_allowed_in_maintenance`. Reuse these; do not add new `Path(__file__)` runtime paths.
- Maintenance mode is process-global: any test that triggers it must `clear_maintenance_mode()` in teardown, or every
  later POST in the session gets 503.
- Startup snapshot only when `backups/.last_seen_version.json` differs from version.json.
- production_sync: DEV_DB = `database.DB_PATH` (honours DATABASE_PATH), backups prefixed `psync_`, destructive
  routes 403 when frozen (checked in the service). `tests/unit/test_production_sync.py::test_sync_dev_to_prod`
  still merges into `dist/Sorour_Logistics_Standalone/sorour_logistics.db`: skip it with `-k` when running locally.
- DB-writing maintenance scripts (root execute_user_database_updates / populate_* / clean_* / update_db_schema /
  reset_clean_production_db / sync_to_production, scripts/restore_database + prepare_uat_environment) go through
  `scripts/db_script_guard.py` (`run_cli_action` exit 2 = refused; `guard_target(confirm=True)` -> lock probe + verified
  backup). Tests: `tests/unit/test_db_safety_scripts.py` (decoys under a patched ROOT_DIR + `guard.default_db_path`).
- `guard.live_db_paths()` also covers installed laptop DBs (Inno `{AppId}_is1` registry key + default install dirs).
  Tests monkeypatch `guard._registry_app_dirs` + env vars, or inject a fake `winreg` via `sys.modules`.
- Lock probe that works on Windows: `mode=rw` URI, timeout 0, `PRAGMA locking_mode=EXCLUSIVE` + `BEGIN EXCLUSIVE`
  -> "database is locked" while any WAL connection is open (even idle). Does not detect idle rollback-journal conns.
- Flutter `local_process_sync_io.dart` calls `sync_to_production.py` without --db/--confirm: exits 2 until fixed.
- Frozen simulation: in-process patch `sys.frozen`/`sys.executable`; for module-level constants (settings, database,
  crypto_utils) run a subprocess that sets them before import (see `tests/unit/test_db_safety_frozen_paths.py`).
- Mailbox passwords derive from SECRET_KEY; old frozen builds used `LEGACY_FALLBACK_SECRET` (decrypt-only, MultiFernet).
  Any SECRET_KEY rotation must keep the previous key in that decrypt list.
- `settings.ALLOW_DEV_AUTH_BYPASS` is forced False when frozen. `ADMIN_INITIAL_PASSWORD` is written to .env only
  when seeding the admin, and removed from .env (frozen only) once the admin password was changed.
- Tests calling `get_backup_encryption_key()`/settings helpers write os.environ: restore keys in a fixture.
- A test file calling `MasterDataSyncService.sync_all()` must import every `modules/*/model.py` first, or it only
  passes when run after other files (missing `expense_catalog` etc. in Base.metadata).
- Startup seed creates ONLY `admin` on an empty users table: never assume manager/operator1/operator2 exist in
  tests. Installed version: `utils.db_safety.read_installed_version()` ("unknown" fallback); never hard-code it.
- `/api/v1/production-sync/check-updates` is local-only; update discovery belongs to `modules/app_update`.

## Startup migrations (Phase 2, 2026-09-24)
- Startup order (`schema_upgrade_service`): preflight `inspect_db_state` (UNKNOWN/R10 -> maintenance before ANY write)
  -> auto snapshot -> `pre_migration_*` (UNSTAMPED/BEHIND) -> upgrade (BEHIND) -> create_all/ALTER -> stamp (FRESH/UNSTAMPED).
  Rule: models == head schema; post-baseline revisions defensive + `batch_alter_table`.
- Patch `migration_runner.{upgrade_to_head,take_pre_migration_backup,sqlite_online_backup}` (sus calls them via the module).
- `alembic/env.py` imports `database.models` (imported nowhere else): keep it a PyInstaller hidden import. Alembic
  resolves revision PREFIXES, so `inspect_db_state` requires an exact match.
- Any `import main` against the repo DB now stamps it (after a pre_migration backup). On 2026-09-24 the Phase 5 dev did
  that by forgetting DATABASE_PATH: ALWAYS smoke-import with `DATABASE_PATH=<scratch>/x.db`; record DB sha256 before/after.
- Alembic runs on `engine.connect()` (NOT `engine.begin()`): an outer transaction makes transaction_per_migration a
  no-op. Startup fails closed when the SQLite engine file != DATABASE_PATH (backups would protect the wrong file).
- conftest session DB lives in `mkdtemp(prefix="importflow_test_db_")`, stamped after create_all, removed at session
  end. Never `import tests.conftest` outside pytest: it re-executes and creates a new temp dir + DATABASE_PATH.

## app_update Phase 5 (apply / rollback / stage-local, 2026-09-24)
- Tests share `tests/unit/app_update_testkit.py` (`make_env`, FakeLauncher; never the default `db_path`). Patch
  `service.{sqlite_online_backup,quick_check,validate_local_file}`, `validators.get_drive_type`; bytes params need `ids=`.
- Failure paths restore the maintenance snapshot (`_restore_maintenance`), never plain `clear_maintenance_mode()` (R8/R10).
- `repository.rollback_pending_reason(db_path, installed_version=None, data_dir=None)`: startup guard, fails CLOSED on a
  broken `rollback_blocked.json`; the reason must start with "rollback pending" (Dev A's test matches it).
