"""
Customs Tariff Search, Master Data CRUD, Bulk Import & Smart Parser Sub-Service
(modules/customs_tariff/tariff_search_service.py)

Decomposed from customs_tariff/service.py:
- Customs tariff master creation, update, archive versioning, and soft-delete/restore
- HS code queries, ID lookups, and chapter/heading/category filtering
- Category search text mapping via enum codes
- Verification and manual updates (Addendum 3 workflow)
- Bulk import & Excel/CSV template processing
- Nafeza fee code lookup and registration
- Smart Nafeza text parsing and automatic diff comparison
"""
import csv
import io
from datetime import date
from decimal import Decimal
from typing import List, Optional, Tuple

from fastapi import HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from modules.common import enum_codes
from . import repository
from .model import CustomsTariff
from .nafeza_text_parser import import_duty_rates, parse_nafeza_tariff_text
from .schemas import (
    CustomsTariffCreate,
    CustomsTariffUpdate,
    FeeCodeCreate,
    SmartTariffParseResponse,
    TariffVerificationRequest,
    normalize_customs_category,
)
from .tariff_agreements_service import compare_tariff_versions_service
from .tariff_calculation_service import _parse_decimal
from .validators import (
    resolve_rate_change_effective_date,
    validate_effective_date_range,
    validate_no_duplicate_hs_code,
    validate_no_overlapping_hs_code_dates,
)


def create_tariff_service(db: Session, data: CustomsTariffCreate) -> CustomsTariff:
    validate_no_duplicate_hs_code(
        db,
        data.hs_code,
        effective_from=data.effective_from,
        effective_to=data.effective_to,
    )
    validate_effective_date_range(data.effective_from, data.effective_to)
    tariff = repository.create_tariff(db, data.model_dump())
    db.commit()
    db.refresh(tariff)
    versions = repository.get_all_tariff_versions_by_hs_code(db, tariff.hs_code)
    tariff.total_versions = len(versions)
    if getattr(tariff, "has_anti_dumping_risk", False):
        from modules.experience_guide.service import ExperienceGuideService
        ExperienceGuideService(db).sync_anti_dumping_guide_entry(
            tariff.hs_code,
            tariff.hs_description,
            tariff.anti_dumping_notes,
        )
    return tariff


def get_all_tariffs_service(
    db: Session,
    include_inactive: bool = False,
    search: Optional[str] = None,
    skip: int = 0,
    limit: Optional[int] = None,
) -> Tuple[List[CustomsTariff], int]:
    tariffs, total = repository.get_all_tariffs(
        db,
        include_inactive=include_inactive,
        search=search,
        skip=skip,
        limit=limit,
        category_values=customs_category_search_values(search),
    )
    if tariffs:
        hs_codes = list({t.hs_code for t in tariffs})
        counts = dict(
            db.query(CustomsTariff.hs_code, func.count(CustomsTariff.tariff_id))
            .filter(CustomsTariff.hs_code.in_(hs_codes))
            .group_by(CustomsTariff.hs_code)
            .all()
        )
        for t in tariffs:
            t.total_versions = counts.get(t.hs_code, 1)
    return tariffs, total


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
        raise HTTPException(status_code=404, detail="سجل التعريفة الجمركية غير موجود")
    versions = repository.get_all_tariff_versions_by_hs_code(db, tariff.hs_code)
    tariff.total_versions = len(versions)
    return tariff


def get_tariff_by_hs_code_service(
    db: Session, hs_code: str, on_date: Optional[date] = None
) -> CustomsTariff:
    tariff = repository.get_tariff_by_hs_code(db, hs_code, on_date=on_date)
    if not tariff:
        raise HTTPException(status_code=404, detail=f"التعريفة الجمركية للبند الجمركي '{hs_code}' غير موجودة")
    versions = repository.get_all_tariff_versions_by_hs_code(db, hs_code)
    tariff.total_versions = len(versions)
    return tariff


_RATE_AND_REQUIREMENT_FIELDS = (
    "customs_duty_rate",
    "vat_rate",
    "schedule_tax_rate",
    "development_fee_rate",
    "import_fee_rate",
    "customs_service_fee_rate",
    "requires_coo",
    "requires_inspection",
    "requires_acid",
    "regulatory_authority",
    "prior_approval_note",
)


def _has_rate_or_requirement_change(tariff: CustomsTariff, update_dict: dict) -> bool:
    """True when the update changes a rate or regulatory requirement (fields that need a new version)."""
    for field in _RATE_AND_REQUIREMENT_FIELDS:
        if field not in update_dict:
            continue
        curr_val = getattr(tariff, field)
        new_val = update_dict[field]
        if isinstance(curr_val, Decimal) or isinstance(new_val, Decimal):
            if Decimal(str(curr_val or 0)) != Decimal(str(new_val or 0)):
                return True
        elif curr_val != new_val:
            return True
    return False


def _validate_validity_window(
    db: Session, tariff: CustomsTariff, effective_from: date, effective_to: Optional[date]
) -> None:
    validate_effective_date_range(effective_from, effective_to)
    validate_no_overlapping_hs_code_dates(
        db,
        hs_code=tariff.hs_code,
        effective_from=effective_from,
        effective_to=effective_to,
        exclude_id=tariff.tariff_id,
    )


def update_tariff_service(
    db: Session, tariff_id: int, data: CustomsTariffUpdate
) -> CustomsTariff:
    tariff = repository.get_tariff_by_id(db, tariff_id)
    if not tariff:
        raise HTTPException(status_code=404, detail="سجل التعريفة الجمركية غير موجود")

    update_dict = data.model_dump(exclude_unset=True, exclude_none=True)
    # An explicit null effective_to reopens the version (clears its end date).
    if "effective_to" in data.model_fields_set and data.effective_to is None:
        update_dict["effective_to"] = None

    if _has_rate_or_requirement_change(tariff, update_dict):
        eff_date = resolve_rate_change_effective_date(
            tariff.effective_from, update_dict.get("effective_from"), date.today()
        )
        if eff_date > tariff.effective_from:
            # BE67-T08 & ACC1-T08: close the current version and open a new one so past
            # confirmed cost snapshots keep the rates that were in force on their dates.
            # An omitted effective_to keeps the current version's planned (decree) end.
            if "effective_to" not in update_dict:
                update_dict["effective_to"] = repository.carried_over_effective_to(tariff, eff_date)
            _validate_validity_window(db, tariff, eff_date, update_dict["effective_to"])
            result = repository.archive_and_create_new_tariff_version(
                db, tariff, update_dict, effective_date=eff_date
            )
        else:
            # The version starts today or later, so no past day depends on it: edit in place.
            update_dict["effective_from"] = update_dict.get("effective_from", tariff.effective_from)
            _validate_validity_window(
                db,
                tariff,
                update_dict["effective_from"],
                update_dict.get("effective_to", tariff.effective_to),
            )
            result = repository.update_tariff(db, tariff_id, update_dict)
    else:
        # Metadata / validity-window only: in-place update.
        if "effective_from" in update_dict or "effective_to" in update_dict:
            _validate_validity_window(
                db,
                tariff,
                update_dict.get("effective_from", tariff.effective_from),
                update_dict.get("effective_to", tariff.effective_to),
            )
        result = repository.update_tariff(db, tariff_id, update_dict)

    db.commit()
    db.refresh(result)
    versions = repository.get_all_tariff_versions_by_hs_code(db, result.hs_code)
    result.total_versions = len(versions)
    return result


def delete_tariff_service(db: Session, tariff_id: int) -> CustomsTariff:
    tariff = repository.get_tariff_by_id(db, tariff_id)
    if not tariff:
        raise HTTPException(status_code=404, detail="سجل التعريفة الجمركية غير موجود")
    toggled = repository.toggle_tariff_active(db, tariff_id, is_active=False)
    db.commit()
    db.refresh(toggled)
    return toggled


def restore_tariff_service(db: Session, tariff_id: int) -> CustomsTariff:
    tariff = repository.get_tariff_by_id(db, tariff_id)
    if not tariff:
        raise HTTPException(status_code=404, detail="سجل التعريفة الجمركية غير موجود")
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
        raise HTTPException(status_code=404, detail=f"التعريفة الجمركية للبند الجمركي '{hs_code}' غير موجودة")

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


def parse_smart_nafeza_tariff_text_service(raw_text: str, db: Optional[Session] = None) -> SmartTariffParseResponse:
    """Service to parse raw Nafeza tariff sheet text into tariff master record + agreements, with optional diff comparison."""
    tariff, agreements = parse_nafeza_tariff_text(raw_text)
    summary_ar = (
        f"تم تحليل نص البند الجمركي {tariff.hs_code} بنجاح: "
        f"ضريبة الوارد الأساسية {tariff.customs_duty_rate}%، القيمة المضافة {tariff.vat_rate}%، "
        f"وتم استخراج {len(agreements)} اتفاقيات تفضيلية مرتبطة."
    )
    distinct_rates = sorted(set(import_duty_rates(raw_text)))
    if len(distinct_rates) > 1:
        summary_ar += (
            " تنبيه: الصفحة فيها أكتر من نسبة لضريبة الوارد ("
            + "، ".join(f"{rate}%" for rate in distinct_rates)
            + f")؛ اتاخدت النسبة الأولى ({tariff.customs_duty_rate}%) على إنها النظام الأساسي، راجعها قبل الحفظ."
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
