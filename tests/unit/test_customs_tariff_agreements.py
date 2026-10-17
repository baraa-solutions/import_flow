from datetime import date
from decimal import Decimal
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.customs_tariff.nafeza_text_parser import parse_nafeza_tariff_text
from modules.customs_tariff.schemas import (
    TariffAgreementBulkSaveRequest,
    OriginDutyCheckRequest,
)
from modules.customs_tariff.service import (
    parse_smart_nafeza_tariff_text_service,
    save_tariff_with_agreements_service,
    evaluate_duty_by_origin_and_document_service,
)

# Import models for metadata FK resolution
from modules.currencies.model import Currency
from modules.external_service_providers.model import ExternalServiceProvider
from modules.import_files.model import ImportFile
from modules.purchase_orders.model import PurchaseOrder
from modules.projects.model import Project
from modules.suppliers.model import Supplier
from modules.import_companies.model import ImportCompany
from modules.incoterms.model import Incoterm
from modules.customs_tariff.model import CustomsTariff, PreferentialAgreement, FeeCode


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()


RAW_NAFEZA_TEXT_EXAMPLE = """رقم البند :
3925900090
نص البند :
أصناف أخر لتجهيزات البناء من لدائن ، غير مذكورة أو داخلة في مكان أخر .
الضرائب :
ضريبة الوارد (النظام الاساسي) :
40.000 %
ضريبة الوارد (اتفاقية أمريكا اللاتينية الميركسور) :
3.000 %
ضريبة قيمه مضافه :
14.000 %
المستندات والأعمال :
ر6722 - اتفاقية صربيا تخفيض 10%
ر6668 - تخفض ض .ج ورسوم بنسبة100%علىسلع صناعيةواردةفى ظل اتفاقية الشراكةالمصرية والمملكة المتحدة
ر6706 - تحصل ض. وارد طبقا للفئات الموضحة قرين كل بند على سلع واردة فى إطار إتفاقيةالميركسور
ر6631 - يعفى من الضريبة الجمركية والرسوم ذات الاثر المماثل الأصناف الواردة من دول الافتا بنسبة100%
ر6607 - تخفض الرسوم الجمركية فى ظل اتفاقيةتركيا بنسبة100% على اصناف واردةبالقائمة 1 برتوكول 1
ر6663 - تخفض ضريبةجمركيةورسوم ذات أثر مماثل بنسبة 100% علىسلع صناعيةواردةفى ظل شراكةأوربيةملحق2"""


class TestCustomsTariffAgreementsEngine:

    def test_parse_nafeza_tariff_text(self):
        """
        اختبار تحليل نص البند المجمع من نافذة واستخراج HS Code والضرائب والاتفاقيات.
        """
        tariff, agreements = parse_nafeza_tariff_text(RAW_NAFEZA_TEXT_EXAMPLE)

        assert tariff.hs_code == "3925900090"
        assert tariff.customs_duty_rate == Decimal("40.00")
        assert tariff.vat_rate == Decimal("14.00")
        assert len(agreements) == 6

        # Check Mercosur agreement parsing
        mercosur = next(ag for ag in agreements if "الميركسور" in ag.agreement_name)
        assert mercosur.preferential_duty_rate == Decimal("3.00")
        assert "BR" in mercosur.origin_countries

        # Check Serbia agreement parsing
        serbia = next(ag for ag in agreements if "صربيا" in ag.agreement_name)
        assert serbia.publication_notice == "ر6722"
        assert "RS" in serbia.origin_countries

    def test_bulk_save_tariff_with_agreements(self, db_session):
        """
        اختبار حفظ البند الجمركي مع كافة اتفاقياته في معاملة واحدة.
        """
        parsed = parse_smart_nafeza_tariff_text_service(RAW_NAFEZA_TEXT_EXAMPLE)
        save_res = save_tariff_with_agreements_service(
            db_session,
            TariffAgreementBulkSaveRequest(
                tariff=parsed.tariff_data,
                agreements=parsed.agreements,
            )
        )

        assert save_res["tariff"].hs_code == "3925900090"
        assert len(save_res["agreements"]) == 6

    def test_origin_duty_check_non_agreement_country(self, db_session):
        """
        إذا لم تكن الدولة مرتبطة باتفاقية (مثل الصين CN): تطبيق الضريبة الأساسية 40% دون طلب مستندات.
        """
        parsed = parse_smart_nafeza_tariff_text_service(RAW_NAFEZA_TEXT_EXAMPLE)
        save_tariff_with_agreements_service(
            db_session,
            TariffAgreementBulkSaveRequest(
                tariff=parsed.tariff_data,
                agreements=parsed.agreements,
            )
        )

        res = evaluate_duty_by_origin_and_document_service(
            db_session,
            OriginDutyCheckRequest(
                hs_code="3925900090",
                origin_country="CN",
                has_preferential_document=False,
            )
        )

        assert res.base_duty_rate == Decimal("40.00")
        assert res.effective_duty_rate == Decimal("40.00")
        assert res.has_matching_agreement is False
        assert res.warning_note is None

    def test_origin_duty_check_agreement_country_with_document(self, db_session):
        """
        إذا كانت الدولة مرتبطة باتفاقية (مثل تركيا TR) وتم تأكيد المستند (EUR.1): تطبيق إعفاء 100% (0%).
        """
        parsed = parse_smart_nafeza_tariff_text_service(RAW_NAFEZA_TEXT_EXAMPLE)
        save_tariff_with_agreements_service(
            db_session,
            TariffAgreementBulkSaveRequest(
                tariff=parsed.tariff_data,
                agreements=parsed.agreements,
            )
        )

        res = evaluate_duty_by_origin_and_document_service(
            db_session,
            OriginDutyCheckRequest(
                hs_code="3925900090",
                origin_country="TR",
                has_preferential_document=True,
            )
        )

        assert res.base_duty_rate == Decimal("40.00")
        assert res.effective_duty_rate == Decimal("0.00")
        assert res.has_matching_agreement is True
        assert res.document_verified is True
        assert "Turkey" in res.applied_agreement_name or "تركيا" in res.applied_agreement_name

    def test_origin_duty_check_agreement_country_without_document(self, db_session):
        """
        إذا كانت الدولة مرتبطة باتفاقية (مثل تركيا TR) ولم يُرفع المستند: العودة للضريبة الأساسية 40% وتوليد تحذير.
        """
        parsed = parse_smart_nafeza_tariff_text_service(RAW_NAFEZA_TEXT_EXAMPLE)
        save_tariff_with_agreements_service(
            db_session,
            TariffAgreementBulkSaveRequest(
                tariff=parsed.tariff_data,
                agreements=parsed.agreements,
            )
        )

        res = evaluate_duty_by_origin_and_document_service(
            db_session,
            OriginDutyCheckRequest(
                hs_code="3925900090",
                origin_country="TR",
                has_preferential_document=False,
            )
        )

        assert res.base_duty_rate == Decimal("40.00")
        assert res.effective_duty_rate == Decimal("40.00")
        assert res.has_matching_agreement is True
        assert res.document_verified is False
        assert res.warning_note is not None
        assert "EUR.1" in res.warning_note

    def test_origin_duty_check_mercosur_fixed_rate(self, db_session):
        """
        اختبار اتفاقية الميركسور (البرازيل BR) وتطبيق الفئة الفتفضيلية المباشرة 3.00%.
        """
        parsed = parse_smart_nafeza_tariff_text_service(RAW_NAFEZA_TEXT_EXAMPLE)
        save_tariff_with_agreements_service(
            db_session,
            TariffAgreementBulkSaveRequest(
                tariff=parsed.tariff_data,
                agreements=parsed.agreements,
            )
        )

        res = evaluate_duty_by_origin_and_document_service(
            db_session,
            OriginDutyCheckRequest(
                hs_code="3925900090",
                origin_country="BR",
                has_preferential_document=True,
            )
        )

        assert res.base_duty_rate == Decimal("40.00")
        assert res.effective_duty_rate == Decimal("3.00")
        assert res.document_verified is True

    def test_tariff_historical_versioning_and_diff(self, db_session):
        """
        اختبار إضافة تحديث جديد لنفس البند:
        1. حفظ النسخة الأولى المطبقة.
        2. حفظ النسخة الجديدة بتغيير منشور تركيا من ر6607 (100%) إلى ر6617 (50%).
        3. التأكد من حفظ النسخة القديمة مع تاريخ انتهاء سريان عدم حذفها.
        4. التحقق من كروت المقارنة (added, removed, modified).
        """
        # 1. Save original tariff version
        parsed1 = parse_smart_nafeza_tariff_text_service(RAW_NAFEZA_TEXT_EXAMPLE, db=db_session)
        save_tariff_with_agreements_service(
            db_session,
            TariffAgreementBulkSaveRequest(
                tariff=parsed1.tariff_data,
                agreements=parsed1.agreements,
            )
        )

        # 2. Updated Nafeza Text with Turkey publication changed from ر6607 to ر6617 (50% discount)
        updated_text = """رقم البند :
3925900090
نص البند :
أصناف أخر لتجهيزات البناء من لدائن ، غير مذكورة أو داخلة في مكان أخر .
الضرائب :
ضريبة الوارد (النظام الاساسي) :
40.000 %
ضريبة الوارد (اتفاقية أمريكا اللاتينية الميركسور) :
3.000 %
ضريبة قيمه مضافه :
14.000 %
المستندات والأعمال :
ر6722 - اتفاقية صربيا تخفيض 10%
ر6668 - تخفض ض .ج ورسوم بنسبة100%علىسلع صناعيةواردةفى ظل اتفاقية الشراكةالمصرية والمملكة المتحدة
ر6706 - تحصل ض. وارد طبقا للفئات الموضحة قرين كل بند على سلع واردة فى إطار إتفاقيةالميركسور
ر6631 - يعفى من الضريبة الجمركية والرسوم ذات الاثر المماثل الأصناف الواردة من دول الافتا بنسبة100%
ر6617 - تخفض الرسوم الجمركية فى ظل اتفاقيةتركيا بنسبة50% على اصناف واردةبالقائمة 1 برتوكول 1
ر6663 - تخفض ضريبةجمركيةورسوم ذات أثر مماثل بنسبة 100% علىسلع صناعيةواردةفى ظل شراكةأوربيةملحق2"""

        # 3. Parse updated text and verify comparison diff
        parsed2 = parse_smart_nafeza_tariff_text_service(updated_text, db=db_session)
        comp = parsed2.comparison
        assert comp is not None
        assert comp.has_previous_version is True
        assert comp.added_count == 1  # ر6617 added
        assert comp.removed_count == 1  # ر6607 removed

        added_item = next(it for it in comp.diff_items if it.change_type == "added")
        assert added_item.publication_notice == "ر6617"
        assert added_item.color_code == "#27AE60"

        removed_item = next(it for it in comp.diff_items if it.change_type == "removed")
        assert removed_item.publication_notice == "ر6607"
        assert removed_item.color_code == "#C0392B"

        # 4. Save updated version into DB with effective update date tomorrow
        from datetime import timedelta
        next_day = date.today() + timedelta(days=1)
        save_tariff_with_agreements_service(
            db_session,
            TariffAgreementBulkSaveRequest(
                tariff=parsed2.tariff_data,
                agreements=parsed2.agreements,
                update_date=next_day,
            )
        )

        # 5. Query all versions from DB to verify historical retention
        from modules.customs_tariff.repository import get_all_tariff_versions_by_hs_code
        versions = get_all_tariff_versions_by_hs_code(db_session, "3925900090")
        assert len(versions) == 2  # Old version and new version both retained!

        old_ver = next(v for v in versions if not v.is_active)
        new_ver = next(v for v in versions if v.is_active)

        assert old_ver.effective_to == next_day
        assert new_ver.effective_from == next_day
        assert new_ver.effective_to is None

    def test_parse_user_provided_air_conditioner_tariff(self, db_session):
        """
        اختبار صريح لتحليل النص الكامل المقدم من المستخدم (أجهزة تكييف HS: 8415820010)
        مع ضريبة الوارد 60%، ضريبة الجدول 8%، القيمة المضافة 14%، 6 اشتراطات رقابية، و8 اتفاقيات تفضيلية.
        """
        raw_user_text = """رقم البند :
8415820010
نص البند :
آلات وأجهزة تكييف أخر متضمنة وحدة تبريد ، وحدات كاملة .
الضرائب :
ضريبة الوارد :
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

ر6704 - فى ظل اتفاق التجارة الحرة بين ج م ع وتجمع الميركسور تخفض الضريبة الجمركية - قائمة هـ

ر7042 - يحصل ضريبة قيمة مضافة بمقدار14% [عام]

ر6607 - تخفض الرسوم الجمركية فى ظل اتفاقيةتركيا بنسبة100% على اصناف واردةبالقائمة 1 برتوكول 1

ر6631 - يعفى من الضريبة الجمركية والرسوم ذات الاثر المماثل الأصناف الواردة من دول الافتا بنسبة100%

ق4547 - يشترط للافراج عن الصنف وارد اتجار أن يكون انتاج مصانع مسجلة من شركات مالكة للعلامة

ق4538 - عدامايرداستخدام خاص وشخصى يشترط للافراج عن الصنف أن يكون من أحد منتجين بـ هـ.ع.ص.و

ر6663 - تخفض ضريبةجمركيةورسوم ذات أثر مماثل بنسبة 100% علىسلع صناعيةواردةفى ظل شراكةأوربيةملحق2

ق4010 - لا يتم استيراد المواد المستنفذه لطبقه الاوزون الابموافقة مسبقة من شئون البيئة

ر6501 - تحصل ضريبة الوارد 20% على ما تستورده المنشآت الفندقيةوالسياحية أو ضريبة الوارد أيهما أقل.

ق9023 - الصنف مخصص للاستعمال كقطع غيار اولـــوازم للسيـــارات اضافة 333-بورسعيد-"""

        tariff, agreements = parse_nafeza_tariff_text(raw_user_text)

        assert tariff.hs_code == "8415820010"
        assert tariff.customs_duty_rate == Decimal("60.00")
        assert tariff.schedule_tax_rate == Decimal("8.00")
        assert tariff.vat_rate == Decimal("14.00")
        assert tariff.requires_inspection is True
        assert "GOEIC" in tariff.regulatory_authority
        assert "EEAA" in tariff.regulatory_authority
        assert "ق4518" in tariff.prior_approval_note
        assert "ق4010" in tariff.prior_approval_note

        assert len(agreements) == 8

        # Verify bulk saving to SQLite
        res = save_tariff_with_agreements_service(
            db_session,
            TariffAgreementBulkSaveRequest(
                tariff=tariff,
                agreements=agreements,
            )
        )
        assert res["tariff"].hs_code == "8415820010"
        assert res["tariff"].schedule_tax_rate == Decimal("8.00")
        assert len(res["agreements"]) == 8

    def test_save_tariff_with_agreements_audit_failure_rolls_back(self, db_session, monkeypatch):
        """
        اختبار التحقق من الذرية (Atomicity): إذا فشل تسجيل Audit Log قبل الـ commit،
        يتم التراجع (Rollback) ولا يتم حفظ البند الجمركي أو أي من اتفاقياته في قاعدة البيانات.
        """
        from modules.audit_logs.service import AuditLogService

        parsed = parse_smart_nafeza_tariff_text_service(RAW_NAFEZA_TEXT_EXAMPLE)
        hs = parsed.tariff_data.hs_code

        def mock_log_activity(*args, **kwargs):
            raise RuntimeError("Simulated AuditLogService database failure")

        monkeypatch.setattr(AuditLogService, "log_activity", mock_log_activity)

        with pytest.raises(RuntimeError, match="Simulated AuditLogService database failure"):
            save_tariff_with_agreements_service(
                db_session,
                TariffAgreementBulkSaveRequest(
                    tariff=parsed.tariff_data,
                    agreements=parsed.agreements,
                ),
            )

        db_session.rollback()

        # Verify nothing was persisted
        from modules.customs_tariff.model import CustomsTariff, PreferentialAgreement
        saved_tariff = db_session.query(CustomsTariff).filter(CustomsTariff.hs_code == hs).first()
        assert saved_tariff is None

        saved_agreements = db_session.query(PreferentialAgreement).filter(PreferentialAgreement.hs_code == hs).all()
        assert len(saved_agreements) == 0

