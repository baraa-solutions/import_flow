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
from modules.cargo_insurance.model import CargoInsuranceCertificate
from modules.customs_clearance.model import CustomsClearanceRecord, ClearanceExpenseInvoice
from modules.inland_transport.model import InlandTransportBooking
from modules.demurrage_detention.model import DemurrageTracking
from modules.import_files.model import ImportFile
from modules.financial_settlement.model import LandedCostSettlementRecord
from modules.financial_settlement.schemas import (
    FinancialSettlementCreate,
    ExpenseInvoiceSchema,
    ItemLandedCostSchema,
    FinancialSettlementUpdate,
    FinancialSettlementResponse,
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
from decimal import Decimal
from modules.freight_quotations.model import FreightRFQRequest, FreightQuotationItem
from modules.purchase_orders.model import PurchaseOrder, POLineItem
import main
from modules.financial_settlement.service import (
    create_settlement_service,
    recalculate_settlement_service,
    get_settlement_service,
    list_settlements_service,
    calculate_landed_cost_engine,
    soft_delete_settlement_service,
    restore_settlement_service,
    simulate_estimated_landed_cost_service,
)

class TestFinancialSettlementModule(unittest.TestCase):
    def setUp(self):
        from modules.currencies.service import clear_currency_cache
        clear_currency_cache()
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
        from modules.currencies.service import clear_currency_cache
        clear_currency_cache()

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

    def test_booking_without_insurance_line_counts_insurance_once(self):
        # ACC3-T02 acceptance test:
        # Booking freight 4,000 USD + insurance certificate 346.50 USD at rate 50.0
        # -> freight row 200,000.00 EGP, insurance row 17,325.00 EGP, no other insurance amount
        from modules.cargo_insurance.model import CargoInsuranceCertificate
        from modules.currencies.model import Currency, ExchangeRate
        from modules.financial_settlement.service import aggregate_shipment_invoices_service

        usd = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
        egp = Currency(currency_code="EGP", currency_name="Egyptian Pound", currency_symbol="EGP", is_base_currency=True, is_active=True)
        self.db.add_all([usd, egp])
        self.db.flush()

        rate_row = ExchangeRate(
            currency_id=usd.currency_id,
            commercial_rate=50.0,
            customs_rate=50.0,
            effective_date=date.today(),
        )
        self.db.add(rate_row)
        self.db.commit()

        # Add booking without insurance line (4,000 USD)
        booking = ShipmentBooking(
            booking_code="BKG-ACC3-001",
            booking_confirmation_no="MSC-CONF-4000",
            import_file_id=self.import_file_id,
            total_freight_cost_usd=4000.0,
            status="Confirmed",
            booking_confirmation_date=datetime.now(timezone.utc),
            is_active=True,
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
        self.db.add(booking)

        # Add insurance certificate (346.50 USD)
        cert = CargoInsuranceCertificate(
            certificate_code="INS-CERT-001",
            policy_number="POL-2026-999",
            import_file_id=self.import_file_id,
            insured_entity_name="Delta Industrial Co",
            insurance_company_name="Misr Insurance",
            port_of_loading="Shanghai, China",
            port_of_discharge="Alexandria, Egypt",
            currency="USD",
            total_payable_premium=346.50,
            exchange_rate=50.0,
            is_active=True,
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
        self.db.add(cert)
        self.db.commit()

        res = aggregate_shipment_invoices_service(self.db, self.import_file_id)
        invoices = res.invoices

        # Check freight invoice: 4,000 USD * 50 = 200,000 EGP
        frt_invoices = [inv for inv in invoices if inv.category == "Ocean/Air Freight"]
        self.assertEqual(len(frt_invoices), 1)
        self.assertEqual(frt_invoices[0].amount_fc, 4000.0)
        self.assertEqual(frt_invoices[0].amount_egp, 200000.0)

        # Check insurance invoice: 346.50 USD * 50 = 17,325 EGP
        ins_invoices = [inv for inv in invoices if inv.category == "Marine Insurance"]
        self.assertEqual(len(ins_invoices), 1)
        self.assertEqual(ins_invoices[0].amount_fc, 346.50)
        self.assertEqual(ins_invoices[0].amount_egp, 17325.0)

        # Verify no other insurance amounts are counted
        total_insurance_egp = sum(inv.amount_egp for inv in ins_invoices)
        self.assertEqual(total_insurance_egp, 17325.0)

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
        else:
            rate_row.commercial_rate = 50.0
            rate_row.customs_rate = 50.0
        self.db.commit()
        from modules.currencies.service import clear_currency_cache
        clear_currency_cache()

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

        # Test CLO-02 and PL-08 share paths for file A (400 units)
        from modules.financial_settlement.service import (
            calculate_actual_landed_cost_service,
            simulate_estimated_landed_cost_service,
        )
        res_clo02 = calculate_actual_landed_cost_service(self.db, file_a.import_file_id)
        self.assertEqual(len(res_clo02.items_breakdown), 1)
        self.assertEqual(res_clo02.items_breakdown[0].qty, 400.0)
        self.assertEqual(res_clo02.items_breakdown[0].fob_total_egp, 200000.0)

        res_pl08 = simulate_estimated_landed_cost_service(self.db, file_a.import_file_id)
        self.assertEqual(len(res_pl08.items_breakdown), 1)
        self.assertEqual(res_pl08.items_breakdown[0].qty, 400.0)
        self.assertEqual(res_pl08.items_breakdown[0].fob_total_fc, 4000.0)

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

        # 2b. PO-level allocation with FOB 0 falls back to quantity ratio (400/1000 = 0.4)
        self.db.delete(alloc_po_a)
        self.db.commit()

        alloc_po_zero_fob = POShipmentAllocation(
            po_id=po.po_id,
            po_item_id=None,
            import_file_id=file_a.import_file_id,
            shipped_quantity=400.0,
            shipped_amount_fob=0.0,
            shipment_ref="BL-A-ZERO-FOB",
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
        self.db.add(alloc_po_zero_fob)
        self.db.commit()

        items_a_zero_fob = _items_from_purchase_orders(self.db, file_a, fx)
        self.assertEqual(len(items_a_zero_fob), 1)
        self.assertEqual(items_a_zero_fob[0]["qty"], 400.0)
        self.assertEqual(items_a_zero_fob[0]["fob_unit_egp"], 500.0)
        shares_zero_fob = file_po_line_shares(self.db, file_a)
        self.assertEqual(len(shares_zero_fob), 1)
        self.assertEqual(shares_zero_fob[0][1], 400.0)
        self.assertEqual(shares_zero_fob[0][2], 0.4)

        # 2c. Mixed PO-level allocations: one with FOB (200 qty, 2000 FOB), one with FOB 0 (200 qty, 0 FOB)
        # Fallback to quantity ratio: (200+200)/1000 = 0.4 -> 400 qty, 0.4 ratio
        self.db.delete(alloc_po_zero_fob)
        self.db.commit()

        alloc_mixed_1 = POShipmentAllocation(
            po_id=po.po_id,
            po_item_id=None,
            import_file_id=file_a.import_file_id,
            shipped_quantity=200.0,
            shipped_amount_fob=2000.0,
            shipment_ref="BL-A-MIXED-1",
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
        alloc_mixed_2 = POShipmentAllocation(
            po_id=po.po_id,
            po_item_id=None,
            import_file_id=file_a.import_file_id,
            shipped_quantity=200.0,
            shipped_amount_fob=0.0,
            shipment_ref="BL-A-MIXED-2",
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
        self.db.add_all([alloc_mixed_1, alloc_mixed_2])
        self.db.commit()

        shares_mixed = file_po_line_shares(self.db, file_a)
        self.assertEqual(len(shares_mixed), 1)
        self.assertEqual(shares_mixed[0][1], 400.0)
        self.assertEqual(shares_mixed[0][2], 0.4)
        items_a_mixed = _items_from_purchase_orders(self.db, file_a, fx)
        self.assertEqual(len(items_a_mixed), 1)
        self.assertEqual(items_a_mixed[0]["qty"], 400.0)
        self.assertEqual(items_a_mixed[0]["fob_unit_egp"], 500.0)

        self.db.delete(alloc_mixed_1)
        self.db.delete(alloc_mixed_2)
        self.db.commit()

        # 3. PO with allocations only for file B -> file A excludes it and returns SETTLEMENT_PO_NOT_ALLOCATED
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

        # 4. Allocations with no import file (import_file_id is None) do NOT cause PO to vanish
        self.db.delete(alloc_po_b)
        self.db.commit()

        alloc_unlinked = POShipmentAllocation(
            po_id=po.po_id,
            po_item_id=line.item_id,
            import_file_id=None,
            shipped_quantity=400.0,
            shipped_amount_fob=4000.0,
            shipment_ref="BL-UNLINKED",
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
        self.db.add(alloc_unlinked)
        self.db.commit()

        # Should keep full-PO behavior (1000 units, not skipped)
        shares_unlinked = file_po_line_shares(self.db, file_a)
        self.assertEqual(len(shares_unlinked), 1)
        self.assertEqual(shares_unlinked[0][1], 1000.0)
        self.assertEqual(shares_unlinked[0][2], 1.0)

        # Recalculation should also contribute full PO FOB when allocations are unlinked
        recalc_unlinked = _fetch_from_purchase_orders(self.db, file_a.import_file_id, "total_amount_fob", "sum")
        self.assertEqual(recalc_unlinked, 500000.0)

    def test_estimate_freight_uses_ocean_cost_only(self):
        """
        ACC3-T03: Phase-1 landed cost estimate uses only the ocean freight of the
        awarded quote for CIF calculation, not the quote total cost (which includes
        local and inland charges).
        Worked example:
        FOB: 100,000 USD, Customs FX rate: 50.0 EGP/USD. Total FOB = 5,000,000 EGP.
        Awarded quote: Ocean freight = 3,000 USD, Local charges = 400 USD, Inland = 600 USD (Total = 4,000 USD).
        Deemed insurance: 2.5% of FOB = 2,500 USD = 125,000 EGP.
        Customs Tariff: Duty = 10%, VAT = 14%.

        Expectations:
        - Freight line amount_fc = 3,000.00 USD, amount_egp = 150,000.00 EGP (not 4,000 / 200,000).
        - Insurance line amount_fc = 2,500.00 USD, amount_egp = 125,000.00 EGP.
        - CIF for customs = 5,000,000 + 150,000 + 125,000 = 5,275,000.00 EGP.
        - Duty (10%) = 527,500.00 EGP.
        - VAT base = 5,275,000 + 527,500 = 5,802,500.00 EGP.
        - VAT (14%) = 812,350.00 EGP.
        - Total customs & taxes = 527,500 + 812,350 = 1,339,850.00 EGP.
        """
        # Ensure USD currency with customs rate 50.0
        usd = self.db.query(Currency).filter(Currency.currency_code == "USD").first()
        if not usd:
            usd = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
            self.db.add(usd)
            self.db.commit()
            self.db.refresh(usd)

        rate = self.db.query(ExchangeRate).filter(ExchangeRate.currency_id == usd.currency_id).first()
        if not rate:
            rate = ExchangeRate(
                currency_id=usd.currency_id,
                customs_rate=Decimal("50.0"),
                commercial_rate=Decimal("50.0"),
                effective_date=date(2020, 1, 1),
                is_active=True,
            )
            self.db.add(rate)
        else:
            rate.customs_rate = Decimal("50.0")
            rate.commercial_rate = Decimal("50.0")
            rate.is_active = True
        self.db.commit()

        # Customs tariff with 10% duty, 14% VAT, 0% service fee for worked example match
        tariff = CustomsTariff(
            hs_code="8479.89.99",
            hs_description="Special Machinery",
            customs_duty_rate=Decimal("10.00"),
            vat_rate=Decimal("14.00"),
            schedule_tax_rate=Decimal("0.00"),
            development_fee_rate=Decimal("0.00"),
            customs_service_fee_rate=Decimal("0.00"),
            effective_from=date(2020, 1, 1),
            is_active=True,
        )
        self.db.add(tariff)
        self.db.commit()
        self.db.refresh(tariff)

        # External service provider
        provider = ExternalServiceProvider(
            partner_code="PRV-ACC3-001",
            partner_name="Ocean Freight Line",
            partner_type="Shipping Line",
            is_active=True,
        )
        self.db.add(provider)
        self.db.commit()
        self.db.refresh(provider)

        # Ensure Supplier, Incoterm, Project exist
        supp = self.db.query(Supplier).filter(Supplier.supplier_id == 1).first()
        if not supp:
            supp = Supplier(
                supplier_id=1,
                supplier_code="SUP-ACC3-01",
                company_name="Global Heavy Equipment Ltd",
                supplier_type="Manufacturer",
                registration_type="CargoX",
                foreign_exporter_id="EXP-ACC3-01",
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
                project_code="PRJ-ACC3-01",
                project_name="Delta Heavy Machinery",
                project_owner="Ahmed",
                company_id=1,
                supplier_id=1,
                incoterm_id=1,
                is_active=True,
            )
            self.db.add(proj)
        self.db.commit()

        # Import File
        imp = ImportFile(
            import_file_code="IMP-ACC3-003",
            company_id=1,
            company_name="Delta Industrial Co",
            supplier_name="Global Supplier",
            po_number="PO-ACC3-003",
            hs_code="8479.89.99",
            is_active=True,
        )
        self.db.add(imp)
        self.db.commit()
        self.db.refresh(imp)

        # Purchase Order: 100,000 USD FOB
        po = PurchaseOrder(
            po_number="PO-ACC3-003",
            project_id=1,
            company_id=1,
            supplier_id=1,
            incoterm_id=1,
            currency_id=usd.currency_id,
            total_amount_fob=100000.0,
            order_date=datetime.now(timezone.utc),
            import_file_id=imp.import_file_id,
            is_active=True,
        )
        self.db.add(po)
        self.db.commit()
        self.db.refresh(po)

        # PO Line Item linked to tariff
        po_item = POLineItem(
            po_id=po.po_id,
            item_code="ITM-ACC3-01",
            description_ar="آلات خاصة",
            description_en="Special Machinery Unit",
            quantity=Decimal("1.0"),
            unit_price=Decimal("100000.0"),
            total_price=Decimal("100000.0"),
            gross_weight_kg=Decimal("1000.0"),
            total_cbm=Decimal("5.0"),
            tariff_id=tariff.tariff_id,
        )
        self.db.add(po_item)
        self.db.commit()

        # Freight RFQ Request (Awarded, is_active=True)
        today = date.today()
        rfq = FreightRFQRequest(
            rfq_code="RFQ-ACC3-003",
            title="Freight RFQ for ACC3-T03",
            shipping_method="Ocean FCL",
            crd_date=today,
            pol_name="Shanghai",
            pod_name="Alexandria",
            import_file_id=imp.import_file_id,
            status="Awarded",
            is_active=True,
        )
        self.db.add(rfq)
        self.db.commit()
        self.db.refresh(rfq)

        # Awarded Quote: Ocean 3,000, Local 400, Inland 600, Total 4,000
        quote = FreightQuotationItem(
            rfq_id=rfq.rfq_id,
            provider_id=provider.provider_id,
            provider_name=provider.partner_name,
            currency_code="USD",
            ocean_freight_cost=3000.0,
            local_charges_cost=400.0,
            inland_cost=600.0,
            total_cost=4000.0,
            sailing_date=today,
            estimated_arrival_date=today,
            is_awarded=True,
        )
        self.db.add(quote)
        self.db.commit()
        self.db.refresh(quote)

        rfq.selected_quotation_id = quote.quotation_id
        self.db.commit()

        # Run simulation
        res = simulate_estimated_landed_cost_service(self.db, imp.import_file_id)

        # 1. Freight expense line must use ocean_freight_cost only (3,000 USD x 50 = 150,000 EGP)
        self.assertEqual(res.total_freight_egp, 150000.0)
        freight_line = next(e for e in res.expenses_breakdown if "Ocean/Air Freight" in e.category)
        self.assertEqual(freight_line.amount_fc, 3000.0)
        self.assertEqual(freight_line.amount_egp, 150000.0)
        self.assertIn("نولون الشحن البحري للعرض الفائز في المناقصة", freight_line.source)

        # 2. Deemed Insurance (2.5% of 100,000 USD = 2,500 USD = 125,000 EGP)
        self.assertEqual(res.total_insurance_egp, 125000.0)
        ins_line = next(e for e in res.expenses_breakdown if "Marine Insurance" in e.category)
        self.assertEqual(ins_line.amount_fc, 2500.0)
        self.assertEqual(ins_line.amount_egp, 125000.0)

        # 3. Customs Duty and VAT calculated on CIF 5,275,000.00 EGP
        # Duty = 10% of CIF = 527,500.00 EGP
        self.assertEqual(res.total_customs_duty_egp, 527500.0)
        # VAT = 14% of (CIF + Duty) = 14% of 5,802,500 = 812,350.00 EGP
        self.assertEqual(res.total_vat_and_fees_egp, 812350.0)
        self.assertEqual(res.total_customs_and_taxes_egp, 527500.0 + 812350.0)

    def test_legacy_row_tolerance_status_null(self):
        """A legacy row with status=NULL, created_by=NULL inserted by SQL -> list 200 and status is None (BE09-T12)."""
        from sqlalchemy import text
        self.db.execute(text(
            "INSERT INTO financial_settlement_records "
            "(settlement_code, import_file_id, incoterm_code, status, accountant_name, created_by, updated_by, created_at, updated_at, is_active, "
            "total_fob_egp, total_expenses_egp, total_landed_cost_egp, average_markup_factor, expense_invoices, item_landed_costs) "
            "VALUES ('LCS-LEGACY-001', :fid, 'FOB', NULL, 'Legacy User', NULL, NULL, NULL, NULL, NULL, 0.0, 0.0, 0.0, 1.0, '[]', '[]')"
        ), {"fid": self.import_file_id})
        self.db.commit()

        rec = self.db.query(LandedCostSettlementRecord).filter_by(settlement_code="LCS-LEGACY-001").first()
        self.assertIsNotNone(rec)
        self.assertIsNone(rec.status)
        self.assertIsNone(rec.created_by)

        parsed = FinancialSettlementResponse.model_validate(rec)
        self.assertIsNone(parsed.status)
        self.assertIsNone(parsed.created_by)
        self.assertIsNone(parsed.updated_by)
        self.assertIsNone(parsed.created_at)
        self.assertIsNone(parsed.updated_at)
        self.assertIsNone(parsed.is_active)

        # list_settlements_service returns this record
        items = list_settlements_service(self.db, include_inactive=True)
        legacy = next(r for r in items if r.settlement_code == "LCS-LEGACY-001")
        resp = FinancialSettlementResponse.model_validate(legacy)
        self.assertIsNone(resp.status)

    def test_duplicate_settlement_create_raises_409(self):
        """Duplicate settlement creation returns 409 SETTLEMENT_DUPLICATE_ACTIVE (BE09-T12)."""
        from fastapi import HTTPException
        schema = FinancialSettlementCreate(import_file_id=self.import_file_id)
        first = create_settlement_service(self.db, schema)
        self.assertIsNotNone(first)

        with self.assertRaises(HTTPException) as ctx:
            create_settlement_service(self.db, schema)
        self.assertEqual(ctx.exception.status_code, 409)
        self.assertEqual(ctx.exception.detail.get("code"), "SETTLEMENT_DUPLICATE_ACTIVE")
        self.assertEqual(ctx.exception.detail.get("settlement_code"), first.settlement_code)

    def test_list_settlements_pagination_skip_limit(self):
        """list_settlements supports skip and limit parameters (BE09-T12)."""
        # Create additional files and settlements to test pagination
        for i in range(3):
            imp_file = ImportFile(
                import_file_code=f"IMP-FILE-PAG-{i}",
                company_id=1,
                company_name="Delta Industrial Co",
                supplier_name="Global Heavy Equipment Ltd",
            )
            self.db.add(imp_file)
            self.db.commit()
            self.db.refresh(imp_file)
            schema = FinancialSettlementCreate(import_file_id=imp_file.import_file_id)
            create_settlement_service(self.db, schema)

        all_records = list_settlements_service(self.db, include_inactive=True)
        self.assertGreaterEqual(len(all_records), 3)

        limit1 = list_settlements_service(self.db, include_inactive=True, limit=1)
        self.assertEqual(len(limit1), 1)
        self.assertEqual(limit1[0].settlement_id, all_records[0].settlement_id)

        skip1 = list_settlements_service(self.db, include_inactive=True, skip=1, limit=1)
        self.assertEqual(len(skip1), 1)
        self.assertEqual(skip1[0].settlement_id, all_records[1].settlement_id)

    def test_acc2_t02_code_first_expense_classification(self):
        """ACC2-T02: Code-first classification for the 7 clearance codes."""
        from modules.common.enum_codes import CLEARANCE_EXPENSE_CATEGORY, label_en
        from modules.financial_settlement.model import CLEARANCE_CATEGORY_BUCKET
        from modules.financial_settlement.service import actual_expense_bucket

        for code, expected_bucket in CLEARANCE_CATEGORY_BUCKET.items():
            en_label = label_en(CLEARANCE_EXPENSE_CATEGORY, code)
            self.assertEqual(actual_expense_bucket(code, "BROKER"), expected_bucket, f"Failed for code {code}")
            self.assertEqual(actual_expense_bucket(en_label, "BROKER"), expected_bucket, f"Failed for en {en_label}")
            self.assertEqual(actual_expense_bucket(f"Clearance / {en_label}"), expected_bucket)

    def test_acc2_t02_clo02_port_dues_clearance_bucket_value_based(self):
        """ACC2-T02: CLO-02 with PORT_DUES_WHARFAGE allocated as Clearance & Port (not Freight) by Value-Based."""
        from modules.financial_settlement.service import (
            calculate_actual_landed_cost_service,
            confirm_invoices_settlement_service,
        )
        from modules.financial_settlement.schemas import (
            ActualLandedCostCalculationRequest,
            ConfirmInvoicesSettlementRequest,
        )
        from modules.purchase_orders.model import PurchaseOrder, POLineItem
        from modules.customs_clearance.model import CustomsClearanceRecord, ClearanceExpenseInvoice

        imp = ImportFile(
            import_file_code="IMP-ACC2-T02-01",
            company_id=1,
            company_name="Test Company",
            supplier_name="Test Supplier",
        )
        self.db.add(imp)
        self.db.commit()
        self.db.refresh(imp)

        egp_curr = self.db.query(Currency).filter(Currency.currency_code == "EGP").first()
        if not egp_curr:
            egp_curr = Currency(currency_code="EGP", currency_name="Egyptian Pound", currency_symbol="EGP", is_active=True)
            self.db.add(egp_curr)
            self.db.flush()

        po = PurchaseOrder(
            po_number="PO-ACC2-02",
            import_file_id=imp.import_file_id,
            company_id=1,
            supplier_id=1,
            project_id=1,
            incoterm_id=1,
            currency_id=egp_curr.currency_id,
            total_amount_fob=100000.0,
            exchange_rate=1.0,
        )
        self.db.add(po)
        self.db.commit()
        self.db.refresh(po)

        item_a = POLineItem(
            po_id=po.po_id,
            item_code="ITM-A",
            description_ar="بند أ",
            description_en="Item A",
            quantity=1.0,
            unit_price=90000.0,
            total_price=90000.0,
            total_cbm=1.0,
            gross_weight_kg=100.0,
        )
        item_b = POLineItem(
            po_id=po.po_id,
            item_code="ITM-B",
            description_ar="بند ب",
            description_en="Item B",
            quantity=1.0,
            unit_price=10000.0,
            total_price=10000.0,
            total_cbm=9.0,
            gross_weight_kg=900.0,
        )
        self.db.add_all([item_a, item_b])
        self.db.commit()

        cl = CustomsClearanceRecord(
            clearance_code="CLR-ACC2-02",
            import_file_id=imp.import_file_id,
            broker_name="Broker Express",
            actual_duty_total=0.0,
        )
        self.db.add(cl)
        self.db.commit()
        self.db.refresh(cl)

        inv = ClearanceExpenseInvoice(
            invoice_code="INV-CLR-ACC2-01",
            import_file_id=imp.import_file_id,
            customs_clearance_id=cl.customs_clearance_id,
            provider_name="Broker Express",
            invoice_number="INV-PORT-01",
            expense_category="PORT_DUES_WHARFAGE",
            amount_egp=10000.0,
            currency="EGP",
            payment_status="Paid",
            is_active=True,
        )
        self.db.add(inv)
        self.db.commit()

        confirm_invoices_settlement_service(
            self.db,
            ConfirmInvoicesSettlementRequest(import_file_id=imp.import_file_id),
            actor="test_user",
        )

        calc = calculate_actual_landed_cost_service(
            self.db,
            imp.import_file_id,
            ActualLandedCostCalculationRequest(allocation_preference="Value-Based"),
        )

        item_res_a = next(i for i in calc.items_breakdown if i.item_code == "ITM-A")
        item_res_b = next(i for i in calc.items_breakdown if i.item_code == "ITM-B")
        self.assertEqual(item_res_a.allocated_clearance_egp, 9000.0)
        self.assertEqual(item_res_a.allocated_freight_egp, 0.0)
        self.assertEqual(item_res_b.allocated_clearance_egp, 1000.0)
        self.assertEqual(item_res_b.allocated_freight_egp, 0.0)

    def test_acc2_t03_declaration_46_component_splitting(self):
        """
        ACC2-T03: Customs Declaration 46 Duty Component Splitting.
        Validates:
        - Declaration 46 with components (100k duty, 120k vat, 15k sched tax, 10k dev fee, 5k svc fees = 250k)
        - aggregate_shipment_invoices_service populates components on the AggregatedInvoiceItemSchema
        - calculate_actual_landed_cost_service splits actual expenses into Customs Duty (100k) and VAT & Taxes (150k)
        - approve_actual_landed_cost_service records itemized expense rows for each duty component.
        """
        from modules.financial_settlement.service import (
            aggregate_shipment_invoices_service,
            calculate_actual_landed_cost_service,
            approve_actual_landed_cost_service,
        )
        from modules.financial_settlement.schemas import (
            ActualLandedCostCalculationRequest,
            ApproveActualLandedCostRequest,
        )

        imp = ImportFile(
            import_file_code="IMP-DEC46-03",
            company_name="Alpha Tech Imports",
            supplier_name="Global Supplier Co.",
            status="OPEN",
            is_active=True,
        )
        self.db.add(imp)
        self.db.commit()
        self.db.refresh(imp)

        egp_curr = self.db.query(Currency).filter(Currency.currency_code == "EGP").first()
        if not egp_curr:
            egp_curr = Currency(currency_code="EGP", currency_name="Egyptian Pound", currency_symbol="EGP", is_active=True)
            self.db.add(egp_curr)
            self.db.flush()

        po = PurchaseOrder(
            po_number="PO-DEC46-03",
            import_file_id=imp.import_file_id,
            company_id=1,
            supplier_id=1,
            project_id=1,
            incoterm_id=1,
            currency_id=egp_curr.currency_id,
            total_amount_fob=100000.0,
            exchange_rate=1.0,
        )
        self.db.add(po)
        self.db.commit()
        self.db.refresh(po)

        item = POLineItem(
            po_id=po.po_id,
            item_code="ITM-D46",
            description_ar="وحدة تصنيع",
            description_en="Manufacturing Unit",
            quantity=1.0,
            unit_price=100000.0,
            total_price=100000.0,
        )
        self.db.add(item)
        self.db.commit()

        cl = CustomsClearanceRecord(
            clearance_code="CLR-DEC46-03",
            import_file_id=imp.import_file_id,
            broker_name="Customs Broker Express",
            declaration_46_no="DEC-46-88899",
            actual_duty_total=250000.0,
            import_duty_amount=100000.0,
            vat_amount=120000.0,
            schedule_tax_amount=15000.0,
            development_fee_amount=10000.0,
            customs_service_fees=5000.0,
            duty_paid_amount=250000.0,
        )
        self.db.add(cl)
        self.db.commit()
        self.db.refresh(cl)

        # 1. Test Aggregation (CLO-01)
        agg = aggregate_shipment_invoices_service(self.db, imp.import_file_id)
        cust_inv = next(inv for inv in agg.invoices if inv.invoice_id == f"CUST-{cl.customs_clearance_id}")
        self.assertEqual(len(cust_inv.components), 5)
        comp_map = {c.component: c.amount_egp for c in cust_inv.components}
        self.assertEqual(comp_map["import_duty_amount"], 100000.0)
        self.assertEqual(comp_map["vat_amount"], 120000.0)
        self.assertEqual(comp_map["schedule_tax_amount"], 15000.0)
        self.assertEqual(comp_map["development_fee_amount"], 10000.0)
        self.assertEqual(comp_map["customs_service_fees"], 5000.0)

        # 2. Test Calculation (CLO-02)
        calc = calculate_actual_landed_cost_service(
            self.db,
            imp.import_file_id,
            ActualLandedCostCalculationRequest(allocation_preference="Value-Based"),
        )
        cats = {c.category: c.actual_egp for c in calc.categories_breakdown}
        self.assertEqual(cats["Customs Duty"], 100000.0)
        self.assertEqual(cats["VAT & Taxes"], 150000.0)

        # 3. Test Approval
        approve_res = approve_actual_landed_cost_service(
            self.db,
            ApproveActualLandedCostRequest(
                import_file_id=imp.import_file_id,
                allocation_preference="Value-Based",
                notes="Approved test declaration 46 components",
            ),
            actor="test_officer",
        )
        from modules.financial_settlement.service import get_settlement_by_import_file_id
        settlement = get_settlement_by_import_file_id(self.db, imp.import_file_id)
        self.assertIsNotNone(settlement)
        comp_expenses = [e for e in settlement.expense_invoices if e.get("duty_component")]
        self.assertEqual(len(comp_expenses), 5)
        duty_expense = next(e for e in comp_expenses if e["duty_component"] == "import_duty_amount")
        self.assertEqual(duty_expense["amount_egp"], 100000.0)
        self.assertEqual(duty_expense["bucket"], "Customs Duty")
        vat_expense = next(e for e in comp_expenses if e["duty_component"] == "vat_amount")
        self.assertEqual(vat_expense["amount_egp"], 120000.0)
        self.assertEqual(vat_expense["bucket"], "VAT & Taxes")

    def test_acc2_t09_bp038_allocation_basis_completeness(self):
        """
        ACC2-T09: Allocation bases per BP-038 with a completeness rule.
        Validates:
        1. When items A (CBM 10, FOB 60k) and B (CBM 0, FOB 40k) have a missing CBM on B:
           - Ocean freight 20,000 EGP intended Volume-Based falls back to Value-Based
           - Rule reported is Value-Based
           - Allocated freight: A gets 12,000.00, B gets 8,000.00 (not A 20k, B 0)
           - Message ALLOCATION_BASIS_INCOMPLETE emitted naming ITM-B.
        2. When both items have CBM (A 10, B 30):
           - Demurrage 4,000 EGP allocates Volume-Based: A gets 1,000.00, B gets 3,000.00.
        """
        from modules.financial_settlement.service import (
            calculate_actual_landed_cost_service,
            confirm_invoices_settlement_service,
        )
        from modules.financial_settlement.schemas import (
            ActualLandedCostCalculationRequest,
            ConfirmInvoicesSettlementRequest,
        )
        from modules.customs_clearance.model import ClearanceExpenseInvoice

        # 1. Incomplete CBM scenario: Item A CBM 10, Item B CBM 0
        imp1 = ImportFile(
            import_file_code="IMP-BP038-01",
            company_name="BP038 Test Co.",
            supplier_name="Global Shipper",
            shipment_mode="Sea FCL",
            status="OPEN",
            is_active=True,
        )
        self.db.add(imp1)
        self.db.commit()
        self.db.refresh(imp1)

        egp_curr = self.db.query(Currency).filter(Currency.currency_code == "EGP").first()
        if not egp_curr:
            egp_curr = Currency(currency_code="EGP", currency_name="Egyptian Pound", currency_symbol="EGP", is_active=True)
            self.db.add(egp_curr)
            self.db.flush()

        po1 = PurchaseOrder(
            po_number="PO-BP038-01",
            import_file_id=imp1.import_file_id,
            company_id=1,
            supplier_id=1,
            project_id=1,
            incoterm_id=1,
            currency_id=egp_curr.currency_id,
            total_amount_fob=100000.0,
            exchange_rate=1.0,
        )
        self.db.add(po1)
        self.db.commit()
        self.db.refresh(po1)

        item1_a = POLineItem(
            po_id=po1.po_id,
            item_code="ITM-A",
            description_ar="صنف أ",
            description_en="Item A",
            quantity=1.0,
            unit_price=60000.0,
            total_price=60000.0,
            total_cbm=10.0,
            gross_weight_kg=100.0,
        )
        item1_b = POLineItem(
            po_id=po1.po_id,
            item_code="ITM-B",
            description_ar="صنف ب",
            description_en="Item B",
            quantity=1.0,
            unit_price=40000.0,
            total_price=40000.0,
            total_cbm=0.0,  # Missing CBM!
            gross_weight_kg=100.0,
        )
        self.db.add_all([item1_a, item1_b])
        self.db.commit()

        # Freight invoice: 20,000 EGP
        cl1 = CustomsClearanceRecord(
            clearance_code="CLR-BP038-01",
            import_file_id=imp1.import_file_id,
            broker_name="Broker Sea",
            actual_duty_total=0.0,
        )
        self.db.add(cl1)
        self.db.commit()
        self.db.refresh(cl1)

        freight_inv = ClearanceExpenseInvoice(
            invoice_code="INV-FRT-BP038-01",
            import_file_id=imp1.import_file_id,
            customs_clearance_id=cl1.customs_clearance_id,
            provider_name="Sea Shipping Line",
            invoice_number="FRT-01",
            expense_category="OCEAN_FREIGHT",
            amount_egp=20000.0,
            currency="EGP",
            payment_status="Paid",
            is_active=True,
        )
        self.db.add(freight_inv)
        self.db.commit()

        confirm_invoices_settlement_service(
            self.db,
            ConfirmInvoicesSettlementRequest(import_file_id=imp1.import_file_id),
            actor="test_user",
        )

        calc1 = calculate_actual_landed_cost_service(
            self.db,
            imp1.import_file_id,
            ActualLandedCostCalculationRequest(allocation_preference="Value-Based"),
        )

        frt_cat = next(c for c in calc1.categories_breakdown if c.category == "Freight")
        self.assertEqual(frt_cat.allocation_rule, "Value-Based")
        res_a = next(i for i in calc1.items_breakdown if i.item_code == "ITM-A")
        res_b = next(i for i in calc1.items_breakdown if i.item_code == "ITM-B")
        self.assertEqual(res_a.allocated_freight_egp, 12000.0)
        self.assertEqual(res_b.allocated_freight_egp, 8000.0)

        incomplete_msgs = [m for m in calc1.messages if m.code == "ALLOCATION_BASIS_INCOMPLETE"]
        self.assertTrue(len(incomplete_msgs) > 0)
        frt_msg = next(m for m in incomplete_msgs if m.params.get("bucket") == "Freight")
        self.assertIn("ITM-B", frt_msg.params.get("item_codes", ""))

        # 2. Complete CBM scenario: Item A CBM 10, Item B CBM 30, Demurrage 4,000
        imp2 = ImportFile(
            import_file_code="IMP-BP038-02",
            company_name="BP038 Test Co. 2",
            supplier_name="Global Shipper 2",
            shipment_mode="Sea FCL",
            status="OPEN",
            is_active=True,
        )
        self.db.add(imp2)
        self.db.commit()
        self.db.refresh(imp2)

        po2 = PurchaseOrder(
            po_number="PO-BP038-02",
            import_file_id=imp2.import_file_id,
            company_id=1,
            supplier_id=1,
            project_id=1,
            incoterm_id=1,
            currency_id=egp_curr.currency_id,
            total_amount_fob=100000.0,
            exchange_rate=1.0,
        )
        self.db.add(po2)
        self.db.commit()
        self.db.refresh(po2)

        item2_a = POLineItem(
            po_id=po2.po_id,
            item_code="ITM-A2",
            description_ar="صنف أ2",
            description_en="Item A2",
            quantity=1.0,
            unit_price=50000.0,
            total_price=50000.0,
            total_cbm=10.0,
            gross_weight_kg=100.0,
        )
        item2_b = POLineItem(
            po_id=po2.po_id,
            item_code="ITM-B2",
            description_ar="صنف ب2",
            description_en="Item B2",
            quantity=1.0,
            unit_price=50000.0,
            total_price=50000.0,
            total_cbm=30.0,
            gross_weight_kg=300.0,
        )
        self.db.add_all([item2_a, item2_b])
        self.db.commit()

        cl2 = CustomsClearanceRecord(
            clearance_code="CLR-BP038-02",
            import_file_id=imp2.import_file_id,
            broker_name="Broker Demurrage",
            actual_duty_total=0.0,
        )
        self.db.add(cl2)
        self.db.commit()
        self.db.refresh(cl2)

        dem_inv = ClearanceExpenseInvoice(
            invoice_code="INV-DEM-BP038-02",
            import_file_id=imp2.import_file_id,
            customs_clearance_id=cl2.customs_clearance_id,
            provider_name="Port Authority",
            invoice_number="DEM-01",
            expense_category="STORAGE_DEMURRAGE",
            amount_egp=4000.0,
            currency="EGP",
            payment_status="Paid",
            is_active=True,
        )
        self.db.add(dem_inv)
        self.db.commit()

        confirm_invoices_settlement_service(
            self.db,
            ConfirmInvoicesSettlementRequest(import_file_id=imp2.import_file_id),
            actor="test_user",
        )

        calc2 = calculate_actual_landed_cost_service(
            self.db,
            imp2.import_file_id,
            ActualLandedCostCalculationRequest(allocation_preference="Value-Based"),
        )

        dem_cat = next(c for c in calc2.categories_breakdown if c.category == "Demurrage & Storage")
        self.assertEqual(dem_cat.allocation_rule, "Volume-Based")
        res2_a = next(i for i in calc2.items_breakdown if i.item_code == "ITM-A2")
        res2_b = next(i for i in calc2.items_breakdown if i.item_code == "ITM-B2")
        # 10 / 40 * 4000 = 1000, 30 / 40 * 4000 = 3000
        self.assertEqual(res2_a.allocated_demurrage_egp, 1000.0)
        self.assertEqual(res2_b.allocated_demurrage_egp, 3000.0)

    def test_acc2_t10_pl08_estimate_reconciles_with_lines(self):
        from unittest.mock import patch, MagicMock

        # Create PO with 1 line item
        curr = self.db.query(Currency).first()
        if not curr:
            curr = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$")
            self.db.add(curr)
            self.db.commit()
            self.db.add(ExchangeRate(currency_id=curr.currency_id, commercial_rate=50.0, customs_rate=50.0,
                                     effective_date=date(2020, 1, 1), is_active=True))
            self.db.commit()

        tariff = CustomsTariff(
            hs_code="8415.10.00",
            hs_description="Air conditioners",
            customs_duty_rate=Decimal("10.00"),
            vat_rate=Decimal("14.00"),
            schedule_tax_rate=Decimal("0.00"),
            development_fee_rate=Decimal("0.00"),
            import_fee_rate=Decimal("0.00"),
            customs_service_fee_rate=Decimal("0.00"),
            is_active=True,
        )
        self.db.add(tariff)
        self.db.commit()

        proj = self.db.query(Project).first()
        if not proj:
            proj = Project(
                project_code="PRJ-PL08-T10",
                project_name="Test Project",
                project_owner="Owner",
                company_id=1,
                supplier_id=1,
                incoterm_id=1,
                is_active=True,
            )
            self.db.add(proj)
            self.db.commit()

        po = PurchaseOrder(
            po_number="PO-PL08-T10",
            import_file_id=self.import_file_id,
            project_id=proj.project_id,
            company_id=1,
            supplier_id=1,
            incoterm_id=1,
            currency_id=curr.currency_id,
            total_amount_fob=10000.0,
            is_active=True,
        )
        self.db.add(po)
        self.db.commit()

        po_item = POLineItem(
            po_id=po.po_id,
            item_code="ITM-T10",
            description_ar="تكييف",
            tariff_id=tariff.tariff_id,
            quantity=100.0,
            unit_price=100.0,
            total_price=10000.0,
            cbm_per_unit=0.1,
            total_cbm=10.0,
            gross_weight_kg=1000.0,
            net_weight_kg=900.0,
        )
        self.db.add(po_item)
        self.db.commit()

        mock_breakdown = MagicMock()
        mock_breakdown.total_duty_egp = Decimal("10000.00")
        mock_breakdown.total_vat_egp = Decimal("15000.00")
        mock_breakdown.total_schedule_tax_egp = Decimal("0.00")
        mock_breakdown.total_customs_service_fee_egp = Decimal("500.00")
        mock_breakdown.total_development_fee_egp = Decimal("300.00")
        mock_breakdown.total_import_fee_egp = Decimal("0.00")
        mock_breakdown.total_inspection_fees_egp = Decimal("200.00")
        mock_breakdown.items_taxes_total_egp = Decimal("26000.00")

        mock_line = MagicMock()
        mock_line.line_no = 1
        mock_line.duty_egp = Decimal("10000.00")
        mock_line.vat_egp = Decimal("15000.00")
        mock_line.schedule_tax_egp = Decimal("0.00")
        mock_line.customs_service_fee_egp = Decimal("500.00")
        mock_line.development_fee_egp = Decimal("300.00")
        mock_line.import_fee_egp = Decimal("0.00")
        mock_line.inspection_fee_egp = Decimal("200.00")
        mock_breakdown.lines = [mock_line]

        with patch("modules.customs_tariff.service.estimate_multi_item_customs_duty_service", return_value=mock_breakdown):
            sim = simulate_estimated_landed_cost_service(self.db, self.import_file_id)

        # 1. "VAT & Taxes" line amount = total_taxes_and_fees_egp - total_customs_duty_egp = 26,000 - 10,000 = 16,000.00
        vat_line = next(e for e in sim.expenses_breakdown if e.category == "VAT & Taxes")
        self.assertEqual(vat_line.amount_egp, 16000.0)
        self.assertEqual(sim.total_vat_and_fees_egp, 16000.0)

        # 2. Items customs sum = alloc_duty + alloc_vat = 10,000 + 16,000 = 26,000.00
        item = sim.items_breakdown[0]
        self.assertEqual(item.allocated_customs_duty_egp, 10000.0)
        self.assertEqual(item.allocated_vat_egp, 16000.0)
        self.assertEqual(item.allocated_customs_duty_egp + item.allocated_vat_egp, 26000.0)

        # 3. Currency of every expense line is the goods currency (USD)
        for exp in sim.expenses_breakdown:
            self.assertEqual(exp.currency, sim.currency, f"Expense {exp.category} currency {exp.currency} != {sim.currency}")

        # 4. Reconciliation acceptance criteria:
        # sum(expenses_breakdown.amount_egp) == total_expenses_egp
        # sum(items.total_landed_cost_egp) == total_landed_cost_egp
        sum_expenses = round(sum(e.amount_egp for e in sim.expenses_breakdown), 2)
        self.assertAlmostEqual(sum_expenses, sim.total_expenses_egp, delta=0.01 * len(sim.expenses_breakdown))
        sum_items_landed = round(sum(i.total_landed_cost_egp for i in sim.items_breakdown), 2)
        self.assertAlmostEqual(sum_items_landed, sim.total_landed_cost_egp, delta=0.01 * len(sim.items_breakdown))

    def test_acc2_t11_no_invented_currency_in_estimate_and_aggregation(self):
        """ACC2-T11: No invented currency in estimate / aggregation.
        - invoices_data=[{"invoice_no": "CI-1", "amount": 10000}] without currency -> CLO-01 raises 409 SETTLEMENT_CURRENCY_MISSING with invoice_no CI-1.
        - with "currency": "EUR" and EUR commercial rate 52.80 -> CLO-01 computes 528,000.00 EGP, currency is "EUR", exchange_rate is 52.80.
        - file without goods (invoices_data=[], estimated_cost=None) -> CLO-01 returns currency is None, exchange_rate is 0.0 (no "USD" invented).
        """
        from fastapi import HTTPException
        from modules.financial_settlement.service import aggregate_shipment_invoices_service
        from modules.currencies.model import Currency, ExchangeRate

        # Set up base currency (EGP)
        egp = Currency(currency_code="EGP", currency_name="Egyptian Pound", currency_symbol="EGP", is_base_currency=True, is_active=True)
        self.db.add(egp)
        self.db.flush()

        imp_file = self.db.get(ImportFile, self.import_file_id)

        # 1. Invoice with amount > 0 and no currency -> 409 SETTLEMENT_CURRENCY_MISSING
        imp_file.invoices_data = [{"invoice_no": "CI-1", "amount": 10000}]
        self.db.commit()

        with self.assertRaises(HTTPException) as ctx:
            aggregate_shipment_invoices_service(self.db, self.import_file_id)
        self.assertEqual(ctx.exception.status_code, 409)
        self.assertEqual(ctx.exception.detail.get("code"), "SETTLEMENT_CURRENCY_MISSING")
        self.assertEqual(ctx.exception.detail.get("invoice_no"), "CI-1")

        # 2. Add EUR currency and exchange rate 52.80
        eur = Currency(currency_code="EUR", currency_name="Euro", currency_symbol="€", is_active=True)
        self.db.add(eur)
        self.db.flush()
        rate_eur = ExchangeRate(
            currency_id=eur.currency_id,
            commercial_rate=52.80,
            customs_rate=52.80,
            effective_date=date.today(),
        )
        self.db.add(rate_eur)
        self.db.commit()

        # Update invoice with currency="EUR"
        imp_file.invoices_data = [{"invoice_no": "CI-1", "amount": 10000, "currency": "EUR"}]
        self.db.commit()

        agg = aggregate_shipment_invoices_service(self.db, self.import_file_id)
        self.assertEqual(agg.currency, "EUR")
        self.assertEqual(agg.exchange_rate, 52.80)
        self.assertEqual(len(agg.invoices), 1)
        self.assertEqual(agg.invoices[0].amount_egp, 528000.0)
        self.assertEqual(agg.total_amount_egp, 528000.0)

        # 3. File without goods (no invoices_data, estimated_cost=0.0, no POs)
        imp_file.invoices_data = []
        imp_file.estimated_cost = 0.0
        self.db.commit()

        agg_empty = aggregate_shipment_invoices_service(self.db, self.import_file_id)
        self.assertIsNone(agg_empty.currency)
        self.assertEqual(agg_empty.exchange_rate, 0.0)


if __name__ == "__main__":
    unittest.main()


