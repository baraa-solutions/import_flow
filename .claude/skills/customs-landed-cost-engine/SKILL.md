---
name: customs-landed-cost-engine
description: Calculate Egyptian Customs Duties, Taxes, Fees, and Landed Cost breakdown for imported goods based on HS Code tariff schedule.
---

# Customs & Landed Cost Engine Skill

Use this skill when implementing calculation logic for Egyptian customs duties, taxes, fees, and landed cost.

## Critical Rule: HS Code Drives Everything

Every **HS Code** has its own specific tax rates and applicable fee types. NEVER assume a fixed rate for any tax or fee.

## Egyptian Customs Charge Items (بنود الحساب الجمركي)

Each customs calculation may include the following charge items (applicability depends on the HS Code):

```text
1. Import Duty (ضريبة الوارد)            → % of CIF, varies by HS Code
2. VAT (ضريبة القيمة المضافة)            → % of VAT Base, varies by HS Code (NOT always 14%)
3. Schedule Tax (ضريبة الجدول)            → Additional % per HS Code (if applicable)
4. Import Fee (رسم الوارد)                → Fixed or % (if applicable)
5. Customs Service Fees (رسوم خدمات)      → Multiple service charges
6. Basic Fees (رسوم أساسية)               → Fixed fees
7. Development Fee (رسم التنمية)          → % if applicable per HS Code
```

## Calculation Flow

```text
Step 1: CIF = FOB Value + Freight + Insurance
Step 2: Import Duty = CIF × HS Code Import Duty Rate %
Step 3: VAT Base = CIF + Import Duty + Freight + Other Applicable Fees
Step 4: VAT = VAT Base × HS Code VAT Rate %
Step 5: Schedule Tax = CIF × Schedule Tax Rate % (from HS Code, if applicable)
Step 6: Service Fees + Basic Fees (from fee schedule)
Step 7: Total = Sum of all applicable charge items
```

## Landed Cost Formula

```text
Landed Cost = Purchase Cost (FOB/CIF)
            + Freight (النولون)
            + Insurance (التأمين)
            + Import Duty (ضريبة الوارد)
            + VAT (ضريبة القيمة المضافة)
            + Schedule Tax (ضريبة الجدول)
            + Development Fee (رسم التنمية)
            + Customs Service Fees (رسوم الخدمات الجمركية)
            + Basic Fees (رسوم أساسية)
            + Clearance Fees (أتعاب التخليص الجمركي)
            + Local Transport (النقل الداخلي)
            + Other Import Costs (مصاريف أخرى)
```

## Key Principles
1. **HS Code is King**: All rates and applicable fees are determined by the HS Code from the Tariff Schedule (MD-008).
2. **Cost Breakdown Integrity**: System MUST preserve each cost component line item, not just store a single aggregated total.
3. **Dynamic Tax Rules & Effective-Dated Versioning**: Never hardcode rates. Fetch active rates from HS Code tariff table with effective date range (`effective_from`, `effective_to`). When updating tariff rules or preferential agreements, preserve historical versions without deletion to protect past confirmed calculation snapshots.
4. **Smart Nafeza Tariff Parser**: Extract HS Code, item description, base duty rates, VAT %, and trade agreement publication notices (e.g. `ر6722` Serbia 10%, `ر6668` UK 100%, `ر6706` Mercosur 3%, `ر6631` EFTA 100%, `ر6607/ر6617` Turkey 100%/50%, `ر6663` EU Partnership 100%) directly from raw Nafeza block text.
5. **Real-Time Color-Coded Diff Analysis**: Compare new tariff data blocks against existing DB versions, rendering color-coded badges for Added (`#27AE60` green), Removed (`#C0392B` red), and Modified (`#E67E22` orange) rules and publication notices.
6. **Origin Country & Document Verification**: Check origin country ISO code against active agreements on calculation date. Verify certificate of origin (`EUR.1` / Mercosur Certificate). Fall back to base duty rate with explicit document warnings if certificate is missing.
7. **Currency Conversion**: Apply the official customs exchange rate valid at the declaration date.
8. **Not All Items Apply**: Some HS Codes have Schedule Tax, others don't. Some have Development Fee, others don't. The system must handle optional charge items.
