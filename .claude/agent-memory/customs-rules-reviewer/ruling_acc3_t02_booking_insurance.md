---
name: ruling-acc3-t02-booking-insurance
description: PR #42 ACC3-T02 ruling (2026-10-07) - INSURANCE 422 on write OK, but legacy insurance lines still summed into total_freight_cost_usd on recalc
metadata:
  type: project
---

PR #42 (ACC3-T02, base fix/be45-t01-booking-cost-engine), reviewed 2026-10-07: approve_with_minor-level work but flagged MAJOR.
- validate_charges 422 on INSURANCE (category or inferred from charge_type) on create/update: OK.
- calculate_transit_time_and_costs (modules/freight_booking/service.py ~146-163) tags charge_category but still adds
  every line incl. legacy INSURANCE to total_cost; any recalc (status/date updates) keeps legacy 350 USD insurance in
  the freight total -> settlement still double counts for legacy bookings. Fix: skip INSURANCE in total_cost.
- STORAGE still summed (deferred to Q2 per card) - not a finding beyond MINOR note.
- Settlement test seeds total_freight_cost_usd=4000 directly, never runs the booking engine: weak guard.

**Why:** keep consistent rulings on booking-total exclusions for ACC3-T02 follow-ups and the Q2 storage task.
**How to apply:** when storage (Q2) lands, expect the same exclusion-in-total pattern; check legacy rows on recalc.
