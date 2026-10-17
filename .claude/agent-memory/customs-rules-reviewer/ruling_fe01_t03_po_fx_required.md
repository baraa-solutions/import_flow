---
name: ruling-fe01-t03-po-fx-required
description: PR #77 FE01-T03 (2026-10-09) PO exchange rate required, no 1.0 fallback; stale po_form_dialog_input_test, setState-in-build, inactive rates
metadata:
  type: project
---

PR #77 (ca68ad97) FE01-T03, reviewed 2026-10-09: request_changes.
- Math OK: pickCommercialRate picks latest effectiveDate <= order date (string compare on backend `date` ISO), null otherwise; base/EGP -> 1.0; save/preview no `?? 1.0`.
- MAJOR: frontend/test/features/po_form_dialog_input_test.dart 2 tests red at PR head (green on main): USD fixture has no rates, so save is now blocked. CI gate does not run them.
- MAJOR: `_updateExchangeRateFromCurrency` now calls setState; it is called from build() (po_form_dialog.dart:1518, smart-upload new PO path) -> setState during build.
- MINOR: helper ignores ExchangeRateModel.isActive (backend get_latest_rate filters is_active and orders created_at desc); purchase_orders_screen.dart:1232,2133 print "null" for nullable rate; backend PurchaseOrderCreate.exchange_rate still defaults 1.0 (BE-07).

**Why:** keep later PO/FX reviews consistent ([[ruling-be45-t01-booking-fx]] same stale-test pattern).
**How to apply:** on re-review check fixture rates added, the build-path call guarded, isActive filter.
