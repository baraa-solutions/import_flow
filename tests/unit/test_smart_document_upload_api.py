import pytest
from fastapi.testclient import TestClient
from main import app
from database.database import SessionLocal
from modules.import_files.model import ImportFile
from modules.cargo_shipping.model import CargoShippingRecord

client = TestClient(app)


def test_api_extract_commercial_invoice():
    response = client.post(
        "/api/v1/smart-upload/extract/commercial-invoice",
        data={
            "raw_text": """
            COMMERCIAL INVOICE
            Invoice No: INV-API-001
            Date: 2026-08-20
            ACID Number: 1987654321098765432
            Total Amount: 15,000.00 USD
            Incoterms: FOB
            Port of Loading: Ningbo
            Port of Discharge: Alexandria
            """
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert data["document_type"] == "Commercial Invoice"
    assert data["extracted_fields"]["invoice_number"] == "INV-API-001"
    assert data["extracted_fields"]["acid_number"] == "1987654321098765432"
    assert data["extracted_fields"]["invoice_value"] == 15000.0


def test_api_extract_bill_of_lading():
    response = client.post(
        "/api/v1/smart-upload/extract/bill-of-lading",
        data={
            "raw_text": """
            BILL OF LADING
            B/L No: COSU99887766
            Carrier: COSCO SHIPPING
            ACID: 1987654321098765432
            Port of Loading: Ningbo
            Port of Discharge: Alexandria
            Freight: FREIGHT COLLECT
            Total Gross Weight: 12,000 KG
            Total Packages: 200 Cartons
            """
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert data["document_type"] == "OCEAN_BL"
    assert data["extracted_fields"]["bl_number"] == "COSU99887766"
    assert data["extracted_fields"]["acid_number"] == "1987654321098765432"
    assert data["extracted_fields"]["freight_payment_term"] == "FREIGHT_COLLECT"


def test_api_cross_check():
    payload = {
        "invoice_data": {
            "invoice_number": "INV-API-001",
            "acid_number": "1987654321098765432",
            "importer_tax_id": "200345678",
            "supplier_name": "Ningbo Industrial Co.",
            "importer_name": "Cairo Imports LLC",
            "loading_port": "Ningbo Port",
            "discharge_port": "Alexandria Port",
            "total_gross_weight_kg": 12000.0,
            "incoterms": "FOB",
        },
        "bl_data": {
            "bl_number": "COSU99887766",
            "acid_number": "1987654321098765432",
            "importer_tax_id": "200345678",
            "shipper": "Ningbo Industrial Co.",
            "consignee": "Cairo Imports LLC",
            "loading_port": "Ningbo Port",
            "discharge_port": "Alexandria Port",
            "total_gross_weight_kg": 12100.0,
            "freight_payment_term": "FREIGHT_COLLECT",
        },
        "weight_tolerance_pct": 3.0,
    }
    response = client.post("/api/v1/smart-upload/cross-check/invoice-vs-bl", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["compliance_score"] >= 80.0
    assert "audit_matrix" in data
    assert len(data["audit_matrix"]) == 21



def test_api_apply_invoice_and_bl():
    db = SessionLocal()
    try:
        imp = ImportFile(
            import_file_code="IMP-API-TEST-99",
            company_name="Test Company",
            supplier_name="Test Supplier",
        )
        db.add(imp)
        db.commit()
        db.refresh(imp)

        ship = CargoShippingRecord(
            cargo_shipping_code="SHP-API-TEST-99",
            import_file_id=imp.import_file_id,
        )
        db.add(ship)
        db.commit()
        db.refresh(ship)

        # Apply invoice
        inv_payload = {
            "import_file_id": imp.import_file_id,
            "invoice_data": {
                "invoice_number": "INV-API-001",
                "acid_number": "1987654321098765432",
                "invoice_value": 35000.0,
                "currency": "EUR",
                "incoterms": "CIF",
            }
        }
        res_inv = client.post("/api/v1/smart-upload/apply/commercial-invoice", json=inv_payload)
        assert res_inv.status_code == 200
        assert res_inv.json()["applied"] is True

        # Apply B/L
        bl_payload = {
            "import_file_id": imp.import_file_id,
            "bl_data": {
                "containers": [
                    {"container_no": "MSCU1112223", "seal_no": "EG001", "container_type": "40HC", "gross_weight_kg": 18000.0}
                ]
            }
        }
        res_bl = client.post("/api/v1/smart-upload/apply/bill-of-lading", json=bl_payload)
        assert res_bl.status_code == 200
        assert res_bl.json()["applied"] is True
    finally:
        db.close()


def test_be03_t15_routes_are_synchronous():
    import inspect
    import modules.smart_document_upload.router as sdu_router

    routes = [
        sdu_router.upload_document_form,
        sdu_router.upload_document_path,
        sdu_router.parse_document_for_module,
        sdu_router.parse_multiple_documents_for_module,
        sdu_router.parse_text_for_module,
        sdu_router.extract_commercial_invoice_endpoint,
        sdu_router.extract_bill_of_lading_endpoint,
    ]
    for route_fn in routes:
        assert inspect.iscoroutinefunction(route_fn) is False, f"{route_fn.__name__} should not be a coroutine function"


def test_be03_t15_read_validated_upload_sync_rejects_oversized():
    import io
    from fastapi import UploadFile, HTTPException
    from modules.smart_document_upload.validators import read_validated_upload_sync, MAX_FILE_SIZE_BYTES

    fake_file = UploadFile(filename="test.pdf", file=io.BytesIO(b"%PDF-1.4" + b"A" * (MAX_FILE_SIZE_BYTES + 2)))
    with pytest.raises(HTTPException) as exc:
        read_validated_upload_sync(fake_file)
    assert exc.value.status_code == 413

