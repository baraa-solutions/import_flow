---
name: ruling-be810-t07-dossier-no-invented
description: 2026-10-07 PR#33 BE810-T07 dossier stops inventing values - approve_with_minor; USD estimate default is a column default upstream
metadata:
  type: project
---

PR #33 (BE810-T07, base fix/be810-t06-dossier-fob-per-currency) reviewed 2026-10-07: approve_with_minor.

- markup factor / PO exchange_rate / item_code / net weight now None when missing; fob_source PO|ESTIMATE|None. Tests green.
- Supersedes T06 note: `imp.estimated_cost_currency or "USD"` in file_closure/service.py is practically dead code -
  import_files/model.py:157 column is NOT NULL default "USD" (schema default is the real invention, out of T07 scope). MINOR.
- Remaining 1.0 markup inventions outside file_closure: financial_settlement/service.py ~2110 (`else 1.0` when FOB 0,
  persisted to settlement.average_markup_factor) and Flutter `?? 1.0` in file_closure_model.dart:236 (precheck). MINOR follow-ups.

**Why:** consistent T06/T07/T20 split. **How to apply:** when reviewing T20 or settlement markup work, check these 1.0 fallbacks.

Re-review 2026-10-07 at 787ca4fa: all 3 MAJORs fixed (non-EGP PO rate 1.0/<=0 -> None, EGP keeps 1.0; imp markup
trusted only when actual_landed_cost_calculated_at set; Flutter precheck markup double? with '—'). 101 tests green
(clo03+clo04+phase08_10). New MINOR: precheck skips imp fallback when settlement exists with NULL average_markup_factor
(dossier falls back) - asymmetry. settlement 1.0-at-FOB-0 still flows through settlement branch (known follow-up).
