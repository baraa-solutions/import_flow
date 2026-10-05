# backend-developer memory

- `import main` runs `SchemaUpgradeService.execute_safe_startup_upgrade` at import time (result not kept; check
  `is_maintenance_mode()`). For smoke checks set `DATABASE_PATH` to a temp file in an EXISTING folder and
  `SECRET_KEY` (32+ chars); a missing folder makes create_all fail -> the app boots in maintenance mode.
- `settings.py` appends a generated `SECRET_KEY` to `.env` when none is set; conftest sets temp `DATABASE_PATH` + dev bypass.

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
- `AuthService.register_user/update_user/toggle_user_status/update_user_permissions` require `actor=`; non-ADMIN
  actors cannot assign a role whose permission set exceeds their own (GM + users.manage cannot create
  LOGISTICS_OPERATOR: that role has edit codes GM lacks).
- Non-ADMIN user managers are also blocked (403) from touching users wider than themselves (`_guard_wider_target`,
  stored role + overrides, legacy MANAGER strings count as wider). `update_user_permissions` guards the diff
  `after - before`, because the payload replaces the override set (omitted denies get deleted).
- CRLF files: Edit tool preserves CRLF; Python edits read/write bytes. Heredoc-embedded Python mangles backslash
  escapes (and can fail to parse, running nothing): write scripts to the scratchpad. Never put a bare `cat > file` before a heredoc (hangs on stdin).

## Running tests
- Never run the full suite yourself (qa-verifier does); run your test files one at a time in the foreground.
- Console is cp1252: `sys.stdout.reconfigure(encoding="utf-8")` before printing Arabic. Other agents may edit the
  same worktree concurrently: attribute full-suite failures by module before fixing.
- Auth deps: `modules.auth.router` exports `get_current_user`, `require_admin`, `require_manager_or_admin`;
  `require_permission(code)` lives in `modules.auth.permissions` and calls `resolve_user` itself, so
  `dependency_overrides[get_current_user]` does NOT affect it. Importing `modules.auth.router` from module routers
  causes no circular import. Standard pattern: `APIRouter(..., dependencies=[Depends(get_current_user)])`.
- Strict auth tests: in-memory StaticPool + `seed_rbac` + bearer tokens + `ALLOW_DEV_AUTH_BYPASS=False`
  (example `tests/unit/test_router_auth_tightening.py`); allowed user + invalid body = 422 proves auth passed.
- `seed_rbac` role codes: ADMIN, GENERAL_MANAGER, LOGISTICS_OPERATOR, CUSTOMS_OFFICER, FINANCE_OFFICER, AUDITOR_VIEWER (no OPERATOR).
- In tests import routers via `importlib.import_module("modules.x.router")` (package `__init__` re-exports `router`).

## Startup migrations (Phase 2, 2026-09-24)
- Startup order (`schema_upgrade_service`): preflight `inspect_db_state` (UNKNOWN/R10 -> maintenance before ANY write)
  -> auto snapshot -> `pre_migration_*` (UNSTAMPED/BEHIND) -> upgrade (BEHIND) -> create_all/ALTER -> stamp (FRESH/UNSTAMPED).
  Rule: models == head schema; post-baseline revisions defensive + `batch_alter_table`.
- Patch `migration_runner.{upgrade_to_head,take_pre_migration_backup,sqlite_online_backup}` (sus calls them via the module).
- Adding a revision: bump `HEAD_REVISION` in tests/unit/test_migration_runner.py (and test_default_admin_forced_change.py);
  `BASELINE_REVISION` (e1f2a3b4c5d6) stays the baseline. Head since 2026-10-05: d9e4f5a6b7c8 (tax_rates + B/L codes);
  also bump `HEAD` in test_migration_system_message_codes.py and the chain in test_migration_runner test_11.
- Edits that add a name + its import: do them sequentially (import first). The post-edit hook fires between
  parallel edits and reports a spurious NameError.
- Adding a revision: models == head, so UNSTAMPED DBs never run it: model indexes on new columns come from startup step 4c.
- `alembic/env.py` imports `database.models` (imported nowhere else): keep it a PyInstaller hidden import. Alembic resolves revision PREFIXES, so `inspect_db_state` requires an exact match.
- Any `import main` against the repo DB now stamps it (after a pre_migration backup). On 2026-09-24 the Phase 5 dev did
  that by forgetting DATABASE_PATH: ALWAYS smoke-import with `DATABASE_PATH=<scratch>/x.db`; record DB sha256 before/after.
- Alembic runs on `engine.connect()` (NOT `engine.begin()`): an outer transaction makes transaction_per_migration a
  no-op. Startup fails closed when the SQLite engine file != DATABASE_PATH (backups would protect the wrong file).
- conftest session DB lives in `mkdtemp(prefix="importflow_test_db_")`, stamped after create_all, removed at session
  end. Never `import tests.conftest` outside pytest: it re-executes and creates a new temp dir + DATABASE_PATH.

## Tax rates (2026-10-05)
- Non-tariff rates (WHT) live in `financial_settlement.model.TaxRate` (`tax_rates`, effective-dated, soft delete).
  `service.resolve_wht_rate_percent(db, code, on_date)` (none -> 0). Seeds: `MasterDataSyncService.sync_tax_rates`
  (insert only when the code has no row at all). Migrations must not write rows (test_migration_runner test_4
  compares row counts on a BEHIND upgrade): seed via sync_all. No CRUD endpoints yet. FeeCode is NOT the place:
  every active fee code feeds `calc_collection_fees` (customs estimates).
- Money rounding: compute `amount * (rate_percent / 100.0)` (rate/100 first), never `amount * rate / 100`: the latter
  differs from the legacy `amount * 0.01` on ~0.13% of cent amounts (17.50 -> 0.17). Business dates: `financial_settlement.service.cairo_date`
  (naive = UTC; tzdata not in requirements -> fixed UTC+2 fallback). Real invoice + missing rate = 409 code WHT_RATE_NOT_CONFIGURED.
- `sed -i` on CRLF files in Git Bash silently rewrites them as LF: use Python byte edits.

## import_documentation (Phase 3a D2, 2026-10-05)
- `errors.best_effort(db, fn, label, *a, **kw)`: its first param is `db`, so `best_effort(db, svc, "x", db=db)` is a
  TypeError. Wrap: `lambda: svc(db=db, ...)` (service has `_lifecycle_follow_up` / `_commit_follow_up` helpers).
- NOT NULL traps (no schema change allowed): `acid_registration_sessions.expiry_date`, COO `exporter_name/importer_name/
  country_of_origin`, `import_files.company_name/supplier_name`. ImportFile has NO `total_amount/currency/incoterm`
  columns (service sets transient attrs; real columns: `incoterm_code`, `estimated_cost_currency`).
- Repository create/update functions commit internally: for "one commit" flows, mutate related rows first, then call
  the repo function (its commit persists both). Approval flows: server owns status; `_actor(user, legacy)` fallback.
- Other agents may leave unrelated modules unparseable mid-edit: run tests from a scratch copy
  (`cp -r modules database alembic tests utils scripts` + main/settings/seed/alembic.ini/version.json/pytest.ini,
  restore the broken module from `git show HEAD:`). Edit 5k-line CRLF files with block-replace scripts written via Write.

## Phase 1 shared helpers (2026-10-05)
- Cargo math lives in `modules/common/cargo_math.py` (pure; factor passed in). Air volumetric factor = DB row
  `system_parameters.AIR_VOLUMETRIC_KG_PER_CBM` via `system_parameters.air_volumetric_kg_per_cbm(db)` (default 167).
  `SystemParameter` model is registered by importing it in `purchase_orders/model.py`.
- `seed_rbac.DERIVED_GRANTS`: a new dedicated permission code copies role + user-override grants from its source code ONCE
  (only when the code row is first inserted), so moving a route to a new code does not lock out custom roles.
  Built-in roles get ROLES_CONFIG codes only when the role is created or the code is new in that run; grants of
  EXISTING codes go through `ONE_TIME_ROLE_GRANTS` (batch ids in system_parameters). Editing ROLES_CONFIG alone does nothing on old DBs.
- PO OCC check is service-only (`PurchaseOrderRepository.update` no longer exists). Header-only PO updates never recompute
  totals (`MEASUREMENT_FIELDS`); CBM pushes go through `PurchaseOrderService.apply_measurements`.
- Migrations may seed rows only when they CREATE the table (test_4 builds it via create_all, counts stay equal).
- [Phase 3b ODC/DCA/SDU quirks](phase03b_support_modules.md) - lifecycle self-commit, DCA user fallback, shell heredoc pitfall
- [import_documentation quirks](import_documentation_quirks.md) — 3a repo contract, NOT NULL ACID expiry, fast RBAC router tests
- [app_update.md](app_update.md) — update core + Phase 5 apply/rollback test seams (data dir, signing keys, testkit).

## Customs clearance 06-07 (2026-10-05)
- `customs_clearance/service.py` pattern: validate -> `_commit_write(db, write)` (one commit, retries on clearance/invoice
  code IntegrityError) -> side effects via `_follow_up` (= `errors.best_effort` + commit). Reuse it for new steps.
- One duty formula `duty_components_total` (7 fields, `validators.DUTY_COMPONENT_FIELDS`); payment/release guards in
  `validators.py` (`is_duty_fully_paid`, tolerance 0.01). Legacy `/{id}/pay-duty` + `/complete-release` are adapters.
- SmartTask has NO `completion_notes` column (it was a transient attr): task notes go to `notes`.
- Pytest runs in this worktree sometimes die silently mid-session (exit 127, no junit xml); run one file per
  pytest call and retry, aggregate the per-file XMLs.

## Phases 4-5 (freight booking, insurance, cargo shipping, shipment updates, demurrage; 2026-10-05)
- Heredocs mangle backslash escapes in code: use Write/Edit. Check CRLF vs LF before line-splitting a file (wiped one).
- `lifecycle_board.service.transition_stage_service` does NOT exist (old EIR code swallowed the ImportError); use
  `advance_lifecycle_step_service(completed_step_code=..., target_step_codes=[...])` (commits internally).
- `CurrencyService._get_rate_to_egp` silently falls back to hard-coded rates (USD 48.5...): for "no fake FX" read
  `CurrencyRepository.get_latest_rate` directly and 409 when missing (demurrage `_resolve_exchange_rate`).
- `financial_settlement.service.recalculate_settlement_service` commits and sets status "Calculated"; run it as a best_effort follow-up.
- Demurrage money: `demurrage_detention.service._resolve_tariff(db, policy)` + `_recalculate_containers` (keeps non-computed
  container keys). Insurance: `load_insurance_rates(db)` -> `calculate_cargo_insurance_engine(input, rates)`.
- Creating a settlement from another module: `financial_settlement.repository.add_with_new_code(db, record)` (savepoint
  retry) + `validators.ensure_settlement_editable` before adding rows to an existing one (Approved/Closed are frozen).
- Demurrage: every recalculation uses `_tracking_tariff(db, tracking)` (policy + booking free days + BK-02 keys stored on
  containers `agreed_*_free_days`). Pushed trackings re-push via `_repush_recalculated` (locked -> DD_SETTLEMENT_STALE).
- ImportFile.current_phase_id is the 6-phase BOARD id; shipment_updates' "Phase 1..10" are business phases: map via
  `shipment_updates.validators.BUSINESS_PHASE_BY_STEP` (current_step_code first). current_module = "STEP_xx Name".
- `AuditLogService.log_activity` commits: call it as a best_effort follow-up after the main commit.
- Explicit null on NOT NULL columns in PUT: filter with `common.validators.not_null_columns(Model)` in the service.
- Test fixtures: `DemurrageTracking(...)` needs an explicit `exchange_rate` (NOT NULL, no default since the review wave);
  `create_booking_service` rejects status Confirmed/Sailed (409): create "Booking Requested" then `confirm_booking_service`.
- [phase08_10_modules.md](phase08_10_modules.md) — closure gate, missing container_tracking, coded_error, pinned-copy testing.

## financial_approval (Phase 2 quality, 2026-10-05)
- Errors: `validators.fa_error(status, code, ar, **params)` (never a param named `code`). No FX fallback (`_require_rate`,
  FA_FX_RATE_MISSING): tests seed Currency+ExchangeRate (`tests/unit/test_phase02_support.py`). Sync/override need `current_user`.
- Long pytest runs here get killed (exit 127) and shared-scratchpad files vanish: run files one by one, piped, junit in `mktemp -d`.

## Phase 09 settlement (2026-10-05)
- FX in financial_settlement: `service.SettlementFx(db, rate_type).rate(ccy, date)` (409 SETTLEMENT_FX_RATE_MISSING when
  CurrencyService answers its built-in fallback, i.e. rate_id None). `CurrencyService._get_rate_to_egp` silently returns
  48.5/52.8... for missing rows: never trust it without checking rate_id. Tests must seed ExchangeRate + `clear_currency_cache()`.
  PO/insurance `exchange_rate` columns default 1.0 (= "not set" on foreign currency): `purchase_order_rate_to_egp`.
- Settlement expense rows <-> recalc fields: one classifier `settlement_expense_field` (engine labels first, then
  `actual_expense_bucket`); recalc writes a single `RECALC-ADJ-<field>` row (may be negative; schema allows it only there).
- `best_effort(db, fn, label, *args, **kw)` has its own `db` param: wrap calls that need `db=` in a lambda.
- Break-glass admin (2026-10-05): `sync_system_users` also creates `admin` / `admin_recovery[N]` (username+email
  free case-insensitively) when users exist but no ACTIVE `is_admin_user`; tests seeding non-admin users then expect +1.
  Legacy `users.role` is free text in any case: compare via `is_admin_user` / `.upper()`, never `== "ADMIN"`.
  `is_maintenance_mode` lives in `utils.db_safety` (not schema_upgrade_service).
- [DB safety / maintenance / seed admin](db_safety.md) - db_safety helpers, guarded scripts, frozen simulation, forced password change
- [review_wave_registry.md](review_wave_registry.md) - central code/enum/param registration, completeness scan test, variant codes
