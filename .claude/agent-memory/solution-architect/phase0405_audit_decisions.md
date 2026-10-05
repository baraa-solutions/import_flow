---
name: phase0405-audit-decisions
description: 2026-10-05 Phase 4/5 audit (freight booking, insurance, cargo shipping, shipment updates, demurrage) — non-obvious traps and open CTO decisions
metadata:
  type: project
---

Plan: docs/plans/phase-04-05-quality-plan.md (proposed 2026-10-05; check git for status). Q1-Q13 there.

Non-obvious facts found:
- None of the 5 routers had require_permission; no cargo_insurance permission code exists in the catalog.
- Demurrage recalculation paths (free-days BK-02, PUT tracking) rebuild container JSON and drop per-container EIR/gate-out keys; BK-02 recalc omits policy tiers so schema defaults apply.
- Demurrage push-to-settlement writes LandedCostSettlementRecord directly (own LCS code) — must reuse financial_settlement generate_settlement_code + recalculate_settlement_service.
- TR-05 smart task code TSK-0901-{file_id} is unique -> second partial EIR return 500s.
- Cargo shipping Flutter save always sends status 'Cargo Ready' -> resets approved records; PUT also auto-restores soft-deleted rows.
- CargoX checklist hard-codes ACID passed=True and fabricates tx hash.
- Dual-clock dialog reads keys the backend never returns.
- Hard-coded rates policy chosen: move to system_parameters seeded with current values (byte-identical), not delete.

**Why:** shapes later plans on landed cost, settlement and phase 6+ modules that reuse these engines.
**How to apply:** before planning demurrage/insurance math or settlement integration, check whether the plan landed and Q answers.
