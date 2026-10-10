---
name: ruling-fe02-t01-swift-reconcile
description: FE02-T01 PR #78 SWIFT smart reconcile guard - smart path fixed; manual dialog still prefills amount=requested, date=today
metadata:
  type: project
---

2026-10-09 review of PR #78 (FE02-T01), Flutter swift_reconciliation_screen.dart.
- Smart path: ref/date/amount/currency no longer defaulted; missing -> orange SnackBar, no call. OK.
- Manual dialog (~l.539-554 at PR head): transferred amount still prefilled with pay.requestedAmount and
  receipt date with DateTime.now() (pre-existing). Ruled MAJOR against AC "user must enter amount": saving
  untouched dialog records transferred == requested (variance 0). Currency default = pay.currencyCode is per card.
- Variance fallback (extracted amount - requestedAmount) computed in Flutter is effectively dead (only shown when
  amount_matching.is_matched is true); MINOR, currency-agnostic.

**Why:** keep later SWIFT/financial-approval reviews consistent on what counts as an invented amount.
**How to apply:** prefilling a money field from a different concept (requested vs transferred) = invented value.
