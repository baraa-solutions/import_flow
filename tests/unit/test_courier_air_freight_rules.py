"""
Unit Tests for Air Freight & Express Courier Rules:
1. Dual Volumetric Divisor (6000 IATA vs 5000 Courier)
2. ACID Mandatory vs Postal Parcel Exemption Thresholds (Egyptian Customs Law 207/2020)
3. Lifecycle Stage Skipping for Exempt Postal Shipments (STEP_05, STEP_10, STEP_12)
4. Stage Gate Verification for Mandatory Shipments (blocking advance past STEP_05 without valid 19-digit ACID)
"""

import pytest
from datetime import date
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.cbm_calculator.air_freight_service import (
    COURIER_VOLUMETRIC_DIVISOR,
    IATA_VOLUMETRIC_DIVISOR,
    AirFreightService,
    calculate_volumetric_weight,
    calculate_volumetric_weight_iata,
    calculate_chargeable_weight,
    calculate_air_vs_courier_comparison,
)
from modules.import_files.model import ImportFile
from modules.import_files.schemas import ImportFileCreate, ImportFileUpdate
import modules.import_files.service as import_files_service
from modules.import_files.import_file_lifecycle_service import (
    evaluate_acid_requirement,
    validate_acid_stage_gate,
)
from modules.lifecycle_board.lifecycle_step_service import (
    advance_lifecycle_step_service,
    skip_step_service,
)
from modules.lifecycle_board.schemas import SkipStepPayload
from modules.users.model import User, Role


@pytest.fixture
def db_session():
    """Isolated in-memory SQLite database for unit testing."""
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    try:
        yield session
    finally:
        session.close()


# ==============================================================================
# 1. Dual Divisor Calculations (5000 vs 6000)
# ==============================================================================

class TestDualVolumetricDivisor:

    def test_constants_defined(self):
        assert IATA_VOLUMETRIC_DIVISOR == 6000.0
        assert COURIER_VOLUMETRIC_DIVISOR == 5000.0

    def test_standard_air_freight_divisor_6000(self):
        # Package: 120cm x 80cm x 80cm = 768,000 cm3
        # Volumetric weight = 768,000 / 6000 = 128.0 kg
        vol_calc = calculate_volumetric_weight(120.0, 80.0, 80.0, quantity=1, divisor=6000.0)
        assert vol_calc == 128.0

        vol_iata = calculate_volumetric_weight_iata(120.0, 80.0, 80.0, quantity=1)
        assert vol_iata == 128.0

        # Default divisor is 6000.0
        assert calculate_volumetric_weight(120.0, 80.0, 80.0, quantity=1) == 128.0

        # 1 CBM package: 100cm x 100cm x 100cm = 1,000,000 cm3 -> 166.67 kg
        cbm1_air = calculate_volumetric_weight(100.0, 100.0, 100.0, quantity=1, divisor=6000.0)
        assert cbm1_air == 166.67

    def test_express_courier_divisor_5000(self):
        # Package: 120cm x 80cm x 80cm = 768,000 cm3
        # Volumetric weight = 768,000 / 5000 = 153.6 kg
        vol_courier = calculate_volumetric_weight(120.0, 80.0, 80.0, quantity=1, divisor=5000.0)
        assert vol_courier == 153.6

        # Via freight_type == 'courier'
        vol_type_courier = calculate_volumetric_weight(120.0, 80.0, 80.0, quantity=1, freight_type="courier")
        assert vol_type_courier == 153.6

        # Via freight_type == 'express_courier'
        vol_type_express = calculate_volumetric_weight(120.0, 80.0, 80.0, quantity=1, freight_type="express_courier")
        assert vol_type_express == 153.6

        # 1 CBM package: 100cm x 100cm x 100cm = 1,000,000 cm3 -> 200.0 kg
        cbm1_courier = calculate_volumetric_weight(100.0, 100.0, 100.0, quantity=1, divisor=5000.0)
        assert cbm1_courier == 200.0

    def test_chargeable_weight_rules(self):
        # Chargeable Weight = max(Gross_Weight_kg, Volumetric_Weight_kg)
        # Gross governs:
        assert calculate_chargeable_weight(gross_weight_kg=200.0, volumetric_weight_kg=128.0) == 200.0
        # Volumetric governs:
        assert calculate_chargeable_weight(gross_weight_kg=50.0, volumetric_weight_kg=128.0) == 128.0

        # Boundary divergence where divisor changes chargeable weight:
        # Box 120x80x80cm, gross_weight = 140.0 kg
        # Air Freight (6000): vol = 128.0 -> chargeable = 140.0 kg (governed by gross weight)
        # Courier (5000): vol = 153.6 -> chargeable = 153.6 kg (governed by volumetric weight)
        air_dims = AirFreightService.calculate_dimensions(120, 80, 80, gross_weight_kg=140.0, divisor=6000.0)
        courier_dims = AirFreightService.calculate_dimensions(120, 80, 80, gross_weight_kg=140.0, divisor=5000.0)

        assert air_dims["chargeable_weight_kg"] == 140.0
        assert air_dims["is_higher_volumetric"] is False
        assert courier_dims["chargeable_weight_kg"] == 153.6
        assert courier_dims["is_higher_volumetric"] is True

    def test_air_vs_courier_comparison_metrics(self):
        # Box 120x80x80cm, gross_weight = 140.0 kg, rate = $5.00/kg
        comp = calculate_air_vs_courier_comparison(
            single_length_cm=120,
            single_width_cm=80,
            single_height_cm=80,
            single_gross_weight_kg=140.0,
            single_quantity=1,
            estimated_rate_per_kg=5.0,
        )

        assert comp["gross_weight_kg"] == 140.0
        assert comp["cbm"] == 0.768
        assert comp["air_freight"]["divisor"] == 6000.0
        assert comp["air_freight"]["volumetric_weight_kg"] == 128.0
        assert comp["air_freight"]["chargeable_weight_kg"] == 140.0
        assert comp["air_freight"]["estimated_cost"] == 700.0

        assert comp["courier"]["divisor"] == 5000.0
        assert comp["courier"]["volumetric_weight_kg"] == 153.6
        assert comp["courier"]["chargeable_weight_kg"] == 153.6
        assert comp["courier"]["estimated_cost"] == 768.0

        assert comp["chargeable_weight_difference_kg"] == 13.6
        assert comp["chargeable_weight_increase_percent"] == 9.71
        assert comp["cost_difference"] == 68.0
        assert "Air Freight saves 13.6 kg" in comp["recommendation"]

    def test_zero_and_negative_dimensions_safe(self):
        assert calculate_volumetric_weight(0, 80, 80, divisor=5000) == 0.0
        assert calculate_volumetric_weight(-10, 80, 80, divisor=5000) == 0.0
        assert calculate_volumetric_weight(120, 80, 80, quantity=0, divisor=5000) == 0.0
        assert calculate_volumetric_weight(120, 80, 80, quantity=-1, divisor=5000) == 0.0


# ==============================================================================
# 2. ACID Requirement for Air & Courier Shipments (Customs Law 207/2020)
# ==============================================================================

class TestAcidRequirementRules:

    def test_courier_exceeds_weight_threshold_over_50kg(self):
        # Gross weight > 50 kg -> MANDATORY even if value is <= $2000
        req, reason = evaluate_acid_requirement(
            shipment_mode="Courier",
            shipment_sub_mode="Express Courier",
            gross_weight_kg=50.1,
            customs_value_usd=1500.0,
        )
        assert req == "MANDATORY"
        assert reason == "Exceeds courier threshold: weight > 50kg or value > $2000"

    def test_courier_exceeds_value_threshold_over_2000usd(self):
        # Value > $2000 -> MANDATORY even if weight is <= 50 kg
        req, reason = evaluate_acid_requirement(
            shipment_mode="Air",
            shipment_sub_mode="Express Courier",
            gross_weight_kg=25.0,
            customs_value_usd=2000.01,
        )
        assert req == "MANDATORY"
        assert reason == "Exceeds courier threshold: weight > 50kg or value > $2000"

    def test_courier_exceeds_both_weight_and_value(self):
        req, reason = evaluate_acid_requirement(
            shipment_mode="Air",
            shipment_sub_mode="Express Courier",
            gross_weight_kg=75.0,
            customs_value_usd=5000.0,
        )
        assert req == "MANDATORY"
        assert reason == "Exceeds courier threshold: weight > 50kg or value > $2000"

    def test_courier_exact_boundary_is_exempt(self):
        # Weight <= 50.0 kg AND Value <= 2000.0 USD -> EXEMPT_POSTAL
        req, reason = evaluate_acid_requirement(
            shipment_mode="Courier",
            shipment_sub_mode="Express Courier",
            gross_weight_kg=50.0,
            customs_value_usd=2000.0,
        )
        assert req == "EXEMPT_POSTAL"
        assert reason == "Postal parcel under 50kg and $2000 (Article 1, Customs Law 207/2020)"

    def test_courier_small_postal_parcel_is_exempt(self):
        # Small sample parcel e.g. 5kg, $350
        req, reason = evaluate_acid_requirement(
            shipment_mode="Courier",
            shipment_sub_mode="Express Courier",
            gross_weight_kg=5.0,
            customs_value_usd=350.0,
        )
        assert req == "EXEMPT_POSTAL"
        assert reason == "Postal parcel under 50kg and $2000 (Article 1, Customs Law 207/2020)"

    def test_ocean_shipments_always_mandatory(self):
        # Ocean shipments always require mandatory ACID regardless of weight/value
        req1, reason1 = evaluate_acid_requirement(
            shipment_mode="Sea FCL",
            shipment_sub_mode=None,
            gross_weight_kg=10.0,
            customs_value_usd=500.0,
        )
        assert req1 == "MANDATORY"
        assert "Ocean shipments" in reason1

        req2, reason2 = evaluate_acid_requirement(
            shipment_mode="Sea LCL",
            shipment_sub_mode=None,
            gross_weight_kg=1.0,
            customs_value_usd=50.0,
        )
        assert req2 == "MANDATORY"

        req3, reason3 = evaluate_acid_requirement(
            shipment_mode="Ocean",
            shipment_sub_mode=None,
            gross_weight_kg=2.0,
            customs_value_usd=100.0,
        )
        assert req3 == "MANDATORY"


# ==============================================================================
# 3. Lifecycle Stage Skipping for Exempt Postal Shipments
# ==============================================================================

class TestLifecycleStageSkipping:

    def test_create_import_file_exempt_postal_skips_stages(self, db_session):
        payload = ImportFileCreate(
            company_name="Modern Logistics Egypt",
            supplier_name="Global Fast Supplies",
            shipment_mode="Courier",
            shipment_sub_mode="Express Courier",
            courier_operator="DHL",
            courier_tracking_no="DHL-9876543210",
            packing_lists_data=[
                {"pl_no": "PL-C01", "gross_weight_kg": 15.0, "cbm": 0.05, "total_packages": 2}
            ],
            invoices_data=[
                {"invoice_no": "INV-C01", "amount": 850.0, "currency": "USD"}
            ],
            estimated_cost=850.0,
        )

        file_obj = import_files_service.create_import_file_service(db_session, payload)

        assert file_obj.acid_requirement == "EXEMPT_POSTAL"
        assert file_obj.acid_exemption_reason == "Postal parcel under 50kg and $2000 (Article 1, Customs Law 207/2020)"
        assert file_obj.chargeable_divisor == 5000
        assert file_obj.courier_operator == "DHL"
        assert file_obj.courier_tracking_no == "DHL-9876543210"

        # Skipped stages must include STEP_05, STEP_10, STEP_12
        skipped = file_obj.skipped_stages or []
        assert "STEP_05" in skipped
        assert "STEP_10" in skipped
        assert "STEP_12" in skipped

    def test_create_import_file_mandatory_courier_does_not_skip(self, db_session):
        payload = ImportFileCreate(
            company_name="Modern Logistics Egypt",
            supplier_name="Heavy Machinery Parts",
            shipment_mode="Courier",
            shipment_sub_mode="Express Courier",
            courier_operator="FedEx",
            packing_lists_data=[
                {"pl_no": "PL-C02", "gross_weight_kg": 85.0, "cbm": 0.3, "total_packages": 5}
            ],
            invoices_data=[
                {"invoice_no": "INV-C02", "amount": 3500.0, "currency": "USD"}
            ],
        )

        file_obj = import_files_service.create_import_file_service(db_session, payload)

        assert file_obj.acid_requirement == "MANDATORY"
        assert file_obj.acid_exemption_reason == "Exceeds courier threshold: weight > 50kg or value > $2000"
        assert file_obj.chargeable_divisor == 5000

        skipped = file_obj.skipped_stages or []
        assert "STEP_05" not in skipped
        assert "STEP_10" not in skipped
        assert "STEP_12" not in skipped

    def test_update_import_file_transitions_exemption_and_stages(self, db_session):
        # Initially created as mandatory air freight (weight 90 kg, $4500)
        initial_payload = ImportFileCreate(
            company_name="Modern Logistics Egypt",
            supplier_name="Supplier A",
            shipment_mode="Air",
            shipment_sub_mode="General Air Cargo",
            packing_lists_data=[{"pl_no": "PL-1", "gross_weight_kg": 90.0, "cbm": 0.5}],
            invoices_data=[{"invoice_no": "INV-1", "amount": 4500.0, "currency": "USD"}],
        )
        file_obj = import_files_service.create_import_file_service(db_session, initial_payload)
        assert file_obj.acid_requirement == "MANDATORY"
        assert "STEP_05" not in (file_obj.skipped_stages or [])

        # Update to postal courier parcel (weight 20 kg, $900)
        update_payload = ImportFileUpdate(
            shipment_sub_mode="Express Courier",
            courier_operator="Aramex",
            packing_lists_data=[{"pl_no": "PL-1", "gross_weight_kg": 20.0, "cbm": 0.1}],
            invoices_data=[{"invoice_no": "INV-1", "amount": 900.0, "currency": "USD"}],
        )
        updated_file = import_files_service.update_import_file_service(
            db_session, file_obj.import_file_id, update_payload
        )

        assert updated_file.acid_requirement == "EXEMPT_POSTAL"
        assert updated_file.chargeable_divisor == 5000
        assert "STEP_05" in updated_file.skipped_stages
        assert "STEP_10" in updated_file.skipped_stages
        assert "STEP_12" in updated_file.skipped_stages

    def test_skip_step_service_allows_postal_exempt_steps(self, db_session):
        # Create an EXEMPT_POSTAL file
        payload = ImportFileCreate(
            company_name="Modern Logistics Egypt",
            supplier_name="Express Parts",
            shipment_mode="Courier",
            shipment_sub_mode="Express Courier",
            packing_lists_data=[{"pl_no": "PL-03", "gross_weight_kg": 10.0, "cbm": 0.02}],
            invoices_data=[{"invoice_no": "INV-03", "amount": 400.0, "currency": "USD"}],
        )
        file_obj = import_files_service.create_import_file_service(db_session, payload)

        skip_payload = SkipStepPayload(
            import_file_code=file_obj.import_file_code,
            current_step_code="STEP_05",
            skip_reason="Exempt postal shipment under Law 207/2020",
        )

        # Skipping STEP_05 for postal exempt shipment should succeed cleanly without blocked-policy error
        res = skip_step_service(db_session, skip_payload)
        assert res["skipped_step"] == "STEP_05"
        assert "STEP_05" in file_obj.skipped_stages
        assert res["skip_policy"] == "postal_exempt"


# ==============================================================================
# 4. Stage Gate Verification for Mandatory Shipments
# ==============================================================================

class TestAcidStageGate:

    def test_stage_gate_blocks_mandatory_shipment_without_acid(self):
        # Mock mandatory file without ACID
        file_rec = {
            "acid_requirement": "MANDATORY",
            "acid_number": None,
        }
        with pytest.raises(HTTPException) as exc_info:
            validate_acid_stage_gate(file_rec, "STEP_05")
        assert exc_info.value.status_code == 400
        assert "STEP_05" in exc_info.value.detail or "ACID" in exc_info.value.detail

    def test_stage_gate_blocks_mandatory_shipment_with_invalid_acid(self):
        # Too short (not 19 digits)
        with pytest.raises(HTTPException):
            validate_acid_stage_gate({"acid_requirement": "MANDATORY", "acid_number": "123456789"})

        # 19 characters but contains letters
        with pytest.raises(HTTPException):
            validate_acid_stage_gate({"acid_requirement": "MANDATORY", "acid_number": "123456789012345678A"})

    def test_stage_gate_passes_mandatory_shipment_with_valid_19_digit_acid(self):
        # Exactly 19 digits
        valid_file = {
            "acid_requirement": "MANDATORY",
            "acid_number": "1987654321098765432",
        }
        # Should not raise
        validate_acid_stage_gate(valid_file, "STEP_05")

    def test_stage_gate_bypasses_exempt_postal_shipment_without_acid(self):
        exempt_file = {
            "acid_requirement": "EXEMPT_POSTAL",
            "acid_number": None,
        }
        # Should not raise for EXEMPT_POSTAL
        validate_acid_stage_gate(exempt_file, "STEP_05")

    def test_advance_lifecycle_step_enforces_acid_gate_in_db(self, db_session):
        # 1. Create a mandatory ocean shipment starting at STEP_04
        payload = ImportFileCreate(
            company_name="Mandatory Cargo Ltd",
            supplier_name="Global Steel Inc",
            shipment_mode="Sea FCL",
            initial_starting_step="STEP_04",
            packing_lists_data=[{"pl_no": "PL-M01", "gross_weight_kg": 5000.0, "cbm": 25.0}],
            invoices_data=[{"invoice_no": "INV-M01", "amount": 18000.0, "currency": "USD"}],
        )
        file_obj = import_files_service.create_import_file_service(db_session, payload)
        assert file_obj.acid_requirement == "MANDATORY"
        assert file_obj.acid_number is None

        # 2. Advance completing STEP_04 -> activates STEP_05
        advance_res = advance_lifecycle_step_service(
            db_session,
            completed_step_code="STEP_04",
            import_file_code=file_obj.import_file_code,
            target_step_codes=["STEP_05"],
        )
        assert advance_res["current_step_code"] == "STEP_05"

        # 3. Attempt to advance past STEP_05 without ACID -> MUST be blocked!
        with pytest.raises(HTTPException) as exc_info:
            advance_lifecycle_step_service(
                db_session,
                completed_step_code="STEP_05",
                import_file_code=file_obj.import_file_code,
                target_step_codes=["STEP_06"],
            )
        assert exc_info.value.status_code == 400
        assert "STEP_05" in exc_info.value.detail or "ACID" in exc_info.value.detail

        # 4. Supply a valid 19-digit ACID number and retry -> MUST succeed!
        file_obj.acid_number = "5281534391025810014"
        db_session.commit()

        advance_success = advance_lifecycle_step_service(
            db_session,
            completed_step_code="STEP_05",
            import_file_code=file_obj.import_file_code,
            target_step_codes=["STEP_06"],
        )
        assert advance_success["current_step_code"] == "STEP_06"
