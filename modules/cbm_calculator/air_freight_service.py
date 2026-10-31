"""
Air Freight Volumetric & Chargeable Weight Calculation Service
Based on IATA standards: 1 CBM = 166.67 kg (Divisor 6000 cm3/kg).
"""

from typing import Any, Dict, List, Optional


IATA_VOLUMETRIC_DIVISOR = 6000.0  # cm3 per kg
CM3_PER_CBM = 1_000_000.0


def calculate_volumetric_weight_iata(
    length_cm: float,
    width_cm: float,
    height_cm: float,
    quantity: int = 1,
) -> float:
    """
    Calculates IATA air volumetric weight:
    volumetric_weight = (length_cm * width_cm * height_cm) / 6000.0 * quantity
    """
    if length_cm <= 0 or width_cm <= 0 or height_cm <= 0 or quantity <= 0:
        return 0.0
    vol_per_unit = (length_cm * width_cm * height_cm) / IATA_VOLUMETRIC_DIVISOR
    return round(vol_per_unit * quantity, 2)


def calculate_chargeable_weight(gross_weight_kg: float, volumetric_weight_kg: float) -> float:
    """
    Calculates air chargeable weight:
    chargeable_weight = max(gross_weight, volumetric_weight)
    """
    return round(max(float(gross_weight_kg or 0.0), float(volumetric_weight_kg or 0.0)), 2)


class AirFreightService:
    """
    Service for calculating Air Freight cargo measurements and IATA chargeable weights.
    """

    @staticmethod
    def calculate_dimensions(
        length_cm: float,
        width_cm: float,
        height_cm: float,
        gross_weight_kg: float = 0.0,
        quantity: int = 1,
    ) -> Dict[str, Any]:
        """
        Calculate volumetric weight, chargeable weight, and CBM for a single package specification.
        """
        qty = max(1, quantity)
        gross_total = round(float(gross_weight_kg or 0.0) * (qty if gross_weight_kg and quantity > 1 else 1), 2)
        volumetric_total = calculate_volumetric_weight_iata(length_cm, width_cm, height_cm, qty)
        cbm_total = round(((length_cm * width_cm * height_cm) / CM3_PER_CBM) * qty, 4)
        chargeable_total = calculate_chargeable_weight(gross_total, volumetric_total)

        return {
            "gross_weight_kg": gross_total,
            "volumetric_weight_kg": volumetric_total,
            "chargeable_weight_kg": chargeable_total,
            "cbm": cbm_total,
            "is_higher_volumetric": volumetric_total > gross_total,
            "divisor": IATA_VOLUMETRIC_DIVISOR,
        }

    @staticmethod
    def calculate_air_packages(
        packages: Optional[List[Dict[str, Any]]] = None,
        single_length_cm: Optional[float] = None,
        single_width_cm: Optional[float] = None,
        single_height_cm: Optional[float] = None,
        single_gross_weight_kg: Optional[float] = None,
        single_quantity: int = 1,
    ) -> Dict[str, Any]:
        """
        Calculates aggregate air cargo metrics across single or multiple packages.
        """
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
                line_vol = calculate_volumetric_weight_iata(l, w, h, qty)
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
            "details": details,
        }
