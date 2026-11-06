from datetime import date, timedelta
from typing import List, Optional, Tuple

from sqlalchemy import or_
from sqlalchemy.orm import Session

from .model import CustomsTariff, PreferentialAgreement, TradeRemedyMeasure


# ==================================================
# Basic CRUD
# ==================================================

def get_tariff_by_id(db: Session, tariff_id: int) -> Optional[CustomsTariff]:
    return db.query(CustomsTariff).filter(CustomsTariff.tariff_id == tariff_id).first()


def get_tariff_by_hs_code(
    db: Session, hs_code: str, on_date: Optional[date] = None
) -> Optional[CustomsTariff]:
    if on_date is not None:
        return get_active_tariff_on_date(db, hs_code, on_date, strict=False)
    clean_hs = hs_code.strip()
    nodots = clean_hs.replace(".", "")
    formatted8 = f"{nodots[:4]}.{nodots[4:6]}.{nodots[6:8]}" if len(nodots) >= 8 else clean_hs
    formatted10 = f"{nodots[:4]}.{nodots[4:6]}.{nodots[6:8]}.{nodots[8:]}" if len(nodots) >= 10 else clean_hs
    targets = list(dict.fromkeys([clean_hs, nodots, formatted8, formatted10]))
    res = (
        db.query(CustomsTariff)
        .filter(CustomsTariff.hs_code.in_(targets), CustomsTariff.is_active == True)
        .order_by(CustomsTariff.effective_from.desc())
        .first()
    )
    if res:
        return res
    from sqlalchemy import func
    res = (
        db.query(CustomsTariff)
        .filter(func.replace(CustomsTariff.hs_code, '.', '') == nodots, CustomsTariff.is_active == True)
        .order_by(CustomsTariff.effective_from.desc())
        .first()
    )
    if res:
        return res
    # Fallback to latest version by effective_from if none marked active
    return (
        db.query(CustomsTariff)
        .filter(func.replace(CustomsTariff.hs_code, '.', '') == nodots)
        .order_by(CustomsTariff.effective_from.desc())
        .first()
    )


def get_all_tariffs(
    db: Session,
    include_inactive: bool = False,
    search: Optional[str] = None,
    skip: int = 0,
    limit: Optional[int] = None,
    category_values: Optional[List[str]] = None,
) -> Tuple[List[CustomsTariff], int]:
    """``category_values``: exact customs_category values (codes + their legacy labels) OR-ed into the
    text search, so a label typed by the user also finds rows that store the code."""
    query = db.query(CustomsTariff)
    if not include_inactive:
        query = query.filter(CustomsTariff.is_active == True)
    if search:
        clean_search = search.strip()
        nodots = clean_search.replace(".", "").lower()
        term = f"%{clean_search.lower()}%"
        nodots_term = f"%{nodots}%"
        from sqlalchemy import func
        conditions = [
            CustomsTariff.hs_code.ilike(term),
            func.replace(CustomsTariff.hs_code, '.', '').ilike(nodots_term),
            CustomsTariff.hs_description.ilike(term),
            CustomsTariff.customs_category.ilike(term),
        ]
        if category_values:
            conditions.append(CustomsTariff.customs_category.in_(category_values))
        query = query.filter(or_(*conditions))
    total = query.count()
    query = query.order_by(CustomsTariff.hs_code)
    if skip > 0:
        query = query.offset(skip)
    if limit is not None:
        query = query.limit(limit)
    return query.all(), total


def create_tariff(db: Session, data: dict) -> CustomsTariff:
    tariff = CustomsTariff(**data)
    db.add(tariff)
    db.flush()
    return tariff


def update_tariff(db: Session, tariff_id: int, data: dict) -> Optional[CustomsTariff]:
    tariff = get_tariff_by_id(db, tariff_id)
    if not tariff:
        return None
    for key, value in data.items():
        setattr(tariff, key, value)
    db.flush()
    return tariff


def archive_and_create_new_tariff_version(
    db: Session, current_tariff: CustomsTariff, new_data: dict, effective_date: date
) -> CustomsTariff:
    """
    سلسلة الأتمتة التاريخية (Addendum 3 / BE67-T08 & ACC1-T08):
    1. إغلاق السجل القديم بتحديد effective_to = effective_date - 1 يوم (لتفادي تداخل اليوم الواحد).
    2. إنشاء سجل جديد فعّال يبدأ من effective_date.
    3. الحفاظ على تاريخ سريان الاتفاقيات التفضيلية بإغلاق السابقة واستنساخ السارية للإصدار الجديد.
    """
    if effective_date > current_tariff.effective_from:
        current_tariff.effective_to = effective_date - timedelta(days=1)
    else:
        current_tariff.effective_to = effective_date
    current_tariff.is_active = False

    new_version_data = {
        "hs_code": current_tariff.hs_code,
        "hs_description": new_data.get("hs_description", current_tariff.hs_description),
        "customs_category": new_data.get("customs_category", current_tariff.customs_category),
        "customs_duty_rate": new_data.get("customs_duty_rate", current_tariff.customs_duty_rate),
        "vat_rate": new_data.get("vat_rate", current_tariff.vat_rate),
        "schedule_tax_rate": new_data.get("schedule_tax_rate", current_tariff.schedule_tax_rate),
        "development_fee_rate": new_data.get("development_fee_rate", current_tariff.development_fee_rate),
        "import_fee_rate": new_data.get("import_fee_rate", current_tariff.import_fee_rate),
        "customs_service_fee_rate": new_data.get("customs_service_fee_rate", current_tariff.customs_service_fee_rate),
        "requires_coo": new_data.get("requires_coo", current_tariff.requires_coo),
        "requires_inspection": new_data.get("requires_inspection", current_tariff.requires_inspection),
        "requires_acid": new_data.get("requires_acid", current_tariff.requires_acid),
        "regulatory_authority": new_data.get("regulatory_authority", current_tariff.regulatory_authority),
        "prior_approval_note": new_data.get("prior_approval_note", current_tariff.prior_approval_note),
        "effective_from": effective_date,
        "effective_to": new_data.get("effective_to", None),
        "source_url": new_data.get("source_url", current_tariff.source_url),
        "last_verified_date": date.today(),
        "verified_by": new_data.get("verified_by", "System Admin"),
        "confidence": new_data.get("confidence", "verified_manual"),
        "notes": new_data.get("notes", current_tariff.notes),
        "is_active": True,
    }

    new_tariff = CustomsTariff(**new_version_data)
    db.add(new_tariff)

    # BE67-T08 & ACC1-T08: Preserve preferential agreements for the new tariff version
    old_agreements = (
        db.query(PreferentialAgreement)
        .filter(
            PreferentialAgreement.hs_code == current_tariff.hs_code,
            PreferentialAgreement.effective_to == None,
        )
        .all()
    )
    for old_ag in old_agreements:
        old_ag.effective_to = current_tariff.effective_to
        new_ag = PreferentialAgreement(
            hs_code=old_ag.hs_code,
            agreement_name=old_ag.agreement_name,
            reduction_type=old_ag.reduction_type,
            reduction_percentage=old_ag.reduction_percentage,
            preferential_duty_rate=old_ag.preferential_duty_rate,
            publication_notice=old_ag.publication_notice,
            required_document=old_ag.required_document,
            origin_countries=old_ag.origin_countries,
            conditions_note=old_ag.conditions_note,
            effective_from=effective_date,
            effective_to=None,
            source_url=old_ag.source_url,
            created_by=new_data.get("verified_by", "System Admin"),
        )
        db.add(new_ag)

    db.flush()
    return new_tariff


def toggle_tariff_active(
    db: Session, tariff_id: int, is_active: bool
) -> Optional[CustomsTariff]:
    tariff = get_tariff_by_id(db, tariff_id)
    if not tariff:
        return None
    tariff.is_active = is_active
    db.flush()
    return tariff


# ==================================================
# Date-Aware Tariff Lookup (Snapshot Support)
# ==================================================

def get_active_tariff_on_date(
    db: Session, hs_code: str, on_date: date, strict: bool = True
) -> Optional[CustomsTariff]:
    """
    يرجع السجل الساري في تاريخ معين.
    يستخدم في حساب الجمارك التاريخي (Snapshot) داخل ملف الاستيراد.
    إذا كان strict=True، يرجع None فقط لو لم يوجد بند فعّال في هذا التاريخ.
    """
    clean_hs = hs_code.strip()
    nodots = clean_hs.replace(".", "")
    formatted = f"{nodots[:4]}.{nodots[4:6]}.{nodots[6:8]}" if len(nodots) in (8, 10) else clean_hs
    targets = list(dict.fromkeys([clean_hs, nodots, formatted]))
    if len(nodots) == 10:
        targets.append(f"{nodots[:4]}.{nodots[4:6]}.{nodots[6:8]}.{nodots[8:]}")

    exact = (
        db.query(CustomsTariff)
        .filter(
            CustomsTariff.hs_code.in_(targets),
            CustomsTariff.effective_from <= on_date,
            or_(
                CustomsTariff.effective_to == None,
                CustomsTariff.effective_to >= on_date,
            ),
        )
        .order_by(CustomsTariff.effective_from.desc())
        .first()
    )
    if exact:
        return exact

    if strict:
        return None

    return (
        db.query(CustomsTariff)
        .filter(
            CustomsTariff.hs_code.in_(targets),
            CustomsTariff.is_active == True,
        )
        .order_by(CustomsTariff.effective_from.desc())
        .first()
    )


# ==================================================
# Preferential Agreements CRUD (Addendum 3)
# ==================================================

from .model import FeeCode, PreferentialAgreement


def create_preferential_agreement(db: Session, data: dict) -> PreferentialAgreement:
    agreement = PreferentialAgreement(**data)
    db.add(agreement)
    db.flush()
    return agreement


def get_agreements_by_hs_code(
    db: Session, hs_code: str, origin_country: Optional[str] = None, on_date: Optional[date] = None
) -> List[PreferentialAgreement]:
    from sqlalchemy import func
    nodots = hs_code.strip().replace(".", "")
    candidates = {nodots}
    if len(nodots) == 10:
        candidates.add(nodots[:8])
    elif len(nodots) == 8:
        candidates.add(nodots + "00")
    query = db.query(PreferentialAgreement).filter(
        func.replace(PreferentialAgreement.hs_code, ".", "").in_(list(candidates))
    )
    if on_date:
        query = query.filter(
            PreferentialAgreement.effective_from <= on_date,
            or_(PreferentialAgreement.effective_to == None, PreferentialAgreement.effective_to >= on_date),
        )
    query = query.order_by(
        PreferentialAgreement.effective_from.desc(),
        PreferentialAgreement.agreement_id.desc(),
    )
    results = query.all()
    if origin_country:
        target_origin = origin_country.strip().upper()
        results = [
            ag
            for ag in results
            if target_origin
            in [c.strip().upper() for c in (ag.origin_countries or "").split(",") if c.strip()]
        ]
    return results


def get_all_tariff_versions_by_hs_code(db: Session, hs_code: str) -> List[CustomsTariff]:
    clean_hs = hs_code.strip()
    nodots = clean_hs.replace(".", "")
    from sqlalchemy import func
    return (
        db.query(CustomsTariff)
        .filter(func.replace(CustomsTariff.hs_code, '.', '') == nodots)
        .order_by(CustomsTariff.effective_from.desc(), CustomsTariff.tariff_id.desc())
        .all()
    )


def bulk_create_or_update_tariff_with_agreements(
    db: Session, tariff_data: dict, agreements_data: List[dict], update_date: Optional[date] = None
) -> Tuple[CustomsTariff, List[PreferentialAgreement]]:
    from typing import Tuple
    eff_date = update_date or date.today()
    hs_code = tariff_data["hs_code"].strip()

    existing = get_tariff_by_hs_code(db, hs_code)

    if existing:
        if existing.effective_from == eff_date:
            # Same day update: update fields of existing record in place
            for key, val in tariff_data.items():
                if val is not None and key != "hs_code":
                    setattr(existing, key, val)
            tariff = existing

            # Replace agreements created today for this version
            db.query(PreferentialAgreement).filter(
                PreferentialAgreement.hs_code == hs_code,
                PreferentialAgreement.effective_from == eff_date
            ).delete(synchronize_session=False)
        else:
            # 1. Close out previous active version as a historical snapshot
            existing.effective_to = eff_date
            existing.is_active = False

            # Close out existing agreements for old version
            old_agreements = db.query(PreferentialAgreement).filter(
                PreferentialAgreement.hs_code == hs_code,
                PreferentialAgreement.effective_to == None
            ).all()
            for old_ag in old_agreements:
                old_ag.effective_to = eff_date

            # 2. Create new active version starting from effective_date
            new_tariff_data = dict(tariff_data)
            new_tariff_data["hs_code"] = hs_code
            new_tariff_data["effective_from"] = eff_date
            new_tariff_data["effective_to"] = None
            new_tariff_data["is_active"] = True

            tariff = CustomsTariff(**new_tariff_data)
            db.add(tariff)
    else:
        # Create initial active version
        new_tariff_data = dict(tariff_data)
        new_tariff_data["hs_code"] = hs_code
        new_tariff_data["effective_from"] = eff_date
        new_tariff_data["effective_to"] = None
        new_tariff_data["is_active"] = True

        tariff = CustomsTariff(**new_tariff_data)
        db.add(tariff)

    # Create agreements linked to the active version
    created_agreements = []
    for ag_dict in agreements_data:
        ag_data = dict(ag_dict)
        ag_data["hs_code"] = hs_code
        ag_data["effective_from"] = eff_date
        ag_data["effective_to"] = None
        ag = PreferentialAgreement(**ag_data)
        db.add(ag)
        created_agreements.append(ag)

    db.flush()
    return tariff, created_agreements


# ==================================================
# Fee Codes Repository (Nafeza Statement Registry)
# ==================================================

def get_all_fee_codes(db: Session, include_inactive: bool = False) -> List[FeeCode]:
    query = db.query(FeeCode)
    if not include_inactive:
        query = query.filter(FeeCode.is_active == True)
    return query.order_by(FeeCode.fee_code_id).all()


def get_active_fee_codes(db: Session, on_date: Optional[date] = None) -> List[FeeCode]:
    target_date = on_date or date.today()
    return (
        db.query(FeeCode)
        .filter(
            FeeCode.is_active == True,
            FeeCode.effective_from <= target_date,
            or_(
                FeeCode.effective_to == None,
                FeeCode.effective_to >= target_date,
            ),
        )
        .order_by(FeeCode.fee_code_id)
        .all()
    )


def get_fee_code_by_code(db: Session, code: str) -> Optional[FeeCode]:
    return db.query(FeeCode).filter(FeeCode.code == code.strip()).first()


def create_fee_code(db: Session, data: dict) -> FeeCode:
    fc = FeeCode(**data)
    db.add(fc)
    db.flush()
    return fc




# ==================================================
# Trade remedy measures
# ==================================================

def get_trade_remedy_measure(db: Session, measure_id: int, include_inactive: bool = False) -> Optional[TradeRemedyMeasure]:
    query = db.query(TradeRemedyMeasure).filter(TradeRemedyMeasure.measure_id == measure_id)
    if not include_inactive:
        query = query.filter(TradeRemedyMeasure.is_active == True)
    return query.first()


def list_trade_remedy_measures(
    db: Session,
    hs_code: Optional[str] = None,
    origin_country: Optional[str] = None,
    measure_type: Optional[str] = None,
    include_inactive: bool = False,
) -> List[TradeRemedyMeasure]:
    query = db.query(TradeRemedyMeasure)
    if not include_inactive:
        query = query.filter(TradeRemedyMeasure.is_active == True)
    if hs_code:
        query = query.filter(TradeRemedyMeasure.hs_code.like(f"{hs_code.strip().replace('.', '')}%"))
    if origin_country:
        query = query.filter(TradeRemedyMeasure.origin_country == origin_country.strip().upper())
    if measure_type:
        query = query.filter(TradeRemedyMeasure.measure_type == measure_type)
    return query.order_by(TradeRemedyMeasure.hs_code, TradeRemedyMeasure.effective_from.desc()).all()


def list_trade_remedy_measures_for_key(
    db: Session, measure_type: str, hs_code: str, origin_country: Optional[str], exporter_name: Optional[str]
) -> List[TradeRemedyMeasure]:
    query = db.query(TradeRemedyMeasure).filter(
        TradeRemedyMeasure.is_active == True,
        TradeRemedyMeasure.measure_type == measure_type,
        TradeRemedyMeasure.hs_code == hs_code,
    )
    query = query.filter(
        TradeRemedyMeasure.origin_country == origin_country
        if origin_country else TradeRemedyMeasure.origin_country.is_(None)
    )
    query = query.filter(
        TradeRemedyMeasure.exporter_name == exporter_name
        if exporter_name else TradeRemedyMeasure.exporter_name.is_(None)
    )
    return query.all()


def find_effective_trade_remedy_measures(db: Session, hs_code: str, on_date: date) -> List[TradeRemedyMeasure]:
    """Active measures in force on ``on_date`` whose HS code is a prefix of ``hs_code`` (origin filtered later)."""
    from sqlalchemy import literal

    nodots = (hs_code or "").strip().replace(".", "")
    return (
        db.query(TradeRemedyMeasure)
        .filter(
            TradeRemedyMeasure.is_active == True,
            literal(nodots).like(TradeRemedyMeasure.hs_code + "%"),
            TradeRemedyMeasure.effective_from <= on_date,
            or_(TradeRemedyMeasure.effective_to == None, TradeRemedyMeasure.effective_to >= on_date),
        )
        .all()
    )
