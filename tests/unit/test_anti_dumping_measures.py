"""
Unit Tests for Egyptian Customs Anti-Dumping & Safeguard Measures
(tests/unit/test_anti_dumping_measures.py)

Covers:
1. Smart Nafeza Text Parsing of Anti-Dumping directives (غ6555, غ6904) and HS Code 5703290000.
2. Anti-dumping risk flag and notes persistence in CustomsTariff models.
3. Automatic synchronization of Critical Experience Guide Entry for Anti-Dumping HS codes.
4. Shipment Smart Reference Card Critical Experience Alert generation.
5. Customs Landed Cost Calculation Engine including Anti-Dumping in VAT base.
"""
from decimal import Decimal
import pytest
from sqlalchemy.orm import Session

from modules.customs_tariff.nafeza_text_parser import parse_nafeza_tariff_text
from modules.customs_tariff.schemas import (
    CustomsDutyEstimateRequest,
    CustomsTariffCreate,
    MultiItemCustomsEstimateLine,
    MultiItemCustomsEstimateRequest,
)
from modules.customs_tariff.service import (
    create_tariff_service,
    estimate_customs_duty_service,
    estimate_multi_item_customs_duty_service,
)
from modules.experience_guide.model import GuideEntry, GuideEntryScope
from modules.experience_guide.schemas import GuideMatchRequest
from modules.experience_guide.service import ExperienceGuideService
from modules.import_files.model import ImportFile


SAMPLE_NAFEZA_ANTI_DUMPING_TEXT = """رمز النظام المُنسق
5703290000

الوصف
سجاد وأغطية أرضيات أخر من نايلون أو من بولي أميدات أخر، ذات أوبار ، وإن كانت جاهزة.

الضرائب
ضريبة الوارد
60.000 %
ضريبة الوارد
0.000 %
ضريبة قيمه مضافه
14.000 %

المستندات والأعمال
ر6722 - اتفاقية صربيا تخفيض 10%
ق4518 - لايصرح باستيراد صنف الا بموافقة مختومة بخاتم شعارجمهوريةمن هـ .ع.ص.وطبقا لملحق8 وتعديلاته
ر6706 - تحصل ض. وارد طبقا للفئات الموضحة قرين كل بند على سلع واردة فى إطار إتفاقيةالميركسور
ر6668 - تخفض ض .ج ورسوم بنسبة100%علىسلع صناعيةواردةفى ظل اتفاقية الشراكةالمصرية والمملكة المتحدة
ر6663 - تخفض ض .ج ورسوم ذات أثر مماثل بنسبة 100%علىسلع صناعيةواردةفى ظل شراكةأوربيةملحق2 ،3 ، 4
ر6631 - يعفى من الضريبة الجمركية والرسوم ذات الاثر المماثل الأصناف الواردة من دول الافتا بنسبة100%
ر6607 - تخفض الرسوم الجمركية فى ظل اتفاقيةتركيا بنسبة100% على اصناف واردةبالقائمة 1 برتوكول 1
ر6517 - ستثنى من الأعفاءسلع زراعيةو سلع زراعيةمصنعة وسلع واردة بقائمة4فى اطار اتفاقيةبين مصر وتونس
ر6516 - استثناء أصناف واردةبالمرفق 1 من الاعفاء من الضرائب فى اطار اتفاقية ثنائيةبين ج.م.ع والأردن
غ6555 - يراعى إيداع حصيلة رسم الإغراق والتدابير الوقائية لحساب وزارة الاستثمار والتجارة الخارجية
ر6593 - خضوع الواردت من صنف السجاد الميكانيكى وأغطية الأرضيات من مواد نسجية أو صناعية أو تركيبية و
ق4547 - يشترط للافراج عن الصنف وارد اتجار أن يكون انتاج مصانع مسجلة من شركات مالكة للعلامة
ق4538 - عدامايرداستخدام خاص وشخصى يشترط للافراج عن الصنف أن يكون من أحد منتجين بـ هـ.ع.ص.و
ق4122 - يشترط لاستيراد الصنف للاتجار ان يكون مشحونا من بلد المنشأ أو من مراكزرئيسيةللشركات المنتجة
غ6904 - تخطـــر مصلحـــه الضرائب المصرية فى حالة رد ض القيمة المضافةالسابق سدادها على رسوم الاغراق
ق9994 - لايفرج عن صنف بضاعة مرشدةللمنطقة الحرة الابحصص لكل مستورد يحددهاجهاز تنفيذى للمنطقةالحرة
"""


def test_parse_nafeza_anti_dumping_text():
    tariff, agreements = parse_nafeza_tariff_text(SAMPLE_NAFEZA_ANTI_DUMPING_TEXT)

    assert tariff.hs_code == "5703290000"
    assert "سجاد" in tariff.hs_description
    assert tariff.customs_duty_rate == Decimal("60.00")
    assert tariff.vat_rate == Decimal("14.00")
    assert tariff.has_anti_dumping_risk is True
    assert tariff.anti_dumping_notes is not None
    assert "غ6555" in tariff.anti_dumping_notes
    assert "غ6904" in tariff.anti_dumping_notes
    assert "وزارة الاستثمار والتجارة الخارجية" in tariff.anti_dumping_notes
    assert len(agreements) >= 6


def test_sync_anti_dumping_guide_entry(db_session: Session):
    guide_service = ExperienceGuideService(db_session)

    entry = guide_service.sync_anti_dumping_guide_entry(
        hs_code="5703290000",
        hs_description="سجاد وأغطية أرضيات أخر من نايلون",
        anti_dumping_notes="غ6555 - يراعى إيداع حصيلة رسم الإغراق والتدابير الوقائية لحساب وزارة الاستثمار والتجارة الخارجية",
    )

    assert entry.entry_id is not None
    assert entry.severity == "critical"
    assert entry.created_by == "System Seed (Logistics)"
    # Stored in English (single-language storage); the Nafeza notes are kept verbatim
    assert entry.title == "HS 5703290000: anti-dumping / safeguard measures"
    assert "غ6555" in entry.content

    # Match shipment by HS Code
    match_resp = guide_service.match_shipment(
        GuideMatchRequest(
            hs_code="5703290000",
            product_category="سجاد",
        )
    )
    assert match_resp.has_critical_alert is True
    assert len(match_resp.critical_entries) >= 1
    assert any("5703290000" in e.title or "إغراق" in e.title for e in match_resp.critical_entries)


def test_customs_landed_cost_anti_dumping_vat_base(db_session: Session):
    # 1. Create tariff record with Anti-Dumping risk
    tariff_in = CustomsTariffCreate(
        hs_code="5703290000",
        hs_description="سجاد وأغطية أرضيات نايلون",
        customs_category="CARPETS_TEXTILES",
        customs_duty_rate=Decimal("60.00"),
        vat_rate=Decimal("14.00"),
        has_anti_dumping_risk=True,
        anti_dumping_notes="غ6555 - يراعى إيداع حصيلة رسم الإغراق والتدابير الوقائية لحساب وزارة الاستثمار والتجارة الخارجية",
    )
    tariff = create_tariff_service(db_session, tariff_in)
    assert tariff.has_anti_dumping_risk is True

    # 2. The rate comes from a registered measure (decree + origin + effective dates), never from the request
    from datetime import date
    from modules.customs_tariff.schemas import TradeRemedyMeasureCreate
    from modules.customs_tariff.trade_remedy_service import create_trade_remedy_measure

    create_trade_remedy_measure(db_session, TradeRemedyMeasureCreate(
        measure_type="ANTI_DUMPING", hs_code="5703", origin_country="CN", duty_basis="PERCENT_OF_CIF",
        rate_percent=Decimal("25.00"), decree_ref="غ6555", effective_from=date(2020, 1, 1),
    ), "tester")

    cif_val = Decimal("100000.00")  # 100,000 EGP
    calc_req = CustomsDutyEstimateRequest(
        hs_code="5703290000",
        cif_value=cif_val,
        freight=Decimal("0.00"),
        origin_country="CN",
    )

    breakdown = estimate_customs_duty_service(db_session, calc_req)

    # Basic duty = 60% of 100,000 = 60,000
    assert breakdown.import_duty_amount == Decimal("60000.00")

    # Anti-dumping duty = 25% of 100,000 = 25,000 (measure registered for CN)
    assert breakdown.has_anti_dumping_risk is True
    assert breakdown.trade_remedy_duty_egp == Decimal("25000.00")
    assert breakdown.trade_remedy_duties[0].decree_ref == "غ6555"

    # VAT Base MUST BE CIF + Import Duty + Anti-Dumping Duty = 100,000 + 60,000 + 25,000 = 185,000
    assert breakdown.vat_base == Decimal("185000.00")

    # VAT = 14% of 185,000 = 25,900
    assert breakdown.vat_amount == Decimal("25900.00")

    # The deposit-account notice is a message code rendered from the catalog, not stored text
    assert breakdown.trade_remedy_notice_code == "CT_TRADE_REMEDY_DEPOSIT"
    assert breakdown.trade_remedy_notice_params == {"decree_refs": "غ6555"}

    # Another origin: flagged item, no registered measure -> no duty, and the breakdown says why
    other = estimate_customs_duty_service(db_session, CustomsDutyEstimateRequest(
        hs_code="5703290000", cif_value=cif_val, freight=Decimal("0.00"), origin_country="TR",
    ))
    assert other.trade_remedy_duty_egp == Decimal("0.00")
    assert other.vat_base == Decimal("160000.00")
    assert other.trade_remedy_notice_code == "CT_TRADE_REMEDY_RATE_MISSING"


def test_smart_reference_card_generates_anti_dumping_critical_alert(db_session: Session):
    # Setup tariff with anti-dumping using distinct HS code
    hs = "5703290099"
    tariff_in = CustomsTariffCreate(
        hs_code=hs,
        hs_description="سجاد وأغطية أرضيات نايلون خاصة",
        customs_duty_rate=Decimal("60.00"),
        vat_rate=Decimal("14.00"),
        has_anti_dumping_risk=True,
        anti_dumping_notes="غ6555 - يراعى إيداع حصيلة رسم الإغراق والتدابير الوقائية لحساب وزارة الاستثمار والتجارة الخارجية",
    )
    create_tariff_service(db_session, tariff_in)

    # Create dummy import file with this HS code
    test_file = ImportFile(
        import_file_code="IMP-2026-TEST-DUMP-2",
        company_name="Sorour Logistics Co",
        hs_code=hs,
        product_category="سجاد وأرضيات",
        shipment_mode="SEA_FCL",
        port_of_discharge="ميناء الإسكندرية",
        supplier_name="Global Carpets Ltd",
    )
    db_session.add(test_file)
    db_session.commit()
    db_session.refresh(test_file)

    # Generate Smart Reference Card
    guide_service = ExperienceGuideService(db_session)
    card_resp = guide_service.generate_smart_reference_card(test_file.import_file_id)

    # Must contain matched guide entries with critical alert
    assert len(card_resp.matched_guide_entries) >= 1
    critical_entries = [e for e in card_resp.matched_guide_entries if e.severity == "critical"]
    assert len(critical_entries) >= 1
    assert any(hs in e.title and "anti-dumping" in e.title for e in critical_entries)
