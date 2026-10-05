---
name: ruling-vat-base-and-phase03
description: 2026-10-05 Phase-3 rulings - VAT base = CIF + import duty only (backend engine + worked example); client Form 46 must mirror it incl. schedule tax/import fee; non-column ImportFile writes
metadata:
  type: project
---

Ruling 2026-10-05 (Phase 3 import documentation review, uncommitted on feat/update-notice-rtl-p1).

(a) VAT base: the backend engine (modules/customs_tariff/service.py, "Unified VAT Base" ~l.234 and ~l.732)
uses VAT base = CIF + import duty only. The AGENTS.md worked example agrees (95,942 = 14% x (623,000 + 62,300)).
DOMAIN_RULES "+ other fees" is read as "other fees when the HS code makes them VAT-able", not dev/service fees by default.
Any client-side or secondary calculator that adds development/service fees to the VAT base is a BLOCKER, and so is one
that drops schedule tax / import fee from the total when the tariff row has them.

(b) Writing to ImportFile.total_amount / .currency / .incoterm (not mapped columns; real ones are incoterm_code,
estimated_cost_currency) or CargoShippingRecord.bl_number / vessel_name / total_gross_weight_kg / booking_no
(not columns) silently drops data; reading them raises AttributeError. Treat as BLOCKER when in a changed code path.

**Why:** these questions came up when reviewing the Form 46 calculator and DOC-02/DOC-13. Fixing the answers keeps later reviews consistent.
**How to apply:** check any new duty calculator against (a). Check with hasattr(Model, attr) before accepting attribute writes.
See [[ruling-cc01-service-fee-deemed-cif]].
