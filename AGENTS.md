# 🤖 AI Agent Guidelines — ImportFlow ERP (index)

> هذا الملف فهرس فقط. القواعد نفسها في الملفات دي — لا تكررها هنا.

## Rule files

| File | Loaded | Owns |
|---|---|---|
| [`.agents/rules/AI_WORKFLOW.md`](.agents/rules/AI_WORKFLOW.md) | read first | Task loop, run locally, tests, how to write the code, self-review |
| [`.agents/rules/CORE_RULES.md`](.agents/rules/CORE_RULES.md) | every session | Stack, architecture, testing, security, forbidden practices |
| [`.agents/rules/DOMAIN_RULES.md`](.agents/rules/DOMAIN_RULES.md) | on read | Customs / landed-cost engine, stages, soft delete |
| `.claude/rules/backend.md`, `flutter.md`, `customs-domain.md` | by file path | Per-layer rules (auth, migrations, legacy rows, l10n, RTL) |
| `.claude/agents/*.md` | per agent | Lead operating loop, agent roles, standing rules |
| [`.agents/rules/UI_SCREEN_STANDARDS.md`](.agents/rules/UI_SCREEN_STANDARDS.md) | stub | Points to the `ui-screen-standards` skill |

## Skills (source: `.claude/skills/`, copies in `.agents/skills/`)

`ui-screen-standards` · `screen-audit` · `erp-module-generator` · `customs-landed-cost-engine` · `cbm-calculator` ·
`acid-expiry-tracker` · `smart-nafeza-parser` · `history-logger` · `spec` · `release-check` · `ci-status` · `git-sync`

## System context

ImportFlow ERP (Sorour Logistics): import management, customs clearance, freight & logistics, landed cost,
document management, CargoX / Nafeza. Treat it as an enterprise application, not simple CRUD.

## Language

| Context | Language |
|---|---|
| Talking to the user | Arabic (Egyptian preferred) |
| Code / DB / API / file names | English only — `country_id = 64`, never `country = "مصر"` |

## Stack

Backend: Python 3.12, FastAPI, Pydantic v2, SQLAlchemy 2, Alembic, SQLite (`sorour_logistics.db`).
Frontend: Flutter 3.x Windows desktop, Riverpod, dio, go_router.

## Task completion

Tests green for the changed area → docs in `docs/` if needed → append to `history/YYYY-MM-DD.md` (append-only).
