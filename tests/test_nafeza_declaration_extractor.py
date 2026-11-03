"""
Unit Tests for Nafeza Declaration & Unified Fees Extractor
Validates extraction against official Egyptian Customs Nafeza documents:
- Form A: "نموذج مراجعة بيانات شهادة جمركية" (Customs Declaration Data Review Form)
- Form B: "تفاصيل استمارة الرسوم الموحدة" (Unified Fees Form Details)
- Combined declaration documents matching Shipment IMP-4:
  Assessed CIF base: 2,902,035.00 EGP
  Exchange rate: 56.1986
  Freight: 7,750.00 USD
  Insurance: 1,591.00 EGP
  Discharge / Handling: 8,800.00 EGP
  Total paid in Nafeza: 611,546.07 EGP
"""

import pytest
from modules.smart_document_upload.extractors.nafeza_declaration_extractor import (
    NafezaDeclarationExtractor,
    _normalize_arabic_numbers,
)
from modules.smart_document_upload.service import _EXTRACTOR_MAP


@pytest.fixture
def extractor() -> NafezaDeclarationExtractor:
    return NafezaDeclarationExtractor()


# ─── Sample Realistic Texts for IMP-4 ──────────────────────────────────────────

IMP_4_REVIEW_FORM_TEXT = """
جمهورية مصر العربية - مصلحة الجمارك
النافذة الواحدة القومية للتجارة الخارجية (نافذة)
نموذج مراجعة بيانات شهادة جمركية

بيانات الإقرار والشهادة:
رقم الشهادة الجمركية: 4620261025004
تاريخ الشهادة: 2026-10-25
المركز اللوجستي: المركز اللوجستي بميناء الدخيلة - الإسكندرية
رقم التسجيل المسبق للشحنات (ACID): 2026102500123456789
اسم المستورد: شركة سرور للاستيراد والتصدير
الرقم الضريبي: 100-234-567

البيانات المالية والقيمة الجمركية:
سعر التحويل الجمركي: 56.1986
نوع التعاقد: EXFACTORY
العملة: USD
قيمة الفاتورة: 43704.02
قيمة النولون بالدولار: 7750.00
قيمة التأمين بالجنيه: 1591.00
مصاريف التفريغ بالجنيه: 8800.00
القيمة المقر عنها (وعاء القيمة الجمركية): 2902035.00 ج.م

بيانات البنود الجمركية:
كود البند الجمركي: 8418.10.00
وصف الصنف: وحدات تبريد وثلاجات عرض تجارية
الكمية: 500 وحدة
الوزن الإجمالي: 10510.00 كجم
نسبة ضريبة الوارد: 5%
"""

IMP_4_UNIFIED_FEES_TEXT = """
النافذة الواحدة القومية للتجارة الخارجية (نافذة)
تفاصيل استمارة الرسوم الموحدة

بيانات السداد:
رقم السداد الإلكتروني: 10023456789
الرقم الضريبي: 100-234-567
اسم المستورد: شركة سرور للاستيراد والتصدير
تاريخ الطباعة: 2026-10-25

جدول تفاصيل الرسوم والضرائب المسددة:
كود الرسم | البيان | المبلغ (ج.م)
[1] ضريبة الوارد: 145,101.75
[32] ضريبة القيمة المضافة: 426,599.15
[37] أ.ت.ص: 29,020.35
[788] فحص بالأشعة: 380.00
[3] مصاريف إدارية: 5,000.00
[77] مهن حرة: 50.00
[232] تحت الحساب: 100.00
[250] طباعة: 55.00
[798] نموذج 19: 35.00
[60] دمغة مميكن: 4.50
[74] خدمات مميكنة: 20.00
[107] تنمية محررات: 2.00
[390] خدمات جمركية: 1,081.00
[392] خدمات معلوماتية: 3,457.00
[394] ضريبة قيمة مضافة على خدمات نافذة: 635.32
[397] صندوق تكريم الشهداء: 5.00

إجمالي المبلغ المسدد بنافذة: 611,546.07 ج.م
"""

IMP_4_COMBINED_TEXT = f"""
{IMP_4_REVIEW_FORM_TEXT}

==================================================

{IMP_4_UNIFIED_FEES_TEXT}
"""


# ─── Tests for Form A: نموذج مراجعة بيانات شهادة جمركية ───────────────────────

def test_extract_review_form_imp4(extractor: NafezaDeclarationExtractor):
    result = extractor.extract(IMP_4_REVIEW_FORM_TEXT)

    assert result["document_type"] == "nafeza_declaration_review"
    assert result["declaration_no"] == "4620261025004"
    assert result["declaration_date"] == "2026-10-25"
    assert "الدخيلة" in result["customs_office"]
    assert result["acid_number"] == "2026102500123456789"
    assert "سرور" in result["importer_name"]
    assert result["importer_tax_id"] == "100234567"

    # Core Form A required fields
    assert result["exchange_rate"] == 56.1986
    assert result["incoterm"] == "EXFACTORY"
    assert result["assessed_cif_egp"] == 2902035.00
    assert result["currency"] == "USD"
    assert result["invoice_value"] == 43704.02
    assert result["freight_usd"] == 7750.00
    assert result["insurance_egp"] == 1591.00
    assert result["discharge_egp"] == 8800.00

    # Commodity item details
    assert result["hs_code"] == "8418.10.00"
    assert result["quantity"] == 500.0
    assert result["weight"] == 10510.0
    assert result["duty_rate"] == 5.0

    # Line items array
    assert len(result["items"]) == 1
    assert result["items"][0]["hs_code"] == "8418.10.00"
    assert result["items"][0]["quantity"] == 500.0
    assert result["items"][0]["weight"] == 10510.0
    assert result["items"][0]["duty_rate"] == 5.0
    assert result["items"][0]["cif_value_egp"] == 2902035.00

    assert result["confidence_score"] >= 0.8


# ─── Tests for Form B: تفاصيل استمارة الرسوم الموحدة ──────────────────────────

def test_extract_unified_fees_imp4(extractor: NafezaDeclarationExtractor):
    result = extractor.extract(IMP_4_UNIFIED_FEES_TEXT)

    assert result["document_type"] == "nafeza_unified_fees"
    assert result["e_payment_no"] == "10023456789"
    assert result["importer_tax_id"] == "100234567"
    assert "سرور" in result["importer_name"]
    assert result["print_date"] == "2026-10-25"

    # Verification of all itemized Nafeza codes
    assert result["code_1_import_duty"] == 145101.75
    assert result["duty_amount"] == 145101.75

    assert result["code_32_vat"] == 426599.15
    assert result["vat_amount"] == 426599.15

    assert result["code_37_profit_tax"] == 29020.35
    assert result["profit_tax"] == 29020.35

    assert result["code_788_xray"] == 380.00
    assert result["xray_fee"] == 380.00

    assert result["code_3_admin"] == 5000.00
    assert result["admin_fee"] == 5000.00

    assert result["code_77_professions"] == 50.00
    assert result["professions_tax"] == 50.00

    assert result["code_232_under_account"] == 100.00
    assert result["under_account"] == 100.00

    assert result["code_250_printing"] == 55.00
    assert result["printing_fee"] == 55.00

    assert result["code_798_form_19"] == 35.00
    assert result["form_19_fee"] == 35.00

    assert result["code_60_stamp"] == 4.50
    assert result["mechanized_stamp"] == 4.50

    assert result["code_74_services"] == 20.00
    assert result["mechanized_services"] == 20.00

    assert result["code_107_deed_dev"] == 2.00
    assert result["deed_development"] == 2.00

    # Nafeza platform specific codes [390, 392, 394, 397]
    assert result["code_390_nafeza_customs"] == 1081.00
    assert result["nafeza_customs_service"] == 1081.00

    assert result["code_392_nafeza_info"] == 3457.00
    assert result["nafeza_info_service"] == 3457.00

    assert result["code_394_nafeza_vat"] == 635.32
    assert result["nafeza_vat"] == 635.32

    assert result["code_397_martyrs_fund"] == 5.00
    assert result["martyrs_fund"] == 5.00

    # Total Nafeza platform fees: 1081 + 3457 + 635.32 + 5 = 5,178.32
    assert result["nafeza_fees_total"] == 5178.32

    # Grand total paid in Nafeza
    assert result["total_paid_nafeza"] == 611546.07
    assert result["total_taxes"] == 611546.07

    # Breakdown dictionary coverage
    breakdown = result["financial_codes_breakdown"]
    assert len(breakdown) == 16
    assert breakdown["1"]["name_ar"] == "ضريبة الوارد"
    assert breakdown["1"]["amount"] == 145101.75
    assert breakdown["32"]["name_ar"] == "ضريبة القيمة المضافة"
    assert breakdown["32"]["amount"] == 426599.15
    assert breakdown["37"]["name_ar"] == "أ.ت.ص"
    assert breakdown["37"]["amount"] == 29020.35

    assert result["confidence_score"] >= 0.8


# ─── Tests for Combined Document (Both Forms) ─────────────────────────────────

def test_extract_combined_declaration_imp4(extractor: NafezaDeclarationExtractor):
    result = extractor.extract(IMP_4_COMBINED_TEXT)

    assert result["document_type"] == "nafeza_combined"

    # Form A fields
    assert result["exchange_rate"] == 56.1986
    assert result["incoterm"] == "EXFACTORY"
    assert result["assessed_cif_egp"] == 2902035.00
    assert result["freight_usd"] == 7750.00
    assert result["insurance_egp"] == 1591.00
    assert result["discharge_egp"] == 8800.00
    assert result["hs_code"] == "8418.10.00"
    assert result["weight"] == 10510.0
    assert result["duty_rate"] == 5.0

    # Form B fields
    assert result["e_payment_no"] == "10023456789"
    assert result["duty_amount"] == 145101.75
    assert result["vat_amount"] == 426599.15
    assert result["profit_tax"] == 29020.35
    assert result["xray_fee"] == 380.00
    assert result["admin_fee"] == 5000.00
    assert result["nafeza_fees_total"] == 5178.32
    assert result["total_paid_nafeza"] == 611546.07

    # High confidence score for combined document
    assert result["confidence_score"] == 1.0


# ─── Tests for Table Format Variations ────────────────────────────────────────

def test_extract_table_without_brackets(extractor: NafezaDeclarationExtractor):
    table_text = """
    منظومة نافذة - بيان سداد رسوم موحدة
    رقم السداد الالكتروني: 99887766
    الرقم الضريبي: 200300400
    اسم المستورد: الأهرام للاستيراد والتصدير
    تاريخ الطباعة: 2026-10-30

    كود | البيان | القيمة
    1 | ضريبة الوارد | 145101.75
    32 | ضريبة القيمة المضافة | 426599.15
    37 | أ.ت.ص | 29020.35
    788 | فحص بالأشعة | 380.00
    3 | مصاريف إدارية | 5000.00
    77 | مهن حرة | 50.00
    232 | تحت الحساب | 100.00
    250 | طباعة | 55.00
    798 | نموذج 19 | 35.00
    60 | دمغة مميكن | 4.50
    74 | خدمات مميكنة | 20.00
    107 | تنمية محررات | 2.00
    390 | خدمات جمركية | 1081.00
    392 | خدمات معلوماتية | 3457.00
    394 | ضريبة قيمة مضافة على خدمات نافذة | 635.32
    397 | صندوق تكريم الشهداء | 5.00

    المبلغ الإجمالي المسدد: 611546.07
    """
    res = extractor.extract(table_text)
    assert res["e_payment_no"] == "99887766"
    assert res["importer_tax_id"] == "200300400"
    assert res["duty_amount"] == 145101.75
    assert res["vat_amount"] == 426599.15
    assert res["profit_tax"] == 29020.35
    assert res["xray_fee"] == 380.00
    assert res["admin_fee"] == 5000.00
    assert res["nafeza_fees_total"] == 5178.32
    assert res["total_paid_nafeza"] == 611546.07


def test_extract_eastern_arabic_numerals(extractor: NafezaDeclarationExtractor):
    arabic_num_text = """
    نموذج مراجعة بيانات شهادة جمركية
    سعر التحويل الجمركي: ٥٦.١٩٨٦
    نوع التعاقد: EXFACTORY
    القيمة المقر عنها: ٢٩٠٢٠٣٥.٠٠
    قيمة النولون بالدولار: ٧٧٥٠
    قيمة التأمين بالجنيه: ١٥٩١
    مصاريف التفريغ بالجنيه: ٨٨٠٠
    كود البند الجمركي: 8418.10.00
    الكمية: ٥٠٠
    الوزن الإجمالي: ١٠٥١٠
    نسبة ضريبة الوارد: ٥%
    """
    res = extractor.extract(arabic_num_text)
    assert res["exchange_rate"] == 56.1986
    assert res["assessed_cif_egp"] == 2902035.00
    assert res["freight_usd"] == 7750.00
    assert res["insurance_egp"] == 1591.00
    assert res["discharge_egp"] == 8800.00
    assert res["quantity"] == 500.0
    assert res["weight"] == 10510.0
    assert res["duty_rate"] == 5.0


def test_fallback_sum_when_total_line_missing(extractor: NafezaDeclarationExtractor):
    text_without_total = """
    استمارة الرسوم الموحدة
    رقم السداد الإلكتروني: 123456
    الرقم الضريبي: 123-456-789
    تاريخ الطباعة: 2026-10-25
    [1] ضريبة الوارد: 145101.75
    [32] ضريبة القيمة المضافة: 426599.15
    [37] أ.ت.ص: 29020.35
    [788] فحص بالأشعة: 380.00
    [3] مصاريف إدارية: 5000.00
    [77] مهن حرة: 50.00
    [232] تحت الحساب: 100.00
    [250] طباعة: 55.00
    [798] نموذج 19: 35.00
    [60] دمغة مميكن: 4.50
    [74] خدمات مميكنة: 20.00
    [107] تنمية محررات: 2.00
    [390] خدمات جمركية: 1081.00
    [392] خدمات معلوماتية: 3457.00
    [394] ضريبة قيمة مضافة على خدمات نافذة: 635.32
    [397] صندوق تكريم الشهداء: 5.00
    """
    res = extractor.extract(text_without_total)
    # The total should be automatically computed as the sum of all codes
    assert res["total_paid_nafeza"] == 611546.07


def test_extractor_registered_in_service_map():
    assert "nafeza-declaration" in _EXTRACTOR_MAP
    assert "nafeza-declaration-review" in _EXTRACTOR_MAP
    assert "nafeza-unified-fees" in _EXTRACTOR_MAP
    assert "nafeza" in _EXTRACTOR_MAP
    assert isinstance(_EXTRACTOR_MAP["nafeza-declaration"], NafezaDeclarationExtractor)


def test_incoterms_and_currencies_variations(extractor: NafezaDeclarationExtractor):
    sample_fob = """
    نموذج مراجعة بيانات شهادة جمركية
    سعر التحويل: 48.50
    نوع التعاقد: FOB
    العملة: يورو
    القيمة المقر عنها: 1500000.00
    كود البند الجمركي: 8504.40.10
    """
    res = extractor.extract(sample_fob)
    assert res["incoterm"] == "FOB"
    assert res["currency"] == "EUR"
    assert res["exchange_rate"] == 48.50
    assert res["assessed_cif_egp"] == 1500000.00
    assert res["hs_code"] == "8504.40.10"


def test_missing_required_confidence(extractor: NafezaDeclarationExtractor):
    empty_res = extractor.extract("")
    assert empty_res["confidence_score"] == 0.0
    assert empty_res["exchange_rate"] is None
    assert empty_res["total_paid_nafeza"] is None


def test_european_numeric_formatting(extractor: NafezaDeclarationExtractor):
    euro_num_text = """
    تفاصيل استمارة الرسوم الموحدة
    رقم السداد الإلكتروني: EP-998811
    الرقم الضريبي: 111-222-333
    [1] ضريبة الوارد: 145.101,75
    [32] ضريبة القيمة المضافة: 426.599,15
    [37] أ.ت.ص: 29.020,35
    إجمالي المبلغ المسدد بنافذة: 600.721,25
    """
    res = extractor.extract(euro_num_text)
    assert res["duty_amount"] == 145101.75
    assert res["vat_amount"] == 426599.15
    assert res["profit_tax"] == 29020.35
    assert res["total_paid_nafeza"] == 600721.25

