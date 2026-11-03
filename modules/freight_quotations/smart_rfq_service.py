"""
Smart Freight RFQ Generation & Optimization Service (BP-008 & Operational Standards)
Calculates mode-specific metrics (Air 6000 vs Courier 5000 divisor, LCL CBM & Dead-freight, FCL road weight),
validates weight integrity, injects preferential trade agreements (EUR.1), and enforces 21 days free time / Non-TMT terms.
"""

from datetime import date
from typing import List, Optional, Tuple, Dict, Any
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.freight_quotations.schemas import (
    SmartRFQGenerateRequest,
    SmartRFQResponse,
    SmartRFQMetrics,
    SmartRFQPackageItem,
)
from modules.import_files.model import ImportFile


# Operational Constants
IATA_AIR_DIVISOR = 6000.0       # cm3/kg for standard air freight (1 CBM = 166.67 kg)
COURIER_DIVISOR = 5000.0        # cm3/kg for express couriers DHL/FedEx/UPS/Aramex (1 CBM = 200.00 kg)
CBM_DIVISOR = 1_000_000.0       # cm3 per m3 (CBM)
HEAVY_20FT_ROAD_THRESHOLD_KG = 21000.0  # Road transport limit for standard 20' chassis in Europe/Egypt
MAX_SINGLE_LAYER_PALLETS_20FT = 11      # Maximum floor pallets in standard 20' GP container

EU_COUNTRIES = {
    "germany", "france", "italy", "spain", "netherlands", "belgium", "luxembourg",
    "austria", "poland", "sweden", "denmark", "finland", "portugal", "greece",
    "czech republic", "hungary", "romania", "bulgaria", "slovakia", "slovenia",
    "ireland", "croatia", "cyprus", "estonia", "latvia", "lithuania", "malta"
}
EU_COUNTRY_CODES = {
    "de", "fr", "it", "es", "nl", "be", "lu", "at", "pl", "se", "dk",
    "fi", "pt", "gr", "cz", "hu", "ro", "bg", "sk", "si", "ie", "hr",
    "cy", "ee", "lv", "lt", "mt"
}


class SmartRFQService:

    @staticmethod
    def _detect_trade_agreement(country_or_code: Optional[str], text_pool: str = "") -> Optional[str]:
        """
        Determines applicable preferential origin agreement based on country name, ISO code, or text clues.
        """
        combined = f"{country_or_code or ''} {text_pool}".lower()
        if any(code in combined.split() for code in EU_COUNTRY_CODES) or any(c in combined for c in EU_COUNTRIES):
            return "Egypt-EU Association Agreement (EUR.1 / Approved Exporter statement required for preferential duty rate)"
        if "uk" in combined.split() or "gb" in combined.split() or "united kingdom" in combined or "england" in combined or "scotland" in combined:
            return "Egypt-UK Partnership Agreement (UK Origin Declaration required for preferential duty rate)"
        if "tr" in combined.split() or "turkey" in combined or "türkiye" in combined:
            return "Egypt-Turkey Free Trade Agreement (EUR-MED Certificate required)"
        return None

    @staticmethod
    def _normalize_mode(raw_mode: Optional[str]) -> str:
        """
        Normalizes shipment mode to one of: 'AIR', 'COURIER', 'SEA_LCL', 'SEA_FCL'.
        """
        if not raw_mode:
            return "SEA_FCL"
        m = raw_mode.upper().strip()
        if "COURIER" in m or "EXPRESS" in m:
            return "COURIER"
        if "AIR" in m:
            return "AIR"
        if "LCL" in m:
            return "SEA_LCL"
        return "SEA_FCL"

    @classmethod
    def calculate_cargo_metrics(
        cls,
        mode: str,
        packages: Optional[List[SmartRFQPackageItem]],
        manual_gross_kg: Optional[float] = None,
        manual_net_kg: Optional[float] = None,
        manual_cbm: Optional[float] = None,
        is_stackable: bool = True,
        equipment_type: Optional[str] = None,
        container_count: int = 1,
    ) -> SmartRFQMetrics:
        """
        Computes mode-specific measurements:
        - Air: IATA 6000 divisor
        - Courier: Express 5000 divisor
        - Sea LCL: CBM + dead-freight footprint note if non-stackable
        - Sea FCL: road limit check and double-stack pallet verification
        """
        total_qty = 0
        total_gross = 0.0
        total_net = 0.0
        total_cbm = 0.0
        total_volumetric = 0.0

        divisor = None
        if mode == "AIR":
            divisor = IATA_AIR_DIVISOR
        elif mode == "COURIER":
            divisor = COURIER_DIVISOR

        if packages and len(packages) > 0:
            for pkg in packages:
                qty = max(1, pkg.quantity)
                total_qty += qty
                pkg_vol_cbm = ((pkg.length_cm * pkg.width_cm * pkg.height_cm) / CBM_DIVISOR) * qty
                total_cbm += pkg_vol_cbm

                pkg_gross = pkg.gross_weight_kg * (qty if pkg.gross_weight_kg and qty > 1 else 1.0)
                total_gross += pkg_gross

                if pkg.net_weight_kg is not None:
                    pkg_net = pkg.net_weight_kg * (qty if pkg.net_weight_kg and qty > 1 else 1.0)
                    total_net += pkg_net

                if divisor:
                    vol_kg = ((pkg.length_cm * pkg.width_cm * pkg.height_cm) / divisor) * qty
                    total_volumetric += vol_kg
        else:
            total_gross = manual_gross_kg or 0.0
            total_net = manual_net_kg or 0.0
            total_cbm = manual_cbm or 0.0
            if divisor and total_cbm > 0:
                # 1 CBM in Air = 166.67 kg (1,000,000 / 6000); in Courier = 200 kg (1,000,000 / 5000)
                total_volumetric = total_cbm * (CBM_DIVISOR / divisor)

        # Apply manual overrides if given
        if manual_gross_kg is not None and manual_gross_kg > 0:
            total_gross = manual_gross_kg
        if manual_net_kg is not None and manual_net_kg > 0:
            total_net = manual_net_kg
        if manual_cbm is not None and manual_cbm > 0:
            total_cbm = manual_cbm

        total_gross = round(total_gross, 2)
        total_net = round(total_net, 2)
        total_cbm = round(total_cbm, 4)
        total_volumetric = round(total_volumetric, 2)

        # STRICT VALIDATION: Gross Weight >= Net Weight
        if total_gross > 0 and total_net > 0 and total_net > total_gross:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"خطأ فني في الأوزان: الوزن الصافي ({total_net:,.2f} كجم) لا يمكن أن يكون أكبر من الوزن الإجمالي ({total_gross:,.2f} كجم).",
            )

        # Mode-specific chargeable calculations
        chargeable_weight_kg = total_gross
        is_vol_higher = False
        dead_freight = False

        if mode in ("AIR", "COURIER"):
            chargeable_weight_kg = round(max(total_gross, total_volumetric), 2)
            is_vol_higher = total_volumetric > total_gross
        elif mode == "SEA_LCL":
            # For ocean LCL: 1 CBM = 1000 kg (1 ton)
            weight_in_tons = total_gross / 1000.0
            chargeable_weight_kg = round(max(total_gross, total_cbm * 1000.0), 2)
            is_vol_higher = total_cbm > weight_in_tons
            if not is_stackable:
                dead_freight = True

        # FCL checks
        is_heavy_road = False
        road_warning = None
        is_double_stack = False

        eq_upper = (equipment_type or "").upper()
        if mode == "SEA_FCL":
            if "20" in eq_upper and total_gross >= HEAVY_20FT_ROAD_THRESHOLD_KG:
                is_heavy_road = True
                road_warning = (
                    f"Heavy Road Weight ({total_gross:,.0f} KGS): Strictly verify road payload limits "
                    "with carrier/haulage provider (tri-axle chassis may be required)."
                )
            if "20" in eq_upper and total_qty > MAX_SINGLE_LAYER_PALLETS_20FT:
                is_double_stack = True

        return SmartRFQMetrics(
            shipment_mode=mode,
            total_packages_count=total_qty,
            total_gross_weight_kg=total_gross,
            total_net_weight_kg=total_net,
            total_volume_cbm=total_cbm,
            chargeable_weight_kg=chargeable_weight_kg,
            volumetric_divisor=divisor,
            is_volumetric_higher=is_vol_higher,
            is_stackable=is_stackable,
            dead_freight_applied=dead_freight,
            is_heavy_road_cargo=is_heavy_road,
            road_weight_warning=road_warning,
            is_double_stackable=is_double_stack,
            free_days_at_pod=21,
            terminal_restriction=None,
        )

    @classmethod
    def generate_smart_rfq(
        cls,
        db: Optional[Session],
        req: SmartRFQGenerateRequest,
    ) -> SmartRFQResponse:
        """
        Orchestrates full Smart RFQ generation from an import file or custom request.
        """
        import_file: Optional[ImportFile] = None
        if req.import_file_id and db:
            import_file = db.query(ImportFile).filter(
                ImportFile.import_file_id == req.import_file_id,
                ImportFile.is_active == True,
            ).first()

        # Resolve field values with fallback hierarchy (Request > ImportFile > Defaults)
        mode_raw = req.shipment_mode or (import_file.shipment_mode if import_file else "Sea FCL")
        mode = cls._normalize_mode(mode_raw)

        incoterm = req.incoterm_code or (import_file.incoterm_code if import_file else "EXW")
        pickup_addr = req.pickup_address or (import_file.pickup_address if import_file else None) or "Shipper's Warehouse / Factory"
        pol = req.port_of_loading or (import_file.port_of_loading if import_file else None) or "Nearest International Port/Airport"
        pod = req.port_of_discharge or (import_file.port_of_discharge if import_file else None) or "El Dekheila Port, Alexandria, Egypt"
        crd = req.cargo_ready_date or (import_file.cargo_ready_date if import_file else None) or date.today()
        commodity = req.commodity_description or (import_file.product_category if import_file else None) or "General Cargo"
        hs_code = req.hs_code or (import_file.hs_code if import_file else None) or "N/A"
        consignee_name = (import_file.company_name if import_file else None) or "ARCHI BRANDS FOR CARPET AND FLOOR TRADING"
        file_ref = (import_file.import_file_code if import_file else None) or "IMP-RFQ-DRAFT"
        po_ref = (import_file.po_number if import_file else None) or "PO-REF"

        equipment = req.equipment_type
        if not equipment:
            if mode == "SEA_FCL":
                equipment = "1 x 40' High Cube (40'HC)"
            elif mode == "SEA_LCL":
                equipment = "LCL Consolidation"
            elif mode == "AIR":
                equipment = "Air Cargo"
            else:
                equipment = "Door-to-Door Express Courier"

        # Extract packing list data from import_file if packages not explicitly provided
        packages = req.packages
        manual_gross = req.manual_gross_weight_kg
        manual_net = req.manual_net_weight_kg
        manual_cbm = req.manual_volume_cbm

        if not packages and not manual_gross and import_file and import_file.packing_lists_data:
            try:
                pl_data = import_file.packing_lists_data
                if isinstance(pl_data, list) and len(pl_data) > 0:
                    first_pl = pl_data[0]
                    manual_gross = float(first_pl.get("gross_weight_kg") or 0.0)
                    manual_net = float(first_pl.get("net_weight_kg") or 0.0)
                    manual_cbm = float(first_pl.get("cbm") or 0.0)
            except Exception:
                pass

        # Compute cargo metrics
        metrics = cls.calculate_cargo_metrics(
            mode=mode,
            packages=packages,
            manual_gross_kg=manual_gross,
            manual_net_kg=manual_net,
            manual_cbm=manual_cbm,
            is_stackable=req.is_stackable if req.is_stackable is not None else True,
            equipment_type=equipment,
            container_count=req.container_count or 1,
        )

        # Destination & Terminal Checks
        pod_lower = pod.lower()
        is_dekheila_alex = "dekheila" in pod_lower or "alexandria" in pod_lower or "إسكندرية" in pod_lower or "دخيلة" in pod_lower
        if is_dekheila_alex:
            metrics.free_days_at_pod = req.target_free_days or 21
            if req.avoid_tmt_terminal:
                metrics.terminal_restriction = "Direct El Dekheila Terminal (TMT Yard MUST BE STRICTLY AVOIDED)"
        else:
            metrics.free_days_at_pod = req.target_free_days or 14

        # Preferential Trade Agreement Check
        origin_text = f"{pickup_addr} {pol}"
        trade_agreement = cls._detect_trade_agreement(None, origin_text)
        metrics.trade_agreement_applicable = trade_agreement

        # Build mode-specific email subject & body
        subject, body = cls._render_rfq_content(
            mode=mode,
            file_ref=file_ref,
            po_ref=po_ref,
            incoterm=incoterm,
            pickup_addr=pickup_addr,
            pol=pol,
            pod=pod,
            crd=crd,
            commodity=commodity,
            hs_code=hs_code,
            consignee_name=consignee_name,
            equipment=equipment,
            container_count=req.container_count or 1,
            packages=packages,
            metrics=metrics,
            is_dg=req.is_dangerous_goods or False,
            has_battery=req.has_lithium_battery or False,
            custom_notes=req.custom_notes,
        )

        warnings: List[str] = []
        if metrics.road_weight_warning:
            warnings.append(metrics.road_weight_warning)
        if metrics.dead_freight_applied:
            warnings.append("LCL Cargo is strictly Non-Stackable; freight forwarder may charge volume based on full container height clearance.")
        if metrics.is_volumetric_higher:
            warnings.append(f"Chargeable weight is driven by Volume ({metrics.chargeable_weight_kg:,.2f} KG vs {metrics.total_gross_weight_kg:,.2f} KG Gross).")

        return SmartRFQResponse(
            subject=subject,
            body_text=body,
            metrics=metrics,
            warnings=warnings,
        )

    @staticmethod
    def _render_rfq_content(
        mode: str,
        file_ref: str,
        po_ref: str,
        incoterm: str,
        pickup_addr: str,
        pol: str,
        pod: str,
        crd: date,
        commodity: str,
        hs_code: str,
        consignee_name: str,
        equipment: str,
        container_count: int,
        packages: Optional[List[SmartRFQPackageItem]],
        metrics: SmartRFQMetrics,
        is_dg: bool,
        has_battery: bool,
        custom_notes: Optional[str] = None,
    ) -> Tuple[str, str]:
        """
        Renders clean, professional, mode-tailored RFQ subject and message body.
        """
        crd_str = crd.strftime("%d %b %Y") if hasattr(crd, "strftime") else str(crd)
        dg_label = "DANGEROUS GOODS (MSDS Attached)" if is_dg else "Non-Dangerous Goods (Non-DG / General Cargo)"
        battery_label = "Lithium Batteries Included (Section II compliant)" if has_battery else "No Lithium Batteries"

        # Packages breakdown string
        pkg_desc_lines = []
        if packages:
            for idx, p in enumerate(packages, 1):
                p_gross = p.gross_weight_kg * (p.quantity if p.gross_weight_kg and p.quantity > 1 else 1.0)
                pkg_desc_lines.append(
                    f"   - Item {idx}: {p.quantity} x {p.package_type or 'Pkg'} @ "
                    f"{p.length_cm:.0f} x {p.width_cm:.0f} x {p.height_cm:.0f} cm | Gross: {p_gross:,.2f} KGS"
                )
            pkg_str = "\n".join(pkg_desc_lines)
        else:
            pkg_str = f"   - Packaging: Standard export packaging ({metrics.total_packages_count or 'N/A'} packages)"

        # ----------------------------------------------------
        # 1. SEA FREIGHT (FCL)
        # ----------------------------------------------------
        if mode == "SEA_FCL":
            subject = f"RFQ - SEA FCL / {incoterm} - {file_ref} - {pol} to {pod} - {equipment}"

            terminal_instruction = ""
            if metrics.terminal_restriction:
                terminal_instruction = f"\n   - Terminal Preference: {metrics.terminal_restriction}"

            double_stack_note = ""
            if metrics.is_double_stackable:
                double_stack_note = "\n   - Internal Stacking: Certified Double-Stackable inside container"

            road_weight_note = ""
            if metrics.is_heavy_road_cargo:
                road_weight_note = " (Heavy Cargo - Strictly adhering to road weight limits)"

            trade_note = ""
            if metrics.trade_agreement_applicable:
                trade_note = f"\n   - Origin Documentation: Assistance with {metrics.trade_agreement_applicable}"

            body = f"""Dear Shipping Partner,

Please provide your best All-in {incoterm} freight quotation and earliest direct sailing schedule for the containerized cargo detailed below:

1. SHIPMENT REFERENCES & INCOTERMS:
   - File Reference: {file_ref} | PO: {po_ref}
   - Incoterm: {incoterm}
   - Cargo Ready Date (CRD): {crd_str}
   - Consignee: {consignee_name}

2. ROUTING & PORTS:
   - Pick-up Address: {pickup_addr}
   - Port of Loading (POL): {pol}
   - Port of Discharge (POD): {pod}{terminal_instruction}

3. CONTAINER & CARGO SPECIFICATIONS:
   - Equipment: {container_count} x {equipment}
   - Commodity: {commodity} (HS Code: {hs_code})
   - Total Gross Weight: {metrics.total_gross_weight_kg:,.2f} KGS{road_weight_note}
   - Total Net Weight: {metrics.total_net_weight_kg:,.2f} KGS
   - Estimated Volume: {metrics.total_volume_cbm:,.2f} CBM{double_stack_note}
   - Cargo Classification: {dg_label}
{pkg_str}

4. MANDATORY SERVICE TERMS:
   - Routing: DIRECT service ONLY (No transshipment).
   - Free Time at POD: Minimum {metrics.free_days_at_pod} Days Combined Free Time (Demurrage + Detention).{trade_note}

5. REQUIRED RATE BREAKDOWN:
   - Ex-Works Pick-up & Inland Haulage to POL
   - Export Customs Clearance & Origin Port Charges (OTHC)
   - Ocean Freight (All-in rate including BAF, LSS, and standard surcharges)
   - Destination DTHC
   - Schedule: Carrier name, Cut-off date, ETD, ETA, and Transit Time.
"""
            if custom_notes:
                body += f"\nSpecial Instructions:\n{custom_notes}\n"
            return subject, body.strip()

        # ----------------------------------------------------
        # 2. SEA FREIGHT (LCL)
        # ----------------------------------------------------
        elif mode == "SEA_LCL":
            subject = f"RFQ - SEA LCL / {incoterm} - {file_ref} - {pol} to {pod} - {metrics.total_volume_cbm:.2f} CBM / {metrics.total_gross_weight_kg:,.0f} KG"

            stack_str = "Strictly NON-STACKABLE (Please factor into CFS container stowage)" if not metrics.is_stackable else "Stackable cargo"
            trade_note = ""
            if metrics.trade_agreement_applicable:
                trade_note = f"\n   - Origin Documentation: Assistance with {metrics.trade_agreement_applicable}"

            body = f"""Dear Consolidation Partner,

Please provide your best LCL consolidation rate and earliest schedule for the shipment detailed below:

1. SHIPMENT REFERENCES & INCOTERMS:
   - File Reference: {file_ref} | PO: {po_ref}
   - Incoterm: {incoterm}
   - Cargo Ready Date (CRD): {crd_str}
   - Consignee: {consignee_name}

2. ROUTING & CFS DETAILS:
   - Shipper Pick-up Address: {pickup_addr}
   - CFS Port of Loading: {pol}
   - Destination CFS (POD): {pod}

3. DIMENSIONS, VOLUME & WEIGHT:
   - Commodity: {commodity} (HS Code: {hs_code})
   - Packaging Breakdown:
{pkg_str}
   - Actual Total Volume: {metrics.total_volume_cbm:,.3f} CBM
   - Total Gross Weight: {metrics.total_gross_weight_kg:,.2f} KGS
   - Total Net Weight: {metrics.total_net_weight_kg:,.2f} KGS
   - Stacking Status: {stack_str}
   - Cargo Classification: {dg_label}

4. SPECIAL CONDITIONS:
   - Cargo Handover: Full export packing and palletized.{trade_note}

5. QUOTATION BREAKDOWN REQUIRED:
   - Ex-Works Pick-up from shipper to origin CFS
   - Export Customs Formalities & Origin CFS Handling
   - Ocean Freight rate per W/M (Weight or Measure: 1 CBM = 1,000 KG)
   - Destination CFS Handling & De-stuffing fees at {pod}
   - Available CFS Cut-off date, ETD, ETA, and total Transit Time.
"""
            if custom_notes:
                body += f"\nSpecial Instructions:\n{custom_notes}\n"
            return subject, body.strip()

        # ----------------------------------------------------
        # 3. AIR FREIGHT
        # ----------------------------------------------------
        elif mode == "AIR":
            subject = f"URGENT RFQ - AIR FREIGHT / {incoterm} - {file_ref} - {pol} to {pod} - {metrics.chargeable_weight_kg:,.1f} KG CW (IATA 1:6000)"

            comp_note = (
                "Chargeable Weight is driven by VOLUMETRIC WEIGHT"
                if metrics.is_volumetric_higher
                else "Chargeable Weight is driven by ACTUAL GROSS WEIGHT"
            )

            body = f"""Dear Airfreight Operations Team,

Please submit your most competitive air cargo rate and earliest flight schedule (Direct flight preferred) for the urgent cargo detailed below:

1. SHIPMENT REFERENCES & PRIORITY:
   - File Reference: {file_ref} | PO: {po_ref}
   - Incoterm: {incoterm}
   - Cargo Ready Date: {crd_str}
   - Consignee: {consignee_name}

2. AIR ROUTING:
   - Pick-up Address: {pickup_addr}
   - Airport of Departure (AOD): {pol}
   - Airport of Destination (AOA): {pod}

3. CARGO DIMENSIONS & IATA CHARGEABLE WEIGHT:
   - Commodity: {commodity} (HS Code: {hs_code})
   - Packaging Details:
{pkg_str}
   - Total Actual Gross Weight: {metrics.total_gross_weight_kg:,.2f} KGS
   - Total Net Weight: {metrics.total_net_weight_kg:,.2f} KGS
   - Total Volume: {metrics.total_volume_cbm:,.3f} CBM
   - Volumetric Weight (IATA Divisor 6000 cm³/kg): {metrics.chargeable_weight_kg:,.2f} KGS
   - Chargeable Weight (CW): {metrics.chargeable_weight_kg:,.2f} KGS ({comp_note})
   - Dangerous Goods: {dg_label}
   - Battery Statement: {battery_label}

4. REQUIRED RATE BREAKDOWN:
   - Origin Pick-up & Transfer to Airport Terminal
   - German/European Export Customs & Security Screening (X-Ray)
   - Airfreight Net/Net All-in rate per KG (including FSC fuel & SSC security)
   - Confirmed Flight Schedule: Airline name, Flight Number, Routing (Direct preferred), ETD, ETA.
"""
            if custom_notes:
                body += f"\nSpecial Instructions:\n{custom_notes}\n"
            return subject, body.strip()

        # ----------------------------------------------------
        # 4. COURIER (EXPRESS)
        # ----------------------------------------------------
        else:
            subject = f"EXPRESS COURIER RFQ - Door-to-Door / {file_ref} - {pol} to {pod} - {metrics.chargeable_weight_kg:,.1f} KG CW (Divisor 5000)"

            body = f"""Dear Express Courier Desk,

Please provide your best Door-to-Door express tariff and earliest collection window for the parcel shipment detailed below:

1. SHIPMENT REFERENCES:
   - File Reference: {file_ref} | PO: {po_ref}
   - Service Required: Express Door-to-Door Courier
   - Cargo Ready Date: {crd_str}

2. SHIPPER & COLLECTION ADDRESS:
   - Collection Address: {pickup_addr}

3. CONSIGNEE & DELIVERY ADDRESS:
   - Consignee: {consignee_name}
   - Destination City/Airport: {pod}

4. PARCEL SPECIFICATIONS & EXPRESS VOLUMETRIC CALCULATION:
   - Commodity: {commodity} (HS Code: {hs_code})
   - Packages Details:
{pkg_str}
   - Actual Gross Weight: {metrics.total_gross_weight_kg:,.2f} KGS
   - Actual Net Weight: {metrics.total_net_weight_kg:,.2f} KGS
   - Express Volumetric Weight (Divisor 5000 cm³/kg): {metrics.chargeable_weight_kg:,.2f} KGS
   - Chargeable Weight (CW): {metrics.chargeable_weight_kg:,.2f} KGS
   - Cargo Nature: {dg_label}

5. QUOTATION REQUIREMENTS:
   - Door-to-Door All-inclusive Express Freight (including Fuel Surcharge)
   - Local Egyptian clearance admin charges
   - Estimated Delivery Lead Time (business days).
"""
            if custom_notes:
                body += f"\nSpecial Instructions:\n{custom_notes}\n"
            return subject, body.strip()
