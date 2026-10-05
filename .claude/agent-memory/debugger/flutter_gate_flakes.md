---
name: flutter-gate-flakes
description: Flutter gate noise - "did not complete"/exit 79/127 from concurrent agents, app_update isPolling in-flight window, design-refresh finder drift
metadata:
  type: project
---

- `flutter test` "did not complete [E]" for every test in a file with no exception, or exit 79 / 127, is
  interference from another agent's concurrent `flutter test` in the same worktree (shared build dir). Rerun
  before you start debugging. Seen 2026-10-05 (purchase_orders agent running alongside).
- app_update `isPolling` means "a poll Timer is scheduled". It is false while a /status call is in flight.
  Under CPU load a check made right after `statusCalls >= N` can land in that window (repro: run the
  session test with 2 heavy screen tests at default concurrency, failed 2 of 8 runs). Wait on
  `statusCalls >= N && notifier.isPolling`.
- Design refresh (2026-10) changed KPI strips: currency went into the title (`'<kpi> (EGP|جنيه)'`), values use
  CcFormat.money (`53,500.50`), short shared l10n labels repeat elsewhere. Scope finders with
  `find.descendant(of: MetricCardStrip|key)`.
- Form 46 no longer invents HS codes or tariffs. Tests need a PO line with an HS code plus a customs FX
  currency override, otherwise the EUR.1 card and the regulatory board are not rendered.

**Why:** these took most of the 2026-10-05 review-wave triage, and none of them was a product regression.
**How to apply:** rerun or isolate first. Check whether a missing label was renamed or depends on data before you restore it.
