---
name: db-safety-runtime
description: utils/db_safety helpers, maintenance mode, guarded DB scripts, frozen-build simulation, admin seed/forced password change
metadata:
  type: project
---

## DB safety (Phase 0a-runtime, 2026-09-24)
- `utils/db_safety.py` (stdlib only) is the single place for: `is_frozen_build()`, `app_base_dir()` (exe dir when
  frozen, never `_MEIPASS`), `version_file_path()`, `backups_dir_for(db)` (backups sit next to the DB),
  `is_protected_backup` / `select_prunable` (R9, keep floor 7), `sqlite_online_backup` (+integrity_check+sha256),
  maintenance flag + `is_request_allowed_in_maintenance`, `same_file` (False on empty/unresolvable),
  `unique_backup_name(stem, dir)` (`<stem>.db` / `<stem>_N.db`). Refusal guards use `db_script_guard.same_file_fail_closed`
  (abspath fallback, never False on error). Auth merge: `permissions.merge_role_and_overrides`. Reuse these.
- Maintenance mode is process-global: any test that triggers it must `clear_maintenance_mode()` in teardown, or every later POST in the session gets 503.
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
- Frozen simulation: in-process patch `sys.frozen`/`sys.executable`; for module-level constants (settings, database,
  crypto_utils) run a subprocess that sets them before import (see `tests/unit/test_db_safety_frozen_paths.py`).
- Mailbox passwords derive from SECRET_KEY; old frozen builds used `LEGACY_FALLBACK_SECRET` (decrypt-only, MultiFernet).
  Any SECRET_KEY rotation must keep the previous key in that decrypt list.
- `settings.ALLOW_DEV_AUTH_BYPASS` is forced False when frozen. Since 2026-09-29 the seeded admin gets
  `settings.ADMIN_INITIAL_PASSWORD` (= env override or `DEFAULT_ADMIN_PASSWORD` "Admin@123") + `must_change_password=True`;
  nothing is written to .env any more. A leftover `ADMIN_INITIAL_PASSWORD=` line (old 2.1.x) is still removed (frozen only)
  once changed. The dev repo `.env` may define it: smoke scripts set `ADMIN_INITIAL_PASSWORD=""` to get Admin@123.
- Forced change: `permissions.enforce_password_change` runs in BOTH `get_current_user` and `require_permission`
  (auth router routes are permission-only). Token requests only (dev bypass exempt). The session DB admin seeded by
  `import main` has the flag: a test logging in as it must POST `/auth/me/change-password` first.
  Seed password: frozen = always DEFAULT; the leftover-line cleanup compares against
  `settings.env_admin_initial_password(ENV_PATH)` (reads the .env file; None = unreadable -> keep the line).
- Startup step 4b (`schema_upgrade_service.add_column_ddl`) emits `NOT NULL DEFAULT x` only for constant
  server_defaults: give new NOT NULL model columns a `server_default`, or UNSTAMPED DBs get NULLs.
- A test file calling `MasterDataSyncService.sync_all()` must import every `modules/*/model.py` first, or it only
  passes when run after other files (missing `expense_catalog` etc. in Base.metadata).
- Startup seed creates ONLY `admin` on an empty users table: never assume manager/operator1/operator2 exist in
  tests. Installed version: `utils.db_safety.read_installed_version()` ("unknown" fallback); never hard-code it.
- `/production-sync/check-updates` is local-only (discovery = app_update). Settings-helper tests: restore os.environ.
  Flutter `local_process_sync_io.dart` calls sync_to_production.py without --db/--confirm (exit 2).

