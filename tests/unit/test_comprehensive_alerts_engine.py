"""
Unit Tests: Comprehensive Smart Alerts and Real-Time Expiry Engine
Verifies all 9 proactive alert workflows across the ImportFlow ERP lifecycle.
"""

import unittest
from datetime import date, datetime, timezone, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.notifications.service import NotificationService
from modules.import_companies.model import ImportCompany
from modules.import_documentation.model import AcidRegistrationSession, BankingDocumentSession
from modules.import_files.model import ImportFile
from modules.cargox.model import CargoXEnvelope
from modules.original_documents_collection.model import OriginalDocumentsCollectionSession
from modules.import_requirements.model import ImportRequirementAssessment
from modules.demurrage_detention.model import DemurrageTracking, DemurragePolicy
from modules.financial_settlement.model import LandedCostSettlementRecord
from modules.currencies.model import Currency, ExchangeRate


class TestComprehensiveAlertsEngine(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
        TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=self.engine)
        Base.metadata.create_all(bind=self.engine)
        self.db = TestingSessionLocal()
        self.service = NotificationService(self.db)

    def tearDown(self):
        self.db.close()
        Base.metadata.drop_all(bind=self.engine)

    def test_cargox_upload_watchdog(self):
        file = ImportFile(
            import_file_code="IMP-2026-001",
            company_name="ECO ASSOCIATES",
            supplier_name="Steelcase SAS",
            status="In Progress",
            is_customs_released=False,
            required_eta=date.today() + timedelta(days=3),
        )
        self.db.add(file)
        self.db.commit()

        alerts = self.service.trigger_expiry_check()
        cargox_alerts = [a for a in alerts if a.category == "CARGOX_UPLOAD_PENDING"]
        self.assertEqual(len(cargox_alerts), 1)
        self.assertEqual(cargox_alerts[0].severity, "CRITICAL")
        self.assertIn("CargoX", cargox_alerts[0].title)

        # Ensure no duplicate
        alerts2 = self.service.trigger_expiry_check()
        cargox_alerts2 = [a for a in alerts2 if a.category == "CARGOX_UPLOAD_PENDING"]
        self.assertEqual(len(cargox_alerts2), 0)

    def test_bank_form4_pending_alert(self):
        doc = BankingDocumentSession(
            bank_doc_code="F4-2026-001",
            bank_name="National Bank of Egypt",
            doc_type="Form 4",
            status="Submitted to Bank",
            request_date=date.today() - timedelta(days=10),
        )
        self.db.add(doc)
        self.db.commit()

        alerts = self.service.trigger_expiry_check()
        form4_alerts = [a for a in alerts if a.category == "BANK_FORM4_PENDING"]
        self.assertEqual(len(form4_alerts), 1)
        self.assertEqual(form4_alerts[0].severity, "WARNING")
        self.assertIn("Form 4", form4_alerts[0].title)
        self.assertEqual(form4_alerts[0].msg_code, "NOTIF_FORM4_DELAY")

    def test_empty_container_detention_alert(self):
        tracking = DemurrageTracking(
            port_name="Alexandria",
            tracking_code="DND-2026-001",
            carrier_name="MSC",
            bill_of_lading_no="MEDU12345678",
            discharge_date=date.today() - timedelta(days=12),
            gate_out_date=date.today() - timedelta(days=6),
            empty_return_date=None,
            exchange_rate=50.0,  # no default rate since the review wave (NOT NULL, no fabricated 50.0)
            status="Free Time Active",
        )
        self.db.add(tracking)
        self.db.commit()

        alerts = self.service.trigger_expiry_check()
        detention_alerts = [a for a in alerts if a.category == "CONTAINER_DETENTION_RISK"]
        self.assertEqual(len(detention_alerts), 1)
        self.assertIn("detention", detention_alerts[0].title)
        self.assertEqual(detention_alerts[0].msg_code, "NOTIF_DETENTION_RETURN_DEADLINE")

    def test_courier_tracking_alert(self):
        file = ImportFile(
            import_file_code="IMP-2026-002",
            company_name="ECO ASSOCIATES",
            supplier_name="G.I. Industrial",
            status="In Progress",
            required_eta=date.today() + timedelta(days=2),
        )
        self.db.add(file)
        self.db.commit()

        coll = OriginalDocumentsCollectionSession(
            collection_code="DOC-2026-001",
            import_file_id=file.import_file_id,
            import_file_code=file.import_file_code,
            status="IN_TRANSIT",
        )
        self.db.add(coll)
        self.db.commit()

        alerts = self.service.trigger_expiry_check()
        courier_alerts = [a for a in alerts if a.category == "COURIER_DELAY"]
        self.assertEqual(len(courier_alerts), 1)
        self.assertIn("Original documents", courier_alerts[0].title)
        self.assertEqual(courier_alerts[0].msg_code, "NOTIF_ORIGINALS_COLLECTION_DELAY")

    def test_regulatory_inspection_alert(self):
        assess = ImportRequirementAssessment(
            assessment_code="BP011-2026-001",
            import_file_code="IMP-2026-003",
            hs_code="84158200",
            inspection_required=True,
            inspection_status="Pending",
            permit_issuing_authority="GOEIC",
        )
        self.db.add(assess)
        self.db.commit()

        alerts = self.service.trigger_expiry_check()
        reg_alerts = [a for a in alerts if a.category == "REGULATORY_INSPECTION_PENDING"]
        self.assertEqual(len(reg_alerts), 1)
        self.assertIn("Regulatory", reg_alerts[0].title)
        self.assertEqual(reg_alerts[0].msg_code, "NOTIF_REGULATORY_PENDING")

    def test_budget_variance_alert(self):
        file = ImportFile(
            import_file_code="IMP-2026-004",
            company_name="ECO ASSOCIATES",
            supplier_name="Narbutas",
            status="In Progress",
            estimated_cost=1000.0,
            estimated_cost_currency="USD",
        )
        self.db.add(file)
        self.db.commit()

        rec = LandedCostSettlementRecord(
            settlement_code="LCS-2026-001",
            import_file_id=file.import_file_id,
            total_expenses_egp=65000.0,  # 30% increase over 50,000 EGP
        )
        self.db.add(rec)
        self.db.commit()

        alerts = self.service.trigger_expiry_check()
        budget_alerts = [a for a in alerts if a.category == "BUDGET_VARIANCE"]
        self.assertEqual(len(budget_alerts), 1)
        self.assertEqual(budget_alerts[0].severity, "CRITICAL")
        self.assertIn("budget", budget_alerts[0].title)
        self.assertEqual(budget_alerts[0].msg_code, "NOTIF_BUDGET_OVERRUN")

    def test_currency_fluctuation_alert(self):
        curr = Currency(
            currency_code="USD",
            currency_name="US Dollar",
            currency_symbol="$",
        )
        self.db.add(curr)
        self.db.commit()

        rate_old = ExchangeRate(
            currency_id=curr.currency_id,
            commercial_rate=48.50,
            customs_rate=48.50,
            effective_date=date.today() - timedelta(days=5),
        )
        rate_new = ExchangeRate(
            currency_id=curr.currency_id,
            commercial_rate=51.00,
            customs_rate=51.00,  # > 5% change
            effective_date=date.today(),
        )
        self.db.add_all([rate_old, rate_new])
        self.db.commit()

        alerts = self.service.trigger_expiry_check()
        curr_alerts = [a for a in alerts if a.category == "CURRENCY_FLUCTUATION"]
        self.assertEqual(len(curr_alerts), 1)
        self.assertIn("Customs USD", curr_alerts[0].title)
        self.assertEqual(curr_alerts[0].msg_code, "NOTIF_CUSTOMS_FX_RISE")
        self.assertEqual(curr_alerts[0].msg_params["change_pct"], 5.15)  # absolute; direction is in the code
        self.assertIn("rose by 5.15%", curr_alerts[0].message)

    def test_company_expiry_alerts(self):
        comp = ImportCompany(
            importer_name="ECO ASSOCIATES",
            address="7 Hosni Osman, Cairo",
            country="Egypt",
            importer_id="12345",
            importer_id_expiry=date.today() + timedelta(days=5),  # <= 7 days -> CRITICAL
            vat_id="200183044",
            vat_id_expiry=date.today() + timedelta(days=90),
            registration_number="REG-9988",
            registration_expiry=date.today() + timedelta(days=120),
        )
        self.db.add(comp)
        self.db.commit()

        alerts = self.service.trigger_expiry_check()
        comp_alerts = [a for a in alerts if a.category == "COMPANY_EXPIRY_IMP_ID"]
        self.assertEqual(len(comp_alerts), 1)
        self.assertEqual(comp_alerts[0].severity, "CRITICAL")
