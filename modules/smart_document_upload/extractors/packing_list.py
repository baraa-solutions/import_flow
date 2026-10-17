"""
Packing List Extractor
Extracts structured packing list numbers, supplier, consignee, ACID, Tax ID,
package counts, pallets, gross/net weights, dimensions, CBM, and line items.
"""

from __future__ import annotations

import re
from typing import Any, Dict, List, Optional

from modules.smart_document_upload.extractors.base_extractor import BaseExtractor


class PackingListExtractor(BaseExtractor):
    """
    Enhanced Packing List Extractor.
    Extracts structured fields from international Packing Lists & Weight Lists
    (Viccarbe Spanish dual-tier, Narbutas Lithuanian hierarchical BOM,
     Impact Acoustic inline dimensions & pallets manifest, G.I. Industrial bilingual blocks,
     and Asian/Chinese multi-row tables).
    """

    def required_fields(self) -> List[str]:
        return ["packing_list_number", "total_gross_weight_kg", "total_packages"]

    def extract(self, raw_text: str, spatial_boxes: dict) -> Dict[str, Any]:
        text = (raw_text or "").replace("\r", "\n")

        # 1. Delegate to the comprehensive ai_document_parser engine
        try:
            from modules.import_documentation.ai_document_parser import (
                extract_packing_list_data,
            )
            parsed = extract_packing_list_data(text)
        except Exception:
            parsed = {}

        # 2. Extract or supplement fields with robust regex fallbacks
        packing_list_number = parsed.get("packing_list_number") or self.find_first([
            r"(?:PACKING\s*N[º°o]\.?|PACKING\s*SLIP\s*Nr\.?|PACKING\s*LIST\s*N[º°o]?\.?|PACKING\s*LIST\s*NO\.?|PACKING\s*LIST\s*#|DOC(?:UMENT)?\s*NO\.?|DELIVERY\s*NOTE\s*NO\.?)[:\s]*([^\n\r]{3,35})",
            r"(?:Packing\s+List)[:\s#]*([A-Z0-9\-_]{4,30})",
            r"(?:Document\s+No\.?|Doc\s+No\.?|Document\s+Nr\.?)[:\s]*([A-Z0-9/\-]{3,30})",
            r"\bNr\.\s*([A-Z0-9\-_]{5,25})\b",
        ], text)
        if packing_list_number:
            packing_list_number = re.sub(r"\s+(?:Date|Milan|PO|August|Load\s*ID).*$", "", str(packing_list_number), flags=re.I).strip()

        # 19-digit Egyptian ACID
        acid_number = parsed.get("acid_number") or self.find_first([
            r"(?:ACID|ACI\s+NO|ADVANCE\s+CARGO\s+INFO|ACID:\s*|ACID\s+#)[:\s#,-]*([0-9a-zA-Z]{19})",
            r"\b(\d{19})\b",
        ], text)
        if acid_number:
            acid_number = re.sub(r"[^0-9]", "", str(acid_number))
            if len(acid_number) != 19:
                acid_number = parsed.get("acid_number")

        # Importer Tax ID (9 digits)
        importer_tax_id = parsed.get("importer_tax_id")
        if not importer_tax_id:
            m_tax = re.search(r"(?:TAX\s*ID|VAT\s*NO|TAX\s*NO|REGISTRATION\s*NO)[:\s]*(\d{3}[-\s]?\d{3}[-\s]?\d{3})\b", text, re.I)
            if m_tax:
                importer_tax_id = re.sub(r"[-\s]", "", m_tax.group(1).strip())
            elif acid_number and len(str(acid_number)) == 19:
                importer_tax_id = str(acid_number)[:9]

        supplier_name = parsed.get("supplier_name") or parsed.get("shipper") or self.find_first([
            r"(?:SHIPPER|EXPORTER|SUPPLIER)[:\s]*([^\n\r]+)",
            r"\b(UAB\s+Narbutas\s+International|Viccarbe|IMPACT\s+ACOUSTIC\s+S\.R\.L\.|G\.I\.\s*INDUSTRIAL\s+HOLDING\s+SPA|Suzhou\s+Yuheng\s+Textile\s+Co\.?,?\s*Ltd\.?)\b",
        ], text)

        consignee_name = parsed.get("consignee_name") or parsed.get("importer_name") or self.find_first([
            r"(?:CONSIGNEE|IMPORTER|BUYER|CUSTOMER)[:\s]*([^\n\r]+)",
            r"\b(SCAS|Archi\s+Brands\s+for\s+Corpet\s+and\s+Floor\s+Trading|ECO\s+ASSOCIATES)\b",
        ], text)

        date_val = parsed.get("date")

        total_packages = parsed.get("total_packages") or parsed.get("packages_count")
        pallets_count = parsed.get("pallets_count")
        total_gross_weight = parsed.get("total_gross_weight_kg")
        total_net_weight = parsed.get("total_net_weight_kg")
        total_cbm = parsed.get("total_cbm")

        items = parsed.get("items", [])
        pallets = parsed.get("pallets", [])

        return {
            "document_type": "Packing and Weight List",
            "packing_list_number": packing_list_number,
            "date": date_val,
            "acid_number": acid_number,
            "importer_tax_id": importer_tax_id,
            "supplier_name": supplier_name,
            "shipper_name": supplier_name,
            "consignee_name": consignee_name,
            "importer_name": consignee_name,
            "order_number": parsed.get("order_number"),
            "po_number": parsed.get("po_number"),
            "sales_order": parsed.get("sales_order"),
            "load_id": parsed.get("load_id"),
            "terms_of_delivery": parsed.get("terms_of_delivery"),
            "incoterm": parsed.get("incoterm"),
            "total_packages": total_packages,
            "packages_count": total_packages,
            "pallets_count": pallets_count,
            "total_gross_weight_kg": total_gross_weight,
            "total_net_weight_kg": total_net_weight,
            "pallet_gross_weight_kg": parsed.get("pallet_gross_weight_kg"),
            "total_cbm": total_cbm,
            "pallet_cbm": parsed.get("pallet_cbm"),
            "items": items,
            "items_count": len(items),
            "pallets": pallets,
            "pallets_manifest_count": len(pallets),
        }
