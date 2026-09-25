import re
from datetime import datetime, timezone, date
from typing import List, Optional, Dict, Any
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from modules.import_files.schemas import (
    ImportFileCreate,
    ImportFileUpdate,
    ImportFileResponse,
    ImportMasterReportSummary,
    CloneImportFileRequest,
    CloseShipmentSubmit,
    ReopenShipmentSubmit,
)
from modules.import_files.model import ImportFile
import modules.import_files.repository as repo
import modules.import_files.validators as validators


STEP_INITIAL_CONFIG = {
    "STEP_01": {
        "module": "BP-001 Receive Purchase Order & Planning",
        "stage": "Phase 1: Import Planning & Feasibility",
        "progress": 15.0,
        "next_action": "Evaluate Shipping Scenarios (BP-007) & Request Freight Quotations (BP-008)",
    },
    "STEP_02": {
        "module": "BP-002 Customs Studies & Tariff Review",
        "stage": "Phase 1 - Planning & Feasibility",
        "progress": 15.0,
        "next_action": "Review Import Regulatory Requirements",
    },
    "STEP_03": {
        "module": "BP-003 Import Regulatory Requirements",
        "stage": "Phase 1 - Planning & Feasibility",
        "progress": 20.0,
        "next_action": "Prepare Financial Approval Request",
    },
    "STEP_04": {
        "module": "BP-004 Finance Approvals & Budget",
        "stage": "Phase 2 - Shipment Initiation",
        "progress": 25.0,
        "next_action": "Issue Advance Payment & Request ACID",
    },
    "STEP_05": {
        "module": "BP-005 ACID Operations",
        "stage": "Phase 2 - Shipment Initiation",
        "progress": 30.0,
        "next_action": "Confirm ACID & Proceed to Freight Booking",
    },
    "STEP_06": {
        "module": "BP-006 Freight Booking",
        "stage": "Phase 3 - Booking & Doc Prep",
        "progress": 40.0,
        "next_action": "Confirm Shipping Line Booking & Review Draft BL",
    },
    "STEP_07": {
        "module": "BP-007 Freight Allocations",
        "stage": "Phase 3 - Booking & Doc Prep",
        "progress": 45.0,
        "next_action": "Audit Draft BL & Commercial Invoices",
    },
    "STEP_08": {
        "module": "BP-008 Draft Docs Review",
        "stage": "Phase 3 - Booking & Doc Prep",
        "progress": 50.0,
        "next_action": "Obtain Customs Approval on Draft Documents",
    },
    "STEP_08_PO": {
        "module": "BP-008.1 PO & Packing Reconciliation",
        "stage": "Phase 3 - Booking & Doc Prep",
        "progress": 48.0,
        "next_action": "Audit Commercial Invoice & Packing List vs PO",
    },
    "STEP_08_BL": {
        "module": "BP-008.2 Draft B/L Review & Approval",
        "stage": "Phase 3 - Booking & Doc Prep",
        "progress": 50.0,
        "next_action": "Review Draft B/L with Carrier & Issue Revisions",
    },
    "STEP_08_MATCH": {
        "module": "BP-008.3 Smart Invoice vs B/L Match",
        "stage": "Phase 3 - Booking & Doc Prep",
        "progress": 52.0,
        "next_action": "Verify Field Matching between Invoice & B/L",
    },
    "STEP_08_COO": {
        "module": "BP-008.4 Draft COO & EUR.1 Review",
        "stage": "Phase 3 - Booking & Doc Prep",
        "progress": 54.0,
        "next_action": "Audit Certificate of Origin & Preferential Trade Rules",
    },
    "STEP_08_COC": {
        "module": "BP-008.5 Draft Inspection Review",
        "stage": "Phase 3 - Booking & Doc Prep",
        "progress": 55.0,
        "next_action": "Audit Pre-shipment Inspection & Conformity Certificates",
    },
    "STEP_09": {
        "module": "BP-009 Docs Customs Approval",
        "stage": "Phase 3 - Booking & Doc Prep",
        "progress": 55.0,
        "next_action": "Upload Digital Documents to CargoX",
    },
    "STEP_10": {
        "module": "BP-010 CargoX Follow-up / Upload",
        "stage": "Phase 4 - Digital & Banking",
        "progress": 60.0,
        "next_action": "Collect Original Documents & Process Form 4",
    },
    "STEP_11": {
        "module": "BP-011 Originals Collection",
        "stage": "Phase 4 - Digital & Banking",
        "progress": 65.0,
        "next_action": "Submit Documents to Bank for Form 4",
    },
    "STEP_12": {
        "module": "BP-012 Bank Form 4",
        "stage": "Phase 4 - Digital & Banking",
        "progress": 70.0,
        "next_action": "Register Customs Declaration 46 K.M.",
    },
    "STEP_13": {
        "module": "BP-013 Customs Declaration 46",
        "stage": "Phase 5 - Port Operations & Clearance",
        "progress": 75.0,
        "next_action": "Customs Valuation, Inspection & Sampling",
    },
    "STEP_14": {
        "module": "BP-014 Clearance Follow-up",
        "stage": "Phase 5 - Port Operations & Clearance",
        "progress": 78.0,
        "next_action": "Inspect Cargo & Settle Customs Taxes",
    },
    "STEP_15": {
        "module": "BP-015 Drawing Samples",
        "stage": "Phase 5 - Port Operations & Clearance",
        "progress": 80.0,
        "next_action": "Track Regulatory & Lab Sample Test Results",
    },
    "STEP_16": {
        "module": "BP-016 Cargo Discrepancy",
        "stage": "Phase 5 - Port Operations & Clearance",
        "progress": 82.0,
        "next_action": "Verify Cargo Quantities & Reconcile Discrepancies",
    },
    "STEP_17": {
        "module": "BP-017 Final Customs Calculation",
        "stage": "Phase 5 - Port Operations & Clearance",
        "progress": 85.0,
        "next_action": "Pay Customs Duties & Release Cargo from Port",
    },
    "STEP_18": {
        "module": "BP-018 Demurrage & Detention",
        "stage": "Phase 5 - Port Operations & Clearance",
        "progress": 88.0,
        "next_action": "Track Container Demurrage & Free Time Expiry",
    },
    "STEP_19": {
        "module": "BP-019 Warehouse Receiving GRN",
        "stage": "Phase 6 - Inbound & Final Closure",
        "progress": 90.0,
        "next_action": "Inspect Received Goods & Settle Landed Cost",
    },
    "STEP_20": {
        "module": "BP-020 Landed Cost Settlement",
        "stage": "Phase 6 - Inbound & Final Closure",
        "progress": 95.0,
        "next_action": "Audit Landed Cost Breakdown & Issue Closure Certificate",
    },
    "STEP_21": {
        "module": "BP-021 Import File Final Closure",
        "stage": "Phase 6 - Inbound & Final Closure",
        "progress": 100.0,
        "next_action": "Archive Import File",
    },
}


def compute_file_formulas(
    form46_no: Optional[str] = None,
    form4_no: Optional[str] = None,
    swift_no: Optional[str] = None,
    selected_scenario: Optional[str] = None,
    status_str: str = "Open",
    initial_step: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Computes Formula values for Current Module, Current Stage, Progress %, and Next Action.
    """
    if status_str == "Closed" or status_str == "Archived":
        return {
            "current_module": "BP-040 Close Import File & Historical Archive",
            "current_stage": "Phase 10: Import File Closure",
            "progress_percent": 100.0,
            "next_action": "File Fully Closed & Archived",
        }

    if form46_no and form46_no.strip():
        return {
            "current_module": "BP-019 Prepare Customs Declaration 46",
            "current_stage": "Phase 3: Import Documentation & ACI",
            "progress_percent": 65.0,
            "next_action": "Customs Inspection & Duty Settlement (Phase 6/7)",
        }

    if (form4_no and form4_no.strip()) or (swift_no and swift_no.strip()):
        return {
            "current_module": "BP-015 Process Form 4 / Form 9 / L/C",
            "current_stage": "Phase 3: Import Documentation & ACI",
            "progress_percent": 50.0,
            "next_action": "Upload Digital Documents to CargoX & Prepare Declaration 46",
        }

    if selected_scenario and selected_scenario.strip():
        return {
            "current_module": "BP-007 Evaluate Shipping Scenarios",
            "current_stage": "Phase 1: Import Planning & Feasibility",
            "progress_percent": 25.0,
            "next_action": "Create Payment Request (BP-012) & Issue Form 4",
        }

    # If starting from a specific custom step (e.g. STEP_13 or STEP_06)
    if initial_step and initial_step in STEP_INITIAL_CONFIG and initial_step != "STEP_01":
        cfg = STEP_INITIAL_CONFIG[initial_step]
        return {
            "current_module": cfg["module"],
            "current_stage": cfg["stage"],
            "progress_percent": cfg["progress"],
            "next_action": cfg["next_action"],
        }

    return {
        "current_module": "BP-001 Receive Purchase Order & Planning",
        "current_stage": "Phase 1: Import Planning & Feasibility",
        "progress_percent": 15.0,
        "next_action": "Evaluate Shipping Scenarios (BP-007) & Request Freight Quotations (BP-008)",
    }



def create_import_file_service(
    db: Session, payload: ImportFileCreate, current_user: str = "System"
) -> ImportFile:
    # 1. Validate custom file number uniqueness if provided
    validators.validate_custom_file_number_unique(db, payload.custom_file_number)

    # 2. Validate multi-project ownership rule
    validators.validate_company_project_ownership(db, payload.company_id, payload.project_ids)

    # 3. Validate invoice currency consistency (all invoices must share the exact same currency)
    validators.validate_invoices_currency_consistency(payload.invoices_data)

    # 4. Generate file code if custom file number not given
    file_code = repo.generate_import_file_code(db)
    if not payload.custom_file_number:
        custom_num = file_code.replace("IMP-", "FILE-")
    else:
        custom_num = payload.custom_file_number.strip()

    # 5. Compute formulas
    formulas = compute_file_formulas(
        form46_no=payload.form46_no,
        form4_no=payload.form4_no,
        swift_no=payload.swift_no,
        selected_scenario=payload.selected_scenario,
        status_str=payload.status,
        initial_step=payload.initial_starting_step,
    )

    data_dict = payload.model_dump()
    data_dict["import_file_code"] = file_code
    data_dict["custom_file_number"] = custom_num
    if not data_dict.get("created_by"):
        data_dict["created_by"] = current_user
    if not data_dict.get("owner"):
        data_dict["owner"] = current_user
    data_dict.update(formulas)

    created_file = repo.create_import_file(db, data_dict)

    # 6. Seed initial stage activities in Lifecycle Board
    try:
        from modules.lifecycle_board.service import initialize_file_lifecycle_service
        initialize_file_lifecycle_service(db, file_code, payload.initial_starting_step or "STEP_01")
    except Exception:
        pass

    try:
        from modules.smart_tasks.service import auto_generate_system_tasks_for_file
        auto_generate_system_tasks_for_file(db, created_file)
    except Exception:
        pass
    return created_file


def update_import_file_service(
    db: Session, import_file_id: int, payload: ImportFileUpdate
) -> ImportFile:
    existing = repo.get_import_file_by_id(db, import_file_id)
    if not existing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ملف الاستيراد برقم المعرف {import_file_id} غير موجود.",
        )

    # Validate custom file number if changed
    if payload.custom_file_number:
        validators.validate_custom_file_number_unique(
            db, payload.custom_file_number, current_file_id=import_file_id
        )

    # Validate multi-project ownership
    target_company_id = payload.company_id or existing.company_id
    target_project_ids = payload.project_ids if payload.project_ids is not None else existing.project_ids
    validators.validate_company_project_ownership(db, target_company_id, target_project_ids)

    # Validate invoice currency consistency
    if payload.invoices_data is not None:
        validators.validate_invoices_currency_consistency(payload.invoices_data)

    update_dict = payload.model_dump(exclude_unset=True)

    # Re-compute formulas
    f46 = update_dict.get("form46_no", existing.form46_no)
    f4 = update_dict.get("form4_no", existing.form4_no)
    swift = update_dict.get("swift_no", existing.swift_no)
    scen = update_dict.get("selected_scenario", existing.selected_scenario)
    stat = update_dict.get("status", existing.status)

    formulas = compute_file_formulas(
        form46_no=f46,
        form4_no=f4,
        swift_no=swift,
        selected_scenario=scen,
        status_str=stat,
    )
    update_dict.update(formulas)

    updated_file = repo.update_import_file(db, import_file_id, update_dict)
    if updated_file:
        try:
            from modules.smart_tasks.service import auto_generate_system_tasks_for_file
            auto_generate_system_tasks_for_file(db, updated_file)
        except Exception:
            pass

        # Propagate ACID Number to Import Requirements Assessments
        if updated_file.acid_number:
            try:
                from modules.import_requirements.model import ImportRequirementAssessment
                from modules.import_requirements.service import sync_regulatory_tasks_and_alerts
                assessments = db.query(ImportRequirementAssessment).filter(
                    ImportRequirementAssessment.import_file_id == import_file_id
                ).all()
                for a in assessments:
                    a.acid_number = updated_file.acid_number
                    db.commit()
                    sync_regulatory_tasks_and_alerts(db, a.assessment_id)
            except Exception:
                pass

    return updated_file


def generate_master_report_service(
    db: Session,
    company_id: Optional[int] = None,
    supplier_id: Optional[int] = None,
    status: Optional[str] = None,
    owner: Optional[str] = None,
    search: Optional[str] = None,
) -> ImportMasterReportSummary:
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
    total_cost = sum(f.estimated_cost for f in files)

    file_responses = [ImportFileResponse.model_validate(f) for f in files]

    return ImportMasterReportSummary(
        total_import_files=len(files),
        open_files_count=len(open_files),
        in_progress_count=len(in_prog),
        closed_files_count=len(closed_files),
        total_estimated_cost=total_cost,
        files=file_responses,
    )


def close_shipment_service(
    db: Session,
    import_file_id: int,
    payload: "CloseShipmentSubmit",
) -> ImportFile:
    existing = repo.get_import_file_by_id(db, import_file_id)
    if not existing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ملف الاستيراد '{import_file_id}' غير موجود.",
        )

    if not payload.closure_reason or not payload.closure_reason.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="يلزم إدخال سبب إيقاف وإغلاق الشحنة قبل إتمام العملية.",
        )

    update_dict = {
        "status": "Closed",
        "current_module": "Phase 10 - Import File Closure & Historical Archive",
        "current_stage": f"Closed at {payload.closed_at_phase} - {payload.closure_reason.strip()}",
        "progress_percent": 100.0,
        "next_action": f"File Closed Early at {payload.closed_at_phase}",
        "closure_reason": payload.closure_reason.strip(),
        "closed_at_phase": payload.closed_at_phase,
    }

    return repo.update_import_file(db, import_file_id, update_dict)


def reopen_shipment_service(
    db: Session,
    import_file_id: int,
    payload: "ReopenShipmentSubmit",
) -> ImportFile:
    existing = repo.get_import_file_by_id(db, import_file_id)
    if not existing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ملف الاستيراد '{import_file_id}' غير موجود.",
        )

    if existing.status != "Closed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="الشحنة ليست مغلقة لإعادة فتحها.",
        )

    if not payload.reopen_reason or not payload.reopen_reason.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="يلزم إدخال سبب إعادة فتح وتنشيط الشحنة.",
        )

    restored_phase = existing.closed_at_phase or "Phase 1 - Import Planning & Feasibility"

    update_dict = {
        "status": "Active",
        "current_module": restored_phase,
        "current_stage": f"Reopened at {restored_phase} - {payload.reopen_reason.strip()}",
        "next_action": f"Resume Operations at {restored_phase}",
        "closure_reason": None,
        "closed_at_phase": None,
    }

    return repo.update_import_file(db, import_file_id, update_dict)

def get_all_import_files_service(
    db: Session,
    include_inactive: bool = False,
    search: Optional[str] = None,
    company_id: Optional[int] = None,
    supplier_id: Optional[int] = None,
    status: Optional[str] = None,
    owner: Optional[str] = None,
    hs_code: Optional[str] = None,
    incoterm_code: Optional[str] = None,
    port_of_loading: Optional[str] = None,
    port_of_discharge: Optional[str] = None,
    shipment_mode: Optional[str] = None,
    carrier: Optional[str] = None,
    date_from: Optional[date] = None,
    date_to: Optional[date] = None,
):
    return repo.get_all_import_files(
        db,
        include_inactive=include_inactive,
        search=search,
        company_id=company_id,
        supplier_id=supplier_id,
        status=status,
        owner=owner,
        hs_code=hs_code,
        incoterm_code=incoterm_code,
        port_of_loading=port_of_loading,
        port_of_discharge=port_of_discharge,
        shipment_mode=shipment_mode,
        carrier=carrier,
        date_from=date_from,
        date_to=date_to,
    )

def get_paginated_import_files_service(
    db: Session,
    page: int = 1,
    page_size: int = 50,
    include_inactive: bool = False,
    search: Optional[str] = None,
    company_id: Optional[int] = None,
    supplier_id: Optional[int] = None,
    status: Optional[str] = None,
    owner: Optional[str] = None,
    hs_code: Optional[str] = None,
    incoterm_code: Optional[str] = None,
    port_of_loading: Optional[str] = None,
    port_of_discharge: Optional[str] = None,
    shipment_mode: Optional[str] = None,
    carrier: Optional[str] = None,
    date_from: Optional[date] = None,
    date_to: Optional[date] = None,
):
    return repo.get_paginated_import_files(
        db,
        include_inactive=include_inactive,
        search=search,
        company_id=company_id,
        supplier_id=supplier_id,
        status=status,
        owner=owner,
        hs_code=hs_code,
        incoterm_code=incoterm_code,
        port_of_loading=port_of_loading,
        port_of_discharge=port_of_discharge,
        shipment_mode=shipment_mode,
        carrier=carrier,
        date_from=date_from,
        date_to=date_to,
        page=page,
        page_size=page_size,
    )

def get_operational_dashboard_data_service(db: Session, phase: Optional[str] = None, priority: Optional[str] = None, broker_id: Optional[int] = None, broker_name: Optional[str] = None, search: Optional[str] = None):
    return repo.get_operational_dashboard_data(db, phase=phase, priority=priority, broker_id=broker_id, broker_name=broker_name, search=search)

def get_import_file_by_id_service(db: Session, import_file_id: int):
    return repo.get_import_file_by_id(db, import_file_id)

def get_import_file_by_code_service(db: Session, import_file_code: str):
    return repo.get_import_file_by_code(db, import_file_code)

def soft_delete_import_file_service(db: Session, import_file_id: int):
    return repo.soft_delete_import_file(db, import_file_id)


def generate_freight_rfq_service(
    db: Session,
    import_file_id: int,
    recipient_name: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Generates structured Freight RFQ data, Email templates, and WhatsApp text
    based on the Import File, linked Purchase Orders, Packing Lists, and Supplier Address.
    """
    import_file = repo.get_import_file_by_id(db, import_file_id)
    if not import_file:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ملف الاستيراد '{import_file_id}' غير موجود.",
        )

    # 1. Fetch linked POs and collect details
    from modules.purchase_orders.model import PurchaseOrder
    po_ids_list = import_file.po_ids or []
    linked_pos: List[PurchaseOrder] = db.query(PurchaseOrder).filter(
        (PurchaseOrder.import_file_id == import_file_id) |
        (PurchaseOrder.po_id.in_(po_ids_list) if po_ids_list else False) |
        (PurchaseOrder.po_number == (import_file.po_number or "---"))
    ).all()

    # Helper function to clean noise from commodity description
    def _clean_commodity_item(txt: str) -> str:
        if not txt:
            return ""
        noise_patterns = [
            r"weight\s+kg", r"gross\s+weight(?:\s+kg)?", r"net\s+weight(?:\s+kg)?",
            r"volume\s+mc", r"packages", r"country\s+of\s+origin\s*:\s*[A-Za-z]+",
            r"commessa\s+[0-9/\-]+", r"your\s+order[^\n]*", r"our\s+order[^\n]*",
            r"bolla\s+[^\n]*", r"dis\.\s*[0-9/\-]+", r"rev\.\s*[0-9/\-]+",
            r"n\.i\.art\.[^\n]*", r"dpr\s+633[^\n]*", r"v\.a\.t\.[^\n]*",
            r"bank\s+details[^\n]*", r"iban\s*:[^\n]*", r"swift\s*:[^\n]*",
            r"payment\s+condition[^\n]*", r"delivery\s+address[^\n]*",
            r"administration\s+manager[^\n]*",
        ]
        cleaned = txt
        for pat in noise_patterns:
            cleaned = re.sub(pat, "", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"\s+", " ", cleaned).strip(" ,;|/-")
        return cleaned

    # 2. Extract Commodity, HS Codes & Descriptions
    commodities = set()
    hs_codes_set = set()
    total_cbm = 0.0
    gross_weight = 0.0
    net_weight = 0.0
    total_packages = 0
    package_breakdowns = []
    earliest_ready_date = None

    for po in linked_pos:
        if po.total_cbm:
            total_cbm += float(po.total_cbm)
        if po.total_gross_weight_kg:
            gross_weight += float(po.total_gross_weight_kg)
        if po.total_net_weight_kg:
            net_weight += float(po.total_net_weight_kg)
        if po.total_packages_count:
            total_packages += int(po.total_packages_count)

        po_hs = getattr(po, 'hs_code', None)
        if po_hs:
            clean_hs = re.sub(r"[^0-9]", "", str(po_hs).strip())
            if clean_hs:
                hs_codes_set.add(clean_hs)

        for line in getattr(po, 'line_items', []):
            desc = line.description_en or line.description_ar
            if desc:
                cleaned_desc = _clean_commodity_item(desc.strip())
                if cleaned_desc:
                    commodities.add(cleaned_desc)
            line_hs = getattr(line, 'hs_code', None)
            if not line_hs and getattr(line, 'tariff', None):
                line_hs = getattr(line.tariff, 'hs_code', None)
            if line_hs:
                clean_hs = re.sub(r"[^0-9]", "", str(line_hs).strip())
                if clean_hs:
                    hs_codes_set.add(clean_hs)

        for pl_item in getattr(po, 'packing_list_items', []):
            qty = int(pl_item.qty_pkg) if pl_item.qty_pkg else 1
            l_val = float(pl_item.length_cm or 0)
            w_val = float(pl_item.width_cm or 0)
            h_val = float(pl_item.height_cm or 0)
            dims = f"{qty} {pl_item.package_type or 'pkg'} @ {l_val:g} x {w_val:g} x {h_val:g} cm"
            package_breakdowns.append(dims)
            if getattr(pl_item, 'hs_code', None):
                clean_hs = re.sub(r"[^0-9]", "", str(pl_item.hs_code).strip())
                if clean_hs:
                    hs_codes_set.add(clean_hs)

    # Fallback to packing_lists_data from ImportFile if PO aggregates were 0
    if total_cbm == 0.0 and import_file.packing_lists_data:
        for p in import_file.packing_lists_data:
            total_cbm += float(p.get("cbm", 0.0))
            gross_weight += float(p.get("gross_weight_kg", 0.0))
            total_packages += int(p.get("total_packages", 0))

    imp_hs = getattr(import_file, 'hs_code', None)
    if imp_hs:
        clean_hs = re.sub(r"[^0-9]", "", str(imp_hs).strip())
        if clean_hs:
            hs_codes_set.add(clean_hs)

    commodity_str = " | ".join(sorted(commodities)) if commodities else (import_file.notes or "General Imported Cargo")
    hs_codes_str = ", ".join(sorted(hs_codes_set)) if hs_codes_set else "As per invoice / To be declared"
    
    # 3. Logistics Details & Air Freight Detection
    supplier = import_file.supplier
    supplier_address_parts = []
    if supplier:
        if getattr(supplier, 'address', None):
            supplier_address_parts.append(supplier.address)
        if getattr(supplier, 'city', None):
            supplier_address_parts.append(supplier.city)
        if getattr(supplier, 'country', None):
            supplier_address_parts.append(supplier.country)

    default_pickup_addr = ", ".join(supplier_address_parts) if supplier_address_parts else (import_file.pickup_address or "Supplier Factory Address")
    pickup_address = import_file.pickup_address or default_pickup_addr
    
    origin_country = supplier.country if supplier and getattr(supplier, 'country', None) else "Origin Port"
    default_pol = "London Gateway" if "UK" in origin_country or "United Kingdom" in origin_country else ("Shanghai Port" if "China" in origin_country or "CN" in origin_country else ("Jeddah Port" if "Saudi" in origin_country else "Port of Loading"))
    
    pol = import_file.port_of_loading or default_pol
    pod = import_file.port_of_discharge or "El Dekheila Port, Egypt (non TMT)"
    incoterm = import_file.incoterm_code or "EXW"
    free_days = import_file.target_free_days or 21
    service_type = import_file.service_type_preference or "Direct"

    # Detect if Air Freight or Courier or Multimodal
    mode_str = (import_file.shipment_mode or "").lower()
    pol_lower = (pol or "").lower()
    pod_lower = (pod or "").lower()
    is_courier = "courier" in mode_str or "بريد" in mode_str or "express" in mode_str
    is_air = ("air" in mode_str or "airport" in pol_lower or "airport" in pod_lower or "مطار" in pol_lower or "مطار" in pod_lower or "جوي" in mode_str or is_courier)
    is_multimodal = "multi" in mode_str or "متعدد" in mode_str

    # Calculate Volumetric & Chargeable Weight for Air / Courier
    divisor = 5000.0 if is_courier else 6000.0
    volumetric_weight_air = total_cbm * (200.0 if is_courier else 166.67) if total_cbm > 0 else 0.0
    pl_vol_weight = 0.0
    for po in linked_pos:
        for pl_item in getattr(po, 'packing_list_items', []):
            qty = float(pl_item.qty_pkg or 1)
            l = float(pl_item.length_cm or 0)
            w = float(pl_item.width_cm or 0)
            h = float(pl_item.height_cm or 0)
            if l > 0 and w > 0 and h > 0:
                pl_vol_weight += ((l * w * h) / divisor) * qty
    if pl_vol_weight > volumetric_weight_air:
        volumetric_weight_air = pl_vol_weight

    chargeable_weight = max(gross_weight, volumetric_weight_air) if is_air else gross_weight

    # Calculate Recommended Containers / Mode Description
    if is_courier:
        recommended_containers = f"Courier Express ({total_cbm:.2f} CBM | Chg Wt: {chargeable_weight:,.1f} kg)"
    elif is_air:
        recommended_containers = f"Air Freight ({total_cbm:.2f} CBM | Chg Wt: {chargeable_weight:,.1f} kg)"
    elif is_multimodal:
        recommended_containers = f"Multimodal Transport ({total_cbm:.2f} CBM | {gross_weight:,.1f} kg)"
    elif total_cbm >= 60:
        recommended_containers = "1 CTNR * 40HC + 1 CTNR * 20GP"
    elif total_cbm >= 30:
        recommended_containers = "1 CTNR * 40HC (40' High Cube)"
    elif total_cbm >= 15:
        recommended_containers = "1 CTNR * 20GP (20' General Purpose)"
    elif total_cbm > 0:
        recommended_containers = f"LCL ({total_cbm:.2f} CBM) / 20GP"
    else:
        recommended_containers = "40'HC / 20'GP"

    ready_date_str = import_file.cargo_ready_date.strftime("%d %B %Y") if import_file.cargo_ready_date else "End of Current Month"
    recipient = recipient_name.strip() if recipient_name and recipient_name.strip() else "Shipping Line / Forwarder"

    packages_str = f"{total_packages} Packages" if total_packages > 0 else "As per Packing List"
    if package_breakdowns:
        packages_str += "\n" + "\n".join(f"  • {pb}" for pb in package_breakdowns[:10])

    # 4. Evaluate Stackability (Stackable vs Non-Stackable vs Mixed)
    stackable_pkgs = 0
    non_stackable_pkgs = 0
    has_pl_items = False

    for po in linked_pos:
        pl_items = getattr(po, 'packing_list_items', [])
        if pl_items:
            has_pl_items = True
            for pl in pl_items:
                q = int(pl.qty_pkg or 1)
                if getattr(pl, 'is_stackable', None) is False or getattr(pl, 'is_stackable', None) == 0:
                    non_stackable_pkgs += q
                else:
                    stackable_pkgs += q
        else:
            po_stackable = getattr(po, 'is_pallet_stackable', None)
            po_pkg_count = int(po.total_packages_count or 1)
            if po_stackable is False:
                non_stackable_pkgs += po_pkg_count
            elif po_stackable is True:
                stackable_pkgs += po_pkg_count

    if not has_pl_items and import_file.packing_lists_data:
        for p in import_file.packing_lists_data:
            q = int(p.get("total_packages", 1))
            if p.get("is_stackable") is False:
                non_stackable_pkgs += q
            elif p.get("is_stackable") is True:
                stackable_pkgs += q

    if stackable_pkgs > 0 and non_stackable_pkgs > 0:
        stackability_str = f"Mixed ({stackable_pkgs} Pkgs Stackable, {non_stackable_pkgs} Pkgs Non-Stackable)"
    elif stackable_pkgs > 0 and non_stackable_pkgs == 0:
        stackability_str = "Stackable (Yes)"
    elif non_stackable_pkgs > 0 and stackable_pkgs == 0:
        stackability_str = "Non-Stackable (Do Not Double Stack)"
    else:
        if "crate" in packages_str.lower() or "pallet" in packages_str.lower():
            stackability_str = "Non-Stackable (Do Not Double Stack)"
        else:
            stackability_str = "Stackable (Yes)"

    special_reqs = import_file.shipping_instructions_notes or f"Must be {free_days} days free time at destination (DET/DEM), direct line preferred, delivery port {pod}."

    # 5. Generate Email Body Template
    if incoterm.upper() == "EXW":
        if is_air:
            email_body = f"""Dear {recipient},

Good day.
Could you please provide your best EXW (Ex Works) all-in air freight quotation for the below shipment:

• Incoterm: EXW (Ex Works)
• Commodity: "{commodity_str}"
• HS Code(s): {hs_codes_str}
• Shipment Mode: Air Freight (Total Volume: {total_cbm:.2f} CBM)
• Gross Weight: {gross_weight:,.1f} kg | Net Weight: {net_weight:,.1f} kg
• Chargeable Weight: {chargeable_weight:,.1f} kg (Volumetric Wt: {volumetric_weight_air:,.1f} kg)
• Number of Packages: {packages_str}
• Stackability: {stackability_str}

• Pickup Address:
  {import_file.supplier_name}
  {pickup_address}

• Airport of Departure (Preferred): {pol}
• Airport of Destination: {pod}
• Service: {service_type}
• Cargo Ready Date: {ready_date_str}

Kindly include:
1. EXW All-in Rate (Trucking from factory + Origin Airport Handling / OTHC + Export Customs Clearance + Air Freight)
2. Destination Terminal Handling & D/O fees (DTHC) for {pod}
3. Flight Schedule & Transit Time (T/T in days)
4. Earliest Flight Departure & ETD Date
5. Destination Storage / Free Time confirmation (if applicable)

We look forward to receiving your quotation ASAP.
Best regards,
{import_file.company_name} - Logistics & Import Dept.
"""
        else:
            email_body = f"""Dear {recipient},

Good day.
Could you please provide your best EXW (Ex Works) all-in freight quotation for the below shipment:

• Incoterm: EXW (Ex Works)
• Commodity: "{commodity_str}"
• HS Code(s): {hs_codes_str}
• Volume / Mode: {recommended_containers} (Total CBM: {total_cbm:.2f} m³)
• Gross Weight: {gross_weight:,.1f} kg | Net Weight: {net_weight:,.1f} kg
• Number of Packages: {packages_str}
• Stackability: {stackability_str}

• Pickup Address:
  {import_file.supplier_name}
  {pickup_address}

• Port of Loading (Preferred): {pol}
• Port of Discharge: {pod}
• Service: {service_type}
• Cargo Ready Date: {ready_date_str}
• Required Free Time: Must be {free_days} days free time at destination (DET/DEM)

Kindly include:
1. EXW All-in Rate (Trucking + Local Origin Port Fees / OTHC + Export Customs Clearance + Ocean Freight)
2. DTHC for {pod}
3. Transit Time (T/T in days)
4. Earliest Vessel Schedule & ETD Date
5. Free time at destination (DET/DEM) - Must be {free_days} days free time.

We look forward to receiving your quotation ASAP.
Best regards,
{import_file.company_name} - Logistics & Import Dept.
"""
    else:
        weight_line = f"• Total Volume: {total_cbm:.2f} m³ | Gross Weight: {gross_weight:,.1f} kg | Chargeable Weight: {chargeable_weight:,.1f} kg" if is_air else f"• Total Volume: {total_cbm:.2f} m³ | Total Gross Weight: {gross_weight:,.1f} kg"
        email_body = f"""Dear {recipient},

Good day.
Kindly share your best {incoterm} freight rates for {recommended_containers} based on the shipment details below:

• Incoterm: {incoterm}
• Commodity: "{commodity_str}"
• HS Code(s): {hs_codes_str}
• POL (Port of Loading / Airport): {pol}
• POD (Port of Discharge / Airport): {pod}
{weight_line}
• Number of Packages: {packages_str}
• Stackability: {stackability_str}
• Cargo Ready Date: {ready_date_str}
• Required Free Time: {free_days} days free time (FT) at destination
• Service: {service_type}

Kindly include:
1. Freight Rate ({incoterm} to {pod})
2. DTHC for {pod}
3. Transit Time & Earliest Schedule (ETD)
4. Free Time confirmation ({free_days} days FT at destination)

Special Instructions:
{special_reqs}

Thanks to share the competitive rates and earliest schedule ASAP.
Best regards,
{import_file.company_name} - Logistics & Import Dept.
"""

    # 6. Generate WhatsApp Text Template (100% Professional English)
    chg_wt_str = f" | Chg Wt: {chargeable_weight:,.1f} KG" if is_air else ""
    whatsapp_text = f"""🚢 *FREIGHT QUOTATION INQUIRY (RFQ)*
━━━━━━━━━━━━━━━━━━
🏢 *Requester / Importer:* {import_file.company_name}
📦 *Commodity:* {commodity_str}
🏷️ *HS Code(s):* {hs_codes_str}
📊 *Volume & Weight:* {recommended_containers} | {total_cbm:.2f} CBM | {gross_weight:,.1f} KG{chg_wt_str}
📦 *Packages & Stackability:* {total_packages} Pkgs | {stackability_str}
🌐 *Incoterm Rule:* {incoterm}
📍 *Port / Airport of Loading (POL):* {pol}
🏁 *Port / Airport of Discharge (POD):* {pod}
📅 *Cargo Ready Date:* {ready_date_str}
⏳ *Required Free Time:* {free_days} Days Free Time (FT at destination)
⚡ *Service Preference:* {service_type} Direct Line

{"📍 *Pickup / Factory Address:*\n" + pickup_address + "\n" if incoterm.upper() == 'EXW' else ""}
📝 *Special Instructions:*
{special_reqs}
━━━━━━━━━━━━━━━━━━
Kindly provide your most competitive all-in rates and earliest departure schedule. Thank you."""

    file_title = import_file.custom_file_number or import_file.import_file_code
    email_subject = f"Freight Rate Inquiry - {file_title} | {import_file.supplier_name} | {import_file.company_name} | {incoterm} | {recommended_containers}"

    return {
        "import_file_id": import_file.import_file_id,
        "import_file_code": import_file.import_file_code,
        "custom_file_number": import_file.custom_file_number,
        "company_name": import_file.company_name,
        "supplier_name": import_file.supplier_name,
        "incoterm_code": incoterm,
        "commodity": commodity_str,
        "hs_codes": list(hs_codes_set),
        "hs_codes_str": hs_codes_str,
        "shipment_mode": "Air Freight" if is_air else (import_file.shipment_mode or "Sea FCL"),
        "is_air": is_air,
        "recommended_containers": recommended_containers,
        "total_cbm": round(total_cbm, 3),
        "gross_weight_kg": round(gross_weight, 2),
        "net_weight_kg": round(net_weight, 2),
        "volumetric_weight_kg": round(volumetric_weight_air, 2),
        "chargeable_weight_kg": round(chargeable_weight, 2),
        "total_packages": total_packages,
        "packages_breakdown": packages_str,
        "stackability": stackability_str,
        "pickup_address": pickup_address,
        "port_of_loading": pol,
        "port_of_discharge": pod,
        "cargo_ready_date": ready_date_str,
        "target_free_days": free_days,
        "service_type": service_type,
        "special_requirements": special_reqs,
        "email_subject": email_subject,
        "email_body_template": email_body,
        "whatsapp_text_template": whatsapp_text,
    }


def hold_import_file_service(
    db: Session,
    import_file_id: int,
    hold_reason: str,
    hold_notes: Optional[str] = None,
    stage_name: Optional[str] = None,
    step_name: Optional[str] = None,
) -> ImportFile:
    existing = repo.get_import_file_by_id(db, import_file_id)
    if not existing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ملف الاستيراد '{import_file_id}' غير موجود.",
        )

    if not hold_reason or not hold_reason.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="يلزم إدخال سبب إيقاف وتعليق الشحنة.",
        )

    now_dt = datetime.now()
    stage = stage_name or existing.current_stage
    step = step_name or existing.current_module

    update_dict = {
        "status": "On Hold",
        "paused_at_stage": stage,
        "paused_at_step": step,
        "hold_reason": hold_reason.strip(),
        "hold_date": now_dt,
        "notes": f"تم إيقاف الشحنة عند مرحلة [{stage}]: {hold_reason.strip()}" + (f" | {hold_notes}" if hold_notes else ""),
    }

    # Update lifecycle board activities
    try:
        from modules.lifecycle_board.service import hold_shipment_activities_service
        hold_shipment_activities_service(db, existing.import_file_code, hold_reason.strip())
    except Exception:
        pass

    return repo.update_import_file(db, import_file_id, update_dict)


def resume_import_file_service(
    db: Session,
    import_file_id: int,
    resume_notes: Optional[str] = None,
) -> ImportFile:
    existing = repo.get_import_file_by_id(db, import_file_id)
    if not existing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ملف الاستيراد '{import_file_id}' غير موجود.",
        )

    if existing.status != "On Hold":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="الشحنة ليست في حالة تعليق (On Hold) لاستئنافها.",
        )

    update_dict = {
        "status": "In Progress",
        "hold_reason": None,
        "hold_date": None,
        "notes": f"تم استئناف العمل: {resume_notes or 'استئناف تشغيل الشحنة'}",
    }

    # Resume lifecycle board activities
    try:
        from modules.lifecycle_board.service import resume_shipment_activities_service
        resume_shipment_activities_service(db, existing.import_file_code, resume_notes)
    except Exception:
        pass

    return repo.update_import_file(db, import_file_id, update_dict)


def clone_import_file_service(
    db: Session, import_file_id: int, payload: CloneImportFileRequest, current_user: str = "System"
):
    """
    Universal Clone Engine (UX-CLONE-011) — Entity-Level Clone for Import Files.
    Copies: Company, Supplier, Broker, Ports, Mode, Incoterms, Priority, Category, Invoices & Packing Lists (optional).
    Mandatory Resets:
      - import_file_code must be unique (validated).
      - custom_file_number must be unique or null.
      - acid_number, form4_no, swift_no, form46_no, b/l numbers -> RESET to None.
      - is_customs_released = False, customs_released_at = None.
      - progress_percent = 0.0, current_stage = "Draft", current_module = "Import Documentation".
      - status = "Draft".
      - cloned_from_id = original.import_file_id, cloned_from_code = original.import_file_code.
      - attachments are NOT copied unless explicitly requested.
    """
    original = repo.get_import_file_by_id(db, import_file_id)
    if not original:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ملف الاستيراد الأصلي '{import_file_id}' غير موجود.",
        )

    target_code = payload.target_import_file_code or payload.new_import_file_code
    if not target_code:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="كود ملف الاستيراد الجديد مطلوب.",
        )

    copy_invoices = payload.copy_invoices_data if payload.copy_items is None else payload.copy_items
    copy_pls = payload.copy_packing_lists if payload.copy_items is None else payload.copy_items

    # 1. Uniqueness check for target_code
    existing_code = repo.get_import_file_by_code(db, target_code)
    if existing_code:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"كود ملف الاستيراد '{target_code}' مستخدم بالفعل.",
        )

    # 2. Uniqueness check for target_custom_file_number if provided
    if payload.target_custom_file_number:
        existing_custom = db.query(ImportFile).filter(
            ImportFile.custom_file_number == payload.target_custom_file_number
        ).first()
        if existing_custom:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"رقم الملف الجمركي المخصص '{payload.target_custom_file_number}' مستخدم بالفعل.",
            )

    cloned_data = {
        "import_file_code": target_code,
        "custom_file_number": payload.target_custom_file_number,
        "company_id": original.company_id,
        "company_name": original.company_name,
        "supplier_id": original.supplier_id,
        "supplier_name": original.supplier_name,
        "broker_id": original.broker_id,
        "broker_name": original.broker_name,
        "po_number": None,
        "po_ids": [],
        "pi_number": None,
        "invoices_data": original.invoices_data if copy_invoices else [],
        "packing_lists_data": original.packing_lists_data if copy_pls else [],
        "invoices_count": len(original.invoices_data) if (copy_invoices and original.invoices_data) else 0,
        "extraction_preference": original.extraction_preference,
        "project_ids": original.project_ids or [],
        "project_names": original.project_names,
        "shipment_mode": original.shipment_mode,
        "incoterm_code": original.incoterm_code,
        "priority": original.priority or "High",
        "shipment_category": original.shipment_category or "New Purchase",
        "required_eta": None,
        "file_opening_date": date.today(),
        "selected_scenario": original.selected_scenario,
        "pickup_address": original.pickup_address,
        "hs_code": original.hs_code,
        "product_category": original.product_category,
        "port_of_loading": original.port_of_loading,
        "port_of_discharge": original.port_of_discharge,
        "cargo_ready_date": None,
        "target_free_days": original.target_free_days or 21,
        "service_type_preference": original.service_type_preference or "Direct",
        "shipping_instructions_notes": original.shipping_instructions_notes,
        # Mandatory Reset Fields
        "acid_number": None,
        "acid_request_date": None,
        "acid_issue_date": None,
        "acid_expiry_date": None,
        "acid_execution_days": None,
        "is_customs_released": False,
        "customs_released_at": None,
        "form4_no": None,
        "form4_request_date": None,
        "form4_received_date": None,
        "form4_execution_days": None,
        "swift_no": None,
        "form46_no": None,
        "estimated_cost": original.estimated_cost,
        "estimated_cost_currency": original.estimated_cost_currency or "USD",
        "current_module": "Import Documentation",
        "current_stage": "Draft",
        "progress_percent": 0.0,
        "next_action": "إكمال بيانات الشحنة المستنسخة وفتح إجراءات ACID",
        "initial_starting_stage": "Draft",
        "status": "Draft",
        "owner": original.owner or current_user,
        "notes": payload.notes or f"مستنسخ من الشحنة: {original.import_file_code}",
        "is_active": True,
        "created_by": current_user,
        "updated_by": current_user,
        "cloned_from_id": original.import_file_id,
        "cloned_from_code": original.import_file_code,
    }

    new_file = ImportFile(**cloned_data)
    db.add(new_file)
    db.commit()
    db.refresh(new_file)
    return new_file



