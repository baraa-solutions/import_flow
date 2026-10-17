from datetime import date, datetime
from decimal import Decimal, ROUND_HALF_UP
from typing import Any, Dict, List, Optional, Set, Tuple

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.common import enum_codes
from . import repository
from .model import CustomsTariff, PreferentialAgreement
from .schemas import normalize_customs_category
from .schemas import (
    CustomsDutyBreakdown,
    CustomsDutyEstimateRequest,
    CustomsTariffCreate,
    CustomsTariffUpdate,
    MultiItemCustomsBreakdown,
    MultiItemCustomsEstimateLine,
    MultiItemCustomsEstimateRequest,
    MultiItemCustomsLineBreakdown,
    PreferentialAgreementCreate,
    PreferentialAgreementResponse,
    TariffVerificationRequest,
    ImportFileCustomsSimulationRequest,
    ImportFileCustomsSimulationResponse,
)
from .validators import (
    validate_effective_date_range,
    validate_no_duplicate_hs_code,
    validate_tariff_exists,
)


def _round(value: Any) -> Decimal:
    """Helper to round financial decimals to 2 decimal places using HALF_UP."""
    if not isinstance(value, Decimal):
        value = Decimal(str(value))
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def _agreement_duty_rate(standard_rate: Decimal, ag: Any) -> Decimal:
    """Calculate effective preferential customs duty rate.

    ag can be a PreferentialAgreement model instance or schema.
    reduction_type can be:
    - 'full_duty_exemption': 0.00%
    - 'fixed_rate': uses preferential_duty_rate (must not be None)
    - 'percentage_of_duty': standard_rate * (1 - reduction_percentage),
      reduction_percentage is in range 0..1 (default 1.00 if None)
    Raises HTTPException(422, CT_AGREEMENT_DATA_INVALID) on invalid agreement data.
    """
    red_type = getattr(ag, "reduction_type", None)
    if red_type == "full_duty_exemption":
        return Decimal("0.00")
    elif red_type == "fixed_rate":
        pref_rate = getattr(ag, "preferential_duty_rate", None)
        if pref_rate is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail={
                    "code": "CT_AGREEMENT_DATA_INVALID",
                    "message": "نسبة الضريبة التفضيلية المحددة غير مسجلة للاتفاقية ذات الفئة الثابتة.",
                    "reason": "missing preferential_duty_rate for fixed_rate agreement",
                },
            )
        return _round(Decimal(str(pref_rate)))
    elif red_type == "percentage_of_duty":
        raw_pct = getattr(ag, "reduction_percentage", None)
        pct = Decimal(str(raw_pct if raw_pct is not None else "1.00"))
        if pct > Decimal("1.00") or pct < Decimal("0.00"):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail={
                    "code": "CT_AGREEMENT_DATA_INVALID",
                    "message": f"نسبة التخفيض يجب أن تكون بين 0 و 1 (القيمة الحالية: {pct}).",
                    "reason": f"reduction_percentage out of range (0..1): {pct}",
                },
            )
        eff = _round(standard_rate * (Decimal("1.00") - pct))
        return max(Decimal("0.00"), eff)
    else:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail={
                "code": "CT_AGREEMENT_DATA_INVALID",
                "message": f"نوع التخفيض غير معروف: {red_type}.",
                "reason": f"unknown reduction_type: {red_type}",
            },
        )


# ==================================================
# Customs Tariff Services (MD-008)
# ==================================================

def create_tariff_service(db: Session, data: CustomsTariffCreate) -> CustomsTariff:
    validate_no_duplicate_hs_code(db, data.hs_code)
    validate_effective_date_range(data.effective_from, data.effective_to)
    tariff = repository.create_tariff(db, data.model_dump())
    db.commit()
    db.refresh(tariff)
    return tariff


def get_all_tariffs_service(
    db: Session,
    include_inactive: bool = False,
    search: Optional[str] = None,
    skip: int = 0,
    limit: Optional[int] = None,
) -> Tuple[List[CustomsTariff], int]:
    return repository.get_all_tariffs(
        db,
        include_inactive=include_inactive,
        search=search,
        skip=skip,
        limit=limit,
        category_values=customs_category_search_values(search),
    )


def customs_category_search_values(search: Optional[str]) -> List[str]:
    """customs_category is stored as a CUSTOMS_CATEGORY code (legacy rows keep their old label): map the
    search text through the enum labels + legacy map to every matching code and its legacy values."""
    if not search or not search.strip():
        return []
    values: List[str] = []
    for code in enum_codes.codes_matching(enum_codes.CUSTOMS_CATEGORY, search.strip()):
        for value in enum_codes.legacy_values(enum_codes.CUSTOMS_CATEGORY, code):
            if value not in values:
                values.append(value)
    return values


def get_tariff_by_id_service(db: Session, tariff_id: int) -> CustomsTariff:
    tariff = repository.get_tariff_by_id(db, tariff_id)
    if not tariff:
        raise HTTPException(status_code=404, detail="Customs Tariff record not found")
    return tariff


def get_tariff_by_hs_code_service(db: Session, hs_code: str) -> CustomsTariff:
    tariff = repository.get_tariff_by_hs_code(db, hs_code)
    if not tariff:
        raise HTTPException(status_code=404, detail=f"Customs Tariff for HS Code '{hs_code}' not found")
    return tariff


def update_tariff_service(
    db: Session, tariff_id: int, data: CustomsTariffUpdate
) -> CustomsTariff:
    tariff = repository.get_tariff_by_id(db, tariff_id)
    if not tariff:
        raise HTTPException(status_code=404, detail="Customs Tariff record not found")

    update_dict = data.model_dump(exclude_unset=True, exclude_none=True)

    if "effective_from" in update_dict or "effective_to" in update_dict:
        eff_from = update_dict.get("effective_from", tariff.effective_from)
        eff_to = update_dict.get("effective_to", tariff.effective_to)
        validate_effective_date_range(eff_from, eff_to)

    updated = repository.update_tariff(db, tariff_id, update_dict)
    db.commit()
    db.refresh(updated)
    return updated


def delete_tariff_service(db: Session, tariff_id: int) -> CustomsTariff:
    tariff = repository.get_tariff_by_id(db, tariff_id)
    if not tariff:
        raise HTTPException(status_code=404, detail="Customs Tariff record not found")
    toggled = repository.toggle_tariff_active(db, tariff_id, is_active=False)
    db.commit()
    db.refresh(toggled)
    return toggled


def restore_tariff_service(db: Session, tariff_id: int) -> CustomsTariff:
    tariff = repository.get_tariff_by_id(db, tariff_id)
    if not tariff:
        raise HTTPException(status_code=404, detail="Customs Tariff record not found")
    toggled = repository.toggle_tariff_active(db, tariff_id, is_active=True)
    db.commit()
    db.refresh(toggled)
    return toggled


def verify_and_update_tariff_service(
    db: Session, hs_code: str, request: TariffVerificationRequest
) -> CustomsTariff:
    """
    مراجعة وتحديث البند الجمركي يدوياً (Addendum 3 Workflow):
    1. البحث عن البند الجمركي الفعّال حالياً.
    2. في حالة تغيير أي من نسب الضرائب (customs_duty_rate, vat_rate, schedule_tax_rate, ...):
       يتم أتمتة السلسلة التاريخية بإغلاق السجل الحالي اليوم وإنشاء سجل جديد بتاريخ بداية اليوم.
    3. في حالة مراجعة البيانات فقط بدون تغيير في النسب:
       يتم تحديث بيانات التوثيق (source_url, last_verified_date, verified_by, confidence, prior_approval_note) على السجل الحالي مباشرة.
    """
    tariff = repository.get_tariff_by_hs_code(db, hs_code)
    if not tariff:
        raise HTTPException(status_code=404, detail=f"Customs Tariff for HS Code '{hs_code}' not found")

    update_data = request.model_dump(exclude_unset=True, exclude_none=True)
    today = date.today()

    # Check if rate values have changed
    has_rate_change = False
    rate_fields = ["customs_duty_rate", "vat_rate", "schedule_tax_rate", "development_fee_rate", "import_fee_rate"]
    for field in rate_fields:
        if field in update_data:
            current_val = getattr(tariff, field)
            new_val = update_data[field]
            if Decimal(str(current_val)) != Decimal(str(new_val)):
                has_rate_change = True
                break

    if has_rate_change:
        result = repository.archive_and_create_new_tariff_version(db, tariff, update_data, effective_date=today)
    else:
        update_data["last_verified_date"] = today
        result = repository.update_tariff(db, tariff.tariff_id, update_data)
    db.commit()
    db.refresh(result)
    return result


def create_preferential_agreement_service(
    db: Session, request: PreferentialAgreementCreate
) -> PreferentialAgreement:
    agreement = repository.create_preferential_agreement(db, request.model_dump())
    db.commit()
    db.refresh(agreement)
    return agreement


def get_agreements_by_hs_code_service(
    db: Session, hs_code: str, origin_country: Optional[str] = None
) -> List[PreferentialAgreement]:
    return repository.get_agreements_by_hs_code(db, hs_code, origin_country)


# ==================================================
# Egyptian Customs Duty Calculation Engine (7.2)
# ==================================================

def estimate_customs_duty_service(
    db: Session, request: CustomsDutyEstimateRequest
) -> CustomsDutyBreakdown:
    """
    محرك الحساب الجمركي المصري للبند المنفرد (Single Item Customs Engine)
    """
    on_date = request.estimate_date or date.today()
    tariff = repository.get_active_tariff_on_date(db, request.hs_code, on_date, strict=True)

    if not tariff:
        raise HTTPException(
            status_code=422,
            detail=(
                f"لا يوجد بند تعريفة فعّال لكود {request.hs_code} بتاريخ {on_date}. "
                "لا يمكن إكمال الحساب بنسبة افتراضية — أضف البند لجدول customs_tariffs أولاً."
            ),
        )

    cif = request.cif_value
    freight = request.freight

    # Convert numeric fields to Decimal safely
    standard_duty_rate = Decimal(str(tariff.customs_duty_rate))
    vat_rate = Decimal(str(tariff.vat_rate))
    schedule_rate = Decimal(str(tariff.schedule_tax_rate))
    dev_rate = Decimal(str(tariff.development_fee_rate))
    import_fee_rate = Decimal(str(tariff.import_fee_rate))
    svc_fee_rate = Decimal(str(tariff.customs_service_fee_rate if tariff.customs_service_fee_rate is not None else "1.00"))

    # Trade Agreements Preferential Tariff Check (DB ONLY)
    effective_duty_rate = standard_duty_rate
    trade_agreement_name = None
    conditions_note = None
    if request.origin_country:
        origin_clean = request.origin_country.upper()
        db_agreements = repository.get_agreements_by_hs_code(db, request.hs_code, origin_clean, on_date=on_date)
        if db_agreements:
            ag_db = db_agreements[0]
            trade_agreement_name = ag_db.agreement_name
            conditions_note = ag_db.conditions_note
            effective_duty_rate = _agreement_duty_rate(standard_duty_rate, ag_db)

    # Calculation Steps
    import_duty_amount = _round(cif * (effective_duty_rate / Decimal("100")))
    schedule_tax_amount = _round(cif * (schedule_rate / Decimal("100")))
    development_fee_amount = _round(cif * (dev_rate / Decimal("100")))
    import_fee_amount = _round(cif * (import_fee_rate / Decimal("100")))
    customs_service_fee_amount = _round(cif * (svc_fee_rate / Decimal("100")))

    # Unified VAT Base equation: CIF Base + Actual Import Duty Amount
    vat_base = cif + import_duty_amount
    vat_amount = _round(vat_base * (vat_rate / Decimal("100")))

    total_taxes = (
        import_duty_amount
        + vat_amount
        + schedule_tax_amount
        + development_fee_amount
        + import_fee_amount
        + customs_service_fee_amount
    )

    return CustomsDutyBreakdown(
        hs_code=tariff.hs_code,
        hs_description=tariff.hs_description,
        customs_category=tariff.customs_category,
        estimate_date=on_date,
        origin_country=request.origin_country,
        cif_value=cif,
        freight=freight,
        packaging_egp=request.packaging_egp or Decimal("0.00"),
        customs_duty_rate=effective_duty_rate,
        vat_rate=vat_rate,
        schedule_tax_rate=schedule_rate,
        development_fee_rate=dev_rate,
        import_fee_rate=import_fee_rate,
        customs_service_fee_rate=svc_fee_rate,
        import_duty_amount=import_duty_amount,
        vat_base=vat_base,
        vat_amount=vat_amount,
        schedule_tax_amount=schedule_tax_amount,
        development_fee_amount=development_fee_amount,
        import_fee_amount=import_fee_amount,
        customs_service_fee_amount=customs_service_fee_amount,
        total_taxes_and_fees=total_taxes,
        trade_agreement_applied=trade_agreement_name,
        conditions_note=conditions_note,
        requires_coo=tariff.requires_coo,
        requires_inspection=tariff.requires_inspection,
        requires_acid=tariff.requires_acid,
        regulatory_authority=tariff.regulatory_authority,
    )



# ==================================================
# Bulk Import & Template Generator (MD-008 Excel/CSV)
# ==================================================

import csv
import io

def bulk_import_tariffs_service(db: Session, file_contents: bytes, filename: str) -> dict:
    """
    Bulk import or update Egyptian Customs Tariffs from CSV/Excel file.
    """
    try:
        text_content = file_contents.decode("utf-8-sig")
    except Exception:
        try:
            text_content = file_contents.decode("latin-1")
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Invalid file encoding: {str(e)}")

    reader = csv.DictReader(io.StringIO(text_content))
    if not reader.fieldnames:
        raise HTTPException(status_code=400, detail="CSV/Excel file is empty or invalid format")

    field_map = {}
    for name in reader.fieldnames:
        clean = name.strip().lower()
        if clean in ("hs_code", "hscode", "code", "كود البند"):
            field_map["hs_code"] = name
        elif clean in ("hs_description", "description", "name", "الوصف"):
            field_map["hs_description"] = name
        elif clean in ("customs_category", "category", "التصنيف"):
            field_map["customs_category"] = name
        elif clean in ("customs_duty_rate", "duty", "duty%", "duty_rate", "ضريبة الوارد"):
            field_map["customs_duty_rate"] = name
        elif clean in ("vat_rate", "vat", "vat%", "ضريبة القيمة المضافة"):
            field_map["vat_rate"] = name
        elif clean in ("schedule_tax_rate", "schedule_tax", "ضريبة الجدول"):
            field_map["schedule_tax_rate"] = name
        elif clean in ("development_fee_rate", "dev_fee", "development_fee", "رسم التنمية"):
            field_map["development_fee_rate"] = name
        elif clean in ("import_fee_rate", "import_fee", "رسم الوارد"):
            field_map["import_fee_rate"] = name
        elif clean in ("regulatory_authority", "authority", "الجهة الرقابية"):
            field_map["regulatory_authority"] = name
        elif clean in ("requires_coo", "coo"):
            field_map["requires_coo"] = name
        elif clean in ("requires_inspection", "inspection", "insp"):
            field_map["requires_inspection"] = name
        elif clean in ("requires_acid", "acid"):
            field_map["requires_acid"] = name
        elif clean in ("notes", "ملاحظات"):
            field_map["notes"] = name

    if "hs_code" not in field_map or "hs_description" not in field_map:
        raise HTTPException(
            status_code=400,
            detail="File must contain 'hs_code' (or 'hscode') and 'hs_description' (or 'description') columns.",
        )

    imported_count = 0
    updated_count = 0
    errors = []

    for row_idx, row in enumerate(reader, start=2):
        try:
            hs_code_val = row.get(field_map["hs_code"], "").strip()
            if not hs_code_val:
                continue

            desc_val = row.get(field_map["hs_description"], "").strip() or f"HS Code {hs_code_val}"
            category_val = normalize_customs_category(row.get(field_map.get("customs_category", ""), "")) or "GENERAL_GOODS"

            duty_val = _parse_decimal(row.get(field_map.get("customs_duty_rate", ""), "0"))
            vat_val = _parse_decimal(row.get(field_map.get("vat_rate", ""), "0"))
            sched_val = _parse_decimal(row.get(field_map.get("schedule_tax_rate", ""), "0"))
            dev_val = _parse_decimal(row.get(field_map.get("development_fee_rate", ""), "0"))
            imp_fee_val = _parse_decimal(row.get(field_map.get("import_fee_rate", ""), "0"))
            svc_fee_val = _parse_decimal(row.get(field_map.get("customs_service_fee_rate", ""), "1.00"))

            auth_val = row.get(field_map.get("regulatory_authority", ""), "").strip() or None
            coo_val = str(row.get(field_map.get("requires_coo", ""), "true")).strip().lower() in ("true", "1", "yes", "نعم")
            insp_val = str(row.get(field_map.get("requires_inspection", ""), "true")).strip().lower() in ("true", "1", "yes", "نعم")
            acid_val = str(row.get(field_map.get("requires_acid", ""), "true")).strip().lower() in ("true", "1", "yes", "نعم")
            notes_val = row.get(field_map.get("notes", ""), "").strip() or None

            existing = repository.get_tariff_by_hs_code(db, hs_code_val)
            data_dict = {
                "hs_code": hs_code_val,
                "hs_description": desc_val,
                "customs_category": category_val,
                "customs_duty_rate": duty_val,
                "vat_rate": vat_val,
                "schedule_tax_rate": sched_val,
                "development_fee_rate": dev_val,
                "import_fee_rate": imp_fee_val,
                "customs_service_fee_rate": svc_fee_val,
                "regulatory_authority": auth_val,
                "requires_coo": coo_val,
                "requires_inspection": insp_val,
                "requires_acid": acid_val,
                "notes": notes_val,
                "is_active": True,
            }

            if existing:
                repository.update_tariff(db, existing.tariff_id, data_dict)
                updated_count += 1
            else:
                repository.create_tariff(db, data_dict)
                imported_count += 1
        except Exception as e:
            errors.append(f"Row {row_idx}: {str(e)}")

    if imported_count > 0 or updated_count > 0:
        db.commit()

    return {
        "imported": imported_count,
        "updated": updated_count,
        "total_processed": imported_count + updated_count,
        "errors": errors,
    }


# ==================================================
# Technical Addendum Lookup Registries & Engine Functions
# ==================================================

EXEMPTIONS_REGISTRY: Dict[str, dict] = {
    "INV-LAW-EXEMPT-01": {
        "exemption_code": "INV-LAW-EXEMPT-01",
        "applies_to": ["duty"],
        "exemption_type": "full",
        "exemption_percentage": None,
        "legal_basis": "قانون الاستثمار رقم 72 لسنة 2017 - إعفاء من ضريبة الوارد",
    },
    "FREEZONE-EXEMPT-02": {
        "exemption_code": "FREEZONE-EXEMPT-02",
        "applies_to": ["duty", "schedule_tax", "vat"],
        "exemption_type": "full",
        "exemption_percentage": None,
        "legal_basis": "إعفاء المناطق حرة - شامل لكافة الضرائب والرسوم الجمركية",
    },
    "DIPLO-EXEMPT-03": {
        "exemption_code": "DIPLO-EXEMPT-03",
        "applies_to": ["duty", "schedule_tax", "vat"],
        "exemption_type": "full",
        "exemption_percentage": None,
        "legal_basis": "إعفاء الهيئات الدبلوماسية والقنصلية",
    },
    "PARTIAL-50-EXEMPT": {
        "exemption_code": "PARTIAL-50-EXEMPT",
        "applies_to": ["duty"],
        "exemption_type": "percentage",
        "exemption_percentage": Decimal("0.50"),
        "legal_basis": "إعفاء جزئي بنسبة 50% من ضريبة الوارد",
    },
}


def _parse_decimal(raw: str, default: str = "0.00") -> Decimal:
    """Helper to safely parse string/numeric inputs into Decimal without binary float rounding errors."""
    try:
        val = str(raw).strip()
        if not val:
            return Decimal(default)
        return Decimal(val)
    except Exception:
        return Decimal(default)


def resolve_insurance_freight(
    invoice_total_value_fc: Decimal,
    exchange_rate: Decimal,
    actual_insurance_egp: Decimal,
    actual_freight_egp: Decimal,
    has_insurance_document: bool,
    has_freight_document: bool,
    deemed_insurance_rate: Decimal = Decimal("0.025"),
    deemed_freight_rate: Decimal = Decimal("0.020"),
    freight_currency: str = "EGP",
    freight_foreign_amount: Decimal = Decimal("0.00"),
    freight_exchange_rate: Optional[Decimal] = None,
    packaging_egp: Decimal = Decimal("0.00"),
) -> Tuple[Decimal, Decimal, str, str, Decimal]:
    """
    حساب وتأكيد قيم التأمين والنولون الفعلي أو الحكمي (Statutory / Deemed Costs)
    يدعم تحويل النولون الفعلي بالعملة الأجنبية باستخدام معامل تحويل النولون الفعلي أو سعر الصرف الأساسي
    """
    fob_value_egp = _round((invoice_total_value_fc * exchange_rate) + packaging_egp)

    # Resolution of Insurance
    if has_insurance_document and actual_insurance_egp > Decimal("0.00"):
        resolved_insurance = actual_insurance_egp
        insurance_source = "actual"
    else:
        resolved_insurance = _round(fob_value_egp * deemed_insurance_rate)
        insurance_source = "deemed"

    # Resolution of Freight (support foreign currency freight & specific freight exchange rate)
    effective_actual_freight_egp = actual_freight_egp
    if freight_currency and freight_currency.upper() != "EGP" and freight_foreign_amount > Decimal("0.00"):
        frt_rate = freight_exchange_rate if (freight_exchange_rate and freight_exchange_rate > Decimal("0.00")) else Decimal("0.00")
        effective_actual_freight_egp = _round(freight_foreign_amount * frt_rate)

    if has_freight_document and effective_actual_freight_egp > Decimal("0.00"):
        resolved_freight = effective_actual_freight_egp
        freight_source = "actual"
    else:
        resolved_freight = _round(fob_value_egp * deemed_freight_rate)
        freight_source = "deemed"

    return resolved_insurance, resolved_freight, insurance_source, freight_source, fob_value_egp


def apply_exemption(cif_line_egp: Decimal, exemption: Optional[dict], tax_type: str) -> Tuple[Decimal, Optional[str]]:
    """
    تطبيق الإعفاء الجمركي على الوعاء الضريبي (Base) قبل ضربه في النسبة
    """
    if not exemption or tax_type not in exemption.get("applies_to", []):
        return cif_line_egp, None

    ex_type = exemption.get("exemption_type")
    legal_basis = exemption.get("legal_basis", "إعفاء جمركي قانوني")

    if ex_type == "full":
        return Decimal("0.00"), f"إعفاء كامل شامل ({legal_basis})"
    elif ex_type == "percentage":
        pct = exemption.get("exemption_percentage") or Decimal("0.00")
        taxable_base = _round(cif_line_egp * (Decimal("1.00") - pct))
        pct_display = int(pct * Decimal("100"))
        return taxable_base, f"إعفاء جزئي بنسبة {pct_display}% ({legal_basis})"

    return cif_line_egp, None


def calc_collection_fees(
    fee_codes: List[repository.FeeCode],
    duty_amount: Decimal,
    service_fee_amount: Decimal,
    vat_amount: Decimal,
) -> dict:
    """
    حساب تفاصيل الرسوم والإقرارات الرسمية نافذة (Fee Codes Collection Engine)
    """
    computed: dict = {}
    itemized: List[dict] = []
    reference_map = {
        "duty_amount": duty_amount,
        "service_fee_amount": service_fee_amount,
        "vat_amount": vat_amount,
    }

    # Stage 1: Flat & Reference Fee Codes
    for fc in fee_codes:
        if fc.calculation_type == "flat":
            computed[fc.code] = Decimal(str(fc.flat_amount or 0))
        elif fc.calculation_type == "reference":
            computed[fc.code] = reference_map.get(fc.reference_source, Decimal("0.00"))

    # Stage 2: Derived Fee Codes (depends on stage 1 codes)
    for fc in fee_codes:
        if fc.calculation_type == "derived" and fc.derived_formula_base_codes:
            base_codes = [c.strip() for c in fc.derived_formula_base_codes.split(",")]
            base_sum = sum(computed.get(c, Decimal("0.00")) for c in base_codes)
            computed[fc.code] = _round(base_sum * (Decimal(str(fc.derived_formula_rate or 0)) / Decimal("100")))

    groups: dict = {}
    group_items: dict = {}
    for fc in fee_codes:
        group_name = fc.collection_group
        val = computed.get(fc.code, Decimal("0.00"))
        groups.setdefault(group_name, Decimal("0.00"))
        groups[group_name] += val

        item_info = {
            "code": fc.code,
            "name_ar": fc.name_ar,
            "collection_group": fc.collection_group,
            "calculation_type": fc.calculation_type,
            "calculated_amount": float(val),
        }
        itemized.append(item_info)
        group_items.setdefault(group_name, []).append(item_info)

    total_sum = sum(groups.values())
    return {
        "by_code": {k: float(v) for k, v in computed.items()},
        "by_group": {k: float(v) for k, v in groups.items()},
        "itemized_fees": itemized,
        "group_items": {k: v for k, v in group_items.items()},
        "grand_total": float(total_sum),
    }


def _customs_rate(
    db: Session, currency: str, on_date: Optional[date] = None
) -> Tuple[Decimal, Optional[date], Optional[int]]:
    """Resolves the official Egyptian customs exchange rate for a given currency on a target date.

    Returns (rate as Decimal, effective_date, rate_id).
    Raises HTTPException 422 with code CT_CUSTOMS_RATE_MISSING if no rate is registered or currency is unknown.
    """
    code = (currency or "").upper().strip()
    ref_date = on_date or date.today()
    if code == "EGP":
        return Decimal("1.0"), ref_date, None

    from modules.currencies.service import CurrencyService

    c_service = CurrencyService(db)
    try:
        r_val, r_date, r_id = c_service._get_rate_to_egp(code, rate_type="customs", as_of_date=ref_date)
    except HTTPException:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail={
                "code": "CT_CUSTOMS_RATE_MISSING",
                "message": f"لا يوجد سعر صرف جمركي مسجل للعملة {code} بتاريخ {ref_date}.",
                "currency": code,
                "on_date": ref_date.isoformat() if isinstance(ref_date, (date, datetime)) else str(ref_date),
            },
        )
    if r_id is None or r_val is None or r_val <= 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail={
                "code": "CT_CUSTOMS_RATE_MISSING",
                "message": f"لا يوجد سعر صرف جمركي مسجل للعملة {code} بتاريخ {ref_date}.",
                "currency": code,
                "on_date": ref_date.isoformat() if isinstance(ref_date, (date, datetime)) else str(ref_date),
            },
        )
    return Decimal(str(r_val)), r_date, r_id


# ==================================================
# Multi-Item Egyptian Customs Engine (Nafeza Statement Engine)
# ==================================================

def estimate_multi_item_customs_duty_service(
    db: Session, request: MultiItemCustomsEstimateRequest
) -> MultiItemCustomsBreakdown:
    """
    محرك الحساب الجمركي المصري لشحنة متعددة الأصناف (Multi-HS Code Customs Engine)
    يتوافق 100% مع النموذج الرسمي لقوائم التحصيل والشهادات الجمركية بمنصة نافذة.
    """
    on_date = request.estimate_date or date.today()
    if not request.lines:
        raise HTTPException(status_code=400, detail="At least one line item is required")

    invoice_total_value_fc = sum(line.value_fc for line in request.lines)
    if invoice_total_value_fc <= Decimal("0.00"):
        raise HTTPException(status_code=400, detail="Total invoice value must be greater than 0")

    # Resolve Customs Exchange Rate Snapshot (Historical / Effective-Dated Pricing)
    rate_date = on_date
    rate_id = None
    if request.exchange_rate is not None and request.exchange_rate > Decimal("0.00"):
        effective_exchange_rate = request.exchange_rate
    else:
        effective_exchange_rate, rate_date, rate_id = _customs_rate(db, request.currency, on_date)
    # Step 0: Resolve Freight Rate & Source (ACC1-T01)
    freight_curr = (request.freight_currency or "EGP").strip().upper()
    freight_foreign_amt = request.freight_foreign_amount or Decimal("0.00")
    freight_rate_used: Optional[Decimal] = None
    freight_rate_source: Optional[str] = None

    if request.has_freight_document and freight_curr != "EGP" and freight_foreign_amt > Decimal("0.00"):
        if freight_curr == (request.currency or "").strip().upper():
            freight_rate_used = effective_exchange_rate
            freight_rate_source = "invoice_currency"
        elif request.freight_exchange_rate is not None and request.freight_exchange_rate > Decimal("0.00"):
            freight_rate_used = request.freight_exchange_rate
            freight_rate_source = "manual"
        else:
            freight_rate_used, _, _ = _customs_rate(db, freight_curr, on_date)
            freight_rate_source = "table"

    # Step 1: Resolve Insurance & Freight (Actual vs Statutory/Deemed)
    (
        resolved_insurance_egp,
        resolved_freight_egp,
        insurance_source,
        freight_source,
        fob_value_egp,
    ) = resolve_insurance_freight(
        invoice_total_value_fc=invoice_total_value_fc,
        exchange_rate=effective_exchange_rate,
        actual_insurance_egp=request.insurance_egp,
        actual_freight_egp=request.freight_egp,
        has_insurance_document=request.has_insurance_document,
        has_freight_document=request.has_freight_document,
        deemed_insurance_rate=request.deemed_insurance_rate,
        deemed_freight_rate=request.deemed_freight_rate,
        freight_currency=freight_curr,
        freight_foreign_amount=freight_foreign_amt,
        freight_exchange_rate=freight_rate_used,
        packaging_egp=request.packaging_egp or Decimal("0.00"),
    )

    if freight_source == "deemed" or freight_curr == "EGP" or freight_foreign_amt <= Decimal("0.00"):
        freight_rate_source = None
        freight_rate_used = None

    total_insurance_freight_packaging_egp = resolved_insurance_egp + resolved_freight_egp + request.packaging_egp

    line_breakdowns: List[MultiItemCustomsLineBreakdown] = []
    total_duty_egp = Decimal("0.00")
    total_schedule_tax_egp = Decimal("0.00")
    total_vat_egp = Decimal("0.00")
    total_customs_service_fee_egp = Decimal("0.00")
    total_development_fee_egp = Decimal("0.00")
    total_import_fee_egp = Decimal("0.00")
    total_inspection_fees_egp = Decimal("0.00")

    for line in request.lines:
        # Strict Tariff Lookup — FAIL LOUDLY if HS Code is not in DB on date (Issue #1)
        tariff = repository.get_active_tariff_on_date(db, line.hs_code, on_date, strict=True)
        if not tariff:
            raise HTTPException(
                status_code=422,
                detail=(
                    f"لا يوجد بند تعريفة فعّال لكود {line.hs_code} بتاريخ {on_date}. "
                    "لا يمكن إكمال الحساب بنسبة افتراضية — أضف البند لجدول customs_tariffs أولاً."
                ),
            )

        standard_duty_rate = Decimal(str(tariff.customs_duty_rate))
        vat_rate = Decimal(str(request.vat_rate_override or tariff.vat_rate))
        sched_rate = Decimal(str(tariff.schedule_tax_rate))
        dev_rate = Decimal(str(tariff.development_fee_rate))
        imp_fee_rate = Decimal(str(tariff.import_fee_rate))
        svc_fee_rate = Decimal(str(tariff.customs_service_fee_rate if tariff.customs_service_fee_rate is not None else "1.00"))

        # Step 2: Trade Agreements Preferential Tariff Check (DB ONLY - Issue #2)
        duty_rate = standard_duty_rate
        trade_agreement_name = None
        conditions_note = None
        is_exemption_applied = False

        if line.is_exemption_conditions_met is True:
            # Explicit user activation of exemption / conditions met checklist
            duty_rate = Decimal("0.00")
            is_exemption_applied = True
            trade_agreement_name = "معفى بموجب اتفاقية / استيفاء الشروط"
        elif line.is_exemption_conditions_met is False:
            # Explicit user deactivation: standard duty rate must be strictly applied
            duty_rate = standard_duty_rate
            is_exemption_applied = False
            trade_agreement_name = "خاضع للفئة القياسية (لم يتم استيفاء شروط الإعفاء)"
        elif line.origin_country:
            origin_clean = line.origin_country.upper()
            db_agreements = repository.get_agreements_by_hs_code(db, line.hs_code, origin_clean, on_date=on_date)
            if db_agreements:
                ag_db = db_agreements[0]
                trade_agreement_name = ag_db.agreement_name
                conditions_note = ag_db.conditions_note
                duty_rate = _agreement_duty_rate(standard_duty_rate, ag_db)
                is_exemption_applied = (duty_rate == Decimal("0.00"))

        schedule_tax_base = "cif"

        requires_coo = tariff.requires_coo
        requires_inspection = tariff.requires_inspection
        requires_acid = tariff.requires_acid
        regulatory_authority = tariff.regulatory_authority
        hs_description = tariff.hs_description
        customs_category = tariff.customs_category

        value_share = line.value_fc / invoice_total_value_fc
        allocated_ins_freight = total_insurance_freight_packaging_egp * value_share

        line_taxable_fc = line.value_fc - line.exempted_value_fc - line.value_without_payment_fc
        if request.cif_declared_total_egp and request.cif_declared_total_egp > Decimal("0.00"):
            cif_line_egp = _round(request.cif_declared_total_egp * value_share)
        else:
            cif_line_egp = _round((line_taxable_fc * effective_exchange_rate) + allocated_ins_freight)

        # Step 3: Resolve Exemptions for Line
        exemption_code_to_apply = line.exemption_code or request.exemption_code
        exemption_info = EXEMPTIONS_REGISTRY.get(exemption_code_to_apply) if exemption_code_to_apply else None
        exemption_details = None

        # Apply Duty Exemption on Base ONLY for Import Duty
        duty_taxable_base_egp, ex_det_duty = apply_exemption(cif_line_egp, exemption_info, "duty")
        if ex_det_duty:
            exemption_details = ex_det_duty

        duty_line_egp = _round(duty_taxable_base_egp * (duty_rate / Decimal("100")))

        # Schedule Tax Exemption (does NOT get exempted by trade agreements!)
        schedule_taxable_base_egp, _ = apply_exemption(cif_line_egp, exemption_info, "schedule_tax")
        schedule_tax_line_egp = _round(schedule_taxable_base_egp * (sched_rate / Decimal("100")))

        # Customs Service Fee (أ.ت.ص 1%) — Calculated ALWAYS on full CIF value, NEVER exempted by duty agreements! (Issue #3)
        customs_service_fee_line_egp = _round(cif_line_egp * (svc_fee_rate / Decimal("100")))

        # Development & Import Fees
        development_fee_line_egp = _round(cif_line_egp * (dev_rate / Decimal("100")))
        import_fee_line_egp = _round(cif_line_egp * (imp_fee_rate / Decimal("100")))

        # Unified VAT Base Equation: CIF Line EGP + Actual Import Duty EGP (Issue #4)
        vat_taxable_base_egp, _ = apply_exemption(cif_line_egp, exemption_info, "vat")
        vat_base_egp = vat_taxable_base_egp + duty_line_egp
        vat_line_egp = _round(vat_base_egp * (vat_rate / Decimal("100")))

        inspection_fee_line_egp = _round(line.inspection_fee_egp)

        total_duty_egp += duty_line_egp
        total_schedule_tax_egp += schedule_tax_line_egp
        total_vat_egp += vat_line_egp
        total_customs_service_fee_egp += customs_service_fee_line_egp
        total_development_fee_egp += development_fee_line_egp
        total_import_fee_egp += import_fee_line_egp
        total_inspection_fees_egp += inspection_fee_line_egp

        line_breakdowns.append(
            MultiItemCustomsLineBreakdown(
                line_no=line.line_no,
                hs_code=line.hs_code,
                hs_description=hs_description,
                customs_category=customs_category,
                origin_country=line.origin_country,
                value_fc=line.value_fc,
                value_share=_round(value_share * Decimal("100")),
                allocated_insurance_freight_egp=_round(allocated_ins_freight),
                cif_value_egp=cif_line_egp,
                duty_taxable_base_egp=duty_taxable_base_egp,
                schedule_taxable_base_egp=schedule_taxable_base_egp,
                vat_taxable_base_egp=vat_taxable_base_egp,
                customs_duty_rate=duty_rate,
                duty_egp=duty_line_egp,
                schedule_tax_rate=sched_rate,
                schedule_tax_base=schedule_tax_base,
                schedule_tax_egp=schedule_tax_line_egp,
                vat_rate=vat_rate,
                vat_base_egp=vat_base_egp,
                vat_egp=vat_line_egp,
                development_fee_rate=dev_rate,
                development_fee_egp=development_fee_line_egp,
                import_fee_rate=imp_fee_rate,
                import_fee_egp=import_fee_line_egp,
                customs_service_fee_rate=svc_fee_rate,
                customs_service_fee_egp=customs_service_fee_line_egp,
                inspection_fee_egp=inspection_fee_line_egp,
                insurance_source=insurance_source,
                freight_source=freight_source,
                exemption_code_applied=exemption_code_to_apply if exemption_info else None,
                exemption_applied_details=exemption_details,
                is_exemption_applied=is_exemption_applied,
                preferential_agreement_applied=trade_agreement_name,
                conditions_note=conditions_note,
                requires_coo=requires_coo,
                requires_inspection=requires_inspection,
                requires_acid=requires_acid,
                regulatory_authority=regulatory_authority,
            )
        )

    # Compute Fee Codes Collection Breakdown (Issue #10)
    active_fee_codes = repository.get_active_fee_codes(db, on_date)
    fee_codes_result = calc_collection_fees(
        fee_codes=active_fee_codes,
        duty_amount=total_duty_egp,
        service_fee_amount=total_customs_service_fee_egp,
        vat_amount=total_vat_egp,
    )

    # Extra Nafeza administrative & non-tax fees (Fee Codes Total minus taxes already in items_taxes_total_egp)
    nafeza_fee_codes_grand_total = Decimal(str(fee_codes_result["grand_total"]))
    taxes_in_fee_codes = total_duty_egp + total_vat_egp + total_customs_service_fee_egp + total_schedule_tax_egp
    extra_nafeza_fees = _round(nafeza_fee_codes_grand_total - taxes_in_fee_codes)
    if extra_nafeza_fees < Decimal("0.00"):
        extra_nafeza_fees = Decimal("0.00")

    additional_fees_total_egp = (
        request.additional_fees_egp
        if request.additional_fees_egp > Decimal("0.00")
        else extra_nafeza_fees
    )

    items_taxes_total_egp = (
        total_duty_egp
        + total_schedule_tax_egp
        + total_customs_service_fee_egp
        + total_vat_egp
        + total_development_fee_egp
        + total_import_fee_egp
        + total_inspection_fees_egp
    )
    grand_total_payable_egp = items_taxes_total_egp + _round(additional_fees_total_egp)

    return MultiItemCustomsBreakdown(
        currency=request.currency,
        exchange_rate=effective_exchange_rate,
        rate_date=rate_date,
        exchange_rate_id=rate_id,
        invoice_total_value_fc=invoice_total_value_fc,
        fob_value_egp=fob_value_egp,
        insurance_egp=resolved_insurance_egp,
        freight_egp=resolved_freight_egp,
        packaging_egp=request.packaging_egp,
        insurance_source=insurance_source,
        freight_source=freight_source,
        freight_exchange_rate_used=freight_rate_used,
        freight_rate_source=freight_rate_source,
        additional_fees_egp=additional_fees_total_egp,
        estimate_date=on_date,
        lines=line_breakdowns,
        total_duty_egp=total_duty_egp,
        total_schedule_tax_egp=total_schedule_tax_egp,
        total_vat_egp=total_vat_egp,
        total_customs_service_fee_egp=total_customs_service_fee_egp,
        total_development_fee_egp=total_development_fee_egp,
        total_import_fee_egp=total_import_fee_egp,
        total_inspection_fees_egp=total_inspection_fees_egp,
        items_taxes_total_egp=items_taxes_total_egp,
        grand_total_payable_egp=grand_total_payable_egp,
        fee_codes_breakdown=fee_codes_result,
    )


# ==================================================
# Fee Code Services
# ==================================================

from .schemas import FeeCodeCreate


def get_all_fee_codes_service(
    db: Session, include_inactive: bool = False
) -> List[repository.FeeCode]:
    return repository.get_all_fee_codes(db, include_inactive=include_inactive)


def create_fee_code_service(
    db: Session, request: FeeCodeCreate
) -> repository.FeeCode:
    existing = repository.get_fee_code_by_code(db, request.code)
    if existing:
        raise HTTPException(
            status_code=409,
            detail="CT_FEE_CODE_DUPLICATE: A fee code with this code already exists",
        )
    fc = repository.create_fee_code(db, request.model_dump())
    db.commit()
    db.refresh(fc)
    return fc


# ==================================================
# Smart Nafeza Text Parser & Agreement Duty Engine Services
# ==================================================

from modules.customs_tariff.nafeza_text_parser import parse_nafeza_tariff_text
from modules.customs_tariff.schemas import (
    SmartTariffParseResponse,
    TariffAgreementBulkSaveRequest,
    OriginDutyCheckRequest,
    OriginDutyCheckResponse,
    PreferentialAgreementResponse,
    CustomsTariffResponse,
    TariffDiffItem,
    TariffVersionComparisonResponse,
)


def compare_tariff_versions_service(
    db: Session,
    hs_code: str,
    new_tariff_data: dict,
    new_agreements: List[dict]
) -> TariffVersionComparisonResponse:
    """Service to compare new tariff/agreements data against existing active version for the HS Code."""
    existing_active = repository.get_tariff_by_hs_code(db, hs_code)
    if not existing_active:
        return TariffVersionComparisonResponse(
            hs_code=hs_code,
            has_previous_version=False,
            previous_effective_from=None,
            previous_effective_to=None,
            new_effective_from=date.today(),
            added_count=len(new_agreements),
            removed_count=0,
            modified_count=0,
            unchanged_count=0,
            diff_items=[],
            summary_ar="هذا البند جديد لا توجد له نسخة سابقة في قاعدة البيانات."
        )

    old_agreements = repository.get_agreements_by_hs_code(db, existing_active.hs_code)
    old_ag_by_notice = {}
    for ag in old_agreements:
        key = ag.publication_notice or ag.agreement_name
        old_ag_by_notice.setdefault(key, ag)

    new_ag_by_notice = {}
    for ag in new_agreements:
        key = ag.get("publication_notice") or ag.get("agreement_name")
        new_ag_by_notice[key] = ag

    diff_items = []
    added_c = 0
    removed_c = 0
    modified_c = 0
    unchanged_c = 0

    # 1. Base Tax & Duty Rate changes
    old_duty = Decimal(str(existing_active.customs_duty_rate))
    new_duty = Decimal(str(new_tariff_data.get("customs_duty_rate", old_duty)))
    if old_duty != new_duty:
        modified_c += 1
        diff_items.append(
            TariffDiffItem(
                change_type="modified",
                publication_notice=None,
                agreement_name="ضريبة الوارد النظام الأساسي",
                origin_countries="All",
                old_value_desc=f"{old_duty}%",
                new_value_desc=f"{new_duty}%",
                color_code="#E67E22",
                summary_ar=f"تغيرت ضريبة الوارد الأساسية من {old_duty}% إلى {new_duty}%"
            )
        )

    # 2. Agreement Lines Changes
    for key, new_ag in new_ag_by_notice.items():
        ag_name = new_ag.get("agreement_name", "اتفاقية جمركية")
        pub = new_ag.get("publication_notice")
        origin = new_ag.get("origin_countries", "")
        new_rate = new_ag.get("preferential_duty_rate")
        new_disc = new_ag.get("reduction_percentage")
        new_desc = f"خصم {new_disc*100}%" if new_disc is not None else f"ضريبة {new_rate}%"

        if key not in old_ag_by_notice:
            added_c += 1
            diff_items.append(
                TariffDiffItem(
                    change_type="added",
                    publication_notice=pub,
                    agreement_name=ag_name,
                    origin_countries=origin,
                    old_value_desc="غير موجود سابقاً",
                    new_value_desc=new_desc,
                    color_code="#27AE60",
                    summary_ar=f"إضافة بند/منشور جديد ({pub or ag_name}): {new_desc}"
                )
            )
        else:
            old_ag = old_ag_by_notice[key]
            old_rate = old_ag.preferential_duty_rate
            old_disc = old_ag.reduction_percentage
            old_desc = f"خصم {old_disc*100}%" if old_disc is not None else f"ضريبة {old_rate}%"

            if old_rate != new_rate or old_disc != new_disc or old_ag.publication_notice != pub:
                modified_c += 1
                diff_items.append(
                    TariffDiffItem(
                        change_type="modified",
                        publication_notice=pub,
                        agreement_name=ag_name,
                        origin_countries=origin,
                        old_value_desc=old_desc,
                        new_value_desc=new_desc,
                        color_code="#E67E22",
                        summary_ar=f"تعديل في ({pub or ag_name}): تغير التخفيض من {old_desc} إلى {new_desc}"
                    )
                )
            else:
                unchanged_c += 1
                diff_items.append(
                    TariffDiffItem(
                        change_type="unchanged",
                        publication_notice=pub,
                        agreement_name=ag_name,
                        origin_countries=origin,
                        old_value_desc=old_desc,
                        new_value_desc=new_desc,
                        color_code="#2C3E50",
                        summary_ar=f"دون تغيير ({pub or ag_name}): {new_desc}"
                    )
                )

    # 3. Removed Agreements
    for key, old_ag in old_ag_by_notice.items():
        if key not in new_ag_by_notice:
            removed_c += 1
            pub = old_ag.publication_notice
            ag_name = old_ag.agreement_name
            old_disc = old_ag.reduction_percentage
            old_rate = old_ag.preferential_duty_rate
            old_desc = f"خصم {old_disc*100}%" if old_disc is not None else f"ضريبة {old_rate}%"
            diff_items.append(
                TariffDiffItem(
                    change_type="removed",
                    publication_notice=pub,
                    agreement_name=ag_name,
                    origin_countries=old_ag.origin_countries,
                    old_value_desc=old_desc,
                    new_value_desc="تم حذف/إلغاء المنشور",
                    color_code="#C0392B",
                    summary_ar=f"حذف/إلغاء المنشور ({pub or ag_name}): كان مطبقاً بنسبة {old_desc}"
                )
            )

    prev_from = existing_active.effective_from
    prev_to = date.today()

    return TariffVersionComparisonResponse(
        hs_code=hs_code,
        has_previous_version=True,
        previous_effective_from=prev_from,
        previous_effective_to=prev_to,
        new_effective_from=date.today(),
        added_count=added_c,
        removed_count=removed_c,
        modified_count=modified_c,
        unchanged_count=unchanged_c,
        diff_items=diff_items,
        summary_ar=f"تحليل التغيرات للبند {hs_code}: النسخة السابقة كانت مطبقة من {prev_from} حتى {prev_to}. تم اكتشاف {added_c} إضافات، {removed_c} محذوفات، {modified_c} تعديلات."
    )


def parse_smart_nafeza_tariff_text_service(raw_text: str, db: Optional[Session] = None) -> SmartTariffParseResponse:
    """Service to parse raw Nafeza tariff sheet text into tariff master record + agreements, with optional diff comparison."""
    tariff, agreements = parse_nafeza_tariff_text(raw_text)
    summary_ar = (
        f"تم تحليل نص البند الجمركي {tariff.hs_code} بنجاح: "
        f"ضريبة الوارد الأساسية {tariff.customs_duty_rate}%، القيمة المضافة {tariff.vat_rate}%، "
        f"وتم استخراج {len(agreements)} اتفاقيات تفضيلية مرتبطة."
    )

    comparison = None
    if db is not None:
        tariff_dict = tariff.model_dump()
        agreements_dicts = [ag.model_dump() for ag in agreements]
        comparison = compare_tariff_versions_service(
            db=db, hs_code=tariff.hs_code, new_tariff_data=tariff_dict, new_agreements=agreements_dicts
        )

    return SmartTariffParseResponse(
        tariff_data=tariff,
        agreements=agreements,
        parsed_agreements_count=len(agreements),
        summary_ar=summary_ar,
        comparison=comparison,
    )


def save_tariff_with_agreements_service(
    db: Session, req: TariffAgreementBulkSaveRequest
) -> dict:
    """Service to save/update an HS Code master record with all its preferential agreements in a single transaction while preserving historical snapshots."""
    from modules.audit_logs.service import AuditLogService

    tariff_dict = req.tariff.model_dump()
    agreements_dicts = [ag.model_dump() for ag in req.agreements]

    existing_before = repository.get_tariff_by_hs_code(db, req.tariff.hs_code)
    is_update = existing_before is not None

    tariff, created_agreements = repository.bulk_create_or_update_tariff_with_agreements(
        db=db, tariff_data=tariff_dict, agreements_data=agreements_dicts, update_date=req.update_date
    )

    action_name = "UPDATE" if is_update else "CREATE"
    summary_text = (
        f"Updated customs tariff line {tariff.hs_code} with {len(created_agreements)} preferential agreements"
        if is_update
        else f"Created customs tariff line {tariff.hs_code} with {len(created_agreements)} preferential agreements"
    )

    AuditLogService(db).log_activity(
        action=action_name,
        entity_type="CustomsTariff",
        entity_id=tariff.tariff_id,
        entity_code=tariff.hs_code,
        performed_by="System Admin",
        changes_summary=summary_text,
        new_data={
            "customs_duty_rate": str(tariff.customs_duty_rate),
            "vat_rate": str(tariff.vat_rate),
            "agreements_count": len(created_agreements),
        },
    )

    db.commit()
    db.refresh(tariff)
    for ag in created_agreements:
        db.refresh(ag)

    return {
        "tariff": CustomsTariffResponse.model_validate(tariff),
        "agreements": [PreferentialAgreementResponse.model_validate(ag) for ag in created_agreements],
        "summary_ar": f"تم حفظ الإصدار الجديد للبند الجمركي {tariff.hs_code} مع {len(created_agreements)} اتفاقية تفضيلية بنجاح دون المساس بالسجلات التاريخية السابقة.",
    }


def get_tariff_version_history_service(db: Session, hs_code: str) -> dict:
    """Service to fetch all historical versions, diff changes, and audit logs of an HS Code."""
    from sqlalchemy import and_, or_
    from modules.audit_logs.model import AuditLog

    clean_hs = hs_code.strip()
    nodots = clean_hs.replace(".", "")
    versions = repository.get_all_tariff_versions_by_hs_code(db, hs_code)

    tariff_ids = [v.tariff_id for v in versions]
    logs = (
        db.query(AuditLog)
        .filter(
            or_(
                AuditLog.entity_code == clean_hs,
                AuditLog.entity_code == nodots,
                and_(
                    AuditLog.entity_type.in_(["CustomsTariff", "customs_tariffs", "preferential_agreements"]),
                    AuditLog.entity_id.in_(tariff_ids) if tariff_ids else False,
                )
            )
        )
        .order_by(AuditLog.log_id.desc())
        .all()
    )

    version_items = []
    for idx, v in enumerate(versions):
        agreements = repository.get_agreements_by_hs_code(db, v.hs_code)
        version_items.append({
            "tariff_id": v.tariff_id,
            "hs_code": v.hs_code,
            "hs_description": v.hs_description,
            "customs_duty_rate": float(v.customs_duty_rate) if v.customs_duty_rate is not None else 0.0,
            "vat_rate": float(v.vat_rate) if v.vat_rate is not None else 14.0,
            "schedule_tax_rate": float(v.schedule_tax_rate) if v.schedule_tax_rate is not None else 0.0,
            "development_fee_rate": float(v.development_fee_rate) if v.development_fee_rate is not None else 0.0,
            "import_fee_rate": float(v.import_fee_rate) if v.import_fee_rate is not None else 0.0,
            "customs_service_fee_rate": float(v.customs_service_fee_rate) if v.customs_service_fee_rate is not None else 1.0,
            "regulatory_authority": v.regulatory_authority,
            "prior_approval_note": v.prior_approval_note,
            "effective_from": v.effective_from.isoformat() if v.effective_from else None,
            "effective_to": v.effective_to.isoformat() if v.effective_to else None,
            "created_at": v.created_at.isoformat() if v.created_at else None,
            "updated_at": v.updated_at.isoformat() if v.updated_at else None,
            "is_current_active": v.is_active,
            "agreements_count": len(agreements),
            "agreements": [
                {
                    "agreement_id": ag.agreement_id,
                    "agreement_name": ag.agreement_name,
                    "publication_notice": ag.publication_notice,
                    "preferential_duty_rate": float(ag.preferential_duty_rate) if ag.preferential_duty_rate is not None else None,
                    "reduction_percentage": float(ag.reduction_percentage) if ag.reduction_percentage is not None else None,
                    "reduction_type": ag.reduction_type,
                    "origin_countries": ag.origin_countries,
                    "required_document": ag.required_document,
                    "conditions_note": ag.conditions_note,
                }
                for ag in agreements
            ],
            "effective_period_desc": f"مطبق من {v.effective_from} حتى {v.effective_to or 'الآن (ساري)'}"
        })

    audit_items = [
        {
            "log_id": log.log_id,
            "action": log.action,
            "changes_summary": log.changes_summary,
            "performed_by": log.performed_by,
            "created_at": log.performed_at.isoformat() if log.performed_at else None,
            "old_values": log.old_values,
            "new_values": log.new_values,
        }
        for log in logs
    ]

    return {
        "hs_code": hs_code,
        "total_versions": len(versions),
        "versions": version_items,
        "audit_logs": audit_items,
    }


def evaluate_duty_by_origin_and_document_service(
    db: Session, req: OriginDutyCheckRequest
) -> OriginDutyCheckResponse:
    """
    محرك تقييم الضريبة حسب بلد المنشأ وتأكيد المستند (Origin Country & Document Verification Engine).
    تطبيق قواعد العمل:
    1. إذا لم تكن الدولة مرتبطة باتفاقية -> إرجاع الضريبة الأساسية بدون تنبيهات.
    2. إذا كانت الدولة مرتبطة باتفاقية -> إظهار تنبيه المستند المطلوب (EUR.1).
       - مع تأكيد المستند -> تطبيق الضريبة التفضيلية المخفضة.
       - بدون تأكيد المستند -> تطبيق الضريبة الأساسية وتثبيت التحذير.
    """
    target_date = req.check_date or date.today()
    tariff = repository.get_active_tariff_on_date(db, req.hs_code, target_date, strict=False)
    if not tariff:
        tariff = repository.get_tariff_by_hs_code(db, req.hs_code)

    if not tariff:
        raise HTTPException(
            status_code=404,
            detail=f"البند الجمركي {req.hs_code} غير مسجل في النظام."
        )

    base_duty = Decimal(str(tariff.customs_duty_rate))
    origin_code = req.origin_country.strip().upper()

    all_agreements = repository.get_agreements_by_hs_code(
        db, req.hs_code, origin_country=origin_code, on_date=target_date
    )
    matching_agreement = all_agreements[0] if all_agreements else None

    if not matching_agreement:
        return OriginDutyCheckResponse(
            hs_code=req.hs_code,
            origin_country=origin_code,
            base_duty_rate=base_duty,
            effective_duty_rate=base_duty,
            applied_agreement_name=None,
            publication_notice=None,
            required_document=None,
            has_matching_agreement=False,
            document_verified=False,
            status_label="تطبيق ضريبة الوارد للنظام الأساسي (لا توجد اتفاقية مع بلد المنشأ)",
            warning_note=None,
            summary_ar=f"بلد المنشأ ({origin_code}) غير مرتبط باتفاقية تفضيلية. تم تطبيق ضريبة الوارد الأساسية {base_duty}%.",
        )

    ag_name = matching_agreement.agreement_name
    pub_notice = matching_agreement.publication_notice or "منشور جمركي"
    req_doc = matching_agreement.required_document or "شهادة منشأ تفضيلية (EUR.1)"

    pref_duty = _agreement_duty_rate(base_duty, matching_agreement)

    if req.has_preferential_document:
        return OriginDutyCheckResponse(
            hs_code=req.hs_code,
            origin_country=origin_code,
            base_duty_rate=base_duty,
            effective_duty_rate=pref_duty,
            applied_agreement_name=ag_name,
            publication_notice=pub_notice,
            required_document=req_doc,
            has_matching_agreement=True,
            document_verified=True,
            status_label=f"تم تطبيق تخفيض {ag_name} ({pref_duty}% بدلاً من {base_duty}%)",
            warning_note=None,
            summary_ar=f"تمت المطابقة مع {ag_name} ({pub_notice}). تم تأكيد {req_doc} وتطبيق الضريبة المخفضة {pref_duty}%.",
        )
    else:
        warning = f"توجد اتفاقية تفضيلية ({ag_name} - {pub_notice}) بخصم إلى {pref_duty}%، ولكن يلزم إرفاق ({req_doc}) لتفعيل الإعفاء/التخفيض."
        return OriginDutyCheckResponse(
            hs_code=req.hs_code,
            origin_country=origin_code,
            base_duty_rate=base_duty,
            effective_duty_rate=base_duty,
            applied_agreement_name=ag_name,
            publication_notice=pub_notice,
            required_document=req_doc,
            has_matching_agreement=True,
            document_verified=False,
            status_label=f"توجد اتفاقية ({ag_name}) — يتطلب تقديم {req_doc}",
            warning_note=warning,
            summary_ar=f"توجد اتفاقية مع {origin_code} ({ag_name}) ولكن لم يتم إرفاق {req_doc}. تم تطبيق الضريبة الأساسية {base_duty}% مؤقتاً.",
        )


def _resolve_origin_iso2(
    db: Session,
    origin_val: Optional[str] = None,
    country_id: Optional[int] = None,
) -> Optional[str]:
    from modules.transport_locations.model import Country
    if country_id:
        c = db.query(Country).filter(Country.country_id == country_id, Country.is_active == True).first()
        if c and c.country_code and len(c.country_code.strip()) == 2:
            return c.country_code.strip().upper()
    if not origin_val:
        return None
    val = str(origin_val).strip()
    if not val:
        return None
    token = val.split(" - ")[0].strip() if " - " in val else val
    # Master Country table lookup by token (e.g. ISO-2 code)
    c = db.query(Country).filter(Country.country_code.ilike(token), Country.is_active == True).first()
    if c and c.country_code and len(c.country_code.strip()) == 2:
        return c.country_code.strip().upper()
    # Master Country table lookup by full name or Arabic name
    c = db.query(Country).filter(
        (Country.country_name.ilike(val)) | (Country.country_name_ar == val),
        Country.is_active == True,
    ).first()
    if c and c.country_code and len(c.country_code.strip()) == 2:
        return c.country_code.strip().upper()
    # If not found in Country table, check if token itself is an ISO-2 alphabetic code
    if len(token) == 2 and token.isalpha():
        return token.upper()
    return None


def simulate_import_file_customs_duty_service(
    db: Session,
    import_file_id: int,
    request: Optional[ImportFileCustomsSimulationRequest] = None,
) -> ImportFileCustomsSimulationResponse:
    """
    محاكاة واحتساب الرسوم والضرائب التقديرية لملف الشحنة الاستيرادية (PL-07: Customs Duty Simulation).
    1. استخراج بنود أمر الشراء أو الفواتير المرتبطة بالملف دون أي قيم أو بنود مخترعة.
    2. استرجاع سعر الصرف الجمركي الرسمي لكل عملة لأوامر الشراء في تاريخ التقدير.
    3. تحويل البنود إلى الجنيه المصري وتمريرها لمحرك الضرائب الموحد.
    4. استرجاع أو احتساب النولون والتأمين (فعلي أو حكمي).
    5. تحديث جلسة الاستشارة الجمركية القائمة، أو إنشاء واحدة جديدة فقط في حال تعيين مخلص جمركي.
    """
    from modules.import_files.model import ImportFile
    from modules.purchase_orders.model import PurchaseOrder
    from modules.currencies.model import Currency
    from modules.customs_consultation.model import CustomsConsultationSession, CustomsChecklistItem

    req = request or ImportFileCustomsSimulationRequest()
    calc_date = req.estimate_date or date.today()

    import_file = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
    if not import_file:
        raise HTTPException(
            status_code=404,
            detail=f"ملف الشحنة رقم {import_file_id} غير موجود.",
        )

    # 1. Gather POs and Line Items
    pos = (
        db.query(PurchaseOrder)
        .filter(PurchaseOrder.import_file_id == import_file_id, PurchaseOrder.is_active == True)
        .all()
    )
    po_numbers = [po.po_number for po in pos if po.po_number]

    estimate_lines: List[MultiItemCustomsEstimateLine] = []
    skipped_lines: List[dict] = []
    warnings: List[str] = []
    unique_currencies: Set[str] = set()
    line_idx = 1

    # Pre-scan distinct PO currencies upfront to safely handle manual exchange_rate override
    po_currencies: Dict[int, Optional[str]] = {}
    distinct_non_egp_currencies: Set[str] = set()
    for po in pos:
        c_code = (po.currency.currency_code if po.currency and po.currency.currency_code else getattr(po, "currency_code", None) or "").upper().strip()
        if not c_code and getattr(po, "currency_id", None):
            c_obj = db.query(Currency).filter(Currency.currency_id == po.currency_id).first()
            if c_obj and c_obj.currency_code:
                c_code = c_obj.currency_code.upper().strip()
        po_currencies[po.po_id] = c_code if c_code else None
        if c_code and c_code != "EGP":
            distinct_non_egp_currencies.add(c_code)

    override_applies = (
        req.exchange_rate is not None
        and req.exchange_rate > Decimal("0.00")
        and len(distinct_non_egp_currencies) == 1
    )
    if req.exchange_rate is not None and req.exchange_rate > Decimal("0.00") and len(distinct_non_egp_currencies) > 1:
        warnings.append("EXCHANGE_RATE_OVERRIDE_AMBIGUOUS")

    for po in pos:
        po_curr = po_currencies.get(po.po_id)
        if not po_curr:
            for item in (po.line_items or []):
                item_code_val = (
                    getattr(item, "item_code", "")
                    or getattr(item, "description_ar", "")
                    or getattr(item, "description_en", "")
                    or ""
                )
                skipped_lines.append({
                    "po_number": po.po_number or "",
                    "item_code": item_code_val,
                    "reason": "NO_CURRENCY",
                })
            continue

        unique_currencies.add(po_curr)

        # Resolve exchange rate for this PO currency
        if po_curr == "EGP":
            po_rate = Decimal("1.0000")
        elif override_applies and po_curr in distinct_non_egp_currencies:
            po_rate = req.exchange_rate
        else:
            po_rate, _, _ = _customs_rate(db, po_curr, calc_date)

        for item in (po.line_items or []):
            hs = (item.tariff.hs_code if getattr(item, "tariff", None) else getattr(item, "hs_code", "")) or ""
            hs = hs.strip()
            if not hs and import_file.hs_code:
                hs = import_file.hs_code.strip()

            item_code_val = (
                getattr(item, "item_code", "")
                or getattr(item, "description_ar", "")
                or getattr(item, "description_en", "")
                or ""
            )

            if not hs:
                skipped_lines.append({
                    "po_number": po.po_number or "",
                    "item_code": item_code_val,
                    "reason": "NO_HS",
                })
                continue

            qty = Decimal(str(item.quantity or 0.0))
            u_price = Decimal(str(item.unit_price or 0.0))
            val_fc = Decimal(str(item.total_price or (qty * u_price)))
            if val_fc <= Decimal("0.00"):
                skipped_lines.append({
                    "po_number": po.po_number or "",
                    "item_code": item_code_val,
                    "reason": "NO_VALUE",
                })
                continue

            origin_raw = (getattr(item, "country_of_origin", "") or getattr(po, "country_of_origin", "") or "").strip()
            country_id = getattr(item, "country_id", None) or getattr(po, "country_id", None)
            origin_iso = _resolve_origin_iso2(db, origin_val=origin_raw, country_id=country_id)

            val_egp = _round(val_fc * po_rate)

            estimate_lines.append(
                MultiItemCustomsEstimateLine(
                    line_no=line_idx,
                    hs_code=hs,
                    value_fc=val_egp,
                    weight_kg=Decimal(str(getattr(item, "gross_weight_kg", 0.0) or 0.0)),
                    qty=qty if qty > Decimal("0.00") else Decimal("1.00"),
                    origin_country=origin_iso,
                )
            )
            line_idx += 1

    # Fallback to invoices_data if no PO items exist
    if not estimate_lines and not pos and import_file.invoices_data:
        inv_non_egp_currencies: Set[str] = set()
        for inv in import_file.invoices_data:
            c = (inv.get("currency") or "").upper().strip()
            if c and c != "EGP":
                inv_non_egp_currencies.add(c)

        inv_override_applies = (
            req.exchange_rate is not None
            and req.exchange_rate > Decimal("0.00")
            and len(inv_non_egp_currencies) == 1
        )
        if req.exchange_rate is not None and req.exchange_rate > Decimal("0.00") and len(inv_non_egp_currencies) > 1:
            warnings.append("EXCHANGE_RATE_OVERRIDE_AMBIGUOUS")

        for inv in import_file.invoices_data:
            inv_curr = (inv.get("currency") or "").upper().strip()
            inv_num = inv.get("invoice_number", "") or "INVOICE"
            if not inv_curr:
                skipped_lines.append({
                    "po_number": inv_num,
                    "item_code": "INVOICE",
                    "reason": "NO_CURRENCY",
                })
                continue

            unique_currencies.add(inv_curr)
            if inv_curr == "EGP":
                inv_rate = Decimal("1.0000")
            elif inv_override_applies and inv_curr in inv_non_egp_currencies:
                inv_rate = req.exchange_rate
            else:
                inv_rate, _, _ = _customs_rate(db, inv_curr, calc_date)

            hs = (import_file.hs_code or "").strip()
            if not hs:
                skipped_lines.append({
                    "po_number": inv_num,
                    "item_code": "INVOICE",
                    "reason": "NO_HS",
                })
                continue

            inv_amt = Decimal(str(inv.get("amount") or 0.0))
            if inv_amt <= Decimal("0.00"):
                skipped_lines.append({
                    "po_number": inv_num,
                    "item_code": "INVOICE",
                    "reason": "NO_VALUE",
                })
                continue

            val_egp = _round(inv_amt * inv_rate)
            estimate_lines.append(
                MultiItemCustomsEstimateLine(
                    line_no=line_idx,
                    hs_code=hs,
                    value_fc=val_egp,
                    weight_kg=Decimal("0.00"),
                    qty=Decimal("1.00"),
                    origin_country=None,
                )
            )
            line_idx += 1

    # If no lines exist, fail with 422 CT_SIMULATION_NO_LINES
    if not estimate_lines:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail={
                "code": "CT_SIMULATION_NO_LINES",
                "message": "لا توجد أصناف بها بند جمركي وقيمة لاحتساب الرسوم التقديرية.",
            },
        )

    # 2. Resolve Freight & Insurance
    has_freight_doc = req.freight_egp is not None and req.freight_egp > Decimal("0.00")
    freight_val_egp = req.freight_egp or Decimal("0.00")
    if not has_freight_doc:
        from modules.freight_quotations.model import FreightRFQRequest, FreightQuotationItem
        awarded_rfq = (
            db.query(FreightRFQRequest)
            .filter(FreightRFQRequest.import_file_id == import_file_id)
            .order_by(FreightRFQRequest.rfq_id.desc())
            .first()
        )
        if awarded_rfq and awarded_rfq.selected_quotation_id:
            winning_q = db.query(FreightQuotationItem).filter(
                FreightQuotationItem.quotation_id == awarded_rfq.selected_quotation_id
            ).first()
            if winning_q and winning_q.total_cost:
                q_curr = (winning_q.currency_code or "").upper().strip()
                if not q_curr:
                    warnings.append("CT_SIMULATION_FREIGHT_NO_CURRENCY")
                else:
                    q_cost = Decimal(str(winning_q.total_cost))
                    if q_curr == "EGP":
                        freight_val_egp = q_cost
                    else:
                        q_rate, _, _ = _customs_rate(db, q_curr, calc_date)
                        freight_val_egp = _round(q_cost * q_rate)
                    has_freight_doc = True

    has_ins_doc = req.insurance_egp is not None and req.insurance_egp > Decimal("0.00")
    ins_val_egp = req.insurance_egp or Decimal("0.00")

    # 3. Build Multi-Item Calculation Request and execute
    # Lines have already been converted to EGP per their PO customs exchange rates
    calc_request = MultiItemCustomsEstimateRequest(
        currency="EGP",
        exchange_rate=Decimal("1.0000"),
        insurance_egp=ins_val_egp,
        freight_egp=freight_val_egp,
        packaging_egp=req.packaging_egp or Decimal("0.00"),
        has_insurance_document=has_ins_doc,
        has_freight_document=has_freight_doc,
        estimate_date=calc_date,
        lines=estimate_lines,
    )

    breakdown = estimate_multi_item_customs_duty_service(db, calc_request)

    # 4. Persist to Consultation Session if requested
    consultation_id = None
    if req.save_to_consultation:
        consultation = (
            db.query(CustomsConsultationSession)
            .filter(
                CustomsConsultationSession.import_file_id == import_file_id,
                CustomsConsultationSession.is_active == True,
            )
            .first()
        )

        grand_duties_egp = float(breakdown.grand_total_payable_egp)

        if consultation:
            consultation.estimated_duties_egp = grand_duties_egp
            db.commit()
            db.refresh(consultation)
            consultation_id = consultation.consultation_id
        elif import_file.broker_id:
            from modules.external_service_providers.model import ExternalServiceProvider
            broker = (
                db.query(ExternalServiceProvider)
                .filter(ExternalServiceProvider.provider_id == import_file.broker_id, ExternalServiceProvider.is_active == True)
                .first()
            )
            if broker:
                broker_name = broker.partner_name
                consultation = CustomsConsultationSession(
                    consultation_code=f"CONS-{import_file.import_file_code}",
                    title=f"Customs consultation study - {import_file.import_file_code}",
                    broker_id=import_file.broker_id,
                    broker_name=broker_name,
                    import_file_id=import_file_id,
                    overall_status="Pending Review",
                    estimated_duties_egp=grand_duties_egp,
                    is_active=True,
                )
                db.add(consultation)
                db.flush()

                checklist_items = []
                acid_needed = any(l.requires_acid for l in breakdown.lines)
                if acid_needed:
                    checklist_items.append(
                        CustomsChecklistItem(
                            consultation_id=consultation.consultation_id,
                            document_type="Advance ACID Filing (Nafeza / CargoX)",
                            is_required=True,
                            is_blocking_shipment=True,
                            responsible_party="Importer Team",
                            regulatory_agency="Nafeza / CargoX",
                            status="Pending",
                            remarks="The advance ACID number is mandatory before the B/L is issued.",
                        )
                    )

                coo_needed = any(l.requires_coo for l in breakdown.lines)
                if coo_needed:
                    checklist_items.append(
                        CustomsChecklistItem(
                            consultation_id=consultation.consultation_id,
                            document_type="Certificate of Origin (COO / EUR.1)",
                            is_required=True,
                            is_blocking_shipment=True,
                            responsible_party="Supplier / Exporter",
                            regulatory_agency="Chamber of Commerce / Customs",
                            status="Pending",
                            remarks="Official certificate of origin required to apply customs exemptions.",
                        )
                    )

                insp_needed = any(l.requires_inspection for l in breakdown.lines)
                if insp_needed:
                    checklist_items.append(
                        CustomsChecklistItem(
                            consultation_id=consultation.consultation_id,
                            document_type="GOEIC Inspection",
                            is_required=True,
                            is_blocking_shipment=True,
                            responsible_party="Customs Broker",
                            regulatory_agency="GOEIC",
                            status="Pending",
                            remarks="Physical inspection and lab sampling by GOEIC.",
                        )
                    )

                if checklist_items:
                    db.add_all(checklist_items)

                db.commit()
                db.refresh(consultation)
                consultation_id = consultation.consultation_id
            else:
                warnings.append("CT_SIMULATION_NO_BROKER")
        else:
            warnings.append("CT_SIMULATION_NO_BROKER")

    resp_currency = list(unique_currencies)[0] if len(unique_currencies) == 1 else "EGP"

    summary = (
        f"تمت المحاكاة الجمركية لملف {import_file.import_file_code}: "
        f"إجمالي سيف {breakdown.grand_total_payable_egp:.2f} ج.م، "
        f"ضريبة الوارد {breakdown.total_duty_egp:.2f} ج.م، "
        f"ضريبة القيمة المضافة {breakdown.total_vat_egp:.2f} ج.م، "
        f"إجمالي الضرائب والرسوم المقدرة {breakdown.grand_total_payable_egp:.2f} ج.م."
    )

    return ImportFileCustomsSimulationResponse(
        import_file_id=import_file_id,
        import_file_code=import_file.import_file_code,
        po_numbers=po_numbers,
        currency=resp_currency,
        breakdown=breakdown,
        consultation_id=consultation_id,
        summary_ar=summary,
        warnings=warnings,
        skipped_lines=skipped_lines,
    )




