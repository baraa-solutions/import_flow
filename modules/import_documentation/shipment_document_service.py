"""
Shipment Documents, Endorsement, and Central Document Archive Service (Phase 3 - BP-016).
"""

import logging
from datetime import date, datetime, timezone, timedelta
from typing import Any, Dict, List, Optional, Set, Tuple
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

logger = logging.getLogger(__name__)

from modules.import_documentation.model import (
    ShipmentDocumentItem,
    CustomsDeclarationDraft,
    DraftBLReviewSession,
    AcidRegistrationSession,
    BankingDocumentSession,
    CertificateOfOriginReviewSession,
    InspectionCertificateReviewSession,
    InvoiceBLMatchSession,
    POPackingReconciliationSession,
)
from modules.import_files.model import ImportFile
from modules.import_documentation.schemas import *
from modules.import_documentation.validators import (
    validate_no_duplicate_declaration_draft,
    validate_acid_number,
    validate_status,
)
import modules.import_documentation.repository as repo
from modules.common.system_messages import coded_text, msg, render_en
from modules.common.enum_codes import Placeholder, finalize_structured_values
from modules.common.file_tracking import set_file_tracking
from modules.common.errors import best_effort
from modules.common.validators import not_found, require_active
from modules.import_files.repository import codes_by_ids

from modules.import_documentation.doc_common import (
    SYSTEM_ACTOR,
    LABEL_IMPORT_FILE,
    LABEL_SHIPMENT_DOC,
    LABEL_PURCHASE_ORDER,
    _actor,
    _bad_request,
    _conflict,
    _active_import_file,
    _get_active_import_file,
    _require_active_po,
    _commit_follow_up,
    _lifecycle_follow_up,
    get_import_files_map,
)

def enrich_shipment_doc_response(db: Session, item: ShipmentDocumentItem, import_file: Optional[Any] = None):
    import_file_code = None
    if item.import_file_id:
        if import_file is not None:
            import_file_code = import_file.import_file_code or import_file.custom_file_number
        else:
            import_file_code = codes_by_ids(db, [item.import_file_id]).get(item.import_file_id)

    from modules.import_documentation.schemas import ShipmentDocumentResponse
    res = ShipmentDocumentResponse.model_validate(item)
    res.import_file_code = import_file_code
    return res



def create_shipment_document_service(
    db: Session, schema: ShipmentDocumentCreate, user: Optional[str] = None
):
    if schema.import_file_id is not None:
        _active_import_file(db, schema.import_file_id)
    _require_active_po(db, schema.po_id)
    item = repo.create_shipment_document(db, schema, user=user)
    return enrich_shipment_doc_response(db, item)


def list_shipment_documents_service(
    db: Session,
    import_file_id: Optional[int] = None,
    skip: int = 0,
    limit: Optional[int] = None,
    return_total: bool = False,
) -> Union[List[Any], Tuple[List[Any], int]]:
    res = repo.get_all_shipment_documents(
        db, import_file_id=import_file_id, skip=skip, limit=limit, return_total=return_total
    )
    if return_total:
        items, total = res
    else:
        items, total = res, len(res)

    import_files_map = get_import_files_map(db, [item.import_file_id for item in items])
    enriched = [enrich_shipment_doc_response(db, item, import_file=import_files_map.get(item.import_file_id)) for item in items]
    return (enriched, total) if return_total else enriched


def update_cargox_and_bl_endorsement_service(
    db: Session,
    doc_id: int,
    cargox_envelope_id: str | None = None,
    endorsement_number: str | None = None,
    user: Optional[str] = None,
):
    exists = (
        db.query(ShipmentDocumentItem.document_id)
        .filter(ShipmentDocumentItem.document_id == doc_id, ShipmentDocumentItem.is_active == True)
        .first()
    )
    if not exists:
        raise not_found(LABEL_SHIPMENT_DOC, doc_id)

    schema = ShipmentDocumentUpdate()
    if cargox_envelope_id:
        schema.is_cargox_uploaded = True
        schema.cargox_envelope_id = cargox_envelope_id
    if endorsement_number:
        schema.is_bl_endorsed = True
        schema.endorsement_number = endorsement_number
        schema.status = "Endorsed"

    item = repo.update_shipment_document(db, doc_id, schema, user=user)
    return enrich_shipment_doc_response(db, item)


# --- CUSTOMS DECLARATION SERVICE ---
def create_customs_declaration_service(
    db: Session, schema: CustomsDeclarationCreate, user: Optional[str] = None
) -> CustomsDeclarationResponse:
    validate_acid_number(schema.acid_number, allow_pending=False)

    imp_file = None
    if schema.import_file_id is not None:
        imp_file = _active_import_file(db, schema.import_file_id)
        validate_no_duplicate_declaration_draft(db, schema.import_file_id)
        if imp_file.acid_number:
            clean_file_acid = imp_file.acid_number.strip()
            if clean_file_acid and clean_file_acid.upper() not in ["PENDING", "REQUESTED", "DRAFT", ""]:
                if schema.acid_number.strip() != clean_file_acid:
                    raise _conflict(
                        f"رقم ACID في الإقرار ({schema.acid_number}) لا يطابق رقم ACID المسجل للملف ({clean_file_acid})."
                    )

    _require_active_po(db, schema.po_id)
    item = repo.create_customs_declaration(db, schema, user=user)

    amounts_entered = any(
        v is not None
        for v in (schema.total_cif_val_egp, schema.total_customs_duties_egp, schema.total_vat_egp)
    )

    import_file_code = None
    if imp_file:
        import_file_code = imp_file.import_file_code or imp_file.custom_file_number
    elif item.import_file_id:
        import_file_code = codes_by_ids(db, [item.import_file_id]).get(item.import_file_id)

    return CustomsDeclarationResponse(
        declaration_id=item.declaration_id,
        declaration_code=item.declaration_code,
        import_file_id=item.import_file_id,
        import_file_code=import_file_code,
        po_id=item.po_id,
        acid_number=item.acid_number,
        form4_number=item.form4_number,
        bl_number=item.bl_number,
        total_cif_val_egp=schema.total_cif_val_egp,
        total_customs_duties_egp=schema.total_customs_duties_egp,
        total_vat_egp=schema.total_vat_egp,
        amounts_entered=amounts_entered,
        declaration_status=item.declaration_status,
        is_active=item.is_active,
        created_at=item.created_at,
        updated_at=item.updated_at,
        created_by=item.created_by,
        updated_by=item.updated_by,
    )


# ==============================================================================
# PHASE 6: INTELLIGENT DOCUMENT VERIFICATION & COMPARISON ENGINES
# ==============================================================================
import difflib
from modules.import_files.model import ImportFile
from modules.purchase_orders.model import PurchaseOrder, POLineItem, PackingListItem
from modules.freight_booking.model import ShipmentBooking
from modules.cargo_shipping.model import CargoShippingRecord
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.import_documentation.model import (
    DraftBLReviewSession,
    CertificateOfOriginReviewSession,
    InspectionCertificateReviewSession,
)
from modules.import_documentation.schemas import (
    POFinalAdjustmentRequest,
    DraftBLReviewCreate,
    DraftBLReviewUpdate,
    DraftBLReviewResponse,
    DraftBLComparisonRequest,
    CertificateOfOriginReviewCreate,
    CertificateOfOriginReviewUpdate,
    CertificateOfOriginReviewResponse,
    COOComparisonRequest,
    InspectionCertificateReviewCreate,
    InspectionCertificateReviewUpdate,
    LegalDocsExpiryComplianceResponse,
    LegalDocAlertItem,
    InvoiceBLExtractAndMatchRequest,
    InvoiceBLExtractAndMatchResponse,
    InvoiceBLSyncRequest,
    POExtractAndCompareRequest,
    POExtractAndCompareResponse,
)





def get_all_shipment_documents_service(
    db: Session,
    import_file_id: int = None,
    skip: int = 0,
    limit: int | None = None,
    return_total: bool = False,
):
    return repo.get_all_shipment_documents(
        db,
        import_file_id=import_file_id,
        skip=skip,
        limit=limit,
        return_total=return_total,
    )



def get_central_archive_service(db: Session, import_file_id: int) -> CentralArchiveResponse:
    from modules.import_requirements.model import ImportRequirementAssessment
    from modules.import_files.model import ImportFile
    from modules.import_companies.model import ImportCompany
    from modules.suppliers.model import Supplier
    from modules.cargo_shipping.model import ShipmentBooking

    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
    if not imp_file:
        raise HTTPException(status_code=404, detail="Import File not found")

    company = db.query(ImportCompany).filter(ImportCompany.company_id == imp_file.company_id).first() if imp_file.company_id else None
    supplier = db.query(Supplier).filter(Supplier.supplier_id == imp_file.supplier_id).first() if imp_file.supplier_id else None
    booking = db.query(ShipmentBooking).filter(
        ShipmentBooking.import_file_id == import_file_id,
        ShipmentBooking.is_active == True
    ).first()
    acid_session = db.query(AcidRegistrationSession).filter(
        AcidRegistrationSession.import_file_id == import_file_id,
        AcidRegistrationSession.is_active == True
    ).first()
    po_reconciliation = db.query(POPackingReconciliationSession).filter(
        POPackingReconciliationSession.import_file_id == import_file_id,
        POPackingReconciliationSession.is_active == True
    ).first()
    bl_review = db.query(DraftBLReviewSession).filter(
        DraftBLReviewSession.import_file_id == import_file_id,
        DraftBLReviewSession.is_active == True
    ).order_by(DraftBLReviewSession.bl_review_id.desc()).first()
    coo_review = db.query(CertificateOfOriginReviewSession).filter(
        CertificateOfOriginReviewSession.import_file_id == import_file_id,
        CertificateOfOriginReviewSession.is_active == True
    ).order_by(CertificateOfOriginReviewSession.coo_review_id.desc()).first()
    inspection_review = db.query(InspectionCertificateReviewSession).filter(
        InspectionCertificateReviewSession.import_file_id == import_file_id,
        InspectionCertificateReviewSession.is_active == True
    ).order_by(InspectionCertificateReviewSession.inspection_review_id.desc()).first()

    # Query Import Requirement Assessment (BP-011)
    assessment = db.query(ImportRequirementAssessment).filter(
        ImportRequirementAssessment.import_file_id == import_file_id,
        ImportRequirementAssessment.is_active == True
    ).order_by(ImportRequirementAssessment.assessment_id.desc()).first()
    if not assessment and imp_file.supplier_id:
        assessment = db.query(ImportRequirementAssessment).filter(
            ImportRequirementAssessment.supplier_id == imp_file.supplier_id,
            ImportRequirementAssessment.is_active == True
        ).order_by(ImportRequirementAssessment.assessment_id.desc()).first()

    # Determine Country of Origin
    origin_country = (
        (assessment.country_of_origin if assessment and assessment.country_of_origin else None)
        or (coo_review.country_of_origin if coo_review and coo_review.country_of_origin else None)
        or (supplier.foreign_exporter_country if supplier and supplier.foreign_exporter_country else None)
        or (getattr(imp_file, 'country_of_origin', None))
        or "European Union / International"
    )

    eu_countries = [
        'lithuania', 'germany', 'italy', 'france', 'spain', 'poland', 'belgium',
        'netherlands', 'austria', 'czech', 'sweden', 'denmark', 'finland', 'greece',
        'portugal', 'hungary', 'ireland', 'romania', 'bulgaria', 'slovakia', 'slovenia',
        'croatia', 'latvia', 'estonia', 'cyprus', 'malta', 'luxembourg', 'eu', 'europe', 'european'
    ]
    is_eu_origin = any(c in origin_country.lower() for c in eu_countries) or (coo_review and coo_review.certificate_type == "EUR.1")

    # Evaluate COO / EUR.1 Requirements (Rule 2: Conditional by Tariff/Origin)
    tariff_exemption_alert = None
    if assessment and assessment.coo_required:
        coo_is_mandatory = True
        coo_is_waived = False
        if is_eu_origin or assessment.coo_type == "EUR.1":
            coo_legal_note = "مطلوبة شهادة EUR.1 مدوناً بها عبارة 'REVISED RULES' بالخانة 7 لتطبيق إعفاء 0% ضريبة وارد."
            tariff_exemption_alert = "⚠️ فرصة إعفاء جمركي: الشحنة مؤهلة لإعفاء كامل (0% ضريبة وارد) بموجب الشراكة المصرية الأوروبية، بشرط تقديم شهادة EUR.1 مدوناً بها عبارة 'REVISED RULES' بالخانة 7."
        else:
            coo_legal_note = "مطلوبة شهادة منشأ معتمدة لإثبات المنشأ الجمركي ومطابقة التعرفة."
    elif assessment and not assessment.coo_required:
        coo_is_mandatory = False
        coo_is_waived = True
        coo_legal_note = "غير مطلوبة / معفاة قانونياً وفق تقييم متطلبات الاستيراد (BP-011)."
    else:
        # Default heuristic based on origin
        if is_eu_origin:
            coo_is_mandatory = True
            coo_is_waived = False
            coo_legal_note = "مطلوبة شهادة EUR.1 بعبارة 'REVISED RULES' للاستفادة من الإعفاء الجمركي 0%."
            tariff_exemption_alert = "⚠️ فرصة إعفاء جمركي: الشحنة مؤهلة لإعفاء كامل (0% ضريبة وارد) بموجب الشراكة المصرية الأوروبية، بشرط تقديم شهادة EUR.1 مدوناً بها عبارة 'REVISED RULES' بالخانة 7."
        elif "china" in origin_country.lower() or (coo_review and "ccpit" in str(coo_review.certificate_type).lower()):
            coo_is_mandatory = True
            coo_is_waived = False
            coo_legal_note = "مطلوبة شهادة منشأ الصين CCPIT إلكترونية مع باركود ورابط التحقق."
        else:
            coo_is_mandatory = False
            coo_is_waived = True
            coo_legal_note = "شهادة المنشأ غير ملزمة / معفاة لهذا البند الجمركي والمنشأ."

    # Evaluate Inspection Certificate (VoC / COC) Requirements (Rule 2: Conditional by GOEIC/NFSA)
    goeic_inspection_alert = None
    if assessment and assessment.inspection_required:
        insp_is_mandatory = True
        insp_is_waived = False
        insp_agency = assessment.inspection_body or "COTECNA / TÜV / SGS"
        insp_legal_note = f"خاضع لفحص الهيئة العامة للرقابة على الصادرات والواردات (GOEIC) وتفتيش ما قبل الشحن عبر ({insp_agency})."
        goeic_inspection_alert = f"⚠️ تنبيه فحص نوعي (GOEIC): البند الجمركي خاضع لفحص ما قبل الشحن من شركة معاينة معتمدة ({insp_agency}) مع ضرورة تدقيق مسودة الـ 48 ساعة."
    elif assessment and not assessment.inspection_required:
        insp_is_mandatory = False
        insp_is_waived = True
        insp_legal_note = "الصنف غير خاضع لفحص الصادرات والواردات (GOEIC) ولا يتطلب شهادة فحص ما قبل الشحن."
    else:
        # If an inspection review session exists, consider it active; otherwise waived
        if inspection_review is not None:
            insp_is_mandatory = True
            insp_is_waived = False
            insp_legal_note = f"تم إدراج فحص نوعي ما قبل الشحن عبر ({inspection_review.inspection_agency})."
        else:
            insp_is_mandatory = False
            insp_is_waived = True
            insp_legal_note = "غير خاضع لفحص ما قبل الشحن بموجب البند الجمركي."

    # Evaluate Decree 43 / White List
    decree_43_alert = None
    if assessment and assessment.decree_43_applicable:
        if not assessment.white_list_verified:
            supp_name = assessment.supplier_name or (supplier.company_name if supplier else (imp_file.supplier_name or "المورد"))
            decree_43_alert = f"⚠️ تنبيه قرار 43: المصنع ({supp_name}) خاضع للقرار 43/2016 ويلزم التحقق من قيده بالقائمة البيضاء للهيئة برقم: {assessment.factory_registration_no or 'غير مسجل'}"

    all_discrepancies = []
    total_critical = 0
    total_warning = 0

    # 1. Final Commercial Invoice (100% Mandatory Core)
    inv_available = po_reconciliation is not None and bool(po_reconciliation.final_invoice_number)
    inv_discrepancies = []
    if po_reconciliation and po_reconciliation.header_discrepancies:
        for d in po_reconciliation.header_discrepancies:
            if "invoice" in str(d.get("field", "")).lower() or "price" in str(d.get("field", "")).lower() or "amount" in str(d.get("field", "")).lower():
                sev = "CRITICAL" if d.get("severity") in ["CRITICAL", "BLOCKING"] else "WARNING"
                item = {
                    "document": "الفاتورة التجارية النهائية (Commercial Invoice)",
                    "field": d.get("field", "Invoice Field"),
                    "severity": sev,
                    "issue": d.get("issue", d.get("description", "عدم تطابق في الفاتورة")),
                    "rectification": d.get("rectification", "تعديل الفاتورة التجارية لتطابق أمر الشراء"),
                }
                inv_discrepancies.append(item)
                all_discrepancies.append(item)
                if sev == "CRITICAL": total_critical += 1
                else: total_warning += 1

    po_curr = po_reconciliation.currency.strip() if (po_reconciliation and po_reconciliation.currency) else None
    file_curr = (imp_file.estimated_cost_currency.strip() if getattr(imp_file, 'estimated_cost_currency', None) else None)
    archive_currency = po_curr or file_curr or None

    final_invoice = CentralArchiveDocumentSummary(
        document_type="FINAL_COMMERCIAL_INVOICE",
        title_ar="الفاتورة التجارية النهائية المعتمدة",
        is_available=inv_available,
        is_mandatory=True,
        is_waived=False,
        legal_requirement_note="مستند إلزامي حتمي لكافة الشحنات لإثبات القيمة الجمركية (CIF/FOB) والوعاء الضريبي.",
        status="APPROVED" if (inv_available and po_reconciliation.is_safe_for_certification) else ("REVIEW_PENDING" if inv_available else "NOT_STARTED"),
        document_reference=(po_reconciliation.final_invoice_number if po_reconciliation else None) or imp_file.pi_number,
        details={
            "invoice_number": (po_reconciliation.final_invoice_number if po_reconciliation else None) or imp_file.pi_number,
            "total_amount": float(po_reconciliation.total_invoice_amount) if po_reconciliation else float(getattr(imp_file, 'estimated_cost', 0.0) or 0.0),
            "currency": archive_currency,
            "shipper_name": (po_reconciliation.shipper_name if po_reconciliation else None) or (supplier.company_name if supplier else imp_file.supplier_name),
            "reconciled_items_count": len(po_reconciliation.reconciled_invoice_items or []) if po_reconciliation else 0,
            "certified_by": po_reconciliation.certified_by if po_reconciliation else None,
        },
        discrepancies=inv_discrepancies,
        last_updated=po_reconciliation.updated_at if po_reconciliation else None
    )

    # 2. Final Packing List (100% Mandatory Core)
    pkg_available = po_reconciliation is not None and bool(po_reconciliation.final_packing_list_number or po_reconciliation.total_packages)
    pkg_discrepancies = []
    if po_reconciliation and po_reconciliation.header_discrepancies:
        for d in po_reconciliation.header_discrepancies:
            if "weight" in str(d.get("field", "")).lower() or "package" in str(d.get("field", "")).lower() or "cbm" in str(d.get("field", "")).lower():
                sev = "CRITICAL" if d.get("severity") in ["CRITICAL", "BLOCKING"] else "WARNING"
                item = {
                    "document": "قائمة التعبئة النهائية (Packing List)",
                    "field": d.get("field", "Packing Field"),
                    "severity": sev,
                    "issue": d.get("issue", d.get("description", "عدم تطابق في التعبئة أو الوزن")),
                    "rectification": d.get("rectification", "تعديل قائمة التعبئة لتطابق الأوزان الفعلية"),
                }
                pkg_discrepancies.append(item)
                all_discrepancies.append(item)
                if sev == "CRITICAL": total_critical += 1
                else: total_warning += 1

    final_packing_list = CentralArchiveDocumentSummary(
        document_type="FINAL_PACKING_LIST",
        title_ar="قائمة التعبئة النهائية المعتمدة",
        is_available=pkg_available,
        is_mandatory=True,
        is_waived=False,
        legal_requirement_note="مستند إلزامي حتمي لتحديد الأوزان الصافية والقائمة وعدد الطرود وأرقام الحاويات للجمارك.",
        status="APPROVED" if (pkg_available and po_reconciliation.is_safe_for_certification) else ("REVIEW_PENDING" if pkg_available else "NOT_STARTED"),
        document_reference=(po_reconciliation.final_packing_list_number if po_reconciliation else None) or f"PL-{imp_file.import_file_code}",
        details={
            "packing_list_number": (po_reconciliation.final_packing_list_number if po_reconciliation else None) or f"PL-{imp_file.import_file_code}",
            "total_packages": int(po_reconciliation.total_packages) if po_reconciliation else 0,
            "total_gross_weight_kg": float(po_reconciliation.total_gross_weight_kg) if po_reconciliation else 0.0,
            "total_net_weight_kg": float(po_reconciliation.total_net_weight_kg) if po_reconciliation else 0.0,
            "total_cbm": float(po_reconciliation.total_cbm) if po_reconciliation else 0.0,
        },
        discrepancies=pkg_discrepancies,
        last_updated=po_reconciliation.updated_at if po_reconciliation else None
    )

    # 3. Draft Bill of Lading (100% Mandatory Core)
    bl_available = bl_review is not None
    bl_discrepancies = []
    if bl_review and bl_review.comparison_matrix:
        for row in bl_review.comparison_matrix:
            if row.get("status") in ["MISMATCH", "MISMATCH_CRITICAL", "MISMATCH_MINOR", "DIFF"]:
                sev = "CRITICAL" if row.get("severity") in ["BLOCKING", "CRITICAL"] or row.get("status") == "MISMATCH_CRITICAL" else "WARNING"
                item = {
                    "document": "مسودة بوليصة الشحن (Draft B/L)",
                    "field": row.get("field") or row.get("check_item", "B/L Field"),
                    "severity": sev,
                    "issue": f"القيمة في البوليصة: '{row.get('bl_val') or row.get('compared_value')}' مقابل النظام: '{row.get('sys_val') or row.get('system_value')}'",
                    "rectification": row.get("correction_instruction") or row.get("details") or "طلب تعديل درافت البوليصة من الخط الملاحي",
                }
                bl_discrepancies.append(item)
                all_discrepancies.append(item)
                if sev == "CRITICAL": total_critical += 1
                else: total_warning += 1

    draft_bl = CentralArchiveDocumentSummary(
        document_type="DRAFT_BL",
        title_ar="مسودة بوليصة الشحن (Draft B/L)",
        is_available=bl_available,
        is_mandatory=True,
        is_waived=False,
        legal_requirement_note="مستند إلزامي حتمي يثبت الشحن والناقل البحري ورقم القيد الجمركي ACID.",
        status="APPROVED" if (bl_available and bl_review.status in ["Approved", "APPROVED", "FINAL"]) else ("MODIFICATIONS_REQUESTED" if bl_discrepancies else ("REVIEW_PENDING" if bl_available else "NOT_STARTED")),
        document_reference=(bl_review.draft_bl_number if bl_review else None) or (getattr(booking, 'booking_confirmation_no', None) or getattr(booking, 'booking_code', None) if booking else None),
        details={
            "draft_bl_number": (bl_review.draft_bl_number if bl_review else None) or "DRAFT-BL",
            "shipping_line": (bl_review.shipping_line if bl_review else None) or (getattr(booking, 'shipping_line_name', None) or getattr(booking, 'shipping_line', None) if booking else "MSC / Maersk"),
            "vessel_name": (bl_review.vessel_name if bl_review else None) or (getattr(booking, 'vessel_name', None) if booking else None),
            "voyage_number": (bl_review.voyage_number if bl_review else None) or (getattr(booking, 'voyage_number', None) if booking else None),
            "container_summary": bl_review.container_summary if bl_review else None,
            "gross_weight_kg": bl_review.gross_weight if (bl_review and hasattr(bl_review, 'gross_weight')) else (getattr(booking, 'gross_weight', 0.0) or 0.0),
        },
        discrepancies=bl_discrepancies,
        raw_content=bl_review.raw_input_text if (bl_review and hasattr(bl_review, 'raw_input_text')) else None,
        last_updated=bl_review.updated_at if bl_review else None
    )

    # 4. Certificate of Origin / EUR.1 (Conditional)
    coo_available = coo_review is not None
    coo_discrepancies = []
    if coo_review and coo_review.comparison_matrix:
        for row in coo_review.comparison_matrix:
            if row.get("status") in ["MISMATCH", "MISMATCH_CRITICAL", "MISMATCH_MINOR", "DIFF"]:
                sev = "CRITICAL" if row.get("severity") in ["BLOCKING", "CRITICAL"] or row.get("status") == "MISMATCH_CRITICAL" else "WARNING"
                item = {
                    "document": f"شهادة المنشأ ({coo_review.certificate_type})",
                    "field": row.get("field") or row.get("check_item", "COO Field"),
                    "severity": sev,
                    "issue": f"المطابقة: {row.get('details') or row.get('issue', 'فرق في بيانات المنشأ')}",
                    "rectification": row.get("rectification", "طلب تعديل درافت شهادة المنشأ من المصدر أو الغرفة التجارية"),
                }
                coo_discrepancies.append(item)
                all_discrepancies.append(item)
                if sev == "CRITICAL": total_critical += 1
                else: total_warning += 1

    coo_status = "WAIVED" if coo_is_waived else (
        "APPROVED" if (coo_available and coo_review.status in ["Approved", "APPROVED", "Verified"]) else ("MODIFICATIONS_REQUESTED" if coo_discrepancies else ("REVIEW_PENDING" if coo_available else "NOT_STARTED"))
    )

    certificate_of_origin = CentralArchiveDocumentSummary(
        document_type="CERTIFICATE_OF_ORIGIN",
        title_ar="شهادة المنشأ / يورو 1 (COO / EUR.1)",
        is_available=coo_available,
        is_mandatory=coo_is_mandatory,
        is_waived=coo_is_waived,
        waive_reason="غير مطلوبة قانونياً / معفاة وفق تقييم البند الجمركي (BP-011)" if coo_is_waived else None,
        legal_requirement_note=coo_legal_note,
        status=coo_status,
        document_reference=coo_review.certificate_number if coo_review else None,
        details={
            "certificate_type": (coo_review.certificate_type if coo_review else ("EUR.1" if is_eu_origin else "Standard COO")),
            "certificate_number": coo_review.certificate_number if coo_review else "DRAFT-COO",
            "country_of_origin": origin_country,
            "exporter_name": (coo_review.exporter_name if coo_review else (supplier.company_name if supplier else imp_file.supplier_name)),
            "importer_name": (coo_review.importer_name if coo_review else (company.importer_name if company else imp_file.company_name)),
            "is_preferential_agreement": is_eu_origin,
            "tariff_exemption_eligible": is_eu_origin,
        },
        discrepancies=coo_discrepancies,
        raw_content=coo_review.raw_input_text if coo_review else None,
        last_updated=coo_review.updated_at if coo_review else None
    )

    # 5. Inspection Certificate / VoC (Conditional)
    insp_available = inspection_review is not None
    insp_discrepancies = []
    if inspection_review and inspection_review.comparison_matrix:
        for row in inspection_review.comparison_matrix:
            if row.get("status") in ["MISMATCH", "MISMATCH_CRITICAL", "MISMATCH_MINOR", "DIFF"]:
                sev = "CRITICAL" if row.get("severity") in ["BLOCKING", "CRITICAL"] or row.get("status") == "MISMATCH_CRITICAL" else "WARNING"
                item = {
                    "document": f"شهادة الفحص ({inspection_review.inspection_agency})",
                    "field": row.get("field") or row.get("check_item", "Inspection Field"),
                    "severity": sev,
                    "issue": f"المطابقة: {row.get('details') or row.get('issue', 'فرق في بيانات الفحص')}",
                    "rectification": row.get("rectification", "طلب تعديل درافت الفحص من شركة المعاينة الدولية"),
                }
                insp_discrepancies.append(item)
                all_discrepancies.append(item)
                if sev == "CRITICAL": total_critical += 1
                else: total_warning += 1

    insp_status = "WAIVED" if insp_is_waived else (
        "APPROVED" if (insp_available and inspection_review.status in ["Approved", "APPROVED", "Verified"]) else ("MODIFICATIONS_REQUESTED" if insp_discrepancies else ("REVIEW_PENDING" if insp_available else "NOT_STARTED"))
    )

    inspection_certificate = CentralArchiveDocumentSummary(
        document_type="INSPECTION_CERTIFICATE",
        title_ar="شهادة الفحص والتطابق (VoC / COC)",
        is_available=insp_available,
        is_mandatory=insp_is_mandatory,
        is_waived=insp_is_waived,
        waive_reason="الصنف غير خاضع لرقابة الصادرات والواردات (GOEIC) ولا يتطلب فحص ما قبل الشحن" if insp_is_waived else None,
        legal_requirement_note=insp_legal_note,
        status=insp_status,
        document_reference=inspection_review.certificate_number if inspection_review else None,
        details={
            "inspection_type": (inspection_review.inspection_type if inspection_review else "COC (Certificate of Conformity)"),
            "inspection_agency": (inspection_review.inspection_agency if inspection_review else "COTECNA / TÜV / SGS"),
            "certificate_number": inspection_review.certificate_number if inspection_review else "DRAFT-COC",
            "regulatory_authority": (inspection_review.regulatory_authority if inspection_review else "GOEIC"),
            "standard_specification": (inspection_review.standard_specification if inspection_review else None),
        },
        discrepancies=insp_discrepancies,
        raw_content=inspection_review.raw_input_text if inspection_review else None,
        last_updated=inspection_review.updated_at if inspection_review else None
    )

    # Dynamic Readiness Calculation (Only counts active non-waived mandatory docs)
    all_doc_summaries = [final_invoice, final_packing_list, draft_bl, certificate_of_origin, inspection_certificate]
    mandatory_docs = [d for d in all_doc_summaries if d.is_mandatory and not d.is_waived]
    req_count = len(mandatory_docs)
    approved_count = sum(1 for d in mandatory_docs if d.status == "APPROVED" or (d.is_available and len(d.discrepancies) == 0))

    base_score = (approved_count / req_count * 100.0) if req_count > 0 else 100.0
    deduction = (total_critical * 25.0) + (total_warning * 5.0)
    final_score = max(0.0, min(100.0, base_score - deduction))

    if total_critical == 0 and total_warning == 0 and approved_count == req_count:
        readiness_status = "READY_FOR_RELEASE"
        final_score = 100.0
    elif total_critical > 0 or total_warning > 0:
        readiness_status = "ACTION_REQUIRED"
    else:
        readiness_status = "IN_REVIEW"

    # Compile Import Requirements Summary
    import_requirements_summary = {
        "has_assessment": assessment is not None,
        "assessment_code": assessment.assessment_code if assessment else None,
        "hs_code": (assessment.hs_code if assessment else None) or "9403.10 / 9403.20",
        "commodity_description": (assessment.commodity_description if assessment else None) or "Office furniture & commercial goods",
        "country_of_origin": origin_country,
        "coo_required": coo_is_mandatory and not coo_is_waived,
        "coo_type": (assessment.coo_type if assessment else None) or ("EUR.1" if is_eu_origin else "Standard COO"),
        "coo_status": "Required" if (coo_is_mandatory and not coo_is_waived) else "Waived",
        "inspection_required": insp_is_mandatory and not insp_is_waived,
        "inspection_body": (assessment.inspection_body if assessment else None) or "COTECNA",
        "inspection_status": "Required" if (insp_is_mandatory and not insp_is_waived) else "Waived",
        "decree_43_applicable": assessment.decree_43_applicable if assessment else False,
        "white_list_verified": assessment.white_list_verified if assessment else False,
        "factory_registration_no": assessment.factory_registration_no if assessment else None,
        "import_permit_required": assessment.import_permit_required if assessment else False,
        "permit_issuing_authority": assessment.permit_issuing_authority if assessment else None,
        "overall_status": assessment.overall_status if assessment else "Completed / Inferred",
    }

    # Generate Supplier Email & WhatsApp text
    sys_acid = (acid_session.acid_number if acid_session else None) or imp_file.acid_number or "N/A"
    email_lines = [
        f"Subject: URGENT: Document Revision & Discrepancies Notice for Shipment {imp_file.import_file_code} (ACID: {sys_acid})\n",
        f"Dear {supplier.company_name if supplier else imp_file.supplier_name},\n",
        f"We have reviewed the draft shipping documents for Import File {imp_file.import_file_code} (Customs File: {imp_file.custom_file_number or 'N/A'}).",
        f"Please find below the required corrections and discrepancies that must be rectified before issuing the final original documents and uploading to CargoX:\n"
    ]
    if tariff_exemption_alert:
        email_lines.append(f"[IMPORTANT COMPLIANCE NOTE]: {tariff_exemption_alert}\n")
    if goeic_inspection_alert:
        email_lines.append(f"[INSPECTION NOTE]: {goeic_inspection_alert}\n")

    if all_discrepancies:
        for idx, item in enumerate(all_discrepancies, 1):
            sev_tag = "[CRITICAL / MANDATORY]" if item["severity"] == "CRITICAL" else "[WARNING / RECOMMENDATION]"
            email_lines.append(f"{idx}. {sev_tag} {item['document']}:")
            email_lines.append(f"   - Field / Item: {item['field']}")
            email_lines.append(f"   - Issue: {item['issue']}")
            email_lines.append(f"   - Required Correction: {item['rectification']}\n")
    else:
        email_lines.append("All reviewed documents are fully compliant with Egyptian Customs and Nafeza regulations. You may proceed to issue final originals.\n")

    email_lines.append(f"Consignee: {company.importer_name if company else imp_file.company_name}")
    email_lines.append(f"ACID Number: {sys_acid}")
    email_lines.append("\nBest regards,\nImport Operations Department - Sorour Logistics")
    email_text = "\n".join(email_lines)

    wa_lines = [
        f"*إشعار تعديلات المستندات - ملف الشحنة {imp_file.import_file_code}*",
        f"رقم القيد الجمركي ACID: `{sys_acid}`",
        f"المستورد: {company.importer_name if company else imp_file.company_name}",
        f"المورد: {supplier.company_name if supplier else imp_file.supplier_name}",
        "------------------------------------",
    ]
    if tariff_exemption_alert:
        wa_lines.append(f"🇪🇺 *تنبيه الإعفاء الجمركي:* يلزم تدوين `REVISED RULES` بالخانة 7 بشهادة EUR.1")
    if all_discrepancies:
        wa_lines.append("*التعديلات المطلوبة لإصدار الأصول:*")
        for idx, item in enumerate(all_discrepancies, 1):
            icon = "🔴" if item["severity"] == "CRITICAL" else "🟡"
            wa_lines.append(f"{icon} *{item['document']}* ({item['field']}):")
            wa_lines.append(f"   • المطلوب: {item['rectification']}")
    else:
        wa_lines.append("🟢 *كافة المستندات مطابقة بنسبة 100% وجاهزة لإصدار الأصول والرفع على كارجو إكس.*")
    wa_text = "\n".join(wa_lines)

    return CentralArchiveResponse(
        import_file_id=import_file_id,
        import_file_code=imp_file.import_file_code,
        custom_file_number=imp_file.custom_file_number,
        importer_name=(company.importer_name if company else imp_file.company_name) or "",
        supplier_name=(supplier.company_name if supplier else imp_file.supplier_name) or "",
        acid_number=sys_acid,
        port_of_loading=getattr(imp_file, 'port_of_loading', None) or getattr(imp_file, 'pol_name', None),
        port_of_discharge=getattr(imp_file, 'port_of_discharge', None) or getattr(imp_file, 'pod_name', None),
        total_packages=int(po_reconciliation.total_packages) if po_reconciliation else (booking.packages_count if booking else 0),
        total_gross_weight_kg=float(po_reconciliation.total_gross_weight_kg) if po_reconciliation else (booking.gross_weight if booking else 0.0),
        currency=archive_currency,
        fob_or_cif_amount=float(po_reconciliation.total_invoice_amount) if po_reconciliation else float(getattr(imp_file, 'estimated_cost', 0.0) or 0.0),
        readiness_status=readiness_status,
        readiness_score=round(final_score, 1),
        final_invoice=final_invoice,
        final_packing_list=final_packing_list,
        draft_bl=draft_bl,
        certificate_of_origin=certificate_of_origin,
        inspection_certificate=inspection_certificate,
        import_requirements_summary=import_requirements_summary,
        tariff_exemption_alert=tariff_exemption_alert,
        goeic_inspection_alert=goeic_inspection_alert,
        decree_43_alert=decree_43_alert,
        total_critical_discrepancies=total_critical,
        total_warning_discrepancies=total_warning,
        all_rectifications_checklist=all_discrepancies,
        supplier_email_rectification_text=email_text,
        supplier_whatsapp_rectification_text=wa_text,
    )

