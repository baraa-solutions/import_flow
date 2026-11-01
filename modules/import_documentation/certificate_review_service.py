"""
Certificate of Origin (COO) and Inspection Certificate review service (Phase 3 - BP-018).
"""

import logging
import re
from datetime import date, datetime, timezone, timedelta
from typing import Any, Dict, List, Optional, Set, Tuple
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

logger = logging.getLogger(__name__)

from modules.freight_booking.model import ShipmentBooking
from modules.import_companies.model import ImportCompany
from modules.cargo_shipping.model import CargoShippingRecord
from modules.suppliers.model import Supplier
from modules.import_documentation.model import POPackingReconciliationSession, DraftBLReviewSession, ShipmentDocumentItem, BankingDocumentSession, AcidRegistrationSession, CertificateOfOriginReviewSession, InspectionCertificateReviewSession, InvoiceBLMatchSession


from modules.import_documentation.model import (
    CertificateOfOriginReviewSession,
    InspectionCertificateReviewSession,
)
from modules.import_files.model import ImportFile
from modules.freight_booking.model import ShipmentBooking
from modules.import_companies.model import ImportCompany
from modules.import_documentation.schemas import *
from modules.import_documentation.validators import validate_status
import modules.import_documentation.repository as repo
from modules.common.system_messages import coded_text, msg, render_en
from modules.common.enum_codes import Placeholder, finalize_structured_values
from modules.common.file_tracking import set_file_tracking
from modules.common.errors import best_effort
from modules.common.validators import not_found, require_active
from modules.import_files.repository import codes_by_ids

from modules.import_documentation.ai_document_parser import (
    extract_coo_china_ccpit_text,
    extract_eur1_certificate_text,
    extract_standard_coo_text,
    extract_agadir_gafta_form_a_coo_text,
    extract_inspection_voc_certificate_text,
    extract_psi_certificate_text,
    extract_coa_certificate_text,
)
from modules.import_documentation.document_upload_ocr_service import extract_text_from_uploaded_file
from modules.import_documentation.certificate_template_service import (
    COUNTRY_ISO_MAP,
    EU_27_COUNTRIES,
    CHINA_NAMES,
    AGADIR_COUNTRIES,
    GAFTA_COUNTRIES,
    ARAB_LEAGUE_COUNTRIES,
    classify_coo_certificate_type,
    sanitize_english_only,
    int_to_english_words,
    extract_clean_main_description,
    format_coo_hs_code,
    get_package_type_plural,
    format_total_packages_line,
    format_coo_quantity_box,
    generate_coo_draft_template_service,
    generate_inspection_draft_template_service,
)
from modules.import_documentation.doc_common import (
    SYSTEM_ACTOR,
    LABEL_IMPORT_FILE,
    LABEL_COO_REVIEW,
    LABEL_INSPECTION_REVIEW,
    COMPANY_DOC_EXPIRING_SOON_DAYS,
    ETA_SAFETY_MARGIN_DAYS,
    _require_active_po,
    _actor,
    _bad_request,
    _conflict,
    _active_import_file,
    _get_active_import_file,
    _commit_follow_up,
    _lifecycle_follow_up,
    _fuzzy_match,
    _numeric_match,
    _has_text,
)

def _compare_origins(sys_origin: str, drf_origin: str) -> Tuple[bool, float]:
    s_norm = sys_origin.lower().strip()
    d_norm = drf_origin.lower().strip()
    if not s_norm and not d_norm:
        return True, 1.0
    if not s_norm or not d_norm:
        return False, 0.0
    if s_norm == d_norm or s_norm in d_norm or d_norm in s_norm:
        return True, 1.0
    if ("eu" in d_norm or "european union" in d_norm or "الاتحاد الأوروبي" in d_norm) and any(eu == s_norm or eu in s_norm for eu in EU_27_COUNTRIES):
        return True, 1.0
    return _fuzzy_match(sys_origin, drf_origin, threshold=0.75)


# --- 3. CERTIFICATE OF ORIGIN (COO / EUR.1) VERIFICATION ENGINE ---
def _extraction_failed_row(key: str, label_ar: str, sys_val: Any, severity: str, details_code: str) -> Dict[str, Any]:
    """Comparison-matrix row for a certificate field that could not be read from the uploaded draft."""
    return finalize_structured_values({
        "field_key": key,
        "field_label_ar": label_ar,
        "system_value": sys_val,
        "draft_value": Placeholder("NOT_EXTRACTED"),
        "match_status": "EXTRACTION_FAILED",
        "severity": severity,
        **coded_text("details", details_code),
    })


def compare_coo_service(db: Session, request: COOComparisonRequest) -> dict:
    imp_file = _active_import_file(db, request.import_file_id, status_code=status.HTTP_404_NOT_FOUND)
    company = db.query(ImportCompany).filter(ImportCompany.company_id == imp_file.company_id).first() if imp_file.company_id else None
    supplier = db.query(Supplier).filter(Supplier.supplier_id == imp_file.supplier_id).first() if imp_file.supplier_id else None
    # DOC-03: an unknown origin / invoice stays None (never a sample country or invoice number).
    raw_country = (getattr(supplier, 'foreign_exporter_country', None)) or (getattr(imp_file, 'origin_country', None)) or None
    country_iso = getattr(supplier, 'foreign_exporter_country_code', None) or COUNTRY_ISO_MAP.get(str(raw_country or "").strip().lower(), "")
    raw_reg = (getattr(supplier, 'tax_id', None)) or (getattr(supplier, 'foreign_exporter_id', None)) or (getattr(supplier, 'exporter_code', None)) or ""
    if raw_reg and country_iso and not str(raw_reg).strip().upper().startswith(country_iso.upper()):
        exp_reg_id = f"{country_iso.upper()}{str(raw_reg).strip()}"
    else:
        exp_reg_id = str(raw_reg).strip()

    sys_snapshot = {
        "exporter_name": supplier.company_name if supplier else imp_file.supplier_name,
        "exporter_reg_id": exp_reg_id,
        "exporter_address": supplier.address if supplier else "",
        "country_of_origin": raw_country,
        "importer_name": company.importer_name if company else imp_file.company_name,
        "importer_address": company.address if company else "",
        "destination_country": "Egypt",
        "invoice_number": imp_file.pi_number or None,
        "invoice_date": str(imp_file.pi_date) if getattr(imp_file, "pi_date", None) else None,
        "certificate_type": request.certificate_type,
    }

    draft_fields = request.draft_fields or {}
    matrix = []
    has_critical = False
    has_discrepancies = False

    coo_checks = [
        ("exporter_reg_id", "كود المصدر الأجنبي / رقم التسجيل (Foreign Exporter Reg Code)", False),
        ("exporter_name", "اسم المصدر (Exporter Name)", True),
        ("country_of_origin", "بلد المنشأ (Country of Origin)", True),
        ("importer_name", "اسم المستورد (Importer / Consignee)", True),
        ("destination_country", "بلد المقصد (Destination Country)", True),
        ("invoice_number", "رقم الفاتورة (Commercial Invoice No)", True),
        ("certificate_type", "نوع شهادة المنشأ (Certificate Type)", False),
    ]

    from modules.import_documentation.ai_document_parser import clean_exporter_name, clean_consignee_name

    for key, label_ar, is_critical in coo_checks:
        sys_val = sys_snapshot.get(key)
        drf_val = draft_fields.get(key)

        clean_sys_val = sys_val
        clean_drf_val = drf_val

        if key == "exporter_name":
            clean_sys_val = clean_exporter_name(str(sys_val or ""))
            clean_drf_val = clean_exporter_name(str(drf_val or ""), str(draft_fields.get("exporter_reg_id") or ""))
        elif key == "importer_name":
            clean_sys_val = clean_consignee_name(str(sys_val or ""))
            clean_drf_val = clean_consignee_name(str(drf_val or ""))

        if not drf_val or not str(drf_val).strip():
            if key == "exporter_reg_id":
                matched = True
                ratio = 1.0
            else:
                has_discrepancies = True
                if is_critical:
                    has_critical = True
                matrix.append(_extraction_failed_row(
                    key, label_ar, sys_val,
                    severity="BLOCKING" if is_critical else "WARNING",
                    details_code="DOC_COO_VALUE_NOT_FOUND",
                ))
                continue
        else:
            matched, ratio = _fuzzy_match(clean_sys_val, clean_drf_val, threshold=0.85)
        
        # Special rule for EUR.1 origin comparison: 'EU' or 'European Union' matches any EU-27 member country in system
        if key == "country_of_origin" and not matched:
            sys_norm = str(sys_val or "").lower().strip()
            drf_norm = str(drf_val or "").lower().strip()
            if ("eu" in drf_norm or "european union" in drf_norm or "الاتحاد الأوروبي" in drf_norm) and any(eu == sys_norm or eu in sys_norm for eu in EU_27_COUNTRIES):
                matched = True
                ratio = 1.0
        
        if matched:
            match_status = "MATCH"
            severity = "NONE"
        else:
            has_discrepancies = True
            if is_critical:
                has_critical = True
                match_status = "MISMATCH_CRITICAL"
                severity = "BLOCKING"
            else:
                match_status = "MISMATCH_MINOR"
                severity = "WARNING"

        displayed_draft_val = drf_val
        if key == "exporter_name":
            displayed_draft_val = clean_drf_val
        elif key == "importer_name":
            displayed_draft_val = clean_drf_val

        matrix.append({
            "field_key": key,
            "field_label_ar": label_ar,
            "system_value": sys_val,
            "draft_value": displayed_draft_val,
            "match_status": match_status,
            "severity": severity,
            **coded_text("details", "DOC_COO_SIMILARITY", match_pct=round(ratio * 100, 1)),
        })

    status_calc = "Verified" if not has_discrepancies else ("Discrepancy_Accepted" if not has_critical else "Correction Requested")

    return {
        "import_file_id": request.import_file_id,
        "certificate_type": request.certificate_type,
        "system_snapshot_data": sys_snapshot,
        "draft_input_data": draft_fields,
        "comparison_matrix": matrix,
        "has_discrepancies": has_discrepancies,
        "has_critical_mismatch": has_critical,
        "status": status_calc,
    }


_COO_JUSTIFICATION_DETAIL = (
    "يجب ذكر سبب ومبررات الموافقة على الاختلافات قبل اعتماد وحفظ دراسة شهادة المنشأ، أو العودة للتعديل ومخاطبة المورد."
)
_INSPECTION_JUSTIFICATION_DETAIL = (
    "يجب ذكر سبب ومبررات الموافقة على الاختلافات قبل اعتماد وحفظ دراسة شهادة الفحص، أو العودة للتعديل ومخاطبة المورد."
)
_INSPECTION_APPROVED_STATUSES = ("Verified", "Approved", "Discrepancy_Accepted")


def _matrix_flags(matrix: Optional[List[Any]]) -> Tuple[bool, bool]:
    """(has_discrepancies, has_critical_mismatch) derived from a stored comparison matrix, so a client cannot hide
    a mismatch by sending the flags as False (DOC-06)."""
    has_disc = False
    has_crit = False
    for row in matrix or []:
        if not isinstance(row, dict):
            continue
        match_status = str(row.get("match_status") or "").strip().upper()
        severity = str(row.get("severity") or "").strip().upper()
        if match_status and match_status != "MATCH":
            has_disc = True
        if severity == "BLOCKING" or match_status == "MISMATCH_CRITICAL":
            has_disc = True
            has_crit = True
    return has_disc, has_crit


def _has_text(value: Optional[str]) -> bool:
    return bool(value and value.strip())


def _known(value: Optional[str]) -> Optional[str]:
    """A master value or None: blank and the schema placeholder "N/A" count as unknown."""
    if value is None:
        return None
    text = str(value).strip()
    return text if text and text.upper() != "N/A" else None


def _coo_certified_follow_ups(db: Session, file_id: int, certificate_type: Optional[str],
                              certificate_number: Optional[str], actor: str) -> None:
    """Customs approval sync, lifecycle STEP_08_COO -> STEP_09 and file tracking of a certified COO review."""

    def _sync_customs_approval() -> None:
        from modules.docs_customs_approval.model import CustomsDocumentApproval
        coo_app = db.query(CustomsDocumentApproval).filter(
            CustomsDocumentApproval.import_file_id == file_id,
            CustomsDocumentApproval.document_type == "Certificate of Origin",
            CustomsDocumentApproval.is_active == True,
        ).first()
        if coo_app:
            coo_app.document_reference_no = certificate_number or coo_app.document_reference_no
            coo_app.commercial_status = "Approved"
            coo_app.commercial_reviewed_by = actor
            coo_app.commercial_reviewed_at = datetime.now(timezone.utc)
            coo_app.commercial_notes = f"Certificate of origin {certificate_type} - {certificate_number} approved (STEP_08_COO)."
            if coo_app.customs_status == "Approved":
                coo_app.overall_status = "Approved for Clearance"
            else:
                coo_app.overall_status = "Under Review"

    _commit_follow_up(db, _sync_customs_approval, "COO CustomsDocumentApproval sync")

    _lifecycle_follow_up(
        db, "Lifecycle advance STEP_08_COO->STEP_09",
        import_file_id=file_id,
        completed_step_code="STEP_08_COO",
        target_step_codes=["STEP_09"],
        notes_msg=msg(
            "DOC_COO_APPROVED",
            certificate_type=certificate_type,
            certificate_number=certificate_number,
        ),
        next_action_msg=msg("NA_STEP09_FINAL_DOCS_APPROVAL"),
        assigned_user=actor,
    )

    def _track_file() -> None:
        imp_file = _get_active_import_file(db, file_id)
        if imp_file:
            set_file_tracking(imp_file, step_code="STEP_09", next_action=msg("NA_STEP09_FINAL_DOCS_APPROVAL"))
            if (imp_file.progress_percent or 0.0) < 58.0:
                imp_file.progress_percent = 58.0

    _commit_follow_up(db, _track_file, "COO import file tracking")


def create_coo_review_service(
    db: Session, schema: CertificateOfOriginReviewCreate, user: Optional[str] = None
) -> CertificateOfOriginReviewSession:
    validate_status("coo", schema.status)
    _active_import_file(db, schema.import_file_id)
    _require_active_po(db, schema.po_id)
    actor = _actor(user, schema.reviewed_by)

    # Review #13: a certified save always uses the server comparison (a client matrix is kept for drafts only).
    if not schema.comparison_matrix or not getattr(schema, "is_draft", False):
        schema.has_discrepancies = False
        schema.has_critical_mismatch = False
        comp = compare_coo_service(db, COOComparisonRequest(
            import_file_id=schema.import_file_id,
            certificate_type=schema.certificate_type,
            draft_fields=schema.draft_input_data,
        ))
        schema.system_snapshot_data = comp["system_snapshot_data"]
        schema.comparison_matrix = comp["comparison_matrix"]
        schema.has_discrepancies = comp["has_discrepancies"]
        schema.has_critical_mismatch = comp["has_critical_mismatch"]
    derived_disc, derived_crit = _matrix_flags(schema.comparison_matrix)
    schema.has_discrepancies = bool(schema.has_discrepancies or derived_disc)
    schema.has_critical_mismatch = bool(schema.has_critical_mismatch or derived_crit)

    # Auto-populate exporter, importer, country of origin from the draft or the system snapshot. Unknown values
    # stay empty (DOC-03): the NOT NULL columns get "" instead of an invented name or country.
    draft_dict = schema.draft_input_data or {}
    sys_dict = schema.system_snapshot_data or {}
    schema.exporter_name = _known(schema.exporter_name) or _known(draft_dict.get("exporter_name")) or _known(sys_dict.get("exporter_name")) or ""
    schema.importer_name = _known(schema.importer_name) or _known(draft_dict.get("importer_name")) or _known(sys_dict.get("importer_name")) or ""
    schema.country_of_origin = _known(schema.country_of_origin) or _known(draft_dict.get("country_of_origin")) or _known(sys_dict.get("country_of_origin")) or ""

    is_draft = bool(getattr(schema, "is_draft", False))
    if is_draft:
        schema.status = "Draft Generated"
    else:
        # DOC-06: any discrepancy needs a justification, whatever status the client or the compare reported.
        if (schema.has_discrepancies or schema.has_critical_mismatch) and not _has_text(schema.override_reason):
            raise HTTPException(status_code=400, detail=_COO_JUSTIFICATION_DETAIL)
        if not schema.country_of_origin:
            raise _bad_request("لا يمكن اعتماد دراسة شهادة المنشأ بدون بلد منشأ معروف. يرجى إدخال بلد المنشأ أولاً.")
        schema.status = "Approved"
        schema.reviewed_by = actor
        schema.reviewed_at = datetime.now(timezone.utc)

    existing_certified = repo.get_coo_review_by_file_id(db, schema.import_file_id, include_inactive=False, include_drafts=False)
    if existing_certified:
        if is_draft:
            raise _conflict(
                f"يوجد بالفعل دراسة معتمدة لشهادة المنشأ لهذا الملف ({existing_certified.coo_review_code}): "
                f"لا يمكن حفظ مسودة فوقها."
            )
        raise _conflict(
            f"يوجد بالفعل دراسة معتمدة لشهادة المنشأ لهذا الملف ({existing_certified.coo_review_code}): "
            f"الدراسة المعتمدة مقفلة ولا يمكن اعتماد دراسة جديدة فوقها."
        )
    existing = repo.get_coo_review_by_file_id(db, schema.import_file_id, include_inactive=False, include_drafts=True)
    if existing:
        update_schema = CertificateOfOriginReviewUpdate(**schema.model_dump(exclude_unset=True))
        saved_session = repo.update_coo_review(db, existing.coo_review_id, update_schema, user=actor)
    else:
        saved_session = repo.create_coo_review(db, schema, user=actor)

    # If certified (not draft), sync to Customs Document Approvals and Central Lifecycle (follow-ups, DOC-11)
    if not is_draft:
        import sys
        _facade = sys.modules.get("modules.import_documentation.service")
        _fn = getattr(_facade, "_coo_certified_follow_ups", _coo_certified_follow_ups) if _facade else _coo_certified_follow_ups
        _fn(db, schema.import_file_id, schema.certificate_type, schema.certificate_number, actor)
        db.refresh(saved_session)

    return saved_session


def update_coo_review_service(
    db: Session, review_id: int, schema: CertificateOfOriginReviewUpdate, user: Optional[str] = None
) -> CertificateOfOriginReviewSession:
    validate_status("coo", schema.status)
    review = repo.get_coo_review_by_id(db, review_id)
    if not review:
        raise not_found(LABEL_COO_REVIEW, review_id)
    fields = schema.model_fields_set

    if not review.is_draft:
        disallowed = set(fields) - {"notes", "override_reason"}
        if disallowed:
            raise _conflict(
                f"دراسة شهادة المنشأ ({review.coo_review_code}) معتمدة ومقفلة: "
                f"لا يمكن تعديل الحقول ({', '.join(sorted(disallowed))})، يسمح فقط بتعديل الملاحظات."
            )
        if "notes" in fields:
            review.notes = schema.notes
            review.updated_by = _actor(user)
            db.commit()
            db.refresh(review)
        elif "override_reason" in fields:
            review.override_reason = schema.override_reason
            review.updated_by = _actor(user)
            db.commit()
            db.refresh(review)
        return review

    def _merged(name: str) -> Any:
        return getattr(schema, name) if name in fields else getattr(review, name)

    is_draft = bool(_merged("is_draft"))
    if is_draft and not review.is_draft:
        raise _conflict(f"دراسة شهادة المنشأ ({review.coo_review_code}) معتمدة: لا يمكن إعادتها إلى مسودة.")

    data = schema.model_dump(exclude_unset=True)
    data.pop("status", None)
    data.pop("reviewed_by", None)
    data.pop("reviewed_at", None)
    for name in ("exporter_name", "importer_name", "country_of_origin"):
        if name in data and data[name] is None:
            data[name] = ""  # NOT NULL columns: unknown stays empty
    clean = CertificateOfOriginReviewUpdate(**data)

    if not is_draft:
        # Review #13: a certified save always uses the server comparison.
        comp = compare_coo_service(db, COOComparisonRequest(
            import_file_id=review.import_file_id,
            certificate_type=_merged("certificate_type"),
            draft_fields=_merged("draft_input_data"),
        ))
        clean.comparison_matrix = comp["comparison_matrix"]
        clean.has_discrepancies = comp["has_discrepancies"]
        clean.has_critical_mismatch = comp["has_critical_mismatch"]
        has_disc, has_crit = comp["has_discrepancies"], comp["has_critical_mismatch"]
    else:
        derived_disc, derived_crit = _matrix_flags(_merged("comparison_matrix"))
        has_disc = bool(_merged("has_discrepancies") or derived_disc)
        has_crit = bool(_merged("has_critical_mismatch") or derived_crit)
    if is_draft:
        clean.status = "Draft Generated"
    else:
        if (has_disc or has_crit) and not _has_text(_merged("override_reason")):
            raise HTTPException(status_code=400, detail=_COO_JUSTIFICATION_DETAIL)
        if not _known(_merged("country_of_origin")):
            raise _bad_request("لا يمكن اعتماد دراسة شهادة المنشأ بدون بلد منشأ معروف. يرجى إدخال بلد المنشأ أولاً.")
        clean.status = "Approved"
        clean.reviewed_by = _actor(user)
        clean.reviewed_at = datetime.now(timezone.utc)
    becomes_certified = bool(review.is_draft) and not is_draft
    saved = repo.update_coo_review(db, review_id, clean, user=_actor(user))
    if becomes_certified:
        import sys
        _facade = sys.modules.get("modules.import_documentation.service")
        _fn = getattr(_facade, "_coo_certified_follow_ups", _coo_certified_follow_ups) if _facade else _coo_certified_follow_ups
        _fn(db, saved.import_file_id, saved.certificate_type, saved.certificate_number, clean.reviewed_by)
        db.refresh(saved)
    return saved


# --- 4. INSPECTION CERTIFICATE (COC / COA / VOC) VERIFICATION ENGINE ---
def compare_inspection_cert_service(db: Session, request: InspectionComparisonRequest) -> dict:
    imp_file = _active_import_file(db, request.import_file_id, status_code=status.HTTP_404_NOT_FOUND)
    company = db.query(ImportCompany).filter(ImportCompany.company_id == imp_file.company_id).first() if imp_file.company_id else None
    supplier = db.query(Supplier).filter(Supplier.supplier_id == imp_file.supplier_id).first() if imp_file.supplier_id else None
    acid_session = db.query(AcidRegistrationSession).filter(
        AcidRegistrationSession.import_file_id == request.import_file_id,
        AcidRegistrationSession.is_active == True
    ).first()

    acid_val = (acid_session.acid_number if acid_session else None) or getattr(imp_file, 'acid_number', None) or None
    country_val = getattr(supplier, 'country_name', None) or getattr(imp_file, 'country_of_origin', None) or None

    draft_fields = request.draft_fields or {}

    sys_snapshot = {
        "importer_name": company.importer_name if company else imp_file.company_name,
        "exporter_name": supplier.company_name if supplier else imp_file.supplier_name,
        "acid_number": acid_val,
        "country_of_origin": country_val,
        "inspection_agency": request.inspection_agency,
        "inspection_type": request.inspection_type,
        "regulatory_authority": "General Organization for Export and Import Control (GOEIC)",
        "invoice_number": getattr(imp_file, 'pi_number', None) or (draft_fields.get("invoice_number") if draft_fields else None) or (acid_session.proforma_invoice_no if acid_session else None) or None,
        "standard_specification": "Egyptian Standard ES / EN 13501-1:2018",
    }

    matrix = []
    has_critical = False
    has_discrepancies = False

    insp_checks = [
        ("inspection_agency", "جهة الفحص والمعاينة (Inspection Agency)", True),
        ("importer_name", "اسم المستورد (Importer Name)", True),
        ("exporter_name", "اسم المصدر (Exporter Name)", True),
        ("acid_number", "رقم القيد الجمركي المسبق للشحنة (ACID Number)", False),
        ("country_of_origin", "بلد المنشأ (Country of Origin)", False),
        ("regulatory_authority", "الجهة الرقابية المصرية المختصة (Regulatory Authority)", True),
        ("invoice_number", "رقم الفاتورة الخاضعة للفحص (Invoice No)", True),
        ("standard_specification", "المواصفة القياسية المعتمدة (Specification)", False),
    ]

    for key, label_ar, is_critical in insp_checks:
        sys_val = sys_snapshot.get(key)
        drf_val = draft_fields.get(key)
        
        # Smart Field Matching
        if drf_val is None or not str(drf_val).strip():
            if not is_critical:
                matrix.append(finalize_structured_values({
                    "field_key": key,
                    "field_label_ar": label_ar,
                    "system_value": sys_val,
                    "draft_value": Placeholder("OPTIONAL_NOT_INCLUDED"),
                    "match_status": "MATCH",
                    "severity": "NONE",
                    **coded_text("details", "DOC_INSPECTION_OPTIONAL_NOT_INCLUDED"),
                }))
                continue
            has_discrepancies = True
            has_critical = True
            matrix.append(_extraction_failed_row(
                key, label_ar, sys_val,
                severity="BLOCKING",
                details_code="DOC_INSPECTION_VALUE_NOT_FOUND",
            ))
            continue
        elif key == "regulatory_authority":
            sys_is_goeic = bool(re.search(r'GOEIC|Export and Import Control|الصادرات والواردات', str(sys_val), re.I))
            drf_is_goeic = bool(re.search(r'GOEIC|Export and Import Control|الصادرات والواردات', str(drf_val), re.I))
            if sys_is_goeic and drf_is_goeic:
                matched, ratio = True, 1.0
            else:
                matched, ratio = _fuzzy_match(sys_val, drf_val, threshold=0.75)
        elif key == "importer_name" or key == "exporter_name":
            # Token set matching ignoring corporate suffixes
            s_clean = re.sub(r'(?:SPA|S\.P\.A\.|LTD|CO\.|COMPANY|LLC|CORPORATION|UAB|INTERNATIONAL|FOR|TRADING|AND|CORPET)', '', str(sys_val).upper()).strip()
            d_clean = re.sub(r'(?:SPA|S\.P\.A\.|LTD|CO\.|COMPANY|LLC|CORPORATION|UAB|INTERNATIONAL|FOR|TRADING|AND|CORPET)', '', str(drf_val).upper()).strip()
            if s_clean and d_clean and (s_clean in d_clean or d_clean in s_clean or _fuzzy_match(s_clean, d_clean, threshold=0.65)[0]):
                matched, ratio = True, 1.0
            else:
                matched, ratio = _fuzzy_match(sys_val, drf_val, threshold=0.75)
        elif key == "country_of_origin":
            matched, ratio = _compare_origins(str(sys_val or ""), str(drf_val or ""))
        elif key == "acid_number":
            s_acid = re.sub(r'\D', '', str(sys_val or ""))
            d_acid = re.sub(r'\D', '', str(drf_val or ""))
            if s_acid and d_acid and (s_acid == d_acid or s_acid in d_acid or d_acid in s_acid):
                matched, ratio = True, 1.0
            else:
                matched, ratio = (s_acid == d_acid), (1.0 if s_acid == d_acid else 0.0)
        elif key == "invoice_number":
            s_invs = re.findall(r'[A-Za-z0-9\-_]{4,}', str(sys_val or ""))
            d_invs = re.findall(r'[A-Za-z0-9\-_]{4,}', str(drf_val or ""))
            if any(si in d_invs for si in s_invs) or any(di in s_invs for di in d_invs) or (sys_val and drf_val and (str(sys_val) in str(drf_val) or str(drf_val) in str(sys_val))):
                matched, ratio = True, 1.0
            else:
                matched, ratio = _fuzzy_match(sys_val, drf_val, threshold=0.70)
        elif key == "standard_specification":
            matched, ratio = True, 1.0 if bool(drf_val) else (False, 0.0)
        else:
            matched, ratio = _fuzzy_match(sys_val, drf_val, threshold=0.80)

        if matched:
            match_status = "MATCH"
            severity = "NONE"
        else:
            has_discrepancies = True
            if is_critical:
                has_critical = True
                match_status = "MISMATCH_CRITICAL"
                severity = "BLOCKING"
            else:
                match_status = "MISMATCH_MINOR"
                severity = "WARNING"

        matrix.append({
            "field_key": key,
            "field_label_ar": label_ar,
            "system_value": sys_val,
            "draft_value": drf_val,
            "match_status": match_status,
            "severity": severity,
            **coded_text("details", "DOC_INSPECTION_MATCH_RATE", match_pct=round(ratio * 100, 1)),
        })

    status_calc = "Verified" if not has_discrepancies else ("Discrepancy_Accepted" if not has_critical else "Correction Requested")

    return {
        "import_file_id": request.import_file_id,
        "inspection_type": request.inspection_type,
        "inspection_agency": request.inspection_agency,
        "system_snapshot_data": sys_snapshot,
        "draft_input_data": draft_fields,
        "comparison_matrix": matrix,
        "has_discrepancies": has_discrepancies,
        "has_critical_mismatch": has_critical,
        "status": status_calc,
    }


def _inspection_status(has_disc: bool, has_crit: bool, override_reason: Optional[str]) -> str:
    """Server-computed inspection review status (DOC-06): clean -> Verified; any discrepancy needs a
    justification (400 without one) and is then Discrepancy_Accepted."""
    if not (has_disc or has_crit):
        return "Verified"
    if not _has_text(override_reason):
        raise HTTPException(status_code=400, detail=_INSPECTION_JUSTIFICATION_DETAIL)
    return "Discrepancy_Accepted"


def create_inspection_review_service(
    db: Session, schema: InspectionCertificateReviewCreate, user: Optional[str] = None
) -> InspectionCertificateReviewSession:
    validate_status("inspection", schema.status)
    _active_import_file(db, schema.import_file_id)
    _require_active_po(db, schema.po_id)
    actor = _actor(user, schema.reviewed_by)

    # Review #13: inspection saves are always certified, so the comparison always runs on the server.
    comp = compare_inspection_cert_service(db, InspectionComparisonRequest(
        import_file_id=schema.import_file_id,
        inspection_type=schema.inspection_type,
        inspection_agency=schema.inspection_agency,
        draft_fields=schema.draft_input_data,
    ))
    schema.system_snapshot_data = comp["system_snapshot_data"]
    schema.comparison_matrix = comp["comparison_matrix"]
    schema.has_discrepancies = comp["has_discrepancies"]
    schema.has_critical_mismatch = comp["has_critical_mismatch"]
    derived_disc, derived_crit = _matrix_flags(schema.comparison_matrix)
    schema.has_discrepancies = bool(schema.has_discrepancies or derived_disc)
    schema.has_critical_mismatch = bool(schema.has_critical_mismatch or derived_crit)

    # Mandatory justification validation on discrepancies; the client status is ignored.
    schema.status = _inspection_status(schema.has_discrepancies, schema.has_critical_mismatch, schema.override_reason)
    schema.reviewed_by = actor
    schema.reviewed_at = datetime.now(timezone.utc)

    existing = repo.get_inspection_review_by_file_id(db, schema.import_file_id, include_inactive=False)
    if existing:
        update_schema = InspectionCertificateReviewUpdate(**schema.model_dump(exclude_unset=True))
        saved = repo.update_inspection_review(db, existing.inspection_review_id, update_schema, user=actor)
    else:
        saved = repo.create_inspection_review(db, schema, user=actor)

    # Advance Central Lifecycle (STEP_08_COC -> STEP_09)
    if saved.status in _INSPECTION_APPROVED_STATUSES:
        file_id, review_code = saved.import_file_id, saved.inspection_review_code
        _lifecycle_follow_up(
            db, "Lifecycle advance STEP_08_COC->STEP_09",
            import_file_id=file_id,
            completed_step_code="STEP_08_COC",
            target_step_codes=["STEP_09"],
            notes_msg=msg("DOC_INSPECTION_REVIEW_APPROVED", review_code=review_code),
            assigned_user="Compliance Officer",
        )
        db.refresh(saved)

    return saved


def update_inspection_review_service(
    db: Session, review_id: int, schema: InspectionCertificateReviewUpdate, user: Optional[str] = None
) -> InspectionCertificateReviewSession:
    validate_status("inspection", schema.status)
    review = repo.get_inspection_review_by_id(db, review_id)
    if not review:
        raise not_found(LABEL_INSPECTION_REVIEW, review_id)
    fields = schema.model_fields_set

    def _merged(name: str) -> Any:
        return getattr(schema, name) if name in fields else getattr(review, name)

    data = schema.model_dump(exclude_unset=True)
    for name in ("status", "reviewed_by", "reviewed_at"):
        data.pop(name, None)
    clean = InspectionCertificateReviewUpdate(**data)
    # Review #13: inspection saves are certified, so the comparison always runs on the server.
    comp = compare_inspection_cert_service(db, InspectionComparisonRequest(
        import_file_id=review.import_file_id,
        inspection_type=_merged("inspection_type"),
        inspection_agency=_merged("inspection_agency"),
        draft_fields=_merged("draft_input_data"),
    ))
    clean.comparison_matrix = comp["comparison_matrix"]
    clean.has_discrepancies = comp["has_discrepancies"]
    clean.has_critical_mismatch = comp["has_critical_mismatch"]
    clean.status = _inspection_status(comp["has_discrepancies"], comp["has_critical_mismatch"], _merged("override_reason"))
    clean.reviewed_by = _actor(user)
    clean.reviewed_at = datetime.now(timezone.utc)
    saved = repo.update_inspection_review(db, review_id, clean, user=_actor(user))

    # Advance Central Lifecycle (STEP_08_COC -> STEP_09)
    if saved.status in _INSPECTION_APPROVED_STATUSES:
        file_id, review_code = saved.import_file_id, saved.inspection_review_code
        _lifecycle_follow_up(
            db, "Lifecycle advance STEP_08_COC->STEP_09",
            import_file_id=file_id,
            completed_step_code="STEP_08_COC",
            target_step_codes=["STEP_09"],
            notes_msg=msg("DOC_INSPECTION_REVIEW_UPDATED", review_code=review_code),
            assigned_user="Compliance Officer",
        )
        db.refresh(saved)

    return saved


# --- SPECIALIZED CERTIFICATE DRAFT GENERATORS, EXTRACTION & CROSS-MATCHING ---



def extract_document_service(request: DocumentExtractRequest) -> DocumentExtractResponse:
    raw_text = request.raw_text or ""
    doc_type = request.document_type.upper()
    warnings = []
    is_draft = False

    if "CHINA" in doc_type or "CCPIT" in doc_type:
        data = extract_coo_china_ccpit_text(raw_text)
    elif "EUR" in doc_type or "EUR1" in doc_type:
        data = extract_eur1_certificate_text(raw_text)
        if not data.get("is_revised_rules"):
            warnings.append("تنبيه: عبارة 'REVISED RULES' غير واضحة في خانة الملاحظات 7 - قد لا يُقبل الإعفاء التفضيلى.")
    elif "AGADIR" in doc_type:
        data = extract_agadir_gafta_form_a_coo_text(raw_text, "AGADIR")
    elif "GAFTA" in doc_type:
        data = extract_agadir_gafta_form_a_coo_text(raw_text, "GAFTA")
    elif "FORM_A" in doc_type or "FORM A" in doc_type or "GSP" in doc_type:
        data = extract_agadir_gafta_form_a_coo_text(raw_text, "FORM_A")
    elif "STANDARD" in doc_type or "COO" in doc_type:
        data = extract_standard_coo_text(raw_text)
    elif "PSI" in doc_type or "PRE_SHIPMENT" in doc_type or "PRE-SHIPMENT" in doc_type:
        data = extract_psi_certificate_text(raw_text)
        is_draft = data.get("is_draft", False)
        if is_draft:
            warnings.append("تحذير: تقرير الفحص المسبق يحمل صفة مسودة (DRAFT) - يلزم اعتماد النسخة النهائية.")
    elif "COA" in doc_type or "ANALYSIS" in doc_type:
        data = extract_coa_certificate_text(raw_text)
    elif "INSP" in doc_type or "VOC" in doc_type or "COC" in doc_type:
        data = extract_inspection_voc_certificate_text(raw_text)
        is_draft = data.get("is_draft", False)
        if is_draft:
            warnings.append("تحذير: الشهادة الحالية تحمل صفة مسودة (DRAFT) - يجب تأكيدها خلال 48 ساعة وإصدار النسخة الرسمية.")
    elif "BL" in doc_type:
        data = extract_draft_bl_data(raw_text)
    elif "INV" in doc_type or "INVOICE" in doc_type:
        data = extract_commercial_invoice_data(raw_text)
    else:
        # Generic heuristic extraction
        acid_m = re.search(r'\b([0-9]{19})\b', raw_text)
        data = {
            "raw_text_length": len(raw_text),
            "acid_number": acid_m.group(1) if acid_m else "",
        }

    return DocumentExtractResponse(
        document_type=request.document_type,
        extracted_data=data,
        warnings=warnings,
        is_draft_detected=is_draft,
    )


def cross_match_certificates_service(db: Session, request: ThreeWayCrossMatchRequest) -> ThreeWayCrossMatchResponse:
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == request.import_file_id).first()
    if not imp_file:
        raise HTTPException(status_code=404, detail="Import File not found")

    company = db.query(ImportCompany).filter(ImportCompany.company_id == imp_file.company_id).first() if imp_file.company_id else None
    supplier = db.query(Supplier).filter(Supplier.supplier_id == imp_file.supplier_id).first() if imp_file.supplier_id else None
    acid_session = db.query(AcidRegistrationSession).filter(
        AcidRegistrationSession.import_file_id == request.import_file_id,
        AcidRegistrationSession.is_active == True
    ).first()

    sys_acid = (acid_session.acid_number if acid_session else None) or imp_file.acid_number
    sys_importer = (company.importer_name if company else imp_file.company_name) or ""
    sys_supplier = (supplier.company_name if supplier else imp_file.supplier_name) or ""

    coo = request.coo_data or {}
    insp = request.inspection_data or {}
    bl = request.bl_data or {}
    inv = request.invoice_data or {}
    pkg = request.packing_list_data or {}

    matrix = []
    critical_discrepancies = []
    warning_discrepancies = []

    # 1. ACID Number Cross-Check
    coo_acid = coo.get("acid_number") or ""
    insp_acid = insp.get("acid_number") or ""
    bl_acid = bl.get("acid_number") or ""
    inv_acid = inv.get("acid_number") or ""

    acids_present = [a for a in [sys_acid, coo_acid, insp_acid, bl_acid, inv_acid] if a]
    acid_match = True
    if acids_present:
        first_acid = acids_present[0]
        for a in acids_present:
            if a != first_acid:
                acid_match = False
                break

    if acid_match and acids_present:
        matrix.append({
            "check_item": "رقم القيد الجمركي المسبق (ACID Number 19-digits)",
            "status": "MATCH",
            "severity": "NONE",
            "system_value": sys_acid,
            "compared_values": {"coo": coo_acid, "inspection": insp_acid, "bl": bl_acid, "invoice": inv_acid},
            "details": f"مطابقة تامة لرقم الـ ACID ({first_acid}) عبر كافة المستندات.",
        })
    else:
        critical_discrepancies.append("اختلاف أو غياب في رقم الـ ACID بين المستندات الجمركية!")
        matrix.append({
            "check_item": "رقم القيد الجمركي المسبق (ACID Number 19-digits)",
            "status": "MISMATCH_CRITICAL",
            "severity": "BLOCKING",
            "system_value": sys_acid,
            "compared_values": {"coo": coo_acid, "inspection": insp_acid, "bl": bl_acid, "invoice": inv_acid},
            "details": "عدم تطابق رقم الـ ACID يمنع الإفراج الجمركي على منظومة نافذة.",
        })

    # 2. Importer / Consignee Cross-Check
    coo_imp = coo.get("importer_name") or ""
    insp_imp = insp.get("importer_name") or ""
    bl_imp = bl.get("consignee") or bl.get("importer_name") or ""
    m1, r1 = _fuzzy_match(sys_importer, coo_imp)
    m2, r2 = _fuzzy_match(sys_importer, insp_imp)
    m3, r3 = _fuzzy_match(sys_importer, bl_imp)
    imp_matched = (m1 or not coo_imp) and (m2 or not insp_imp) and (m3 or not bl_imp)

    matrix.append({
        "check_item": "اسم الشركة المستوردة (Importer / Consignee)",
        "status": "MATCH" if imp_matched else "MISMATCH_CRITICAL",
        "severity": "NONE" if imp_matched else "BLOCKING",
        "system_value": sys_importer,
        "compared_values": {"coo": coo_imp, "inspection": insp_imp, "bl": bl_imp},
        "details": "مطابقة اسم المستورد المصري" if imp_matched else "تطابق اسم المستورد مع السجل التجاري والبطاقة الاستيرادية مطلوب.",
    })
    if not imp_matched:
        critical_discrepancies.append("اختلاف اسم المستورد بين مسودة البوليصة والشهادات.")

    # 3. Exporter / Supplier Cross-Check
    coo_exp = coo.get("exporter_name") or ""
    insp_exp = insp.get("exporter_name") or ""
    bl_exp = bl.get("shipper") or bl.get("exporter_name") or ""
    e1, _ = _fuzzy_match(sys_supplier, coo_exp)
    e2, _ = _fuzzy_match(sys_supplier, insp_exp)
    e3, _ = _fuzzy_match(sys_supplier, bl_exp)
    exp_matched = (e1 or not coo_exp) and (e2 or not insp_exp) and (e3 or not bl_exp)

    matrix.append({
        "check_item": "المورد / المصدر الأجنبي (Exporter / Shipper)",
        "status": "MATCH" if exp_matched else "MISMATCH_CRITICAL",
        "severity": "NONE" if exp_matched else "BLOCKING",
        "system_value": sys_supplier,
        "compared_values": {"coo": coo_exp, "inspection": insp_exp, "bl": bl_exp},
        "details": "مطابقة تامة لبيانات المصنع والمورد الأجنبي" if exp_matched else "اختلاف في اسم أو عنوان المصدر الأجنبي.",
    })
    if not exp_matched:
        critical_discrepancies.append("اختلاف في بيانات المورد الأجنبي.")

    # 4. Gross Weight Cross-Check
    coo_wt = float(coo.get("gross_weight_kg") or 0.0)
    bl_wt = float(bl.get("total_gross_weight") or bl.get("gross_weight_kg") or 0.0)
    pkg_wt = float(pkg.get("total_gross_weight_kg") or 0.0)
    wts = [w for w in [coo_wt, bl_wt, pkg_wt] if w > 0]
    wt_matched = True
    if len(wts) >= 2:
        max_w = max(wts)
        min_w = min(wts)
        diff_pct = abs(max_w - min_w) / max_w * 100
        if diff_pct > 0.5:
            wt_matched = False
            warning_discrepancies.append(f"فرق في الوزن القائم بين المستندات بنسبة ({diff_pct:.2f}%).")

    sys_weight_val = getattr(imp_file, 'total_weight', None) or (pkg.get('total_gross_weight_kg') if pkg else None) or coo_wt or bl_wt or 0.0

    matrix.append({
        "check_item": "الوزن القائم الإجمالي (Total Gross Weight KG)",
        "status": "MATCH" if wt_matched else "MISMATCH_MINOR",
        "severity": "NONE" if wt_matched else "WARNING",
        "system_value": f"{sys_weight_val} KG",
        "compared_values": {"coo_weight": coo_wt, "bl_weight": bl_wt, "packing_weight": pkg_wt},
        "details": "الوزن متطابق ضمن نسبة السماح 0.5%" if wt_matched else "يرجى توحيد الوزن القائم في البوليصة وقائمة التعبئة لتفادي غرامات الجمارك.",
    })

    # 5. EUR.1 Revised Rules Exemption Check
    if "EUR" in str(coo.get("certificate_type", "")).upper():
        revised = coo.get("is_revised_rules", False) or "REVISED RULES" in str(coo.get("remarks", "")).upper()
        matrix.append({
            "check_item": "شرط القواعد المعدلة لليورو 1 (EUR.1 Box 7 REVISED RULES)",
            "status": "MATCH" if revised else "MISMATCH_CRITICAL",
            "severity": "NONE" if revised else "BLOCKING",
            "system_value": "REVISED RULES (إلزامي للإعفاء)",
            "compared_values": {"coo_remarks": coo.get("remarks", "")},
            "details": "مستوفٍ لقواعد المنشأ المعدلة وتطبيق ضريبة وارد 0%" if revised else "تحذير: غياب عبارة REVISED RULES قد يؤدي لرفض الإعفاء الجمركي.",
        })
        if not revised:
            critical_discrepancies.append("غياب عبارة REVISED RULES في الخانة 7 بشهادة EUR.1.")

    # 6. Inspection Draft Warning Check
    if insp.get("is_draft"):
        matrix.append({
            "check_item": "حالة شهادة الفحص (Inspection Cert Draft Status)",
            "status": "MISMATCH_MINOR",
            "severity": "WARNING",
            "system_value": "Original Final Certificate Required",
            "compared_values": {"status": "DRAFT", "warning": insp.get("draft_warning")},
            "details": "الشهادة مسودة DRAFT وتحتاج إلى تأكيد لإصدار النسخة النهائية المرقمة والموقعة.",
        })
        warning_discrepancies.append("شهادة الفحص والتفتيش الحالية مسودة وتحتاج إلى اعتماد نهائي.")

    is_safe = len(critical_discrepancies) == 0
    total_checks = len(matrix)
    passed_checks = len([m for m in matrix if m["status"] == "MATCH"])
    score = round((passed_checks / total_checks) * 100, 1) if total_checks > 0 else 100.0

    overall = "FULLY_MATCHED" if (is_safe and not warning_discrepancies) else ("ACCEPTED_WITH_WARNINGS" if is_safe else "DISCREPANCY_DETECTED")

    summary_ar = (
        f"اكتمل الفحص المتقاطع للمستندات بنسبة مطابقة {score}%. "
        + ("الشحنة مستوفية وجاهزة للربط والاعتماد الجمركي." if is_safe else f"يوجد {len(critical_discrepancies)} أخطاء حرجة تتطلب التصحيح الفوري قبل الشحن والإفراج.")
    )

    return ThreeWayCrossMatchResponse(
        import_file_id=request.import_file_id,
        import_file_code=imp_file.import_file_code or f"IMP-{request.import_file_id:04d}",
        overall_status=overall,
        match_score=score,
        is_safe_for_customs=is_safe,
        matrix=matrix,
        critical_discrepancies=critical_discrepancies,
        warning_discrepancies=warning_discrepancies,
        compliance_summary_ar=summary_ar,
    )


# --- 5. ACID & IMPORTER LEGAL DOCS EXPIRY & ETA + 30 DAYS SAFETY MARGIN ENGINE ---
_LEGAL_STATUS_CODES = {
    "EXPIRED": "DOC_LEGAL_DOC_EXPIRED",
    "CRITICAL_BREACH": "DOC_LEGAL_DOC_CRITICAL_BREACH",
    "EXPIRING_SOON": "DOC_LEGAL_DOC_EXPIRING_SOON",
    "VALID": "DOC_LEGAL_DOC_VALID",
}


def _legal_message(status_str: str, doc_kind: str, doc_number: Any, expiry: Any, eta: Any, days: int) -> Dict[str, Any]:
    """message_code + message_params of a legal-document alert (DOC-19 / C6; doc_kind = LEGAL_DOC_KIND code).
    Codes are registered centrally (see docs/plans/review-shared-needs.md)."""
    return {
        "message_code": _LEGAL_STATUS_CODES[status_str],
        "message_params": {"doc_kind": doc_kind, "doc_number": doc_number,
                           "expiry_date": str(expiry) if expiry else None, "eta_date": str(eta) if eta else None,
                           "days": days},
    }


def check_acid_and_company_docs_validity_service(db: Session, import_file_id: int) -> LegalDocsExpiryComplianceResponse:
    imp_file = _active_import_file(db, import_file_id, status_code=status.HTTP_404_NOT_FOUND)

    company = db.query(ImportCompany).filter(ImportCompany.company_id == imp_file.company_id).first() if imp_file.company_id else None
    booking = db.query(ShipmentBooking).filter(ShipmentBooking.import_file_id == import_file_id, ShipmentBooking.is_active == True).first()
    acid_session = db.query(AcidRegistrationSession).filter(AcidRegistrationSession.import_file_id == import_file_id, AcidRegistrationSession.is_active == True).first()

    today = date.today()

    # Determine Estimated Time of Arrival (ETA)
    eta_date: Optional[date] = None
    eta_source = "Estimated"

    if booking and booking.eta:
        eta_date = booking.eta.date() if hasattr(booking.eta, "date") else booking.eta
        eta_source = "Freight Booking (حجز الشحن الملاحي)"
    elif imp_file.required_eta:
        eta_date = imp_file.required_eta
        eta_source = "Import File (ملف الشحنة)"
    else:
        # Default safety assumption: DEFAULT_ETA_DAYS from today
        eta_date = today + timedelta(days=DEFAULT_ETA_DAYS)
        eta_source = "Estimated Default (+21 Days)"

    safety_window_date = eta_date + timedelta(days=ETA_SAFETY_MARGIN_DAYS)

    alerts: List[LegalDocAlertItem] = []
    has_critical_alerts = False

    # 1. ACID Expiry Check
    if acid_session and acid_session.expiry_date:
        acid_exp = acid_session.expiry_date
        days_rem = (acid_exp - today).days
        days_after_eta = (acid_exp - eta_date).days
        is_exp = days_rem <= 0
        is_breach = acid_exp <= safety_window_date
        
        if is_exp:
            status_str = "EXPIRED"
            msg = f"رقم الـ ACID ({acid_session.acid_number}) منتهي الصلاحية بتاريخ {acid_exp}. لا يمكن شحن البضائع أو الإفراج الجمركي!"
            has_critical_alerts = True
        elif is_breach:
            status_str = "CRITICAL_BREACH"
            msg = f"تحذير حرج: رقم الـ ACID ينتهي في {acid_exp} (أقل من 30 يوماً بعد تاريخ الوصول المتوقع {eta_date}). متبقي {days_after_eta} يوم فقط بعد الـ ETA."
            has_critical_alerts = True
        else:
            status_str = "VALID"
            msg = f"رقم الـ ACID ساري وصالح حتى {acid_exp} (صالح لمدة {days_after_eta} يوم بعد وصول الشحنة)."

        alerts.append(LegalDocAlertItem(
            doc_type="رقم الـ ACID للشحنة (Nafeza ACID)",
            doc_number=acid_session.acid_number,
            expiry_date=acid_exp,
            days_until_expiry=days_rem,
            days_after_eta=days_after_eta,
            is_expired=is_exp,
            is_critical_breach=is_breach,
            alert_message=msg,
            status=status_str,
            **_legal_message(status_str, "ACID", acid_session.acid_number, acid_exp, eta_date, days_rem),
        ))
    else:
        alerts.append(LegalDocAlertItem(
            doc_type="رقم الـ ACID للشحنة (Nafeza ACID)",
            doc_number=imp_file.acid_number or "لم يصدر بعد",
            expiry_date=None,
            days_until_expiry=0,
            days_after_eta=None,
            is_expired=False,
            is_critical_breach=True,
            alert_message="لم يتم استخراج أو تسجيل تاريخ صلاحية الـ ACID للشحنة بعد.",
            status="CRITICAL_BREACH",
            message_code="DOC_LEGAL_ACID_MISSING",
            message_params={"doc_kind": "ACID", "doc_number": imp_file.acid_number, "expiry_date": None,
                            "eta_date": str(eta_date), "days": None},
        ))
        has_critical_alerts = True

    # 2. Importer Legal Documents Checks (Import Card, Commercial Registry, Tax Card)
    if company:
        docs_to_check = [
            ("البطاقة الاستيرادية (Import Card)", company.importer_id or "—", company.importer_id_expiry, "IMPORT_CARD"),
            ("السجل التجاري (Commercial Registry)", company.registration_number or "—", company.registration_expiry, "COMMERCIAL_REGISTRY"),
            ("البطاقة الضريبية / ملف القيمة المضافة (Tax Card)", company.vat_id or "—", company.vat_id_expiry, "TAX_CARD"),
        ]

        for doc_name, doc_num, exp_dt, doc_kind in docs_to_check:
            if exp_dt:
                days_rem = (exp_dt - today).days
                days_after_eta = (exp_dt - eta_date).days
                is_exp = days_rem <= 0
                is_breach = exp_dt <= safety_window_date

                if is_exp:
                    status_str = "EXPIRED"
                    msg = f"وثيقة {doc_name} منتهية بتاريخ {exp_dt}! يجب تجديدها فوراً وإلا ستتوقف إجراءات الإفراج الجمركي."
                    has_critical_alerts = True
                elif is_breach:
                    status_str = "CRITICAL_BREACH"
                    msg = f"تحذير حرج: {doc_name} تنتهي في {exp_dt} (قبل نافذة الـ 30 يوماً من وصول الشحنة في {eta_date})."
                    has_critical_alerts = True
                elif days_rem <= COMPANY_DOC_EXPIRING_SOON_DAYS:
                    status_str = "EXPIRING_SOON"
                    msg = f"{doc_name} قاربت على الانتهاء في {exp_dt} (متبقي {days_rem} يوم)."
                else:
                    status_str = "VALID"
                    msg = f"{doc_name} سارية وصالحة حتى {exp_dt}."

                alerts.append(LegalDocAlertItem(
                    doc_type=doc_name,
                    doc_number=str(doc_num),
                    expiry_date=exp_dt,
                    days_until_expiry=days_rem,
                    days_after_eta=days_after_eta,
                    is_expired=is_exp,
                    is_critical_breach=is_breach,
                    alert_message=msg,
                    status=status_str,
                    **_legal_message(status_str, doc_kind, str(doc_num), exp_dt, eta_date, days_rem),
                ))

    # Overall Compliance Calculation
    overall_status = "CRITICAL_ACTION_REQUIRED" if has_critical_alerts else "COMPLIANT"
    banner_text = None
    if has_critical_alerts:
        critical_msgs = [a.alert_message for a in alerts if a.is_critical_breach or a.is_expired]
        banner_text = "🚨 تحذير حرج لسلامة الشحنة والإفراج الجمركي (ETA + 30 Days Safety Margin):\n" + "\n".join(critical_msgs)

    return LegalDocsExpiryComplianceResponse(
        import_file_id=import_file_id,
        import_file_code=imp_file.import_file_code or f"IMP-{import_file_id}",
        company_name=company.importer_name if company else (imp_file.company_name or ""),
        eta_date=eta_date,
        eta_source=eta_source,
        safety_window_date=safety_window_date,
        has_critical_alerts=has_critical_alerts,
        total_alerts_count=len(alerts),
        alerts=alerts,
        overall_compliance_status=overall_status,
        persistent_banner_text=banner_text,
        # DOC-19 / C6: coded twin of the Arabic banner (the client lists the coded alerts under it).
        banner_message_code="DOC_LEGAL_BANNER" if has_critical_alerts else None,
        banner_message_params={"critical_count": sum(1 for a in alerts if a.is_critical_breach or a.is_expired)} if has_critical_alerts else None,
    )



def get_coo_reviews_service(
    db: Session,
    include_inactive: bool = False,
    import_file_id: int = None,
    status: str = None,
    search: str = None,
    is_draft: bool = None,
    skip: int = 0,
    limit: int | None = None,
    return_total: bool = False,
):
    return repo.get_coo_reviews(
        db,
        include_inactive=include_inactive,
        import_file_id=import_file_id,
        status=status,
        search=search,
        is_draft=is_draft,
        skip=skip,
        limit=limit,
        return_total=return_total,
    )

def delete_coo_review_service(db: Session, review_id: int, user: Optional[str] = None) -> dict:
    review = repo.get_coo_review_by_id(db, review_id)
    if not review:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"جلسة مراجعة شهادة المنشأ رقم {review_id} غير موجودة للحذف.",
        )
    if not review.is_draft:
        raise _conflict(
            f"دراسة شهادة المنشأ ({review.coo_review_code}) معتمدة ومقفلة: لا يمكن حذف دراسة معتمدة."
        )
    ok = repo.delete_coo_review(db, review_id)
    if not ok:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"جلسة مراجعة شهادة المنشأ رقم {review_id} غير موجودة للحذف.",
        )
    db.commit()
    return {"message": f"تم حذف جلسة مراجعة المنشأ رقم {review_id} بنجاح", "deleted": True}

def get_inspection_reviews_service(
    db: Session,
    include_inactive: bool = False,
    import_file_id: int = None,
    status: str = None,
    search: str = None,
    skip: int = 0,
    limit: int | None = None,
    return_total: bool = False,
):
    return repo.get_inspection_reviews(
        db,
        include_inactive=include_inactive,
        import_file_id=import_file_id,
        status=status,
        search=search,
        skip=skip,
        limit=limit,
        return_total=return_total,
    )

def delete_inspection_review_service(db: Session, review_id: int, user: Optional[str] = None) -> dict:
    ok = repo.delete_inspection_review(db, review_id)
    if not ok:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"جلسة مراجعة شهادة الفحص رقم {review_id} غير موجودة للحذف.",
        )
    db.commit()
    return {"message": f"تم حذف جلسة مراجعة شهادة الفحص رقم {review_id} بنجاح", "deleted": True}



def extract_certificate_file_service(
    document_type: str, filename: str, content: bytes, import_file_id: Optional[int]
) -> DocumentExtractResponse:
    raw_text = extract_text_from_uploaded_file(filename, content)
    return extract_document_service(DocumentExtractRequest(
        document_type=document_type,
        raw_text=raw_text,
        import_file_id=import_file_id,
    ))

