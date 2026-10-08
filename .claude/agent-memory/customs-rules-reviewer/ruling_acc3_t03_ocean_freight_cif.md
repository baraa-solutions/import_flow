---
name: ruling-acc3-t03-ocean-freight-cif
description: PR #45 ACC3-T03 first review 2026-10-07 - estimate CIF freight = awarded quote ocean_freight_cost only; approved
metadata:
  type: project
---

PR #45 (ACC3-T03, base fix/acc2-t01-partial-po-landed-cost), first review 2026-10-07: approve_with_minor.
- `simulate_estimated_landed_cost_service` now uses `winning_q.ocean_freight_cost` (NULL -> 0 -> deemed rate),
  active RFQ only, quote must belong to the RFQ. Matches the card exactly; worked example
  (FOB 100k USD @50, ocean 3,000, freight 150,000, CIF 5,275,000, duty 527,500, VAT 812,350) verified by test.
- Ocean 0 with total > 0 falls to deemed %, not to total_cost: correct (repository total = ocean+local+inland).
- MINOR only: history/2026-10-07.md says it falls back to total_cost (it does not).

**Why:** keeps future reviews of freight-into-CIF consistent (local/inland stay out of CIF; separate THC/inland lines).
**How to apply:** any other path that feeds a quote's total_cost into CIF is the same bug (see [[ruling-be67-t04-simulate-file]]).
