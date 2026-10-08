---
name: ruling-be45-t01-booking-fx
description: BE45-T01 (PR #41, 2026-10-07) booking charge FX to USD + per-container-type qty; db=None 1.0 fallback, FE hard-coded 40HC tag
metadata:
  type: project
---

PR #41 (BE45-T01 + absorbed ACC3-T01), reviewed 2026-10-07: approve_with_minor.
- Math matches card: fx = rate_to_egp(ccy)/rate_to_egp(USD) commercial at confirmation date (today if unconfirmed); 409 via shared resolver; line rounded then summed; 43 related tests green.
- Leftovers: `fx_rate_to_usd = 1.0` when `db is None` (unreachable, all callers pass db); FE tags "Sea Freight 40ft" as 40HC, so picking 40GP/45HC in the container dropdown gives 422 on save.

**Why:** card step 6 told FE to hard-code 40HC/20GP; reviewers judged it a usability gap, not a money error.
**How to apply:** for ACC3-T02 / BE45-T20 follow-ups, check whether the container-type mapping was made dynamic and whether the db=None fallback was removed. Related: [[ruling-bew0-01-fx-resolver]].

Re-review 2026-10-07 at e7437ae2 (request was changes after 78f13736): SH-01 currency seed fixed (89/89 booking tests green);
db=None now 422, is_active checked. FE now tags sea-freight lines with the first allocated 40/45 or 20 type, but changing
row 0 across sizes (40HC -> 20GP) silently drops the 40ft freight line, and with mixed 40+20 quotes the 20ft rate gets
priced at the 40ft count. Ruled MAJOR (silent understated freight, user-driven off-quote edit), not BLOCKER. No 40GP widget test.
Still open minors: zero commercial rate -> amount_usd 0, plain-string 422s, ref date not Cairo.
