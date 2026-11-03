"""
Air Freight & Express Courier Volumetric & Chargeable Weight Calculation Service
- Standard Air Freight (IATA Cargo): Divisor 6000.0 (1 CBM = 166.67 kg).
- Express Courier (DHL, FedEx, UPS, Aramex): Divisor 5000.0 (1 CBM = 200.0 kg).
"""

from typing import Any, Dict, List, Optional, Tuple, Union


COURIER_VOLUMETRIC_DIVISOR = 5000.0  # cm3 per kg (1 CBM = 200 kg)
IATA_VOLUMETRIC_DIVISOR = 6000.0    # cm3 per kg (1 CBM = 166.67 kg)
CM3_PER_CBM = 1_000_000.0


def calculate_volumetric_weight(
    length_cm: float,
    width_cm: float,
    height_cm: float,
    quantity: int = 1,
    divisor: float = IATA_VOLUMETRIC_DIVISOR,
    freight_type: Optional[str] = None,
) -> float:
    """
    Calculates air/courier volumetric weight:
    volumetric_weight = (length_cm * width_cm * height_cm) / divisor * quantity
    - Default divisor is 6000.0 (IATA Air Freight)
    - If freight_type == 'courier' (or express courier), divisor defaults to 5000.0
    """
    if freight_type and ("courier" in str(freight_type).lower() or "express" in str(freight_type).lower()):
        effective_divisor = COURIER_VOLUMETRIC_DIVISOR
    else:
        effective_divisor = float(divisor if divisor is not None and divisor > 0 else IATA_VOLUMETRIC_DIVISOR)

    if length_cm <= 0 or width_cm <= 0 or height_cm <= 0 or quantity <= 0 or effective_divisor <= 0:
        return 0.0
    vol_per_unit = (length_cm * width_cm * height_cm) / effective_divisor
    return round(vol_per_unit * quantity, 2)


def calculate_volumetric_weight_iata(
    length_cm: float,
    width_cm: float,
    height_cm: float,
    quantity: int = 1,
) -> float:
    """
    Calculates IATA air volumetric weight using standard 6000.0 divisor:
    volumetric_weight = (length_cm * width_cm * height_cm) / 6000.0 * quantity
    """
    return calculate_volumetric_weight(
        length_cm=length_cm,
        width_cm=width_cm,
        height_cm=height_cm,
        quantity=quantity,
        divisor=IATA_VOLUMETRIC_DIVISOR,
    )


def calculate_chargeable_weight(gross_weight_kg: float, volumetric_weight_kg: float) -> float:
    """
    Calculates air chargeable weight:
    chargeable_weight = max(gross_weight, volumetric_weight)
    """
    return round(max(float(gross_weight_kg or 0.0), float(volumetric_weight_kg or 0.0)), 2)


class AirFreightService:
    """
    Service for calculating Air Freight and Courier cargo measurements, volumetric weights,
    and chargeable weights with dual divisors (6000 vs 5000).
    """

    @staticmethod
    def calculate_dimensions(
        length_cm: float,
        width_cm: float,
        height_cm: float,
        gross_weight_kg: float = 0.0,
        quantity: int = 1,
        divisor: float = IATA_VOLUMETRIC_DIVISOR,
        freight_type: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Calculate volumetric weight, chargeable weight, and CBM for a single package specification.
        """
        qty = max(1, quantity)
        gross_total = round(float(gross_weight_kg or 0.0) * (qty if gross_weight_kg and quantity > 1 else 1), 2)
        
        if freight_type and ("courier" in str(freight_type).lower() or "express" in str(freight_type).lower()):
            effective_divisor = COURIER_VOLUMETRIC_DIVISOR
        else:
            effective_divisor = float(divisor if divisor is not None and divisor > 0 else IATA_VOLUMETRIC_DIVISOR)

        volumetric_total = calculate_volumetric_weight(length_cm, width_cm, height_cm, qty, divisor=effective_divisor, freight_type=freight_type)
        cbm_total = round(((length_cm * width_cm * height_cm) / CM3_PER_CBM) * qty, 4)
        chargeable_total = calculate_chargeable_weight(gross_total, volumetric_total)

        return {
            "gross_weight_kg": gross_total,
            "volumetric_weight_kg": volumetric_total,
            "chargeable_weight_kg": chargeable_total,
            "cbm": cbm_total,
            "is_higher_volumetric": volumetric_total > gross_total,
            "divisor": effective_divisor,
            "freight_type": "courier" if effective_divisor == COURIER_VOLUMETRIC_DIVISOR else "air_freight",
        }

    @staticmethod
    def calculate_air_packages(
        packages: Optional[List[Dict[str, Any]]] = None,
        single_length_cm: Optional[float] = None,
        single_width_cm: Optional[float] = None,
        single_height_cm: Optional[float] = None,
        single_gross_weight_kg: Optional[float] = None,
        single_quantity: int = 1,
        divisor: float = IATA_VOLUMETRIC_DIVISOR,
        freight_type: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Calculates aggregate cargo metrics across single or multiple packages.
        Supports dynamic divisor (default 6000.0, or 5000.0 when freight_type == 'courier').
        """
        if freight_type and ("courier" in str(freight_type).lower() or "express" in str(freight_type).lower()):
            effective_divisor = COURIER_VOLUMETRIC_DIVISOR
        else:
            effective_divisor = float(divisor if divisor is not None and divisor > 0 else IATA_VOLUMETRIC_DIVISOR)

        total_gross = 0.0
        total_volumetric = 0.0
        total_cbm = 0.0
        details = []

        if packages:
            for pkg in packages:
                l = float(pkg.get("length_cm", 0.0) or 0.0)
                w = float(pkg.get("width_cm", 0.0) or 0.0)
                h = float(pkg.get("height_cm", 0.0) or 0.0)
                qty = int(pkg.get("quantity", 1) or 1)
                item_gross = float(pkg.get("gross_weight_kg", 0.0) or 0.0)

                line_gross = round(item_gross * (qty if item_gross and qty > 1 else 1), 2)
                line_vol = calculate_volumetric_weight(l, w, h, qty, divisor=effective_divisor, freight_type=freight_type)
                line_cbm = round(((l * w * h) / CM3_PER_CBM) * qty, 4)
                line_chg = calculate_chargeable_weight(line_gross, line_vol)

                total_gross += line_gross
                total_volumetric += line_vol
                total_cbm += line_cbm

                details.append({
                    "length_cm": l,
                    "width_cm": w,
                    "height_cm": h,
                    "quantity": qty,
                    "gross_weight_kg": line_gross,
                    "volumetric_weight_kg": line_vol,
                    "chargeable_weight_kg": line_chg,
                    "cbm": line_cbm,
                })
        elif single_length_cm and single_width_cm and single_height_cm:
            res = AirFreightService.calculate_dimensions(
                length_cm=single_length_cm,
                width_cm=single_width_cm,
                height_cm=single_height_cm,
                gross_weight_kg=single_gross_weight_kg or 0.0,
                quantity=single_quantity,
                divisor=effective_divisor,
                freight_type=freight_type,
            )
            total_gross = res["gross_weight_kg"]
            total_volumetric = res["volumetric_weight_kg"]
            total_cbm = res["cbm"]
            details.append(res)
        else:
            total_gross = float(single_gross_weight_kg or 0.0)
            total_volumetric = 0.0
            total_cbm = 0.0

        total_gross = round(total_gross, 2)
        total_volumetric = round(total_volumetric, 2)
        total_cbm = round(total_cbm, 4)
        chargeable = calculate_chargeable_weight(total_gross, total_volumetric)

        return {
            "gross_weight_kg": total_gross,
            "volumetric_weight_kg": total_volumetric,
            "chargeable_weight_kg": chargeable,
            "cbm": total_cbm,
            "is_higher_volumetric": total_volumetric > total_gross,
            "divisor": effective_divisor,
            "freight_type": "courier" if effective_divisor == COURIER_VOLUMETRIC_DIVISOR else "air_freight",
            "details": details,
        }

    @staticmethod
    def calculate_air_vs_courier_comparison(
        packages: Optional[List[Dict[str, Any]]] = None,
        single_length_cm: Optional[float] = None,
        single_width_cm: Optional[float] = None,
        single_height_cm: Optional[float] = None,
        single_gross_weight_kg: Optional[float] = None,
        single_quantity: int = 1,
        air_rate_per_kg: float = 0.0,
        courier_rate_per_kg: float = 0.0,
        estimated_rate_per_kg: float = 0.0,
    ) -> Dict[str, Any]:
        """
        Calculates comparison between Standard Air Freight (6000 divisor) and Express Courier (5000 divisor),
        returning chargeable weight difference and cost impact.
        """
        # Determine effective rates
        eff_air_rate = float(air_rate_per_kg or estimated_rate_per_kg or 0.0)
        eff_courier_rate = float(courier_rate_per_kg or estimated_rate_per_kg or 0.0)

        # Standard Air Freight (6000)
        air_metrics = AirFreightService.calculate_air_packages(
            packages=packages,
            single_length_cm=single_length_cm,
            single_width_cm=single_width_cm,
            single_height_cm=single_height_cm,
            single_gross_weight_kg=single_gross_weight_kg,
            single_quantity=single_quantity,
            divisor=IATA_VOLUMETRIC_DIVISOR,
            freight_type="air_freight",
        )

        # Express Courier (5000)
        courier_metrics = AirFreightService.calculate_air_packages(
            packages=packages,
            single_length_cm=single_length_cm,
            single_width_cm=single_width_cm,
            single_height_cm=single_height_cm,
            single_gross_weight_kg=single_gross_weight_kg,
            single_quantity=single_quantity,
            divisor=COURIER_VOLUMETRIC_DIVISOR,
            freight_type="courier",
        )

        air_chg = air_metrics["chargeable_weight_kg"]
        courier_chg = courier_metrics["chargeable_weight_kg"]
        chg_diff = round(courier_chg - air_chg, 2)
        pct_diff = round((chg_diff / air_chg * 100.0), 2) if air_chg > 0 else 0.0

        air_cost = round(air_chg * eff_air_rate, 2) if eff_air_rate > 0 else 0.0
        courier_cost = round(courier_chg * eff_courier_rate, 2) if eff_courier_rate > 0 else 0.0
        cost_diff = round(courier_cost - air_cost, 2)

        if chg_diff > 0:
            rec = f"Air Freight saves {chg_diff} kg ({pct_diff}%) in chargeable weight over Courier due to the 6000 divisor."
        elif chg_diff < 0:
            rec = f"Courier provides a lower chargeable weight by {abs(chg_diff)} kg."
        else:
            rec = "Chargeable weight is identical (governed by gross weight)."

        return {
            "cbm": air_metrics["cbm"],
            "gross_weight_kg": air_metrics["gross_weight_kg"],
            "air_freight": {
                **air_metrics,
                "rate_per_kg": eff_air_rate,
                "estimated_cost": air_cost,
            },
            "courier": {
                **courier_metrics,
                "rate_per_kg": eff_courier_rate,
                "estimated_cost": courier_cost,
            },
            "chargeable_weight_difference_kg": chg_diff,
            "chargeable_weight_increase_percent": pct_diff,
            "cost_difference": cost_diff,
            "recommendation": rec,
        }


def calculate_air_vs_courier_comparison(
    packages: Optional[List[Dict[str, Any]]] = None,
    single_length_cm: Optional[float] = None,
    single_width_cm: Optional[float] = None,
    single_height_cm: Optional[float] = None,
    single_gross_weight_kg: Optional[float] = None,
    single_quantity: int = 1,
    air_rate_per_kg: float = 0.0,
    courier_rate_per_kg: float = 0.0,
    estimated_rate_per_kg: float = 0.0,
) -> Dict[str, Any]:
    """
    Returns metrics comparing Standard Air Freight (6000 divisor) and Express Courier (5000 divisor),
    highlighting chargeable weight difference and cost impact.
    """
    return AirFreightService.calculate_air_vs_courier_comparison(
        packages=packages,
        single_length_cm=single_length_cm,
        single_width_cm=single_width_cm,
        single_height_cm=single_height_cm,
        single_gross_weight_kg=single_gross_weight_kg,
        single_quantity=single_quantity,
        air_rate_per_kg=air_rate_per_kg,
        courier_rate_per_kg=courier_rate_per_kg,
        estimated_rate_per_kg=estimated_rate_per_kg,
    )
