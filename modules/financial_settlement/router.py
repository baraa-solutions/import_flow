from typing import List, Optional
from fastapi import APIRouter, Depends, Query, Response, status
from modules.auth.router import get_current_user
from modules.auth.permissions import require_permission
from modules.users.model import User
from sqlalchemy.orm import Session

from database.database import get_db
from .schemas import (
    FinancialSettlementCreate,
    FinancialSettlementUpdate,
    FinancialSettlementResponse,
    OdooJournalEntryResponse,
    OdooExportConfig,
    EstimatedLandedCostSimulationRequest,
    EstimatedLandedCostSimulationResponse,
    InvoicesAggregationResponse,
    ConfirmInvoicesSettlementRequest,
    ConfirmInvoicesSettlementResponse,
    ActualLandedCostCalculationRequest,
    ActualLandedCostCalculationResponse,
    ApproveActualLandedCostRequest,
    ApproveActualLandedCostResponse,
    FobValuationResponse,
)
from .fob_valuation_service import get_fob_valuation_service, revalue_fob_valuation_service
from .service import (
    create_settlement_service,
    recalculate_settlement_service,
    update_settlement_service,
    get_settlement_service,
    list_settlements_service,
    soft_delete_settlement_service,
    restore_settlement_service,
    simulate_estimated_landed_cost_service,
    aggregate_shipment_invoices_service,
    confirm_invoices_settlement_service,
    calculate_actual_landed_cost_service,
    approve_actual_landed_cost_service,
)
from .odoo_export_service import (
    generate_odoo_journal_entry_service,
    export_odoo_csv_service,
    export_odoo_excel_service,
    odoo_export_filename,
)

# Reads, exports and calculations without persistence: financial_settlement.view.
# Writes, confirm and approve: financial_settlement.calculate (Q3).
# The acting user (current_user.username) is recorded; actor names sent in the body are ignored (FS-04).
VIEW = require_permission("financial_settlement.view")
CALCULATE = require_permission("financial_settlement.calculate")

router = APIRouter(prefix="/api/v1/financial-settlement", tags=["Phase 9 - Financial Settlement & Landed Cost"], dependencies=[Depends(get_current_user)])

@router.get("", response_model=List[FinancialSettlementResponse])
def list_settlements(
    include_inactive: bool = Query(False, description="Include soft-deleted records"),
    import_file_id: Optional[int] = Query(None, description="Filter by import file ID"),
    status_filter: Optional[str] = Query(None, alias="status", description="Filter by operational status"),
    search: Optional[str] = Query(None, description="Search term"),
    skip: int = Query(0, ge=0, description="Records to skip"),
    limit: Optional[int] = Query(None, ge=1, le=500, description="Max records to return"),
    db: Session = Depends(get_db),
    current_user: User = Depends(VIEW),
):
    return list_settlements_service(
        db,
        include_inactive=include_inactive,
        import_file_id=import_file_id,
        status=status_filter,
        search=search,
        skip=skip,
        limit=limit,
    )

@router.post("", response_model=FinancialSettlementResponse, status_code=status.HTTP_201_CREATED)
def create_settlement(
    schema: FinancialSettlementCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(CALCULATE),
):
    return create_settlement_service(db, schema, actor=current_user.username)

@router.get("/{settlement_id}", response_model=FinancialSettlementResponse)
def get_settlement(
    settlement_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(VIEW),
):
    return get_settlement_service(db, settlement_id)

@router.put("/{settlement_id}", response_model=FinancialSettlementResponse)
def update_settlement(
    settlement_id: int,
    schema: FinancialSettlementUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(CALCULATE),
):
    return update_settlement_service(db, settlement_id, schema, actor=current_user.username)

@router.post("/{settlement_id}/recalculate", response_model=FinancialSettlementResponse)
def recalculate_settlement(
    settlement_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(CALCULATE),
):
    return recalculate_settlement_service(db, settlement_id, actor=current_user.username)

@router.delete("/{settlement_id}", status_code=status.HTTP_204_NO_CONTENT)
def soft_delete_settlement(
    settlement_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(CALCULATE),
):
    soft_delete_settlement_service(db, settlement_id, actor=current_user.username)
    return None

@router.patch("/{settlement_id}/restore", response_model=FinancialSettlementResponse)
def restore_settlement(
    settlement_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(CALCULATE),
):
    return restore_settlement_service(db, settlement_id, actor=current_user.username)

@router.get("/{settlement_id}/odoo-journal-entry", response_model=OdooJournalEntryResponse)
def get_odoo_journal_entry(
    settlement_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(VIEW),
):
    """
    Returns balanced double-entry accounting journal for Odoo and ERP General Ledger.
    """
    return generate_odoo_journal_entry_service(db, settlement_id)

@router.get("/{settlement_id}/export-odoo-csv")
def export_odoo_csv(
    settlement_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(VIEW),
):
    """
    Exports Odoo-compatible CSV file for account.move / account.move.line batch import (409 when unbalanced).
    """
    csv_data = export_odoo_csv_service(db, settlement_id)
    filename = odoo_export_filename(db, settlement_id, "csv")
    return Response(
        content=csv_data,
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )

@router.get("/{settlement_id}/export-odoo-excel")
def export_odoo_excel(
    settlement_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(VIEW),
):
    """
    Exports full professional Excel file containing Odoo import sheet, Accounting Voucher, and Item Landed Cost
    breakdown (409 when the journal is unbalanced).
    """
    excel_bytes = export_odoo_excel_service(db, settlement_id)
    filename = odoo_export_filename(db, settlement_id, "xlsx")
    return Response(
        content=excel_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )


@router.post("/simulate-file/{import_file_id}", response_model=EstimatedLandedCostSimulationResponse)
def simulate_estimated_landed_cost(
    import_file_id: int,
    payload: Optional[EstimatedLandedCostSimulationRequest] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(VIEW),
):
    """
    محاكاة واحتساب تكلفة الوصول التقديرية للشحنة وللوحدة الواحدة (PL-08: Estimated Landed Cost Simulation).
    """
    return simulate_estimated_landed_cost_service(db, import_file_id, payload)


@router.get("/invoices-aggregation/{import_file_id}", response_model=InvoicesAggregationResponse)
def get_invoices_aggregation(
    import_file_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(VIEW),
):
    """
    CLO-01: تجميع فواتير ومصروفات الشحنة من كافة الموديولات (المورد، الشحن، الجمارك، التأمين، المخلص، النقل، غرامات التأخير).
    """
    return aggregate_shipment_invoices_service(db, import_file_id)


@router.post("/confirm-invoices-settlement", response_model=ConfirmInvoicesSettlementResponse)
def confirm_invoices_settlement(
    payload: ConfirmInvoicesSettlementRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(CALCULATE),
):
    """
    CLO-01: اعتماد تسوية الفواتير الختامية للملف وإغلاق TSK-0901 وتصعيد المهمة الذكية التالية CLO-02.
    """
    return confirm_invoices_settlement_service(db, payload, actor=current_user.username)


@router.post("/calculate-actual-landed-cost/{import_file_id}", response_model=ActualLandedCostCalculationResponse)
def calculate_actual_landed_cost(
    import_file_id: int,
    payload: Optional[ActualLandedCostCalculationRequest] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(VIEW),
):
    """
    CLO-02: احتساب تكلفة الوصول الفعلية وتوزيع المصاريف على الأصناف ومقارنة الفعلي بالتقديري والانحراف.
    """
    return calculate_actual_landed_cost_service(db, import_file_id, payload)


@router.post("/approve-actual-landed-cost", response_model=ApproveActualLandedCostResponse)
def approve_actual_landed_cost(
    payload: ApproveActualLandedCostRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(CALCULATE),
):
    """
    CLO-02: اعتماد تكلفة الوصول الفعلية للشحنة وتحديث حالة الملف وإغلاق TSK-0902 وإطلاق مهمة الملف الشامل TSK-0903.
    """
    return approve_actual_landed_cost_service(db, payload, actor=current_user.username)


@router.get("/fob-valuation/{import_file_id}", response_model=FobValuationResponse)
def get_fob_valuation(
    import_file_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(VIEW),
):
    """
    تقييم الفوب الصافي الموحد للملف (قيمة البضاعة بعد استبعاد هامش التمويل والخصم، سعر الصرف المثبت حسب مسار الدفع،
    الوعاء الجمركي بسعر تاريخ الإقرار، وإعادة تقييم الحساب المفتوح). قراءة فقط.
    """
    return get_fob_valuation_service(db, import_file_id)


@router.post("/fob-valuation/{import_file_id}/revalue", response_model=FobValuationResponse)
def revalue_fob_valuation(
    import_file_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(CALCULATE),
):
    """
    إعادة تقييم الفوب الصافي وحفظ اللقطة على ملف الشحنة (تحديث سعر التثبيت وفروق إعادة تقييم الحساب المفتوح).
    """
    return revalue_fob_valuation_service(db, import_file_id, actor=current_user.username)
