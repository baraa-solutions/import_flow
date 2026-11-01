"""
Trade Agreements, Preferential Exemptions, and Tariff History Sub-Service
(modules/customs_tariff/tariff_agreements_service.py)

Decomposed from customs_tariff/service.py:
- Preferential agreements lookup & duty rate determination
- Exemption registry & tax base exemption resolution
- Historical tariff version tracking, diff comparisons, and audit log history
- Origin country duty checks with EUR.1 / preferential document validation
- Country ISO2 origin resolution
"""
from datetime import date, datetime
from decimal import Decimal, ROUND_HALF_UP
from typing import Any, Dict, List, Optional, Tuple

from fastapi import HTTPException, status
from sqlalchemy import and_, or_
from sqlalchemy.orm import Session

from modules.audit_logs.model import AuditLog
from modules.audit_logs.service import AuditLogService
from modules.transport_locations.model import Country
from . import repository
from .model import CustomsTariff, PreferentialAgreement
from .schemas import (
    CustomsTariffResponse,
    OriginDutyCheckRequest,
    OriginDutyCheckResponse,
    PreferentialAgreementCreate,
    PreferentialAgreementResponse,
    TariffAgreementBulkSaveRequest,
    TariffDiffItem,
    TariffVersionComparisonResponse,
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


def save_tariff_with_agreements_service(
    db: Session, req: TariffAgreementBulkSaveRequest
) -> dict:
    """Service to save/update an HS Code master record with all its preferential agreements in a single transaction while preserving historical snapshots."""
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

    all_agreements = repository.get_agreements_by_hs_code(db, clean_hs)

    version_items = []
    for idx, v in enumerate(versions):
        agreements = []
        for ag in all_agreements:
            ag_from = ag.effective_from
            ag_to = ag.effective_to
            v_from = v.effective_from
            v_to = v.effective_to
            if ag_to and v_from and ag_to < v_from:
                continue
            if v_to and ag_from and ag_from > v_to:
                continue
            agreements.append(ag)

        version_num = len(versions) - idx
        version_items.append({
            "tariff_id": v.tariff_id,
            "hs_code": v.hs_code,
            "hs_description": v.hs_description,
            "customs_category": v.customs_category,
            "version_number": version_num,
            "stage_label": f"المرحلة {version_num}: من {v.effective_from} إلى {v.effective_to or 'الآن (ساري)'}",
            "customs_duty_rate": float(v.customs_duty_rate) if v.customs_duty_rate is not None else 0.0,
            "vat_rate": float(v.vat_rate) if v.vat_rate is not None else None,
            "schedule_tax_rate": float(v.schedule_tax_rate) if v.schedule_tax_rate is not None else 0.0,
            "development_fee_rate": float(v.development_fee_rate) if v.development_fee_rate is not None else 0.0,
            "import_fee_rate": float(v.import_fee_rate) if v.import_fee_rate is not None else 0.0,
            "customs_service_fee_rate": float(v.customs_service_fee_rate) if v.customs_service_fee_rate is not None else None,
            # Regulatory requirements (الاشتراطات الجمركية والرقابية لكل مرحلة)
            "requires_coo": bool(v.requires_coo),
            "requires_inspection": bool(v.requires_inspection),
            "requires_acid": bool(v.requires_acid),
            "regulatory_authority": v.regulatory_authority,
            "prior_approval_note": v.prior_approval_note,
            "notes": v.notes,
            "effective_from": v.effective_from.isoformat() if v.effective_from else None,
            "effective_to": v.effective_to.isoformat() if v.effective_to else None,
            "created_at": v.created_at.isoformat() if v.created_at else None,
            "updated_at": v.updated_at.isoformat() if v.updated_at else None,
            "is_current_active": bool(v.is_active),
            "is_current": bool(v.is_active),
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
