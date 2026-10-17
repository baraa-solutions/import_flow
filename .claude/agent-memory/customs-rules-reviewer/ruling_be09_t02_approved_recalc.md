---
name: ruling-be09-t02-approved-recalc
description: PR #48 BE09-T02 ruling - approved settlement stays Approved on justified recalc; file variance re-derived from old_total-old_var
metadata:
  type: project
---

2026-10-09 PR #48 (head 6840826c): approve_with_minor.
- Status kept Approved via current_status param in _apply_in_place_to_entity; variance refresh in _refresh_file_landed_cost
  recovers estimated = old_total - old_var, same formula as approval (financial_settlement/service.py:2344-2345).
- Accepted gaps: legacy file with variance NULL keeps stale variance while total updates; test covers PUT 409 only (not DELETE / /recalculate).
- 29 tests green (test_recalculation_engine + test_customs_consultation_recalculation).

**Why:** consistent rulings across BE09 tasks. **How to apply:** BE09-T03 touches the same apply path; see [[ruling-phase09-settlement]].
