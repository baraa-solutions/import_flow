---
name: ruling-acc2-t01-po-shares
description: ACC2-T01 PR #39 (2026-10-07) ruling on file_po_line_shares, qty-0 lines dropped in CLO-02/PL-08, CI 401 in consultation test not from diff
metadata:
  type: project
---

PR #39 (ACC2-T01, head 64efaabb) reviewed 2026-10-07: approve_with_minor.
- `file_po_line_shares` matches card steps 1-5; card test numbers (400/600, 200,000, 650.00, PO-level 40 %, recalc 200,000) pass.
- Card-mandated basis change: CLO-02 / PL-08 / recalc now use unit_price x qty_share (not total_price / header FOB). Not a finding; FOB basis is ACC2-T06.
- MINOR: lines with quantity 0/NULL are skipped in CLO-02 and PL-08 without a message (create path keeps them at qty 0).
- `recalculate_settlement_totals` added unused (BEW0-06 leftover) -> unrelated scope.
- CI: failure was tests/unit/test_customs_consultation_recalculation.py 401 (test overrides only get_db, relies on another test's auth override) -> order-dependent, not from this diff. Same family as the clo04 401 flake.

**Why:** keeps rulings on partial-shipment shares consistent for ACC2-T06 / BE09-T03 reviews.
**How to apply:** when reviewing ACC2-T06, check it reuses file_po_line_shares and handles qty-0 lump-sum lines with a message.
