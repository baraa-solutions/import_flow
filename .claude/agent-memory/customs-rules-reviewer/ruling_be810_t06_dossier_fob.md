---
name: ruling-be810-t06-dossier-fob
description: 2026-10-07 PR#26 BE810-T06 dossier FOB per currency - money path correct; estimate fallback still defaults currency to USD
metadata:
  type: project
---

PR #26 (BE810-T06, base fix/bew0-01-shared-fx-resolver, head 7783eb68) reviewed 2026-10-07: approve_with_minor.

- Dossier FOB: fob_by_currency per PO currency; unknown currency -> total_fob_fc/fob_currency/total_fob_egp None;
  EGP = settlement first, else clearance stored rate (single currency, rate != 1.0), else customs rate at Form 46 date.
  Card numbers verified by test: USD 10,000 @50.50 + EUR 5,000 @55.20 = 781,000 EGP; single USD = 505,000.
- Ruled MINOR (left for BE810-T07): estimated-cost fallback `imp.estimated_cost_currency or "USD"` (service.py ~472)
  is an invented currency that flows into total_fob_egp. Fix = treat NULL currency as unknown.
- Running PR tests without checkout: `git archive refs/remotes/company-pr/<n> -- . ':!frontend' ':!docs' | tar -xf - -C <scratchpad>` then pytest there (use /c/... path, not C:/ for tar).

**Why:** keeps T06/T07 split consistent across reviews. **How to apply:** when reviewing T07, check this USD default is removed.
