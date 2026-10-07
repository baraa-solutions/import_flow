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


if __name__ == "__main__":
    unittest.main()

