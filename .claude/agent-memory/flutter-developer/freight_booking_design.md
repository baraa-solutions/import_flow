---
name: freight-booking-design
description: Freight booking design pass (2026-10-05) - widget split, no-fabricated-defaults decisions, form/validator traps, ENOSPC and cross-agent compile breaks
metadata:
  type: project
---

- `freight_booking/widgets/`: `freight_booking_ui.dart` (FbkFormat, FbkUi.status/snack/fit, FbkNotice, FbkPromptDialog,
  FbkDateField FormField, FbkSavingsSummary, FbkButtonWrap), `_registry_row` (card row, FbkRowActions), `_toolbar`
  (FbkActionBar/FbkFilterBar), `_form_dialog` (public FreightBookingFormDialog, 17-item state kept as fields), `_cost_row`,
  `_quote_card`, `_prompts` (FbkPrompts: delete / mismatch / duplicate), `_confirm_dialog` (BK-01), `_view_dialog`,
  `_print_dialog`, `departure_confirmation_dialog` (SH-01). Dialogs reuse CcStageDialogShell / CcFormSection / CcField /
  CcFieldRow / ccInputDecoration / CcDateTile (customs_clearance) and ShippingStepSwitcher / ShippingDialogFrame (cargo_shipping).
- Form: both tabs stay mounted via `Offstage` so validators cover every field; cost-row TextFormFields use a
  `_quoteRevision` ValueKey so applying a quote refreshes their `initialValue`.
- SearchableDropdownField validators must read the State field, not the validator argument (FormField initialValue goes
  stale when the value is changed from outside, e.g. a quote apply). Pass `hintText` (the child Text shows it), the
  decoration hint alone is not drawn.
- Removed fabricated data: sample confirmation no / vessel / voyage / release order / ports / carriers, owner 'Kamal'
  (model default now ''), container MSCU... / seal / VGM invented on quote apply, 8500 USD default rate, 40 CBM / 2274 kg
  cargo fallback (now no recommendation + cshCargoMetricsMissing notice), ETD/ETA now+5/+23, free days 14.
- Left on purpose: expected warehouse days 7, freight terms 'Collect' (no UI), departure dialog ATD defaults to ETD/now,
  clone flow opens the form with bookingId 0 as an EDIT (create vs update decided by `bookingToEdit == null`).
- Tests: `test/freight_booking_design_test.dart` (providers stubbed with StateNotifier fakes; `createBooking` returns
  `Future<ShipmentBookingModel?>`).
- Pitfalls: Git Bash `sed -i` strips CRLF from CRLF files (re-add with `sed -i 's/\r$//; s/$/\r/'`); disk D: filled up
  (ENOSPC on Edit) - deleting `frontend/build` of the worktree frees ~280 MB; a half-done change in another agent's
  `demurrage_model.dart` (nullable exchangeRate) broke compile of every test importing `row_history_dialog` ->
  `master_data_export_service`; wait and retry rather than editing core.

**Why:** hit during the freight booking pass.
**How to apply:** reuse the Fbk widgets for booking-like screens; keep forms free of sample defaults.
