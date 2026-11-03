"""
Nafeza Customs Declaration & Unified Fees Extractor
Extracts structured fields from Egyptian Nafeza official customs documents:
1. "نموذج مراجعة بيانات شهادة جمركية" (Customs Declaration Data Review Form):
   - Exchange rate (سعر التحويل الجمركي) e.g. 56.1986
   - Incoterm (نوع التعاقد) e.g. EXFACTORY, EXW, FOB, CIF
   - Assessed CIF EGP (القيمة المقر عنها / وعاء القيمة الجمركية) e.g. 2902035.00
   - Currency, invoice value, freight in USD, insurance in EGP, discharge/handling in EGP
   - HS Code, quantity, weight, and customs import duty rate (نسبة ضريبة الوارد)
2. "تفاصيل استمارة الرسوم الموحدة" (Unified Fees Form Details):
   - Electronic payment number (رقم السداد الإلكتروني)
   - Importer Tax ID (الرقم الضريبي)
   - Importer Name (اسم المستورد)
   - Print Date (تاريخ الطباعة)
   - Customs financial codes breakdown:
     [1] ضريبة الوارد (import duty)
     [32] ضريبة القيمة المضافة (VAT)
     [37] أ.ت.ص (commercial & industrial profit tax)
     [788] فحص بالأشعة (X-ray inspection)
     [3] مصاريف إدارية (admin expenses)
     [77] مهن حرة (freelance / professional tax)
     [232] تحت الحساب (advance VAT payment)
     [250] طباعة (printing fee)
     [798] نموذج 19 (Form 19 fee)
     [60] دمغة مميكن (mechanized stamp)
     [74] خدمات مميكنة (mechanized services)
     [107] تنمية محررات (deed development fee)
     Nafeza platform fees: [390, 392, 394, 397]
   - Total amount paid in Nafeza (إجمالي المبلغ المسدد بنافذة)
"""

from __future__ import annotations

import re
from typing import Any, Dict, List, Optional, Tuple

from modules.smart_document_upload.extractors.base_extractor import BaseExtractor


# ─── Arabic Digit Normalizer ──────────────────────────────────────────────────

_ARABIC_DIGITS_MAP = str.maketrans("٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹،", "01234567890123456789,")


def _normalize_arabic_numbers(text: str) -> str:
    """Replaces Eastern Arabic and Persian numerals with ASCII digits and Arabic comma with comma."""
    if not text:
        return ""
    return text.translate(_ARABIC_DIGITS_MAP)


# ─── Known Nafeza Financial Codes Specification ───────────────────────────────

KNOWN_FINANCIAL_CODES: Dict[str, Dict[str, Any]] = {
    "1": {
        "key": "code_1_import_duty",
        "alias": "duty_amount",
        "name_ar": "ضريبة الوارد",
        "keywords": ["ضريبة الوارد", "ضريبة وارد", "وارد جمركي", "رسوم جمركية", "Import Duty", "Customs Duty"],
    },
    "32": {
        "key": "code_32_vat",
        "alias": "vat_amount",
        "name_ar": "ضريبة القيمة المضافة",
        "keywords": ["ضريبة القيمة المضافة", "قيمة مضافة", "ض.ق.م", "ض ق م", "VAT", "Value Added Tax"],
    },
    "37": {
        "key": "code_37_profit_tax",
        "alias": "profit_tax",
        "name_ar": "أ.ت.ص",
        "keywords": ["أ.ت.ص", "أ ت ص", "أ.ت.ص.", "أرباح تجارية وصناعية", "ارباح تجارية وصناعية", "ضريبة أ.ت.ص", "ضريبة أ ت ص", "WHT"],
    },
    "788": {
        "key": "code_788_xray",
        "alias": "xray_fee",
        "name_ar": "فحص بالأشعة",
        "keywords": ["فحص بالأشعة", "فحص بالاشعة", "كشف بالأشعة", "كشف بالاشعة", "فحص أشعة", "فحص اشعة", "أشعة", "اشعة", "X-Ray", "Xray"],
    },
    "3": {
        "key": "code_3_admin",
        "alias": "admin_fee",
        "name_ar": "مصاريف إدارية",
        "keywords": ["مصاريف إدارية", "مصاريف ادارية", "مصروفات إدارية", "مصروفات ادارية", "رسم مصاريف إدارية", "Admin Fee"],
    },
    "77": {
        "key": "code_77_professions",
        "alias": "professions_tax",
        "name_ar": "مهن حرة",
        "keywords": ["مهن حرة", "مهن حره", "ضريبة مهن حرة", "رسم مهن حرة", "نقابة التجاريين", "Professions Tax"],
    },
    "232": {
        "key": "code_232_under_account",
        "alias": "under_account",
        "name_ar": "تحت الحساب",
        "keywords": ["تحت الحساب", "تحت حساب قيمة مضافة", "تحت حساب ضريبة القيمة المضافة", "تحت حساب الضريبة", "Under Account"],
    },
    "250": {
        "key": "code_250_printing",
        "alias": "printing_fee",
        "name_ar": "طباعة",
        "keywords": ["طباعة", "رسم طباعة", "رسم طباعة بيان جمركي موحد", "طباعة بيان جمركي", "طباعة بيان", "Printing"],
    },
    "798": {
        "key": "code_798_form_19",
        "alias": "form_19_fee",
        "name_ar": "نموذج 19",
        "keywords": ["نموذج 19", "نموذج ١٩", "رسم نموذج 19", "نموذج 19 ك م", "نموذج 19 ك.م", "Form 19"],
    },
    "60": {
        "key": "code_60_stamp",
        "alias": "mechanized_stamp",
        "name_ar": "دمغة مميكن",
        "keywords": ["دمغة مميكن", "دمغة مميكنة", "دمغة إقرار مميكن", "دمغة ميكنة", "دمغة", "Stamp"],
    },
    "74": {
        "key": "code_74_services",
        "alias": "mechanized_services",
        "name_ar": "خدمات مميكنة",
        "keywords": ["خدمات مميكنة", "خدمات مميكنه", "رسم خدمات مميكنة", "خدمات إلكترونية", "خدمات الكترونية", "Mechanized Services"],
    },
    "107": {
        "key": "code_107_deed_dev",
        "alias": "deed_development",
        "name_ar": "تنمية محررات",
        "keywords": ["تنمية محررات", "رسم تنمية محررات", "تنمية محررات رسمية", "Deed Development"],
    },
    "390": {
        "key": "code_390_nafeza_customs",
        "alias": "nafeza_customs_service",
        "name_ar": "خدمات جمركية نافذة",
        "keywords": ["خدمات جمركية نافذة", "رسوم خدمات نافذة جمركية", "خدمات جمركية", "نافذة خدمات جمركية"],
    },
    "392": {
        "key": "code_392_nafeza_info",
        "alias": "nafeza_info_service",
        "name_ar": "خدمات معلوماتية نافذة",
        "keywords": ["خدمات معلوماتية نافذة", "رسوم خدمات معلوماتية نافذة", "خدمات معلوماتية", "نافذة خدمات معلوماتية"],
    },
    "394": {
        "key": "code_394_nafeza_vat",
        "alias": "nafeza_vat",
        "name_ar": "ضريبة قيمة مضافة على خدمات نافذة",
        "keywords": ["ضريبة قيمة مضافة على خدمات نافذة", "ق.م خدمات نافذة", "ق م خدمات نافذة", "ضريبة خدمات نافذة", "ضريبة قيمة مضافة خدمات نافذة"],
    },
    "397": {
        "key": "code_397_martyrs_fund",
        "alias": "martyrs_fund",
        "name_ar": "صندوق تكريم الشهداء",
        "keywords": ["صندوق تكريم الشهداء", "تكريم الشهداء", "رسم الشهداء", "صندوق الشهداء", "شهداء", "Martyrs Fund"],
    },
}

NAFEZA_PLATFORM_CODES = ["390", "392", "394", "397"]


class NafezaDeclarationExtractor(BaseExtractor):
    """
    Extractor for Egyptian Nafeza Customs Declarations:
    - Form A: "نموذج مراجعة بيانات شهادة جمركية" (Customs Declaration Data Review Form)
    - Form B: "تفاصيل استمارة الرسوم الموحدة" (Unified Fees Form Details)
    - Combined multi-page or combined Nafeza declarations.
    """

    def required_fields(self) -> List[str]:
        return ["assessed_cif_egp", "total_paid_nafeza"]

    def compute_confidence(self, extracted: Dict[str, Any]) -> float:
        """Dynamically compute extraction confidence based on detected document type."""
        doc_type = extracted.get("document_type")
        if doc_type == "nafeza_declaration_review":
            required = ["exchange_rate", "assessed_cif_egp", "incoterm", "hs_code"]
        elif doc_type == "nafeza_unified_fees":
            required = ["e_payment_no", "importer_tax_id", "total_paid_nafeza", "duty_amount"]
        else:
            required = ["exchange_rate", "assessed_cif_egp", "total_paid_nafeza", "duty_amount"]

        found = sum(
            1 for f in required
            if extracted.get(f) is not None and str(extracted.get(f, "")).strip() != ""
        )
        return round(found / len(required), 2)

    def extract(self, raw_text: str, spatial_boxes: dict = None) -> Dict[str, Any]:
        raw = raw_text or ""
        text = _normalize_arabic_numbers(raw).replace("\r\n", "\n").replace("\r", "\n")

        # ─── Document Type Detection ──────────────────────────────────────────
        doc_type = self._detect_document_type(text)

        # ─── Shared Header & Metadata ─────────────────────────────────────────
        declaration_no = self._extract_declaration_no(text)
        declaration_date = self._extract_declaration_date(text)
        customs_office = self._extract_customs_office(text)
        acid_number = self._extract_acid_number(text)
        importer_name = self._extract_importer_name(text)
        importer_tax_id = self._extract_tax_id(text)
        e_payment_no = self._extract_epayment_no(text)
        print_date = self._extract_print_date(text)

        # ─── Form A: نموذج مراجعة بيانات شهادة جمركية ──────────────────────────
        exchange_rate = self._extract_exchange_rate(text)
        incoterm = self._extract_incoterm(text)
        currency = self._extract_currency(text)
        invoice_value = self._extract_invoice_value(text)
        freight_usd = self._extract_freight_usd(text)
        insurance_egp = self._extract_insurance_egp(text)
        discharge_egp = self._extract_discharge_egp(text)
        assessed_cif_egp = self._extract_assessed_cif(text)

        hs_code = self._extract_hs_code(text)
        quantity = self._extract_quantity(text)
        weight = self._extract_weight(text)
        duty_rate = self._extract_duty_rate(text)

        # ─── Form B: تفاصيل استمارة الرسوم الموحدة ───────────────────────────
        financial_breakdown, individual_codes = self._extract_financial_codes(text)

        # Nafeza platform fees calculation ([390, 392, 394, 397])
        nafeza_fees_total = round(
            sum(individual_codes.get(f"code_{c}", 0.0) for c in NAFEZA_PLATFORM_CODES),
            2,
        )

        # Total amount paid in Nafeza
        total_paid_nafeza = self._extract_total_paid(text, individual_codes)

        # Build items list (single or multiple items in declaration review)
        items = []
        if hs_code or quantity or weight or duty_rate:
            items.append({
                "hs_code": hs_code,
                "quantity": quantity,
                "weight": weight,
                "duty_rate": duty_rate,
                "cif_value_egp": assessed_cif_egp,
            })

        # Assemble full result dictionary
        result: Dict[str, Any] = {
            "document_type": doc_type,
            "declaration_no": declaration_no,
            "declaration_date": declaration_date,
            "customs_office": customs_office,
            "acid_number": acid_number,
            "e_payment_no": e_payment_no,
            "importer_tax_id": importer_tax_id,
            "importer_name": importer_name,
            "print_date": print_date,
            # Form A fields
            "exchange_rate": exchange_rate,
            "incoterm": incoterm,
            "currency": currency,
            "invoice_value": invoice_value,
            "freight_usd": freight_usd,
            "insurance_egp": insurance_egp,
            "discharge_egp": discharge_egp,
            "assessed_cif_egp": assessed_cif_egp,
            "hs_code": hs_code,
            "quantity": quantity,
            "weight": weight,
            "duty_rate": duty_rate,
            "items": items,
            # Form B individual codes & named aliases
            "code_1_import_duty": individual_codes.get("code_1", None),
            "duty_amount": individual_codes.get("code_1", None),
            "code_32_vat": individual_codes.get("code_32", None),
            "vat_amount": individual_codes.get("code_32", None),
            "code_37_profit_tax": individual_codes.get("code_37", None),
            "profit_tax": individual_codes.get("code_37", None),
            "code_788_xray": individual_codes.get("code_788", None),
            "xray_fee": individual_codes.get("code_788", None),
            "code_3_admin": individual_codes.get("code_3", None),
            "admin_fee": individual_codes.get("code_3", None),
            "code_77_professions": individual_codes.get("code_77", None),
            "professions_tax": individual_codes.get("code_77", None),
            "code_232_under_account": individual_codes.get("code_232", None),
            "under_account": individual_codes.get("code_232", None),
            "code_250_printing": individual_codes.get("code_250", None),
            "printing_fee": individual_codes.get("code_250", None),
            "code_798_form_19": individual_codes.get("code_798", None),
            "form_19_fee": individual_codes.get("code_798", None),
            "code_60_stamp": individual_codes.get("code_60", None),
            "mechanized_stamp": individual_codes.get("code_60", None),
            "code_74_services": individual_codes.get("code_74", None),
            "mechanized_services": individual_codes.get("code_74", None),
            "code_107_deed_dev": individual_codes.get("code_107", None),
            "deed_development": individual_codes.get("code_107", None),
            "code_390_nafeza_customs": individual_codes.get("code_390", None),
            "nafeza_customs_service": individual_codes.get("code_390", None),
            "code_392_nafeza_info": individual_codes.get("code_392", None),
            "nafeza_info_service": individual_codes.get("code_392", None),
            "code_394_nafeza_vat": individual_codes.get("code_394", None),
            "nafeza_vat": individual_codes.get("code_394", None),
            "code_397_martyrs_fund": individual_codes.get("code_397", None),
            "martyrs_fund": individual_codes.get("code_397", None),
            # Aggregates
            "nafeza_fees_total": nafeza_fees_total if nafeza_fees_total > 0 else None,
            "total_paid_nafeza": total_paid_nafeza,
            "financial_codes_breakdown": financial_breakdown,
            # Compatibility aliases for customs clearance pipeline
            "customs_value_egp": assessed_cif_egp,
            "import_duty": individual_codes.get("code_1", None),
            "wht_amount": individual_codes.get("code_37", None),
            "total_taxes": total_paid_nafeza,
        }

        # Calculate confidence
        result["confidence_score"] = self.compute_confidence(result)
        return result

    # ─── Internal Parsing Helpers ─────────────────────────────────────────────

    def _detect_document_type(self, text: str) -> str:
        has_review = bool(re.search(
            r"(?:نموذج\s+مراجعة|مراجعة\s+بيانات\s+شهادة|بيانات\s+شهادة\s+جمركية|سعر\s+التحويل|القيمة\s+المقر\s+عنها)",
            text,
            re.IGNORECASE,
        ))
        has_fees = bool(re.search(
            r"(?:استمارة\s+الرسوم\s+الموحدة|تفاصيل\s+استمارة|رقم\s+السداد\s+الإلكتروني|المبلغ\s+المسدد\s+بنافذة|صندوق\s+تكريم\s+الشهداء)",
            text,
            re.IGNORECASE,
        ))

        if has_review and has_fees:
            return "nafeza_combined"
        elif has_review:
            return "nafeza_declaration_review"
        elif has_fees:
            return "nafeza_unified_fees"
        return "nafeza_declaration"

    def _extract_declaration_no(self, text: str) -> Optional[str]:
        return self.find_first([
            r"(?:رقم\s+الشهادة\s+الجمركية|رقم\s+الشهادة|رقم\s+البيان\s+الجمركي|رقم\s+البيان|بيان\s+رقم|شهادة\s+رقم|Declaration\s+No\.?|Certificate\s+No\.?)[:\s#]*([0-9/\-]{4,30})",
            r"(?:نموذج\s+46|46\s*ك\.?م?)[:\s#]*([0-9/\-]{4,30})",
        ], text)

    def _extract_declaration_date(self, text: str) -> Optional[str]:
        return self.find_first([
            r"(?:تاريخ\s+الشهادة|تاريخ\s+البيان|تاريخ\s+الإقرار|Declaration\s+Date)[:\s]+(\d{1,4}[/-]\d{1,2}[/-]\d{2,4})",
            r"(?:تاريخ\s+الشهادة|تاريخ\s+البيان)[:\s]+(\d{4}-\d{2}-\d{2})",
        ], text)

    def _extract_customs_office(self, text: str) -> Optional[str]:
        return self.find_first([
            r"(?:المركز\s+اللوجستي\s*ب?|جمرك\s*|ميناء\s*|Customs\s+Office|Logistics\s+Center)[:\s]+([^\n,]{3,60}?)(?:\n|$|\|)",
        ], text)

    def _extract_acid_number(self, text: str) -> Optional[str]:
        match = self.find_first([
            r"(?:ACID|ACI\s+NO|رقم\s+التسجيل\s+المسبق|رقم\s+الاسيد|رقم\s+الإسيد)[:\s#,-]*([0-9a-zA-Z]{19})",
            r"\b(\d{19})\b",
        ], text)
        if match:
            clean = re.sub(r"[^0-9]", "", match)
            if len(clean) == 19:
                return clean
        return None

    def _extract_importer_name(self, text: str) -> Optional[str]:
        name = self.find_first([
            r"(?:اسم\s+المستورد|المستورد|الشركة\s+المستوردة|اسم\s+العميل|Consignee|Importer(?:\s+Name)?)[:\s]+(?:شركة\s+)?([^\n|,]{3,80}?)(?:\n|$|\||\()",
        ], text)
        if name:
            return name.strip()
        return None

    def _extract_tax_id(self, text: str) -> Optional[str]:
        tax_id = self.find_first([
            r"(?:الرقم\s*الضريبي(?:\s*للمستورد)?|البطاقة\s*الضريبية|السجل\s*الضريبي|رقم\s*التسجيل\s*الضريبي|Tax\s*ID)[:\s#]*(\d{3}[-\s]?\d{3}[-\s]?\d{3}|\d{9})",
            r"\b(\d{3}-\d{3}-\d{3})\b",
        ], text)
        if tax_id:
            clean = re.sub(r"[\s-]", "", tax_id)
            if len(clean) == 9:
                return clean
        return None

    def _extract_epayment_no(self, text: str) -> Optional[str]:
        return self.find_first([
            r"(?:رقم\s+السداد\s+الإلكتروني|رقم\s+السداد\s+الالكتروني|رقم\s+إذن\s+السداد|رقم\s+السداد|إذن\s+سداد\s+رقم|Electronic\s+Payment\s*No\.?|e-?Payment\s*No\.?)[:\s#]*([0-9A-Za-z\-_]{4,35})",
        ], text)

    def _extract_print_date(self, text: str) -> Optional[str]:
        return self.find_first([
            r"(?:تاريخ\s+الطباعة|تاريخ\s+استخراج\s+الاستمارة|تاريخ\s+الإصدار|Print\s+Date)[:\s]+(\d{1,4}[/-]\d{1,2}[/-]\d{2,4}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?)",
        ], text)

    # ─── Form A Specific Fields ───────────────────────────────────────────────

    def _extract_exchange_rate(self, text: str) -> Optional[float]:
        return self.find_float([
            r"(?:سعر\s+التحويل\s+الجمركي|سعر\s+التحويل|سعر\s+الصرف\s+الجمركي|سعر\s+الصرف|سعر\s+الدولار\s+الجمركي|معامل\s+التحويل|Exchange\s+Rate|Customs\s+FX\s+Rate)[:\s]+([0-9]+\.?[0-9]*)",
            r"([0-9]+\.[0-9]{3,6})\s*(?:سعر\s+التحويل|معامل\s+التحويل)",
        ], text)

    def _extract_incoterm(self, text: str) -> Optional[str]:
        # Check explicit EXFACTORY / EX FACTORY first
        if re.search(r"(?:نوع\s+التعاقد|شرط\s+التعاقد|شرط\s+التسليم|شرط\s+الشحن|Incoterms?)[^\n:]*?[:\s]+(EX[\s\-]?FACTORY|EXW|FOB|CIF|CFR|DDP|DAP|FCA|CPT|CIP)", text, re.I):
            m = re.search(r"(?:نوع\s+التعاقد|شرط\s+التعاقد|شرط\s+التسليم|شرط\s+الشحن|Incoterms?)[^\n:]*?[:\s]+(EX[\s\-]?FACTORY|EXW|FOB|CIF|CFR|DDP|DAP|FCA|CPT|CIP)", text, re.I)
            term = m.group(1).upper().replace(" ", "").replace("-", "")
            if "EXFACTORY" in term:
                return "EXFACTORY"
            return term

        # Standalone EXFACTORY match
        if re.search(r"\bEX[\s\-]?FACTORY\b", text, re.I):
            return "EXFACTORY"

        return self.normalize_incoterms(text)

    def _extract_currency(self, text: str) -> Optional[str]:
        explicit = self.find_first([
            r"(?:العملة|كود\s+العملة|Currency)[:\s]+(USD|EUR|GBP|EGP|CNY|JPY|AED|SAR|دولار(?:\s+أمريكي)?|يورو|جنيه(?:\s+مصري)?)",
        ], text)
        if explicit:
            norm = explicit.upper().strip()
            if "دولار" in explicit or "USD" in norm:
                return "USD"
            if "يورو" in explicit or "EUR" in norm:
                return "EUR"
            if "جنيه" in explicit or "EGP" in norm:
                return "EGP"
            return norm
        return self.normalize_currency(text)

    def _extract_invoice_value(self, text: str) -> Optional[float]:
        return self.find_float([
            r"(?:قيمة\s+الفاتورة\s*(?:\([^)]+\))?|مبلغ\s+الفاتورة|الفاتورة\s+التجارية|Invoice\s+Value|Invoice\s+Amount)[:\s]+([0-9]+[0-9.,]*)",
        ], text)

    def _extract_freight_usd(self, text: str) -> Optional[float]:
        return self.find_float([
            r"(?:قيمة\s+النولون\s+بالدولار|النولون\s+بالدولار|Freight\s*(?:\(USD\)|USD))[:\s]+(?:\$)?([0-9]+[0-9.,]*)",
            r"(?:قيمة\s+النولون|النولون|Freight)\s*(?:\([^)]*?(?:دولار|\$|USD)[^)]*?\))[:\s]+(?:\$)?([0-9]+[0-9.,]*)",
            r"(?:قيمة\s+النولون|النولون|Freight)[:\s]+(?:\$)?([0-9]+[0-9.,]*)\s*(?:\$|USD|دولار)",
            r"(?:قيمة\s+النولون|النولون|Freight)[:\s]+(?:\$)?([0-9]+[0-9.,]*)",
        ], text)

    def _extract_insurance_egp(self, text: str) -> Optional[float]:
        return self.find_float([
            r"(?:قيمة\s+التأمين\s+بالجنيه|التأمين\s+بالجنيه|Insurance\s*(?:\(EGP\)|EGP))[:\s]+([0-9]+[0-9.,]*)",
            r"(?:قيمة\s+التأمين|التأمين|Insurance)\s*(?:\([^)]*?(?:ج\.?م|EGP|جنيه)[^)]*?\))[:\s]+([0-9]+[0-9.,]*)",
            r"(?:قيمة\s+التأمين|التأمين|Insurance)[:\s]+([0-9]+[0-9.,]*)\s*(?:ج\.?م|EGP|جنيه)",
            r"(?:قيمة\s+التأمين|التأمين|Insurance)[:\s]+([0-9]+[0-9.,]*)",
        ], text)

    def _extract_discharge_egp(self, text: str) -> Optional[float]:
        return self.find_float([
            r"(?:مصاريف\s+التفريغ\s+بالجنيه|التفريغ\s+بالجنيه|Discharge\s*(?:\(EGP\)|EGP))[:\s]+([0-9]+[0-9.,]*)",
            r"(?:مصاريف\s+التفريغ|عوائد\s+وتفريغ|التفريغ|Discharge|Handling)\s*(?:\([^)]*?(?:ج\.?م|EGP|جنيه)[^)]*?\))[:\s]+([0-9]+[0-9.,]*)",
            r"(?:مصاريف\s+التفريغ|عوائد\s+وتفريغ|التفريغ|Discharge|Handling)[:\s]+([0-9]+[0-9.,]*)\s*(?:ج\.?م|EGP|جنيه)",
            r"(?:مصاريف\s+التفريغ|عوائد\s+وتفريغ|التفريغ|Discharge|Handling)[:\s]+([0-9]+[0-9.,]*)",
        ], text)

    def _extract_assessed_cif(self, text: str) -> Optional[float]:
        return self.find_float([
            r"(?:القيمة\s+المقر\s+عنها\s*(?:\([^)]+\))?|القيمة\s+المقر\s+عنها|القيمة\s+النهائية\s*(?:\([^)]+\))?|وعاء\s+القيمة\s+الجمركية|القيمة\s+للأغراض\s+الجمركية|وعاء\s+ضريبة\s+الوارد|القيمة\s+الجمركية\s+CIF|القيمة\s+الجمركية|Assessed\s+CIF|Assessed\s+Value)[:\s]+([0-9]+[0-9.,]*)",
            r"(?:إجمالي\s+وعاء\s+الضريبة|الوعاء\s+الجمركي)[:\s]+([0-9]+[0-9.,]*)",
        ], text)

    def _extract_hs_code(self, text: str) -> Optional[str]:
        raw_code = self.find_first([
            r"(?:كود\s+البند\s+الجمركي|بند\s+التعريفة|البند\s+الجمركي|رقم\s+البند|HS\s*Code|Tariff\s*Code)[:\s]*([0-9]{4,10}(?:\.[0-9]+)*)",
            r"(?:H\.S\.)[:\s]*([0-9]{4,10}(?:\.[0-9]+)*)",
        ], text)
        if raw_code:
            return raw_code.strip()
        # Fallback: look for 8-digit or dotted 8-digit HS pattern
        match = re.search(r"\b(\d{4}\.\d{2}\.\d{2}|\d{8})\b", text)
        if match:
            return match.group(1)
        return None

    def _extract_quantity(self, text: str) -> Optional[float]:
        return self.find_float([
            r"(?:الكمية\s*(?:\([^)]+\))?|العدد|Quantity|Qty)[:\s]+([0-9]+[0-9.,]*)",
        ], text)

    def _extract_weight(self, text: str) -> Optional[float]:
        return self.find_float([
            r"(?:الوزن\s+الإجمالي|الوزن\s+القائم|الوزن\s+الكلي|الوزن\s*(?:\(كجم\))?|الوزن|Gross\s+Weight|Weight)[:\s]+([0-9]+[0-9.,]*)",
        ], text)

    def _extract_duty_rate(self, text: str) -> Optional[float]:
        return self.find_float([
            r"(?:نسبة\s+ضريبة\s+الوارد|فئة\s+ضريبة\s+الوارد|ضريبة\s+الوارد\s*%|فئة\s+الوارد|Import\s+Duty\s*Rate|Duty\s*Rate)[:\s]+([0-9]+[0-9.,]*)\s*%?",
            r"(?:ضريبة\s+الوارد)[:\s]+([0-9]+[0-9.,]*)\s*%",
        ], text)

    # ─── Form B Financial Codes Breakdown ─────────────────────────────────────

    def _extract_financial_codes(self, text: str) -> Tuple[Dict[str, Dict[str, Any]], Dict[str, float]]:
        """
        Extracts all financial duty/tax/fee codes from Nafeza statement text.
        Returns:
            breakdown: Dict of code -> {"code": ..., "name_ar": ..., "amount": float}
            individual: Dict of "code_{c}" -> float
        """
        breakdown: Dict[str, Dict[str, Any]] = {}
        individual: Dict[str, float] = {}

        # 1. Line-by-line structured table scan
        lines = text.split("\n")
        for line in lines:
            line_clean = line.strip()
            if not line_clean:
                continue

            # Check if line matches: [Code] Name Amount or Code | Name | Amount or Code Name: Amount
            table_match = re.search(
                r"^[\s\-_*#]*\[?(\d{1,4})\]?[\s\-_:\|\t]+(.*?)(?:[:\t|]|\s{2,}|\s+)([0-9]+[0-9.,]*)\s*(?:ج\.?م|EGP|جنيه)?(?:\s*\(.*?\))?$",
                line_clean,
            )
            if table_match:
                code_str = table_match.group(1).strip()
                name_cand = re.sub(r"[\s\-_:\|\t]+$", "", table_match.group(2).strip())
                amt_str = table_match.group(3).strip().rstrip(".,")
                try:
                    amt_val = self.parse_numeric_str(amt_str)
                    if code_str in KNOWN_FINANCIAL_CODES or amt_val > 0:
                        meta = KNOWN_FINANCIAL_CODES.get(code_str, {})
                        canonical_name = meta.get("name_ar", name_cand)
                        breakdown[code_str] = {
                            "code": code_str,
                            "name_ar": canonical_name,
                            "amount": amt_val,
                        }
                        individual[f"code_{code_str}"] = amt_val
                except ValueError:
                    pass

        # 2. Match known codes specifically via regex patterns across whole text
        for code_str, meta in KNOWN_FINANCIAL_CODES.items():
            if code_str in breakdown:
                continue  # Already extracted via line scan

            kw_pattern = "|".join(re.escape(k) for k in meta["keywords"])

            # Regex A: [Code] Name: Amount
            pat_a = rf"(?:\[|\()?\s*{code_str}\s*(?:\]|\))?[\s\-_:\|\t]+(?:{kw_pattern})[\s\-_:\|\t]+([0-9]+[0-9.,]*)"
            # Regex B: Name [Code]: Amount
            pat_b = rf"(?:{kw_pattern})[\s\-_:\|\t]*(?:\[|\()?\s*{code_str}\s*(?:\]|\))?[\s\-_:\|\t]+([0-9]+[0-9.,]*)"
            # Regex C: Name: Amount (where name is unambiguous e.g. "فحص بالأشعة")
            pat_c = rf"(?:{kw_pattern})[\s\-_:\|\t]+([0-9]+[0-9.,]*)"

            val = self.find_float([pat_a, pat_b, pat_c], text)
            if val is not None:
                breakdown[code_str] = {
                    "code": code_str,
                    "name_ar": meta["name_ar"],
                    "amount": val,
                }
                individual[f"code_{code_str}"] = val

        return breakdown, individual

    def _extract_total_paid(self, text: str, individual_codes: Dict[str, float]) -> Optional[float]:
        """Extracts total amount paid in Nafeza, falling back to sum of codes if not found."""
        total = self.find_float([
            r"(?:إجمالي\s+المبلغ\s+المسدد\s+بنافذة|إجمالي\s+المسدد\s+بنافذة|المبلغ\s+المسدد\s+بنافذة|إجمالي\s+المبلغ\s+المسدد|إجمالي\s+المسدد|المبلغ\s+الإجمالي\s+المسدد|إجمالي\s+استمارة\s+الرسوم|المبلغ\s+المطلوب\s+سداده|Total\s+Paid|Total\s+Nafeza\s+Amount)[:\s]+([0-9]+[0-9.,]*)",
            r"(?:إجمالي\s+الرسوم\s+والضرائب|المبلغ\s+الإجمالي)[:\s]+([0-9]+[0-9.,]*)",
        ], text)

        if total is not None and total > 0:
            return total

        # If not explicitly stated, sum all extracted financial codes
        if individual_codes:
            calculated_sum = round(sum(individual_codes.values()), 2)
            if calculated_sum > 0:
                return calculated_sum

        return None
