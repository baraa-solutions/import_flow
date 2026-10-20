from datetime import date, datetime, timedelta, timezone
from typing import List, Optional, Tuple, Dict, Any, Union
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from .model import CustomsAbandonmentRadar
from .schemas import (
    CustomsAbandonmentRadarCreate,
    CustomsAbandonmentRadarUpdate,
    ExtensionRequestCreate,
    ExtensionGrantCreate,
    ExtensionLetterDraftResponse,
    CustomsAbandonmentSummaryResponse,
    RecalculateResponse,
)
from .repository import CustomsAbandonmentRepository
from .validators import (
    normalize_port_type,
    validate_risk_level,
    validate_abandonment_status,
    parse_date,
)
from modules.import_files.model import ImportFile


def evaluate_abandonment_risk(
    port_type: str,
    arrival_date: Union[date, datetime, str],
    current_date: Optional[Union[date, datetime, str]] = None,
    extension_granted_until: Optional[Union[date, datetime, str]] = None,
) -> Tuple[int, int, int, str]:
    """
    Evaluates statutory abandonment risk metrics under Egyptian Customs Law 207/2020 Art. 67:
      - Seaports: 60 days
      - Dry ports & Airports: 30 days
    Returns:
      (max_legal_days, days_in_port, days_remaining, risk_level)
    """
    norm_type = normalize_port_type(port_type)
    arr_date = parse_date(arrival_date)
    curr_date = parse_date(current_date) or date.today()
    ext_date = parse_date(extension_granted_until)

    if not arr_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Valid arrival_date is required.",
        )

    # Base statutory duration per Art. 67
    base_max = 60 if norm_type == "SEAPORT" else 30
    
    # If official extension granted past the base limit
    if ext_date and ext_date > arr_date:
        extended_days = (ext_date - arr_date).days
        max_legal_days = max(base_max, extended_days)
    else:
        max_legal_days = base_max

    # Elapsed days in yard (cannot be negative)
    days_in_port = max(0, (curr_date - arr_date).days)
    days_remaining = max_legal_days - days_in_port

    # Risk Level mapping:
    # NORMAL (>15 days), WARNING_15_DAYS (8-15 days), CRITICAL_7_DAYS (1-7 days), UNDER_ABANDONMENT_INVENTORY (<=0 days)
    if days_remaining <= 0:
        risk_level = "UNDER_ABANDONMENT_INVENTORY"
    elif days_remaining <= 7:
        risk_level = "CRITICAL_7_DAYS"
    elif days_remaining <= 15:
        risk_level = "WARNING_15_DAYS"
    else:
        risk_level = "NORMAL"

    return max_legal_days, days_in_port, days_remaining, risk_level


def create_radar_service(
    db: Session,
    payload: CustomsAbandonmentRadarCreate,
    user: str = "System",
) -> CustomsAbandonmentRadar:
    norm_type = normalize_port_type(payload.port_type)
    max_days, days_in, days_rem, risk = evaluate_abandonment_risk(
        port_type=norm_type,
        arrival_date=payload.arrival_date,
    )

    radar_obj = CustomsAbandonmentRadar(
        import_file_id=payload.import_file_id,
        import_file_code=payload.import_file_code.strip().upper(),
        port_type=norm_type,
        port_name=payload.port_name or ("Alexandria Port" if norm_type == "SEAPORT" else "Cairo Cargo Terminal"),
        arrival_date=payload.arrival_date,
        max_legal_days=max_days,
        days_in_port=days_in,
        days_remaining=days_rem,
        risk_level=risk,
        abandonment_status="ACTIVE_CLEARING",
        importer_name=payload.importer_name,
        cargo_description=payload.cargo_description,
        customs_declaration_no=payload.customs_declaration_no,
        bl_number=payload.bl_number,
        acid_number=payload.acid_number,
        container_numbers=payload.container_numbers,
        notes=payload.notes,
        created_by=user,
        updated_by=user,
    )
    return CustomsAbandonmentRepository.create_radar(db, radar_obj)


def list_radars_service(
    db: Session,
    risk_level: Optional[str] = None,
    abandonment_status: Optional[str] = None,
    port_type: Optional[str] = None,
    search: Optional[str] = None,
    is_active: bool = True,
    skip: int = 0,
    limit: int = 100,
) -> Tuple[List[CustomsAbandonmentRadar], int]:
    if risk_level:
        risk_level = validate_risk_level(risk_level)
    if abandonment_status:
        abandonment_status = validate_abandonment_status(abandonment_status)
    if port_type:
        port_type = normalize_port_type(port_type)

    return CustomsAbandonmentRepository.list_radars(
        db,
        risk_level=risk_level,
        abandonment_status=abandonment_status,
        port_type=port_type,
        search=search,
        is_active=is_active,
        skip=skip,
        limit=limit,
    )


def get_radar_by_id_service(db: Session, radar_id: int) -> CustomsAbandonmentRadar:
    radar = CustomsAbandonmentRepository.get_radar(db, radar_id)
    if not radar:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Customs abandonment radar record not found.")
    return radar


def update_radar_service(
    db: Session,
    radar_id: int,
    payload: CustomsAbandonmentRadarUpdate,
    user: str = "System",
) -> CustomsAbandonmentRadar:
    updates = payload.model_dump(exclude_unset=True)
    if "port_type" in updates and updates["port_type"]:
        updates["port_type"] = normalize_port_type(updates["port_type"])
    if "risk_level" in updates and updates["risk_level"]:
        updates["risk_level"] = validate_risk_level(updates["risk_level"])
    if "abandonment_status" in updates and updates["abandonment_status"]:
        updates["abandonment_status"] = validate_abandonment_status(updates["abandonment_status"])
        
    updates["updated_by"] = user
    radar = CustomsAbandonmentRepository.update_radar(db, radar_id, updates)
    if not radar:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Customs abandonment radar record not found.")
    return radar


def delete_radar_service(db: Session, radar_id: int, user: str = "System") -> bool:
    success = CustomsAbandonmentRepository.delete_radar(db, radar_id, user)
    if not success:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Customs abandonment radar record not found.")
    return True


def recalculate_open_files_service(db: Session, current_date: Optional[date] = None) -> RecalculateResponse:
    """
    Recalculates countdown metrics for all active radars and syncs from open import files.
    """
    calc_date = current_date or date.today()
    active_radars = CustomsAbandonmentRepository.get_all_active_radars(db)
    updated_count = 0

    critical_count = 0
    warning_count = 0
    inventory_count = 0
    normal_count = 0

    for radar in active_radars:
        max_days, days_in, days_rem, risk = evaluate_abandonment_risk(
            port_type=radar.port_type,
            arrival_date=radar.arrival_date,
            current_date=calc_date,
            extension_granted_until=radar.extension_granted_until,
        )
        radar.max_legal_days = max_days
        radar.days_in_port = days_in
        radar.days_remaining = days_rem
        radar.risk_level = risk
        
        # If past deadline and not yet resolved/warehouse, escalate status
        if days_rem <= 0 and radar.abandonment_status in ("ACTIVE_CLEARING", "EXTENSION_PENDING"):
            radar.abandonment_status = "MOVED_TO_ABANDONED_WAREHOUSE"

        radar.updated_at = datetime.now(timezone.utc)
        updated_count += 1

        if risk == "CRITICAL_7_DAYS":
            critical_count += 1
        elif risk == "WARNING_15_DAYS":
            warning_count += 1
        elif risk == "UNDER_ABANDONMENT_INVENTORY":
            inventory_count += 1
        else:
            normal_count += 1

    # Optional: discover active import files that don't have a radar entry yet
    open_files = db.query(ImportFile).filter(
        ImportFile.is_active == True,
        ImportFile.status.in_(["Open", "In Progress"]),
        ImportFile.is_customs_released == False,
    ).all()

    existing_file_ids = {r.import_file_id for r in active_radars if r.import_file_id is not None}

    for f in open_files:
        if f.import_file_id not in existing_file_ids:
            # Determine arrival date: required_eta or file_opening_date or today - 5 days
            arr_date = f.required_eta or f.file_opening_date or (calc_date - timedelta(days=5))
            port_type = "AIRPORT" if "AIR" in (f.shipment_mode or "").upper() else "SEAPORT"
            max_days, days_in, days_rem, risk = evaluate_abandonment_risk(
                port_type=port_type,
                arrival_date=arr_date,
                current_date=calc_date,
            )
            new_radar = CustomsAbandonmentRadar(
                import_file_id=f.import_file_id,
                import_file_code=f.import_file_code,
                port_type=port_type,
                port_name=f.port_of_discharge or "Egyptian Port",
                arrival_date=arr_date,
                max_legal_days=max_days,
                days_in_port=days_in,
                days_remaining=days_rem,
                risk_level=risk,
                importer_name=f.company_name,
                cargo_description=f.product_category,
                bl_number=f.bl_number,
                acid_number=f.acid_number,
                abandonment_status="ACTIVE_CLEARING",
                created_by="RecalculateEngine",
                updated_by="RecalculateEngine",
            )
            db.add(new_radar)
            updated_count += 1
            if risk == "CRITICAL_7_DAYS":
                critical_count += 1
            elif risk == "WARNING_15_DAYS":
                warning_count += 1
            elif risk == "UNDER_ABANDONMENT_INVENTORY":
                inventory_count += 1
            else:
                normal_count += 1

    db.commit()

    return RecalculateResponse(
        total_evaluated=len(active_radars) + len(open_files),
        updated_records=updated_count,
        critical_count=critical_count,
        warning_count=warning_count,
        inventory_count=inventory_count,
        normal_count=normal_count,
        evaluated_at=datetime.now(timezone.utc),
    )


def request_extension_service(
    db: Session,
    radar_id: int,
    payload: ExtensionRequestCreate,
    user: str = "System",
) -> CustomsAbandonmentRadar:
    radar = get_radar_by_id_service(db, radar_id)
    radar.extension_requested = True
    radar.extension_request_date = date.today()
    radar.extension_reason = payload.reason
    radar.extension_request_ref = payload.extension_request_ref or f"EXT-REQ-{radar.import_file_code}-{int(datetime.now().timestamp())}"
    radar.action_plan = payload.action_plan
    radar.abandonment_status = "EXTENSION_PENDING"
    radar.updated_by = user
    radar.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(radar)
    return radar


def grant_extension_service(
    db: Session,
    radar_id: int,
    payload: ExtensionGrantCreate,
    user: str = "System",
) -> CustomsAbandonmentRadar:
    radar = get_radar_by_id_service(db, radar_id)
    if payload.extension_granted_until <= radar.arrival_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Granted extension date must be after arrival date.",
        )

    radar.extension_granted_until = payload.extension_granted_until
    radar.abandonment_status = "ACTIVE_CLEARING"
    if payload.notes:
        radar.notes = f"{radar.notes}\n[Extension Approval]: {payload.notes}".strip() if radar.notes else payload.notes

    # Recalculate risk immediately
    max_days, days_in, days_rem, risk = evaluate_abandonment_risk(
        port_type=radar.port_type,
        arrival_date=radar.arrival_date,
        extension_granted_until=radar.extension_granted_until,
    )
    radar.max_legal_days = max_days
    radar.days_in_port = days_in
    radar.days_remaining = days_rem
    radar.risk_level = risk
    radar.updated_by = user
    radar.updated_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(radar)
    return radar


def resolve_radar_service(
    db: Session,
    radar_id: int,
    user: str = "System",
) -> CustomsAbandonmentRadar:
    radar = get_radar_by_id_service(db, radar_id)
    radar.abandonment_status = "RESOLVED_RELEASED"
    radar.risk_level = "NORMAL"
    radar.updated_by = user
    radar.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(radar)
    return radar


def generate_extension_letter_draft(
    db: Session,
    radar_id: int,
    requested_days: int = 30,
    reason: Optional[str] = None,
    current_date: Optional[date] = None,
) -> ExtensionLetterDraftResponse:
    """
    Generates official petition draft to the Egyptian Customs Central Administration / Director General
    pursuant to Article 67 of Egyptian Customs Law No. 207 of 2020.
    """
    radar = get_radar_by_id_service(db, radar_id)
    today_dt = current_date or date.today()
    letter_ref = f"CUST-EXT/{radar.import_file_code}/{today_dt.strftime('%Y%m%d')}"
    
    port_title = radar.port_name or ("ميناء الإسكندرية البحري" if radar.port_type == "SEAPORT" else "قرية البضائع بمطار القاهرة")
    importer = radar.importer_name or "الشركة المستوردة"
    bl_no = radar.bl_number or "غير محدد"
    dec_no = radar.customs_declaration_no or "تحت القيد"
    acid = radar.acid_number or "غير متوفر"
    op_reason = reason or radar.extension_reason or "استيفاء الموافقات والاشتراطات الرقابية وفحص العينات بالهيئة العامة للرقابة على الصادرات والواردات (GOIEC)"

    recipient = f"السيد الأستاذ / رئيس الإدارة المركزية لجمارك {port_title}"
    subject = f"طلب مد مهلة بقاء البضائع بالميناء (مهمل) طبقاً للمادة (67) من قانون الجمارك رقم 207 لسنة 2020 — ملف: {radar.import_file_code}"

    formal_body_ar = f"""بسم الله الرحمن الرحيم

التاريخ: {today_dt.strftime('%Y/%m/%d')}
مرجع الخطاب: {letter_ref}

{recipient}
تحية طيبة وبعد،،،

الموضوع: {subject}

إيماءً إلى أحكام قانون الجمارك المصري رقم 207 لسنة 2020 ولائحته التنفيذية، ولا سيما المادة (67) المنظمة للمدد القانونية لبقاء البضائع في ساحات ومخازن الموانئ الجمركية وقواعد إحالتها إلى مستودعات المهمل؛

نحيط سيادتكم علماً بأن الشحنة الواردة باسم السادة / {importer}، والمشمولة بالبيانات الجمركية الآتية:
• رقم ملف العملية: {radar.import_file_code}
• رقم بوليصة الشحن (B/L): {bl_no}
• رقم القيد الجمركي / الشهادة (نموذج 46): {dec_no}
• الرقم التعريفي المسبق للشحنة (ACID): {acid}
• تاريخ الوصول والتفريغ: {radar.arrival_date.strftime('%Y/%m/%d')}
• وصف المشمل والبضاعة: {radar.cargo_description or 'بضائع عامة / معدات صناعية'}
• الأيام المنقضية بالدائرة الجمركية: {radar.days_in_port} يوماً (المهلة القانونية: {radar.max_legal_days} يوماً)

وحيث أن إجراءات التخليص الجمركي واستكمال الإفراج النهائي جارية حالياً على قدم وساق، وحيث أن التأخير ناتج عن أسباب إجرائية خارجة عن إرادة المستورد تتمثل في:
«{op_reason}»؛

لذا، نلتمس من سيادتكم التفضل بالموافقة الكريمة على منحنا مهلة إضافية مدتها ({requested_days}) يوماً تبدأ من تاريخ انتهاء المهلة الحالية، وعدم إحالة مشمول الرسالة إلى قائمة جرد المهمل أو مستودعات البيع بالمزاد العلني، وذلك لتمكيننا من إنهاء الإجراءات وسداد الرسوم الجمركية والضريبية المستحقة لخزينة الدولة واستلام المشمول.

مستعدون لتقديم كافة الضمانات والتعهدات اللازمة في هذا الشأن.

وتفضلوا بقبول فائق الاحترام والتقدير،،،

مقدمه لسيادتكم:
السادة / {importer}
عنهم / المستخلص الجمركي المعتمد
التوقيع والختم: ........................................
"""

    radar.official_letter_issued = True
    db.commit()

    return ExtensionLetterDraftResponse(
        letter_ref=letter_ref,
        letter_date=today_dt,
        recipient_title=recipient,
        importer_name=importer,
        import_file_code=radar.import_file_code,
        port_name=port_title,
        subject=subject,
        formal_body_ar=formal_body_ar.strip(),
        legal_basis="Egyptian Customs Law No. 207 of 2020, Article 67",
        metadata={
            "radar_id": radar.radar_id,
            "days_in_port": radar.days_in_port,
            "days_remaining": radar.days_remaining,
            "risk_level": radar.risk_level,
            "requested_days": requested_days,
            "bl_number": bl_no,
            "acid_number": acid,
        },
    )


def get_customs_abandonment_summary_service(db: Session) -> CustomsAbandonmentSummaryResponse:
    summary = CustomsAbandonmentRepository.get_summary(db)
    return CustomsAbandonmentSummaryResponse(**summary)
