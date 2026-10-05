---
name: ruling-cc01-service-fee-deemed-cif
description: 2026-10-05 Phase-1 CC-01 rulings - tariff customs_service_fee_rate "1.00" fallback acceptable; deemed freight/insurance 0 in consultation recalc is a product gap, not a rule breach; air factor 167
metadata:
  type: project
---

Rulings made 2026-10-05 reviewing uncommitted Phase-1 work (base 8f776ae), customs_consultation recalculate (CC-01).

(a) Service fee rate: customs_tariffs.customs_service_fee_rate is NOT NULL (model default 1.00), so the engine's
"1.00" fallback (customs_tariff/service.py ~653) is unreachable for stored rows -> passes reviewer rule 1
("documented fallback never used when the HS code has a value"). The real weakness is upstream: create schema,
Nafeza parser and CSV import all write 1.00 when the source has no value. Follow-up only, not a blocker.

(b) Deemed freight 2% / insurance 2.5%: no rule in DOMAIN_RULES §2 or BP-010 requires them (both only say
CIF = FOB + Freight + Insurance). Passing deemed=0 is compliant. But the recalc defaults freight/insurance to 0,
so CIF = FOB on the common path and taxes are understated. Recommended: deemed path only when the user entered
nothing, show insurance_source/freight_source, and move the 2%/2.5% into system_parameters. Product decision for the CTO.

Air volumetric factor: single configurable AIR_VOLUMETRIC_KG_PER_CBM = 167 (CTO decision Q1, matches DOMAIN_RULES §7).
Courier keeps 200 kg/CBM (/5000). If any code still uses 166.67 or /6000, flag it.

**Why:** these were open questions that the rules leave ambiguous. Keeping the answers fixed keeps later reviews consistent.
**How to apply:** do not re-flag the 1.00 fallback as a hard-coded rate. Do flag code that applies deemed rates
silently without exposing the source. See [[ruling-wht-tax-rates]].
