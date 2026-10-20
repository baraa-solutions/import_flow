"""
Unit tests for Broker Mapping Memory & Semantic Matching (M1-2 & M1-4).
Verifies:
1. High-accuracy Arabic normalization (digits, tashkeel, tatweel, hamzas, etc.)
2. Confidence score classification (high >=85%, medium 60-84%, uncoded <60%)
3. Broker Mapping Memory persistence, retrieval, and quotation extraction integration.
"""

import pytest
from modules.expense_catalog.broker_mapping_service import (
    BrokerMappingMemoryService,
    normalize_arabic_for_matching,
)
from modules.smart_document_upload.extractors.customs_broker_quotation import CustomsBrokerQuotationExtractor


@pytest.fixture(autouse=True)
def clean_broker_memory():
    """Ensures clean memory before and after each test."""
    BrokerMappingMemoryService.clear_memory()
    yield
    BrokerMappingMemoryService.clear_memory()


def test_arabic_normalization_accuracy():
    """Tests normalizer handling of eastern numbers, tashkeel, tatweel, and letter variations."""
    # Eastern Arabic-Indic numerals to Western
    assert normalize_arabic_for_matching("حاوية ٢٠ قدم") == "حاويه 20 قدم"
    assert normalize_arabic_for_matching("٤٠ HQ") == "40 hq"
    assert normalize_arabic_for_matching("١,٥٠٠ ج.م") == "1 500 ج م"

    # Tashkeel / Harakat removal
    assert normalize_arabic_for_matching("أَتْعَابُ التَّخْلِيصِ") == "اتعاب التخليص"
    assert normalize_arabic_for_matching("تَأْمِينٌ") == "تامين"

    # Tatweel / Kashida removal
    assert normalize_arabic_for_matching("تـــخــلــيــص") == "تخليص"

    # Alef & Hamza variants
    assert normalize_arabic_for_matching("إجراءات وموافقات") == "اجراءات وموافقات"
    assert normalize_arabic_for_matching("آلات ومعدات") == "الات ومعدات"
    assert normalize_arabic_for_matching("مسؤولية") == "مسووليه"

    # Taa Marbuta and Yaa / Alif Maqsura / Hamza on Nabira
    assert normalize_arabic_for_matching("رسوم جمركية") == "رسوم جمركيه"
    assert normalize_arabic_for_matching("مستودع نهائى") == normalize_arabic_for_matching("مستودع نهائي")


def test_semantic_matching_confidence_levels():
    """Verifies confidence classification into high (>=85%), medium (60-84%), and uncoded (<60%)."""
    extractor = CustomsBrokerQuotationExtractor()

    # 1. High confidence match (exact or very close)
    match_high = extractor._match_catalog_item("اتعاب تخليص ( فاتوره) LCL", category_hint="Clearance Fees")
    assert match_high is not None
    assert match_high["match_confidence"] == "high"
    assert match_high["confidence_score"] >= 0.85
    assert match_high["is_uncoded"] is False
    assert match_high["status"] == "coded"
    assert match_high["code"] == "CLR-LCL-INV"

    # 2. Medium confidence match (token overlap or partial match)
    match_med = extractor._match_catalog_item("رسوم توكيل خط ملاحي", category_hint="Procedures & Approvals")
    assert match_med is not None
    assert match_med["match_confidence"] in ("high", "medium")
    assert match_med["confidence_score"] >= 0.60
    assert match_med["is_uncoded"] is False

    # 3. Uncoded item (completely unknown colloquial term)
    match_uncoded = extractor._match_catalog_item("خدمات ضيافة وبوفيه كبار الزوار بالميناء")
    assert match_uncoded is not None
    assert match_uncoded["match_confidence"] == "uncoded"
    assert match_uncoded["confidence_score"] < 0.60
    assert match_uncoded["is_uncoded"] is True
    assert match_uncoded["status"] == "needs_coding"
    assert match_uncoded["code"] is None


def test_broker_mapping_memory_learning_and_recall():
    """Tests that custom broker terminology is learned and retrieved with 100% confidence."""
    broker_name = "شركة النور للخدمات الجمركية"
    colloquial_term = "رسوم كشف وكلارك شريف"
    target_code = "CLR-FCL40-CONT"

    # 1. Before learning: item is uncoded or low confidence
    extractor = CustomsBrokerQuotationExtractor()
    initial_match = extractor._match_catalog_item(colloquial_term, broker_name=broker_name)
    assert initial_match["is_uncoded"] is True or initial_match.get("source") != "broker_memory"

    # 2. Learn / Remember the mapping for this broker
    saved = BrokerMappingMemoryService.remember_mapping(
        broker_name=broker_name,
        raw_item_name=colloquial_term,
        catalog_code=target_code,
    )
    assert saved["code"] == target_code
    assert saved["broker_name"] == broker_name
    assert saved["confidence_score"] == 1.0

    # 3. After learning: extractor immediately recognizes it with high confidence (1.0)
    learned_match = extractor._match_catalog_item(colloquial_term, broker_name=broker_name)
    assert learned_match is not None
    assert learned_match["code"] == target_code
    assert learned_match["confidence_score"] == 1.0
    assert learned_match["match_confidence"] == "high"
    assert learned_match["source"] == "broker_memory"
    assert learned_match["is_uncoded"] is False
    assert learned_match["status"] == "coded"


def test_broker_quotation_extractor_end_to_end_with_memory():
    """Verifies that quotation extraction uses Broker Mapping Memory on end-to-end documents."""
    broker = "ACC"
    custom_item_name = "إكرامية خاصة لمهندس السيل"
    mapped_code = "PROC-CUSTOMS-SEAL"

    # Pre-train broker mapping memory
    BrokerMappingMemoryService.remember_mapping(
        broker_name=broker,
        raw_item_name=custom_item_name,
        catalog_code=mapped_code,
    )

    quote_text = f"""
    شركة اسكندرية للأعمال الجمركية (ACC)
    عرض أسعار ومقايسة تخليص جمركي
    التاريخ: 2026/04/01
    LCL
    EGP 1,250.00 اتعاب تخليص ( فاتوره)
    EGP 500.00 {custom_item_name}
    """

    extractor = CustomsBrokerQuotationExtractor()
    result = extractor.extract(quote_text, {})

    catalog = result.get("expenses_catalog", [])
    custom_extracted = next((itm for itm in catalog if custom_item_name in itm["item_name"]), None)

    assert custom_extracted is not None
    assert custom_extracted["code"] == mapped_code
    assert custom_extracted["confidence_score"] == 1.0
    assert custom_extracted["match_confidence"] == "high"
    assert custom_extracted["is_uncoded"] is False


def test_broker_isolation_in_memory():
    """Verifies that mappings learned for Broker A do not pollute Broker B."""
    BrokerMappingMemoryService.remember_mapping(
        broker_name="مكتب السلام",
        raw_item_name="مصاريف خاصة جدا",
        catalog_code="PROC-ACID-REG",
    )

    extractor = CustomsBrokerQuotationExtractor()
    # Broker A has the mapping
    match_a = extractor._match_catalog_item("مصاريف خاصة جدا", broker_name="مكتب السلام")
    assert match_a["code"] == "PROC-ACID-REG"
    assert match_a["confidence_score"] == 1.0

    # Broker B does NOT have the mapping
    match_b = extractor._match_catalog_item("مصاريف خاصة جدا", broker_name="شركة الأهرام")
    assert match_b.get("code") != "PROC-ACID-REG" or match_b.get("source") != "broker_memory"
