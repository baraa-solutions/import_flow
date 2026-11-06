import re
from decimal import Decimal
from typing import List, Tuple, Dict, Any, Optional

from modules.customs_tariff.schemas import CustomsTariffCreate, PreferentialAgreementCreate


AGREEMENT_COUNTRY_MAPPINGS: Dict[str, Dict[str, str]] = {
    "ميركسور": {
        "canonical_name": "اتفاقية أمريكا اللاتينية الميركسور (Mercosur)",
        "origin_countries": "BR,AR,UY,PY",
        "required_document": "شهادة منشأ اتفاقية الميركسور",
    },
    "صربيا": {
        "canonical_name": "اتفاقية صربيا للتجارة الحرة",
        "origin_countries": "RS",
        "required_document": "شهادة منشأ صربية / EUR.1",
    },
    "المملكة المتحدة": {
        "canonical_name": "اتفاقية الشراكة المصرية والمملكة المتحدة (UK Partnership)",
        "origin_countries": "GB",
        "required_document": "شهادة منشأ المملكة المتحدة / EUR.1",
    },
    "الافتا": {
        "canonical_name": "اتفاقية دول الإفتا (EFTA)",
        "origin_countries": "IS,LI,NO,CH",
        "required_document": "شهادة EUR.1 / EFTA",
    },
    "تركيا": {
        "canonical_name": "اتفاقية التجارة الحرة مع تركيا (Turkey FTA)",
        "origin_countries": "TR",
        "required_document": "شهادة EUR.1",
    },
    "أوربية": {
        "canonical_name": "اتفاقية الشراكة الأوروبية (EU Partnership)",
        "origin_countries": "DE,FR,IT,ES,NL,BE,AT,SE,DK,FI,GR,PT,IE,PL,CZ,HU,RO,BG,HR,SK,SI,CY,MT,EE,LV,LT",
        "required_document": "شهادة EUR.1",
    },
    "أغادير": {
        "canonical_name": "اتفاقية الأغادير (Agadir Agreement)",
        "origin_countries": "JO,TN,MA,EG",
        "required_document": "شهادة EUR.1 / Agadir",
    },
    "العربية الكبرى": {
        "canonical_name": "منطقة التجارة الحرة العربية الكبرى (GAFTA)",
        "origin_countries": "SA,AE,KW,QA,BH,OM,JO,TN,MA,DZ,LB,SY,IQ,SD,LY,YE",
        "required_document": "شهادة منشأ جامعة الدول العربية",
    },
}


def import_duty_rates(text: str) -> List[Decimal]:
    """Every "ضريبة الوارد" rate on a Nafeza page, in page order."""
    return [
        Decimal(rate)
        for rate in re.findall(r"ضريبة\s*الوارد(?:\s*\([^)]+\))?[\s:\n]*([\d\.]+)\s*%", text)
    ]


def parse_nafeza_tariff_text(raw_text: str) -> Tuple[CustomsTariffCreate, List[PreferentialAgreementCreate]]:
    """
    محلل وصائغ النصوص الجمركية الذكي (Nafeza Smart Tariff Parser).
    يقوم بتحليل نص البند المجمع من نافذة واستخراج:
    - رقم البند (HS Code)
    - وصف البند
    - ضريبة الوارد (النظام الأساسي)
    - ضريبة القيمة المضافة
    - الاتفاقيات التفضيلية وتخفيضاتها والقرارات الوزارية والمستندات المطلوبة لكل دولة.
    """
    text = raw_text.strip()

    # 1. Extract HS Code
    hs_code_match = re.search(r"(?:رقم\s*البند|رمز\s*النظام\s*ال[مُ]?نسق|HS\s*Code)[\s:\n]*([\d\.\s]+)", text)
    if not hs_code_match:
        # Fallback regex for raw numbers
        hs_code_match = re.search(r"\b(\d{8,10})\b", text)
        if not hs_code_match:
            raise ValueError("تعذر استخراج رقم البند الجمركي (HS Code) من النص المدخل.")
    raw_hs = hs_code_match.group(1).replace(".", "").strip()
    hs_code = raw_hs

    # 2. Extract Description
    hs_desc = "بند جمركي"
    desc_match = re.search(r"(?:نص\s*البند|الوصف|Description)[\s:\n]*(.*?)(?=\n\s*(?:الضرائب|Taxes|المستندات)|$)", text, re.DOTALL | re.IGNORECASE)
    if desc_match:
        raw_d = desc_match.group(1).strip()
        if raw_d:
            hs_desc = re.sub(r"\s+", " ", raw_d)

    # 3. Extract Base Duty Rate ("النظام الأساسي" or generic)
    customs_duty_rate = Decimal("0.00")
    duty_match = re.search(r"ضريبة\s*الوارد\s*\(\s*النظام\s*الاساسي\s*\)[\s:\n]*([\d\.]+)\s*%", text)
    if duty_match:
        customs_duty_rate = Decimal(duty_match.group(1))
    else:
        # Nafeza lists the base regime first; later "ضريبة الوارد" rows belong to other regimes. Take the
        # first row (as before #200), never the highest; the parse summary flags pages with several rates.
        page_rates = import_duty_rates(text)
        if page_rates:
            customs_duty_rate = page_rates[0]

    # 4. Extract VAT Rate
    vat_rate = Decimal("14.00")
    vat_match = re.search(r"(?:ضريبة\s*قيمه\s*مضافه|ضريبة\s*القيمة\s*المضافة|ض\.ق\.م|VAT)[\s:\n]*([\d\.]+)\s*%", text, re.IGNORECASE)
    if vat_match:
        vat_rate = Decimal(vat_match.group(1))

    # 5. Extract Schedule Tax Rate (ضريبة الجدول)
    schedule_tax_rate = Decimal("0.00")
    sched_match = re.search(r"ضريبة\s*الجدول\s*:\s*([\d\.]+)\s*%", text)
    if sched_match:
        schedule_tax_rate = Decimal(sched_match.group(1))

    # 6. Extract Development Fee (رسم التنمية)
    development_fee_rate = Decimal("0.00")
    dev_match = re.search(r"رسم\s*التنمية\s*:\s*([\d\.]+)\s*%", text)
    if dev_match:
        development_fee_rate = Decimal(dev_match.group(1))

    # 7. Extract Import Fee (رسم الوارد)
    import_fee_rate = Decimal("0.00")
    imp_match = re.search(r"رسم\s*الوارد\s*:\s*([\d\.]+)\s*%", text)
    if imp_match:
        import_fee_rate = Decimal(imp_match.group(1))

    # 8. Extract Specific Preferential Rates from "الضرائب" Section (e.g. Mercosur 3%)
    specific_duty_rates: Dict[str, Decimal] = {}
    tax_section_match = re.search(r"الضرائب\s*:(.*?)(?=\n\s*المستندات|$)", text, re.DOTALL)
    if tax_section_match:
        tax_lines = tax_section_match.group(1).splitlines()
        for i, line in enumerate(tax_lines):
            line_str = line.strip()
            if "ضريبة الوارد" in line_str and "النظام الاساسي" not in line_str:
                ag_name_match = re.search(r"ضريبة\s*الوارد\s*\((.*?)\)", line_str)
                if ag_name_match:
                    name_key = ag_name_match.group(1).strip()
                    # Check next lines for rate %
                    for next_line in tax_lines[i : i + 3]:
                        rate_m = re.search(r"([\d\.]+)\s*%", next_line)
                        if rate_m:
                            specific_duty_rates[name_key] = Decimal(rate_m.group(1))
                            break

    # 9. Parse Regulatory Requirements & Decisions under "المستندات والأعمال :"
    prior_approvals_list: List[str] = []
    requires_inspection = False
    requires_coo = True
    requires_acid = True
    regulatory_authorities: List[str] = []

    has_anti_dumping_risk = False
    anti_dumping_notes_list: List[str] = []
    dumping_keywords = ["إغراق", "اغراق", "رسم الإغراق", "رسوم الإغراق", "تدابير وقائية", "التدابير الوقائية", "مكافحة الدعم", "رسوم تعويضية"]
    doc_section_match = re.search(r"(?:المستندات\s*والأعمال|الاشتراطات\s*والمستندات|المستندات)[\s:\n]*(.*)", text, re.DOTALL)
    doc_lines: List[str] = []
    if doc_section_match:
        raw_doc_lines = doc_section_match.group(1).splitlines()
        current_block = []
        for line in raw_doc_lines:
            line_str = line.strip()
            if not line_str:
                if current_block:
                    doc_lines.append(" ".join(current_block))
                    current_block = []
            elif line_str.startswith("ر") or line_str.startswith("ق") or line_str.startswith("غ"):
                if current_block:
                    doc_lines.append(" ".join(current_block))
                    current_block = []
                current_block.append(line_str)
            else:
                current_block.append(line_str)
        if current_block:
            doc_lines.append(" ".join(current_block))

    for dline_str in doc_lines:
        # Check Anti-Dumping & Safeguards (غ... or dumping keywords)
        if dline_str.startswith("غ") or any(kw in dline_str for kw in dumping_keywords):
            has_anti_dumping_risk = True
            anti_dumping_notes_list.append(dline_str)

        # Check if this is a regulatory decision / restriction (ق...)
        if dline_str.startswith("ق") or "لايصرح" in dline_str or "لايفرج" in dline_str or "يشترط" in dline_str or "لا يتم استيراد" in dline_str:
            prior_approvals_list.append(dline_str)
            requires_inspection = True

        if "هـ .ع.ص.و" in dline_str or "هـ.ع.ص.و" in dline_str or "الصادرات والواردات" in dline_str:
            if "الهيئة العامة للرقابة على الصادرات والواردات (GOEIC)" not in regulatory_authorities:
                regulatory_authorities.append("الهيئة العامة للرقابة على الصادرات والواردات (GOEIC)")
        if "البيئة" in dline_str or "الأوزون" in dline_str or "الاوزون" in dline_str:
            if "جهاز شئون البيئة (EEAA)" not in regulatory_authorities:
                regulatory_authorities.append("جهاز شئون البيئة (EEAA)")

    prior_approval_note = "\n\n".join(prior_approvals_list) if prior_approvals_list else None
    regulatory_authority = " / ".join(regulatory_authorities) if regulatory_authorities else ("الهيئة العامة للرقابة على الصادرات والواردات (GOEIC)" if requires_inspection else None)
    anti_dumping_notes = "\n".join(anti_dumping_notes_list) if anti_dumping_notes_list else None

    # Construct CustomsTariffCreate
    tariff = CustomsTariffCreate(
        hs_code=hs_code,
        hs_description=hs_desc,
        customs_category="CARPETS_TEXTILES" if ("سجاد" in hs_desc or "أرضيات" in hs_desc or "أنسجة" in hs_desc) else ("MACHINERY_EQUIPMENT" if ("آلات" in hs_desc or "أجهزة" in hs_desc or "تكييف" in hs_desc) else "GENERAL_GOODS"),
        customs_duty_rate=customs_duty_rate,
        vat_rate=vat_rate,
        schedule_tax_rate=schedule_tax_rate,
        development_fee_rate=development_fee_rate,
        import_fee_rate=import_fee_rate,
        customs_service_fee_rate=Decimal("1.00"),
        requires_coo=requires_coo,
        requires_inspection=requires_inspection,
        requires_acid=requires_acid,
        regulatory_authority=regulatory_authority,
        prior_approval_note=prior_approval_note,
        has_anti_dumping_risk=has_anti_dumping_risk,
        anti_dumping_notes=anti_dumping_notes,
        source_url="https://www.nafeza.gov.eg/ar/tariff/details/" + hs_code,
    )

    # 10. Parse Agreements & Reductions (ر...)
    agreements: List[PreferentialAgreementCreate] = []

    for dline_str in doc_lines:
        if not (dline_str.startswith("ر") or "اتفاقية" in dline_str or "تخفض" in dline_str or "يعفى" in dline_str):
            continue

        # Extract publication notice e.g. ر6722, ر6668, ر6706, ر6631, ر6607, ر6663
        notice_match = re.search(r"(ر\d{4,5})", dline_str)
        pub_notice = notice_match.group(1) if notice_match else None

        # Detect matching agreement mapping key
        matched_mapping_key = None
        matched_mapping_info = None
        for key, info in AGREEMENT_COUNTRY_MAPPINGS.items():
            if key in dline_str:
                matched_mapping_key = key
                matched_mapping_info = info
                break

        if not matched_mapping_info:
            # Generic fallback if no specific keyword matched
            matched_mapping_info = {
                "canonical_name": f"اتفاقية تفضيلية ({pub_notice or 'خاصة'})",
                "origin_countries": "OTHER",
                "required_document": "شهادة منشأ تفضيلية معتمدة",
            }

        canonical_name = matched_mapping_info["canonical_name"]
        origin_countries = matched_mapping_info["origin_countries"]
        required_document = matched_mapping_info["required_document"]

        # Determine reduction type & percentages
        reduction_type = "percentage_of_duty"
        reduction_percentage = Decimal("1.00")
        preferential_duty_rate: Optional[Decimal] = None

        # Check if specific fixed duty rate was extracted from tax section (e.g. Mercosur 3%)
        for tax_key, rate_val in specific_duty_rates.items():
            if matched_mapping_key and matched_mapping_key in tax_key:
                preferential_duty_rate = rate_val
                reduction_type = "fixed_rate"
                break

        if preferential_duty_rate is None:
            # Check for explicit percentage in line e.g. "تخفيض 10%", "بنسبة100%"
            pct_match = re.search(r"بنسبة\s*(\d+)%|تخفيض\s*(\d+)%", dline_str)
            if pct_match:
                pct_val = Decimal(pct_match.group(1) or pct_match.group(2))
                if pct_val == Decimal("100"):
                    reduction_type = "full_duty_exemption"
                    reduction_percentage = Decimal("1.00")
                    preferential_duty_rate = Decimal("0.00")
                else:
                    reduction_type = "percentage_of_duty"
                    reduction_percentage = pct_val / Decimal("100.0")
                    preferential_duty_rate = _calculate_reduced_rate(customs_duty_rate, reduction_percentage)
            elif "يعفى" in dline_str:
                reduction_type = "full_duty_exemption"
                reduction_percentage = Decimal("1.00")
                preferential_duty_rate = Decimal("0.00")

        ag_create = PreferentialAgreementCreate(
            hs_code=hs_code,
            agreement_name=canonical_name,
            reduction_type=reduction_type,
            reduction_percentage=reduction_percentage,
            preferential_duty_rate=preferential_duty_rate,
            publication_notice=pub_notice,
            required_document=required_document,
            origin_countries=origin_countries,
            conditions_note=dline_str,
        )
        agreements.append(ag_create)

    return tariff, agreements


def _calculate_reduced_rate(base_duty: Decimal, reduction_percentage: Decimal) -> Decimal:
    """Calculates reduced duty rate e.g. 40% base with 10% discount -> 36%."""
    reduced = base_duty * (Decimal("1.00") - reduction_percentage)
    return max(Decimal("0.00"), round(reduced, 2))
