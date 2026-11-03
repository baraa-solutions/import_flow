import unittest
from datetime import date
from fastapi import HTTPException
from utils.export_import_helper import MasterDataExportImportHelper


class TestMasterDataExportImportHelper(unittest.TestCase):
    def test_as_excel_response(self):
        content = b"fake-excel-data"
        filename = "test_export.xlsx"
        response = MasterDataExportImportHelper.as_excel_response(filename, content)
        
        self.assertEqual(response.media_type, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
        self.assertIn(f"filename={filename}", response.headers.get("content-disposition", ""))
        self.assertEqual(response.body, content)

    def test_as_pdf_response(self):
        content = b"fake-pdf-data"
        filename = "test_export.pdf"
        response = MasterDataExportImportHelper.as_pdf_response(filename, content)

        self.assertEqual(response.media_type, "application/pdf")
        self.assertIn(f"filename={filename}", response.headers.get("content-disposition", ""))
        self.assertEqual(response.body, content)

    def test_standard_export_filename(self):
        today_str = date.today().strftime("%Y-%m-%d")
        fn1 = MasterDataExportImportHelper.standard_export_filename("Egyptian Import Companies", "xlsx")
        self.assertEqual(fn1, f"Egyptian_Import_Companies_{today_str}.xlsx")

        fn2 = MasterDataExportImportHelper.standard_export_filename("Incoterm", ".csv", doc_code="FOB")
        self.assertEqual(fn2, f"Incoterm_FOB_{today_str}.csv")

    def test_format_date_safe(self):
        self.assertEqual(MasterDataExportImportHelper.format_date_safe(date(2026, 10, 9)), "2026-10-09")
        self.assertEqual(MasterDataExportImportHelper.format_date_safe(None), "")
        self.assertEqual(MasterDataExportImportHelper.format_date_safe(None, default="-"), "-")

    def test_parse_date_safe(self):
        # Valid date strings
        self.assertEqual(MasterDataExportImportHelper.parse_date_safe("2026-09-14"), date(2026, 9, 14))
        self.assertEqual(MasterDataExportImportHelper.parse_date_safe("2026-01-01T12:00:00"), date(2026, 1, 1))

        # Invalid formats
        self.assertIsNone(MasterDataExportImportHelper.parse_date_safe("not-a-date"))
        self.assertIsNone(MasterDataExportImportHelper.parse_date_safe(""))
        self.assertIsNone(MasterDataExportImportHelper.parse_date_safe(None))

        # Custom default
        fallback = date(2025, 1, 1)
        self.assertEqual(MasterDataExportImportHelper.parse_date_safe("corrupt", default=fallback), fallback)
        self.assertEqual(MasterDataExportImportHelper.parse_date_safe(None, default=fallback), fallback)

    def test_parse_bool_safe(self):
        # Truthy variations (English & Arabic)
        for truthy in ["true", "True", "TRUE", "1", "yes", "YES", "نعم", "t", "T", "  yes  "]:
            self.assertTrue(MasterDataExportImportHelper.parse_bool_safe(truthy), f"Expected True for '{truthy}'")

        # Falsy variations
        for falsy in ["false", "False", "0", "no", "NO", "لا", "", None, 0, "unknown"]:
            self.assertFalse(MasterDataExportImportHelper.parse_bool_safe(falsy), f"Expected False for '{falsy}'")

    def test_create_and_parse_excel_template(self):
        columns = ["company_name", "tax_number", "commercial_register", "is_active", "notes"]
        sample = {
            "company_name": "Test Importer LLC",
            "tax_number": "123-456-789",
            "commercial_register": "CR-9988",
            "is_active": "نعم",
            "notes": "Sample company notes",
        }
        excel_bytes = MasterDataExportImportHelper.create_excel_template(columns, sample)
        self.assertIsInstance(excel_bytes, bytes)
        self.assertGreater(len(excel_bytes), 100)

        # Parse generated template back
        parsed_rows = MasterDataExportImportHelper.parse_excel_file(excel_bytes, columns)
        self.assertEqual(len(parsed_rows), 1)
        self.assertEqual(parsed_rows[0].get("company_name"), "Test Importer LLC")
        self.assertEqual(parsed_rows[0].get("tax_number"), "123-456-789")
        self.assertEqual(parsed_rows[0].get("commercial_register"), "CR-9988")
        self.assertEqual(parsed_rows[0].get("is_active"), "نعم")

    def test_parse_excel_file_empty_raises_400(self):
        with self.assertRaises(HTTPException) as ctx:
            MasterDataExportImportHelper.parse_excel_file(b"", ["col1"])
        self.assertEqual(ctx.exception.status_code, 400)
        self.assertIn("empty", ctx.exception.detail.lower())

    def test_parse_excel_file_corrupt_raises_400(self):
        corrupt_bytes = b"This is not a valid zip or excel file binary stream"
        with self.assertRaises(HTTPException) as ctx:
            MasterDataExportImportHelper.parse_excel_file(corrupt_bytes, ["col1"])
        self.assertEqual(ctx.exception.status_code, 400)
        self.assertIn("invalid or corrupted", ctx.exception.detail.lower())

    def test_parse_excel_file_oversized_raises_413(self):
        fake_data = b"x" * 1024
        # Test with a low max_size threshold to simulate size limit enforcement
        with self.assertRaises(HTTPException) as ctx:
            MasterDataExportImportHelper.parse_excel_file(fake_data, ["col1"], max_size_bytes=512)
        self.assertEqual(ctx.exception.status_code, 413)
        self.assertIn("exceeds maximum allowed limit", ctx.exception.detail.lower())

    def test_export_to_excel(self):
        headers = ["Code", "Description", "Value"]
        rows = [
            ["ITM-01", "Item One", 150.0],
            ["ITM-02", "Item Two", 300.0],
        ]
        result_bytes = MasterDataExportImportHelper.export_to_excel("Test Report", headers, rows)
        self.assertIsInstance(result_bytes, bytes)
        self.assertGreater(len(result_bytes), 200)

        # Re-parse exported excel to verify data integrity
        parsed = MasterDataExportImportHelper.parse_excel_file(result_bytes, headers)
        self.assertEqual(len(parsed), 2)
        self.assertEqual(parsed[0].get("Code"), "ITM-01")
        self.assertEqual(parsed[1].get("Description"), "Item Two")


    def test_execute_atomic_import_success(self):
        from sqlalchemy import create_engine, Column, Integer, String
        from sqlalchemy.orm import declarative_base, sessionmaker

        Base = declarative_base()

        class DummyModel(Base):
            __tablename__ = "dummy_import_test"
            id = Column(Integer, primary_key=True)
            name = Column(String)

        engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(engine)
        Session = sessionmaker(bind=engine)
        db = Session()

        rows = [{"name": "Item A"}, {"name": "Item B"}, {"name": "Item C"}]

        def row_processor(idx, r):
            obj = DummyModel(name=r["name"])
            db.add(obj)
            db.flush()

        res = MasterDataExportImportHelper.execute_atomic_import(db, rows, row_processor)
        self.assertEqual(res["imported_count"], 3)
        self.assertEqual(db.query(DummyModel).count(), 3)
        db.close()

    def test_execute_atomic_import_rollback_on_error(self):
        from sqlalchemy import create_engine, Column, Integer, String
        from sqlalchemy.orm import declarative_base, sessionmaker

        Base = declarative_base()

        class DummyModel(Base):
            __tablename__ = "dummy_rollback_test"
            id = Column(Integer, primary_key=True)
            name = Column(String)

        engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(engine)
        Session = sessionmaker(bind=engine)
        db = Session()

        rows = [
            {"name": "Valid 1"},
            {"name": "Valid 2"},
            {"name": "FAIL"},  # Will trigger error
            {"name": "Valid 3"},
        ]

        def row_processor(idx, r):
            if r["name"] == "FAIL":
                raise ValueError("Corrupt data in row!")
            obj = DummyModel(name=r["name"])
            db.add(obj)
            db.flush()

        with self.assertRaises(HTTPException) as ctx:
            MasterDataExportImportHelper.execute_atomic_import(db, rows, row_processor)

        self.assertEqual(ctx.exception.status_code, 400)
        self.assertIn("Corrupt data in row!", str(ctx.exception.detail))
        # Critical verification of All-or-Nothing atomicity: 0 items must be persisted
        self.assertEqual(db.query(DummyModel).count(), 0)
        db.close()


if __name__ == "__main__":
    unittest.main()
