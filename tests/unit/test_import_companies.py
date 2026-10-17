import unittest
from datetime import date, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.import_companies.schemas import ImportCompanyCreate
from modules.import_companies.service import (
    create_import_company,
    get_all_companies,
    delete_import_company,
    restore_import_company,
)
from modules.import_companies.utils import calculate_days_to_renew

class TestImportCompaniesBackend(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
        TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=self.engine)
        Base.metadata.create_all(bind=self.engine)
        self.db = TestingSessionLocal()

    def tearDown(self):
        self.db.close()
        Base.metadata.drop_all(bind=self.engine)

    def test_calculate_days_to_renew(self):
        future_date = date.today() + timedelta(days=45)
        days = calculate_days_to_renew(future_date)
        self.assertEqual(days, 45)

    def test_create_import_company_service(self):
        company_data = ImportCompanyCreate(
            importer_name="Pharaohs Trading Co",
            address="12 Ramses St, Cairo",
            country="Egypt",
            importer_id="IMP-100200",
            importer_id_expiry=date.today() + timedelta(days=120),
            vat_id="VAT-998877",
            vat_id_expiry=date.today() + timedelta(days=90),
            registration_number="REG-554433",
            registration_expiry=date.today() + timedelta(days=60),
        )
        
        created = create_import_company(self.db, company_data)
        self.assertIsNotNone(created.company_id)
        self.assertEqual(created.importer_name, "Pharaohs Trading Co")
        self.assertTrue(created.is_active)

    def test_get_active_companies_filtering(self):
        c1 = create_import_company(self.db, ImportCompanyCreate(
            importer_name="Company A",
            address="Address A",
            country="Egypt",
            importer_id="IMP-A",
            importer_id_expiry=date.today(),
            vat_id="VAT-A",
            vat_id_expiry=date.today(),
            registration_number="REG-A",
            registration_expiry=date.today(),
        ))
        
        companies = get_all_companies(self.db)
        self.assertEqual(len(companies), 1)
        
        # Soft Delete
        delete_import_company(self.db, c1.company_id)
        
        active_companies = get_all_companies(self.db)
        self.assertEqual(len(active_companies), 0)

    def test_restore_company(self):
        c1 = create_import_company(self.db, ImportCompanyCreate(
            importer_name="Company B",
            address="Address B",
            country="Egypt",
            importer_id="IMP-B",
            importer_id_expiry=date.today(),
            vat_id="VAT-B",
            vat_id_expiry=date.today(),
            registration_number="REG-B",
            registration_expiry=date.today(),
        ))
        
        delete_import_company(self.db, c1.company_id)
        restored = restore_import_company(self.db, c1.company_id)
        self.assertTrue(restored.is_active)
        
        active = get_all_companies(self.db)
        self.assertEqual(len(active), 1)

    def test_nafeza_token_encrypted_at_rest_and_audit_sanitized(self):
        from modules.audit_logs.model import AuditLog
        from modules.import_companies.schemas import ImportCompanyResponse, ImportCompanyUpdate
        from modules.import_companies.service import update_import_company

        # 1. Create company with token
        c = create_import_company(self.db, ImportCompanyCreate(
            importer_name="Secure Importer Ltd",
            address="Free Zone, Alexandria",
            country="Egypt",
            importer_id="IMP-SEC-01",
            importer_id_expiry=date.today(),
            vat_id="VAT-SEC-01",
            vat_id_expiry=date.today(),
            registration_number="REG-SEC-01",
            registration_expiry=date.today(),
            nafeza_token="NFT-SECRET-TOKEN-9988",
        ))

        # Check DB column is encrypted
        self.assertIsNotNone(c.nafeza_token)
        self.assertTrue(c.nafeza_token.startswith("enc:"))
        self.assertNotEqual(c.nafeza_token, "NFT-SECRET-TOKEN-9988")
        self.assertTrue(c.has_nafeza_token)
        self.assertEqual(c.masked_nafeza_token, "****9988")

        # Check response schema sanitization
        resp = ImportCompanyResponse.model_validate(c)
        self.assertIsNone(resp.nafeza_token)
        self.assertTrue(resp.has_nafeza_token)
        self.assertEqual(resp.masked_nafeza_token, "****9988")

        # Check audit log does not leak the secret token
        create_audit = self.db.query(AuditLog).filter(
            AuditLog.entity_type == "ImportCompany",
            AuditLog.entity_id == c.company_id,
            AuditLog.action == "CREATE"
        ).first()
        self.assertIsNotNone(create_audit)
        import json
        audit_data = json.loads(create_audit.new_values)
        self.assertNotIn("nafeza_token", audit_data)
        self.assertTrue(audit_data.get("has_nafeza_token"))

        # 2. Update company with new token
        updated = update_import_company(self.db, c.company_id, ImportCompanyUpdate(
            nafeza_token="NFT-UPDATED-KEY-7766"
        ))
        self.assertIsNotNone(updated)
        self.assertTrue(updated.nafeza_token.startswith("enc:"))
        self.assertEqual(updated.masked_nafeza_token, "****7766")

        # Check update audit log
        update_audit = self.db.query(AuditLog).filter(
            AuditLog.entity_type == "ImportCompany",
            AuditLog.entity_id == c.company_id,
            AuditLog.action == "UPDATE"
        ).first()
        self.assertIsNotNone(update_audit)
        upd_new = json.loads(update_audit.new_values)
        self.assertNotIn("nafeza_token", upd_new)
        self.assertTrue(upd_new.get("has_nafeza_token"))


if __name__ == "__main__":
    unittest.main()
