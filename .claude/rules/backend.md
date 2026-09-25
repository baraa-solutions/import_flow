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
- No `except Exception: pass`. User-facing validation errors: `HTTPException` with an Arabic `detail`.
- Tests: `tests/unit/test_<module>.py`. Read results from `--junitxml` + exit code (the console summary
  is suppressed after `import main`).
