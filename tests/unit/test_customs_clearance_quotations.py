"""
Unit Tests for Customs Clearance Quotations & Price Lists Engine and Extractor
"""

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from fastapi import HTTPException
import main  # noqa: F401 - registers all SQLAlchemy models
from database.database import Base
from modules.customs_clearance_quotations.schemas import (
    CustomsClearanceRFQCreate,
    CustomsClearanceRFQUpdate,
    CustomsClearanceRFQResponse,
    CustomsClearanceQuotationCreate,
    CustomsClearanceQuotationUpdate,
    ClearancePriceListItemCreate,
    ClearancePriceListItemUpdate,
)
from modules.customs_clearance_quotations.service import (
    create_rfq_service,
    get_rfqs_service,
    get_rfq_by_id_service,
    update_rfq_service,
    delete_rfq_service,
    add_quotation_service,
    update_quotation_service,
    delete_quotation_service,
    award_quotation_service,
    create_price_item_service,
    update_price_item_service,
    get_price_list_service,
)
from modules.external_service_providers.model import ExternalServiceProvider
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
    assert awarded_rfq.awarded_provider_name == "Broker 2"
    assert awarded_rfq.awarded_quotation_id == q2.quotation_id


def test_clearance_price_list_master(db_session):
    _providers(db_session)
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
    assert items[0].provider_name == "Broker 1"


def test_award_workflow_and_rfq_lock_guards(db_session):
    _providers(db_session)
    rfq = create_rfq_service(
        db_session,
        CustomsClearanceRFQCreate(
            title="RFQ Test Award Lock",
            port_name="Alexandria Port",
            commodity_description="Machinery",
        ),
    )
    q1 = add_quotation_service(
        db_session,
        rfq.rfq_id,
        CustomsClearanceQuotationCreate(
            provider_id=1,
            clearance_fee=2000.0,
            inland_transport_fee=4000.0,
        ),
    )
    q2 = add_quotation_service(
        db_session,
        rfq.rfq_id,
        CustomsClearanceQuotationCreate(
            provider_id=2,
            clearance_fee=1500.0,
            inland_transport_fee=3500.0,
        ),
    )
    # Award q2
    awarded_rfq = award_quotation_service(db_session, rfq.rfq_id, q2.quotation_id)
    assert awarded_rfq.status == "Awarded"
    assert awarded_rfq.awarded_quotation_id == q2.quotation_id

    # 1. Awarding a second time -> 409 CCQ_RFQ_AWARDED
    with pytest.raises(HTTPException) as exc_info:
        award_quotation_service(db_session, rfq.rfq_id, q1.quotation_id)
    assert exc_info.value.status_code == 409
    assert exc_info.value.detail.get("code") == "CCQ_RFQ_AWARDED"

    # 2. Add quote to awarded RFQ -> 409 CCQ_RFQ_AWARDED
    with pytest.raises(HTTPException) as exc_info:
        add_quotation_service(
            db_session,
            rfq.rfq_id,
            CustomsClearanceQuotationCreate(provider_id=1, clearance_fee=1000.0),
        )
    assert exc_info.value.status_code == 409
    assert exc_info.value.detail.get("code") == "CCQ_RFQ_AWARDED"

    # 3. Update quote on awarded RFQ -> 409 CCQ_RFQ_AWARDED
    with pytest.raises(HTTPException) as exc_info:
        update_quotation_service(
            db_session,
            q1.quotation_id,
            CustomsClearanceQuotationUpdate(clearance_fee=2500.0),
        )
    assert exc_info.value.status_code == 409
    assert exc_info.value.detail.get("code") == "CCQ_RFQ_AWARDED"

    # 4. Delete quote from awarded RFQ -> 409 CCQ_RFQ_AWARDED
    with pytest.raises(HTTPException) as exc_info:
        delete_quotation_service(db_session, q1.quotation_id)
    assert exc_info.value.status_code == 409
    assert exc_info.value.detail.get("code") == "CCQ_RFQ_AWARDED"

    # 5. Delete awarded RFQ -> 409 CCQ_RFQ_AWARDED
    with pytest.raises(HTTPException) as exc_info:
        delete_rfq_service(db_session, rfq.rfq_id)
    assert exc_info.value.status_code == 409
    assert exc_info.value.detail.get("code") == "CCQ_RFQ_AWARDED"

    # 6. Change status of awarded RFQ -> 409 CCQ_RFQ_AWARDED
    with pytest.raises(HTTPException) as exc_info:
        update_rfq_service(db_session, rfq.rfq_id, CustomsClearanceRFQUpdate(status="Under Review"))
    assert exc_info.value.status_code == 409
    assert exc_info.value.detail.get("code") == "CCQ_RFQ_AWARDED"


def test_cancelled_rfq_quote_mutation_guards(db_session):
    _providers(db_session)
    rfq = create_rfq_service(
        db_session,
        CustomsClearanceRFQCreate(
            title="RFQ Test Cancelled",
            port_name="Alexandria Port",
            commodity_description="Chemicals",
        ),
    )
    q1 = add_quotation_service(
        db_session,
        rfq.rfq_id,
        CustomsClearanceQuotationCreate(
            provider_id=1,
            clearance_fee=2000.0,
        ),
    )
    # Cancel RFQ
    update_rfq_service(db_session, rfq.rfq_id, CustomsClearanceRFQUpdate(status="Cancelled"))

    # Add quote on Cancelled RFQ -> 409 CCQ_RFQ_CANCELLED
    with pytest.raises(HTTPException) as exc_info:
        add_quotation_service(
            db_session,
            rfq.rfq_id,
            CustomsClearanceQuotationCreate(provider_id=2, clearance_fee=1800.0),
        )
    assert exc_info.value.status_code == 409
    assert exc_info.value.detail.get("code") == "CCQ_RFQ_CANCELLED"

    # Update quote on Cancelled RFQ -> 409 CCQ_RFQ_CANCELLED
    with pytest.raises(HTTPException) as exc_info:
        update_quotation_service(
            db_session,
            q1.quotation_id,
            CustomsClearanceQuotationUpdate(clearance_fee=2200.0),
        )
    assert exc_info.value.status_code == 409
    assert exc_info.value.detail.get("code") == "CCQ_RFQ_CANCELLED"


def test_provider_name_overridden_from_master(db_session):
    _providers(db_session)
    rfq = create_rfq_service(
        db_session,
        CustomsClearanceRFQCreate(
            title="RFQ Master Data Check",
            port_name="Alexandria Port",
            commodity_description="Electronics",
        ),
    )
    # Client passes bogus provider_name="Ignored Client Name"
    q = add_quotation_service(
        db_session,
        rfq.rfq_id,
        CustomsClearanceQuotationCreate(
            provider_id=1,
            provider_name="Ignored Client Name",
            clearance_fee=2000.0,
        ),
    )
    assert q.provider_name == "Broker 1"

    # Price item creation with client-supplied name
    price_item = create_price_item_service(
        db_session,
        ClearancePriceListItemCreate(
            provider_id=2,
            provider_name="Another Bogus Name",
            port_name="Damietta Port",
            service_category="Agency Fee",
            container_type="20GP",
            unit_price=1200.0,
        ),
    )
    assert price_item.provider_name == "Broker 2"

    # Update price item provider_id
    updated_item = update_price_item_service(
        db_session,
        price_item.price_item_id,
        ClearancePriceListItemUpdate(provider_id=1),
    )
    assert updated_item.provider_id == 1
    assert updated_item.provider_name == "Broker 1"


def test_price_list_inactive_provider_validation(db_session):
    _providers(db_session)
    # Add inactive provider
    inactive_broker = ExternalServiceProvider(
        provider_id=99,
        partner_code="ESP-INACT",
        partner_name="Inactive Broker",
        partner_type="Customs Broker",
        is_active=False,
    )
    db_session.add(inactive_broker)
    db_session.commit()

    # Create price item with inactive provider -> 400
    with pytest.raises(HTTPException) as exc_info:
        create_price_item_service(
            db_session,
            ClearancePriceListItemCreate(
                provider_id=99,
                port_name="Port Said Port",
                service_category="Agency Fee",
                container_type="40HQ",
                unit_price=1000.0,
            ),
        )
    assert exc_info.value.status_code == 400

    # Create price item with non-existent provider -> 400
    with pytest.raises(HTTPException) as exc_info:
        create_price_item_service(
            db_session,
            ClearancePriceListItemCreate(
                provider_id=999,
                port_name="Port Said Port",
                service_category="Agency Fee",
                container_type="40HQ",
                unit_price=1000.0,
            ),
        )
    assert exc_info.value.status_code == 400

    # Create valid price item, then try updating to inactive provider -> 400
    valid_item = create_price_item_service(
        db_session,
        ClearancePriceListItemCreate(
            provider_id=1,
            port_name="Alexandria Port",
            service_category="Agency Fee",
            container_type="40HQ",
            unit_price=1500.0,
        ),
    )
    with pytest.raises(HTTPException) as exc_info:
        update_price_item_service(
            db_session,
            valid_item.price_item_id,
            ClearancePriceListItemUpdate(provider_id=99),
        )
    assert exc_info.value.status_code == 400


def test_rfq_response_filters_inactive_quotes(db_session):
    _providers(db_session)
    rfq = create_rfq_service(
        db_session,
        CustomsClearanceRFQCreate(
            title="RFQ Response Filtering Check",
            port_name="Alexandria Port",
            commodity_description="Textiles",
        ),
    )
    q1 = add_quotation_service(
        db_session,
        rfq.rfq_id,
        CustomsClearanceQuotationCreate(provider_id=1, clearance_fee=1000.0),
    )
    q2 = add_quotation_service(
        db_session,
        rfq.rfq_id,
        CustomsClearanceQuotationCreate(provider_id=2, clearance_fee=2000.0),
    )

    # Soft delete q1
    delete_quotation_service(db_session, q1.quotation_id)

    # Refresh RFQ from DB
    loaded = get_rfq_by_id_service(db_session, rfq.rfq_id)
    # In DB relationship, all quotations (active or inactive) are loaded if eager/present
    assert any(q.quotation_id == q1.quotation_id and not q.is_active for q in loaded.quotations)

    # Pydantic schema serialization filters out inactive quotes
    response = CustomsClearanceRFQResponse.model_validate(loaded)
    quote_ids = [q.quotation_id for q in response.quotations]
    assert q1.quotation_id not in quote_ids
    assert q2.quotation_id in quote_ids
    assert len(response.quotations) == 1


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

