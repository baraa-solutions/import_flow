import pytest
from modules.smart_document_upload.extractors.commercial_invoice import CommercialInvoiceExtractor
from modules.smart_document_upload.service import (
    extract_commercial_invoice_service,
    apply_extracted_invoice_service,
)
from database.database import get_db, SessionLocal
from modules.import_files.model import ImportFile
from modules.incoterms.model import Incoterm
from modules.smart_document_upload.schemas import ApplyInvoiceRequest


SAMPLE_INVOICE_TEXT = """
COMMERCIAL INVOICE
Invoice No: INV-2026-99881
Invoice Date: 2026-08-15
ACID Number: 1987654321098765432
Importer Tax ID: 200345678
Exporter Registration No: CN91310000778899
Supplier / Exporter: Shanghai Machinery Co., Ltd.
Importer / Buyer: Egyptian National Industrial Supply LLC
Country of Origin: China
Port of Loading: Shanghai Port
Port of Discharge: Alexandria Port
Incoterms: FOB
Currency: USD

Item Description                  Qty    UOM    Unit Price   Total Price
Industrial Milling Tool A10      100    PCS    250.00       25000.00
Hydraulic Valve 2-inch            50    PCS    180.00        9000.00
Control Unit Replacement         200    PCS     80.00       16000.00

Total Amount: 50,000.00 USD
Total Gross Weight: 4,500.00 KG
Total Net Weight: 4,100.00 KG
Payment Terms: 30% Advance, 70% against Draft BL copy
"""


class TestCommercialInvoiceExtractor:
    def test_extract_invoice_fields(self):
        extractor = CommercialInvoiceExtractor()
        data = extractor.extract(SAMPLE_INVOICE_TEXT, {})

        assert data["invoice_number"] == "INV-2026-99881"
        assert data["acid_number"] == "1987654321098765432"
        assert data["importer_tax_id"] == "200345678"
        assert data["exporter_registration_no"] == "CN91310000778899"
        assert "Shanghai" in data["supplier_name"]
        assert "Egyptian" in data["importer_name"]
        assert data["origin_country"] == "China"
        assert data["incoterms"] == "FOB"
        assert data["currency"] == "USD"
        assert data["invoice_value"] == 50000.0
        assert data["total_gross_weight_kg"] == 4500.0
        assert data["total_net_weight_kg"] == 4100.0
        assert data["items_count"] == 3

    def test_extract_service_wrapper(self):
        res = extract_commercial_invoice_service(
            filename="invoice.txt",
            raw_text=SAMPLE_INVOICE_TEXT,
        )

        assert res["document_type"] == "Commercial Invoice"
        assert res["extracted_fields"]["invoice_number"] == "INV-2026-99881"
        assert res["items_count"] == 3
        assert len(res["items"]) == 3
        assert res["items"][0]["quantity"] == 100.0

    def test_apply_extracted_invoice_to_import_file(self):
        db = SessionLocal()
        try:
            # Create a test import file
            import_file = ImportFile(
                import_file_code="IMP-INV-TEST-001",
                company_name="Egyptian National Industrial Supply LLC",
                supplier_name="Shanghai Machinery Co., Ltd.",
                shipment_mode="Sea FCL",
                incoterm_code="EXW",
                estimated_cost=25000.0,
                estimated_cost_currency="EUR",
            )
            db.add(import_file)
            db.commit()
            db.refresh(import_file)

            # SDU-01: the Incoterm is validated against the incoterms master table.
            if db.query(Incoterm).filter(Incoterm.incoterm_code == "FOB").first() is None:
                db.add(Incoterm(incoterm_code="FOB", incoterm_name="Free On Board"))
                db.commit()

            extractor = CommercialInvoiceExtractor()
            data = extractor.extract(SAMPLE_INVOICE_TEXT, {})

            # SDU-01: typed request body (same keys as the extractor output).
            apply_res = apply_extracted_invoice_service(
                db=db,
                payload=ApplyInvoiceRequest(import_file_id=import_file.import_file_id, invoice_data=data),
                user="tester",
            )

            assert apply_res["applied"] is True
            assert apply_res["import_file_id"] == import_file.import_file_id
            assert apply_res["params"]["replaced"] is False

            # Verify db update
            db.refresh(import_file)
            assert import_file.acid_number == "1987654321098765432"
            assert import_file.incoterm_code == "FOB"
            assert import_file.port_of_loading == "Shanghai Port"
            assert import_file.port_of_discharge == "Alexandria Port"
            assert import_file.estimated_cost == 25000.0  # BE03-T03: estimate unchanged
            assert import_file.estimated_cost_currency == "EUR"  # BE03-T03: currency unchanged
            assert import_file.invoices_count == 1

            # Second apply with updated amount is idempotent: updates in place, does not duplicate
            data["invoice_value"] = 60000.0
            apply_res_2 = apply_extracted_invoice_service(
                db=db,
                payload=ApplyInvoiceRequest(import_file_id=import_file.import_file_id, invoice_data=data),
                user="tester",
            )
            assert apply_res_2["applied"] is True
            assert apply_res_2["params"]["replaced"] is True
            db.refresh(import_file)
            assert import_file.invoices_count == 1
            assert len(import_file.invoices_data) == 1
            assert import_file.invoices_data[0]["amount"] == 60000.0
            assert import_file.estimated_cost == 25000.0
        finally:
            db.close()
