"""
Unit Tests for Smart Freight RFQ Generator & Cargo Calculations (BP-008)
Tests mode-specific volumetric calculations (Air 6000 vs Courier 5000),
Sea LCL stackability & dead-freight, Sea FCL road weight limits,
preferential trade agreements (EUR.1), and weight validation guards.
"""

import pytest
from datetime import date
from fastapi import HTTPException
from modules.freight_quotations.smart_rfq_service import (
    SmartRFQService,
    IATA_AIR_DIVISOR,
    COURIER_DIVISOR,
)
from modules.freight_quotations.schemas import (
    SmartRFQGenerateRequest,
    SmartRFQPackageItem,
)


class TestSmartRFQGenerator:

    def test_air_chargeable_weight_iata_6000(self):
        """
        Tests that Air Freight uses IATA 6000 divisor and correctly compares
        volumetric weight vs actual gross weight.
        """
        # 3 crates @ 120 x 80 x 80 cm, Gross weight 280 kg
        packages = [
            SmartRFQPackageItem(
                length_cm=120.0,
                width_cm=80.0,
                height_cm=80.0,
                quantity=3,
                gross_weight_kg=280.0 / 3.0,
                net_weight_kg=250.0 / 3.0,
                package_type="Wooden Crate",
            )
        ]

        metrics = SmartRFQService.calculate_cargo_metrics(
            mode="AIR",
            packages=packages,
        )

        # Expected:
        # CBM = (120 * 80 * 80 / 1,000,000) * 3 = 2.304 CBM
        # Vol. Wt = (120 * 80 * 80 / 6000) * 3 = 384.0 KG
        # Chargeable = max(280.0, 384.0) = 384.0 KG
        assert metrics.total_volume_cbm == 2.304
        assert metrics.volumetric_divisor == IATA_AIR_DIVISOR
        assert metrics.volumetric_divisor == 6000.0
        assert metrics.chargeable_weight_kg == 384.0
        assert metrics.is_volumetric_higher is True
        assert round(metrics.total_gross_weight_kg, 1) == 280.0

    def test_courier_chargeable_weight_divisor_5000(self):
        """
        Tests that Courier Express uses 5000 divisor, resulting in exactly
        20% higher volumetric weight than air freight for identical dimensions.
        """
        packages = [
            SmartRFQPackageItem(
                length_cm=120.0,
                width_cm=80.0,
                height_cm=80.0,
                quantity=3,
                gross_weight_kg=280.0 / 3.0,
                net_weight_kg=250.0 / 3.0,
                package_type="Wooden Crate",
            )
        ]

        metrics = SmartRFQService.calculate_cargo_metrics(
            mode="COURIER",
            packages=packages,
        )

        # Expected with 5000:
        # Vol. Wt = (120 * 80 * 80 / 5000) * 3 = 460.8 KG
        assert metrics.volumetric_divisor == COURIER_DIVISOR
        assert metrics.volumetric_divisor == 5000.0
        assert metrics.chargeable_weight_kg == 460.8
        assert metrics.is_volumetric_higher is True
        # Verify 20% higher ratio: 460.8 / 384.0 == 1.20
        assert round(460.8 / 384.0, 2) == 1.20

    def test_weight_validation_error_net_greater_than_gross(self):
        """
        Tests that the system strictly prevents RFQ generation when Net Weight > Gross Weight
        (reproducing and guarding against the real error found in the studied UK email).
        """
        req = SmartRFQGenerateRequest(
            shipment_mode="Sea FCL",
            manual_gross_weight_kg=19656.0,
            manual_net_weight_kg=21262.0,  # Invalid: Net > Gross
        )

        with pytest.raises(HTTPException) as exc_info:
            SmartRFQService.generate_smart_rfq(db=None, req=req)

        assert exc_info.value.status_code == 422
        assert "لا يمكن أن يكون أكبر من الوزن الإجمالي" in exc_info.value.detail

    def test_sea_fcl_heavy_road_weight_and_double_stacking(self):
        """
        Tests Sea FCL logic for a 20' container carrying 22 pallets:
        - Detects road weight compliance warning (> 21 Tons)
        - Detects double-stacking (> 11 pallets in 20' GP)
        - Injects 21 days free time and avoids TMT for El Dekheila
        - Detects Egypt-EU Association Agreement (EUR.1) for France
        """
        req = SmartRFQGenerateRequest(
            shipment_mode="Sea FCL",
            incoterm_code="EXW",
            pickup_address="113 av. Daumesnil, 75012 Paris, France",
            port_of_loading="Le Havre / Fos-sur-Mer, France",
            port_of_discharge="El Dekheila Port, Alexandria, Egypt",
            cargo_ready_date=date(2026, 11, 28),
            commodity_description="Ceramic Floor Tiles",
            hs_code="6907.21",
            equipment_type="20' GP",
            manual_gross_weight_kg=22100.0,
            manual_net_weight_kg=21560.0,
            manual_volume_cbm=19.2,
            target_free_days=21,
            avoid_tmt_terminal=True,
            packages=[
                SmartRFQPackageItem(
                    length_cm=120.0,
                    width_cm=80.0,
                    height_cm=100.0,
                    quantity=22,
                    gross_weight_kg=22100.0 / 22.0,
                    net_weight_kg=21560.0 / 22.0,
                    package_type="Pallet",
                )
            ],
        )

        response = SmartRFQService.generate_smart_rfq(db=None, req=req)

        assert response.metrics.is_heavy_road_cargo is True
        assert response.metrics.is_double_stackable is True
        assert response.metrics.free_days_at_pod == 21
        assert "TMT Yard MUST BE STRICTLY AVOIDED" in (response.metrics.terminal_restriction or "")
        assert "EUR.1" in (response.metrics.trade_agreement_applicable or "")

        # Check rendered email text
        assert "TMT Yard MUST BE STRICTLY AVOIDED" in response.body_text
        assert "Minimum 21 Days Combined Free Time" in response.body_text
        assert "EUR.1" in response.body_text
        assert "Double-Stackable" in response.body_text
        assert "Heavy Cargo" in response.body_text

    def test_sea_lcl_non_stackable_dead_freight(self):
        """
        Tests Sea LCL logic for 6 pallets non-stackable:
        - Calculates volume (6.804 CBM)
        - Flags dead freight applied due to non-stackable status
        - Sets appropriate warnings
        """
        req = SmartRFQGenerateRequest(
            shipment_mode="Sea LCL",
            incoterm_code="EXW",
            pickup_address="ZI Eselborn Lentzweiler, Luxembourg",
            port_of_loading="Antwerp / Rotterdam CFS",
            port_of_discharge="El Dekheila Port CFS, Egypt",
            commodity_description="Industrial Spare Parts",
            is_stackable=False,
            packages=[
                SmartRFQPackageItem(
                    length_cm=108.0,
                    width_cm=105.0,
                    height_cm=100.0,
                    quantity=6,
                    gross_weight_kg=4051.0 / 6.0,
                    net_weight_kg=3900.0 / 6.0,
                    package_type="Pallet",
                )
            ],
        )

        response = SmartRFQService.generate_smart_rfq(db=None, req=req)

        assert response.metrics.is_stackable is False
        assert response.metrics.dead_freight_applied is True
        assert round(response.metrics.total_volume_cbm, 2) == 6.80
        assert "NON-STACKABLE" in response.body_text
        assert any("Non-Stackable" in w for w in response.warnings)
