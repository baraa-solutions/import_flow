"""
Import File Cost, Landed Cost & Financial Aggregation Service (ملفات الاستيراد - خدمات التكاليف والمصروفات).

Handles:
- Master report generation with multi-currency estimated cost aggregation
- Landed cost summaries, customs duty references, and logistics itemization
- File export rows construction (Excel, CSV, PDF) with language separation
"""

from typing import Any, Dict, List, Optional
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.import_files.schemas import (
    ImportFileResponse,
    ImportMasterReportSummary,
)
from modules.import_files.model import ImportFile
import modules.import_files.repository as repo


STATUS_TRANSLATIONS = {
    "Open": {"ar": "مفتوح", "en": "Open"},
    "In Progress": {"ar": "قيد التنفيذ", "en": "In Progress"},
    "Closed": {"ar": "مغلق", "en": "Closed"},
    "Archived": {"ar": "مؤرشف", "en": "Archived"},
    "On Hold": {"ar": "معلق", "en": "On Hold"},
}

STAGE_TRANSLATIONS = {
    "Bank Form 4": {"ar": "نموذج 4 البنكي", "en": "Bank Form 4"},
    "Cargo Tracking": {"ar": "تتبع الشحنة", "en": "Cargo Tracking"},
    "Customs Clearance": {"ar": "التخليص الجمركي", "en": "Customs Clearance"},
    "Warehouse Receiving": {"ar": "الاستلام المخزني", "en": "Warehouse Receiving"},
    "File Closure": {"ar": "إغلاق الملف", "en": "File Closure"},
    "Draft Documents": {"ar": "مراجعة المسودات", "en": "Draft Documents"},
    "Freight RFQ": {"ar": "عروض أسعار الشحن", "en": "Freight RFQ"},
}


def generate_master_report_service(
    db: Session,
    company_id: Optional[int] = None,
    supplier_id: Optional[int] = None,
    status: Optional[str] = None,
    owner: Optional[str] = None,
    search: Optional[str] = None,
) -> ImportMasterReportSummary:
    """Generates master report summary across all import files with currency-specific aggregations."""
    files = repo.get_all_import_files(
        db,
        include_inactive=False,
        search=search,
        company_id=company_id,
        supplier_id=supplier_id,
        status=status,
        owner=owner,
    )

    open_files = [f for f in files if f.status == "Open"]
    in_prog = [f for f in files if f.status == "In Progress"]
    closed_files = [f for f in files if f.status in ("Closed", "Archived")]
    estimated_cost_by_currency: Dict[str, float] = {}
    for f in files:
        cost = float(f.estimated_cost or 0.0)
        curr = (f.estimated_cost_currency or "").strip().upper()
        if not curr:
            curr = "UNKNOWN"
        estimated_cost_by_currency[curr] = round(
            estimated_cost_by_currency.get(curr, 0.0) + cost, 2
        )

    if len(estimated_cost_by_currency) == 1:
        total_estimated_cost = round(next(iter(estimated_cost_by_currency.values())), 2)
    elif len(estimated_cost_by_currency) == 0:
        total_estimated_cost = 0.0
    else:
        total_estimated_cost = None

    file_responses = [ImportFileResponse.model_validate(f) for f in files]

    return ImportMasterReportSummary(
        total_import_files=len(files),
        open_files_count=len(open_files),
        in_progress_count=len(in_prog),
        closed_files_count=len(closed_files),
        total_estimated_cost=total_estimated_cost,
        estimated_cost_by_currency=estimated_cost_by_currency,
        files=file_responses,
    )


def get_landed_cost_summary_service(
    db: Session,
    import_file_id: int,
) -> Dict[str, Any]:
    """
    Cost itemization, landed cost summaries, customs duty references, and financial aggregation
    for an individual import file.
    """
    import_file = repo.get_import_file_by_id(db, import_file_id)
    if not import_file:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ملف الاستيراد '{import_file_id}' غير موجود.",
        )

    invoices = import_file.invoices_data or []
    invoice_totals_by_currency: Dict[str, float] = {}
    for inv in invoices:
        amt = float(inv.get("amount") or 0.0)
        curr = (inv.get("currency") or "USD").strip().upper()
        invoice_totals_by_currency[curr] = round(
            invoice_totals_by_currency.get(curr, 0.0) + amt, 2
        )

    return {
        "import_file_id": import_file.import_file_id,
        "import_file_code": import_file.import_file_code,
        "custom_file_number": import_file.custom_file_number,
        "estimated_cost": import_file.estimated_cost,
        "estimated_cost_currency": import_file.estimated_cost_currency,
        "invoices_count": len(invoices),
        "invoice_totals_by_currency": invoice_totals_by_currency,
        "customs_duty": {
            "paid_amount_egp": import_file.customs_duty_paid_amount or 0.0,
            "receipt_no": import_file.customs_duty_receipt_no,
            "sadad_no": import_file.customs_duty_sadad_no,
            "payment_date": import_file.customs_duty_payment_date,
            "payment_status": import_file.customs_duty_payment_status or "PENDING",
        },
        "clearance_expenses_egp": import_file.total_clearance_expenses_egp or 0.0,
        "clearance_invoices_status": import_file.clearance_invoices_status,
        "inland_transport": {
            "cost_egp": import_file.inland_transport_cost_egp or 0.0,
            "status": import_file.inland_transport_status,
            "carrier_name": import_file.inland_carrier_name,
            "booking_no": import_file.inland_transport_booking_no,
        },
        "financial_settlement": {
            "status": import_file.financial_settlement_status,
            "date": import_file.financial_settlement_date,
            "invoices_count": import_file.financial_settlement_invoices_count or 0,
            "total_settled_egp": import_file.financial_settlement_total_egp or 0.0,
            "actual_landed_cost_total_egp": import_file.actual_landed_cost_total_egp or 0.0,
            "actual_landed_cost_markup_factor": import_file.actual_landed_cost_markup_factor,
            "actual_landed_cost_variance_egp": import_file.actual_landed_cost_variance_egp or 0.0,
            "actual_landed_cost_variance_pct": import_file.actual_landed_cost_variance_pct or 0.0,
        },
    }


def build_export_rows(files: List[Any], format: str = "excel", lang: str = "ar") -> List[List[Any]]:
    """Build tabular export rows for import files in Excel, CSV, or PDF format with None-safe formatting and language separation."""
    rows = []
    if format == "pdf":
        for f in files:
            file_ref = f.custom_file_number or f.import_file_code
            po_pi = f"{f.po_number or '-'}\n{f.pi_number or '-'}"
            progress = f"{(f.progress_percent or 0):.0f}%"
            st = STATUS_TRANSLATIONS.get(f.status, {}).get(lang, f.status)
            stage = STAGE_TRANSLATIONS.get(f.current_stage, {}).get(lang, f.current_stage)
            mode_inco = f"{f.shipment_mode} ({f.incoterm_code})" if f.incoterm_code else f.shipment_mode
            rows.append([
                file_ref,
                f.company_name,
                f.supplier_name,
                po_pi,
                mode_inco,
                stage,
                progress,
                st,
            ])
    else:
        for f in files:
            progress = f"{(f.progress_percent or 0):.0f}%"
            st = STATUS_TRANSLATIONS.get(f.status, {}).get(lang, f.status)
            stage = STAGE_TRANSLATIONS.get(f.current_stage, {}).get(lang, f.current_stage)
            rows.append([
                f.import_file_code,
                f.custom_file_number or '',
                f.company_name,
                f.supplier_name,
                f.po_number or '',
                f.pi_number or '',
                f.shipment_mode,
                f.incoterm_code,
                f.priority,
                stage,
                progress,
                f.next_action or '',
                f.owner or '',
                st,
                f.estimated_cost,
                f.estimated_cost_currency,
                f.port_of_loading or '',
                f.port_of_discharge or '',
                f.acid_number or '',
                f.form4_no or '',
                f.form46_no or '',
            ])
    return rows
