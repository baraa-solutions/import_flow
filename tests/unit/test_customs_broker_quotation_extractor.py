import re
import pytest
from modules.smart_document_upload.extractors.customs_broker_quotation import CustomsBrokerQuotationExtractor

def test_customs_broker_quotation_extractor_accuracy():
    extractor = CustomsBrokerQuotationExtractor()
    quote_text = '\n    شركة الأهرام للخدمات الجمركية\n    عرض أسعار ومقايسة تخليص جمركي\n    ميناء الوصول: ميناء الإسكندرية البحري\n    الحاوية: 40HQ\n    \n    أتعاب التخليص الجمركي: 3500 ج.م\n    نولون النقل الداخلي: 19500 ج.م\n    مصاريف الفحص والمعاينة واللجان: 2800 ج.م\n    مصاريف وعوائد الميناء والتفريغ: 8000 ج.م\n    رسوم كشف وكلارك وتعتيق: 1200 ج.م\n    \n    إجمالي المقايسة التقديرية: 35000 ج.م\n    '
    
    result = extractor.extract(quote_text, {})
    
    assert 'الأهرام' in result['broker_name']
    assert 'Alexandria' in result['port_name']
    assert result['clearance_fee'] == 3500.0
    assert result['inland_transport_fee'] == 19500.0
    assert result['inspection_fee'] == 2800.0
    assert result['port_expenses'] == 8000.0
    assert result['total_estimated_clearance_cost'] == 35000.0
    
    catalog = result.get('expenses_catalog', [])
    assert len(catalog) >= 5
    names = [item['expense_name'] for item in catalog]
    assert any('كشف وكلارك وتعتيق' in n for n in names)

def test_customs_broker_quotation_no_hardcoded_overwrite():
    extractor = CustomsBrokerQuotationExtractor()
    quote_text = '\n    مكتب النور للتخليص الجمركي\n    مقايسة حاوية 20ft\n    أتعاب التخليص: 4200 جنيه\n    النقل: 11000 جنيه\n    إكراميات وتعتيق: 850 جنيه\n    رسوم موازين: 350 جنيه\n    الإجمالي: 16400 جنيه\n    '
    
    result = extractor.extract(quote_text, {})
    
    assert 'النور' in result['broker_name']
    assert result['clearance_fee'] == 4200.0
    assert result['inland_transport_fee'] == 11000.0
    assert result['total_estimated_clearance_cost'] == 16400.0
    
    catalog = result.get('expenses_catalog', [])
    names = [c['expense_name'] for c in catalog]
    assert any('إكراميات وتعتيق' in n for n in names)
    assert any('رسوم موازين' in n for n in names)

def test_customs_broker_quotation_english_and_currency_symbols():
    extractor = CustomsBrokerQuotationExtractor()
    quote_text = '\n    Alexandria Customs Clearance Agency\n    Quotation for Port: Sokhna Port\n    Clearance Fee: EGP 5000\n    Inland Transport: EGP 14500\n    Port Handling: EGP 6200\n    Inspection: EGP 1800\n    Storage & Demurrage Coverage: EGP 3000\n    Total Cost: EGP 30500\n    '
    
    result = extractor.extract(quote_text, {})
    
    assert result['clearance_fee'] == 5000.0
    assert result['inland_transport_fee'] == 14500.0
    assert result['port_expenses'] == 6200.0
    assert result['inspection_fee'] == 1800.0
    assert result['total_estimated_clearance_cost'] == 30500.0
    
    catalog = result.get('expenses_catalog', [])
    names = [c['expense_name'] for c in catalog]
    assert any('Storage & Demurrage' in n for n in names)


def test_customs_broker_quotation_full_acc_extraction():
    extractor = CustomsBrokerQuotationExtractor()
    quote_text = """
    شركة اسكندرية للأعمال الجمركية (ACC)
    شريف سقسلي
    عرض أسعار ومقايسة تخليص جمركي
    التاريخ: 2026/04/01
    ميناء الإسكندرية والدخيلة

    LCL
    EGP 1,250.00 اتعاب تخليص ( فاتوره)
    EGP 4,750.00 مصاريف تخليص واحد طن
    EGP 1,000.00 مصاريف تخليص كل طن زيادة

    20FT
    EGP 2,500.00 اتعاب تخليص ( فاتوره)
    EGP 7,500.00 مصاريف تخليص ١ حاوية
    EGP 1,500.00 كل حاوية زيادة

    40FT
    EGP 2,500.00 اتعاب تخليص ( فاتوره)
    EGP 7,500.00 مصاريف تخليص ١ حاوية
    EGP 2,000.00 كل حاوية زيادة

    تكاليف اخري : (اجراءات تخليص)
    EGP 1,000.00 ACID تسجيل الشحنة الجمركي المبدئي
    EGP 250.00 - 250.00 بريد - دمغات
    EGP 2,500.00 - 3,500.00 عرض الواردات + اعتماد الايباك
    EGP 5,000.00 عرض امن عام القاهره
    EGP 500.00 - 1,000.00 - 1,500.00 امن عام ( اسكندرية - كفر الشيخ - البحيرة )
    EGP 500.00 وثيقة تامين
    EGP 250.00 عرض اكس راي
    EGP 1,000.00 تطبيق اتفاقيات
    EGP 350.00 الافراج تحت التحفظ
    EGP 250.00 سيل الجمرك والترصيص
    EGP 3,000.00 مطافي ومفرقعات ودمغة موازين
    EGP 3,000.00 افراج نهائي واشعاع وكيمياء
    EGP 750.00 ( 250 / 250 / 250 ) سحب اذن تسليم وتصوير ومنافستو
    EGP 300.00 توكيل
    EGP 1,500.00 تفريغ
    EGP 500.00 فحص كيمياء
    EGP 500.00 فحص اشعاع
    EGP 1,000.00 لجنة فحص خارجي
    EGP 350.00 منافستو
    EGP 250.00 تصوير مستندات
    EGP 500.00 اكراميات ولجان

    النقل من الإسكندرية للقاهرة
    EGP 6,150.00 نقل سيارة 1 طن دبابة للقاهرة
    EGP 8,200.00 نقل سيارة جامبو حتى 4 طن للقاهرة
    EGP 14,150.00 نقل سيارة فرداني حتى 7 طن للقاهرة
    EGP 14,800.00 نقل حاوية 20 قدم وزن اقل من 10 طن للقاهرة
    EGP 16,500.00 نقل حاوية 20 قدم وزن اكبر من 10 طن للقاهرة
    EGP 18,400.00 نقل حاوية 20*2 للقاهرة
    EGP 18,400.00 نقل حاوية 40 قدم للقاهرة

    بياتة الحاويات
    EGP 3,600.00 بياتة شاحنة 20*2
    EGP 3,600.00 بياتة شاحنة 40*1
    EGP 3,000.00 بياتة شاحنة 20*1

    مصاريف الميناء والتعامل
    EGP 1,000.00 كارتة ابوقير
    EGP 3,500.00 تعتيق ونقل وزن داخل الميناء ( قماش )
    """

    result = extractor.extract(quote_text, {})

    assert result['clearance_fee'] == 2500.0
    assert result['inland_transport_fee'] == 18400.0
    assert result['port_expenses'] == 7500.0
    assert result['inspection_fee'] == 2500.0

    catalog = result.get('expenses_catalog', [])
    assert len(catalog) >= 35

    names = [c['expense_name'] for c in catalog]
    # Check LCL fees
    assert any('LCL' in n and 'فاتورة' in n for n in names)
    assert any('LCL' in n and 'واحد طن' in n for n in names)
    # Check 20FT & 40FT fees
    assert any('20' in n and 'أول حاوية' in n for n in names)
    assert any('40' in n and 'أول حاوية' in n for n in names)
    # Check Procedures
    assert any('ACID' in n for n in names)
    assert any('بريد' in n for n in names)
    assert any('الواردات' in n for n in names)
    # Check Transport
    assert any('دبابة' in n for n in names)
    assert any('جامبو' in n for n in names)
    assert any('فرداني' in n for n in names)
    assert any('بياتة' in n for n in names)
    assert any('أبوقير' in n for n in names)



from modules.smart_document_upload.extractors.quotation_validation_layer import QuotationValidationLayer


def test_quotation_validation_layer_counter():
    raw_text = """
    شركة اسكندرية للأعمال الجمركية (ACC)
    LCL
    EGP 1,250.00 اتعاب تخليص ( فاتوره)
    EGP 4,750.00 مصاريف تخليص واحد طن
    EGP 1,000.00 مصاريف تخليص كل طن زيادة

    20FT
    EGP 2,500.00 اتعاب تخليص ( فاتوره)
    EGP 7,500.00 مصاريف تخليص ١ حاوية
    EGP 1,500.00 كل حاوية زيادة

    40FT
    EGP 2,500.00 اتعاب تخليص ( فاتوره)
    EGP 7,500.00 مصاريف تخليص ١ حاوية
    EGP 2,000.00 كل حاوية زيادة

    تكاليف اخري :
    EGP 250.00 - 250.00 بريد - دمغات
    EGP 500.00 - 1,000.00 - 1,500.00 امن عام ( اسكندرية - كفر الشيخ - البحيرة )
    EGP 750.00 ( 250 / 250 / 250 ) سحب اذن تسليم وتصوير ومنافستو
    EGP 1,000.00 ACID تسجيل الشحنة الجمركي المبدئي
    EGP 500.00 وثيقة تامين
    EGP 250.00 عرض اكس راي

    النقل من الإسكندرية للقاهرة:
    EGP 6,150.00 نقل سيارة 1 طن دبابة للقاهرة
    EGP 8,200.00 نقل سيارة جامبو حتى 4 طن للقاهرة
    EGP 18,400.00 نقل حاوية 40 قدم للقاهرة

    شروط وبنود خارج الجدول:
    بخلاف مصاريف كشف الحاويات المشتركة من 1000 إلى 5000 جنيه
    بخلاف كشف التجميع للحاويات من 1500 إلى 3000 جنيه
    """
    res = QuotationValidationLayer.count_expected_items(raw_text)
    expected_count = res["expected_item_count"]
    # Verify expected items count is accurate
    assert expected_count >= 20
    assert len(res["pattern_details"]) >= 15


def test_quotation_validation_layer_banner_thresholds():
    # Gap <= 5%: Safe / reliable
    report_safe = QuotationValidationLayer.validate_extraction(100, [{"name": f"item_{i}"} for i in range(97)])
    assert report_safe["banner_status"] == "safe"
    assert report_safe["requires_modal_confirmation"] is False
    assert "استخراج موثوق" in report_safe["banner_message_ar"]

    # 5% < Gap <= 20%: Warning
    report_warn = QuotationValidationLayer.validate_extraction(100, [{"name": f"item_{i}"} for i in range(85)])
    assert report_warn["banner_status"] == "warning"
    assert report_warn["requires_modal_confirmation"] is False
    assert "تنبيه" in report_warn["banner_message_ar"]

    # Gap > 20%: Critical
    report_crit = QuotationValidationLayer.validate_extraction(100, [{"name": f"item_{i}"} for i in range(70)])
    assert report_crit["banner_status"] == "critical"
    assert report_crit["requires_modal_confirmation"] is True
    assert "تحذير حرج" in report_crit["banner_message_ar"]


def test_customs_broker_quotation_multi_value_splitting():
    extractor = CustomsBrokerQuotationExtractor()
    quote_text = """
    شركة اسكندرية للأعمال الجمركية (ACC)
    تكاليف اخري : (اجراءات تخليص)
    EGP 250.00 - 250.00 بريد - دمغات
    EGP 500.00 - 1,000.00 - 1,500.00 امن عام ( اسكندرية - كفر الشيخ - البحيرة )
    EGP 750.00 ( 250 / 250 / 250 ) سحب اذن تسليم وتصوير ومنافستو
    """
    result = extractor.extract(quote_text, {})
    catalog = result["expenses_catalog"]

    split_items = [c for c in catalog if c.get("is_multi_value_split")]
    # Assert at least 8 items produced from these 3 multi-value lines (2 + 3 + 3)
    assert len(split_items) >= 8

    # Check specific split items
    names = [c["item_name"] for c in split_items]
    assert any("بريد" in n for n in names)
    assert any("دمغات" in n for n in names)
    assert any("اسكندرية" in n for n in names)
    assert any("كفر الشيخ" in n for n in names)
    assert any("البحيرة" in n for n in names)
    assert any("سحب إذن" in n for n in names)
    assert any("تصوير" in n for n in names)
    assert any("منافستو" in n for n in names)

    # Check extraction confidence is medium
    for item in split_items:
        assert item["extraction_confidence"] == "medium"
        assert item["price_type"] == "fixed"
        assert item["price"] > 0


def test_customs_broker_quotation_conditional_range_items():
    extractor = CustomsBrokerQuotationExtractor()
    quote_text = """
    شركة اسكندرية للأعمال الجمركية (ACC)
    شروط وبنود خارج الجدول:
    بخلاف مصاريف كشف الحاويات المشتركة من 1000 إلى 5000 جنيه
    بخلاف كشف التجميع للحاويات من 1500 إلى 3000 جنيه
    بخلاف رسوم المعامل وفحص العينات الكيماوية من 500 إلى 2000 جنيه
    بخلاف أتعاب فتح شهادة الترانزيت ونقل جمركي من 2000 إلى 4000 جنيه
    بخلاف رسوم توكيلات ملاحية وإيصالات رسمية من 1000 إلى 5000 جنيه
    """
    result = extractor.extract(quote_text, {})
    catalog = result["expenses_catalog"]

    range_items = [c for c in catalog if c.get("price_type") == "range"]
    assert len(range_items) >= 5

    for item in range_items:
        assert item["source_location"] == "outside_table"
        assert item["extraction_confidence"] == "needs_review"
        assert item["price_min"] is not None
        assert item["price_max"] is not None
        assert item["price_max"] >= item["price_min"]


def test_golden_acc_quotation_completeness_and_validation():
    extractor = CustomsBrokerQuotationExtractor()
    full_acc_text = """
    شركة اسكندرية للأعمال الجمركية (ACC)
    شريف سقسلي
    عرض أسعار ومقايسة تخليص جمركي
    التاريخ: 2026/04/01
    ميناء الإسكندرية والدخيلة

    LCL
    EGP 1,250.00 اتعاب تخليص ( فاتوره)
    EGP 4,750.00 مصاريف تخليص واحد طن
    EGP 1,000.00 مصاريف تخليص كل طن زيادة

    20FT
    EGP 2,500.00 اتعاب تخليص ( فاتوره)
    EGP 7,500.00 مصاريف تخليص ١ حاوية
    EGP 1,500.00 كل حاوية زيادة

    40FT
    EGP 2,500.00 اتعاب تخليص ( فاتوره)
    EGP 7,500.00 مصاريف تخليص ١ حاوية
    EGP 2,000.00 كل حاوية زيادة

    تكاليف اخري : (اجراءات تخليص)
    EGP 1,000.00 ACID تسجيل الشحنة الجمركي المبدئي
    EGP 250.00 - 250.00 بريد - دمغات
    EGP 2,500.00 - 3,500.00 عرض الواردات + اعتماد الايباك
    EGP 5,000.00 عرض امن عام القاهره
    EGP 500.00 - 1,000.00 - 1,500.00 امن عام ( اسكندرية - كفر الشيخ - البحيرة )
    EGP 500.00 وثيقة تامين
    EGP 250.00 عرض اكس راي
    EGP 1,000.00 تطبيق اتفاقيات
    EGP 350.00 الافراج تحت التحفظ
    EGP 250.00 سيل الجمرك والترصيص
    EGP 3,000.00 مطافي ومفرقعات ودمغة موازين
    EGP 3,000.00 افراج نهائي واشعاع وكيمياء
    EGP 750.00 ( 250 / 250 / 250 ) سحب اذن تسليم وتصوير ومنافستو
    EGP 300.00 توكيل
    EGP 1,500.00 تفريغ
    EGP 500.00 فحص كيمياء
    EGP 500.00 فحص اشعاع
    EGP 1,000.00 لجنة فحص خارجي
    EGP 350.00 منافستو
    EGP 250.00 تصوير مستندات
    EGP 500.00 اكراميات ولجان

    النقل من الإسكندرية للقاهرة
    EGP 6,150.00 نقل سيارة 1 طن دبابة للقاهرة
    EGP 8,200.00 نقل سيارة جامبو حتى 4 طن للقاهرة
    EGP 14,150.00 نقل سيارة فرداني حتى 7 طن للقاهرة
    EGP 14,800.00 نقل حاوية 20 قدم وزن اقل من 10 طن للقاهرة
    EGP 16,500.00 نقل حاوية 20 قدم وزن اكبر من 10 طن للقاهرة
    EGP 18,400.00 نقل حاوية 20*2 للقاهرة
    EGP 18,400.00 نقل حاوية 40 قدم للقاهرة

    بياتة الحاويات
    EGP 3,600.00 بياتة شاحنة 20*2
    EGP 3,600.00 بياتة شاحنة 40*1
    EGP 3,000.00 بياتة شاحنة 20*1

    مصاريف الميناء والتعامل
    EGP 1,000.00 كارتة ابوقير
    EGP 3,500.00 تعتيق ونقل وزن داخل الميناء ( قماش )

    شروط وبنود خارج الجدول:
    بخلاف مصاريف كشف الحاويات المشتركة من 1000 إلى 5000 جنيه
    بخلاف كشف التجميع للحاويات من 1500 إلى 3000 جنيه
    بخلاف رسوم المعامل وفحص العينات الكيماوية من 500 إلى 2000 جنيه
    بخلاف أتعاب فتح شهادة الترانزيت ونقل جمركي من 2000 إلى 4000 جنيه
    بخلاف رسوم توكيلات ملاحية وإيصالات رسمية من 1000 إلى 5000 جنيه
    """

    result = extractor.extract(full_acc_text, {})

    assert result["clearance_fee"] == 2500.0
    assert result["inland_transport_fee"] == 18400.0
    assert result["port_expenses"] == 7500.0
    assert result["inspection_fee"] == 2500.0

    catalog = result.get("expenses_catalog", [])

    # Definition of Done: ACC fixture produces 45+ correctly classified items
    assert len(catalog) >= 45, f"Expected 45+ items, but extracted {len(catalog)}"

    report = result.get("validation_report", {})
    assert report, "Validation report must be present"

    # Must NOT produce a critical red warning banner on this complete document
    assert report["banner_status"] in ("safe", "reliable", "warning")
    assert report["requires_modal_confirmation"] is False

    # Check multi-value split items count >= 6
    assert report["multi_value_items_count"] >= 6

    # Check conditional range items count >= 5
    assert report["range_items_count"] >= 5
    assert report["outside_table_items_count"] >= 5


# ─── Trello AKpuUmDn: Eastern numerals, dialect tiers, header context, twin ports, BiDi title ─────────

PORT_SAID_STYLE_QUOTE = """
السادة شركة سكاس للتشييد والبناء
بيان باسعار التخليص والنقل للرسائل الواردة لسيادتكم علي ميناء الاسكندرية والدخيلة لعام ٢٠٢٦

النقل من الاسكندرية للقاهرة
EGP ٦,١٥٠ نقل سيارة 1 طن دبابة
EGP ١٤,٨٠٠ نقل حاوية 20 قدم حتى 10 طن
EGP ١٦,٥٠٠ نقل حاوية 20 قدم اكثر من 10 طن
EGP ۱۸,۴۰۰ الحاوية ۴۰ قدم

بخلاف مصاريف كشـ
ف الجميع او استخدام العمال والكلارك من ۱۰۰۰ الي ۲۰۰۰
بخلاف اي ايصالات رسمية
"""


def test_eastern_and_persian_digits_are_normalized():
    from modules.expense_catalog.broker_mapping_service import normalize_arabic_indic_numerals

    assert normalize_arabic_indic_numerals("من ١٠٠٠ إلى ٢٠٠٠") == "من 1000 إلى 2000"
    assert normalize_arabic_indic_numerals("من ۱۰۰۰ الي ۲۰۰۰") == "من 1000 الي 2000"
    assert normalize_arabic_indic_numerals("") == ""


def test_dialect_weight_tier_and_inherited_transport_context():
    result = CustomsBrokerQuotationExtractor().extract(PORT_SAID_STYLE_QUOTE, {})
    transport = {
        c["expense_name"]: c["price"]
        for c in result["expenses_catalog"]
        if c["category"].startswith("Inland Transport")
    }
    assert transport.get("نقل حاوية 20 قدم حتى 10 طن (إسكندرية - قاهرة)") == 14800.0
    assert transport.get("نقل حاوية 20 قدم أكثر من 10 طن (إسكندرية - قاهرة)") == 16500.0
    # "الحاوية ٤٠ قدم" has no "نقل" in the row: it inherits the transport section of its header.
    assert transport.get("نقل حاوية 40 قدم (إسكندرية - قاهرة)") == 18400.0
    assert len(transport) == 4


def test_twin_ports_and_pure_arabic_title():
    result = CustomsBrokerQuotationExtractor().extract(PORT_SAID_STYLE_QUOTE, {})
    assert result["port_names"] == ["Alexandria Port", "El Dekheila Port"]
    assert result["title"].startswith("بيان باسعار التخليص والنقل")
    assert "2026" in result["title"]
    assert not re.search(r"[A-Za-z]", result["title"])


def test_fallback_title_uses_arabic_port_names():
    result = CustomsBrokerQuotationExtractor().extract("ميناء الدخيلة\nEGP 2,500 اتعاب تخليص", {})
    assert "الدخيلة" in result["title"]
    assert not re.search(r"[A-Za-z]", result["title"])


def test_notes_keep_numbers_and_ocr_wrapped_words():
    result = CustomsBrokerQuotationExtractor().extract(PORT_SAID_STYLE_QUOTE, {})
    assert "كشف الجميع" in result["notes"]
    assert "1000" in result["notes"] and "2000" in result["notes"]
    assert "ايصالات رسمية" in result["notes"]
