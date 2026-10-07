---
name: ruling-be67-t02-agreement-rate
description: 2026-10-07 PR #40 BE67-T02 preferential-agreement helper ruling - 10-digit HS mismatch, _customs_rate extension
metadata:
  type: project
---

PR #40 (BE67-T02) ruling, 2026-10-07: `_agreement_duty_rate` helper is correct (fixed_rate uses preferential_duty_rate,
percentage 0..1, unknown type -> 422); on_date now passed in all three engines. Legacy reduction_percentage > 1 rows now
raise 422 (intended by card). Seeds and Nafeza parser already write 0..1.

Gap: repository agreement match only strips dots, so a 10-digit request `8536410000` does NOT match `8536.41.00`
(`85364100`), while `get_active_tariff_on_date` does match it -> estimate silently uses full duty. Card acceptance
names the 10-digit case; the PR test uses 8 digits. The card's Step 2 and acceptance contradict each other.

Accepted scope extension: `_customs_rate` wraps CurrencyService._get_rate_to_egp and refuses rate_id None (blocks the
48.50 fallback, see [[ruling-bew0-01-fx-resolver]]); untested; CT_CUSTOMS_RATE_MISSING not in system_messages.

**Why:** keep later reviews of BE67-T13/T14/ACC1-T04 (depend on T02) consistent.
**How to apply:** check whether a follow-up normalised HS to 10 digits on both sides before re-flagging.
