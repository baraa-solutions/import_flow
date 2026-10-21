from datetime import date, timedelta
from decimal import Decimal
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.customs_tariff import repository
from modules.customs_tariff.model import CustomsTariff, PreferentialAgreement, FeeCode
from modules.customs_tariff.schemas import (
    CustomsTariffCreate,
    MultiItemCustomsEstimateLine,
    MultiItemCustomsEstimateRequest,
    PreferentialAgreementCreate,
    TariffVerificationRequest,
)
from modules.customs_tariff.service import (
    create_preferential_agreement_service,
    create_tariff_service,
    estimate_customs_duty_service,
    estimate_multi_item_customs_duty_service,
    verify_and_update_tariff_service,
)


@pytest.fixture
def db_session():
    test_engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=test_engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)
    db = TestingSessionLocal()

    # Seed default fee codes
    fc1 = FeeCode(code="390", name_ar="خدمات جمركية", collection_group="رسوم النافذة الموحدة", calculation_type="flat", flat_amount=Decimal("1081.00"), is_active=True)
    fc2 = FeeCode(code="392", name_ar="خدمات معلوماتية", collection_group="رسوم النافذة الموحدة", calculation_type="flat", flat_amount=Decimal("3457.00"), is_active=True)
    fc3 = FeeCode(code="394", name_ar="ضريبة قيمة مضافة نافذة", collection_group="رسوم النافذة الموحدة", calculation_type="derived", derived_formula_rate=Decimal("14.00"), derived_formula_base_codes="390,392", is_active=True)
    db.add_all([fc1, fc2, fc3])
    db.commit()

    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=test_engine)


def test_nafeza_official_worked_example_multi_item_engine(db_session):
    """
    اختبار محرك الحساب الجمركي المصري المتعدد الأصناف بنفس أرقام البيان الجمركي الفعلي المرفق من منصة نافذة:
    - رقم البيان: 2026-612-1-94731
    - قيمة الفاتورة: 11,736.4 USD
    - سعر الصرف: 50.7917
    - التأمين: 14,902.793 EGP
    - النولون: 11,922.234 EGP
    - رسوم إضافية أساسية: 1,329.50 EGP
    - السطور 3 بنود:
      Line 1: 8536410000 | 607.6 USD | 10% duty | 10% sched tax | 0 inspection
      Line 2: 8537109000 | 4371.2 USD | 10% duty | 10% sched tax | 8514.81 inspection
      Line 3: 8537109000 | 6757.6 USD | 10% duty | 10% sched tax | 69772.09 inspection
    """
    create_tariff_service(
        db_session,
        CustomsTariffCreate(
            hs_code="8536410000",
            hs_description="Relays for voltage not exceeding 60 V",
            customs_duty_rate=Decimal("10.00"),
            vat_rate=Decimal("14.00"),
            schedule_tax_rate=Decimal("10.00"),
            customs_service_fee_rate=Decimal("1.00"),
        ),
    )
    create_tariff_service(
        db_session,
        CustomsTariffCreate(
            hs_code="8537109000",
            hs_description="Boards, panels, consoles for electric control",
            customs_duty_rate=Decimal("10.00"),
            vat_rate=Decimal("14.00"),
            schedule_tax_rate=Decimal("10.00"),
            customs_service_fee_rate=Decimal("1.00"),
        ),
    )

    request = MultiItemCustomsEstimateRequest(
        currency="USD",
        exchange_rate=Decimal("50.7917"),
        insurance_egp=Decimal("14902.793"),
        freight_egp=Decimal("11922.234"),
        additional_fees_egp=Decimal("1329.50"),
        cif_declared_total_egp=Decimal("623000.00"),
        vat_rate_override=Decimal("14.00"),
        lines=[
            MultiItemCustomsEstimateLine(
                line_no=1,
                hs_code="8536410000",
                value_fc=Decimal("607.6"),
                weight_kg=Decimal("4.68"),
                qty=Decimal("10"),
                inspection_fee_egp=Decimal("0.00"),
            ),
            MultiItemCustomsEstimateLine(
                line_no=2,
                hs_code="8537109000",
                value_fc=Decimal("4371.2"),
                weight_kg=Decimal("5.00"),
                qty=Decimal("5"),
                inspection_fee_egp=Decimal("8514.81"),
            ),
            MultiItemCustomsEstimateLine(
                line_no=3,
                hs_code="8537109000",
                value_fc=Decimal("6757.6"),
                weight_kg=Decimal("5.00"),
                qty=Decimal("10"),
                inspection_fee_egp=Decimal("69772.09"),
            ),
        ],
    )

    result = estimate_multi_item_customs_duty_service(db_session, request)

    # Assert Header Totals match Nafeza Statement exactly
    assert result.invoice_total_value_fc == Decimal("11736.4")
    assert len(result.lines) == 3

    # Assert Line 1 Totals
    line1 = result.lines[0]
    assert line1.duty_egp == Decimal("3225.31")
    assert line1.schedule_tax_egp == Decimal("3225.31")

    # Assert Line 2 Totals
    line2 = result.lines[1]
    assert line2.duty_egp == Decimal("23203.52")

    # Assert Line 3 Totals
    line3 = result.lines[2]
    assert line3.duty_egp == Decimal("35871.18")

    # Assert Global Aggregations
    assert result.total_duty_egp == Decimal("62300.01")
    assert result.total_vat_egp == Decimal("95942.00")
    assert result.total_inspection_fees_egp == Decimal("78286.90")


def test_value_based_apportionment_rule(db_session):
    """
    اختبار قاعدة التوزيع على أساس القيمة (Value-based Apportionment)
    """
    create_tariff_service(
        db_session,
        CustomsTariffCreate(
            hs_code="1001.99.00",
            hs_description="Wheat and meslin",
            customs_duty_rate=Decimal("0.00"),
            vat_rate=Decimal("0.00"),
        ),
    )

    request = MultiItemCustomsEstimateRequest(
        currency="USD",
        exchange_rate=Decimal("50.00"),
        insurance_egp=Decimal("1000.00"),
        freight_egp=Decimal("1000.00"),
        additional_fees_egp=Decimal("0.00"),
        lines=[
            MultiItemCustomsEstimateLine(
                line_no=1,
                hs_code="1001.99.00",
                value_fc=Decimal("2000.00"),
            ),
            MultiItemCustomsEstimateLine(
                line_no=2,
                hs_code="1001.99.00",
                value_fc=Decimal("8000.00"),
            ),
        ],
    )

    result = estimate_multi_item_customs_duty_service(db_session, request)

    # Total insurance + freight = 2000 EGP
    # Line 1 (20% share) gets 400 EGP
    # Line 2 (80% share) gets 1600 EGP
    assert result.lines[0].allocated_insurance_freight_egp == Decimal("400.00")
    assert result.lines[1].allocated_insurance_freight_egp == Decimal("1600.00")


def test_deemed_insurance_and_freight_fallback(db_session):
    """
    اختبار التأمين والنولون الحكمي (Statutory/Deemed Insurance & Freight)
    عند غياب وثائق التأمين أو الشحن (2.5% تأمين حكمي و 2.0% نولون حكمي).
    """
    create_tariff_service(
        db_session,
        CustomsTariffCreate(
            hs_code="8536410000",
            hs_description="Relays",
            customs_duty_rate=Decimal("10.00"),
            vat_rate=Decimal("14.00"),
        ),
    )

    request = MultiItemCustomsEstimateRequest(
        currency="USD",
        exchange_rate=Decimal("50.00"),
        insurance_egp=Decimal("0.00"),
        freight_egp=Decimal("0.00"),
        has_insurance_document=False,  # No document -> Deemed 2.5%
        has_freight_document=False,    # No document -> Deemed 2.0%
        lines=[
            MultiItemCustomsEstimateLine(
                line_no=1,
                hs_code="8536410000",
                value_fc=Decimal("10000.00"),
            ),
        ],
    )

    result = estimate_multi_item_customs_duty_service(db_session, request)

    # FOB = 10,000 USD * 50.00 EGP = 500,000 EGP
    # Deemed Insurance = 500,000 * 2.5% = 12,500 EGP
    # Deemed Freight   = 500,000 * 2.0% = 10,000 EGP
    assert result.fob_value_egp == Decimal("500000.00")
    assert result.insurance_egp == Decimal("12500.00")
    assert result.freight_egp == Decimal("10000.00")
    assert result.insurance_source == "deemed"
    assert result.freight_source == "deemed"
    assert result.lines[0].cif_value_egp == Decimal("522500.00")  # 500k + 12.5k + 10k


def test_full_customs_exemption_duty_only(db_session):
    """
    اختبار الإعفاء الجمركي الكامل لضريبة الوارد (INV-LAW-EXEMPT-01 - قانون الاستثمار)
    الجمرك = صفر، ولكن ضريبة القيمة المضافة تُحسب على كامل الوعاء.
    """
    create_tariff_service(
        db_session,
        CustomsTariffCreate(
            hs_code="8536410000",
            hs_description="Relays",
            customs_duty_rate=Decimal("10.00"),
            vat_rate=Decimal("14.00"),
        ),
    )

    request = MultiItemCustomsEstimateRequest(
        currency="USD",
        exchange_rate=Decimal("50.00"),
        insurance_egp=Decimal("0.00"),
        freight_egp=Decimal("0.00"),
        has_insurance_document=False,  # Deemed costs 4.5% -> CIF 104,500 EGP
        has_freight_document=False,
        lines=[
            MultiItemCustomsEstimateLine(
                line_no=1,
                hs_code="8536410000",
                value_fc=Decimal("2000.00"),
                exemption_code="INV-LAW-EXEMPT-01",  # Exempt Duty Only
            ),
        ],
    )

    result = estimate_multi_item_customs_duty_service(db_session, request)

    line = result.lines[0]
    # FOB = 100,000 EGP. Deemed Insurance + Freight = 4,500 EGP -> CIF = 104,500 EGP
    assert line.cif_value_egp == Decimal("104500.00")
    assert line.duty_taxable_base_egp == Decimal("0.00")  # Base reduced to 0 by exemption
    assert line.duty_egp == Decimal("0.00")              # Duty = 0 EGP
    assert line.vat_base_egp == Decimal("104500.00")     # VAT Base = CIF (104.5k) + Duty (0)
    assert line.vat_egp == Decimal("14630.00")          # VAT 14% = 14,630 EGP
    assert line.exemption_code_applied == "INV-LAW-EXEMPT-01"


def test_partial_percentage_exemption(db_session):
    """
    اختبار الإعفاء الجمركي الجزئي بنسبة 50% (PARTIAL-50-EXEMPT)
    """
    create_tariff_service(
        db_session,
        CustomsTariffCreate(
            hs_code="8536410000",
            hs_description="Relays",
            customs_duty_rate=Decimal("10.00"),
            vat_rate=Decimal("14.00"),
        ),
    )

    request = MultiItemCustomsEstimateRequest(
        currency="USD",
        exchange_rate=Decimal("50.00"),
        insurance_egp=Decimal("0.00"),
        freight_egp=Decimal("0.00"),
        has_insurance_document=False,  # Deemed costs 4.5% -> CIF 104,500 EGP
        has_freight_document=False,
        lines=[
            MultiItemCustomsEstimateLine(
                line_no=1,
                hs_code="8536410000",  # Standard Tariff 10%
                value_fc=Decimal("2000.00"),
                exemption_code="PARTIAL-50-EXEMPT",
            ),
        ],
    )

    result = estimate_multi_item_customs_duty_service(db_session, request)

    line = result.lines[0]
    # CIF = 104,500 EGP
    # Taxable Base = 104,500 * (1 - 0.50) = 52,250 EGP
    # Duty 10% on 52,250 = 5,225 EGP
    assert line.cif_value_egp == Decimal("104500.00")
    assert line.duty_taxable_base_egp == Decimal("52250.00")
    assert line.duty_egp == Decimal("5225.00")


def test_trade_agreement_preferential_tariff(db_session):
    """
    اختبار تطبيق التخفيض الجمركي لاتفاقية الشراكة المصرية التركية (TR Origin -> 0% Duty)
    """
    create_tariff_service(
        db_session,
        CustomsTariffCreate(
            hs_code="8536410000",
            hs_description="Relays",
            customs_duty_rate=Decimal("10.00"),
            vat_rate=Decimal("14.00"),
        ),
    )
    create_preferential_agreement_service(
        db_session,
        PreferentialAgreementCreate(
            hs_code="8536410000",
            agreement_name="اتفاقية الشراكة المصرية التركية",
            reduction_type="full_duty_exemption",
            reduction_percentage=Decimal("1.00"),
            origin_countries="TR",
        ),
    )

    request = MultiItemCustomsEstimateRequest(
        currency="USD",
        exchange_rate=Decimal("50.00"),
        insurance_egp=Decimal("0.00"),
        freight_egp=Decimal("0.00"),
        lines=[
            MultiItemCustomsEstimateLine(
                line_no=1,
                hs_code="8536410000",
                value_fc=Decimal("2000.00"),
                origin_country="TR",  # Turkey Partnership Agreement
            ),
        ],
    )

    result = estimate_multi_item_customs_duty_service(db_session, request)

    line = result.lines[0]
    assert line.customs_duty_rate == Decimal("0.00")
    assert line.duty_egp == Decimal("0.00")
    assert line.preferential_agreement_applied == "اتفاقية الشراكة المصرية التركية"


def test_manual_tariff_verification_workflow(db_session):
    """
    اختبار توثيق المراجعة اليدوية ورابط نافذة بدون تغيير في النسب (Addendum 3)
    """
    hs = "8471300000"
    create_tariff_service(
        db_session,
        CustomsTariffCreate(
            hs_code=hs,
            hs_description="Laptops and Notebooks Test",
            customs_duty_rate=Decimal("5.00"),
            vat_rate=Decimal("14.00"),
        ),
    )

    req = TariffVerificationRequest(
        verified_by="أحمد صلاح",
        source_url="https://www.nafeza.gov.eg/ar/tarrif?code=8471300000",
        confidence="verified_manual",
        prior_approval_note="موافقة الجهاز القومي لتنظيم الاتصالات NTRA",
    )

    verified = verify_and_update_tariff_service(db_session, hs, req)
    assert verified.verified_by == "أحمد صلاح"
    assert verified.source_url == "https://www.nafeza.gov.eg/ar/tarrif?code=8471300000"
    assert verified.confidence == "verified_manual"
    assert verified.prior_approval_note == "موافقة الجهاز القومي لتنظيم الاتصالات NTRA"
    assert verified.last_verified_date == date.today()


def test_tariff_rate_change_creates_version_history(db_session):
    """
    اختبار أتمتة السلسلة التاريخية (Addendum 3 Versioning):
    عند تعديل نسبة ضريبة الوارد لبند جمركي، يتم إغلاق السجل القديم بتاريخ اليوم وإصدار سجل جديد.
    عند الحساب بتاريخ قديم، يتم الاعتماد على نسبة السجل التاريخي القديم.
    """
    hs = "9999999999"

    # Step 1: Create initial tariff effective from 30 days ago with 10% duty
    past_date = date.today() - timedelta(days=30)
    old_version = CustomsTariff(
        hs_code=hs,
        hs_description="Versioned Item",
        customs_duty_rate=Decimal("10.00"),
        vat_rate=Decimal("14.00"),
        effective_from=past_date,
        is_active=True,
    )
    db_session.add(old_version)
    db_session.commit()

    # Step 2: Perform manual verification update changing duty rate to 15% today
    update_req = TariffVerificationRequest(
        customs_duty_rate=Decimal("15.00"),
        verified_by="جمرك الإسكندرية",
        source_url="https://www.nafeza.gov.eg/ar/tarrif?code=9999999999",
    )
    new_version = verify_and_update_tariff_service(db_session, hs, update_req)

    assert new_version.customs_duty_rate == Decimal("15.00")
    assert new_version.effective_from == date.today()
    assert new_version.effective_to is None
    assert new_version.is_active is True

    # Check old version was archived
    db_session.refresh(old_version)
    # Versions never overlap (BE67 HS versioning): the old one closes the day before the new one starts.
    assert old_version.effective_to == date.today() - timedelta(days=1)
    assert old_version.is_active is False

    # Step 3: Historical date query (15 days ago) returns old 10% rate!
    historical_tariff = repository.get_active_tariff_on_date(db_session, hs, past_date + timedelta(days=15))
    assert historical_tariff is not None
    assert historical_tariff.customs_duty_rate == Decimal("10.00")


def test_database_preferential_agreement_resolution(db_session):
    """
    اختبار استعلام وقواعد الاتفاقيات التفضيلية المخزنة بقاعدة البيانات (Addendum 3)
    """
    hs = "8703230000"
    create_tariff_service(
        db_session,
        CustomsTariffCreate(
            hs_code=hs,
            hs_description="Test Car Tariff",
            customs_duty_rate=Decimal("40.00"),
            vat_rate=Decimal("14.00"),
        ),
    )
    create_preferential_agreement_service(
        db_session,
        PreferentialAgreementCreate(
            hs_code=hs,
            agreement_name="اتفاقية تونس التجارية التفضيلية الخاصة",
            reduction_type="full_duty_exemption",
            reduction_percentage=Decimal("1.00"),
            origin_countries="TN,DZ",
        ),
    )

    request = MultiItemCustomsEstimateRequest(
        currency="USD",
        exchange_rate=Decimal("50.00"),
        insurance_egp=Decimal("0.00"),
        freight_egp=Decimal("0.00"),
        lines=[
            MultiItemCustomsEstimateLine(
                line_no=1,
                hs_code=hs,
                value_fc=Decimal("1000.00"),
                origin_country="TN",
            ),
        ],
    )

    result = estimate_multi_item_customs_duty_service(db_session, request)
    line = result.lines[0]
    assert line.customs_duty_rate == Decimal("0.00")
    assert line.duty_egp == Decimal("0.00")
    assert line.preferential_agreement_applied == "اتفاقية تونس التجارية التفضيلية الخاصة"


def test_multi_item_engine_exemption_conditions_met_toggle(db_session):
    """
    اختبار تفعيل وإلغاء خيار استيفاء شروط الإعفاء الجمركي (is_exemption_conditions_met):
    - عند True: تصبح ضريبة الوارد 0% ويعاد احتساب الوعاء الضريبي للقيمة المضافة.
    - عند False: تطبق النسبة القياسية (Standard Duty Rate) كما هي.
    """
    hs = "8471.30.00"
    create_tariff_service(
        db_session,
        CustomsTariffCreate(
            hs_code=hs,
            hs_description="Laptop Computer",
            customs_duty_rate=Decimal("15.00"),
            vat_rate=Decimal("14.00"),
        ),
    )

    # 1. When is_exemption_conditions_met = True -> 0% duty
    req_active = MultiItemCustomsEstimateRequest(
        currency="USD",
        exchange_rate=Decimal("50.00"),
        insurance_egp=Decimal("0.00"),
        freight_egp=Decimal("0.00"),
        lines=[
            MultiItemCustomsEstimateLine(
                line_no=1,
                hs_code=hs,
                value_fc=Decimal("1000.00"),
                is_exemption_conditions_met=True,
            ),
        ],
    )
    res_active = estimate_multi_item_customs_duty_service(db_session, req_active)
    line_active = res_active.lines[0]
    assert line_active.customs_duty_rate == Decimal("0.00")
    assert line_active.duty_egp == Decimal("0.00")
    assert line_active.is_exemption_applied is True
    # When duty is 0, VAT base = CIF line EGP
    assert line_active.vat_base_egp == line_active.cif_value_egp
    assert line_active.vat_egp == (line_active.cif_value_egp * Decimal("0.14"))

    # 2. When is_exemption_conditions_met = False -> standard 15% duty
    req_inactive = MultiItemCustomsEstimateRequest(
        currency="USD",
        exchange_rate=Decimal("50.00"),
        insurance_egp=Decimal("0.00"),
        freight_egp=Decimal("0.00"),
        lines=[
            MultiItemCustomsEstimateLine(
                line_no=1,
                hs_code=hs,
                value_fc=Decimal("1000.00"),
                is_exemption_conditions_met=False,
            ),
        ],
    )
    res_inactive = estimate_multi_item_customs_duty_service(db_session, req_inactive)
    line_inactive = res_inactive.lines[0]
    assert line_inactive.customs_duty_rate == Decimal("15.00")
    expected_duty = line_inactive.cif_value_egp * Decimal("0.15")
    assert line_inactive.duty_egp == expected_duty
    assert line_inactive.is_exemption_applied is False
    # VAT base = CIF + Duty
    assert line_inactive.vat_base_egp == line_inactive.cif_value_egp + expected_duty
    assert line_inactive.vat_egp == (line_inactive.vat_base_egp * Decimal("0.14"))


