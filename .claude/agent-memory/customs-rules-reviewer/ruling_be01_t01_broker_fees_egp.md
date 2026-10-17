---
name: ruling-be01-t01-broker-fees-egp
description: BE01-T01 (PR #53) broker fee EGP conversion ruling 2026-10-09 - commercial rate at created_at date accepted; fx=None raw-sum fallback flagged MINOR
metadata:
  type: project
---

PR #53 af7d528e, reviewed 2026-10-09: approve_with_minor. 26 tests green (be01 + customs_consultation*).
- Per-line conversion `total_amount * SettlementFx(db,"commercial").rate(currency, cairo_date(created_at))`, rounded to 2 dp at the end: matches card. The rate date is the session's created_at, also on update (accepted as the card says; CTO Q1 decides rate type).
- MINOR: `_recompute_metrics` fx=None branch sums line totals in mixed currencies without converting. Every current caller passes fx, so this code never runs today.
- Schema default `currency="EGP"` on quote items existed before this PR. It is not a BE01-T01 finding.

**Why:** keep rulings consistent for BE01-T08/T12 follow-ups.
**How to apply:** if a later PR adds a caller without fx, raise that fallback to BLOCKER.
