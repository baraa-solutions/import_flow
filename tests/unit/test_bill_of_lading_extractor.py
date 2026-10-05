import pytest
from modules.smart_document_upload.extractors.cargo_shipping import CargoShippingExtractor
from modules.smart_document_upload.service import (
    extract_bill_of_lading_service,
    apply_extracted_bl_service,
)
from database.database import SessionLocal
from modules.cargo_shipping.model import CargoShippingRecord
from modules.import_files.model import ImportFile
from modules.smart_document_upload.schemas import ApplyBLRequest



SAMPLE_OCEAN_BL_TEXT = """
MEDITERRANEAN SHIPPING COMPANY S.A.
BILL OF LADING
B/L No: MEDUSH12345678
ACID Number: 1987654321098765432
Carrier: MSC Mediterranean Shipping Company
Vessel: MSC OSCAR
Voyage: 2608W
Port of Loading: Shanghai Port
Port of Discharge: Alexandria Port
Place of Delivery: Alexandria Port
Shipper: Shanghai Machinery Co., Ltd.
Consignee: Egyptian National Industrial Supply LLC
Freight Payment: FREIGHT COLLECT
Total Packages: 350 Packages
Total Gross Weight: 4,550.00 KGS
Total Measurement: 28.50 CBM

Container & Seal Numbers:
MSCU7654321 / SEAL: ML-EG99881 / 40HC / Gross: 24,000 KG / CBM: 28.5
"""

SAMPLE_AIR_WAYBILL_TEXT = """
EMIRATES SKYCARGO
AIR WAYBILL
AWB No: 176-12345678
ACID: 1987654321098765432
Flight No: EK923
Airport of Departure: Dubai International Airport
Airport of Destination: Cairo International Airport
Shipper: Gulf Trading FZE
Consignee: Cairo Imports Co.
Total Packages: 15 Cartons
Gross Weight: 320.00 KGS
Freight: FREIGHT PREPAID
"""


class TestBillOfLadingExtractor:
    def test_extract_ocean_bl(self):
        extractor = CargoShippingExtractor()
        data = extractor.extract(SAMPLE_OCEAN_BL_TEXT, {})

        assert data["bl_type"] == "OCEAN_BL"
        assert data["bl_number"] == "MEDUSH12345678"
        assert data["acid_number"] == "1987654321098765432"
        assert "MSC" in data["carrier_name"]
        assert "OSCAR" in data["vessel_name"]
        assert "Shanghai" in data["loading_port"]
        assert "Alexandria" in data["discharge_port"]
        assert data["freight_payment_term"] == "FREIGHT_COLLECT"
        assert data["total_gross_weight_kg"] == 4550.0
        assert data["total_cbm"] == 28.5
        assert data["total_packages_count"] == 350
        assert len(data["containers"]) >= 1
        assert data["containers"][0]["container_no"] == "MSCU7654321"

    def test_extract_air_waybill(self):
        extractor = CargoShippingExtractor()
        data = extractor.extract(SAMPLE_AIR_WAYBILL_TEXT, {})

        assert data["bl_type"] == "AIR_WAYBILL"
        assert "176-12345678" in data["bl_number"]
        assert data["acid_number"] == "1987654321098765432"
        assert data["flight_number"] == "EK923"
        assert data["freight_payment_term"] == "FREIGHT_PREPAID"
        assert data["total_gross_weight_kg"] == 320.0
        assert data["total_packages_count"] == 15

    def test_extract_service_wrapper(self):
        res = extract_bill_of_lading_service(
            filename="bill_of_lading.txt",
            raw_text=SAMPLE_OCEAN_BL_TEXT,
        )

        assert res["document_type"] == "OCEAN_BL"
        assert res["extracted_fields"]["bl_number"] == "MEDUSH12345678"
        assert res["containers_count"] >= 1

    def test_apply_extracted_bl_to_shipping(self):
        db = SessionLocal()
        try:
            # Create import file and shipping record
            imp = ImportFile(
                import_file_code="IMP-BL-TEST-002",
                company_name="Cairo Imports Co.",
                supplier_name="Gulf Trading FZE",
            )
            db.add(imp)
            db.commit()
            db.refresh(imp)

            ship = CargoShippingRecord(
                cargo_shipping_code="SHP-TEST-002",
                import_file_id=imp.import_file_id,
            )

            db.add(ship)
            db.commit()
            db.refresh(ship)

            extractor = CargoShippingExtractor()
            data = extractor.extract(SAMPLE_OCEAN_BL_TEXT, {})

            # SDU-01: typed request body (same keys as the extractor output).
            apply_res = apply_extracted_bl_service(
                db=db,
                payload=ApplyBLRequest(import_file_id=imp.import_file_id, bl_data=data),
                user="tester",
            )

            assert apply_res["applied"] is True
            db.refresh(ship)
            assert len(ship.containers_loading_data) >= 1
            assert ship.containers_loading_data[0]["container_no"] == "MSCU7654321"
        finally:
            db.close()
