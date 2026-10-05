# solution-architect memory

- Schema changes: models + Alembic migration; `database/schema_upgrade_service.py` also adds missing
  tables/columns at startup, so migrations must be additive-compatible with it.
- Lifecycle: 6 phases / 25 steps board (`modules/lifecycle_board/`); stage validation per GP-002.
- [Auth enforcement decisions](auth_enforcement_decisions.md) — router-level deps, bypass test seam, WS first-message auth, docs flag
- [Update system decisions](update_system_decisions.md) — watchdog/202 rule, no taskkill /T, rollback installer cache, Alembic startup order
- [Update distribution constraints](project_update_distribution.md) — private repo, single laptop, Hostinger static + Ed25519 manifest, DB safety first
- [Bash guard blocks package_production.py mentions](bash_guard_package_production.md) — use Grep/Read tools to inspect it
- [RTL / localization decisions](rtl_localization_decisions.md) — root cause (no supportedLocales), icon double-flip, bidi minus, ratchet guard
- [Single-language storage](single_language_storage_decisions.md) — T1 msg_code+params w/ English render, T2 English, T3 enum codes; traps
- [Phase-1 audit decisions](phase01_audit_decisions.md) — 167 vs /6000 conflict, RBAC gaps, PO item_id rebuild trap
- [Phase-3b audit decisions](phase03b_audit_decisions.md) — DCA fake matrix rows, ODC auto-approves DCA, smart-upload callers, cairo_today location
- [Phase-3a audit decisions](phase03a_audit_decisions.md) — view/upload/approve perms, server-owned review status, no fabricated customs defaults
- [Phase-2 audit decisions](phase02_audit_decisions.md) — best_effort rollback trap, no FA manage perm, tests pinning Draft->Paid
- [Phase-9 audit decisions](phase09_audit_decisions.md) — approve corrupts settlement JSON, FX 48.5, recalc double-count, Q1-Q12
- [Flutter audit traps](flutter_audit_traps.md) — silent Pydantic key drops, fabricated defaults, null-on-error lookups
- [Phase-8/10 audit decisions](phase08_10_audit_decisions.md) — fail-open closure gate, bad SystemNotification kwargs, reopen→Phase 1
- [Phase-6/7 audit decisions](phase06_07_audit_decisions.md) — lifecycle commits inside, best_effort-after-commit, settlement reads duty fields
- [Phase-4/5 audit decisions](phase0405_audit_decisions.md) — DD recalcs drop EIR keys, settlement bypass, CargoX fakes, rates->system_parameters
- [AI config layout](ai_config_layout.md) — dangling AGENTS.md refs, two skill trees, VAT base = CIF+duty (decided), config edits are lead's
- Record architecture decisions here (date, decision, reason) so later plans stay consistent.
