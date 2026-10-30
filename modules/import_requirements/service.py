import logging
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

from sqlalchemy.orm import Session
from modules.import_requirements.schemas import (
    ImportRequirementCreate,
    ImportRequirementUpdate,
    ImportRequirementPrefillResponse,
    ImportRequirementHSCodeItem,
)
from modules.import_requirements import repository as repo
from modules.import_requirements.validators import (
    validate_no_active_assessment_for_file,
    validate_overall_status,
    validate_required_fields_not_null,
    validate_requirement_currency,
    validate_risk_level,
    validate_shipment_value,
)
from modules.import_files.model import ImportFile
from modules.purchase_orders.model import PurchaseOrder
from modules.customs_consultation.model import CustomsConsultationSession
from modules.customs_tariff.model import CustomsTariff
from modules.common import enum_codes
from modules.common.errors import best_effort
from modules.common.system_messages import SystemMessageItem, SysMsg, msg, render_en, to_item
from modules.common.validators import get_or_404
from modules.import_requirements.model import ImportRequirementAssessment
from modules.common.file_tracking import set_file_tracking
from modules.customs_consultation.repository import CustomsConsultationRepository
from modules.customs_tariff.repository import get_tariff_by_hs_code
from modules.suppliers.repository import get_supplier_by_id

logger = logging.getLogger(__name__)

# Verbatim placeholder for a not-yet-issued ACID inside message params (params never carry translated text).
ACID_PENDING_PLACEHOLDER = "PENDING"


def _requirement_item(req_type: str, priority: str, code: str, **params: object) -> dict:
    """One pending regulatory requirement: English title/description plus the system message code."""
    m: SysMsg = msg(code, **params)
    return {
        "type": req_type,
        "title": render_en(m.code, m.params, "title"),
        "desc": render_en(m.code, m.params, "body"),
        "priority": priority,
        "msg": m,
    }


def sync_regulatory_tasks_and_alerts(db: Session, assessment_id: int):
    """
    Business Rule & Smart Tasks Sync:
    1. Identify all uncompleted/pending regulatory requirements across the 5 pillars.
    2. Generate/Update Smart Tasks for incomplete regulatory requirements for this Import File (linking ACID if present).
    3. Auto-close tasks if requirements become Verified/Approved.
    4. Auto-update ImportFile next_action and stage progression.
    """
    assessment = repo.get_assessment_by_id(db, assessment_id)
    if not assessment:
        return

    import_file = None
    if assessment.import_file_id:
        import_file = db.get(ImportFile, assessment.import_file_id)

    file_code = import_file.import_file_code if import_file else None
    acid_str = assessment.acid_number or (import_file.acid_number if import_file else None) or ACID_PENDING_PLACEHOLDER

    # If import_file has an acid_number but assessment doesn't, sync it
    if import_file and import_file.acid_number and not assessment.acid_number:
        assessment.acid_number = import_file.acid_number

    # Identify uncompleted / pending items
    uncompleted = []
    completed = []

    # Identify uncompleted / pending items per HS Code or globally
    uncompleted = []
    completed = []

    hs_items = assessment.hs_code_items or []
    if isinstance(hs_items, list) and len(hs_items) > 0:
        for itm in hs_items:
            hs = itm.get("hs_code") or "General"
            
            # 1. Decree 43 per HS Code
            if itm.get("decree_43_applicable"):
                if itm.get("white_list_verified"):
                    completed.append(f"Decree43_{hs}")
                elif itm.get("decree_43_action") == "justified" or (itm.get("decree_43_justification") and itm.get("decree_43_justification").strip()):
                    completed.append(f"Decree43_{hs}")
                else:
                    uncompleted.append(_requirement_item(
                        f"Decree43_{hs}", "Critical", "REQ_TASK_DECREE43_HS",
                        import_file_code=file_code, hs_code=hs, acid_number=acid_str,
                    ))

            # 2. Certificate of Origin per HS Code
            if itm.get("coo_required"):
                c_status = itm.get("coo_status") or "Not Required"
                if c_status in ["Verified", "Approved", "Received", "Obtained"]:
                    completed.append(f"COO_{hs}")
                else:
                    c_type = itm.get("coo_type") or "COO"
                    uncompleted.append(_requirement_item(
                        f"COO_{hs}", "High", "REQ_TASK_COO_HS",
                        import_file_code=file_code, hs_code=hs, acid_number=acid_str,
                        certificate_type=c_type,
                        status_enum_requirement_status=enum_codes.normalize(enum_codes.REQUIREMENT_STATUS, c_status),
                    ))

            # 3. Pre-Shipment Inspection per HS Code
            if itm.get("inspection_required"):
                i_status = itm.get("inspection_status") or "Not Required"
                if i_status in ["Verified", "Approved", "Received", "Completed", "Obtained"]:
                    completed.append(f"Inspection_{hs}")
                else:
                    i_body = itm.get("inspection_body") or "GOEIC"
                    uncompleted.append(_requirement_item(
                        f"Inspection_{hs}", "Critical", "REQ_TASK_INSPECTION_HS",
                        import_file_code=file_code, hs_code=hs, acid_number=acid_str, authority_enum_regulatory_body=enum_codes.normalize(enum_codes.REGULATORY_BODY, i_body),
                    ))

            # 4. Regulatory Permits per HS Code
            if itm.get("permit_required"):
                p_status = itm.get("permit_status") or "Not Required"
                if p_status in ["Verified", "Approved", "Received", "Obtained"]:
                    completed.append(f"Permit_{hs}")
                else:
                    p_auth = itm.get("regulatory_authority") or "Regulatory authority"
                    uncompleted.append(_requirement_item(
                        f"Permit_{hs}", "Critical", "REQ_TASK_PERMIT_HS",
                        import_file_code=file_code, hs_code=hs, acid_number=acid_str, authority_enum_regulatory_body=enum_codes.normalize(enum_codes.REGULATORY_BODY, p_auth),
                    ))

    # Global / Assessment-level fallback if hs_code_items is empty
    if not uncompleted and not completed:
        # 1. Decree 43
        if assessment.decree_43_applicable:
            if not assessment.white_list_verified:
                uncompleted.append(_requirement_item(
                    "Decree43", "Critical", "REQ_TASK_DECREE43",
                    import_file_code=file_code, acid_number=acid_str,
                ))
            else:
                completed.append("Decree43")

        # 2. Certificate of Origin
        if assessment.coo_required:
            if assessment.coo_status not in ["Verified", "Approved", "Received", "Obtained"]:
                raw_coo = (assessment.coo_type or "COO").strip()
                clean_coo = raw_coo.replace("(", "").replace(")", "").replace("—", "-").strip()
                uncompleted.append(_requirement_item(
                    "COO", "High", "REQ_TASK_COO",
                    import_file_code=file_code, acid_number=acid_str, status_enum_requirement_status=enum_codes.normalize(
                        enum_codes.REQUIREMENT_STATUS, assessment.coo_status
                    ),
                ))
            else:
                completed.append("COO")

        # 3. Pre-Shipment Inspection
        if assessment.inspection_required:
            if assessment.inspection_status not in ["Verified", "Approved", "Received", "Completed", "Obtained"]:
                raw_insp = (assessment.inspection_body or "GOEIC").strip()
                clean_insp = raw_insp.replace("(", "").replace(")", "").strip()
                if "GOEIC" in clean_insp or "الصادرات والواردات" in clean_insp:
                    insp_display = "GOEIC"
                else:
                    insp_display = clean_insp or "Approved inspection body"
                uncompleted.append(_requirement_item(
                    "Inspection", "Critical", "REQ_TASK_INSPECTION",
                    import_file_code=file_code, acid_number=acid_str, authority_enum_regulatory_body=enum_codes.normalize(enum_codes.REGULATORY_BODY, insp_display),
                ))
            else:
                completed.append("Inspection")

        # 4. Import Permit / Regulatory Approvals
        if assessment.import_permit_required:
            if assessment.permit_status not in ["Verified", "Approved", "Received", "Obtained"]:
                raw_permit = (assessment.permit_issuing_authority or "Regulatory authority").strip()
                clean_permit = raw_permit.replace("(", "").replace(")", "").strip()
                uncompleted.append(_requirement_item(
                    "Permit", "Critical", "REQ_TASK_PERMIT",
                    import_file_code=file_code, acid_number=acid_str, authority_enum_regulatory_body=enum_codes.normalize(enum_codes.REGULATORY_BODY, clean_permit),
                ))
            else:
                completed.append("Permit")

    # 5. Technical Documents
    if assessment.msds_required:
        if assessment.msds_status not in ["Verified", "Approved", "Received", "Obtained"]:
            uncompleted.append(_requirement_item(
                "MSDS", "Medium", "REQ_TASK_MSDS", import_file_code=file_code, acid_number=acid_str,
            ))
        else:
            completed.append("MSDS")

    if assessment.halal_cert_required:
        if assessment.halal_cert_status not in ["Verified", "Approved", "Received", "Obtained"]:
            uncompleted.append(_requirement_item(
                "Halal", "High", "REQ_TASK_HALAL", import_file_code=file_code, acid_number=acid_str,
            ))
        else:
            completed.append("Halal")

    if assessment.coa_required:
        if assessment.coa_status not in ["Verified", "Approved", "Received", "Obtained"]:
            uncompleted.append(_requirement_item(
                "COA", "Medium", "REQ_TASK_COA", import_file_code=file_code, acid_number=acid_str,
            ))
        else:
            completed.append("COA")

    # Manage SmartTasks in DB
    from modules.smart_tasks.model import SmartTask
    import modules.smart_tasks.repository as task_repo
    from modules.smart_tasks.schemas import SmartTaskCreate

    # 1. Create or ensure uncompleted tasks exist
    for item in uncompleted:
        escaped_type = str(item["type"]).replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
        existing_task = db.query(SmartTask).filter(
            SmartTask.import_file_id == assessment.import_file_id,
            SmartTask.notes.like(f"%REQ_TYPE:{escaped_type}|%", escape="\\"),
            SmartTask.is_active == True,
            SmartTask.status.in_(["Pending", "In Progress"]),
        ).first()

        if not existing_task:
            task_schema = SmartTaskCreate(
                title=item["title"],
                description=item["desc"],
                task_type="Regulatory Compliance",
                import_file_id=assessment.import_file_id,
                import_file_code=file_code,
                phase_name="STEP_03: Import Regulatory Requirements",
                assigned_user=import_file.owner if import_file and import_file.owner else None,
                priority=item["priority"],
                reminder_type="Regulatory Compliance",
                status="Pending",
                due_date=None,
                notes=f"REQ_TYPE:{item['type']}| ASSESSMENT:{assessment.assessment_code}",
            )
            task_repo.create_task(
                db, task_schema, created_by="Requirements Engine",
                msg_code=item["msg"].code, msg_params=item["msg"].params, step_code="STEP_03",
            )
        else:
            existing_task.title = item["title"]
            existing_task.msg_code = item["msg"].code
            existing_task.msg_params = item["msg"].params

    # 2. Auto-close completed requirements tasks
    for c_type in completed:
        escaped_c = str(c_type).replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
        open_tasks = db.query(SmartTask).filter(
            SmartTask.import_file_id == assessment.import_file_id,
            SmartTask.notes.like(f"%REQ_TYPE:{escaped_c}|%", escape="\\"),
            SmartTask.is_active == True,
            SmartTask.status.in_(["Pending", "In Progress"]),
        ).all()
        for t in open_tasks:
            t.status = "Completed"
            t.is_auto_closed = True

    # 3. Synchronize ImportFile next action and stage activity
    if import_file:
        from modules.lifecycle_board.service import sync_requirements_lifecycle_stage
        import modules.lifecycle_board.repository as lifecycle_repo

        if len(uncompleted) == 0 and assessment.overall_status in ["Complete", "Approved", "Cleared", "Confirmed"]:
            # Complete STEP_03 and move to STEP_04
            lifecycle_repo.save_or_update_activity(
                db,
                import_file_code=file_code,
                step_code="STEP_03",
                status="Completed",
                completed_at=datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S"),
            )
            lifecycle_repo.save_or_update_activity(
                db,
                import_file_code=file_code,
                step_code="STEP_04",
                status="In-Progress",
                started_at=datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S"),
            )
            set_file_tracking(
                import_file,
                step_code="STEP_04",
                next_action=msg("NA_STEP04_COMPLETE_PAYMENT_REQUEST_ACID"),
            )
            import_file.progress_percent = max(float(import_file.progress_percent or 0), 30.0)
        else:
            # Mark STEP_01 and STEP_02 as Completed, and STEP_03 as In-Progress
            sync_requirements_lifecycle_stage(db, assessment.import_file_id)
            req_names = [r["type"] for r in uncompleted]
            req_display = ", ".join(req_names[:3])
            set_file_tracking(
                import_file,
                next_action=msg("NA_PENDING_REGULATORY_REQUIREMENTS", count=len(uncompleted), requirements=req_display),
            )


# ==============================================================================
# CRUD
# ==============================================================================

ASSESSMENT_LABEL = "دراسة متطلبات الاستيراد"


def _check_one_per_file(
    db: Session, import_file_id: int, file_code: Optional[str], assessment_id: Optional[int] = None
) -> None:
    existing = repo.get_assessment_by_import_file(db, import_file_id)
    if existing is not None and existing.assessment_id != assessment_id:
        validate_no_active_assessment_for_file(existing, file_code or str(import_file_id))


def _sync_tasks_safely(db: Session, assessment_id: int) -> None:
    """Smart tasks / stage follow-up. A failure is logged and never undoes the saved assessment."""
    def _run() -> None:
        sync_regulatory_tasks_and_alerts(db, assessment_id)
        db.commit()

    best_effort(db, _run, f"Regulatory requirement sync for assessment {assessment_id}")


def create_assessment_service(db: Session, payload: ImportRequirementCreate, user: str = "System"):
    validate_risk_level(payload.risk_level)
    validate_overall_status(payload.overall_status)
    validate_shipment_value(payload.shipment_value_usd)
    price = float(payload.shipment_value or 0.0)
    payload.currency = validate_requirement_currency(db, price, payload.currency)
    if payload.import_file_id:
        _check_one_per_file(db, payload.import_file_id, payload.import_file_code)

    now = datetime.now(timezone.utc)
    obj_data = payload.model_dump()
    obj_data.update(
        assessment_code=repo.generate_assessment_code(db),
        created_at=now,
        updated_at=now,
        created_by=user,
        updated_by=user,
    )
    created = repo.create_assessment(db, obj_data)
    db.commit()
    db.refresh(created)
    _sync_tasks_safely(db, created.assessment_id)
    return created


def update_assessment_service(db: Session, assessment_id: int, payload: ImportRequirementUpdate, user: str = "System"):
    obj = get_or_404(db, ImportRequirementAssessment, assessment_id, ASSESSMENT_LABEL)
    # Only the fields the client sent: an explicit null clears an optional field.
    update_data = payload.model_dump(exclude_unset=True)
    validate_required_fields_not_null(update_data)
    if "risk_level" in update_data:
        validate_risk_level(update_data["risk_level"])
    if "overall_status" in update_data:
        validate_overall_status(update_data["overall_status"])
    if "shipment_value_usd" in update_data:
        validate_shipment_value(update_data["shipment_value_usd"])
    if "shipment_value" in update_data or "currency" in update_data:
        eff_price = update_data.get("shipment_value") if "shipment_value" in update_data else getattr(obj, "shipment_value", 0.0)
        eff_curr = update_data.get("currency") if "currency" in update_data else getattr(obj, "currency", None)
        norm_curr = validate_requirement_currency(db, eff_price, eff_curr)
        if "currency" in update_data:
            update_data["currency"] = norm_curr
    file_id = update_data.get("import_file_id") or obj.import_file_id
    # An update reactivates a soft-deleted assessment: the one-per-file rule applies then too.
    if file_id and (file_id != obj.import_file_id or not obj.is_active):
        _check_one_per_file(db, file_id, update_data.get("import_file_code") or obj.import_file_code, assessment_id)
    update_data["updated_at"] = datetime.now(timezone.utc)
    update_data["updated_by"] = user
    updated = repo.update_assessment(db, obj, update_data)
    db.commit()
    db.refresh(updated)
    _sync_tasks_safely(db, updated.assessment_id)
    return updated


def restore_assessment_service(db: Session, assessment_id: int, user: str = "System"):
    obj = get_or_404(db, ImportRequirementAssessment, assessment_id, ASSESSMENT_LABEL)
    if obj.import_file_id and not obj.is_active:
        _check_one_per_file(db, obj.import_file_id, obj.import_file_code, assessment_id)
    restored = repo.restore_assessment(db, obj, user)
    db.commit()
    db.refresh(restored)
    _sync_tasks_safely(db, restored.assessment_id)
    return restored


def get_all_assessments_service(
    db: Session,
    import_file_id: Optional[int] = None,
    overall_status: Optional[str] = None,
    risk_level: Optional[str] = None,
    search: Optional[str] = None,
    include_inactive: bool = False,
):
    return repo.get_all_assessments(
        db, import_file_id=import_file_id, overall_status=overall_status,
        risk_level=risk_level, search=search, include_inactive=include_inactive,
    )


def get_assessment_by_id_service(db: Session, assessment_id: int):
    return get_or_404(db, ImportRequirementAssessment, assessment_id, ASSESSMENT_LABEL, active_only=True)


def soft_delete_assessment_service(db: Session, assessment_id: int, user: str = "System") -> None:
    repo.soft_delete_assessment(db, get_or_404(db, ImportRequirementAssessment, assessment_id, ASSESSMENT_LABEL, active_only=True), user)
    db.commit()


# ==============================================================================
# Prefill (BP-011): read-only extraction, never fabricates customs data
# ==============================================================================

NOT_REQUIRED = "Not Required"

# Prefill message codes (ImportRequirementPrefillResponse.messages).
PREFILL_NO_HS = "PREFILL_NO_HS"
PREFILL_LINE_NO_HS = "PREFILL_LINE_NO_HS"
PREFILL_MIXED_CURRENCY = "PREFILL_MIXED_CURRENCY"

# Decree 43 (factory registration) is administered by GOEIC. There is no tariff flag column yet
# (backlog): detection uses the REGULATORY_BODY code of the tariff authority / checklist agency.
DECREE_43_BODY = "GOEIC"


def _body_code(text: Optional[str]) -> Optional[str]:
    """REGULATORY_BODY code of a free-text authority (unknown text is returned unchanged, blank -> None)."""
    if not text or not str(text).strip():
        return None
    return enum_codes.normalize(enum_codes.REGULATORY_BODY, str(text).strip())


def _is_decree_43_body(*texts: Optional[str]) -> bool:
    return any(_body_code(t) == DECREE_43_BODY for t in texts)


def _clean_hs(hs: Optional[str]) -> str:
    return (hs or "").replace(".", "").strip()


def _status_if(required: bool, value: str) -> str:
    return value if required else NOT_REQUIRED


def _hs_item(hs: str, tariff: Optional[CustomsTariff], pillars: Dict[str, Any], **values: Any) -> Dict[str, Any]:
    """One HS line of the prefill. Tariff flags win over the consultation findings when a tariff exists."""
    line_hs = _clean_hs(hs)
    from_finding = any(line_hs and (f.startswith(line_hs) or line_hs.startswith(f)) for f in pillars["_decree_43_hs"])
    hs_decree43 = from_finding or bool(tariff and _is_decree_43_body(tariff.regulatory_authority))
    white_list_ver = pillars["white_list_verified"]
    coo_req = bool(tariff.requires_coo) if tariff else pillars["coo_required"]
    insp_req = bool(tariff.requires_inspection) if tariff else pillars["inspection_required"]
    tariff_body = _body_code(tariff.regulatory_authority) if tariff else None
    permit_req = bool(tariff_body) if tariff else pillars["import_permit_required"]

    clean_prefix = line_hs[:2] if len(line_hs) >= 2 else ""
    is_perishable_or_consumer = clean_prefix in [f"{i:02d}" for i in range(1, 25)] or clean_prefix in ["30", "33", "38"]

    return {
        "hs_code": hs,
        "decree_43_applicable": hs_decree43,
        "white_list_verified": white_list_ver if hs_decree43 else False,
        "factory_registration_no": pillars["factory_registration_no"],
        "decree_43_action": "verified" if (hs_decree43 and white_list_ver) else None,
        "coo_required": coo_req,
        "coo_type": pillars["coo_type"],
        "coo_status": _status_if(coo_req, pillars["coo_status"]),
        "inspection_required": insp_req,
        "inspection_body": pillars["inspection_body"],
        "inspection_status": _status_if(insp_req, pillars["inspection_status"]),
        "permit_required": permit_req,
        "regulatory_authority": tariff_body
        or (pillars["permit_issuing_authority"] if pillars["import_permit_required"] else None),
        "permit_status": _status_if(permit_req, pillars["permit_status"]),
        "msds_required": pillars["msds_required"],
        "msds_status": pillars["msds_status"],
        "halal_cert_required": pillars["halal_cert_required"],
        "halal_cert_status": pillars["halal_cert_status"],
        "coa_required": pillars["coa_required"],
        "coa_status": pillars["coa_status"],
        "cargox_verified": pillars.get("cargox_verified", False),
        "ready_for_acid": False,
        "commodity_group_matched": True,
        "import_card_group_code": None,
        "is_shelflife_applicable": is_perishable_or_consumer,
        "shelf_life_total_days": None,
        "shelf_life_remaining_percent": None,
        "artwork_arabic_approved": None,
        "labeling_notes": None,
        "sampling_required": pillars.get("sampling_required", False),
        "lab_type": pillars.get("lab_type"),
        "detention_allowed": pillars.get("detention_allowed", False),
        "estimated_lab_fees": 0.0,
        "cold_chain_required": pillars.get("cold_chain_required", False),
        "target_temperature": pillars.get("target_temperature"),
        "data_logger_verified": False,
        "is_hazmat": pillars.get("is_hazmat", False),
        "imo_class": pillars.get("imo_class"),
        **values,
    }


def _consultation_pillars(consultation: Optional[CustomsConsultationSession], factory_reg_no: Optional[str]) -> Dict[str, Any]:
    """Five-pillar findings from the consultation checklist, keyed by ImportRequirementPrefillResponse field
    names. Values are what the checklist holds (authorities as REGULATORY_BODY codes when known); nothing
    is defaulted."""
    p: Dict[str, Any] = {
        "decree_43_applicable": False, "white_list_required": False, "white_list_verified": False,
        "factory_registration_no": factory_reg_no,
        "coo_required": False, "coo_type": None, "coo_status": NOT_REQUIRED, "coo_notes": None,
        "inspection_required": False, "inspection_body": None, "inspection_status": NOT_REQUIRED, "inspection_notes": None,
        "import_permit_required": False, "permit_issuing_authority": None, "permit_status": NOT_REQUIRED, "permit_notes": None,
        "msds_required": False, "msds_status": NOT_REQUIRED,
        "halal_cert_required": False, "halal_cert_status": NOT_REQUIRED,
        "coa_required": False, "coa_status": NOT_REQUIRED,
        "special_notes": None,
        "cargox_verified": False,
        "cargox_status": "Not Verified",
        "ready_for_acid": False,
        "triple_match_status": "Pending",
        "commodity_group_matched": True,
        "import_card_group_code": None,
        "is_shelflife_applicable": False,
        "shelf_life_total_days": None,
        "shelf_life_remaining_percent": None,
        "artwork_arabic_approved": None,
        "labeling_notes": None,
        "sampling_required": False,
        "lab_type": None,
        "detention_allowed": False,
        "estimated_lab_fees": 0.0,
        "cold_chain_required": False,
        "target_temperature": None,
        "data_logger_verified": False,
        "is_hazmat": False,
        "imo_class": None,
        "checker_user_id": None,
        "checker_approved": False,
        "checker_notes": None,
        "is_overridden": False,
        "override_reason": None,
        # HS codes (undotted) of the GOEIC / Decree-43 checklist findings: only those lines get the flag.
        "_decree_43_hs": set(),
    }
    if not consultation:
        return p
    for item in consultation.checklist_items:
        doc_lower = (item.document_type or "").lower()
        agency = item.regulatory_agency or ""
        item_status = item.status or "Pending"
        remarks = item.remarks or ""

        # Pillar 1: Decree 43 / factory registration (GOEIC as agency, or named in the document type)
        if _is_decree_43_body(agency, item.document_type):
            p["decree_43_applicable"] = p["white_list_required"] = True
            if item.hs_code:
                p["_decree_43_hs"].add(_clean_hs(item.hs_code))
            if item_status in ("Verified", "Approved", "Received"):
                p["white_list_verified"] = True

        # Pillar 2: Certificate of Origin
        if "origin" in doc_lower or "منشأ" in doc_lower or "eur.1" in doc_lower or "coo" in doc_lower:
            p.update(coo_required=True, coo_type=item.document_type, coo_status=item_status, coo_notes=remarks)

        # Pillar 3: Pre-shipment inspection
        if "inspection" in doc_lower or "فحص" in doc_lower or "مطابقة" in doc_lower or "sgs" in doc_lower:
            p.update(inspection_required=True, inspection_body=_body_code(agency),
                     inspection_status=item_status, inspection_notes=remarks)

        # Pillar 4: Regulatory permits & approvals
        if ("permit" in doc_lower or "موافقة" in doc_lower or "تصريح" in doc_lower or "eeaa" in doc_lower
                or "بيئة" in agency or "دواء" in agency):
            p.update(import_permit_required=True, permit_issuing_authority=_body_code(agency),
                     permit_status=item_status, permit_notes=remarks)

        # Pillar 5: Technical / special certificates
        if "msds" in doc_lower or "safety" in doc_lower or "أمان" in doc_lower:
            p.update(msds_required=True, msds_status=item_status, special_notes=remarks)
        if "halal" in doc_lower or "حلال" in doc_lower:
            p.update(halal_cert_required=True, halal_cert_status=item_status, special_notes=remarks)
        if "coa" in doc_lower or "تحليل" in doc_lower:
            p.update(coa_required=True, coa_status=item_status, special_notes=remarks)
    return p


def _first_checklist_hs(consultation: Optional[CustomsConsultationSession]) -> Optional[str]:
    if not consultation:
        return None
    return next((item.hs_code for item in consultation.checklist_items if item.hs_code), None)


def _linked_purchase_orders(db: Session, import_file: ImportFile) -> List[PurchaseOrder]:
    pos = repo.active_pos_for_file(db, import_file.import_file_id)
    if not pos and import_file.po_ids:
        pos = repo.active_pos_by_ids(db, import_file.po_ids)
    if not pos and import_file.po_number:
        pos = repo.active_pos_by_number(db, import_file.po_number)
    return pos


def get_import_file_prefill_service(db: Session, import_file_id: int) -> ImportRequirementPrefillResponse:
    """Shipment, supplier, ACID, HS lines (value / currency) and five-pillar compliance findings from the
    import file, its PO lines, its invoices and its customs consultation.

    Never fabricates: a value that is not found stays empty. When no HS code can be found the HS list is
    empty and ``messages`` carries ``PREFILL_NO_HS``; a PO line without a tariff adds ``PREFILL_LINE_NO_HS``."""
    import_file = get_or_404(db, ImportFile, import_file_id, "ملف الاستيراد", active_only=True)

    messages: List[SystemMessageItem] = []
    currency = import_file.estimated_cost_currency or None  # never a default currency
    total_val = float(import_file.estimated_cost or 0.0)

    country_of_origin = None
    foreign_exporter_id = None
    supp = get_supplier_by_id(db, import_file.supplier_id) if import_file.supplier_id else None
    if supp:
        country_of_origin = supp.foreign_exporter_country or None
        foreign_exporter_id = supp.foreign_exporter_id

    consultations = CustomsConsultationRepository.get_all(db, import_file_id=import_file_id)  # active, newest first
    consultation = consultations[0] if consultations else None
    pillars = _consultation_pillars(consultation, foreign_exporter_id)
    primary_hs_code = _first_checklist_hs(consultation)

    hs_items: Dict[Tuple[str, Optional[str]], Dict[str, Any]] = {}
    totals: Dict[str, float] = {}

    # 1. Purchase order lines (HS from the line's tariff only)
    pos = _linked_purchase_orders(db, import_file)
    po_has_lines = False
    for po in pos:
        po_curr = po.currency.currency_code if po.currency else None
        for line in po.line_items:
            po_has_lines = True
            qty = float(line.quantity or 0.0)
            item_val = float(line.total_price or 0.0) or (float(line.unit_price or 0.0) * qty)
            if po_curr:
                totals[po_curr] = totals.get(po_curr, 0.0) + item_val
            tariff = line.tariff
            if not tariff:
                messages.append(to_item(PREFILL_LINE_NO_HS, po_number=po.po_number, item_code=line.item_code))
                continue
            hs = tariff.hs_code
            key = (hs, po_curr)
            if key in hs_items:
                hs_items[key]["item_value"] += item_val
                hs_items[key]["quantity"] += qty
                continue
            hs_items[key] = _hs_item(
                hs, tariff, pillars,
                commodity_description=line.description_ar or tariff.hs_description or line.description_en,
                item_code=line.item_code,
                country_of_origin=line.country_of_origin or po.country_of_origin or country_of_origin,
                currency=po_curr,
                item_value=item_val,
                quantity=qty,
                unit_of_measure=line.unit_of_measure,
            )

    # 2. Invoice rows (HS as written on the invoice, else the consultation's HS)
    if import_file.invoices_data:
        for inv in import_file.invoices_data:
            val = float(inv.get("amount", 0.0) or 0.0)
            inv_curr = inv.get("currency")
            if not po_has_lines and inv_curr and val > 0.0:
                totals[inv_curr] = totals.get(inv_curr, 0.0) + val
            hs = inv.get("hs_code") or primary_hs_code
            if not hs:
                continue
            key = (hs, inv_curr)
            if key in hs_items:
                if hs_items[key]["item_value"] == 0.0:
                    hs_items[key]["item_value"] = val
                continue
            tariff = get_tariff_by_hs_code(db, hs)
            hs_items[key] = _hs_item(
                hs, tariff, pillars,
                commodity_description=inv.get("description") or (tariff.hs_description if tariff else None),
                item_code=inv.get("item_code"),
                country_of_origin=country_of_origin,
                currency=inv_curr,
                item_value=val,
                quantity=0.0,
                unit_of_measure=None,
            )

    # Resolve shipment_value and currency from totals
    shipment_value: Optional[float] = None
    if len(totals) == 1:
        c = next(iter(totals.keys()))
        shipment_value = round(totals[c], 2)
        currency = c
    elif len(totals) > 1:
        shipment_value = None
        currency = None
        sorted_currs = ", ".join(sorted(totals.keys()))
        messages.append(to_item(PREFILL_MIXED_CURRENCY, currencies=sorted_currs))
    else:
        # No PO line / invoice totals: fall back to estimated cost if available
        if total_val > 0.0:
            shipment_value = total_val
        else:
            shipment_value = None
            currency = None

    # 3. Only the consultation's HS code is known: use it (real data). Never a default HS.
    if not hs_items and primary_hs_code:
        tariff = get_tariff_by_hs_code(db, primary_hs_code)
        key = (primary_hs_code, currency)
        hs_items[key] = _hs_item(
            primary_hs_code, tariff, pillars,
            commodity_description=tariff.hs_description if tariff else None,
            item_code=None,
            country_of_origin=country_of_origin,
            currency=currency,
            item_value=shipment_value or 0.0,
            quantity=0.0,
            unit_of_measure=None,
        )

    hs_code_items_list = [ImportRequirementHSCodeItem(**data) for data in hs_items.values()]
    primary_commodity_desc = None
    if hs_code_items_list:
        primary_hs_code = hs_code_items_list[0].hs_code
        primary_commodity_desc = hs_code_items_list[0].commodity_description
    else:
        messages.append(to_item(PREFILL_NO_HS, import_file_code=import_file.import_file_code))

    return ImportRequirementPrefillResponse(
        import_file_id=import_file.import_file_id,
        import_file_code=import_file.import_file_code,
        importer_name=import_file.company_name,
        supplier_id=import_file.supplier_id,
        supplier_name=import_file.supplier_name,
        country_of_origin=country_of_origin,
        foreign_exporter_id=foreign_exporter_id,
        currency=currency,
        shipment_value=shipment_value,
        po_number=import_file.po_number,
        pi_number=import_file.pi_number,
        acid_number=import_file.acid_number,
        hs_code=primary_hs_code,
        commodity_description=primary_commodity_desc,
        hs_code_items=hs_code_items_list,
        consultation_id=consultation.consultation_id if consultation else None,
        consultation_code=consultation.consultation_code if consultation else None,
        broker_name=consultation.broker_name if consultation else None,
        consultation_status=consultation.overall_status if consultation else None,
        readiness_percentage=consultation.readiness_percentage if consultation else 0.0,
        messages=messages,
        **{k: v for k, v in pillars.items() if not k.startswith("_")},
    )
