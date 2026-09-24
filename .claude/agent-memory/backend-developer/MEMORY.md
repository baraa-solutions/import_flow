# backend-developer memory

- `import main` runs `SchemaUpgradeService.execute_safe_startup_upgrade` at import time: it applies DDL and, if
  the DB file exists and is non-empty, writes a backup snapshot to `backups/`. For smoke checks set
  `DATABASE_PATH` to a fresh temp file and `SECRET_KEY` (32+ chars) so nothing touches the live DB or `.env`.
- `settings.py` appends a generated `SECRET_KEY` to `.env` when none is set.
- tests: `tests/conftest.py` sets `DATABASE_PATH` to a temp DB and `ALLOW_DEV_AUTH_BYPASS=true`.
- Undefined-name sweep that works: `python -m pyflakes modules database utils main.py` (install pyflakes to a
  scratch dir with `pip install --target`). String annotations with function-local imports are false positives.
- `modules/import_documentation/{router,service}.py` use `from ...schemas import *` — pyflakes cannot check
  them; import models explicitly there (e.g. `CustomsDeclarationDraft` from `.model`).
- `modules/cargox/city_port_resolver.py` loads a 4.5 MB JSON cache once per process.

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
- Free-text roles: `test_auth.py` registers users without seeding roles and expects `role == "MANAGER"`, so unknown
  role strings are still stored (only `.strip().upper()` applied). Rejecting them needs a lead decision.
- Lifecycle board role comes from `effective_role_code(current_user)` (returns "ADMIN" for any admin first),
  never X-User-Role headers.
- Python edits on CRLF files: read with default newline, write with `newline="
"`; heredoc-embedded Python
  with many triple quotes can break the Bash tool - write the script to the scratchpad with Write instead.
- `/health` opens the hard-coded `sorour_logistics.db` in cwd: do not call it from tests.

## Running tests
- Full `tests/unit` takes more than 10 minutes: start it with `run_in_background` and wait for the notification.
- Windows console is cp1252: when printing junit XML failure messages with Arabic text, call
  `sys.stdout.reconfigure(encoding="utf-8")` first.
- Other agents may edit routers in the same worktree concurrently; attribute full-suite failures by module before fixing.
- Auth deps: `modules.auth.router` exports `get_current_user`, `require_admin`, `require_manager_or_admin`;
  `require_permission(code)` lives in `modules.auth.permissions` and calls `resolve_user` itself, so
  `dependency_overrides[get_current_user]` does NOT affect it. Importing `modules.auth.router` from module routers
  causes no circular import. Standard pattern: `APIRouter(..., dependencies=[Depends(get_current_user)])`.
- Strict auth tests: small FastAPI app + in-memory StaticPool engine + `seed_rbac`, users with real roles,
  `create_access_token({'sub': str(user_id)})` bearer, and monkeypatch `auth_permissions.ALLOW_DEV_AUTH_BYPASS=False`
  (conftest seam otherwise hands out a transient ADMIN). Auth deps fail before body validation: an allowed user with
  an invalid body gets 422, which proves auth passed without running the handler. Example:
  `tests/unit/test_router_auth_tightening.py`.
- `import modules.x.router as r` can yield the APIRouter object (package `__init__` re-exports `router`); use
  `importlib.import_module("modules.x.router")` in tests.
- Editing files from Python on Windows: use `open(..., newline="")`; `Path.write_text` rewrites line endings.
  `modules/import_companies/router.py` contains a stray bare `\r` (git marks it -text) — edit it byte-wise.
