from typing import List, Optional
from sqlalchemy.orm import Session
from fastapi import HTTPException

from modules.suppliers.model import Supplier
from modules.customs_tariff import repository as tariff_repo
from .integration_mode import IntegrationProvider, select_integration_mode
from .schemas import (
    GOEICComplianceCheckRequest,
    GOEICComplianceCheckResponse,
    AccreditedInspectionBody,
)


ACCREDITED_INSPECTION_BODIES = [
    AccreditedInspectionBody(
        body_id="SGS-INTL",
        name_en="SGS (Société Générale de Surveillance)",
        name_ar="شركة إس جي إس العالمية للتفتيش والمطابقة",
        country_headquarters="Switzerland",
        accreditation_scope="فحص عام: هندسي، منسوجات، كهربائي، غذائي، كيميائي",
        is_active=True,
    ),
    AccreditedInspectionBody(
        body_id="BV-FR",
        name_en="Bureau Veritas",
        name_ar="بيرو فيريتاس الدولية للفحص والاعتماد",
        country_headquarters="France",
        accreditation_scope="فحص السلع الاستهلاكية، قطع الغيار، الأجهزة المنزلية",
        is_active=True,
    ),
    AccreditedInspectionBody(
        body_id="TUV-DE",
        name_en="TÜV Rheinland",
        name_ar="توف راينلاند الألمانية للاختبارات والمطابقة",
        country_headquarters="Germany",
        accreditation_scope="فحص المعدات الصناعية، الآلات، معايير السلامة والجودة",
        is_active=True,
    ),
    AccreditedInspectionBody(
        body_id="COTECNA-CH",
        name_en="Cotecna Inspection",
        name_ar="كوتكنا السويسرية للتفتيش وإصدار شهادات المطابقة",
        country_headquarters="Switzerland",
        accreditation_scope="فحص ما قبل الشحن، شهادات المنشأ والمطابقة الجمركية",
        is_active=True,
    ),
    AccreditedInspectionBody(
        body_id="INTERTEK-UK",
        name_en="Intertek Group",
        name_ar="إنترتك لخدمات الفحص والاختبارات وضمان الجودة",
        country_headquarters="United Kingdom",
        accreditation_scope="فحص الإلكترونيات، المنسوجات، الأجهزة الطبية ومستحضرات التجميل",
        is_active=True,
    ),
    AccreditedInspectionBody(
        body_id="CCIC-CN",
        name_en="China Certification & Inspection Group (CCIC)",
        name_ar="المجموعة الصينية للشهادات والتفتيش",
        country_headquarters="China",
        accreditation_scope="فحص الشحنات الصادرة من الموانئ الصينية، الفحص المسبق للمصانع",
        is_active=True,
    ),
]


class GOEICIntegrationClient:
    """
    INT-GOEIC-009: General Organization for Export and Import Control (GOEIC) Hub.
    Handles Ministerial Decree 43/2016 Factory White-List Verification and
    Pre-shipment Inspection Certificate (COI) compliance.
    """

    def __init__(self, mode: Optional[str] = None):
        # Compliance checks run on local master data only (no remote call), so no mock guard applies.
        self.mode = select_integration_mode(IntegrationProvider.GOEIC, mode).value

    def get_accredited_inspection_bodies(self) -> List[AccreditedInspectionBody]:
        """Returns the list of accredited international inspection companies recognized by GOEIC."""
        return ACCREDITED_INSPECTION_BODIES

    def check_compliance(self, db: Session, request: GOEICComplianceCheckRequest) -> GOEICComplianceCheckResponse:
        """
        Validates whether the shipment and supplier meet Egyptian GOEIC compliance standards:
        1. Checks Decree 43 / 2016 applicability based on HS code.
        2. Checks supplier factory white-list registration.
        3. Validates pre-shipment inspection requirement & COI validity.
        """
        supplier = db.query(Supplier).filter(
            Supplier.supplier_id == request.supplier_id,
            Supplier.is_active == True,
        ).first()

        if not supplier:
            raise HTTPException(status_code=404, detail=f"المورد الأجنبي رقم #{request.supplier_id} غير موجود بالنظام.")

        clean_hs = request.hs_code.replace(".", "").strip()
        tariff = tariff_repo.get_tariff_by_hs_code(db, clean_hs)

        # Determine if Decree 43 is mandated
        is_decree_43 = False
        requires_preshipment_inspection = False

        if tariff:
            note = (tariff.prior_approval_note or "")
            reg_auth = (tariff.regulatory_authority or "")

            if "4518" in note or "43" in note or "تسجيل" in note:
                is_decree_43 = True

            if bool(tariff.requires_inspection) or "GOEIC" in reg_auth or "الرقابة" in reg_auth or is_decree_43:
                requires_preshipment_inspection = True

        # Fallback check for well-known Decree 43 chapters:
        # Chapter 61-64 (Apparel/Footwear), 8414-8418 (AC/Fridges), 8509-8516 (Appliances), 6907-6908 (Ceramics)
        decree_43_prefixes = ["8415", "8418", "8509", "8516", "61", "62", "64", "6907", "6908"]
        if any(clean_hs.startswith(p) for p in decree_43_prefixes):
            is_decree_43 = True
            requires_preshipment_inspection = True

        # Check supplier registration status
        is_registered = bool(
            supplier.registered_decree_43 or
            supplier.white_list_registered or
            getattr(supplier, "foreign_exporter_id", None) and getattr(supplier, "foreign_exporter_id", "").startswith("GOEIC-")
        )

        reg_no = supplier.foreign_exporter_id if is_registered else None
        decree_status = "Registered" if is_registered else "Not Registered"

        # Check pre-shipment COI
        coi_valid = False
        if request.has_coi_certificate and request.coi_number:
            coi_agency = (request.coi_agency or "").upper()
            recognized_agencies = ["SGS", "BUREAU VERITAS", "BV", "TUV", "COTECNA", "INTERTEK", "CCIC"]
            if any(ag in coi_agency for ag in recognized_agencies):
                coi_valid = True

        # Determine Verdict
        if is_decree_43 and not is_registered:
            verdict = "BLOCKED_DECREE_43_VIOLATION"
            warning = (
                f"تحذير رقابي حاسم: البند الجمركي #{clean_hs} خاضع للقرار الوزاري 43 لسنة 2016، "
                f"والمصنع [{supplier.company_name}] غير مقيد في القائمة البيضاء المعتمدة بهيئة الرقابة على الصادرات والواردات. "
                f"يمنع إصدار أمر الشراء أو تحويل الدفعة أو الشحن لتفادي الرفض الجمركي وإلزامية إعادة التصدير."
            )
            action = "مطالبة المورد بتقديم شهادة القيد بالهيئة وسجل المصنع المعتمد، أو الاستيراد من مصنع مسجل بالقائمة البيضاء."
        elif requires_preshipment_inspection and not coi_valid:
            verdict = "PENDING_COI_CERTIFICATE"
            warning = (
                f"البند الجمركي #{clean_hs} يستلزم إصدار شهادة فحص ما قبل الشحن (COI) معتمدة من إحدى شركات التفتيش الدولية "
                f"المسجلة بالهيئة قبل إبحار السفينة."
            )
            action = "تكليف شركة فحص معتمدة (مثل SGS أو Bureau Veritas أو TUV) بسحب عينات الشحنة وإصدار شهادة الفحص."
        else:
            verdict = "CLEARED_FOR_IMPORT"
            warning = None
            action = "الشحنة والمصنع مستوفيان لكافة متطلبات هيئة الرقابة على الصادرات والواردات وجاهزة للإبحار والاعتماد."

        return GOEICComplianceCheckResponse(
            supplier_id=supplier.supplier_id,
            supplier_name=supplier.company_name,
            hs_code=clean_hs,
            is_decree_43_mandated=is_decree_43,
            is_factory_registered=is_registered,
            factory_registration_number=reg_no,
            decree_43_status=decree_status,
            requires_preshipment_inspection=requires_preshipment_inspection,
            coi_valid=coi_valid,
            overall_compliance_verdict=verdict,
            warning_message_ar=warning,
            recommended_action_ar=action,
        )
