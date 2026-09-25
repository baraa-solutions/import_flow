"""
FastAPI Router for Financial & Management Approval (BP-012 & BP-013)
"""

from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Header, Query
from modules.auth.router import get_current_user, require_admin
from modules.users.model import User
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.permissions import resolve_user
from modules.financial_approval.schemas import (
    PaymentRequestCreate,
    ClonePaymentRequestRequest,
    PaymentRequestUpdate,
    PaymentRequestResponse,
    SwiftReconciliationRequest,
    ImportBudgetCreate,
    CloneImportBudgetRequest,
    ImportBudgetUpdate,
    ImportBudgetResponse,
    BudgetPrefillResponse,
    SmartSwiftExtractRequest,
    SmartSwiftFileExtractRequest,
    SmartSwiftExtractResponse,
    SmartSwiftReconcileRequest,
    SwiftFieldResponse,
    SwiftBatchResponse,
    SwiftFieldUpdateRequest,
    SwiftBatchConfirmRequest,
    SwiftBatchConfirmResponse,
    SwiftBatchMatchResponse,
    SwiftBatchReconcileRequest,
    BudgetVarianceLogResponse,
    BudgetVarianceOverrideRequest,
    BudgetVarianceSettingResponse,
    BudgetVarianceSettingUpdate,
    BudgetSyncResultResponse,
)
import modules.financial_approval.service as service

router = APIRouter(prefix="/api/v1/financial-approval", tags=["Financial Approval"], dependencies=[Depends(get_current_user)])


# --- SMART AI SWIFT MT103 EXTRACTION & RECONCILIATION ENDPOINTS ---
@router.post(
    "/swift/smart-extract",
    response_model=SmartSwiftExtractResponse,
    summary="Smart AI parser for SWIFT MT103 text and automatic matching against payment requests",
)
def smart_extract_swift(
    payload: SmartSwiftExtractRequest, db: Session = Depends(get_db)
):
    return service.smart_extract_swift_service(db, payload)


@router.post(
    "/swift/smart-extract-file",
    response_model=SmartSwiftExtractResponse,
    summary="Smart Extract SWIFT MT103 from Word, Excel, PDF, or Image file",
)
async def smart_extract_swift_from_file(
    file: UploadFile = File(...),
    target_payment_id: Optional[int] = None,
    db: Session = Depends(get_db),
):
    content_bytes = await file.read()
    return service.smart_extract_swift_from_file_service(
        db=db,
        filename=file.filename or "uploaded_swift_document",
        content_bytes=content_bytes,
        target_payment_id=target_payment_id,
    )


@router.post(
    "/swift/smart-extract-base64",
    response_model=SmartSwiftExtractResponse,
    summary="Smart Extract SWIFT MT103 from Base64 encoded file",
)
def smart_extract_swift_from_base64(
    payload: SmartSwiftFileExtractRequest,
    db: Session = Depends(get_db),
):
    import base64
    content_bytes = base64.b64decode(payload.file_base64)
    return service.smart_extract_swift_from_file_service(
        db=db,
        filename=payload.filename,
        content_bytes=content_bytes,
        target_payment_id=payload.target_payment_id,
    )


@router.post(
    "/swift/smart-reconcile",
    response_model=PaymentRequestResponse,
    summary="Automatically reconcile SWIFT details, confirm bank info, and mark payment as Paid",
)
def smart_reconcile_swift(
    payload: SmartSwiftReconcileRequest, db: Session = Depends(get_db)
):
    return service.smart_reconcile_swift_service(db, payload)


# --- SWIFT EXTRACTION REVIEW LAYER ENDPOINTS ---
@router.post(
    "/swift/extract-for-review",
    response_model=SwiftBatchResponse,
    summary="Extracts SWIFT fields and persists a new batch in EXTRACTED_PENDING_REVIEW status",
)
def extract_swift_for_review(
    payload: SmartSwiftExtractRequest, db: Session = Depends(get_db)
):
    return service.extract_swift_for_review_service(
        db=db,
        raw_text=payload.raw_text,
        filename="pasted_swift_text.txt",
        file_type="Text Input",
    )


@router.get(
    "/swift/review-batch/{batch_id}",
    response_model=SwiftBatchResponse,
    summary="Get batch review details, all fields, confidence scores, and mandatory validation status",
)
def get_swift_batch_review(
    batch_id: int, db: Session = Depends(get_db)
):
    return service.get_swift_batch_review_service(db, batch_id)


@router.put(
    "/swift/review-batch/{batch_id}/field/{field_key}",
    response_model=SwiftBatchResponse,
    summary="Update an individual field value in an extracted SWIFT batch and log OCR audit trail",
)
def update_swift_batch_field(
    batch_id: int,
    field_key: str,
    payload: SwiftFieldUpdateRequest,
    db: Session = Depends(get_db),
):
    return service.update_swift_batch_field_service(db, batch_id, field_key, payload)


@router.post(
    "/swift/review-batch/{batch_id}/re-extract-field/{field_key}",
    response_model=SwiftBatchResponse,
    summary="Re-extract a single field from the batch source text using parser regex",
)
def re_extract_swift_batch_field(
    batch_id: int,
    field_key: str,
    db: Session = Depends(get_db),
):
    return service.re_extract_single_field_service(db, batch_id, field_key)


@router.post(
    "/swift/review-batch/{batch_id}/confirm",
    response_model=SwiftBatchConfirmResponse,
    summary="Confirm all extracted & edited SWIFT fields. Transitions batch to REVIEWED_CONFIRMED",
)
def confirm_swift_batch_review(
    batch_id: int,
    payload: SwiftBatchConfirmRequest,
    db: Session = Depends(get_db),
):
    return service.confirm_swift_batch_review_service(db, batch_id, payload)


@router.post(
    "/swift/review-batch/{batch_id}/match",
    response_model=SwiftBatchMatchResponse,
    summary="Match a confirmed SWIFT batch against payment requests strictly using final_value. Requires REVIEWED_CONFIRMED",
)
def match_reviewed_swift_batch(
    batch_id: int,
    target_payment_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
):
    return service.match_reviewed_batch_service(db, batch_id, target_payment_id)


@router.post(
    "/swift/review-batch/{batch_id}/reconcile",
    response_model=PaymentRequestResponse,
    summary="Reconcile a confirmed SWIFT batch against a payment request strictly using final_value. Requires REVIEWED_CONFIRMED",
)
def reconcile_reviewed_swift_batch(
    batch_id: int,
    payload: SwiftBatchReconcileRequest,
    db: Session = Depends(get_db),
):
    return service.reconcile_reviewed_batch_service(db, batch_id, payload)




# --- CROSS-MODULE PREFILL & AGGREGATOR ENDPOINT ---
@router.get(
    "/prefill/{import_file_id}",
    response_model=BudgetPrefillResponse,
    summary="Get cross-module prefilled financial and budget estimates for an import file",
)
def get_budget_prefill(import_file_id: int, db: Session = Depends(get_db)):
    return service.get_budget_prefill_service(db, import_file_id)


# --- PAYMENT REQUEST ENDPOINTS (BP-012) ---
@router.post(
    "/payment-requests",
    response_model=PaymentRequestResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_payment_request(
    payload: PaymentRequestCreate, db: Session = Depends(get_db)
):
    return service.create_payment_request_service(db, payload)


@router.get("/payment-requests", response_model=List[PaymentRequestResponse])
def list_payment_requests(
    include_inactive: bool = False,
    search: Optional[str] = None,
    po_id: Optional[int] = None,
    supplier_id: Optional[int] = None,
    status: Optional[str] = None,
    db: Session = Depends(get_db),
):
    return service.get_all_payment_requests_service(
        db,
        include_inactive=include_inactive,
        search=search,
        po_id=po_id,
        supplier_id=supplier_id,
        status=status,
    )


@router.get(
    "/payment-requests/{payment_id}", response_model=PaymentRequestResponse
)
def get_payment_request(payment_id: int, db: Session = Depends(get_db)):
    item = service.get_payment_request_by_id_service(db, payment_id)
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Payment Request ID {payment_id} not found.",
        )
    return item


@router.put(
    "/payment-requests/{payment_id}", response_model=PaymentRequestResponse
)
def update_payment_request(
    payment_id: int,
    payload: PaymentRequestUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return service.update_payment_request_service(db, payment_id, payload, current_user_name=current_user.username)


@router.post(
    "/payment-requests/{payment_id}/approve",
    response_model=PaymentRequestResponse,
)
def approve_payment_request(payment_id: int, db: Session = Depends(get_db)):
    return service.approve_payment_request_service(db, payment_id)


@router.post(
    "/payment-requests/{payment_id}/pay", response_model=PaymentRequestResponse
)
def execute_payment(
    payment_id: int,
    swift_reference_no: Optional[str] = None,
    db: Session = Depends(get_db),
):
    return service.execute_payment_service(db, payment_id, swift_reference_no)


@router.post(
    "/payment-requests/{payment_id}/reconcile-swift",
    response_model=PaymentRequestResponse,
    summary="Reconcile and confirm bank SWIFT receipt against payment request",
)
def reconcile_swift_payment(
    payment_id: int,
    payload: SwiftReconciliationRequest,
    db: Session = Depends(get_db),
):
    return service.reconcile_swift_service(db, payment_id, payload)


@router.post(
    "/payment-requests/{payment_id}/clone",
    response_model=PaymentRequestResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Clone a payment request into a new Draft record with mandatory reset invariants",
)
def clone_payment_request(
    payment_id: int,
    payload: ClonePaymentRequestRequest,
    db: Session = Depends(get_db),
):
    return service.clone_payment_request_service(db, payment_id, payload)


@router.delete("/payment-requests/{payment_id}", status_code=status.HTTP_204_NO_CONTENT)
def soft_delete_payment_request(payment_id: int, db: Session = Depends(get_db)):
    success = service.soft_delete_payment_request_service(db, payment_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Payment Request ID {payment_id} not found.",
        )


@router.post("/payment-requests/{payment_id}/restore")
def restore_payment_request(payment_id: int, db: Session = Depends(get_db)):
    success = service.restore_payment_request_service(db, payment_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Payment Request ID {payment_id} not found or active.",
        )
    return {"message": "Payment Request restored successfully"}


# --- IMPORT BUDGET ENDPOINTS (BP-013) ---
@router.post(
    "/import-budgets",
    response_model=ImportBudgetResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_import_budget(payload: ImportBudgetCreate, db: Session = Depends(get_db)):
    return service.create_import_budget_service(db, payload)


@router.get("/import-budgets", response_model=List[ImportBudgetResponse])
def list_import_budgets(
    include_inactive: bool = False,
    search: Optional[str] = None,
    import_file_id: Optional[int] = None,
    po_id: Optional[int] = None,
    budget_status: Optional[str] = None,
    db: Session = Depends(get_db),
):
    return service.get_all_import_budgets_service(
        db,
        include_inactive=include_inactive,
        search=search,
        import_file_id=import_file_id,
        po_id=po_id,
        budget_status=budget_status,
    )


@router.post(
    "/import-budgets/{budget_id}/approve", response_model=ImportBudgetResponse
)
def approve_import_budget(
    budget_id: int,
    approved_by: str = "Finance Manager",
    db: Session = Depends(get_db),
):
    return service.approve_import_budget_service(db, budget_id, approved_by)


@router.post(
    "/import-budgets/{budget_id}/clone",
    response_model=ImportBudgetResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Clone an import budget into a new record with mandatory reset invariants",
)
def clone_import_budget(
    budget_id: int,
    payload: CloneImportBudgetRequest,
    db: Session = Depends(get_db),
):
    return service.clone_import_budget_service(db, budget_id, payload)


@router.post(
    "/import-budgets/{budget_id}/sync",
    response_model=BudgetSyncResultResponse,
    summary="Synchronize import budget with live upstream costs following enterprise SoD, status machine, and revision rules",
)
def sync_import_budget(
    budget_id: int,
    justification_note: Optional[str] = Query(None, description="Optional written justification note for overriding hard block"),
    authorization: Optional[str] = Header(None),
    x_user_role: Optional[str] = Header(None),
    x_user_name: Optional[str] = Header(None),
    db: Session = Depends(get_db),
):
    current_user = resolve_user(db, authorization=authorization, x_user_role=x_user_role, x_user_name=x_user_name)
    return service.sync_budget_with_upstream_service(
        db, budget_id, current_user=current_user, override_justification=justification_note
    )


@router.post(
    "/import-budgets/{budget_id}/override-variance",
    response_model=ImportBudgetResponse,
    summary="Override Hard Block variance by providing an authorized written justification",
)
def override_budget_variance(
    budget_id: int,
    payload: BudgetVarianceOverrideRequest,
    authorization: Optional[str] = Header(None),
    x_user_role: Optional[str] = Header(None),
    x_user_name: Optional[str] = Header(None),
    db: Session = Depends(get_db),
):
    current_user = resolve_user(db, authorization=authorization, x_user_role=x_user_role, x_user_name=x_user_name)
    return service.override_budget_variance_service(
        db, budget_id, current_user=current_user, justification_note=payload.justification_note
    )


@router.get(
    "/import-budgets/{budget_id}/variance-logs",
    response_model=List[BudgetVarianceLogResponse],
    summary="List all recorded variance audit logs for a budget",
)
def get_budget_variance_logs(budget_id: int, db: Session = Depends(get_db)):
    return service.get_budget_variance_logs_service(db, budget_id)


@router.get(
    "/settings/variance-threshold",
    response_model=BudgetVarianceSettingResponse,
    summary="Get current variance threshold percentage configuration",
)
def get_variance_threshold_setting(db: Session = Depends(get_db)):
    val = service.get_variance_threshold_service(db)
    from modules.financial_approval.model import BudgetVarianceSetting
    setting = db.query(BudgetVarianceSetting).filter(
        BudgetVarianceSetting.setting_key == "variance_threshold_percentage"
    ).first()
    return setting


@router.put(
    "/settings/variance-threshold",
    response_model=BudgetVarianceSettingResponse,
    summary="Update variance threshold percentage configuration",
    dependencies=[Depends(require_admin)],
)
def update_variance_threshold_setting(
    payload: BudgetVarianceSettingUpdate,
    authorization: Optional[str] = Header(None),
    x_user_role: Optional[str] = Header(None),
    x_user_name: Optional[str] = Header(None),
    db: Session = Depends(get_db),
):
    current_user = resolve_user(db, authorization=authorization, x_user_role=x_user_role, x_user_name=x_user_name)
    return service.update_variance_threshold_service(
        db, payload.threshold_percentage, updated_by=current_user.username if current_user else "Admin"
    )



@router.get(
    "/import-budgets/{budget_id}", response_model=ImportBudgetResponse
)
def get_import_budget(budget_id: int, db: Session = Depends(get_db)):
    item = service.get_import_budget_by_id_service(db, budget_id)
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Import Budget ID {budget_id} not found.",
        )
    return item


@router.put(
    "/import-budgets/{budget_id}", response_model=ImportBudgetResponse
)
def update_import_budget(
    budget_id: int,
    payload: ImportBudgetUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return service.update_import_budget_service(db, budget_id, payload, current_user_name=current_user.username)


@router.delete("/import-budgets/{budget_id}", status_code=status.HTTP_204_NO_CONTENT)
def soft_delete_import_budget(budget_id: int, db: Session = Depends(get_db)):
    success = service.soft_delete_import_budget_service(db, budget_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Import Budget ID {budget_id} not found.",
        )


@router.post("/import-budgets/{budget_id}/restore")
def restore_import_budget(budget_id: int, db: Session = Depends(get_db)):
    success = service.restore_import_budget_service(db, budget_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Import Budget ID {budget_id} not found or active.",
        )
    return {"message": "Import Budget restored successfully"}
