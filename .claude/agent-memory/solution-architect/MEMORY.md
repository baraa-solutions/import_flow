# solution-architect memory

- Schema changes: models + Alembic migration; `database/schema_upgrade_service.py` also adds missing
  tables/columns at startup, so migrations must be additive-compatible with it.
- Lifecycle: 6 phases / 25 steps board (`modules/lifecycle_board/`); stage validation per GP-002.
- [Auth enforcement decisions](auth_enforcement_decisions.md) — router-level deps, bypass test seam, WS first-message auth, docs flag
- Record architecture decisions here (date, decision, reason) so later plans stay consistent.
