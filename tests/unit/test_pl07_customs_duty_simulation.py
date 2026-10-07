"""
Unit Tests for PL-07: Customs Duty Simulation (المحاكاة الجمركية واحتساب الرسوم والضرائب التقديرية)
Covers Egyptian Customs Calculation Engine rules, CIF bases, VAT base equation (CIF + Duty),
preferential trade agreements (EUR.1 / Mercosur), multi-item Nafeza statement precision,
end-to-end ImportFile simulation, and strict database constraints.
"""

from datetime import date, timedelta
from decimal import Decimal
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.incoterms.model import Incoterm
from modules.currencies.model import Currency, ExchangeRate
from modules.currencies.service import clear_currency_cache
from modules.projects.model import Project
from modules.import_files.model import ImportFile
from modules.purchase_orders.model import PurchaseOrder, POLineItem
from modules.customs_tariff.model import CustomsTariff, PreferentialAgreement, FeeCode
from modules.customs_tariff.schemas import (
    CustomsDutyEstimateRequest,
    CustomsTariffCreate,
    MultiItemCustomsEstimateLine,
    MultiItemCustomsEstimateRequest,
    OriginDutyCheckRequest,
    PreferentialAgreementCreate,
    ImportFileCustomsSimulationRequest,
)
from modules.customs_tariff.service import (
    create_tariff_service,
    create_preferential_agreement_service,
    estimate_customs_duty_service,
    estimate_multi_item_customs_duty_service,
    evaluate_duty_by_origin_and_document_service,
    simulate_import_file_customs_duty_service,
)
from modules.customs_consultation.model import CustomsConsultationSession


@pytest.fixture
def db_session():
    clear_currency_cache()
    test_engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=test_engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)
    db = TestingSessionLocal()

    # Seed official Fee Codes
    fc1 = FeeCode(
        code="390",
        name_ar="خدمات جمركية",
        collection_group="رسوم النافذة الموحدة",
        calculation_type="flat",
        flat_amount=Decimal("1081.00"),
        is_active=True,
    )
    fc2 = FeeCode(
        code="392",
        name_ar="خدمات معلوماتية",
        collection_group="رسوم النافذة الموحدة",
        calculation_type="flat",
        flat_amount=Decimal("3457.00"),
        is_active=True,
    )
    fc3 = FeeCode(
        code="394",
        name_ar="ضريبة قيمة مضافة نافذة",
        collection_group="رسوم النافذة الموحدة",
        calculation_type="derived",
        derived_formula_rate=Decimal("14.00"),
        derived_formula_base_codes="390,392",
        is_active=True,
    )
    db.add_all([fc1, fc2, fc3])

    # Seed Currencies & Customs Exchange Rate
    c_usd = Currency(
        currency_code="USD",
        currency_name="US Dollar",
        currency_symbol="$",
        is_active=True,
    )
    db.add(c_usd)
    db.flush()

    rate_usd = ExchangeRate(
        currency_id=c_usd.currency_id,
        effective_date=date.today(),
        customs_rate=Decimal("50.0000"),
        commercial_rate=Decimal("50.0000"),
        is_active=True,
    )
    db.add(rate_usd)

    # Seed Master Data
    comp = ImportCompany(
        importer_name="شركة سرور اللوجستية للاستيراد",
        address="الإسكندرية، مصر",
        country="Egypt",
        importer_id="IMP-EG-100",
        importer_id_expiry=date.today() + timedelta(days=180),
        vat_id="VAT-EG-200",
        vat_id_expiry=date.today() + timedelta(days=180),
        registration_number="CR-EG-300",
        registration_expiry=date.today() + timedelta(days=180),
        phone="+2010000000",
        email="info@sorour.com",
        is_active=True,
    )
    sup = Supplier(
        supplier_code="SUP-DE-001",
        company_name="Siemens Industrial Automation GmbH",
        supplier_type="Manufacturer",
        registration_type="Commercial Registry",
        foreign_exporter_id="EX-DE-881",
        foreign_exporter_country="Germany",
        foreign_exporter_country_code="DE",
        address="Munich, Germany",
        phone="+498912345",
        email="export@siemens.de",
        is_active=True,
    )
    inco = Incoterm(incoterm_code="FOB", incoterm_name="Free On Board", is_active=True)
    db.add_all([comp, sup, inco])
    db.commit()

    try:
        yield db
    finally:
        clear_currency_cache()
        db.close()
        Base.metadata.drop_all(bind=test_engine)


class TestPL07CustomsDutySimulation:
    """
    Test Suite for PL-07: Customs Duty Simulation (المحاكاة الجمركية واحتساب الرسوم والضرائب التقديرية).
    """

    def test_single_item_customs_duty_estimation_with_vat_base(self, db_session):
        """
        Test 1: Single item duty estimation verifying CIF bases, VAT base (CIF + Duty),
        Schedule tax, Development fee, and non-exempted Customs Service Fee (1%).
        """
        create_tariff_service(
            db_session,
            CustomsTariffCreate(
                hs_code="8415.82.00",
                hs_description="Air conditioning machines",
                customs_duty_rate=Decimal("10.00"),
                vat_rate=Decimal("14.00"),
                schedule_tax_rate=Decimal("5.00"),
                development_fee_rate=Decimal("2.00"),
                import_fee_rate=Decimal("0.00"),
                customs_service_fee_rate=Decimal("1.00"),
                requires_coo=True,
                requires_inspection=True,
                requires_acid=True,
                regulatory_authority="GOEIC",
            ),
        )

        req = CustomsDutyEstimateRequest(
            hs_code="8415.82.00",
            cif_value=Decimal("100000.00"),
            freight=Decimal("10000.00"),
            packaging_egp=Decimal("0.00"),
        )

        breakdown = estimate_customs_duty_service(db_session, req)

        # Assertions
        assert breakdown.hs_code == "8415.82.00"
        assert breakdown.cif_value == Decimal("100000.00")
        assert breakdown.customs_duty_rate == Decimal("10.00")
        assert breakdown.import_duty_amount == Decimal("10000.00")  # 100,000 * 10%

        # Crucial Egyptian Law: VAT Base = CIF + Import Duty
        assert breakdown.vat_base == Decimal("110000.00")  # 100,000 + 10,000
        assert breakdown.vat_amount == Decimal("15400.00")  # 110,000 * 14%

        # Schedule Tax = CIF * 5%
        assert breakdown.schedule_tax_amount == Decimal("5000.00")

        # Development Fee = CIF * 2%
        assert breakdown.development_fee_amount == Decimal("2000.00")

        # Customs Service Fee (أ.ت.ص) = CIF * 1%
        assert breakdown.customs_service_fee_amount == Decimal("1000.00")

        # Total = 10,000 + 15,400 + 5,000 + 2,000 + 1,000 = 33,400.00
        assert breakdown.total_taxes_and_fees == Decimal("33400.00")

    def test_preferential_agreement_eur1_duty_exemption(self, db_session):
        """
        Test 2: Preferential Trade Agreement (EUR.1):
        Full duty exemption (0% duty) applied to goods of European origin (DE),
        while Customs Service Fee (1%) and Schedule Tax strictly remain payable.
        """
        create_tariff_service(
            db_session,
            CustomsTariffCreate(
                hs_code="8421.23.00",
                hs_description="Oil or petrol-filters for internal combustion engines",
                customs_duty_rate=Decimal("20.00"),
                vat_rate=Decimal("14.00"),
                schedule_tax_rate=Decimal("5.00"),
                customs_service_fee_rate=Decimal("1.00"),
            ),
        )

        # Register EU Partnership Agreement
        create_preferential_agreement_service(
            db_session,
            PreferentialAgreementCreate(
                hs_code="8421.23.00",
                agreement_name="اتفاقية الشراكة المصرية الأوروبية (EUR.1)",
                reduction_type="full_duty_exemption",
                reduction_percentage=Decimal("1.00"),
                preferential_duty_rate=Decimal("0.00"),
                publication_notice="ر6663",
                required_document="شهادة منشأ تفضيلية EUR.1",
                origin_countries="DE,FR,IT,ES",
            ),
        )

        req = CustomsDutyEstimateRequest(
            hs_code="8421.23.00",
            cif_value=Decimal("200000.00"),
            origin_country="DE",
        )

        breakdown = estimate_customs_duty_service(db_session, req)

        # Duty is reduced to 0.00% under EUR.1
        assert breakdown.customs_duty_rate == Decimal("0.00")
        assert breakdown.import_duty_amount == Decimal("0.00")
        assert breakdown.trade_agreement_applied == "اتفاقية الشراكة المصرية الأوروبية (EUR.1)"

        # VAT Base with 0 duty = CIF = 200,000
        assert breakdown.vat_base == Decimal("200000.00")
        assert breakdown.vat_amount == Decimal("28000.00")  # 200,000 * 14%

        # Customs Service Fee (1%) is NOT exempted by trade agreements!
        assert breakdown.customs_service_fee_amount == Decimal("2000.00")  # 200,000 * 1%

        # Schedule Tax is NOT exempted by trade agreements!
        assert breakdown.schedule_tax_amount == Decimal("10000.00")  # 200,000 * 5%

        # Total = 0 + 28,000 + 10,000 + 2,000 = 40,000.00
        assert breakdown.total_taxes_and_fees == Decimal("40000.00")

    def test_multi_item_nafeza_official_statement_precision(self, db_session):
        """
        Test 3: Multi-Item Nafeza statement calculation verifying proportional CIF allocation,
        statutory deemed insurance (2.5%) and deemed freight (2.0%), and fee codes collection.
        """
        create_tariff_service(
            db_session,
            CustomsTariffCreate(
                hs_code="8504.40.10",
                hs_description="Uninterruptible power supplies (UPS)",
                customs_duty_rate=Decimal("5.00"),
                vat_rate=Decimal("14.00"),
                schedule_tax_rate=Decimal("0.00"),
                customs_service_fee_rate=Decimal("1.00"),
            ),
        )
        create_tariff_service(
            db_session,
            CustomsTariffCreate(
                hs_code="8504.40.90",
                hs_description="Other static converters",
                customs_duty_rate=Decimal("10.00"),
                vat_rate=Decimal("14.00"),
                schedule_tax_rate=Decimal("0.00"),
                customs_service_fee_rate=Decimal("1.00"),
            ),
        )

        # Deemed insurance (2.5%) and deemed freight (2.0%) test:
        # Invoice = 10,000 USD @ 50.0 = 500,000 EGP FOB
        # Deemed Insurance = 500,000 * 2.5% = 12,500 EGP
        # Deemed Freight = 500,000 * 2.0% = 10,000 EGP
        # Total CIF = 500,000 + 12,500 + 10,000 = 522,500 EGP
        req = MultiItemCustomsEstimateRequest(
            currency="USD",
            exchange_rate=Decimal("50.00"),
            insurance_egp=Decimal("0.00"),
            freight_egp=Decimal("0.00"),
            has_insurance_document=False,  # Triggers deemed 2.5%
            has_freight_document=False,    # Triggers deemed 2.0%
            lines=[
                MultiItemCustomsEstimateLine(
                    line_no=1,
                    hs_code="8504.40.10",
                    value_fc=Decimal("4000.00"),  # 40% share
                    qty=Decimal("4"),
                ),
                MultiItemCustomsEstimateLine(
                    line_no=2,
                    hs_code="8504.40.90",
                    value_fc=Decimal("6000.00"),  # 60% share
                    qty=Decimal("6"),
                ),
            ],
        )

        res = estimate_multi_item_customs_duty_service(db_session, req)

        assert res.fob_value_egp == Decimal("500000.00")
        assert res.insurance_source == "deemed"
        assert res.freight_source == "deemed"
        assert res.insurance_egp == Decimal("12500.00")
        assert res.freight_egp == Decimal("10000.00")

        # Line 1: 40% CIF = 522,500 * 40% = 209,000 EGP
        l1 = res.lines[0]
        assert l1.cif_value_egp == Decimal("209000.00")
        assert l1.customs_duty_rate == Decimal("5.00")
        assert l1.duty_egp == Decimal("10450.00")  # 209,000 * 5%
        assert l1.vat_base_egp == Decimal("219450.00")  # 209,000 + 10,450
        assert l1.vat_egp == Decimal("30723.00")  # 219,450 * 14%
        assert l1.customs_service_fee_egp == Decimal("2090.00")  # 209,000 * 1%

        # Line 2: 60% CIF = 522,500 * 60% = 313,500 EGP
        l2 = res.lines[1]
        assert l2.cif_value_egp == Decimal("313500.00")
        assert l2.customs_duty_rate == Decimal("10.00")
        assert l2.duty_egp == Decimal("31350.00")  # 313,500 * 10%
        assert l2.vat_base_egp == Decimal("344850.00")  # 313,500 + 31,350
        assert l2.vat_egp == Decimal("48279.00")  # 344,850 * 14%
        assert l2.customs_service_fee_egp == Decimal("3135.00")  # 313,500 * 1%

        assert res.items_taxes_total_egp == (
            l1.duty_egp + l1.vat_egp + l1.customs_service_fee_egp +
            l2.duty_egp + l2.vat_egp + l2.customs_service_fee_egp
        )
        assert res.fee_codes_breakdown is not None
        assert "grand_total" in res.fee_codes_breakdown

    def test_origin_duty_and_document_verification(self, db_session):
        """
        Test 4: Origin Duty & Document Check Engine:
        Verifies required EUR.1 note and conditional duty rate based on certificate confirmation.
        """
        create_tariff_service(
            db_session,
            CustomsTariffCreate(
                hs_code="8471.49.00",
                hs_description="Digital processing units",
                customs_duty_rate=Decimal("15.00"),
                vat_rate=Decimal("14.00"),
            ),
        )
        create_preferential_agreement_service(
            db_session,
            PreferentialAgreementCreate(
                hs_code="8471.49.00",
                agreement_name="اتفاقية الشراكة المصرية الأوروبية (EUR.1)",
                reduction_type="full_duty_exemption",
                reduction_percentage=Decimal("1.00"),
                publication_notice="ر6663",
                required_document="شهادة منشأ تفضيلية EUR.1",
                origin_countries="DE,IT",
            ),
        )

        # Scenario A: Origin without document -> base duty 15% with warning
        res_no_doc = evaluate_duty_by_origin_and_document_service(
            db_session,
            OriginDutyCheckRequest(
                hs_code="8471.49.00",
                origin_country="DE",
                has_preferential_document=False,
            ),
        )
        assert res_no_doc.base_duty_rate == Decimal("15.00")
        assert res_no_doc.effective_duty_rate == Decimal("15.00")
        assert res_no_doc.document_verified is False
        assert res_no_doc.has_matching_agreement is True
        assert res_no_doc.warning_note is not None
        assert "EUR.1" in res_no_doc.warning_note

        # Scenario B: Origin with confirmed document -> reduced 0% duty
        res_doc = evaluate_duty_by_origin_and_document_service(
            db_session,
            OriginDutyCheckRequest(
                hs_code="8471.49.00",
                origin_country="DE",
                has_preferential_document=True,
            ),
        )
        assert res_doc.effective_duty_rate == Decimal("0.00")
        assert res_doc.document_verified is True
        assert res_doc.warning_note is None

    def test_simulate_import_file_customs_duties_end_to_end(self, db_session):
        """
        Test 5: End-to-end ImportFile customs simulation:
        Pulls line items from linked Purchase Order, applies exchange rate,
        calculates taxes, and automatically registers or updates CustomsConsultationSession.
        """
        tariff = create_tariff_service(
            db_session,
            CustomsTariffCreate(
                hs_code="8431.49.00",
                hs_description="Parts of machinery",
                customs_duty_rate=Decimal("5.00"),
                vat_rate=Decimal("14.00"),
                schedule_tax_rate=Decimal("0.00"),
                customs_service_fee_rate=Decimal("1.00"),
                requires_acid=True,
                requires_coo=True,
                requires_inspection=True,
            ),
        )

        # Create Project & ImportFile
        proj = Project(
            project_code="PRJ-PL07-01",
            project_name="Machinery Spares Project",
            project_owner="Eng. Tarek",
            company_id=1,
            supplier_id=1,
            incoterm_id=1,
            is_active=True,
        )
        db_session.add(proj)
        db_session.flush()

        imp_file = ImportFile(
            import_file_code="IMP-2026-PL07",
            company_id=1,
            company_name="شركة سرور اللوجستية",
            supplier_id=1,
            supplier_name="Siemens Industrial Automation GmbH",
            broker_id=1,
            broker_name="Approved Customs Broker",
            status="In Progress",
            is_active=True,
        )
        db_session.add(imp_file)
        db_session.flush()

        # Create linked Purchase Order with line item
        po = PurchaseOrder(
            po_number="PO-2026-PL07",
            project_id=proj.project_id,
            import_file_id=imp_file.import_file_id,
            company_id=1,
            supplier_id=1,
            incoterm_id=1,
            currency_id=1,
            country_of_origin="CN",
            status="Approved",
            is_active=True,
        )
        db_session.add(po)
        db_session.flush()

        po_item = POLineItem(
            po_id=po.po_id,
            description_ar="Hydraulic Valve Assembly",
            tariff_id=tariff.tariff_id,
            quantity=Decimal("10.00"),
            unit_of_measure="PCS",
            unit_price=Decimal("1000.00"),
            total_price=Decimal("10000.00"),
            country_of_origin="CN",
        )
        db_session.add(po_item)
        db_session.commit()

        # Execute simulation with actual freight
        sim_req = ImportFileCustomsSimulationRequest(
            exchange_rate=Decimal("50.00"),
            freight_egp=Decimal("20000.00"),
            insurance_egp=Decimal("5000.00"),
            save_to_consultation=True,
        )

        sim_res = simulate_import_file_customs_duty_service(db_session, imp_file.import_file_id, sim_req)

        assert sim_res.import_file_id == imp_file.import_file_id
        assert sim_res.import_file_code == "IMP-2026-PL07"
        assert "PO-2026-PL07" in sim_res.po_numbers
        assert sim_res.currency == "USD"
        assert sim_res.breakdown is not None

        # FOB = 10,000 USD * 50 = 500,000 EGP
        # Freight = 20,000, Insurance = 5,000 -> CIF = 525,000 EGP
        assert sim_res.breakdown.fob_value_egp == Decimal("500000.00")
        assert sim_res.breakdown.freight_egp == Decimal("20000.00")
        assert sim_res.breakdown.insurance_egp == Decimal("5000.00")

        # Line: CIF = 525,000 EGP
        # Duty (5%) = 26,250.00 EGP
        # VAT Base = 525,000 + 26,250 = 551,250.00 EGP
        # VAT (14%) = 77,175.00 EGP
        # Service Fee (1%) = 5,250.00 EGP
        assert sim_res.breakdown.total_duty_egp == Decimal("26250.00")
        assert sim_res.breakdown.total_vat_egp == Decimal("77175.00")
        assert sim_res.breakdown.total_customs_service_fee_egp == Decimal("5250.00")

        # Verify Consultation Session was created & synced
        assert sim_res.consultation_id is not None
        consultation = db_session.query(CustomsConsultationSession).filter(
            CustomsConsultationSession.consultation_id == sim_res.consultation_id
        ).first()
        assert consultation is not None
        assert float(sim_res.breakdown.grand_total_payable_egp) == pytest.approx(consultation.estimated_duties_egp, 0.01)

        # Checklists automatically populated
        checklist_types = [c.document_type for c in consultation.checklist_items]
        assert any("ACID" in t for t in checklist_types)
        assert any("COO" in t or "Origin" in t for t in checklist_types)
        assert any("GOEIC" in t or "Inspection" in t for t in checklist_types)

    def test_customs_tariff_strict_missing_hs_code_validation(self, db_session):
        """
        Test 6: Strict HS Code validation:
        Engine MUST fail loudly with 422 Unprocessable Entity if HS Code is not in database,
        prohibiting assumption of fallback/guesswork tax rates.
        """
        req = CustomsDutyEstimateRequest(
            hs_code="9999.99.99",
            cif_value=Decimal("50000.00"),
        )
        with pytest.raises(HTTPException) as exc_info:
            estimate_customs_duty_service(db_session, req)

        assert exc_info.value.status_code == 422
        assert "لا يوجد بند تعريفة فعّال" in exc_info.value.detail

    def test_simulation_multi_currency_per_po_deemed_additions(self, db_session):
        """
        Test 7: Money & multi-currency PO simulation:
        Customs rates USD 50, EUR 55 on estimate date; both HS codes duty 10%, VAT 14%, service fee 1%;
        request freight_egp=0, insurance_egp=0 (deemed path: insurance 2.5%, freight 2% of FOB EGP 105,000 -> 2,625 + 2,100 = 4,725).
        Line 1 (USD 1,000 -> 50,000 EGP, share 50/105): cif_value_egp == 52,250.00, duty_egp == 5,225.00.
        Line 2 (EUR 1,000 -> 55,000 EGP, share 55/105): cif_value_egp == 57,475.00, duty_egp == 5,747.50.
        """
        sim_date = date(2026, 6, 1)

        # Seed EUR currency
        c_eur = Currency(currency_code="EUR", currency_name="Euro", currency_symbol="€", is_active=True)
        db_session.add(c_eur)
        db_session.flush()

        # Seed exchange rates for USD (50) and EUR (55)
        c_usd = db_session.query(Currency).filter(Currency.currency_code == "USD").one()
        usd_rate = ExchangeRate(
            currency_id=c_usd.currency_id,
            effective_date=sim_date,
            customs_rate=Decimal("50.0000"),
            commercial_rate=Decimal("50.0000"),
            is_active=True,
        )
        eur_rate = ExchangeRate(
            currency_id=c_eur.currency_id,
            effective_date=sim_date,
            customs_rate=Decimal("55.0000"),
            commercial_rate=Decimal("55.0000"),
            is_active=True,
        )
        db_session.add_all([usd_rate, eur_rate])

        # Seed two tariffs (both 10% duty, 14% VAT, 1% service fee)
        t1 = create_tariff_service(
            db_session,
            CustomsTariffCreate(
                hs_code="8471.30.00",
                hs_description="Laptops",
                customs_duty_rate=Decimal("10.00"),
                vat_rate=Decimal("14.00"),
                customs_service_fee_rate=Decimal("1.00"),
                effective_from=date(2025, 1, 1),
            ),
        )
        t2 = create_tariff_service(
            db_session,
            CustomsTariffCreate(
                hs_code="8504.40.90",
                hs_description="Power supplies",
                customs_duty_rate=Decimal("10.00"),
                vat_rate=Decimal("14.00"),
                customs_service_fee_rate=Decimal("1.00"),
                effective_from=date(2025, 1, 1),
            ),
        )

        imp_file = ImportFile(
            import_file_code="IMP-2026-MULTI",
            company_id=1,
            company_name="شركة سرور اللوجستية",
            supplier_id=1,
            supplier_name="Siemens Industrial Automation GmbH",
            broker_id=1,
            broker_name="Approved Broker",
            status="In Progress",
            is_active=True,
        )
        db_session.add(imp_file)
        db_session.flush()

        po_usd = PurchaseOrder(
            po_number="PO-2026-USD",
            project_id=1,
            import_file_id=imp_file.import_file_id,
            company_id=1,
            supplier_id=1,
            incoterm_id=1,
            currency_id=c_usd.currency_id,
            status="Approved",
            is_active=True,
        )
        po_eur = PurchaseOrder(
            po_number="PO-2026-EUR",
            project_id=1,
            import_file_id=imp_file.import_file_id,
            company_id=1,
            supplier_id=1,
            incoterm_id=1,
            currency_id=c_eur.currency_id,
            status="Approved",
            is_active=True,
        )
        db_session.add_all([po_usd, po_eur])
        db_session.flush()

        item_usd = POLineItem(
            po_id=po_usd.po_id,
            item_code="LAP-01",
            description_ar="Laptops",
            tariff_id=t1.tariff_id,
            quantity=Decimal("100.00"),
            unit_price=Decimal("10.00"),
            total_price=Decimal("1000.00"),  # 1,000 USD -> 50,000 EGP
        )
        item_eur = POLineItem(
            po_id=po_eur.po_id,
            item_code="PWR-01",
            description_ar="Power supplies",
            tariff_id=t2.tariff_id,
            quantity=Decimal("50.00"),
            unit_price=Decimal("20.00"),
            total_price=Decimal("1000.00"),  # 1,000 EUR -> 55,000 EGP
        )
        db_session.add_all([item_usd, item_eur])
        db_session.commit()

        req = ImportFileCustomsSimulationRequest(
            freight_egp=Decimal("0.00"),
            insurance_egp=Decimal("0.00"),
            estimate_date=sim_date,
        )
        res = simulate_import_file_customs_duty_service(db_session, imp_file.import_file_id, req)

        assert res.breakdown.fob_value_egp == Decimal("105000.00")
        assert res.breakdown.insurance_egp == Decimal("2625.00")
        assert res.breakdown.freight_egp == Decimal("2100.00")
        assert res.breakdown.insurance_source == "deemed"
        assert res.breakdown.freight_source == "deemed"

        # Line 1 (USD 1,000 -> 50,000 EGP)
        l1 = res.breakdown.lines[0]
        assert l1.cif_value_egp == Decimal("52250.00")
        assert l1.duty_egp == Decimal("5225.00")

        # Line 2 (EUR 1,000 -> 55,000 EGP)
        l2 = res.breakdown.lines[1]
        assert l2.cif_value_egp == Decimal("57475.00")
        assert l2.duty_egp == Decimal("5747.50")
        assert res.currency == "EGP"

    def test_simulation_line_without_hs_appended_to_skipped_lines(self, db_session):
        """
        Test 8: Line without HS is not priced at 8479.89.90; listed in skipped_lines.
        """
        tariff = create_tariff_service(
            db_session,
            CustomsTariffCreate(
                hs_code="8471.30.00",
                hs_description="Laptops",
                customs_duty_rate=Decimal("5.00"),
                vat_rate=Decimal("14.00"),
            ),
        )

        imp_file = ImportFile(
            import_file_code="IMP-2026-SKIPPED",
            company_id=1,
            company_name="شركة سرور اللوجستية",
            supplier_id=1,
            supplier_name="Siemens Industrial Automation GmbH",
            broker_id=1,
            broker_name="Approved Broker",
            status="In Progress",
            is_active=True,
        )
        db_session.add(imp_file)
        db_session.flush()

        po = PurchaseOrder(
            po_number="PO-2026-SKIPPED",
            project_id=1,
            import_file_id=imp_file.import_file_id,
            company_id=1,
            supplier_id=1,
            incoterm_id=1,
            currency_id=1,
            status="Approved",
            is_active=True,
        )
        db_session.add(po)
        db_session.flush()

        # Item 1 with valid tariff
        item1 = POLineItem(
            po_id=po.po_id,
            item_code="GOOD-ITEM",
            description_ar="Laptops",
            tariff_id=tariff.tariff_id,
            quantity=Decimal("5.00"),
            unit_price=Decimal("100.00"),
            total_price=Decimal("500.00"),
        )
        # Item 2 with NO tariff and NO hs_code
        item2 = POLineItem(
            po_id=po.po_id,
            item_code="NO-HS-ITEM",
            description_ar="Mystery goods",
            tariff_id=None,
            quantity=Decimal("5.00"),
            unit_price=Decimal("100.00"),
            total_price=Decimal("500.00"),
        )
        db_session.add_all([item1, item2])
        db_session.commit()

        req = ImportFileCustomsSimulationRequest(
            exchange_rate=Decimal("50.00"),
            freight_egp=Decimal("1000.00"),
            insurance_egp=Decimal("500.00"),
        )
        res = simulate_import_file_customs_duty_service(db_session, imp_file.import_file_id, req)

        # Only item 1 is estimated
        assert len(res.breakdown.lines) == 1
        assert res.breakdown.lines[0].hs_code == "8471.30.00"
        # Item 2 is in skipped_lines with reason NO_HS
        assert len(res.skipped_lines) == 1
        assert res.skipped_lines[0]["po_number"] == "PO-2026-SKIPPED"
        assert res.skipped_lines[0]["item_code"] == "NO-HS-ITEM"
        assert res.skipped_lines[0]["reason"] == "NO_HS"

    def test_simulation_no_usable_lines_raises_422(self, db_session):
        """
        Test 9: When no lines have HS and positive value -> raises 422 CT_SIMULATION_NO_LINES.
        """
        imp_file = ImportFile(
            import_file_code="IMP-2026-EMPTY",
            company_id=1,
            company_name="شركة سرور اللوجستية",
            supplier_id=1,
            supplier_name="Siemens Industrial Automation GmbH",
            broker_id=1,
            broker_name="Approved Broker",
            status="In Progress",
            is_active=True,
        )
        db_session.add(imp_file)
        db_session.flush()

        po = PurchaseOrder(
            po_number="PO-2026-EMPTY",
            project_id=1,
            import_file_id=imp_file.import_file_id,
            company_id=1,
            supplier_id=1,
            incoterm_id=1,
            currency_id=1,
            status="Approved",
            is_active=True,
        )
        db_session.add(po)
        db_session.flush()

        # Item with no HS and 0 price
        item = POLineItem(
            po_id=po.po_id,
            item_code="NO-HS",
            description_ar="Empty item",
            tariff_id=None,
            quantity=Decimal("0.00"),
            unit_price=Decimal("0.00"),
            total_price=Decimal("0.00"),
        )
        db_session.add(item)
        db_session.commit()

        req = ImportFileCustomsSimulationRequest()
        with pytest.raises(HTTPException) as exc_info:
            simulate_import_file_customs_duty_service(db_session, imp_file.import_file_id, req)

        assert exc_info.value.status_code == 422
        assert exc_info.value.detail["code"] == "CT_SIMULATION_NO_LINES"
        assert "لا توجد أصناف بها بند جمركي وقيمة" in exc_info.value.detail["message"]

    def test_simulation_no_broker_leaves_consultation_none_and_warns(self, db_session):
        """
        Test 10: When no consultation exists and import_file has no broker_id,
        consultation_id is None and warning CT_SIMULATION_NO_BROKER is returned.
        """
        tariff = create_tariff_service(
            db_session,
            CustomsTariffCreate(
                hs_code="8471.30.00",
                hs_description="Laptops",
                customs_duty_rate=Decimal("5.00"),
                vat_rate=Decimal("14.00"),
            ),
        )

        imp_file = ImportFile(
            import_file_code="IMP-2026-NO-BROKER",
            company_id=1,
            company_name="شركة سرور اللوجستية",
            supplier_id=1,
            supplier_name="Siemens Industrial Automation GmbH",
            broker_id=None,  # No broker!
            broker_name=None,
            status="In Progress",
            is_active=True,
        )
        db_session.add(imp_file)
        db_session.flush()

        po = PurchaseOrder(
            po_number="PO-2026-NO-BROKER",
            project_id=1,
            import_file_id=imp_file.import_file_id,
            company_id=1,
            supplier_id=1,
            incoterm_id=1,
            currency_id=1,
            status="Approved",
            is_active=True,
        )
        db_session.add(po)
        db_session.flush()

        item = POLineItem(
            po_id=po.po_id,
            item_code="LAP-01",
            description_ar="Laptops",
            tariff_id=tariff.tariff_id,
            quantity=Decimal("10.00"),
            unit_price=Decimal("100.00"),
            total_price=Decimal("1000.00"),
        )
        db_session.add(item)
        db_session.commit()

        req = ImportFileCustomsSimulationRequest(
            exchange_rate=Decimal("50.00"),
            freight_egp=Decimal("2000.00"),
            insurance_egp=Decimal("1000.00"),
            save_to_consultation=True,
        )
        res = simulate_import_file_customs_duty_service(db_session, imp_file.import_file_id, req)

        assert res.consultation_id is None
        assert "CT_SIMULATION_NO_BROKER" in res.warnings

