---
name: ruling-be67-t04-simulate-file
description: BE67-T04 PR #44 (2026-10-07) simulate-file ruling - per-PO FX OK, but blank PO currency defaulted to EGP and blank quote currency defaulted to first/USD
metadata:
  type: project
---

PR #44 (BE67-T04, base fix/acc1-t01-freight-customs-fx), reviewed 2026-10-07: request_changes.
- Per-PO conversion to EGP + engine currency=EGP/rate=1 is correct; acceptance math 52,250 / 57,475 tested and passing (10 tests).
- BLOCKER ruling: PO with no currency -> `po_curr = "EGP"` (service.py ~1459) is an invented currency (rate 1.0); must skip line (reason NO_CURRENCY) like invoices.
- MAJOR: blank freight-quote currency -> first of a set or "USD" (~1598); manual req.exchange_rate applied to first PO only / all invoice currencies.
- qty 0 -> 1.00 on the engine line is NOT money (engine ignores qty); MINOR at most.
**Why:** keep "no invented currency" rulings consistent with [[ruling-be810-t07-dossier-no-invented]].
**How to apply:** in follow-ups, a missing currency must never resolve to EGP or USD silently.
