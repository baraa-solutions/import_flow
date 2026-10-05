---
name: phase01-planning-modules
description: Pitfalls in customs_tariff multi-item engine, CurrencyService fallback rates, CBM/shipping-scenario/consultation models
metadata:
  type: project
---

- `tests/unit/test_phase01_characterization.py` pins PO/CBM/scenario math; its `EXPECTED_TO_CHANGE` list names tests an approved change may edit.
- PO `Numeric(10,4)` columns quantize on READ: clone/update recompute from stored per-unit values (0.12345 -> 0.1235).
- To pin HEAD while others edit modules: `git archive HEAD modules database alembic tests utils settings.py main.py seed.py alembic.ini version.json` into scratch, run there.

## Release topic files
- [release_installer.md](release_installer.md) — Inno .iss (BOM+CRLF), guard hook, ISCC rehearsal, laptop layout, R2m old-install migration.
- [release_workflows.md](release_workflows.md) — signer isolation, manifest contract, publish_update.yml button (private repo), actionlint, /release-check.
- [single_language_storage.md](single_language_storage.md) — msg codes / T3 enum codes helpers, contract regen, hold-notes rule.

## Phase-1 planning modules (2026-10-05)
- `customs_tariff.service.estimate_multi_item_customs_duty_service` raises 422 for ANY line without a tariff and adds
  deemed freight 2% / insurance 2.5% unless `has_*_document=True` + actual > 0: pre-check tariffs with
  `customs_tariff.repository.get_active_tariff_on_date(strict=True)`; pass deemed rates 0 to keep entered freight only.
- `CurrencyService._get_rate_to_egp` silently returns hard-coded fallback rates (rate_id None) when no rate row exists;
  `_RATE_CACHE` leaks across tests (clear it). Reconciled invoice rows use keys po_item_id / description /
  final_quantity / final_unit_price / total_amount (po_item_id may be a fake index).
- `ShippingEvaluationSession` has NO po/project/import_file relationships (old getattr code always returned None).
- CBM/SS/CC tables have no created_by/updated_by columns (needs a migration, alembic owned elsewhere).
