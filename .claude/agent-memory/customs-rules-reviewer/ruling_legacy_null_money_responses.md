---
name: ruling-legacy-null-money-responses
description: 2026-10-05 ruling on Optional[float] legacy-NULL money/rate fields in Clearance/Warehouse/Booking responses (LegacyRowTolerantModel)
metadata:
  type: project
---

Ruling (2026-10-05): returning legacy NULL money/rate as null in CustomsClearanceResponse / WarehouseReceivingResponse /
ShipmentBookingResponse is SAFE for calculations. The response models are only used as router response_model; no
service reads them back. ORM math in customs_clearance, financial_settlement, file_closure, route_intelligence uses
`or 0.0` guards.

Open gaps found then:
- smart_checklists/service.py `clr.actual_duty_total > 0` / `clr.import_duty_amount > 0` raise TypeError on NULL (not in that diff).
- Flutter customs_clearance_model.dart `customs_exchange_rate ?? 1.0` re-creates the fabricated 1.0; the CL-02 dialog
  then pre-fills "1.00" when cif > 0. All Flutter money fields `?? 0.0` show 0.00 for unknown.

**Why:** the point of the change is "missing money must not read as 0 / rate as 1.0"; a client-side fallback undoes it.
**How to apply:** for any future null-tolerance change, check the Dart fromJson defaults and the non-guarded `>` comparisons.
