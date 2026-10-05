from typing import List, Optional

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.permissions import has_user_permission, require_permission
from modules.users.model import User
from .schemas import (
    CustomsClearanceCreate,
    CustomsClearanceUpdate,
    CustomsClearanceResponse,
    CustomsBrokerAuthorizationSubmit,
    DeliveryOrderPaymentSubmit,
    CustomsDeclaration46Submit,
    CustomsInspectionSamplingSubmit,
    FinalDutyAssessmentSubmit,
    CustomsDutyPaymentSubmit,
    DutyPaymentSubmit,
    CompleteReleaseSubmit,
    CustomsFinalReleaseSubmit,
    UnderBondReleaseSubmit,
    LabTestResultSubmit,
    ClearanceExpenseInvoiceCreate,
    ClearanceExpenseInvoiceResponse,
    ClearanceInvoicesSummaryResponse,
)
from .service import (
    create_customs_clearance_service,
    authorize_customs_broker_service,
    record_delivery_order_payment_service,
    register_customs_declaration_46_service,
    record_customs_inspection_sampling_service,
    assess_final_customs_duties_service,
    record_customs_duty_payment_service,
    issue_final_customs_release_service,
    get_customs_clearance_service,
    list_customs_clearances_service,
    submit_duty_payment_service,
    complete_customs_release_service,
    issue_under_bond_release_service,
    record_lab_result_and_lift_quarantine_service,
    update_customs_clearance_service,
    soft_delete_customs_clearance_service,
    restore_customs_clearance_service,
    record_clearance_invoice_service,
    get_clearance_invoices_by_file_service,
    delete_clearance_invoice_service,
)

router = APIRouter(prefix="/api/v1/customs-clearance", tags=["Phase 7 - Customs Clearance"])

# Permission codes (modules/auth/seed_rbac.py): reads, workflow writes, and the final release.
can_view = require_permission("customs_clearance.view")
can_update = require_permission("customs_clearance.update")
can_release = require_permission("customs_clearance.release")


@router.get("", response_model=List[CustomsClearanceResponse])
def list_customs_clearances(
    include_inactive: bool = Query(False, description="Include soft-deleted records"),
    import_file_id: Optional[int] = Query(None, description="Filter by import file ID"),
    status_filter: Optional[str] = Query(None, alias="status", description="Filter by operational status"),
    search: Optional[str] = Query(None, description="Search term"),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    return list_customs_clearances_service(db, include_inactive, import_file_id, status_filter, search)


@router.post("", response_model=CustomsClearanceResponse, status_code=status.HTTP_201_CREATED)
def create_customs_clearance(
    schema: CustomsClearanceCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_update),
):
    return create_customs_clearance_service(db, schema, user=current_user.username)


@router.post("/authorize-broker", response_model=CustomsClearanceResponse, summary="تعيين المخلص الجمركي والتفويض الإلكتروني (CS-01)")
def authorize_customs_broker(
    payload: CustomsBrokerAuthorizationSubmit,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_update),
):
    return authorize_customs_broker_service(db, payload, user=current_user.username)


@router.post("/delivery-order-payment", response_model=CustomsClearanceResponse, summary="سداد إذن التسليم الملاحي واستلام D/O (CS-02)")
def record_delivery_order_payment(
    payload: DeliveryOrderPaymentSubmit,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_update),
):
    return record_delivery_order_payment_service(db, payload, user=current_user.username)


@router.post("/register-declaration-46", response_model=CustomsClearanceResponse, summary="قيد الإقرار الجمركي ونموذج 46 ك.م (CS-03)")
def register_customs_declaration_46(
    payload: CustomsDeclaration46Submit,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_update),
):
    return register_customs_declaration_46_service(db, payload, user=current_user.username)


@router.post("/record-inspection-sampling", response_model=CustomsClearanceResponse, summary="تسجيل الكشف والمعاينة وسحب العينات ومطابقة الرقابة (CL-01)")
def record_customs_inspection_sampling(
    payload: CustomsInspectionSamplingSubmit,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_update),
):
    return record_customs_inspection_sampling_service(db, payload, user=current_user.username)


@router.post("/assess-final-duties", response_model=CustomsClearanceResponse, summary="احتساب الرسوم والضرائب الجمركية النهائية (CL-02)")
def assess_final_customs_duties(
    payload: FinalDutyAssessmentSubmit,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_update),
):
    return assess_final_customs_duties_service(db, payload, user=current_user.username)


@router.post("/record-duty-payment", response_model=CustomsClearanceResponse, summary="تسجيل سداد الرسوم الجمركية بسداد / E-Finance (CL-03)")
def record_customs_duty_payment(
    payload: CustomsDutyPaymentSubmit,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_update),
):
    return record_customs_duty_payment_service(db, payload, user=current_user.username)


@router.post("/issue-final-release", response_model=CustomsClearanceResponse, summary="صدور أمر الإفراج الجمركي الأخضر وبدء إجراءات النقل (CL-04)")
def issue_final_customs_release(
    payload: CustomsFinalReleaseSubmit,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_release),
):
    return issue_final_customs_release_service(db, payload, user=current_user.username)


# ==============================================================================
# CL-05: Clearance Fees & Port Invoices Endpoints (declared before /{record_id})
# ==============================================================================

@router.post("/invoices", response_model=ClearanceExpenseInvoiceResponse, status_code=status.HTTP_201_CREATED, summary="تسجيل فاتورة أتعاب تخليص أو رسوم موانئ أو عتالة (CL-05)")
def record_clearance_invoice(
    payload: ClearanceExpenseInvoiceCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_update),
):
    return record_clearance_invoice_service(db, payload, current_user=current_user.username)


@router.get("/invoices/by-file/{import_file_id}", response_model=ClearanceInvoicesSummaryResponse, summary="استرجاع وتلخيص فواتير ومصاريف التخليص لملف الشحنة (CL-05)")
def get_clearance_invoices_by_file(
    import_file_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    return get_clearance_invoices_by_file_service(db, import_file_id)


@router.delete("/invoices/{invoice_id}", status_code=status.HTTP_200_OK, summary="حذف فاتورة تخليص وإعادة احتساب الإجماليات وتكلفة الوصول")
def delete_clearance_invoice(
    invoice_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_update),
):
    delete_clearance_invoice_service(db, invoice_id, current_user=current_user.username)
    return {"status": "success", "message": "تم حذف فاتورة التخليص وإعادة احتساب الإجماليات بنجاح"}


@router.get("/{record_id}", response_model=CustomsClearanceResponse)
def get_customs_clearance(
    record_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    return get_customs_clearance_service(db, record_id)


@router.put("/{record_id}", response_model=CustomsClearanceResponse)
def update_customs_clearance(
    record_id: int,
    schema: CustomsClearanceUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_update),
):
    return update_customs_clearance_service(db, record_id, schema, user=current_user.username)


@router.post("/{record_id}/pay-duty", response_model=CustomsClearanceResponse)
def submit_duty_payment(
    record_id: int,
    payload: DutyPaymentSubmit,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_update),
):
    return submit_duty_payment_service(db, record_id, payload, user=current_user.username)


@router.post("/{record_id}/complete-release", response_model=CustomsClearanceResponse)
def complete_customs_release(
    record_id: int,
    payload: CompleteReleaseSubmit,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_release),
):
    return complete_customs_release_service(db, record_id, payload, user=current_user.username)


@router.post("/{record_id}/under-bond-release", response_model=CustomsClearanceResponse, summary="إصدار إفراج مشروط تحت التحفظ الجمركي والسحب على عهدة")
def issue_under_bond_release(
    record_id: int,
    payload: UnderBondReleaseSubmit,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_update),
):
    return issue_under_bond_release_service(db, record_id, payload, user=current_user.username)


@router.post("/{record_id}/lab-test-result", response_model=CustomsClearanceResponse, summary="تسجيل نتيجة الفحص المعملي وفك التحفظ الجمركي")
def record_lab_test_result(
    record_id: int,
    payload: LabTestResultSubmit,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_update),
):
    return record_lab_result_and_lift_quarantine_service(
        db, record_id, payload, user=current_user.username,
        can_release=has_user_permission(db, current_user, "customs_clearance.release"),
    )


@router.delete("/{record_id}", status_code=status.HTTP_204_NO_CONTENT)
def soft_delete_customs_clearance(
    record_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_update),
):
    soft_delete_customs_clearance_service(db, record_id, user=current_user.username)
    return None


@router.patch("/{record_id}/restore", response_model=CustomsClearanceResponse)
def restore_customs_clearance(
    record_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_update),
):
    return restore_customs_clearance_service(db, record_id, user=current_user.username)
