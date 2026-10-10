"""
Unit Tests: Partner Statement of Account Multi-Currency, FX Conversion & Matching
==================================================================================
Tests PR #88 Review Items 23, 24, 25:
1. Rate present gives correct equivalent.
2. Rate missing returns None and a warning, never hard-coded 50.0 or 1.0.
3. CL-05 + settlement counts invoice once (no duplicate counting).
4. Empty partner name matches nothing by name fallback.
5. Currency bucketing: amount_fx > 0 books under currency, otherwise amount_egp under EGP.
"""

from datetime import date
import unittest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.common.clock import cairo_today
import modules.audit_logs.model
import modules.transport_locations.model
import modules.import_companies.model
import modules.suppliers.model
import modules.incoterms.model
import modules.currencies.model
import modules.customs_tariff.model
import modules.projects.model
import modules.purchase_orders.model
import modules.import_files.model
import modules.shipping_scenarios.model
import modules.freight_quotations.model
import modules.customs_consultation.model
import modules.financial_approval.model
import modules.import_documentation.model
import modules.freight_booking.model
import modules.cargo_shipping.model
import modules.customs_clearance.model
import modules.warehouse_receiving.model
import modules.financial_settlement.model
import modules.file_closure.model

from modules.currencies.model import Currency, ExchangeRate
from modules.external_service_providers.model import ExternalServiceProvider
from modules.external_service_providers.service import ExternalServiceProviderService
from modules.customs_clearance.model import ClearanceExpenseInvoice
from modules.financial_settlement.model import LandedCostSettlementRecord
from modules.import_files.model import ImportFile


class TestPartnerStatementOfAccountFX(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=self.engine)
        Base.metadata.create_all(bind=self.engine)
        self.db = TestingSessionLocal()
        self.service = ExternalServiceProviderService(self.db)

        # Create base import file
        imp = ImportFile(
            import_file_code="IMP-2026-0001",
            company_name="Al-Sorour Trading",
            supplier_name="Global Steel Corp",
            status="Draft",
            is_active=True,
        )
        self.db.add(imp)
        self.db.commit()
        self.db.refresh(imp)
        self.import_file_id = imp.import_file_id

    def tearDown(self):
        self.db.close()
        Base.metadata.drop_all(bind=self.engine)

    def _create_partner(self, name: str, ptype: str = "Freight Forwarder") -> ExternalServiceProvider:
        p = ExternalServiceProvider(
            partner_code=self.service.generate_partner_code(),
            partner_name=name,
            partner_type=ptype,
            country="Egypt",
            is_active=True,
        )
        self.db.add(p)
        self.db.commit()
        self.db.refresh(p)
        return p

    def _create_currency(self, code: str, name: str, rate: float | None = None) -> Currency:
        c = Currency(
            currency_code=code,
            currency_name=name,
            currency_symbol=code,
            is_base_currency=(code == "EGP"),
            decimal_places=2,
            is_active=True,
        )
        self.db.add(c)
        self.db.commit()
        self.db.refresh(c)

        if rate is not None:
            r = ExchangeRate(
                currency_id=c.currency_id,
                commercial_rate=rate,
                customs_rate=rate,
                effective_date=cairo_today(),
                is_active=True,
            )
            self.db.add(r)
            self.db.commit()

        return c

    def test_soa_rate_present_gives_correct_equivalent(self):
        """When commercial exchange rate is present, equivalent EGP is calculated correctly."""
        partner = self._create_partner("Apex Ocean Lines", "Shipping Line")
        self._create_currency("USD", "US Dollar", rate=48.5)

        # Log clearance invoice in USD
        cl_inv = ClearanceExpenseInvoice(
            invoice_code="CLI-2026-0001",
            import_file_id=self.import_file_id,
            invoice_number="INV-USD-100",
            provider_id=partner.provider_id,
            provider_name=partner.partner_name,
            expense_category="Ocean Freight",
            currency="USD",
            amount_fx=1000.0,
            amount_egp=0.0,
            invoice_date=cairo_today(),
            is_active=True,
        )
        self.db.add(cl_inv)
        self.db.commit()

        soa = self.service.get_partner_statement_of_account(partner.provider_id)

        usd_balance = next(b for b in soa["currency_balances"] if b["currency"] == "USD")
        self.assertEqual(usd_balance["total_invoiced"], 1000.0)
        self.assertEqual(usd_balance["exchange_rate_used"], 48.5)
        self.assertEqual(usd_balance["equivalent_egp"], 48500.0)
        self.assertEqual(usd_balance["rate_type"], "commercial")
        self.assertIsNone(usd_balance["warning"])
        self.assertEqual(soa["equivalent_egp_total"], 48500.0)
        self.assertFalse(soa["has_unconverted_balances"])

    def test_soa_rate_missing_returns_none_and_warning(self):
        """When exchange rate is missing, rate is None, equivalent is None, warning is returned, NO hardcoded fallback."""
        partner = self._create_partner("Bremen Logistics", "Freight Forwarder")
        # Create EUR with NO exchange rate in the database
        self._create_currency("EUR", "Euro", rate=None)

        cl_inv = ClearanceExpenseInvoice(
            invoice_code="CLI-2026-0002",
            import_file_id=self.import_file_id,
            invoice_number="INV-EUR-200",
            provider_id=partner.provider_id,
            provider_name=partner.partner_name,
            expense_category="Terminal Handling",
            currency="EUR",
            amount_fx=500.0,
            amount_egp=0.0,
            invoice_date=cairo_today(),
            is_active=True,
        )
        self.db.add(cl_inv)
        self.db.commit()

        soa = self.service.get_partner_statement_of_account(partner.provider_id)

        eur_balance = next(b for b in soa["currency_balances"] if b["currency"] == "EUR")
        self.assertEqual(eur_balance["total_invoiced"], 500.0)
        # CRITICAL: Must be None, NEVER hardcoded 54.5, 50.0, or 1.0!
        self.assertIsNone(eur_balance["exchange_rate_used"])
        self.assertIsNone(eur_balance["equivalent_egp"])
        self.assertIsNotNone(eur_balance["warning"])
        self.assertIn("EUR", eur_balance["warning"])
        # Total equivalent cannot be computed completely when a non-zero balance is unconverted
        self.assertIsNone(soa["equivalent_egp_total"])
        self.assertTrue(soa["has_unconverted_balances"])

    def test_soa_cl05_and_settlement_counts_invoice_once(self):
        """An invoice present in both CL-05 and settlement expense_invoices must only be counted once."""
        partner = self._create_partner("Alexandria Customs Brokerage", "Customs Broker")

        # 1. Invoice in CL-05 ClearanceExpenseInvoice
        cl_inv = ClearanceExpenseInvoice(
            invoice_code="CLI-2026-0003",
            import_file_id=self.import_file_id,
            invoice_number="INV-DUP-300",
            provider_id=partner.provider_id,
            provider_name=partner.partner_name,
            expense_category="Customs Clearance Fees",
            currency="EGP",
            amount_fx=0.0,
            amount_egp=7500.0,
            invoice_date=cairo_today(),
            is_active=True,
        )
        self.db.add(cl_inv)

        # 2. Same invoice duplicated into LandedCostSettlementRecord
        settlement = LandedCostSettlementRecord(
            settlement_code="LCS-2026-0001",
            import_file_id=self.import_file_id,
            incoterm_code="CIF",
            expense_invoices=[
                {
                    "invoice_no": "INV-DUP-300",
                    "category": "Customs Clearance Fees",
                    "provider_name": partner.partner_name,
                    "partner_id": partner.provider_id,
                    "currency": "EGP",
                    "amount_egp": 7500.0,
                    "amount_fx": 0.0,
                }
            ],
            is_active=True,
        )
        self.db.add(settlement)
        self.db.commit()

        soa = self.service.get_partner_statement_of_account(partner.provider_id)

        egp_balance = next(b for b in soa["currency_balances"] if b["currency"] == "EGP")
        # Must be 7500.0, NOT 15000.0!
        self.assertEqual(egp_balance["total_invoiced"], 7500.0)
        self.assertEqual(len(soa["ledger_entries"]), 1)

    def test_soa_empty_partner_name_matches_nothing(self):
        """A partner with empty or whitespace name must NEVER match all rows via fallback."""
        partner = self._create_partner("", "Customs Broker")
        other_partner = self._create_partner("Global Logistics Hub", "Freight Forwarder")

        # Create an unlinked clearance invoice (provider_id is None)
        cl_inv = ClearanceExpenseInvoice(
            invoice_code="CLI-2026-0004",
            import_file_id=self.import_file_id,
            invoice_number="INV-OTHER-400",
            provider_id=None,
            provider_name="Some Other Forwarder",
            expense_category="Demurrage",
            currency="EGP",
            amount_egp=12000.0,
            is_active=True,
        )
        self.db.add(cl_inv)
        self.db.commit()

        soa = self.service.get_partner_statement_of_account(partner.provider_id)

        egp_balance = next(b for b in soa["currency_balances"] if b["currency"] == "EGP")
        self.assertEqual(egp_balance["total_invoiced"], 0.0)
        self.assertEqual(len(soa["ledger_entries"]), 0)

    def test_soa_currency_bucketing_fx_vs_egp(self):
        """When amount_fx is 0 or None, amount_egp must be booked under EGP, not foreign currency."""
        partner = self._create_partner("Red Sea Shipping", "Shipping Line")

        # Invoice logged with currency="USD" but amount_fx=0 and amount_egp=5000
        cl_inv = ClearanceExpenseInvoice(
            invoice_code="CLI-2026-0005",
            import_file_id=self.import_file_id,
            invoice_number="INV-MIX-500",
            provider_id=partner.provider_id,
            provider_name=partner.partner_name,
            expense_category="Local Surcharge",
            currency="USD",
            amount_fx=0.0,
            amount_egp=5000.0,
            is_active=True,
        )
        self.db.add(cl_inv)
        self.db.commit()

        soa = self.service.get_partner_statement_of_account(partner.provider_id)

        usd_balance = next(b for b in soa["currency_balances"] if b["currency"] == "USD")
        egp_balance = next(b for b in soa["currency_balances"] if b["currency"] == "EGP")

        # Crucial fix: 5000 is booked under EGP, NOT USD!
        self.assertEqual(usd_balance["total_invoiced"], 0.0)
        self.assertEqual(egp_balance["total_invoiced"], 5000.0)

    def test_scorecard_default_free_days_not_invented(self):
        """When default_free_days is None, scorecard must NOT invent 14 days or give fake 95% score."""
        partner = self._create_partner("Hapag-Lloyd", "Shipping Line")
        partner.default_free_days = None
        self.db.commit()

        card = self.service.get_partner_scorecard(partner.provider_id)
        free_days_crit = next(c for c in card.criteria_breakdown if "Demurrage" in c["criterion_name_en"])

        self.assertEqual(free_days_crit["score_achieved"], 0.0)
        self.assertIn("غير محددة", free_days_crit["data_source_ar"])

    def test_scorecard_customs_broker_zero_clearances_not_invented(self):
        """When a broker has zero clearances, scorecard must report 0 completed jobs and no fake jobs/rates."""
        partner = self._create_partner("New Cairo Clearance Broker", "Customs Broker")

        card = self.service.get_partner_scorecard(partner.provider_id)

        self.assertEqual(card.total_jobs_completed, 0)
        self.assertIsNone(card.average_clearance_days)
        self.assertIsNone(card.green_channel_rate)
        turnaround_crit = next(c for c in card.criteria_breakdown if "Turnaround" in c["criterion_name_en"])
        channel_crit = next(c for c in card.criteria_breakdown if "Green Channel" in c["criterion_name_en"])
        self.assertEqual(turnaround_crit["score_achieved"], 0.0)
        self.assertEqual(channel_crit["score_achieved"], 0.0)


if __name__ == "__main__":
    unittest.main()
