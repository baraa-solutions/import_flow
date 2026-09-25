# solution-architect memory

- Schema changes: models + Alembic migration; `database/schema_upgrade_service.py` also adds missing
  tables/columns at startup, so migrations must be additive-compatible with it.
- Lifecycle: 6 phases / 25 steps board (`modules/lifecycle_board/`); stage validation per GP-002.
- [Auth enforcement decisions](auth_enforcement_decisions.md) — router-level deps, bypass test seam, WS first-message auth, docs flag
- [Update system decisions](update_system_decisions.md) — watchdog/202 rule, no taskkill /T, rollback installer cache, Alembic startup order
- [Update distribution constraints](project_update_distribution.md) — private repo, single laptop, Hostinger static + Ed25519 manifest, DB safety first
- [Bash guard blocks package_production.py mentions](bash_guard_package_production.md) — use Grep/Read tools to inspect it
- Record architecture decisions here (date, decision, reason) so later plans stay consistent.
