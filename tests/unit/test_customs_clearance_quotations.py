"""
Unit Tests for Customs Clearance Quotations & Price Lists Engine and Extractor
"""

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main  # noqa: F401 - registers all SQLAlchemy models
from database.database import Base
from modules.customs_clearance_quotations.schemas import (
    CustomsClearanceRFQCreate,
    CustomsClearanceRFQUpdate,
    CustomsClearanceQuotationCreate,
    ClearancePriceListItemCreate,
)
from modules.customs_clearance_quotations.service import (
    create_rfq_service,
    get_rfqs_service,
    get_rfq_by_id_service,
    add_quotation_service,
    award_quotation_service,
    create_price_item_service,
    get_price_list_service,
)
from modules.smart_document_upload.extractors.customs_broker_quotation import CustomsBrokerQuotationExtractor


@pytest.fixture
def db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


def test_customs_broker_quotation_extractor_text_parsing():
    extractor = CustomsBrokerQuotationExtractor()
    sample_text = """
    السادة شركة النور للاستيراد والتصدير
    عرض أسعار وتخليص جمركي مقدم من: مكتب الأهرام للخدمات اللوجستية والتخليص الجمركي
    ميناء الوصول: ميناء الإسكندرية (Alexandria Port)
    نوع الحاوية: 40HQ
    
    1. أتعاب التخليص الجمركي: 3,500 EGP
    2. النقل الداخلي لمصنع العميل: 8,000 EGP
    3. مصاريف فحص وعرض هيئة الرقابة: 2,200 EGP
    4. رسوم موانئ وخدمات ساحات: 4,300 EGP
    5. نثريات ومصروفات إدارية: 500 EGP
    
    الإجمالي التقديري للمقايسة: 18,500 EGP
    مدة التخليص المتوقعة: 4 أيام عمل
    صلاحية العرض: 2026-12-31
    شروط السداد: 50% سلفة نثريات و 50% عند استلام الفاتورة النهائية
    """

    res = extractor.extract(sample_text, {})
    assert "الأهرام" in res["broker_name"] or "تخليص" in res["broker_name"]
    assert "Alexandria" in res["port_name"] or "الإسكندرية" in res["port_name"]
    assert res["container_type"] == "40HQ"
    assert res["clearance_fee"] == 3500.0
    assert res["inland_transport_fee"] == 8000.0
    assert res["inspection_fee"] == 2200.0
    assert res["port_expenses"] == 4300.0
    assert res["miscellaneous_fee"] == 500.0
    assert res["total_estimated_clearance_cost"] == 18500.0
    assert res["transit_clearance_days"] == 4
    assert res["currency"] == "EGP"


def _providers(db_session):
    from modules.external_service_providers.model import ExternalServiceProvider

    for pid in (1, 2):
        db_session.add(ExternalServiceProvider(
            provider_id=pid, partner_code=f"ESP-T{pid}", partner_name=f"Broker {pid}", partner_type="Customs Broker"
        ))
    db_session.commit()


def test_create_clearance_rfq_and_add_quotation(db_session):
    _providers(db_session)  # quotes need an active partner (CCQ-06)
    rfq_data = CustomsClearanceRFQCreate(
        title="طلب عروض أسعار تخليص ونقل شحنة خط إنتاج",
        port_name="Alexandria Port",
        commodity_description="Industrial Production Line Spare Parts",
        hs_code="8479.89.90",
        shipment_type="Ocean FCL (40HQ)",
        containers_count=2,
        packages_count=10,
        gross_weight_kg=15000.0,
        cbm=45.0,
    )
    rfq = create_rfq_service(db_session, rfq_data)
    assert rfq.rfq_id is not None
    assert rfq.rfq_code.startswith("CRFQ-")
    assert rfq.status == "Draft"

    # Add competing broker quote 1
    q1 = add_quotation_service(
        db_session,
        rfq.rfq_id,
        CustomsClearanceQuotationCreate(
            provider_id=1,
            provider_name="مكتب الأهرام للتخليص الجمركي",
            license_number="LIC-2024-001",
            clearance_fee=3500.0,
            inland_transport_fee=7000.0,
            inspection_fee=1500.0,
            port_expenses=2000.0,
            miscellaneous_fee=500.0,
            estimated_turnaround_days=3,
        ),
    )
    assert q1.total_cost == 14500.0

    # Add competing broker quote 2 (cheaper)
    q2 = add_quotation_service(
        db_session,
        rfq.rfq_id,
        CustomsClearanceQuotationCreate(
            provider_id=2,
            provider_name="النسر للخدمات اللوجستية",
            license_number="LIC-2024-002",
            clearance_fee=3000.0,
            inland_transport_fee=6500.0,
            inspection_fee=1200.0,
            port_expenses=1800.0,
            miscellaneous_fee=500.0,
            estimated_turnaround_days=4,
        ),
    )
    assert q2.total_cost == 13000.0

    # Check RFQ metrics
    rfqs = get_rfqs_service(db_session)
    assert len(rfqs) == 1
    loaded_rfq = rfqs[0]
    assert loaded_rfq.lowest_clearance_cost == 13000.0
    assert loaded_rfq.fastest_turnaround_days == 3
    assert len(loaded_rfq.quotations) == 2

    # Award the best quote
    awarded_rfq = award_quotation_service(db_session, loaded_rfq.rfq_id, q2.quotation_id, notes="تم اختيار العرض الأقل تكلفة")
    assert awarded_rfq.status == "Awarded"
    assert awarded_rfq.awarded_provider_id == 2
    assert awarded_rfq.awarded_provider_name == "النسر للخدمات اللوجستية"
    assert awarded_rfq.awarded_quotation_id == q2.quotation_id


def test_clearance_price_list_master(db_session):
    price_item = create_price_item_service(
        db_session,
        ClearancePriceListItemCreate(
            provider_id=1,
            provider_name="مكتب الأهرام للتخليص الجمركي",
            port_name="Alexandria Port",
            service_category="Agency Fee",
            container_type="40HQ",
            unit_price=3500.0,
            currency="EGP",
        ),
    )
    assert price_item.price_item_id is not None
    assert price_item.unit_price == 3500.0

    items = get_price_list_service(db_session, port_name="Alexandria")
    assert len(items) == 1
    assert items[0].provider_name == "مكتب الأهرام للتخليص الجمركي"


def test_acc_customs_broker_quotation_extractor():
    extractor = CustomsBrokerQuotationExtractor()
    acc_text = """
    شركة اسكندرية للأعمال الجمركية
    Alexandria Customs Clearance Co.
    عرض أسعار خدمات التخليص والنقل الداخلي
    ميناء الإسكندرية والدخيلة
    التاريخ: 2026-07-09

    أولاً: أتعاب التخليص الجمركي
    - أتعاب تخليص حاوية 40 قدم: 2,500 EGP
    - أتعاب تخليص حاوية 20 قدم: 2,000 EGP
    - أتعاب شحنة طرد جزئي LCL: 1,500 EGP

    ثانياً: النولون والنقل البري الداخلي (الإسكندرية - القاهرة)
    - نقل حاوية 40 قدم: 18,400 EGP
    - نقل حاوية 20 قدم: 16,000 EGP
    - نقل سيارة صغيرة LCL: 6,000 EGP

    ثالثاً: مصاريف الفحص والجهات الرقابية والموانئ
    1. موازين: 250 EGP
    2. كشف ومعاينة: 450 EGP
    3. سحب عينات جهات رقابية: 650 EGP
    4. عمالة وتعتيق: 800 EGP
    5. رسوم نافذة وإدراج: 950 EGP
    6. تصريح خروج وبوابات: 350 EGP
    7. إذن تسليم ملاحي: 1,200 EGP
    8. غسيل حاويات: 400 EGP
    9. كارتة طريق ورسوم مرور: 550 EGP
    10. مصاريف تفريغ وساحات: 1,500 EGP
    11. نثريات ودمغات: 500 EGP
    12. مطابقة وهيئة الرقابة: 1,200 EGP
    13. خدمات أرضية وتداول: 700 EGP
    14. تأمين بوليصة: 500 EGP

    الإجمالي التقديري لحاوية 40HQ: 30,900 EGP
    الإجمالي التقديري لحاوية 20GP: 27,300 EGP
    الإجمالي التقديري لطرد LCL: 13,650 EGP
    """

    res = extractor.extract(acc_text, {})
    assert "اسكندرية" in res["broker_name"] or "Alexandria" in res["broker_name"]
    assert "الإسكندرية" in res["port_name"] or "Alexandria" in res["port_name"]
    assert res["total_estimated_clearance_cost"] == 30900.0
    assert res["clearance_fee"] == 2500.0
    assert res["inland_transport_fee"] == 18400.0
    assert "rate_options" in res
    assert len(res["rate_options"]) >= 3
    
    # Check rate options
    options_by_type = {opt["container_type"]: opt for opt in res["rate_options"]}
    assert "40HQ" in options_by_type
    assert options_by_type["40HQ"]["total_estimated_clearance_cost"] == 30900.0
    assert "20GP" in options_by_type
    assert options_by_type["20GP"]["total_estimated_clearance_cost"] == 27300.0
    assert "LCL" in options_by_type
    assert options_by_type["LCL"]["total_estimated_clearance_cost"] == 13650.0

    # Check expenses catalog
    assert "expenses_catalog" in res
    assert len(res["expenses_catalog"]) >= 14

