---
name: ruling-fe07-t01-cl03-cl04-refs
description: FE07-T01 (PR #85, c7f5c35f) CL-03/CL-04 dialogs stop inventing SADAD/permit/gate-pass refs; money-lens verdict approve_with_minor
metadata:
  type: project
---

2026-10-09 PR #85 (cumulative on #84; diff vs company-pr/84). Money lens only.
- CL-04 demurrage field: blank when record null/0, `double.tryParse(..) ?? 0.0` at submit -> sends 0.0. Card step 6 explicitly allows this (backend accepts 0); not an invented value. OK.
- CL-03 duty_paid_amount prefill chain (actual > paid > estimated > file) untouched by this PR; same prefill-from-requested concern as [[ruling-fe02-t01-swift-reconcile]] but out of scope.
- Bank now nullable + validator; payload sends _bankName only after form validate. OK.
- Only MINOR: history/*.md + TASKS.md status row edited in PR.
**How to apply:** if a later task touches CL-04 demurrage, recheck whether blank should send null instead of 0.0 (would distinguish "not entered" from "zero").
