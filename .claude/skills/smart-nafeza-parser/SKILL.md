---
name: smart-nafeza-parser
description: Extract, parse, and structure raw text blocks from the Egyptian Nafeza customs portal (MD-008 Tariff Schedule, HS Codes, Duty/Tax Rates, Prior Regulatory Approvals, and Preferential Trade Agreements).
---

# 🧠 Smart Nafeza Parser Engine Skill (MD-008)

Use this skill when parsing, extracting, and standardizing raw text blocks from the Egyptian Customs Single Window portal (**Nafeza / نافذة**), Egyptian Customs Tariff books, or customs clearance sheets.

---

## 🎯 Skill Overview & Purpose

The **Smart Nafeza Parser** eliminates manual transcription errors by taking an unformatted text block copied directly from Nafeza and automatically extracting:
1. **HS Code (رقم البند الجمركي):** 8-10 digit standard HS Code (e.g. `8415820010` or `3925900090`).
2. **Commodity Description (نص / وصف البند):** Official Arabic commodity description.
3. **Customs Duty Rates & Taxes (الضرائب والرسوم الجمركية):**
   - Import Duty (ضريبة الوارد - النظام الأساسي) %
   - VAT Rate (ضريبة القيمة المضافة) %
   - Schedule Tax (ضريبة الجدول) %
   - Development Fee (رسم التنمية) %
   - Import Fee (رسم الوارد) %
4. **Prior Regulatory Approvals & Import Restrictions (الاشتراطات والمستندات الرقابية):**
   - Mandatory inspection bodies (GOEIC, EEAA, EDA, NFSA, NTRA).
   - Presidential / Ministerial Decrees (e.g., `ق4518` Decree 43 White List, `ق9994` Free Zone Quotas).
5. **Preferential Trade Agreements (الاتفاقيات التفضيلية والتخفيضات الجمركية):**
   - Publications codes (`ر6663`, `ر6668`, `ر6706`, `ر6631`, `ر6607`, `ر6722`, `ر6704`).
   - Partner regions (EU Partnership, EFTA, UK, Turkey, Mercosur, Serbia, GAFTA, Agadir).
   - Preferential duty rates and reduction percentages (e.g., 100% exemption, 10% discount, fixed preferential rate).

---

## 🏗️ Canonical Architecture

```text
Raw Text Input (Nafeza Block)
        │
        ▼
┌────────────────────────────────────────────────────────┐
│  Smart Regex & NLP Canonical Tokenizer (Python / Dart) │
├────────────────────────────────────────────────────────┤
│ 1. HS Code & Description Extraction                    │
│ 2. Multi-Tax Rate Parser (% & Base)                    │
│ 3. Publication Notices & Agreements Matcher (ر/ق)      │
│ 4. Regulatory Body & Compliance Detector               │
└───────────────────────┬────────────────────────────────┘
                        │
                        ▼
┌────────────────────────────────────────────────────────┐
│   Structured JSON Payload & Dual-Layer Validation      │
├────────────────────────────────────────────────────────┤
│ • customs_tariffs Table (Master Record)                │
│ • preferential_agreements Table (Linked Agreements)    │
│ • import_requirements Table (BP-011 Linkage)           │
└────────────────────────────────────────────────────────┘
```

---

## 📝 Standard Nafeza Text Format Specification

```text
رقم البند :
8415820010
نص البند :
آلات وأجهزة تكييف أخر متضمنة وحدة تبريد ، وحدات كاملة .
الضرائب :
ضريبة الوارد (النظام الاساسي) :
60.000 %
ضريبة الجدول :
8.000 %
ضريبة قيمه مضافه :
14.000 %
المستندات والأعمال :
ر6722 - اتفاقية صربيا تخفيض 10%
ق4518 - لايصرح باستيراد صنف الا بموافقة مختومة بخاتم شعارجمهوريةمن هـ .ع.ص.وطبقا لملحق8 وتعديلاته
ر6668 - تخفض ض .ج ورسوم بنسبة100%علىسلع صناعيةواردةفى ظل اتفاقية الشراكةالمصرية والمملكة المتحدة
ق9994 - لايفرج عن صنف بضاعة مرشدةللمنطقة الحرة الابحصص لكل مستورد يحددهاجهاز تنفيذى للمنطقةالحرة
ر6704 - فى ظل اتفاق التجارة الحرة بين مصر وتجمع الميركسور تحصل ضريبة جمركية بنسبة 3%
ر6631 - يعفى من الضريبة الجمركية والرسوم ذات الاثر المماثل الأصناف الواردة من دول الافتا بنسبة100%
ر6607 - تخفض الرسوم الجمركية فى ظل اتفاقيةتركيا بنسبة100%
ر6663 - تخفض ضريبةجمركيةورسوم ذات أثر مماثل بنسبة 100% علىسلع صناعيةواردةفى ظل شراكةأوربيةملحق2
```

---

## 🧩 Parsing Rules & Canonical Regex Patterns

### 1. HS Code & Description
- **HS Code:** `r'(?:رقم\s*البند\s*:\s*|HS\s*Code\s*:\s*)(\d{4,10})'`
- **Description:** `r'نص\s*البند\s*:\s*(.*?)(?=\n\s*الضرائب|\n\s*المستندات|$)'`

### 2. Taxes and Duties
- **Import Duty (ضريبة الوارد):** `r'ضريبة\s*الوارد\s*(?:\([^)]+\))?\s*:\s*([\d\.]+)\s*%'`
- **VAT (ضريبة القيمة المضافة):** `r'ضريبة\s*قيمه\s*مضافه\s*:\s*([\d\.]+)\s*%|ضريبة\s*القيمة\s*المضافة\s*:\s*([\d\.]+)\s*%'`
- **Schedule Tax (ضريبة الجدول):** `r'ضريبة\s*الجدول\s*:\s*([\d\.]+)\s*%'`
- **Development Fee (رسم التنمية):** `r'رسم\s*التنمية\s*:\s*([\d\.]+)\s*%'`
- **Import Fee (رسم الوارد):** `r'رسم\s*الوارد\s*:\s*([\d\.]+)\s*%'`

### 3. Trade Agreement Publication Notices (`رXXXX`)
| كود المنشور | الاتفاقية التفضيلية | نسبة التخفيض / الفئة الجمركية |
| :--- | :--- | :--- |
| `ر6663` | اتفاقية الشراكة المصرية الأوروبية (EU Partnership) | إعفاء كامل 100% (ضريبة الوارد 0%) |
| `ر6668` | اتفاقية الشراكة المصرية والمملكة المتحدة (UK Partnership) | إعفاء كامل 100% |
| `ر6631` | اتفاقية دول الإفتا (EFTA) | إعفاء كامل 100% |
| `ر6607` | اتفاقية التجارة الحرة مع تركيا (Turkey FTA) | إعفاء كامل 100% |
| `ر6706` / `ر6704` | اتفاقية التجارة الحرة مع الميركسور (Mercosur) | فئة تفضيلية (مثلاً 3%) |
| `ر6722` | اتفاقية التجارة الحرة مع صربيا (Serbia FTA) | تخفيض 10% |
| `ر6700` | اتفاقية تيسير وتنمية التبادل التجاري العربي (GAFTA) | إعفاء كامل 100% |

### 4. Regulatory & Inspection Directives (`قXXXX`)
- `ق4518` / `ق4547`: خاضع للقرار 43 لسنة 2016 (تسجيل المصانع المؤهلة وفحص GOEIC).
- `ق9994`: بضاعة مرشدة للمنطقة الحرة بحصص استيرادية معتمدة.
- `EEAA / شؤون البيئة`: موافقة بيئية وفحص أجهزة التبريد/الغازات (R410A, R134a, R32).

---

## ⚡ Integration Points in ImportFlow ERP
1. **Master Data Tariff Schedule (`MD-008`):** Immediate 1-click creation of HS Codes with all preferential agreements.
2. **Pre-Shipment Import Requirements (`BP-011`):** Auto-populates 5 pillars (Decree 43, COO, Inspection, Permits, Special Certs) upon HS Code selection.
3. **Egyptian Customs Calculator (`customs-landed-cost-engine`):** Real-time duty calculation based on origin country using the parsed agreement tariff rates.
