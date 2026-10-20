import unittest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from database.database import Base
from modules.audit_logs.service import AuditLogService
from modules.suppliers.service import create_supplier_service as create_supplier, update_supplier_service as update_supplier, delete_supplier_service as soft_delete_supplier, restore_supplier_service as restore_supplier
from modules.suppliers.schemas import SupplierUpdate, SupplierCreate


class TestAuditLogs(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        TestingSessionLocal = sessionmaker(bind=self.engine)
        self.db = TestingSessionLocal()
        self.audit_service = AuditLogService(self.db)

    def tearDown(self):
        self.db.close()

    def test_log_activity_creation_and_retrieval(self):
        log = self.audit_service.log_activity(
            entity_type="TestEntity",
            entity_id=10,
            entity_code="TEST-001",
            action="CREATE",
            performed_by="Tester",
            new_data={"name": "Test Item"}
        )
        self.assertIsNotNone(log.log_id)
        self.assertEqual(log.entity_type, "TestEntity")
        self.assertEqual(log.action, "CREATE")

        logs = self.audit_service.get_logs_for_entity("TestEntity", 10)
        self.assertEqual(len(logs), 1)
        self.assertEqual(logs[0].entity_code, "TEST-001")

    def test_supplier_crud_generates_audit_logs(self):
        # 1. Create
        supplier_data = {
            "supplier_code": "SUP-999",
            "company_name": "Audit Test Corp",
            "supplier_type": "Manufacturer",
            "registration_type": "Factory",
            "foreign_exporter_id": "EXP-AUDIT-1",
            "foreign_exporter_country": "Germany",
            "foreign_exporter_country_code": "DE",
            "address": "Berlin, Germany",
        }
        sup = create_supplier(self.db, SupplierCreate(**supplier_data))

        logs_after_create = self.audit_service.get_logs_for_entity("Supplier", sup.supplier_id)
        self.assertEqual(len(logs_after_create), 1)
        self.assertEqual(logs_after_create[0].action, "CREATE")

        # 2. Update
        update_data = SupplierUpdate(company_name="Audit Test Corp Updated", address="Frankfurt, Germany")
        update_supplier(self.db, sup.supplier_id, update_data)

        logs_after_update = self.audit_service.get_logs_for_entity("Supplier", sup.supplier_id)
        self.assertEqual(len(logs_after_update), 2)
        self.assertEqual(logs_after_update[0].action, "UPDATE")
        self.assertIn("Audit Test Corp", logs_after_update[0].changes_summary)

        # 3. Soft Delete
        soft_delete_supplier(self.db, sup.supplier_id)
        logs_after_delete = self.audit_service.get_logs_for_entity("Supplier", sup.supplier_id)
        self.assertEqual(len(logs_after_delete), 3)
        self.assertEqual(logs_after_delete[0].action, "DELETE")

        # 4. Restore
        restore_supplier(self.db, sup.supplier_id)
        logs_after_restore = self.audit_service.get_logs_for_entity("Supplier", sup.supplier_id)
        self.assertEqual(len(logs_after_restore), 4)
        self.assertEqual(logs_after_restore[0].action, "RESTORE")


if __name__ == "__main__":
    unittest.main()
