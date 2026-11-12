"""
Universal Master Data Entity Extractor
Extracts company name, contact person, mobile, phone, email, website, VAT/Tax ID, address, country, postcode, and industry description
from raw pasted text, image OCR, PDF, or Excel files for coding Suppliers, Importing Companies, Partners, and Banks.
"""

from __future__ import annotations

import re
from typing import Any, Dict, List, Optional

from modules.smart_document_upload.extractors.base_extractor import BaseExtractor
from modules.smart_document_upload.ocr_pipeline import normalize_extracted_text


# ─── Identifier parsing building blocks ──────────────────────────────────────
# A label, then optional filler words ("Registration", "No.", "رقم" ...) and separators (":", "#", "-"), then the
# identifier. The identifier must contain a digit so a following word ("Registered", "Certificate") is never
# captured as the value (the old single-regex patterns returned e.g. "Registration" or "2015").

_SEPARATORS = r"[^\S\r\n]*(?:[:#=\-\u2013\u2014.()]+[^\S\r\n]*)*"
_FILLER_EN = (
    r"(?:platform|blockchain|registered|registration|reg|company|account|wallet|address|identifier|"
    r"certificate|cert|international|trade\s*mark|trademark|mark|tm|database|code|number|num|no|nr|id)"
)
_FILLER_AR = r"(?:رقم|الرقم|معرف|المعرف|تسجيل|التسجيل|شهادة|الشهادة|حساب|الحساب|منصة|المنصة|كود|الكود)"
_FILLER = rf"(?:{_SEPARATORS}(?:{_FILLER_EN}(?![A-Za-z0-9])|{_FILLER_AR}(?![\u0600-\u06FF])))*"
_IDENTIFIER_VALUE = r"([A-Za-z0-9][A-Za-z0-9\-_/.]*(?:[^\S\r\n][0-9][0-9\-_/.]*)*)"
_YEAR_ONLY = re.compile(r"(?:19|20)\d{2}")

# IBAN lengths per country (ISO 13616 registry, subset of trade partners). Unknown countries: 15-34 chars.
IBAN_LENGTHS = {
    "EG": 29, "SA": 24, "AE": 23, "JO": 30, "KW": 30, "QA": 29, "BH": 22, "LB": 28, "TR": 26,
    "DE": 22, "GB": 22, "IT": 27, "FR": 27, "ES": 24, "PT": 25, "NL": 18, "BE": 16, "LU": 20,
    "CH": 21, "AT": 20, "PL": 28, "CZ": 24, "SK": 24, "HU": 28, "RO": 24, "BG": 22, "GR": 27,
    "LT": 20, "LV": 21, "EE": 20, "FI": 18, "SE": 24, "DK": 18, "NO": 15, "IE": 22, "SI": 19,
    "HR": 21, "CY": 28, "MT": 31, "PK": 24, "TN": 24, "MA": 28, "DZ": 26, "IQ": 23, "LY": 25,
}
_SWIFT_SHAPE = re.compile(r"[A-Z]{6}[A-Z0-9]{2}(?:[A-Z0-9]{3})?")


def iban_checksum_valid(iban: str) -> bool:
    """ISO 7064 mod-97 check of a compact IBAN."""
    compact = re.sub(r"\s+", "", iban or "").upper()
    if not re.fullmatch(r"[A-Z]{2}\d{2}[A-Z0-9]{11,30}", compact):
        return False
    rearranged = compact[4:] + compact[:4]
    digits = "".join(str(int(ch, 36)) for ch in rearranged)
    return int(digits) % 97 == 1


def compact_iban_candidate(raw: str) -> Optional[str]:
    """Trims an IBAN-shaped match to the country's length (OCR text often runs into the next label)."""
    tokens = re.findall(r"[A-Za-z0-9]+", raw or "")
    if not tokens:
        return None
    compact = "".join(tokens).upper()
    country = compact[:2]
    expected = IBAN_LENGTHS.get(country)
    if expected:
        return compact[:expected] if len(compact) >= expected else None
    # Unknown country: stop at the first letters-only group after the bank code (e.g. a following "SWIFT").
    kept = [tokens[0].upper()]
    for token in tokens[1:]:
        if len(kept) >= 2 and token.isalpha():
            break
        kept.append(token.upper())
    candidate = "".join(kept)[:34]
    return candidate if 15 <= len(candidate) <= 34 else None


class MasterDataEntityExtractor(BaseExtractor):

    def required_fields(self) -> List[str]:
        return ["company_name", "country_code"]

    def compute_confidence(self, extracted: Dict[str, Any]) -> float:
        if not extracted or not extracted.get("company_name"):
            return 0.0
        score = 0.35
        if any(extracted.get(k) for k in ["vat_tax_id", "vat_id", "commercial_register", "cargox_id", "importer_id", "license_number", "swift_code", "foreign_exporter_id"]):
            score += 0.25
        if any(extracted.get(k) for k in ["phone_number", "mobile_number", "email", "website", "fax_number"]):
            score += 0.20
        if any(extracted.get(k) for k in ["country_code", "country", "address"]):
            score += 0.20
        return round(min(1.0, score), 2)

    # Keys that are aliases / defaults of another key (not counted as "found" fields).
    _NON_SIGNAL_KEYS = {
        "supplier_registration_type", "foreign_exporter_id", "vat_id", "registration_number",
        "importer_card_number", "nafeza_token_id", "cargox_platform_id", "clearance_license_number",
        "insurance_coverage_types", "authorized_ports", "bank_account", "country", "supplier_type",
        "credit_limit", "rating",
    }

    def found_fields(self, extracted: Dict[str, Any]) -> List[str]:
        """Names of the fields that were actually recognized in the document (for the UI / diagnostics)."""
        return [
            key for key, value in (extracted or {}).items()
            if key not in self._NON_SIGNAL_KEYS and value not in (None, "", False, [], {})
        ]

    def extract(self, raw_text: str, spatial_boxes: dict = None, module_name: str = "generic") -> Dict[str, Any]:
        text = normalize_extracted_text(raw_text or "")
        entity_type = "importer" if "importer" in module_name.lower() else ("supplier" if "supplier" in module_name.lower() else "generic")

        company_name = self._extract_company_name(text, entity_type=entity_type)
        reg_type = self._clean_val(self._extract_registration_type(text))
        tax_id = self._clean_val(self._extract_tax_id(text))
        commercial_reg = self._clean_val(self._extract_commercial_register(text))
        importer_id_val = self._clean_val(self._extract_importer_id(text))
        insurance_terms_val = self._clean_val(self._extract_insurance_terms(text))
        ports_val = self._clean_val(self._extract_ports(text))
        has_wipo_val = self._extract_has_wipo(text)
        wipo_num = self._clean_val(self._extract_wipo_number(text))
        has_euipo_val = self._extract_has_euipo(text)
        euipo_num = self._clean_val(self._extract_euipo_number(text))
        has_gbd_val = self._extract_has_global_brand(text)
        gbd_num = self._clean_val(self._extract_global_brand_number(text))
        has_iso9001_val = self._extract_has_iso_9001(text)
        iso9001_num = self._clean_val(self._extract_iso_9001_number(text))
        nafeza_tok = self._clean_val(self._extract_nafeza_token(text))
        iban_val = self._clean_val(self._extract_iban(text))
        acct_num = self._clean_val(self._extract_account_number(text, iban=iban_val))
        swift_val = self._clean_val(self._extract_swift(text))
        cargox_val = self._clean_val(self._extract_cargox_id(text))
        has_wipo_val = has_wipo_val or bool(wipo_num)
        has_euipo_val = has_euipo_val or bool(euipo_num)
        has_gbd_val = has_gbd_val or bool(gbd_num)
        has_iso9001_val = has_iso9001_val or bool(iso9001_num)

        result: Dict[str, Any] = {
            "company_name": company_name,
            "arabic_name": self._extract_arabic_name(text),
            "supplier_type": self._clean_val(self._extract_supplier_type(text)),
            "registration_type": reg_type,
            "supplier_registration_type": reg_type,
            "contact_person": self._clean_val(self._extract_contact_person(text)),
            "mobile_number": self._clean_val(self._extract_mobile(text)),
            "phone_number": self._clean_val(self._extract_phone(text)),
            "fax_number": self._clean_val(self._extract_fax(text)),
            "website": self._clean_val(self._extract_website(text)),
            "email": self._clean_val(self._extract_email(text)),
            "secondary_email": self._clean_val(self._extract_secondary_email(text)),
            "vat_tax_id": tax_id,
            "foreign_exporter_id": tax_id,
            "vat_id": tax_id,
            "address": self._clean_val(self._extract_address(text, company_name=company_name)),
            "country_code": self._clean_val(self._extract_country(text)),
            "country": self._clean_val(self._extract_country_name(text)),
            "postcode": self._clean_val(self._extract_postcode(text)),
            "industry_description": self._clean_val(self._extract_industry(text)),
            "commercial_register": commercial_reg,
            "registration_number": commercial_reg,
            "registration_expiry": self._clean_val(self._extract_registration_expiry(text)),
            "importer_id": importer_id_val,
            "importer_card_number": importer_id_val,
            "importer_id_expiry": self._clean_val(self._extract_importer_expiry(text)),
            "vat_id_expiry": self._clean_val(self._extract_vat_expiry(text)),
            "nafeza_token": nafeza_tok,
            "nafeza_token_id": nafeza_tok,
            "cargox_id": cargox_val,
            "cargox_platform_id": cargox_val,
            "license_number": self._clean_val(self._extract_broker_license(text)),
            "clearance_license_number": self._clean_val(self._extract_broker_license(text)),
            "transport_license_number": self._clean_val(self._extract_transport_license(text)),
            "inspection_accreditation_number": self._clean_val(self._extract_inspection_accreditation(text)),
            "insurance_license_number": self._clean_val(self._extract_insurance_license(text)),
            "fiata_id": self._clean_val(self._extract_fiata_id(text)),
            "scac_code": self._clean_val(self._extract_scac_code(text)),
            "tracking_url": self._clean_val(self._extract_tracking_url(text)),
            "fleet_types": self._clean_val(self._extract_fleet_types(text)),
            "inspection_scope": self._clean_val(self._extract_inspection_scope(text)),
            "insurance_terms": insurance_terms_val,
            "insurance_coverage_types": insurance_terms_val,
            "ports": ports_val,
            "authorized_ports": ports_val,
            "bank_name": self._clean_val(self._extract_bank_name(text)),
            "branch_name": self._clean_val(self._extract_branch_name(text)),
            "bank_code": self._clean_val(self._extract_bank_code(text)),
            "swift_code": swift_val,
            # Account number only: the IBAN has its own field (mixing them was the AC-2 bug).
            "bank_account": acct_num,
            "account_number": acct_num,
            "iban": iban_val,
            "credit_limit": self._extract_credit_limit(text),
            "rating": self._extract_rating(text),
            "has_iso": self._extract_has_iso(text) or has_iso9001_val,
            "has_wipo": has_wipo_val,
            "wipo_number": wipo_num,
            "has_euipo": has_euipo_val,
            "euipo_number": euipo_num,
            "has_global_brand": has_gbd_val,
            "global_brand_number": gbd_num,
            "has_iso_9001": has_iso9001_val,
            "iso_9001_number": iso9001_num,
            "registered_decree_43": self._extract_decree_43(text),
            "white_list_registered": self._extract_white_list(text),
            "brands": self._clean_val(self._extract_brands(text)),
            "notes": self._clean_val(self._extract_notes(text)),
        }
        return result

    def _clean_val(self, val: Optional[str]) -> Optional[str]:
        if not val:
            return None
        cleaned = re.sub(r"[\r\n]+", " ", str(val)).strip()
        cleaned = re.sub(r"\s+", " ", cleaned)
        invalid_tokens = {
            "NONE", "NULL", "PNG", "JPG", "JPEG", "PDF", "UNKNOWN",
            "SUPPLIER", "SHIPPER", "EXPORTER", "IMPORTER", "CONSIGNEE",
            "VENDOR", "BUYER", "SELLER"
        }
        if not cleaned or cleaned.upper() in invalid_tokens:
            return None
        return cleaned

    def _extract_registration_type(self, text: str) -> Optional[str]:
        # 1. Explicit labeled match
        m = self.find_first([
            r"(?:Shipper\s+Registration\s+Type|Registration\s+Type|Reg\s+Type|نوع\s+التسجيل|نوع\s+السجل)[^\S\r\n]*[:=]?[^\S\r\n]*([^\r\n]+)",
        ], text)
        if m:
            val = m.strip().upper()
            if "VAT" in val:
                return "VAT Number"
            if "TAX" in val:
                return "Tax Number"
            if "COMMERCIAL" in val or "CR" in val or "سجل" in val:
                return "Commercial Register"
            if "COMPANY" in val:
                return "Company Registration Number"
            if "FACTORY" in val or "مصنع" in val:
                return "Factory Registration"
            if "DUNS" in val:
                return "DUNS Number"
            if "NAFEZA" in val or "EXPORTER NUMBER" in val:
                return "Foreign Exporter Number (Nafeza)"
            return m.strip()

        # 2. Contextual heuristic
        upper = text.upper()
        if "VAT NUMBER" in upper or "VAT NO" in upper or "VAT REG" in upper or "VAT CODE" in upper or "P.IVA" in upper:
            return "VAT Number"
        if "TAX ID" in upper or "TAX NUMBER" in upper or "TAX NO" in upper:
            return "Tax Number"
        if "COMMERCIAL REGISTER" in upper or "C.R." in upper or "ENTERPRISE CODE" in upper:
            return "Commercial Register"
        if "DUNS" in upper:
            return "DUNS Number"
        return None

    def _extract_importer_expiry(self, text: str) -> Optional[str]:
        for line in text.splitlines():
            if any(kw in line.lower() for kw in ["importer", "import card", "استيرادية"]):
                m = re.search(r"(\d{4}[-/]\d{1,2}[-/]\d{1,2}|\d{1,2}[-/]\d{1,2}[-/]\d{4})", line)
                if m:
                    return m.group(1)
        return self.find_first([
            r"(?:Importer\s+Card\s+Expiry|Import\s+Card\s+Expiry|انتهاء\s+البطاقة\s+الاستيرادية)[^\S\r\n]*[:=]?[^\S\r\n]*([0-9]{4}[-/][0-9]{1,2}[-/][0-9]{1,2}|[0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{4})",
        ], text)

    def _extract_vat_expiry(self, text: str) -> Optional[str]:
        for line in text.splitlines():
            if any(kw in line.lower() for kw in ["vat", "tax", "الضريبية", "ضريبية"]):
                m = re.search(r"(\d{4}[-/]\d{1,2}[-/]\d{1,2}|\d{1,2}[-/]\d{1,2}[-/]\d{4})", line)
                if m:
                    return m.group(1)
        return self.find_first([
            r"(?:VAT\s+Expiry|VAT\s+Registration\s+Expiry|Tax\s+Card\s+Expiry|انتهاء\s+البطاقة\s+الضريبية)[^\S\r\n]*[:=]?[^\S\r\n]*([0-9]{4}[-/][0-9]{1,2}[-/][0-9]{1,2}|[0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{4})",
        ], text)

    def _extract_registration_expiry(self, text: str) -> Optional[str]:
        for line in text.splitlines():
            if any(kw in line.lower() for kw in ["cr", "commercial", "السجل", "سجل"]):
                m = re.search(r"(\d{4}[-/]\d{1,2}[-/]\d{1,2}|\d{1,2}[-/]\d{1,2}[-/]\d{4})", line)
                if m:
                    return m.group(1)
        return self.find_first([
            r"(?:CR\s+Expiry|Commercial\s+Reg\s+Expiry|انتهاء\s+السجل\s+التجاري)[^\S\r\n]*[:=]?[^\S\r\n]*([0-9]{4}[-/][0-9]{1,2}[-/][0-9]{1,2}|[0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{4})",
        ], text)

    def _extract_importer_id(self, text: str) -> Optional[str]:
        return self.find_first([
            r"(?:Importer\s+Card|Import\s+Card|Egyptian\s+Importer\s+Tax\s+ID|Egyptian\s+Importer\s+ID|Importer\s+Tax\s+ID|Importer\s+ID|البطاقة\s+الاستيرادية|بطاقة\s+استيرادية|كود\s+المستورد|رقم\s+المستورد)[^\S\r\n]*[:=]?[^\S\r\n]*([0-9\-_]{4,15})",
            r"\b(IMP-[0-9]{4,10})\b",
        ], text)

    def _extract_broker_license(self, text: str) -> Optional[str]:
        return self.find_first([
            r"(?:Broker\s+License|License\s+No\.?|رخصة\s+التخليص|رقم\s+القيد|رقم\s+الرخصة)[^\S\r\n]*[:=]?[^\S\r\n]*([A-Za-z0-9\-_/]{3,20})",
        ], text)

    def _extract_arabic_name(self, text: str) -> Optional[str]:
        labeled = re.search(
            r"(?:Arabic\s+Name|Name\s+in\s+Arabic|Company\s+Name\s*\((?:AR|Arabic)\)|الاسم\s+بالعربية|الاسم\s+العربي|"
            r"اسم\s+الشركة|الاسم\s+التجاري|اسم\s+المنشأة|اسم\s+المؤسسة)[^\S\r\n]*[:=][^\S\r\n]*([^\r\n]{3,100})",
            text,
            re.IGNORECASE,
        )
        if labeled and re.search(r"[؀-ۿ]{3,}", labeled.group(1)):
            return labeled.group(1).strip()
        lines = [l.strip() for l in text.splitlines() if l.strip()]
        for l in lines:
            if re.search(r"[\u0600-\u06FF]{3,}", l) and any(kw in l for kw in ["شركة", "مؤسسة", "مكتب", "للاستيراد", "للتجارة", "ش.م.م", "ذ.م.م"]):
                return l
        return None

    def _extract_company_name(self, text: str, entity_type: str = "generic") -> Optional[str]:
        lines = [l.strip() for l in text.splitlines() if l.strip()]
        valid_lines = []
        system_stop_words = [
            "UNIVERSAL MASTER DATA", "ENTITY EXTRACTOR", "COMMERCIAL INVOICE",
            "PACKING LIST", "BILL OF LADING", "PAGE 1", "IMPORTFLOW", "SCREENSHOT",
            "RAW TEXT", "POWERED", "AUTO-REGISTRATION ENGINE", ".PNG", ".PDF", ".JPG"
        ]

        meta_prefix_keywords = [
            "SHIPPER REGISTRATION", "REGISTRATION TYPE", "SHIPPER ID", "EXPORTER ID", "SUPPLIER ID",
            "SHIPPER COUNTRY", "EXPORTER COUNTRY", "COUNTRY CODE", "COUNTRY:", "ORIGIN:",
            "VAT NUMBER", "VAT NO", "VAT REG", "TAX ID", "TAX NUMBER", "TAX NO", "P.IVA", "C.F.",
            "EGYPTIAN IMPORTER TAX ID", "EGYPTIAN IMPORTER ID", "IMPORTER TAX ID", "IMPORTER ID",
            "PHONE", "TEL:", "TEL.", "MOB:", "MOBILE:", "FAX:", "E-MAIL", "EMAIL:", "URL:", "WEB:", "WEBSITE:",
            "CARGOX", "SWIFT", "IBAN", "ACCOUNT NO", "BANK ACCOUNT", "CONTACT PERSON", "ATTN:", "ATTENTION:",
            "IMPORTER CARD", "COMMERCIAL REGISTER", "CR NO", "ENTERPRISE CODE", "COMPANY CODE", "VAT CODE"
        ]

        for l in lines:
            upper = l.upper()
            if not any(stop in upper for stop in system_stop_words):
                if not any(upper.startswith(kw) or f"{kw}:" in upper or f"{kw} :" in upper for kw in meta_prefix_keywords):
                    valid_lines.append(l)

        if not valid_lines:
            return None

        # 1. Entity-specific labeled detection (require : or = and exclude metadata keys)
        if entity_type == "importer":
            consignee_match = self.find_first([
                r"(?:Consignee\s+Name|Consignee|Importer\s+Name|Importer|Buyer|Billed\s+to|Sold\s+to|Messrs|Client|اسم\s+المستورد|الشركة\s+المستوردة)[^\S\r\n]*[:=][^\S\r\n]*(?!(?:REGISTRATION|ID|COUNTRY|CODE|ADDRESS|PHONE|TEL|CARD|TAX)\b)([^\r\n]{3,80})",
            ], text)
            if consignee_match and not any(stop in consignee_match.upper() for stop in system_stop_words):
                return self._clean_val(consignee_match)

        elif entity_type == "supplier":
            shipper_match = self.find_first([
                r"(?:Shipper\s+Name|Shipper|Supplier\s+Name|Supplier|Exporter\s+Name|Exporter|Seller|Manufacturer|Vendor|المورد|الشاحن)[^\S\r\n]*[:=][^\S\r\n]*(?!(?:REGISTRATION|ID|COUNTRY|CODE|ADDRESS|PHONE|TEL|TAX|VAT)\b)([^\r\n]{3,80})",
            ], text)
            if shipper_match and not any(stop in shipper_match.upper() for stop in system_stop_words):
                return self._clean_val(shipper_match)

        # 2. General labeled company detection: English labels first (the Latin name is the primary name; an
        #    Arabic "اسم الشركة" line feeds arabic_name), then Arabic labels.
        value_part = r"[^\S\r\n]*[:=][^\S\r\n]*(?!(?:CODE|REGISTRATION|ID|COUNTRY|ADDRESS|PHONE|TEL|TAX|VAT)\b)([^\r\n]{3,80})"
        labeled = self.find_first([
            r"(?:Company\s+Name(?:\s*\((?:EN|English)\))?|Legal\s+Name|Registered\s+Name|Trade\s+Name|Name\s+of\s+(?:the\s+)?Company|"
            r"Company|Consignee\s+Name|Shipper\s+Name|Supplier\s+Name|Exporter\s+Name|Agency\s+Name|Carrier\s+Name)" + value_part,
            r"(?:اسم\s+الشركة|الاسم\s+التجاري|اسم\s+المنشأة|اسم\s+المؤسسة)" + value_part,
        ], text)
        if labeled and not any(stop in labeled.upper() for stop in system_stop_words):
            return self._clean_val(labeled)

        # 3. Look for explicit company lines with legal suffixes
        suffixes = [
            "LIMITED", "LTD", "INC", "CORP", "CO.,LTD", "CO., LTD", "CO.,", "S.P.A", "GMBH", "LLC", "PLC", "HOLDING", "SHAWCONTRACT", "S.A.E", "UAB", "B.V.", "S.R.O", "OÜ", "S.L.",
            "ش.م.م", "ذ.م.م", "ش م م", "ذ م م", "توصية", "تضامن", "مساهمة", "للاستيراد", "للتصدير", "للتجارة", "شركة", "مؤسسة"
        ]
        for idx, line in enumerate(valid_lines):
            upper = line.upper()
            if any(kw in upper for kw in suffixes):
                if not any(stop in upper for stop in ["ADDRESS:", "VAT NUMBER", "PHONE", "TEL:", "FACTORY ADDRESS", "URL:", "BUILDING", "STREET", "ROAD"]):
                    cleaned_line = re.sub(r"^(?:Supplier|Shipper|Exporter|Vendor|Manufacturer|Company|Client|المورد|الشاحن|الشركة)\s*[:=-]\s*", "", line, flags=re.IGNORECASE).strip()
                    # If line is just suffix alone (e.g. "Ltd."), merge with preceding lines
                    if len(cleaned_line.strip("., ")) < 5 and idx > 0:
                        prev = valid_lines[idx - 1]
                        return f"{prev} {cleaned_line}".strip()
                    return cleaned_line

        # 4. Fallback to the first clean line that reads like a name (OCR noise such as "--- PAGE 1 ---",
        #    "|||" or a lone number is skipped)
        for candidate in valid_lines:
            letters = sum(1 for ch in candidate if ch.isalpha())
            if len(candidate) > 3 and letters >= 3 and letters >= len(candidate) * 0.4 and not candidate.startswith("---"):
                return candidate

        return None

    def _extract_contact_person(self, text: str) -> Optional[str]:
        return self.find_first([
            r"(?:Contact\s+Person|Contact|Owner|Factory\s+owner|Manager|Attn|Attention|المسؤول|المدير|مسؤول\s+التواصل)[^\S\r\n]*[:=]?[^\S\r\n]*([A-Za-z0-9\s.\u0600-\u06FF]{3,40})",
            r"\b(Factory\s+owner)\b",
        ], text)

    # Phone-number value: starts with +, ( or a digit, single-line, at least 7 digits (checked in _labeled_phone).
    _PHONE_VALUE = r"(\+?\(?[0-9][0-9 \-\(\)\.]{5,22}[0-9])"

    def _labeled_phone(self, label_pattern: str, text: str) -> Optional[str]:
        pattern = rf"(?:{label_pattern})(?:{_SEPARATORS}(?:no|number|nr|phone)(?![A-Za-z]))?{_SEPARATORS}{self._PHONE_VALUE}"
        for m in re.finditer(pattern, text, re.IGNORECASE):
            value = m.group(1).strip()
            if len(re.sub(r"\D", "", value)) >= 7:
                return value
        return None

    def _extract_mobile(self, text: str) -> Optional[str]:
        labeled = self._labeled_phone(
            r"\bM\b\.?|\bMob(?:ile)?\b\.?|\bCell(?:ular)?\b|\bCel\b|\bGSM\b|\bWhats?App\b|محمول|موبايل|جوال|واتساب|واتس",
            text,
        )
        if labeled:
            return labeled
        return self.find_first([
            r"(\+20\s*1[0-5]\d{8})",
            r"\b(01[0-5]\d{8})\b",
            r"(0086\s*1[3-9]\d{9}|\+86\s*1[3-9]\d{9})",
        ], text)

    def _extract_phone(self, text: str) -> Optional[str]:
        # 1. Explicit labeled match ("Mobile Phone" / "Cell Phone" belong to the mobile field)
        labeled = self._labeled_phone(
            r"(?<!Mobile )(?<!Cell )\bPhone\b|\bTel(?:ephone)?\b\.?(?:[^\S\r\n]*/[^\S\r\n]*Fax)?|\bLandline\b|الهاتف|هاتف|تليفون|أرضي",
            text,
        )
        if labeled:
            return labeled
        found = self.find_first([
            r"(\+44\s*1\d{3}\s*\d{5,6})",
            r"(\+39\s*0\d{2,4}\s*\d{5,8})",
            r"(\+86\s*\d{2,4}\s*\d{7,8})",
            r"(\+370\s*5\s*\d{3}\s*\d{4})",
        ], text)
        if found:
            return found

        # 2. Egyptian landline / area code patterns (e.g. +2 (02) 23101798, +20 2 23101798, 02-23101798)
        landline = self.find_first([
            r"(\+?2\s*\(?02\)?\s*[0-9\s\-]{7,10})",
            r"(\+?20\s*\(?0\d{1,2}\)?\s*[0-9\s\-]{7,10})",
            r"\b(02[- ]?[0-9\s\-]{7,9})\b",
        ], text)
        return landline

    def _extract_fax(self, text: str) -> Optional[str]:
        return self._labeled_phone(r"\bFax\b\.?|\bTel(?:ephone)?\b\.?[^\S\r\n]*/[^\S\r\n]*Fax\b|فاكس", text)

    def _extract_website(self, text: str) -> Optional[str]:
        labeled = re.search(
            r"(?:\bWeb[^\S\r\n]*(?:site|page)?\b|\bURL\b|\bW\b|\bHome[^\S\r\n]*page\b|الموقع(?:[^\S\r\n]+الإلكتروني)?|موقع)"
            r"[^\S\r\n]*[:=]?[^\S\r\n]*"
            r"((?:https?://)?(?:www\.)?[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}(?:/[^\s]*)?)(?![A-Za-z0-9@])",
            text,
            re.IGNORECASE,
        )
        if labeled and "@" not in labeled.group(1):
            return labeled.group(1).rstrip(".,;")
        return self.find_first([
            r"\b(https?://[^\s,;]+)",
            r"\b(www\.[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})\b",
        ], text)

    def _extract_email(self, text: str) -> Optional[str]:
        m = re.search(r"\b([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})\b", text)
        return m.group(1) if m else None

    def _extract_tax_id(self, text: str) -> Optional[str]:
        val = self.find_first([
            # 1. Explicit Shipper / Exporter / Supplier / Importer Tax ID
            r"(?:Shipper\s+ID|Supplier\s+ID|Foreign\s+Exporter\s+ID|Exporter\s+ID|Egyptian\s+Importer\s+Tax\s+ID|Importer\s+Tax\s+ID|Importer\s+ID|Vendor\s+ID|كود\s+المورد|رقم\s+المورد|رقم\s+المصدر|رقم\s+التسجيل\s+الأجنبي)[^\S\r\n]*[:=]?[^\S\r\n]*([A-Za-z0-9\-_/]+)",
            # 2. Explicit VAT / Tax / Registration Labels
            r"(?:VAT\s+Registration\s+No\.?|VAT\s+Registration\s+Number|VAT\s+Registration|VAT\s+Number|VAT\s+No\.?|VAT\s+ID|VAT\s+Code|P\.IVA|Tax\s+ID|Tax\s+No\.?|Tax\s+Number|C\.F\.|Registration\s+No\.?|البطاقة\s+الضريبية|بطاقة\s+ضريبية|التسجيل\s+الضريبي|الرقم\s+الضريبي|رقم\s+القيمة\s+المضافة)[^\S\r\n]*[:=]?[^\S\r\n]*([A-Za-z0-9\-_/]+)",
            # 3. Formats with space but no colon (e.g. VAT Number 428102677)
            r"\bVAT\s+Number[^\S\r\n]+([A-Za-z0-9\-_/]+)",
            r"\bP\.IVA[^\S\r\n]+([A-Za-z0-9]+)",
            r"\bVAT\s+Code[^\S\r\n]+([A-Za-z0-9]+)",
            # 4. Known International VAT / Tax number patterns
            r"\b(GB\d{9,12})\b",           # UK VAT (e.g. GB428102677)
            r"\b(IT\d{11})\b",              # Italian P.IVA (e.g. IT12345678901)
            r"\b(LT\d{9,12})\b",           # Lithuanian VAT (e.g. LT100002821114)
            r"\b(DE\d{9})\b",               # German USt-IdNr
            r"\b(FR\d{11})\b",              # French TVA
            r"\b(91\d{16}[A-Z0-9])\b",     # China Unified Social Credit Code (18 chars)
            r"\b(\d{3}-\d{3}-\d{3})\b",     # Egyptian 9-digit Tax ID with dashes (e.g. 759-552-827)
            r"\b(\d{9})\b",                 # Egyptian 9-digit Tax ID
        ], text)
        return val

    def _extract_address(self, text: str, company_name: Optional[str] = None) -> Optional[str]:
        # 1. Check explicit labeled address
        labeled = self.find_first([
            r"(?:Factory\s+Address|Company\s+Address|Plant\s+Address|Address|Location|العنوان|المقر|عنوان\s+المصنع|عنوان\s+الشركة)[^\S\r\n]*[:=]?[^\S\r\n]*([^\r\n]{5,150})",
        ], text)
        if labeled:
            return labeled.strip()

        # 2. Unlabeled multi-line address recognition
        lines = [line.strip() for line in text.splitlines() if line.strip()]
        if not lines:
            return None

        # Metadata patterns / prefixes to ignore and stop
        meta_prefix_keywords = [
            "SHIPPER REGISTRATION", "REGISTRATION TYPE", "SHIPPER ID", "EXPORTER ID", "SUPPLIER ID",
            "SHIPPER COUNTRY", "EXPORTER COUNTRY", "COUNTRY CODE", "COUNTRY:", "ORIGIN:",
            "VAT NUMBER", "VAT NO", "VAT REG", "TAX ID", "TAX NUMBER", "TAX NO", "P.IVA", "C.F.",
            "EGYPTIAN IMPORTER TAX ID", "EGYPTIAN IMPORTER ID", "IMPORTER TAX ID", "IMPORTER ID",
            "PHONE", "TEL:", "TEL.", "MOB:", "MOBILE:", "CEL:", "CEL ", "CELL:", "CELL ", "FAX:", "E-MAIL", "EMAIL:", "URL:", "WEB:", "WEBSITE:",
            "CARGOX", "SWIFT", "IBAN", "ACCOUNT NO", "BANK ACCOUNT", "CONTACT PERSON", "ATTN:", "ATTENTION:",
            "IMPORTER CARD", "COMMERCIAL REGISTER", "CR NO", "ENTERPRISE CODE", "POSTCODE:", "ZIP CODE:"
        ]

        address_tokens = [
            "ROAD", "RD", "STREET", "ST.", "ST ", "AVENUE", "AVE", "BLVD", "BOULEVARD", "LANE", "LN", "WAY",
            "DRIVE", "DR.", "PARK", "INDUSTRIAL", "ZONE", "BUILDING", "BLDG", "SUITE", "FLOOR", "UNIT",
            "TOWN", "CITY", "PROVINCE", "COUNTY", "DISTRICT", "NO.", "N0.", "POSTCODE", "P.O.", "PO BOX",
            "PLOT", "PART", "SECTOR", "BLOCK",
            "VIA ", "STRASSE", "RUE ", "CALLE ", "SANQUHAR", "CHANGSHU", "SUZHOU", "CAIRO", "ALEXANDRIA",
            "MAADI", "SARAYAT", "ZAMALEK", "NASR CITY", "HELIOPOLIS", "GIZA", "6TH OF OCTOBER", "NEW CAIRO",
            "TAGAMOA", "DOKKI", "MOHANDESSIN", "PORT SAID", "SUEZ", "DAMMETTA", "10TH OF RAMADAN",
            "UNITED KINGDOM", "CHINA", "ITALY", "GERMANY", "LITHUANIA", "EGYPT",
            "شارع", "طريق", "منطقة", "قطعة", "مجاورة", "مدينة", "محافظة", "مبنى", "عمارة", "برج", "حي", "ميدان", "مجمع",
            "المعادي", "زهراء المعادي", "سرايات المعادي", "مدينة نصر", "مصر الجديدة", "التجمع", "القاهرة", "الجيزة", "مصر"
        ]

        addr_lines = []
        for line in lines:
            upper = line.upper()

            # Skip company name line
            if company_name and upper == company_name.upper():
                continue

            # Skip metadata lines
            if any(upper.startswith(kw) or f"{kw}:" in upper or f"{kw} :" in upper for kw in meta_prefix_keywords):
                continue
            if any(kw in upper for kw in ["PHONE", "E-MAIL", "EMAIL", "WEBSITE", "WWW.", "HTTP://", "HTTPS://", "FAX", "CEL:", "CELL:", "MOB:", "MOBILE:"]):
                continue

            # Skip standalone phone / number line
            if re.match(r"^\+?[0-9\s\-\(\)\.]{7,25}$", line):
                continue

            # Check if line looks like address
            has_addr_token = any(token in upper for token in address_tokens)
            has_postcode = bool(re.search(r"\b([A-Z]{1,2}\d[A-Z0-9]?\s*\d[A-Z]{2}|\d{5,6})\b", line))

            if has_addr_token or has_postcode or (len(addr_lines) > 0 and len(line) < 60 and not line.endswith(":")):
                addr_lines.append(line)

        return ", ".join(addr_lines) if addr_lines else None

    def _extract_country(self, text: str) -> Optional[str]:
        # 1. Check explicit labeled country code
        code_match = self.find_first([
            r"(?:Country\s+Code|Shipper\s+Country\s+Code|Exporter\s+Country\s+Code|Origin\s+Country\s+Code|كود\s+الدولة|رمز\s+الدولة)[^\S\r\n]*[:=]?[^\S\r\n]*([A-Za-z]{2})\b",
        ], text)
        if code_match:
            return code_match.upper()

        # 2. Check explicit labeled country name (single line only)
        country_match = self.find_first([
            r"(?:Shipper\s+Country|Exporter\s+Country|Origin\s+Country|دولة\s+المصدر|بلد\s+المنشأ)[^\S\r\n]*[:=]?[^\S\r\n]*([A-Za-z\u0600-\u06FF ]{2,40})",
            r"(?:Country|الدولة|المنشأ)[^\S\r\n]*[:=][^\S\r\n]*([A-Za-z\u0600-\u06FF ]{2,40})",
        ], text)

        found = country_match or self.find_first([
            r"\b(China|United\s+Kingdom|Great\s+Britain|UK|England|Scotland|Italy|Italia|Lithuania|Germany|Deutschland|Egypt|USA|United\s+States|America|Spain|España|France|India|Japan|Korea|South\s+Korea|UAE|United\s+Arab\s+Emirates|Saudi\s+Arabia|Brazil|Russia|Vietnam|Netherlands|Holland|Switzerland|Belgium|Canada|Australia|Poland|Taiwan|Hong\s+Kong|Sweden|Portugal|Austria|Greece|Jordan|Jiangsu|Zhejiang|Guangdong|Shanghai|Beijing|مصر|السعودية|الإمارات|الصين|إيطاليا|ألمانيا|بريطانيا|إسبانيا|فرنسا|الهند|تركيا|Turkey|Turkiye)\b",
        ], text)

        if not found:
            return None

        c = found.strip().upper()
        # Clean up any trailing labels if present
        c = re.split(r"[\r\n]|البطاقة|السجل|الضريبية|TEL|PHONE|VAT", c)[0].strip()

        mapping = {
            "CHINA": "CN", "JIANGSU": "CN", "ZHEJIANG": "CN", "GUANGDONG": "CN", "SHANGHAI": "CN", "BEIJING": "CN", "الصين": "CN", "CN": "CN",
            "UNITED KINGDOM": "GB", "GREAT BRITAIN": "GB", "UK": "GB", "ENGLAND": "GB", "SCOTLAND": "GB", "بريطانيا": "GB", "المملكة المتحدة": "GB", "GB": "GB",
            "ITALY": "IT", "ITALIA": "IT", "إيطاليا": "IT", "IT": "IT",
            "LITHUANIA": "LT", "LT": "LT",
            "EGYPT": "EG", "مصر": "EG", "جمهورية مصر العربية": "EG", "EG": "EG",
            "GERMANY": "DE", "DEUTSCHLAND": "DE", "ألمانيا": "DE", "DE": "DE",
            "USA": "US", "UNITED STATES": "US", "AMERICA": "US", "الولايات المتحدة": "US", "US": "US",
            "TURKEY": "TR", "TURKIYE": "TR", "TÜRKIYE": "TR", "تركيا": "TR", "TR": "TR",
            "SPAIN": "ES", "ESPAÑA": "ES", "إسبانيا": "ES", "ES": "ES",
            "FRANCE": "FR", "فرنسا": "FR", "FR": "FR",
            "INDIA": "IN", "الهند": "IN", "IN": "IN",
            "JAPAN": "JP", "اليابان": "JP", "JP": "JP",
            "SOUTH KOREA": "KR", "KOREA": "KR", "كوريا": "KR", "KR": "KR",
            "UAE": "AE", "UNITED ARAB EMIRATES": "AE", "الإمارات": "AE", "AE": "AE",
            "SAUDI ARABIA": "SA", "KSA": "SA", "السعودية": "SA", "المملكة العربية السعودية": "SA", "SA": "SA",
            "BRAZIL": "BR", "البرازيل": "BR", "BR": "BR",
            "RUSSIA": "RU", "روسيا": "RU", "RU": "RU",
            "VIETNAM": "VN", "فيتنام": "VN", "VN": "VN",
            "NETHERLANDS": "NL", "HOLLAND": "NL", "هولندا": "NL", "NL": "NL",
            "SWITZERLAND": "CH", "سويسرا": "CH", "CH": "CH",
            "BELGIUM": "BE", "بلجيكا": "BE", "BE": "BE",
            "CANADA": "CA", "كندا": "CA", "CA": "CA",
            "AUSTRALIA": "AU", "أستراليا": "AU", "AU": "AU",
            "POLAND": "PL", "بولندا": "PL", "PL": "PL",
            "TAIWAN": "TW", "تايوان": "TW", "TW": "TW",
            "HONG KONG": "HK", "هونج كونج": "HK", "HK": "HK",
            "SWEDEN": "SE", "السويد": "SE", "SE": "SE",
            "PORTUGAL": "PT", "البرتغال": "PT", "PT": "PT",
            "AUSTRIA": "AT", "النمسا": "AT", "AT": "AT",
            "GREECE": "GR", "اليونان": "GR", "GR": "GR",
            "JORDAN": "JO", "الأردن": "JO", "JO": "JO",
        }
        return mapping.get(c, c[:2] if len(c) == 2 else c)

    def _extract_postcode(self, text: str) -> Optional[str]:
        found = self.find_first([
            r"(?:Postcode|Zip|Postal\s+Code|الرمز\s+البريدي)[^\S\r\n]*[:=]?[^\S\r\n]*([A-Za-z0-9\s\-]{4,10})",
            r"\b([A-Z]{1,2}\d[A-Z0-9]?\s*\d[A-Z]{2})\b",
            r"\b(LT-\d{5})\b",
            r"\b(\d{5,6})\b",
        ], text)
        if found:
            found = found.split("\n")[0].strip()
        return found

    def _extract_industry(self, text: str) -> Optional[str]:
        lines = [line.strip() for line in text.splitlines() if line.strip()]
        for line in lines:
            upper = line.upper()
            if any(kw in upper for kw in ["MANUFACTURER", "TRADING", "SUPPLIER", "INDUSTRIES", "CARPET", "ACOUSTIC", "TEXTILE", "HVAC", "FURNITURE"]):
                if not any(stop in upper for stop in ["ADDRESS:", "FACTORY ADDRESS", "FACTORY OWNER", "PHONE", "VAT NUMBER", "LIMITED", "LTD", "E-MAIL", "URL:", "HTTP"]):
                    return line
        return None

    def _extract_commercial_register(self, text: str) -> Optional[str]:
        return self.find_first([
            r"(?:Commercial\s+Register|C\.R\.|CR(?:\s+No\.?)?|Company\s+Code|Enterprise\s+code|السجل\s+التجاري|سجل\s+تجاري|رقم\s+السجل)[^\S\r\n]*[:=]?[^\S\r\n]*([A-Za-z0-9]+)",
            r"Enterprise\s+code\s+([0-9]+)",
            r"Company\s+code\s*[:\s]*([0-9]+)",
            r"C\.R\.\s*([0-9]+)",
        ], text)

    def _extract_scac_code(self, text: str) -> Optional[str]:
        explicit = self.find_first([
            r"(?:SCAC\s+Code|SCAC|Carrier\s+Code|Liner\s+Code|كود\s+الخط|كود\s+الناقل)[^\S\r\n]*[:=]?[^\S\r\n]*([A-Za-z0-9]{2,6})",
        ], text)
        if explicit:
            return explicit.upper().strip()

        # Known SCAC list
        known_scacs = [
            "HLCU", "ONEY", "COSU", "CULI", "ESLU", "EGLV", "YMLU", "ZIMU",
            "WHLC", "PCIU", "HDMU", "GETU", "ARKU", "OOLU", "KMTC", "SEAU",
            "GRIU", "SITC", "LMCU", "MSCU", "MEDU", "MAEU", "MSKU", "CMDU"
        ]
        for scac in known_scacs:
            if re.search(r"\b" + scac + r"\b", text.upper()):
                return scac
        return None

    def _extract_tracking_url(self, text: str) -> Optional[str]:
        explicit = self.find_first([
            r"(?:Tracking\s+Web\s+URL|Tracking\s+URL|Tracking\s+Link|Tracking|Track\s+&\s+Trace|رابط\s+التتبع|تتبع\s+الشحنة)[^\S\r\n]*[:=]?[^\S\r\n]*(https?://[^\s]+)",
        ], text)
        if explicit:
            return explicit.strip()

        # Find any URL with tracking keywords
        m = re.search(r"\b(https?://[^\s]+(?:track|trace|tracking|shipmentlink|elines|cargoTrack)[^\s]*)\b", text, re.IGNORECASE)
        if m:
            return m.group(1).strip()
        return None

    def _extract_fleet_types(self, text: str) -> Optional[str]:
        found = self.find_first([
            r"(?:Fleet\s+Types|Fleet|Truck\s+Types|Trucks|أنواع\s+الأسطول|الأسطول|الشاحنات|المعدات)[^\S\r\n]*[:=]?[^\S\r\n]*([^\r\n]{3,100})",
        ], text)
        if found:
            return found.strip()
        upper = text.upper()
        fleet_items = []
        if "FLATBED" in upper or "مسطح" in text:
            fleet_items.append("Flatbed Trailers")
        if "LOWBED" in upper or "لوبد" in text:
            fleet_items.append("Lowbed Trailers")
        if "CONTAINER" in upper or "حاويات" in text:
            fleet_items.append("Container Chassis")
        if "REEFER" in upper or "مبرد" in text or "براد" in text:
            fleet_items.append("Refrigerated Trucks")
        if "TIPPER" in upper or "قلاب" in text:
            fleet_items.append("Tippers / Dump Trucks")
        return ", ".join(fleet_items) if fleet_items else None

    def _extract_inspection_scope(self, text: str) -> Optional[str]:
        found = self.find_first([
            r"(?:Inspection\s+Scope|Scope\s+of\s+Work|Testing\s+Scope|Certifications|مجال\s+الفحص|نطاق\s+الفحص|المعاينة)[^\S\r\n]*[:=]?[^\S\r\n]*([^\r\n]{3,100})",
        ], text)
        if found:
            return found.strip()
        upper = text.upper()
        scopes = []
        if "PRE-SHIPMENT" in upper or "قبل الشحن" in text:
            scopes.append("Pre-Shipment Inspection (PSI)")
        if "VOC" in upper or "مطابقة" in text:
            scopes.append("Verification of Conformity (VOC)")
        if "GOIEC" in upper or "صادرات وواردات" in text:
            scopes.append("GOIEC Testing & Certification")
        if "CHEMICAL" in upper or "كيميائي" in text:
            scopes.append("Chemical Analysis")
        return ", ".join(scopes) if scopes else None

    def _extract_insurance_terms(self, text: str) -> Optional[str]:
        found = self.find_first([
            r"(?:Insurance\s+Policy|Policy\s+Terms|Coverage|Cover\s+Type|شروط\s+التأمين|نوع\s+الوثيقة|التغطية\s+التأمينية)[^\S\r\n]*[:=]?[^\S\r\n]*([^\r\n]{3,100})",
        ], text)
        if found:
            return found.strip()
        upper = text.upper()
        if "CLAUSE (A)" in upper or "CLAUSES (A)" in upper or "ICC (A)" in upper or "شامل" in text:
            return "Institute Cargo Clauses (A) - All Risks"
        if "CLAUSE (B)" in upper or "ICC (B)" in upper:
            return "Institute Cargo Clauses (B)"
        if "CLAUSE (C)" in upper or "ICC (C)" in upper:
            return "Institute Cargo Clauses (C)"
        return None

    def _extract_ports(self, text: str) -> Optional[str]:
        found = self.find_first([
            r"(?:Operating\s+Ports|Ports|Customs\s+Offices|موانئ\s+العمل|الموانئ|المنافذ\s+الجمركية)[^\S\r\n]*[:=]?[^\S\r\n]*([^\r\n]{3,100})",
        ], text)
        if found:
            return found.strip()
        upper = text.upper()
        ports = []
        if "ALEXANDRIA" in upper or "الإسكندرية" in text:
            ports.append("Alexandria Port")
        if "SOKHNA" in upper or "السخنة" in text:
            ports.append("Sokhna Port")
        if "DAMMETTA" in upper or "DAMMIETTA" in upper or "دمياط" in text:
            ports.append("Damietta Port")
        if "PORT SAID" in upper or "بورسعيد" in text:
            ports.append("Port Said")
        if "CAIRO AIRPORT" in upper or "مطار القاهرة" in text:
            ports.append("Cairo Airport Cargo")
        if "DEKHEILA" in upper or "الدخيلة" in text:
            ports.append("Dekheila Port")
        return ", ".join(ports) if ports else None

    def _extract_supplier_type(self, text: str) -> Optional[str]:
        explicit = self.find_first([
            r"(?:Supplier\s+Type|Type\s+of\s+Supplier|Vendor\s+Type|نوع\s+المورد|صفة\s+المورد)[^\S\r\n]*[:=]?[^\S\r\n]*([^\r\n]{3,60})",
        ], text)
        if explicit:
            val = explicit.strip()
            val_u = val.upper()
            if "MANUFACTURER" in val_u or "مصنع" in val or "PRODUCER" in val_u:
                return "Manufacturer"
            if "AGENT" in val_u or "DISTRIBUTOR" in val_u or "وكيل" in val or "موزع" in val:
                return "Authorized Agent / Distributor"
            if "EXPORTER" in val_u or "مُصدّر" in val or "مصدر" in val:
                return "Exporter"
            if "TRADER" in val_u or "SUPPLIER" in val_u or "تاجر" in val or "مورد" in val:
                return "Foreign Supplier / Trader"
            return val

        upper = text.upper()
        if "MANUFACTURER" in upper or "FACTORY" in upper or "PRODUCER" in upper:
            return "Manufacturer"
        if "AUTHORIZED AGENT" in upper or "DISTRIBUTOR" in upper:
            return "Authorized Agent / Distributor"
        if "EXPORTER" in upper:
            return "Exporter"
        return "Manufacturer"

    def _extract_bank_name(self, text: str) -> Optional[str]:
        return self.find_first([
            r"(?:Bank\s+Name|Beneficiary\s+Bank|Bank|اسم\s+البنك|البنك\s+المستفيد|مصرف)[^\S\r\n]*[:=]?[^\S\r\n]*([^\r\n]{3,80})",
            r"(?:Bank\s*:\s*)([^\r\n]{3,80})",
        ], text)

    def _extract_brands(self, text: str) -> Optional[str]:
        return self.find_first([
            r"(?:Brands|Brand\s+Name|Products|Product\s+Lines|العلامات\s+التجارية|الماركات|المنتجات)[^\S\r\n]*[:=]?[^\S\r\n]*([^\r\n]{2,100})",
        ], text)

    def _extract_notes(self, text: str) -> Optional[str]:
        return self.find_first([
            r"(?:Notes|Remarks|Additional\s+Notes|ملاحظات|ملاحظات\s+إضافية)[^\S\r\n]*[:=]?[^\S\r\n]*([^\r\n]{3,200})",
        ], text)

    def _extract_secondary_email(self, text: str) -> Optional[str]:
        emails = re.findall(r"\b([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})\b", text)
        unique_emails = []
        for em in emails:
            if em.lower() not in [u.lower() for u in unique_emails]:
                unique_emails.append(em)
        if len(unique_emails) >= 2:
            return unique_emails[1]
        return None

    def _extract_country_name(self, text: str) -> Optional[str]:
        code = self._extract_country(text)
        if not code:
            return None
        code_map = {
            "CN": "China (CN)",
            "EG": "Egypt (EG)",
            "US": "United States (US)",
            "DE": "Germany (DE)",
            "IT": "Italy (IT)",
            "TR": "Turkey (TR)",
            "AE": "United Arab Emirates (AE)",
            "SA": "Saudi Arabia (SA)",
            "IN": "India (IN)",
            "GB": "United Kingdom (GB)",
            "ES": "Spain (ES)",
            "FR": "France (FR)",
            "JP": "Japan (JP)",
            "KR": "South Korea (KR)",
            "RU": "Russia (RU)",
            "BR": "Brazil (BR)",
            "LT": "Lithuania (LT)",
            "NL": "Netherlands (NL)",
            "VN": "Vietnam (VN)",
            "CH": "Switzerland (CH)",
            "BE": "Belgium (BE)",
            "CA": "Canada (CA)",
            "AU": "Australia (AU)",
            "PL": "Poland (PL)",
            "SE": "Sweden (SE)",
            "PT": "Portugal (PT)",
            "AT": "Austria (AT)",
            "GR": "Greece (GR)",
            "JO": "Jordan (JO)",
        }
        return code_map.get(code, code)

    def _extract_nafeza_token(self, text: str) -> Optional[str]:
        explicit = self.find_first([
            r"(?:Nafeza\s+Token|Token\s+ID|E-Token|Nafeza\s+E-Token|توكن\s+نافذة|رمز\s+نافذة|توكن)[^\S\r\n]*[:=]?[^\S\r\n]*([A-Za-z0-9\-_]{5,40})",
            r"\b(NFT-[A-Za-z0-9\-]{5,25})\b",
        ], text)
        return explicit.strip() if explicit else None

    def _extract_branch_name(self, text: str) -> Optional[str]:
        return self.find_first([
            r"(?:Branch\s+Name|Branch|اسم\s+الفرع|الفرع)[^\S\r\n]*[:=]?[^\S\r\n]*([^\r\n]{3,60})",
            r"\b([A-Za-z\u0600-\u06FF\s]{3,40}\s+(?:Branch|فرع))\b",
        ], text)

    def _extract_bank_code(self, text: str) -> Optional[str]:
        return self.find_first([
            r"(?:Bank\s+Code|كود\s+البنك|رمز\s+البنك)[^\S\r\n]*[:=]?[^\S\r\n]*([A-Za-z0-9\-_]{3,20})",
        ], text)

    def _extract_transport_license(self, text: str) -> Optional[str]:
        return self.find_first([
            r"(?:Transport\s+License|Truck\s+License|ترخيص\s+النقل|رخصة\s+النقل|ترخيص\s+الأسطول)[^\S\r\n]*[:=]?[^\S\r\n]*([A-Za-z0-9\-_/]{3,30})",
            r"\b(TR-[0-9]{4,10})\b",
        ], text)

    def _extract_inspection_accreditation(self, text: str) -> Optional[str]:
        return self.find_first([
            r"(?:Accreditation\s+No\.?|GOIEC\s+Reg|ISO\s+Accreditation|رقم\s+الاعتماد|تسجيل\s+الرقابة\s+على\s+الصادرات)[^\S\r\n]*[:=]?[^\S\r\n]*([A-Za-z0-9\-_/]{3,30})",
            r"\b(GOIEC-[A-Za-z0-9\-]{3,15})\b",
        ], text)

    def _extract_insurance_license(self, text: str) -> Optional[str]:
        return self.find_first([
            r"(?:Insurance\s+License|FRA\s+License|ترخيص\s+التأمين|ترخيص\s+الرقابة\s+المالية)[^\S\r\n]*[:=]?[^\S\r\n]*([A-Za-z0-9\-_/]{3,30})",
            r"\b(FRA-[0-9]{3,10})\b",
        ], text)

    def _extract_fiata_id(self, text: str) -> Optional[str]:
        return self.find_first([
            r"(?:FIATA\s+ID|FIATA\s+License|رخصة\s+الفياتا|فياتا)[^\S\r\n]*[:=]?[^\S\r\n]*([A-Za-z0-9\-_/]{3,30})",
            r"\b(FIATA-[A-Za-z0-9\-]{3,15})\b",
        ], text)

    def _extract_has_iso(self, text: str) -> bool:
        return bool(re.search(r"\b(ISO\s*9001|ISO\s*14001|ISO\s*45001|ISO\s*22000|ISO\s*CERTIFIED|آيزو|شهادة\s+آيزو)\b", text, re.IGNORECASE))

    def _extract_decree_43(self, text: str) -> bool:
        return bool(re.search(r"\b(DECREE\s*43|REGULATION\s*43|قرار\s*43|قرار\s*وزاري\s*43|43/2016)\b", text, re.IGNORECASE))

    def _extract_white_list(self, text: str) -> bool:
        return bool(re.search(r"\b(WHITE\s*LIST|WHITELIST|القائمة\s+البيضاء|قائمة\s+بيضاء)\b", text, re.IGNORECASE))

    def _extract_credit_limit(self, text: str) -> Optional[float]:
        val = self.find_first([
            r"(?:Credit\s+Limit|حد\s+الائتمان|الحد\s+الائتماني)[^\S\r\n]*[:=]?[^\S\r\n]*([0-9.,]+)",
        ], text)
        if val:
            try:
                return float(val.replace(",", "").strip())
            except ValueError:
                pass
        return 0.0

    def _extract_rating(self, text: str) -> Optional[float]:
        val = self.find_first([
            r"(?:Rating|التقييم|الرتبة)[^\S\r\n]*[:=]?[^\S\r\n]*([0-9.]+)",
        ], text)
        if val:
            try:
                r = float(val.strip())
                if 1.0 <= r <= 5.0:
                    return r
            except ValueError:
                pass
        return 5.0

    def _extract_has_wipo(self, text: str) -> bool:
        return bool(re.search(r"\b(?:WIPO|Madrid\s+Monitor|ويبو|مدريد)\b", text, re.IGNORECASE))

    def _extract_has_global_brand(self, text: str) -> bool:
        return bool(re.search(r"\b(?:Global\s+Brand\s+Database|Global\s+Brand|GBD|قاعدة\s+بيانات\s+العلامات)\b", text, re.IGNORECASE))

    def _find_labeled_identifier(
        self, label_pattern: str, text: str, reject_year_only: bool = False, min_len: int = 3
    ) -> Optional[str]:
        """First identifier (containing a digit) that follows ``label_pattern`` + filler words + separators."""
        pattern = rf"(?:{label_pattern}){_FILLER}{_SEPARATORS}{_IDENTIFIER_VALUE}"
        for m in re.finditer(pattern, text, re.IGNORECASE):
            value = m.group(1).strip().rstrip(".-_/ ")
            if len(value) < min_len or not re.search(r"\d", value):
                continue
            if reject_year_only and _YEAR_ONLY.fullmatch(value):
                continue
            return value
        return None

    def _extract_cargox_id(self, text: str) -> Optional[str]:
        labeled = self._find_labeled_identifier(
            r"\bCargo[^\S\r\n]*-?[^\S\r\n]*X\b|كارجو[^\S\r\n]*[إا]كس|كارجوكس|كارجو[^\S\r\n]*X",
            text,
            min_len=4,
        )
        if labeled:
            return labeled
        m = re.search(r"\b(0x[a-fA-F0-9]{40})\b", text)
        if m:
            return m.group(1)
        m_cx = re.search(r"\b(CX-[A-Za-z0-9][A-Za-z0-9\-]{3,30})\b", text)
        return m_cx.group(1) if m_cx else None

    def _extract_swift(self, text: str) -> Optional[str]:
        label = (
            r"(?:\bSWIFT(?:[^\S\r\n]*/[^\S\r\n]*BIC)?(?:[^\S\r\n]*Code)?|\bBIC\b|كود[^\S\r\n]+السويفت|"
            r"رمز[^\S\r\n]+السويفت|السويفت|سويفت)"
        )
        pattern = rf"{label}{_FILLER}{_SEPARATORS}([A-Za-z0-9]{{8,11}})\b"
        for m in re.finditer(pattern, text, re.IGNORECASE):
            value = m.group(1).upper()
            if _SWIFT_SHAPE.fullmatch(value):
                return value

        # Unlabeled: 8/11-char BIC with a known country code in positions 5-6
        m = re.search(r"\b([A-Z]{4}(?:EG|US|CN|GB|DE|IT|FR|TR|SA|AE|ES|JP|KR|BR|RU|VN|CH|NL|BE|CA|AU|SG|HK)[A-Z0-9]{2}(?:[A-Z0-9]{3})?)\b", text)
        if m:
            val = m.group(1).strip()
            if val.upper() not in ["SUPPLIER", "CONTAINER", "REGISTER", "IMPORTFLOW", "SHIPPER"]:
                return val
        return None

    def _extract_iban(self, text: str) -> Optional[str]:
        # 1. Labeled IBAN (also an IBAN written under an "Account No." label). Structure is enough here:
        #    an OCR slip in one digit must still reach the form so the user can correct it.
        label = (
            r"(?:\bIBAN\b|\bAccount[^\S\r\n]+(?:No\.?|Number)|\bA/C\b|الآيبان|الايبان|آيبان|ايبان|رقم[^\S\r\n]+الحساب)"
        )
        pattern = rf"{label}{_FILLER}{_SEPARATORS}([A-Za-z]{{2}}[0-9]{{2}}(?:[^\S\r\n]?[A-Za-z0-9]){{11,40}})"
        for m in re.finditer(pattern, text, re.IGNORECASE):
            candidate = compact_iban_candidate(m.group(1))
            if candidate and re.fullmatch(r"[A-Z]{2}\d{2}[A-Z0-9]{11,30}", candidate):
                return candidate

        # 2. Unlabeled: only a checksum-valid IBAN is accepted.
        for m in re.finditer(r"\b([A-Z]{2}[0-9]{2}(?:[^\S\r\n]?[A-Z0-9]){11,40})", text):
            candidate = compact_iban_candidate(m.group(1))
            if candidate and iban_checksum_valid(candidate):
                return candidate
        return None

    def _extract_account_number(self, text: str, iban: Optional[str] = None) -> Optional[str]:
        """Local account number (digits). Never the IBAN and never the SWIFT code."""
        label = (
            r"(?:\bA/C\b|\bAcc(?:ount)?\b\.?|\bBank[^\S\r\n]+Account\b|رقم[^\S\r\n]+الحساب|حساب[^\S\r\n]+رقم|"
            r"الحساب[^\S\r\n]+البنكي|الحساب[^\S\r\n]+الجاري)"
        )
        pattern = rf"{label}{_FILLER}{_SEPARATORS}([0-9](?:[0-9\-]|[^\S\r\n](?=[0-9])){{4,40}})"
        iban_compact = (iban or "").replace(" ", "").upper()
        for m in re.finditer(pattern, text, re.IGNORECASE):
            value = m.group(1).strip(" -")
            digits = re.sub(r"\D", "", value)
            if not 6 <= len(digits) <= 30:
                continue
            if iban_compact and digits == re.sub(r"\D", "", iban_compact):
                continue
            return value
        return None

    def _extract_wipo_number(self, text: str) -> Optional[str]:
        return self._find_labeled_identifier(
            r"\bWIPO\b(?:[^\S\r\n]*-?[^\S\r\n]*Madrid(?:[^\S\r\n]+Monitor)?)?|\bMadrid[^\S\r\n]+(?:Monitor|Protocol|System)\b|الويبو|ويبو|مدريد",
            text,
            reject_year_only=True,
        )

    def _extract_has_euipo(self, text: str) -> bool:
        return bool(re.search(
            r"\b(?:EUIPO|EUTM|European\s+Union\s+Intellectual\s+Property|European\s+Union\s+Trade\s*Mark)\b|علامة\s+الاتحاد\s+الأوروبي",
            text,
            re.IGNORECASE,
        ))

    def _extract_euipo_number(self, text: str) -> Optional[str]:
        return self._find_labeled_identifier(
            r"\bEUIPO\b|\bEUTM\b|European[^\S\r\n]+Union[^\S\r\n]+(?:Intellectual[^\S\r\n]+Property(?:[^\S\r\n]+Office)?|Trade[^\S\r\n]*Mark)|علامة[^\S\r\n]+الاتحاد[^\S\r\n]+الأوروبي",
            text,
            reject_year_only=True,
        )

    def _extract_global_brand_number(self, text: str) -> Optional[str]:
        return self._find_labeled_identifier(
            r"\bGlobal[^\S\r\n]+Brands?(?:[^\S\r\n]+Database)?\b|\bGBD\b|قاعدة[^\S\r\n]+بيانات[^\S\r\n]+العلامات(?:[^\S\r\n]+التجارية)?|العلامة[^\S\r\n]+العالمية",
            text,
            reject_year_only=True,
        )

    def _extract_has_iso_9001(self, text: str) -> bool:
        return bool(re.search(r"\bISO[\s\-]*9001\b|[أآا]يزو\s*9001", text, re.IGNORECASE))

    def _extract_iso_9001_number(self, text: str) -> Optional[str]:
        # "ISO 9001:2015 Certificate No: Q-123" -> "Q-123" (the standard's year is never the certificate number)
        return self._find_labeled_identifier(
            r"\bISO[^\S\r\n]*-?[^\S\r\n]*9001(?:[^\S\r\n]*[:\-][^\S\r\n]*(?:19|20)\d{2})?|[أآا]يزو[^\S\r\n]*9001(?:[^\S\r\n]*[:\-][^\S\r\n]*(?:19|20)\d{2})?",
            text,
            reject_year_only=True,
        )
