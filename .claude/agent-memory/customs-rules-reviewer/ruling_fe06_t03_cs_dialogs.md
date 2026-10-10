---
name: ruling-fe06-t03-cs-dialogs
description: FE06-T03 (PR #84) CS-01/02/03 dialogs - generators and 12500 fee removed; D/O expiry still today+14 leaks into free days via date pickers
metadata:
  type: project
---

2026-10-09, PR #84 head 39b8dca9 (cumulative on #83; reviewed diff 83..84 only).

- Ruled OK: DEL-/46-/MTS-/DO- generators removed, D/O fee starts empty with required validator, free days field required.
- MAJOR: delivery_order_payment_dialog.dart initState still sets `_doExpiryDate = _doDate + 14 days` when targetFreeDays is null; picking the issue or expiry date calls `_updateFreeDays()`, which fills free days from that invented expiry (picking today gives 14), and the invented expiry is also sent as `delivery_order_expiry`. Free days drive demurrage money.
- D/O currency default 'EGP' is out of scope (FE06-T14), not flagged.

**Why:** keeps future re-reviews of PR #84 consistent.
**How to apply:** on re-review, check that the expiry starts unset (nullable or required) when there are no free days on the file.
