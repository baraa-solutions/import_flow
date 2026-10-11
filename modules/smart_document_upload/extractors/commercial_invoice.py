"""
Commercial Invoice Extractor
Extracts structured header fields, financial totals, and itemized line items
from Commercial Invoices (PDF, Excel, Word, or plain text) for ImportFlow ERP.
"""

from __future__ import annotations

import re
from typing import Any, Dict, List, Optional

from modules.smart_document_upload.extractors.base_extractor import BaseExtractor


class CommercialInvoiceExtractor(BaseExtractor):
    """
    Enhanced Commercial Invoice Extractor.
    Extracts 19-digit ACID, Importer Tax ID, Exporter ID, Incoterms, Currency,
    Financial totals (FOB, Freight, Insurance, CIF), and line items.
    """

    def required_fields(self) -> List[str]:
        return ["invoice_number", "invoice_value", "currency"]

    def extract(self, raw_text: str, spatial_boxes: dict) -> Dict[str, Any]:
        text = (raw_text or "").replace("\r", "\n")

        # 1. Delegate to the comprehensive ai_document_parser invoice engine
        try:
            from modules.import_documentation.ai_document_parser import (
                extract_commercial_invoice_data,
            )
            parsed = extract_commercial_invoice_data(text)
        except Exception:
            parsed = {}

        # 2. Extract or supplement fields with robust regex fallbacks
        invoice_number = parsed.get("invoice_number") or self.find_first([
            r"(?:INV\.?\s*NO\.?|INVOICE\s+NO\.?|INVOICE\s+NUMBER|COMMERCIAL\s+INVOICE\s+NO\.?|INV\s*#|BILL\s+NO\.?)[:\s]*([A-Z0-9/\-]{3,30})",
            r"(?:Document\s+No\.?|Doc\s+No\.?|Document\s+Nr\.?)[:\s]*([A-Z0-9/\-]{3,30})",
            r"(?:Invoice\s+No\.?|Invoice\s+#|INV\s*#|INV\s+NO)[:\s]*([A-Z0-9/\-]{3,30})",
            r"(?:Commercial\s+Invoice)[:\s#]*([A-Z0-9/\-]{3,30})",
            r"Invoice\s*:\s*([A-Z0-9/\-]{3,30})",
            r"Invoice\s+([A-Z0-9/\-]{3,30})",
        ], text)

        invoice_date = parsed.get("invoice_date") or self.find_first([
            r"(?:Invoice\s+Date|Date\s+of\s+Issue|Issue\s+Date|Date|INV\.DATE)[:\s]+(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})",
            r"(?:Date)[:\s]+(\d{4}-\d{2}-\d{2})",
        ], text)

        # 19-digit ACID Number
        acid_number = parsed.get("acid_number") or self.find_first([
            r"(?:ACID|ACI\s+NO|ADVANCE\s+CARGO\s+INFO|ACID:\s*|ACID\s+#)[:\s#,-]*([0-9a-zA-Z]{19})",
            r"\b(\d{19})\b",
        ], text)
        if acid_number:
            acid_number = re.sub(r"[^0-9]", "", str(acid_number))
            if len(acid_number) != 19:
                acid_number = parsed.get("acid_number")

        importer_tax_id = parsed.get("importer_tax_id") or self.find_first([
            r"(?:IMPORTER\s+TAX\s+ID|TAX\s+ID|VAT\s+ID|TAX\s+REG|EGYPTIAN\s+TAX\s+REG)[:\s#]*(\d{3}[-\s]?\d{3}[-\s]?\d{3}|\d{9})",
        ], text)
        if importer_tax_id:
            importer_tax_id = re.sub(r"[\s-]", "", str(importer_tax_id))
        elif acid_number and len(str(acid_number)) == 19:
            importer_tax_id = str(acid_number)[:9]

        exporter_registration_no = parsed.get("exporter_registration_no") or self.find_first([
            r"(?:EXPORTER\s+REGISTRATION\s+NO|EXPORTER\s+ID|VAT\s+NO|P\.IVA)[:\s#]+([A-Z0-9/_-]+)",
        ], text)

        supplier_name = parsed.get("supplier_name") or parsed.get("shipper") or self.find_first([
            r"(?:Seller|Supplier|Exporter|From|Beneficiary)[:\s]+([A-Za-z0-9\s&,.'-]{3,60}?)(?:\n|,|\|)",
            r"(?:Shipper)[:\s]+([A-Za-z0-9\s&,.'-]{3,60}?)(?:\n|,|\|)",
        ], text)

        importer_name = parsed.get("importer_name") or parsed.get("consignee") or self.find_first([
            r"(?:Buyer|Importer|Consignee|To|Bill\s+To)[:\s]+([A-Za-z0-9\s&,.'-]{3,60}?)(?:\n|,|\|)",
        ], text)

        # 3. Line Items Extraction
        items = parsed.get("items") or []
        if not items:
            items = self._fallback_extract_line_items(text)

        origin_country = parsed.get("origin_country")
        if not origin_country or origin_country.upper() in ["UNIT", "PRICE", "UOM", "RATE"]:
            origin_country = self.find_first([
                r"(?:Country\s+of\s+Origin|Origin)[:\s]+(United\s+Kingdom|Italy|Germany|Spain|China|Lithuania|[A-Za-z\s]{3,40}?)(?:\n|,|\|)",
                r"(?:Made\s+in)[:\s]+([A-Za-z\s]{3,30})",
            ], text)
            if origin_country and origin_country.upper() in ["UNIT", "PRICE", "UOM", "RATE"]:
                origin_country = None
        if not origin_country:
            for it in items:
                if it.get("country_of_origin"):
                    origin_country = it["country_of_origin"]
                    break
        if not origin_country:
            if re.search(r'\b(?:China|Changshu|Suzhou|Shanghai|Shenzhen|Ningbo)\b', text, re.IGNORECASE):
                origin_country = "China"

        loading_port = parsed.get("loading_port") or self.find_first([
            r"(?:Port\s+of\s+Loading|POL|Departure\s+Port)[:\s]+([A-Za-z\s,]{3,50}?)(?:\n|,|\|)",
            r"FROM\s+([A-Za-z\s]+?)\s+TO\s+",
        ], text)

        discharge_port = parsed.get("discharge_port") or self.find_first([
            r"(?:Port\s+of\s+Discharge|POD|Destination\s+Port)[:\s]+([A-Za-z\s,]{3,50}?)(?:\n|,|\|)",
            r"FROM\s+[A-Za-z\s]+?\s+TO\s+([A-Za-z\s]+)",
        ], text)

        incoterms = parsed.get("incoterms") or self.normalize_incoterms(text)
        currency = parsed.get("currency") or self.normalize_currency(text)

        invoice_value = parsed.get("invoice_value") or parsed.get("total_amount") or self.find_float([
            r"(?:Total\s+Amount|Grand\s+Total|Invoice\s+Total|Total\s+Value|Total)[:\s]+(?:[A-Z]{3}\s*)?([0-9,]+\.?\d*)",
            r"(?:Amount\s+Due)[:\s]+(?:[A-Z]{3}\s*)?([0-9,]+\.?\d*)",
        ], text)

        freight_amount = parsed.get("freight_amount") or self.find_float([
            r"(?:Freight\s+Amount|Ocean\s+Freight|Freight\s+Charge|Shipping\s+Total|Freight\s+Total)[:\s]+(?:[A-Z]{3}\s*|[$€£])?\s*([0-9,]+\.?\d*)",
        ], text)

        insurance_amount = parsed.get("insurance_amount") or self.find_float([
            r"(?:Insurance\s+Amount|Insurance\s+Fee)[:\s]+(?:[A-Z]{3}\s*|[$€£])?\s*([0-9,]+\.?\d*)",
        ], text)

        # 4. Total Gross and Net Weight if specified on invoice
        total_gross_weight_kg = parsed.get("total_gross_weight_kg") or self.find_float([
            r"(?:Total\s+Gross\s+Weight|Gross\s+Weight|G\.W\.)[:\s]+([0-9,]+\.?\d*)\s*(?:KGS?|KG)?",
        ], text)

        total_net_weight_kg = parsed.get("total_net_weight_kg") or self.find_float([
            r"(?:Total\s+Net\s+Weight|Net\s+Weight|N\.W\.)[:\s]+([0-9,]+\.?\d*)\s*(?:KGS?|KG)?",
        ], text)

        pallets_count = parsed.get("pallets_count") or parsed.get("qty_pallets")
        if not pallets_count:
            pal_str = self.find_first([
                r"(?:Number\s+of\s+pallets|Total\s+pallets)[:\s]*(\d+)",
                r"(?:^|\n)\s*(\d+)\s*(?:x\s*)?pallets?(?!\s*@)",
                r"\b(\d+)\s*(?:x\s*)?pallets?",
            ], text)
            if pal_str:
                try:
                    pallets_count = int(pal_str)
                except Exception:
                    pass

        result: Dict[str, Any] = {
            "invoice_number": invoice_number,
            "invoice_date": invoice_date,
            "acid_number": acid_number,
            "importer_tax_id": importer_tax_id,
            "exporter_registration_no": exporter_registration_no,
            "supplier_name": supplier_name.strip() if supplier_name else None,
            "importer_name": importer_name.strip() if importer_name else None,
            "origin_country": origin_country.strip() if origin_country else None,
            "loading_port": loading_port.strip() if loading_port else None,
            "discharge_port": discharge_port.strip() if discharge_port else None,
            "incoterms": incoterms,
            "currency": currency or "USD",
            "invoice_value": invoice_value or 0.0,
            "subtotal": parsed.get("subtotal") or invoice_value or 0.0,
            "freight_amount": freight_amount or 0.0,
            "insurance_amount": insurance_amount or 0.0,
            "total_gross_weight_kg": total_gross_weight_kg,
            "total_net_weight_kg": total_net_weight_kg,
            "volume_cbm": parsed.get("volume_cbm"),
            "packages_count": parsed.get("packages_count") or parsed.get("qty_pkg"),
            "pallets_count": pallets_count,
            "is_preferential_origin": parsed.get("is_preferential_origin", False),
            "preferential_origin_agreement": parsed.get("preferential_origin_agreement"),
            "is_free_of_charge": parsed.get("is_free_of_charge", False),
            "customs_statistical_value": parsed.get("customs_statistical_value"),
            "container_number": parsed.get("container_number"),
            "seal_number": parsed.get("seal_number"),
            "shipment_number": parsed.get("shipment_number"),
            "purchase_order": parsed.get("purchase_order"),
            "hs_code": parsed.get("hs_code"),
            "hs_codes": parsed.get("hs_codes", []),
            "payment_terms": parsed.get("payment_terms") or self.find_first([
                r"(?:Payment\s+Terms?|Terms\s+of\s+Payment)[:\s]+([^\n]{3,60})",
            ], text),
            "items": items,
            "items_count": len(items),
        }

        return result

    def _fallback_extract_line_items(self, text: str) -> List[Dict[str, Any]]:
        """Extract item rows if main parser returns empty items list."""
        items: List[Dict[str, Any]] = []
        lines = text.split("\n")
        # Look for table rows formatted as: Description/Code ... Qty ... Price ... Total
        pattern = re.compile(r"^\s*([A-Za-z0-9\-_./\s]{4,40})\s+(\d+(?:\.\d+)?)\s+(?:PCS|UNITS|KG|SETS|M|ROLLS)?\s+([0-9,]+\.?\d*)\s+([0-9,]+\.?\d*)", re.IGNORECASE)
        for line in lines:
            line_str = line.strip()
            m = pattern.search(line_str)
            if m:
                desc = m.group(1).strip()
                if desc.lower() in ["total", "subtotal", "vat", "freight", "description", "item"]:
                    continue
                try:
                    qty = float(m.group(2).replace(",", ""))
                    unit_price = float(m.group(3).replace(",", ""))
                    tot_price = float(m.group(4).replace(",", ""))
                    items.append({
                        "item_code": None,
                        "description": desc,
                        "hs_code": None,
                        "quantity": qty,
                        "unit_of_measure": "PCS",
                        "unit_price": unit_price,
                        "total_price": tot_price,
                        "gross_weight_kg": None,
                        "net_weight_kg": None,
                    })
                except Exception:
                    continue
        return items
