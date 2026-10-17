---
name: ruling-be45-t04-nullable-free-days
description: PR #71 BE45-T04 (2026-10-09, head e1f1dd0a) nullable free_demurrage_days; backend OK; Flutter form still sends ?? 14; legacy test red
metadata:
  type: project
---

PR #71 BE45-T04 reviewed 2026-10-09. Backend matches card steps 1-9; card fixture verified by new tests
(policy 21, 22 consumed -> 1 overdue day, 40.00 USD; agreed 0 -> 22 days).

- BLOCKER: `frontend/.../freight_booking_form_dialog.dart:623` still sends `int.tryParse(...) ?? 14` on create AND
  edit. Empty field -> 14 stored -> engine `_agreed_tariff` now honours any non-null -> overrides 21-day policy
  (350.00 vs 40.00). Card's Flutter list omitted this line, but the PR goal is "no invented 14".
- MAJOR: `tests/unit/test_legacy_row_list_tolerance.py:138` still expects 14 on NULL -> red. Gate skipped it.
- MINOR leftovers: `lifecycle_board/service.py:1451` `or 14`; legacy rows stored 14 by the old default stay 14.

**Why:** gate runs only mapped tests; Flutter default lived in two widgets, card listed one.
**How to apply:** on re-review grep frontend for `?? 14` near free days and run test_legacy_row_list_tolerance.py.
Related: [[ruling-phase04-05-insurance-demurrage]], [[ruling-be45-t02-recalc-before-push]].
