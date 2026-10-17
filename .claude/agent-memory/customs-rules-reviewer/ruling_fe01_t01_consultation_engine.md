---
name: ruling-fe01-t01-consultation-engine
description: PR #75 FE01-T01 (2026-10-09) customs consultation calls estimate-multi; saved duties = client sum of line taxes, not grand_total_payable_egp
metadata:
  type: project
---

PR #75 review 2026-10-09 (request_changes):
- BLOCKER: screen sums line duty+VAT+sched+dev+svc+import_fee and saves that as estimated_duties_egp; engine
  grand_total_payable_egp also includes total_inspection_fees_egp + additional/extra Nafeza fees (service.py:903-912).
- MAJOR: builder skips value<=0 lines without consuming a line_no, mapper uses its own counter -> per-line shift.
- MAJOR: freight FX falls back to invoice customs rate and is sent as manual freight_exchange_rate (overrides table).
- MAJOR: stale engine rows (insurance option / session load do not re-trigger; errors swallowed; total only written if > 0).
- Mapper fallback `exchange_rate ?? 1.0` and "CALCULATED" status on rows with no engine data.

**Why:** engine owns the total; the saved figure must be grand_total_payable_egp.
**How to apply:** on re-review check the screen reads engine totals, not client sums. See [[ruling-cc01-service-fee-deemed-cif]].
