from datetime import date
from decimal import Decimal
import unittest

from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.customs_tariff.schemas import (
    CustomsDutyEstimateRequest,
    CustomsTariffCreate,
    CustomsTariffUpdate,
)
from modules.customs_tariff.service import (
    create_tariff_service,
    delete_tariff_service,
    estimate_customs_duty_service,
    get_all_tariffs_service,
    get_tariff_by_hs_code_service,
    get_tariff_by_id_service,
    restore_tariff_service,
    update_tariff_service,
)
from modules.customs_tariff.validators import (
    validate_effective_date_range,
    validate_no_duplicate_hs_code,
)


class TestCustomsTariffBackend(unittest.TestCase):

    def setUp(self):
        self.engine = create_engine(
            "sqlite:///:memory:", connect_args={"check_same_thread": False}
        )
        TestingSessionLocal = sessionmaker(
            autocommit=False, autoflush=False, bind=self.engine
        )
        Base.metadata.create_all(bind=self.engine)
        self.db = TestingSessionLocal()

    def tearDown(self):
        self.db.close()
        Base.metadata.drop_all(bind=self.engine)

    # ==================================================
    # CRUD Tests
    # ==================================================

    def test_create_tariff(self):
        data = CustomsTariffCreate(
            hs_code="8471.30.00",
            hs_description="Laptops and notebook computers",
            customs_category="Electronics",
            customs_duty_rate=Decimal("5.00"),
            vat_rate=Decimal("14.00"),
            development_fee_rate=Decimal("5.00"),
            requires_coo=True,
            requires_inspection=True,
            requires_acid=True,
            regulatory_authority="NTRA",
        )
        tariff = create_tariff_service(self.db, data)
        self.assertEqual(tariff.hs_code, "8471.30.00")
        self.assertEqual(tariff.customs_duty_rate, Decimal("5.00"))
        self.assertEqual(tariff.vat_rate, Decimal("14.00"))
        self.assertTrue(tariff.is_active)

    def test_duplicate_hs_code_raises_error(self):
        data = CustomsTariffCreate(
            hs_code="8471.30.00",
            hs_description="Laptops",
            customs_duty_rate=Decimal("5.00"),
            vat_rate=Decimal("14.00"),
        )
        create_tariff_service(self.db, data)
        with self.assertRaises(ValueError):
            create_tariff_service(self.db, data)

    def test_invalid_date_range_raises_error(self):
        with self.assertRaises(ValueError):
            CustomsTariffCreate(
                hs_code="8471.30.00",
                hs_description="Laptops",
                customs_duty_rate=Decimal("5.00"),
                vat_rate=Decimal("14.00"),
                effective_from=date(2024, 6, 1),
                effective_to=date(2024, 1, 1),
            )

    def test_update_tariff(self):
        data = CustomsTariffCreate(
            hs_code="8471.30.00",
            hs_description="Laptops",
            customs_duty_rate=Decimal("5.00"),
            vat_rate=Decimal("14.00"),
        )
        tariff = create_tariff_service(self.db, data)

        update_data = CustomsTariffUpdate(
            customs_duty_rate=Decimal("10.00"),
            hs_description="Updated description",
        )
        updated = update_tariff_service(self.db, tariff.tariff_id, update_data)
        self.assertEqual(updated.customs_duty_rate, Decimal("10.00"))
        self.assertEqual(updated.hs_description, "Updated description")

    def test_soft_delete_and_restore_tariff(self):
        data = CustomsTariffCreate(
            hs_code="8471.30.00",
            hs_description="Laptops",
            customs_duty_rate=Decimal("5.00"),
            vat_rate=Decimal("14.00"),
        )
        tariff = create_tariff_service(self.db, data)

        deleted = delete_tariff_service(self.db, tariff.tariff_id)
        self.assertFalse(deleted.is_active)

        restored = restore_tariff_service(self.db, tariff.tariff_id)
        self.assertTrue(restored.is_active)

    def test_get_tariff_by_id_404(self):
        with self.assertRaises(HTTPException) as ctx:
            get_tariff_by_id_service(self.db, 999)
        self.assertEqual(ctx.exception.status_code, 404)

    def test_get_tariff_by_hs_code_404(self):
        with self.assertRaises(HTTPException) as ctx:
            get_tariff_by_hs_code_service(self.db, "0000.00.00")
        self.assertEqual(ctx.exception.status_code, 404)

    # ==================================================
    # Egyptian Customs Calculation Engine Tests (7.2)
    # ==================================================

    def test_estimate_customs_duty_standard_laptop(self):
        """
        Customs Calculation Flow Verification for Laptop:
        FOB/CIF = 100,000 EGP, Freight = 5,000 EGP
        Duties:
          - Import Duty (5%) = 100,000 * 5% = 5,000
          - Schedule Tax (0%) = 0
          - Development Fee (5%) = 100,000 * 5% = 5,000
          - Import Fee (0%) = 0
          - Customs Service Fee (1%) = 100,000 * 1% = 1,000
          - VAT Base = 100,000 + 5,000 (Duty) = 105,000
          - VAT (14%) = 105,000 * 14% = 14,700
          - Total Taxes = 5,000 + 14,700 + 5,000 + 1,000 = 25,700
        """
        create_tariff_service(
            self.db,
            CustomsTariffCreate(
                hs_code="8471.30.00",
                hs_description="Laptops",
                customs_duty_rate=Decimal("5.00"),
                vat_rate=Decimal("14.00"),
                schedule_tax_rate=Decimal("0.00"),
                development_fee_rate=Decimal("5.00"),
                import_fee_rate=Decimal("0.00"),
                customs_service_fee_rate=Decimal("1.00"),
            ),
        )

        request = CustomsDutyEstimateRequest(
            hs_code="8471.30.00",
            cif_value=Decimal("100000.00"),
            freight=Decimal("5000.00"),
        )
        breakdown = estimate_customs_duty_service(self.db, request)

        self.assertEqual(breakdown.import_duty_amount, Decimal("5000.00"))
        self.assertEqual(breakdown.vat_base, Decimal("105000.00"))
        self.assertEqual(breakdown.vat_amount, Decimal("14700.00"))
        self.assertEqual(breakdown.development_fee_amount, Decimal("5000.00"))
        self.assertEqual(breakdown.customs_service_fee_amount, Decimal("1000.00"))
        self.assertEqual(breakdown.total_taxes_and_fees, Decimal("25700.00"))

    def test_estimate_customs_duty_duty_free_pharmaceutical(self):
        """
        Customs Calculation Flow Verification for Pharmaceuticals (0% duty, 0% VAT, 0% Service Fee):
        CIF = 500,000 EGP, Freight = 20,000 EGP
        All duties and VAT must be 0.
        """
        create_tariff_service(
            self.db,
            CustomsTariffCreate(
                hs_code="3004.90.90",
                hs_description="Medicaments",
                customs_duty_rate=Decimal("0.00"),
                vat_rate=Decimal("0.00"),
                schedule_tax_rate=Decimal("0.00"),
                development_fee_rate=Decimal("0.00"),
                customs_service_fee_rate=Decimal("0.00"),
            ),
        )

        request = CustomsDutyEstimateRequest(
            hs_code="3004.90.90",
            cif_value=Decimal("500000.00"),
            freight=Decimal("20000.00"),
        )
        breakdown = estimate_customs_duty_service(self.db, request)

        self.assertEqual(breakdown.import_duty_amount, Decimal("0.00"))
        self.assertEqual(breakdown.vat_amount, Decimal("0.00"))
        self.assertEqual(breakdown.customs_service_fee_amount, Decimal("0.00"))
        self.assertEqual(breakdown.total_taxes_and_fees, Decimal("0.00"))

    def test_estimate_customs_duty_car_with_schedule_tax(self):
        """
        Customs Calculation Flow Verification for Luxury Vehicle:
        CIF = 600,000 EGP, Freight = 30,000 EGP
        Rates: Duty 40%, VAT 14%, Schedule Tax 15%, Dev Fee 8%, Import Fee 3%, Service Fee 1%
        - Duty = 600,000 * 40% = 240,000
        - Schedule Tax = 600,000 * 15% = 90,000
        - Dev Fee = 600,000 * 8% = 48,000
        - Import Fee = 600,000 * 3% = 18,000
        - Service Fee = 600,000 * 1% = 6,000
        - VAT Base = 600,000 + 240,000 = 840,000
        - VAT = 840,000 * 14% = 117,600
        - Total = 240,000 + 117,600 + 90,000 + 48,000 + 18,000 + 6,000 = 519,600
        """
        create_tariff_service(
            self.db,
            CustomsTariffCreate(
                hs_code="8703.23.90",
                hs_description="Vehicles",
                customs_duty_rate=Decimal("40.00"),
                vat_rate=Decimal("14.00"),
                schedule_tax_rate=Decimal("15.00"),
                development_fee_rate=Decimal("8.00"),
                import_fee_rate=Decimal("3.00"),
                customs_service_fee_rate=Decimal("1.00"),
            ),
        )

        request = CustomsDutyEstimateRequest(
            hs_code="8703.23.90",
            cif_value=Decimal("600000.00"),
            freight=Decimal("30000.00"),
        )
        breakdown = estimate_customs_duty_service(self.db, request)

        self.assertEqual(breakdown.import_duty_amount, Decimal("240000.00"))
        self.assertEqual(breakdown.schedule_tax_amount, Decimal("90000.00"))
        self.assertEqual(breakdown.development_fee_amount, Decimal("48000.00"))
        self.assertEqual(breakdown.import_fee_amount, Decimal("18000.00"))
        self.assertEqual(breakdown.customs_service_fee_amount, Decimal("6000.00"))
        self.assertEqual(breakdown.vat_base, Decimal("840000.00"))
        self.assertEqual(breakdown.vat_amount, Decimal("117600.00"))
        self.assertEqual(breakdown.total_taxes_and_fees, Decimal("519600.00"))

    # ==================================================
    # Search and Filter Tests
    # ==================================================

    def test_search_tariffs(self):
        create_tariff_service(
            self.db,
            CustomsTariffCreate(
                hs_code="8471.30.00",
                hs_description="Laptops and Notebooks",
                customs_category="Electronics",
                customs_duty_rate=Decimal("5.00"),
                vat_rate=Decimal("14.00"),
            ),
        )
        create_tariff_service(
            self.db,
            CustomsTariffCreate(
                hs_code="8703.23.90",
                hs_description="Motor Vehicles",
                customs_category="Automotive",
                customs_duty_rate=Decimal("40.00"),
                vat_rate=Decimal("14.00"),
            ),
        )

        # Search by HS code
        results = get_all_tariffs_service(self.db, search="8471")
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0].hs_code, "8471.30.00")

        # Search by description
        results = get_all_tariffs_service(self.db, search="Motor")
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0].hs_code, "8703.23.90")

    def _category_rows(self):
        """Coded rows (normalized on create) + one legacy row that still stores the old Arabic label."""
        from modules.customs_tariff import repository

        create_tariff_service(self.db, CustomsTariffCreate(
            hs_code="8418.10.00", hs_description="Refrigerators", customs_category="آلات وأجهزة وتجهيزات",
            customs_duty_rate=Decimal("30.00"), vat_rate=Decimal("14.00"),
        ))
        create_tariff_service(self.db, CustomsTariffCreate(
            hs_code="8517.12.00", hs_description="Mobile phones", customs_category="Electronics",
            customs_duty_rate=Decimal("5.00"), vat_rate=Decimal("14.00"),
        ))
        create_tariff_service(self.db, CustomsTariffCreate(
            hs_code="6109.10.00", hs_description="Cotton T-shirts", customs_category="Textiles",
            customs_duty_rate=Decimal("40.00"), vat_rate=Decimal("14.00"),
        ))
        repository.create_tariff(self.db, {
            "hs_code": "8450.11.00", "hs_description": "Washing machines",
            "customs_category": "آلات وأجهزة وتجهيزات",  # legacy row, never normalized
            "customs_duty_rate": Decimal("30.00"), "vat_rate": Decimal("14.00"),
            "effective_from": date(2024, 1, 1),
        })

    def test_coded_categories_are_stored_as_codes(self):
        self._category_rows()
        stored = {t.hs_code: t.customs_category for t in get_all_tariffs_service(self.db)}
        self.assertEqual(stored["8418.10.00"], "MACHINERY_EQUIPMENT")
        self.assertEqual(stored["8517.12.00"], "ELECTRONICS")

    def test_search_by_arabic_legacy_label_matches_coded_and_legacy_rows(self):
        self._category_rows()
        hs = sorted(t.hs_code for t in get_all_tariffs_service(self.db, search="آلات"))
        self.assertEqual(hs, ["8418.10.00", "8450.11.00"])

    def test_search_by_english_label_fragment_matches_coded_and_legacy_rows(self):
        self._category_rows()
        hs = sorted(t.hs_code for t in get_all_tariffs_service(self.db, search="machinery"))
        self.assertEqual(hs, ["8418.10.00", "8450.11.00"])
        hs = [t.hs_code for t in get_all_tariffs_service(self.db, search="Electronics")]
        self.assertEqual(hs, ["8517.12.00"])

    def test_search_by_code_and_unmatched_term(self):
        self._category_rows()
        hs = [t.hs_code for t in get_all_tariffs_service(self.db, search="textiles")]
        self.assertEqual(hs, ["6109.10.00"])
        self.assertEqual(get_all_tariffs_service(self.db, search="no-such-category"), [])
        # Blank search is not a filter.
        self.assertEqual(len(get_all_tariffs_service(self.db, search="  ")), 4)

    def test_category_search_values_helper(self):
        from modules.customs_tariff.service import customs_category_search_values

        self.assertEqual(customs_category_search_values(None), [])
        values = customs_category_search_values("general")
        self.assertIn("GENERAL_GOODS", values)
        self.assertIn("أصناف عامة", values)
        self.assertIn("General", values)

    def test_feed_hs_code_3925900090_building_plastics(self):
        """
        Verification of official Nafeza Tariff data for HS 3925900090:
        Standard Duty: 40%, VAT: 14%, Schedule: 0%, Service Fee: 1%
        Category: أصناف وتجهيزات البناء من لدائن
        Mercosur Preferential Duty: 3%
        """
        tariff = create_tariff_service(
            self.db,
            CustomsTariffCreate(
                hs_code="3925900090",
                hs_description="أصناف أخر لتجهيزات البناء من لدائن ، غير مذكورة أو داخلة في مكان آخر .",
                customs_category="أصناف وتجهيزات البناء من لدائن",
                customs_duty_rate=Decimal("40.00"),
                vat_rate=Decimal("14.00"),
                schedule_tax_rate=Decimal("0.00"),
                development_fee_rate=Decimal("0.00"),
                import_fee_rate=Decimal("0.00"),
                customs_service_fee_rate=Decimal("1.00"),
                requires_coo=True,
                requires_inspection=True,
                requires_acid=True,
                regulatory_authority="الهيئة العامة للرقابة على الصادرات والواردات (GOEIC)",
            ),
        )
        self.assertEqual(tariff.hs_code, "3925900090")
        self.assertEqual(tariff.customs_duty_rate, Decimal("40.00"))
        self.assertEqual(tariff.vat_rate, Decimal("14.00"))

        request = CustomsDutyEstimateRequest(
            hs_code="3925900090",
            cif_value=Decimal("100000.00"),
            freight=Decimal("0.00"),
        )
        breakdown = estimate_customs_duty_service(self.db, request)
        self.assertEqual(breakdown.import_duty_amount, Decimal("40000.00"))
        self.assertEqual(breakdown.vat_base, Decimal("140000.00"))
        self.assertEqual(breakdown.vat_amount, Decimal("19600.00"))
        self.assertEqual(breakdown.customs_service_fee_amount, Decimal("1000.00"))
        self.assertEqual(breakdown.total_taxes_and_fees, Decimal("60600.00"))


if __name__ == "__main__":
    unittest.main()

