import unittest
from datetime import datetime, date, timezone
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.incoterms.model import Incoterm
from modules.projects.model import Project
from modules.currencies.model import Currency, ExchangeRate
from modules.customs_tariff.model import CustomsTariff
from modules.external_service_providers.model import ExternalServiceProvider
from modules.transport_locations.model import TransportLocation
from modules.freight_quotations.model import FreightRFQRequest
from modules.purchase_orders.model import PurchaseOrder
from modules.freight_booking.model import ShipmentBooking
from modules.import_files.model import ImportFile
from modules.financial_settlement.model import LandedCostSettlementRecord
from modules.financial_settlement.schemas import (
    FinancialSettlementCreate,
    ExpenseInvoiceSchema,
    ItemLandedCostSchema,
    FinancialSettlementUpdate,
)
from modules.financial_settlement.service import (
    create_settlement_service,
    recalculate_settlement_service,
    get_settlement_service,
    list_settlements_service,
    calculate_landed_cost_engine,
    soft_delete_settlement_service,
    restore_settlement_service,
)

class TestFinancialSettlementModule(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=self.engine)
        self.db = TestingSessionLocal()

        company = ImportCompany(
            company_id=1,
            importer_name="Delta Industrial Co",
            vat_id="999-888-777",
            registration_number="12345",
            address="Cairo, Egypt",
            country="Egypt",
            importer_id="IMP-009",
            importer_id_expiry=date(2028, 1, 1),
            vat_id_expiry=date(2028, 1, 1),
            registration_expiry=date(2028, 1, 1),
        )
        self.db.add(company)
        self.db.commit()

        imp_file = ImportFile(
            import_file_code="IMP-FILE-2026-0009",
            company_id=company.company_id,
            company_name=company.importer_name,
            supplier_name="Global Heavy Equipment Ltd",
            po_number="PO-2026-900",
        )
        self.db.add(imp_file)
        self.db.commit()
        self.db.refresh(imp_file)
        self.import_file_id = imp_file.import_file_id

    def tearDown(self):
        self.db.close()

    def test_landed_cost_engine_allocation_formulas(self):
        expenses = [
            {"invoice_no": "INV-FREIGHT", "category": "Freight", "provider_name": "Maersk", "currency": "USD", "amount_fx": 1000.0, "exchange_rate": 50.0, "amount_egp": 50000.0, "allocation_rule": "Volume-Based"},
            {"invoice_no": "INV-CUSTOMS", "category": "Customs Duty", "provider_name": "Customs Authority", "currency": "EGP", "amount_fx": 20000.0, "exchange_rate": 1.0, "amount_egp": 20000.0, "allocation_rule": "Value-Based"},
        ]

        items = [
            {"item_code": "ITM-01", "item_name": "Pumps", "qty": 100, "gross_weight_kg": 1000.0, "cbm": 10.0, "fob_unit_egp": 1000.0},
            {"item_code": "ITM-02", "item_name": "Valves", "qty": 100, "gross_weight_kg": 500.0, "cbm": 30.0, "fob_unit_egp": 1000.0},
        ]

        res = calculate_landed_cost_engine(expenses, items)

        self.assertEqual(res["total_fob_egp"], 200000.0)
        self.assertEqual(res["total_expenses_egp"], 70000.0)
        self.assertEqual(res["total_landed_cost_egp"], 270000.0)
        self.assertAlmostEqual(res["average_markup_factor"], 1.35, places=2)

        # Check volume-based freight allocation (CBM ratio: 10m³ vs 30m³ -> 1:3 ratio)
        itm1 = res["item_landed_costs"][0]
        itm2 = res["item_landed_costs"][1]
        self.assertEqual(itm1["allocated_freight_egp"], 12500.0) # 25% of 50000
        self.assertEqual(itm2["allocated_freight_egp"], 37500.0) # 75% of 50000

        # Check value-based customs allocation (Equal FOB total -> 50% each)
        self.assertEqual(itm1["allocated_customs_egp"], 10000.0)
        self.assertEqual(itm2["allocated_customs_egp"], 10000.0)

    def test_create_and_recalculate_settlement_service(self):
        schema = FinancialSettlementCreate(
            import_file_id=self.import_file_id,
            expense_invoices=[
                ExpenseInvoiceSchema(
                    invoice_no="INV-TRANS-01",
                    category="Local Transport",
                    provider_name="Cairo Logistics",
                    currency="EGP",
                    amount_fx=10000.0,
                    exchange_rate=1.0,
                    amount_egp=10000.0,
                    allocation_rule="Weight-Based",
                )
            ],
            item_landed_costs=[
                ItemLandedCostSchema(
                    item_code="ITM-99",
                    item_name="Generator",
                    qty=1,
                    gross_weight_kg=2000.0,
                    cbm=5.0,
                    fob_unit_egp=100000.0,
                    fob_total_egp=100000.0,
                )
            ]
        )

        record = create_settlement_service(self.db, schema)
        self.assertIsNotNone(record.settlement_id)
        self.assertTrue(record.settlement_code.startswith("LCS-"))
        self.assertEqual(record.total_fob_egp, 100000.0)
        self.assertEqual(record.total_expenses_egp, 10000.0)
        self.assertEqual(record.total_landed_cost_egp, 110000.0)
        self.assertEqual(record.average_markup_factor, 1.1)

    def test_soft_delete_and_restore(self):
        schema = FinancialSettlementCreate(import_file_id=self.import_file_id)
        record = create_settlement_service(self.db, schema)
        s_id = record.settlement_id

        # Delete
        success = soft_delete_settlement_service(self.db, s_id)
        self.assertTrue(success)

        # Restore
        restored = restore_settlement_service(self.db, s_id)
        self.assertIsNotNone(restored)
        self.assertEqual(restored.settlement_id, s_id)
        self.assertTrue(restored.is_active)

    def test_incoterm_aware_landed_cost_calculation(self):
        # 1. CIF Shipment: Seller pays freight & insurance
        expenses_cif = [
            {"invoice_no": "INV-FR-CIF", "category": "Freight", "amount_egp": 40000.0, "is_seller_paid": True},
            {"invoice_no": "INV-CUST-CIF", "category": "Customs Duty", "amount_egp": 25000.0, "allocation_rule": "Value-Based"},
            {"invoice_no": "INV-TR-CIF", "category": "Local Transport", "amount_egp": 5000.0, "allocation_rule": "Value-Based"},
        ]
        items_cif = [
            {"item_code": "ITM-CIF-01", "item_name": "Medical Device", "qty": 10, "gross_weight_kg": 500.0, "cbm": 4.0, "fob_unit_egp": 20000.0},
        ]
        res_cif = calculate_landed_cost_engine(expenses_cif, items_cif, incoterm="CIF")
        # Importer expenses should only include customs (25000) and transport (5000) = 30000, excluding seller-paid freight
        self.assertEqual(res_cif["total_fob_egp"], 200000.0)
        self.assertEqual(res_cif["total_expenses_egp"], 30000.0)
        self.assertEqual(res_cif["total_landed_cost_egp"], 230000.0)
        self.assertEqual(res_cif["incoterm_code"], "CIF")

        # 2. EXW Shipment: Importer pays origin trucking, freight, insurance, customs, transport
        expenses_exw = [
            {"invoice_no": "INV-ORIG-EXW", "category": "Origin Inland Transport", "amount_egp": 15000.0, "allocation_rule": "Value-Based"},
            {"invoice_no": "INV-FR-EXW", "category": "Freight", "amount_egp": 50000.0, "allocation_rule": "Value-Based"},
            {"invoice_no": "INV-CUST-EXW", "category": "Customs Duty", "amount_egp": 30000.0, "allocation_rule": "Value-Based"},
        ]
        items_exw = [
            {"item_code": "ITM-EXW-01", "item_name": "Industrial Motor", "qty": 5, "gross_weight_kg": 1000.0, "cbm": 8.0, "fob_unit_egp": 30000.0},
        ]
        res_exw = calculate_landed_cost_engine(expenses_exw, items_exw, incoterm="EXW")
        self.assertEqual(res_exw["total_fob_egp"], 150000.0)
        self.assertEqual(res_exw["total_expenses_egp"], 95000.0)
        self.assertEqual(res_exw["total_landed_cost_egp"], 245000.0)
        self.assertEqual(res_exw["incoterm_code"], "EXW")

    def test_partial_shipment_fob_share(self):
        """
        ACC2-T01: Landed cost uses the file's share of partially shipped POs.
        - PO 1 line 1,000 units x 10 USD, PO rate 50, CBM 20, weight 5,000;
        - allocation file A 400, file B 600.
        - Settlement A items: qty 400, FOB 200,000.00, CBM 8.0, weight 2,000;
        - B: 600, 300,000.00;
        - A expense 60,000 Value-Based -> A unit landed cost (200,000+60,000)/400 = 650.00.
        - PO-level allocation 40 % (shipped_amount_fob 4,000) -> same FOB 200,000.
        - PO with allocations only for file B -> file A excludes it and returns SETTLEMENT_PO_NOT_ALLOCATED.
        - Recalculation fetch for A = 200,000.
        """
        import json
        from modules.purchase_orders.model import POLineItem, POShipmentAllocation
        from modules.financial_settlement.service import (
            _items_from_purchase_orders,
            file_po_line_shares,
            SettlementFx,
        )
        from modules.recalculation.service import _fetch_from_purchase_orders

        # Ensure USD exists and exchange rate 50.0
        usd = self.db.query(Currency).filter(Currency.currency_code == "USD").first()
        if not usd:
            usd = Currency(
                currency_code="USD",
                currency_name="US Dollar",
                currency_symbol="$",
                is_base_currency=False,
                decimal_places=2,
                is_active=True,
            )
            self.db.add(usd)
            self.db.commit()
            self.db.refresh(usd)

        rate_row = self.db.query(ExchangeRate).filter(
            ExchangeRate.currency_id == usd.currency_id,
            ExchangeRate.effective_date == date.today(),
        ).first()
        if not rate_row:
            rate_row = ExchangeRate(
                currency_id=usd.currency_id,
                commercial_rate=50.0,
                customs_rate=50.0,
                effective_date=date.today(),
            )
            self.db.add(rate_row)
            self.db.commit()

        # Ensure Supplier, Incoterm, Project exist
        supp = self.db.query(Supplier).filter(Supplier.supplier_id == 1).first()
        if not supp:
            supp = Supplier(
                supplier_id=1,
                supplier_code="SUP-ACC2-01",
                company_name="Global Heavy Equipment Ltd",
                supplier_type="Manufacturer",
                registration_type="CargoX",
                foreign_exporter_id="EXP-ACC2-01",
                foreign_exporter_country="China",
                foreign_exporter_country_code="CN",
                address="Shanghai, China",
                is_active=True,
            )
            self.db.add(supp)

        inco = self.db.query(Incoterm).filter(Incoterm.incoterm_id == 1).first()
        if not inco:
            inco = Incoterm(
                incoterm_id=1,
                incoterm_code="FOB",
                incoterm_name="Free On Board",
                is_active=True,
            )
            self.db.add(inco)

        proj = self.db.query(Project).filter(Project.project_id == 1).first()
        if not proj:
            proj = Project(
                project_id=1,
                project_code="PRJ-ACC2-01",
                project_name="Delta Heavy Machinery",
                project_owner="Ahmed",
                company_id=1,
                supplier_id=1,
                incoterm_id=1,
                is_active=True,
            )
            self.db.add(proj)
        self.db.commit()

        # Create File A and File B
        file_a = ImportFile(
            import_file_code="IMP-FILE-2026-00A",
            company_id=1,
            company_name="Delta Industrial Co",
            supplier_name="Global Supplier",
            po_number="PO-ACC2-001",
        )
        file_b = ImportFile(
            import_file_code="IMP-FILE-2026-00B",
            company_id=1,
            company_name="Delta Industrial Co",
            supplier_name="Global Supplier",
            po_number="PO-ACC2-001",
        )
        self.db.add_all([file_a, file_b])
        self.db.commit()
        self.db.refresh(file_a)
        self.db.refresh(file_b)

        # Create PO: 1,000 units x 10 USD = 10,000 USD FOB
        po = PurchaseOrder(
            po_number="PO-ACC2-001",
            project_id=1,
            company_id=1,
            supplier_id=1,
            incoterm_id=1,
            currency_id=usd.currency_id,
            total_amount_fob=10000.0,
            order_date=datetime.now(timezone.utc),
            import_file_id=file_a.import_file_id,
            is_active=True,
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
        self.db.add(po)
        self.db.commit()
        self.db.refresh(po)

        # File B also lists this PO via po_ids
        file_b.po_ids = json.dumps([po.po_id])
        self.db.commit()

        # Add PO Line Item: 1,000 units, 10 USD, CBM 20, Weight 5,000
        line = POLineItem(
            po_id=po.po_id,
            item_code="ITM-ACC2-01",
            description_ar="Ù…Ø¶Ø®Ø§Øª ØµÙ†Ø§Ø¹ÙŠØ©",
            description_en="Industrial Pumps",
            quantity=1000.0,
            unit_price=10.0,
            total_price=10000.0,
            gross_weight_kg=5000.0,
            total_cbm=20.0,
            created_at=datetime.now(timezone.utc),
        )
        self.db.add(line)
        self.db.commit()
        self.db.refresh(line)

        # 1. Item-level Allocations: File A = 400, File B = 600
        alloc_a = POShipmentAllocation(
            po_id=po.po_id,
            po_item_id=line.item_id,
            import_file_id=file_a.import_file_id,
            shipped_quantity=400.0,
            shipped_amount_fob=4000.0,
            shipment_ref="BL-A-01",
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
        alloc_b = POShipmentAllocation(
            po_id=po.po_id,
            po_item_id=line.item_id,
            import_file_id=file_b.import_file_id,
            shipped_quantity=600.0,
            shipped_amount_fob=6000.0,
            shipment_ref="BL-B-01",
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
        self.db.add_all([alloc_a, alloc_b])
        self.db.commit()

        fx = SettlementFx(self.db, "commercial")

        # Settlement A items: qty 400, FOB 200,000.00, CBM 8.0, weight 2,000
        items_a = _items_from_purchase_orders(self.db, file_a, fx)
        self.assertEqual(len(items_a), 1)
        self.assertEqual(items_a[0]["qty"], 400.0)
        self.assertEqual(items_a[0]["fob_unit_egp"], 500.0)
        self.assertEqual(items_a[0]["cbm"], 8.0)
        self.assertEqual(items_a[0]["gross_weight_kg"], 2000.0)

        # Settlement B items: qty 600, FOB 300,000.00
        items_b = _items_from_purchase_orders(self.db, file_b, fx)
        self.assertEqual(len(items_b), 1)
        self.assertEqual(items_b[0]["qty"], 600.0)
        self.assertEqual(items_b[0]["fob_unit_egp"], 500.0)
        self.assertEqual(items_b[0]["cbm"], 12.0)
        self.assertEqual(items_b[0]["gross_weight_kg"], 3000.0)

        # A expense 60,000 Value-Based -> A unit landed cost (200,000+60,000)/400 = 650.00
        expenses_a = [
            {
                "invoice_no": "EXP-60K",
                "category": "Freight",
                "provider_name": "Carrier",
                "currency": "EGP",
                "amount_fx": 60000.0,
                "exchange_rate": 1.0,
                "amount_egp": 60000.0,
                "allocation_rule": "Value-Based",
            }
        ]
        res_a = calculate_landed_cost_engine(expenses_a, items_a)
        self.assertEqual(res_a["total_fob_egp"], 200000.0)
        self.assertEqual(res_a["total_expenses_egp"], 60000.0)
        self.assertEqual(res_a["total_landed_cost_egp"], 260000.0)
        self.assertEqual(res_a["item_landed_costs"][0]["unit_landed_cost_egp"], 650.0)

        # Recalculation fetch for A = 200,000
        recalc_fob_a = _fetch_from_purchase_orders(self.db, file_a.import_file_id, "total_amount_fob", "sum")
        self.assertEqual(recalc_fob_a, 200000.0)

        # 2. PO-level allocation 40 % (shipped_amount_fob 4,000) -> same FOB 200,000
        self.db.delete(alloc_a)
        self.db.delete(alloc_b)
        self.db.commit()

        alloc_po_a = POShipmentAllocation(
            po_id=po.po_id,
            po_item_id=None,
            import_file_id=file_a.import_file_id,
            shipped_quantity=0.0,
            shipped_amount_fob=4000.0,
            shipment_ref="BL-A-PO",
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
        self.db.add(alloc_po_a)
        self.db.commit()

        items_a_po = _items_from_purchase_orders(self.db, file_a, fx)
        self.assertEqual(len(items_a_po), 1)
        self.assertEqual(items_a_po[0]["qty"], 400.0)
        self.assertEqual(items_a_po[0]["fob_unit_egp"], 500.0)
        self.assertEqual(items_a_po[0]["cbm"], 8.0)
        self.assertEqual(items_a_po[0]["gross_weight_kg"], 2000.0)
        res_a_po = calculate_landed_cost_engine(expenses_a, items_a_po)
        self.assertEqual(res_a_po["total_fob_egp"], 200000.0)

        # 3. PO with allocations only for file B -> file A excludes it and returns SETTLEMENT_PO_NOT_ALLOCATED
        self.db.delete(alloc_po_a)
        alloc_po_b = POShipmentAllocation(
            po_id=po.po_id,
            po_item_id=line.item_id,
            import_file_id=file_b.import_file_id,
            shipped_quantity=600.0,
            shipped_amount_fob=6000.0,
            shipment_ref="BL-B-ONLY",
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
        self.db.add(alloc_po_b)
        self.db.commit()

        messages_a = []
        shares_a = file_po_line_shares(self.db, file_a, messages=messages_a)
        self.assertEqual(len(shares_a), 0)
        self.assertEqual(len(messages_a), 1)
        self.assertEqual(messages_a[0].code, "SETTLEMENT_PO_NOT_ALLOCATED")
        self.assertEqual(messages_a[0].params.get("po_number"), po.po_number)



if __name__ == "__main__":
    unittest.main()
