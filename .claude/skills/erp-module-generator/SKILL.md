---
name: erp-module-generator
description: Generate standard FastAPI 6-file module structure for ImportFlow ERP following AGENTS.md guidelines.
---

# ERP Module Generator Skill

Use this skill when scaffolding a new business module in ImportFlow ERP.

## Module Structure

Every module under `modules/<module_name>/` MUST contain:

1. `model.py` - SQLAlchemy models, foreign keys, constraints, indexes.
2. `schemas.py` - Pydantic request & response schemas.
3. `repository.py` - Database CRUD operations and queries (No business logic).
4. `service.py` - Business logic, transactions, workflow orchestration.
5. `validators.py` - Business validation, duplicate checks, stage rules.
6. `router.py` - FastAPI endpoints (No direct database or complex business logic).

## Guidelines
- Always use explicit Python type hints.
- Never hardcode dynamic tax/duty rates.
- Maintain soft-delete support (`is_active`, `deleted_at`).
