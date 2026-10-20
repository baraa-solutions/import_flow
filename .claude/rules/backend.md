---
paths:
  - "modules/**/*.py"
  - "database/**/*.py"
  - "utils/**/*.py"
  - "alembic/**/*.py"
  - "main.py"
  - "settings.py"
---

# Backend rules (FastAPI / SQLAlchemy, Python 3.12)

- Layering: `router.py` (HTTP + auth dependency only) -> `service.py` (business logic, transactions)
  -> `repository.py` (queries). `validators.py` holds domain rules, `schemas.py` Pydantic models.
- Every route declares `require_permission("<module>.<action>")`, `require_admin`, or `get_current_user`.
  Codes live in `modules/auth/seed_rbac.py` `PERMISSIONS_CATALOG`. `Depends(get_db)` alone = public route.
- Python 3.12 evaluates annotations eagerly: import every name used in a signature (`Dict`, `Optional`,
  schema and model classes). The post-edit hook imports the edited module and blocks on failure.
- Schema change => Alembic migration in `alembic/versions/`. Master data by FK, never free text.
  Soft delete (`is_active` / `deleted_at` / `deleted_by`) with restore. Audit fields via shared helpers.
- New column on an existing table: give it a `server_default` (not only a Python `default=`), or keep it
  nullable AND backfill existing rows in the same migration. `schema_upgrade_service` adds late columns with
  plain `ALTER TABLE ADD COLUMN`, so without a server default every pre-upgrade row reads NULL.
- Response schemas must tolerate legacy rows: a field that can be NULL in old data is `Optional[...]` (money
  and rates stay `None`, never a fabricated 0 / 1.0), list responses use `LegacyRowTolerantModel` /
  `@read_model` from `modules/common/legacy_rows.py`, and input-only rules (lengths, ranges, formats) live on
  Create/Update schemas only. One bad old row must never 500 a whole list.
- The acting user comes from the login token only (`current_user` from the auth dependency), never from body
  fields (`approved_by`, `reviewer_name`, ...) or `X-User-*` headers.
- Every `import main` / pytest / TestClient probe uses a scratch `DATABASE_PATH` (startup stamps and backs up
  the DB it points at).
- A new coded error (`detail={code, message, ...}`) is registered in the same change in
  `modules/common/system_messages.py` + `docs/system_message_codes.json` (+ Flutter catalogs), or
  `tests/unit/test_review_wave_codes.py` fails; if those files are not yours, use `docs/plans/review-shared-needs.md`.
- Never fabricate data: no default exchange rate, tax rate, price, ACID, company, quantity or date; leave it
  null and require it.
- No `except Exception: pass`. User-facing validation errors: `HTTPException` with an Arabic `detail`.
- Tests: `tests/unit/test_<module>.py`. Read results from `--junitxml` + exit code (the console summary
  is suppressed after `import main`).
- Single-language constants storage (Tier 2 English): All statuses, stage codes, enum keys, and DB values must remain in English (`PENDING`, `CUSTOMS_RELEASE`). Never store localized Arabic strings in DB columns or status enums.

