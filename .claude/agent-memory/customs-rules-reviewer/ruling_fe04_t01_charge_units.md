---
name: ruling-fe04-t01-charge-units
description: FE04-T01 PR #79 (2026-10-09) freight booking charge units, cancellation fee, mixed-currency guard ruling
metadata:
  type: project
---
PR #79 head 43daeab5 reviewed 2026-10-09: approve_with_minor.
- Backend `_calculate_*` in modules/freight_booking/service.py multiplies only unit == "Per Container" by total container count; other units keep qty. So 'Per 40ft/20ft Container' fixes 2x40@2000+1x20@1000 -> 5000 (was 9000).
- Residual (pre-existing, not FE04-T01 scope): SOLAS/VGM 'Per Container' qty 1 in Flutter banner vs N containers on save; LCL total = rate*cbm in Flutter but backend rate*ceil(cbm); single non-USD currency still lands in total_freight_cost_usd (FX out of scope).
**How to apply:** if BE-08 / FX tasks land, recheck these three gaps.
