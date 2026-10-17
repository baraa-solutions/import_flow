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
            r"(?:رقم\s*الفاتورة|رقم\s*فاتورة)[:\s]*([A-Za-z0-9/\- ]{3,30})",
            r"(?:Invoice\s+No\.?|Invoice\s+#|INV\s*#|INV\s+NO)[:\s]*([A-Z0-9/\-]{3,30})",
            r"(?:Commercial\s+Invoice)[:\s#]*([A-Z0-9/\-]{3,30})",
            r"Invoice\s*:\s*([A-Z0-9/\-]{3,30})",
        ], text)
        if invoice_number:
            invoice_number = invoice_number.strip().rstrip('.')

        invoice_date = parsed.get("invoice_date") or self.find_first([
            r"(?:تاريخ\s*الفاتورة|تاريخ\s*الإصدار|تاريخ)[:\s]+(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})",
            r"(?:Invoice\s+Date|Date\s+of\s+Issue|Issue\s+Date|Date)[:\s]+(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})",
            r"(?:Date)[:\s]+(\d{4}-\d{2}-\d{2})",
        ], text)

        # 19-digit ACID Number
        acid_number = parsed.get("acid_number") or self.find_first([
            r"(?:ACID|ACI\s+NO|ADVANCE\s+CARGO\s+INFO|ACID:\s*|ACID\s+#|رقم\s*التسجيل\s*المسبق|رقم\s*الاسيد|رقم\s*الإسيد)[:\s#,-]*([0-9a-zA-Z]{19})",
            r"\b(\d{19})\b",
        ], text)
        if acid_number:
            acid_number = re.sub(r"[^0-9]", "", str(acid_number))
            if len(acid_number) != 19:
                acid_number = parsed.get("acid_number")

        importer_tax_id = parsed.get("importer_tax_id") or self.find_first([
            r"(?:الرقم\s*الضريبي(?:\s*للمستورد)?|البطاقة\s*الضريبية|السجل\s*الضريبي|IMPORTER\s+TAX\s+ID|TAX\s+ID|VAT\s+ID|TAX\s+REG|EGYPTIAN\s+TAX\s+REG)(?:\s*\([^\)]*\))?[:\s#]*(\d{3}[-\s]?\d{3}[-\s]?\d{3}|\d{9})",
        ], text)
        if importer_tax_id:
            importer_tax_id = re.sub(r"[\s-]", "", str(importer_tax_id))

        exporter_registration_no = parsed.get("exporter_registration_no") or self.find_first([
            r"(?:EXPORTER\s+REGISTRATION\s+NO|EXPORTER\s+ID|VAT\s+NO|P\.IVA|رقم\s*تسجيل\s*المصدر)[:\s#]+([A-Z0-9/_-]+)",
        ], text)

        supplier_name = parsed.get("supplier_name") or parsed.get("shipper") or self.find_first([
            r"(?:المُصدِّر\s*(?:\(البائع\))?|البائع|المصدر|المورد)[:\s]+(?:شركة\s+)?([^\n|,]{3,60}?)(?:\n|,|\||\()",
            r"(?:Seller|Supplier|Exporter|From|Beneficiary)[:\s]+([A-Za-z0-9\s&,.'-]{3,60}?)(?:\n|,|\|)",
            r"(?:Shipper)[:\s]+([A-Za-z0-9\s&,.'-]{3,60}?)(?:\n|,|\|)",
        ], text)

        importer_name = parsed.get("importer_name") or parsed.get("consignee") or self.find_first([
            r"(?:المستورد\s*(?:\(المشتري\))?|المشتري|المستورد)[:\s]+(?:شركة\s+)?([^\n|,]{3,60}?)(?:\n|,|\||\()",
            r"(?:Buyer|Importer|Consignee|To|Bill\s+To)[:\s]+([A-Za-z0-9\s&,.'-]{3,60}?)(?:\n|,|\|)",
        ], text)

        origin_country = parsed.get("origin_country") or self.find_first([
            r"(?:بلد\s*المنشأ|المنشأ)[:\s]+([^\n|,.(]{2,40}?)(?:\n|,|\||\.|\()",
            r"(?:Country\s+of\s+Origin|Origin)[:\s]+([A-Za-z\s]{3,40}?)(?:\n|,|\|)",
            r"(?:Made\s+in)[:\s]+([A-Za-z\s]{3,30})",
        ], text)

        loading_port = parsed.get("loading_port") or self.find_first([
            r"(?:Port\s+of\s+Loading|POL|Departure\s+Port|ميناء\s*الشحن)[:\s]+([A-Za-z\s,]{3,50}?)(?:\n|,|\|)",
        ], text)

        discharge_port = parsed.get("discharge_port") or self.find_first([
            r"(?:Port\s+of\s+Discharge|POD|Destination\s+Port|ميناء\s*الوصول|ميناء\s*التفريغ)[:\s]+([A-Za-z\s,]{3,50}?)(?:\n|,|\|)",
        ], text)

        incoterms = parsed.get("incoterms") or self.normalize_incoterms(text)
        currency = parsed.get("currency") or self.normalize_currency(text)

        invoice_value = parsed.get("invoice_value") or parsed.get("total_amount") or self.find_float([
            r"(?:القيمة\s*الإجمالية(?:\s*للفاتورة)?|إجمالي\s*الفاتورة|الإجمالي|المبلغ\s*الإجمالي)[:\s]+(?:[A-Z]{3}\s*)?([0-9,]+\.?\d*)",
            r"(?:Total\s+Amount|Grand\s+Total|Invoice\s+Total|Total\s+Value|Total)[:\s]+(?:[A-Z]{3}\s*)?([0-9,]+\.?\d*)",
            r"(?:Amount\s+Due)[:\s]+(?:[A-Z]{3}\s*)?([0-9,]+\.?\d*)",
        ], text)

        freight_amount = parsed.get("freight_amount") or self.find_float([
            r"(?:Freight\s+Amount|Ocean\s+Freight|Freight\s+Charge|نولون\s*الشحن)[:\s]+(?:[A-Z]{3}\s*)?([0-9,]+\.?\d*)",
        ], text)

        insurance_amount = parsed.get("insurance_amount") or self.find_float([
            r"(?:Insurance\s+Amount|Insurance\s+Fee|مبلغ\s*التأمين)[:\s]+(?:[A-Z]{3}\s*)?([0-9,]+\.?\d*)",
        ], text)

        # 3. Line Items Extraction
        items = parsed.get("items") or []
        if not items:
            items = self._fallback_extract_line_items(text)

        # 4. Total Gross and Net Weight if specified on invoice
        total_gross_weight_kg = parsed.get("total_gross_weight_kg") or self.find_float([
            r"(?:الوزن\s*(?:الإجمالي[/\s]*القائم|القائم|الإجمالي))(?:\s*\([^\)]*\))?(?:\s*kgs?|\s*kg)?[:\s]+([0-9,]+\.?\d*)",
            r"(?:Total\s+Gross\s+Weight|Gross\s+Weight|G\.W\.)(?:\s*\([^\)]*\))?[:\s]+([0-9,]+\.?\d*)\s*(?:KGS?|KG)?",
        ], text)

        total_net_weight_kg = parsed.get("total_net_weight_kg") or self.find_float([
            r"(?:الوزن\s*الصافي)(?:\s*\([^\)]*\))?(?:\s*kgs?|\s*kg)?[:\s]+([0-9,]+\.?\d*)",
            r"(?:Total\s+Net\s+Weight|Net\s+Weight|N\.W\.)(?:\s*\([^\)]*\))?[:\s]+([0-9,]+\.?\d*)\s*(?:KGS?|KG)?",
        ], text)

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
            "payment_terms": parsed.get("payment_terms") or self.find_first([
                r"(?:شروط\s*الدفع|طريقة\s*الدفع)[:\s]+([^\n\r(]{3,60})",
                r"(?:Payment\s+Terms?|Terms\s+of\s+Payment)[:\s]+([^\n]{3,60})",
            ], text),
            "items": items,
            "items_count": len(items),
        }

        return result

    def _fallback_extract_line_items(self, text: str) -> List[Dict[str, Any]]:
        """Extract item rows if main parser returns empty items list."""
        items: List[Dict[str, Any]] = []

        # Check labeled items first
        labeled_matches = list(re.finditer(r'(?:كود\s*الصنف|Item\s*(?:Code|No|Number))[:\s]*([^\n\r.]+)', text, re.IGNORECASE))
        if labeled_matches:
            for idx, m in enumerate(labeled_matches):
                start = m.start()
                end = labeled_matches[idx + 1].start() if idx + 1 < len(labeled_matches) else len(text)
                block = text[start:end]
                code = m.group(1).strip().rstrip('.')

                m_desc = re.search(r'(?:الوصف|Description)[:\s]+([^\n\r]+)', block, re.IGNORECASE)
                desc = m_desc.group(1).strip().rstrip('.') if m_desc else f"Product Item {len(items) + 1}"

                m_hs = re.search(r'(?:البند\s*الجمركي|HS\s*Code)(?:\s*\([^\)]*\))?[:\s]*([0-9]{4,10})', block, re.IGNORECASE)
                hs = m_hs.group(1).strip() if m_hs else None

                m_qty = re.search(r'(?:الكمية|Quantity|Qty)[:\s]*([0-9,]+\.?\d*)', block, re.IGNORECASE)
                qty = float(m_qty.group(1).replace(',', '')) if m_qty else 1.0

                m_price = re.search(r'(?:سعر\s*الوحدة|Unit\s*Price)[:\s]*[$€£]?\s*([0-9,]+\.?\d*)', block, re.IGNORECASE)
                price = float(m_price.group(1).replace(',', '')) if m_price else 0.0

                m_tot = re.search(r'(?:الإجمالي\s*للبند|Total\s*Price|Line\s*Total|الإجمالي)[:\s]*[$€£]?\s*([0-9,]+\.?\d*)', block, re.IGNORECASE)
                tot = float(m_tot.group(1).replace(',', '')) if m_tot else (qty * price)

                m_nw = re.search(r'(?:الوزن\s*الصافي|Net\s*Weight)(?:\s*\([^\)]*\))?[:\s]*([0-9,]+\.?\d*)', block, re.IGNORECASE)
                nw = float(m_nw.group(1).replace(',', '')) if m_nw else None

                m_gw = re.search(r'(?:الوزن\s*(?:الإجمالي[/\s]*القائم|القائم)|Gross\s*Weight)(?:\s*\([^\)]*\))?[:\s]*([0-9,]+\.?\d*)', block, re.IGNORECASE)
                gw = float(m_gw.group(1).replace(',', '')) if m_gw else None

                items.append({
                    "item_code": code,
                    "description": desc,
                    "hs_code": hs,
                    "quantity": qty,
                    "unit_of_measure": "PCS",
                    "unit_price": price,
                    "total_price": tot,
                    "gross_weight_kg": gw,
                    "net_weight_kg": nw,
                })
            return items

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
