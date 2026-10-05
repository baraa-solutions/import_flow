---
name: phase01-audit-decisions
description: 2026-10-05 Phase-1 audit — open CTO decisions (volumetric 167 vs /6000, RBAC gaps) and traps (PO line items recreated on update while other modules hold item_id)
metadata:
  type: project
---

Phase-1 audit plan: docs/plans/phase-01-quality-simplify-plan.md (proposed 2026-10-05; check git for status).

Non-obvious facts found:
- PO update rebuilds po_line_items (new item_id) but po_shipment_allocations, import_documentation and cargox hold po_item_id; CGX-003 columns (invoice_number, customs_unit_price) are not in the PO schema and get wiped.
- Air volumetric factor conflict: DOMAIN_RULES/PO use CBM×167, cbm_calculator uses /6000. Open CTO question Q1.
- Only purchase_orders has require_permission among Phase-1 routers; cbm, shipping_scenarios, customs_consultation, import_requirements, freight_quotations rely on authentication only.
- import_requirements raises ValueError for business errors -> global handler returns 500; a test pins it with pytest.raises(Exception).

**Why:** these shape any future Phase-1 plan and contract change.
**How to apply:** check the plan's Q1-Q9 answers before planning cargo math, permissions or PO item edits.
