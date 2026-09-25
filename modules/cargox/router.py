"""
FastAPI Router for CargoX & ACI Dispatch Hub (CGX-001)
"""

from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from modules.auth.router import get_current_user
from sqlalchemy.orm import Session
from database.database import get_db

from .schemas import (
    CargoXEnvelopeCreate,
    CargoXEnvelopeUpdate,
    CargoXEnvelopeResponse,
    CargoXSealAndTransferRequest,
    CargoXSealAndTransferResponse,
    CargoXAcidVerificationReport,
    DigitalManifestResponse,
)
from .service import CargoXService

router = APIRouter(prefix="/api/v1/cargox", tags=["CargoX & ACI Dispatch Hub"], dependencies=[Depends(get_current_user)])


@router.get("/envelopes", response_model=List[CargoXEnvelopeResponse])
def get_cargox_envelopes(
    search: Optional[str] = Query(None, description="Search query by code, ACID, supplier, or B/L"),
    status: Optional[str] = Query(None, description="Status filter"),
    import_file_id: Optional[int] = Query(None, description="Filter by Import File ID"),
    supplier_id: Optional[int] = Query(None, description="Filter by Supplier ID"),
    include_inactive: bool = Query(False, description="Include soft-deleted records"),
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    """
    List all CargoX envelopes with advanced search and status filtering.
    """
    return CargoXService.get_envelopes(
        db=db,
        search=search,
        status=status,
        import_file_id=import_file_id,
        supplier_id=supplier_id,
        include_inactive=include_inactive,
        limit=limit,
        offset=offset,
    )


@router.get("/envelopes/{envelope_id}", response_model=CargoXEnvelopeResponse)
def get_cargox_envelope_by_id(
    envelope_id: int,
    db: Session = Depends(get_db),
):
    """
    Get detailed CargoX envelope by ID with all attached document items.
    """
    return CargoXService.get_envelope_by_id(db, envelope_id)


@router.post("/envelopes", response_model=CargoXEnvelopeResponse, status_code=status.HTTP_201_CREATED)
def create_cargox_envelope(
    payload: CargoXEnvelopeCreate,
    db: Session = Depends(get_db),
):
    """
    Create a new CargoX Blockchain Envelope with PKI Signature & initial attestation.
    """
    return CargoXService.create_envelope(db, payload, created_by="ADMIN")


@router.put("/envelopes/{envelope_id}", response_model=CargoXEnvelopeResponse)
def update_cargox_envelope(
    envelope_id: int,
    payload: CargoXEnvelopeUpdate,
    db: Session = Depends(get_db),
):
    """
    Update CargoX envelope details.
    """
    return CargoXService.update_envelope(db, envelope_id, payload, updated_by="ADMIN")


@router.post("/envelopes/{envelope_id}/seal-and-transfer", response_model=CargoXSealAndTransferResponse)
def seal_and_transfer_to_customs(
    envelope_id: int,
    request: CargoXSealAndTransferRequest,
    db: Session = Depends(get_db),
):
    """
    Seal CargoX envelope, verify mandatory documents, sign with PKI, and transfer to Egyptian Customs (Nafeza).
    """
    return CargoXService.seal_and_transfer_to_customs(db, envelope_id, request, updated_by="ADMIN")


@router.post("/envelopes/{envelope_id}/verify-acid", response_model=CargoXAcidVerificationReport)
def verify_envelope_acid_consistency(
    envelope_id: int,
    db: Session = Depends(get_db),
):
    """
    Perform 100% automated ACID consistency verification across all envelope documents.
    """
    return CargoXService.verify_acid_consistency(db, envelope_id)


@router.get("/envelopes/{envelope_id}/digital-manifest", response_model=DigitalManifestResponse)
def generate_digital_manifest(
    envelope_id: int,
    db: Session = Depends(get_db),
):
    """
    Generate and export official ACI Digital Manifest JSON & structured payload.
    """
    return CargoXService.generate_digital_manifest(db, envelope_id)


@router.delete("/envelopes/{envelope_id}", response_model=CargoXEnvelopeResponse)
def soft_delete_cargox_envelope(
    envelope_id: int,
    db: Session = Depends(get_db),
):
    """
    Soft delete a CargoX envelope.
    """
    return CargoXService.soft_delete_envelope(db, envelope_id, deleted_by="ADMIN")


@router.post("/envelopes/{envelope_id}/restore", response_model=CargoXEnvelopeResponse)
def restore_cargox_envelope(
    envelope_id: int,
    db: Session = Depends(get_db),
):
    """
    Restore a soft-deleted CargoX envelope.
    """
    return CargoXService.restore_envelope(db, envelope_id, restored_by="ADMIN")


# ============================================================================
# STANDARD EXCEL COMMERCIAL INVOICE ENDPOINTS (BP-025 / CGX-002)
# ============================================================================

from fastapi import UploadFile, File, Response
from .schemas import (
    StandardInvoicePayload,
    StandardInvoiceComparisonResponse,
    StandardInvoiceSessionCreate,
    StandardInvoiceSessionResponse,
    StandardInvoiceStatusUpdateRequest,
)
from .service import CargoXStandardInvoiceService


@router.get("/standard-invoice/generate/{import_file_id}")
def generate_standard_invoice_excel(
    import_file_id: int,
    db: Session = Depends(get_db),
):
    """
    Generate and download the official Standard Commercial Invoice (.xlsx)
    with all 36+ Named Ranges and structured InvoiceItems Table.
    """
    excel_bytes = CargoXStandardInvoiceService.generate_excel_template(db, import_file_id)
    return Response(
        content=excel_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={
            "Content-Disposition": f"attachment; filename=Commercial_Invoice_IMP_{import_file_id}.xlsx"
        },
    )


@router.post("/standard-invoice/parse", response_model=StandardInvoicePayload)
async def parse_supplier_invoice_excel(
    file: UploadFile = File(...),
):
    """
    Upload and parse supplier's completed Excel Commercial Invoice template
    using openpyxl Defined Names and the InvoiceItems table.
    """
    file_bytes = await file.read()
    return CargoXStandardInvoiceService.parse_excel_file(file_bytes)


@router.post("/standard-invoice/compare/{import_file_id}", response_model=StandardInvoiceComparisonResponse)
def compare_standard_invoice(
    import_file_id: int,
    supplier_data: StandardInvoicePayload,
    db: Session = Depends(get_db),
):
    """
    Run the side-by-side comparison engine between System Baseline Snapshot vs Supplier Uploaded Excel.
    """
    return CargoXStandardInvoiceService.compare_invoices(db, import_file_id, supplier_data)


@router.post("/standard-invoice/session", response_model=StandardInvoiceSessionResponse)
def save_or_upsert_standard_invoice_session(
    payload: StandardInvoiceSessionCreate,
    db: Session = Depends(get_db),
):
    """
    Create or update (Upsert) a Standard Commercial Invoice Review Session.
    Enforces mandatory override justification if approved with discrepancies.
    """
    return CargoXStandardInvoiceService.save_or_upsert_session(db, payload, created_by="ADMIN")


@router.get("/standard-invoice/session/by-file/{import_file_id}", response_model=Optional[StandardInvoiceSessionResponse])
def get_standard_invoice_session_by_file(
    import_file_id: int,
    db: Session = Depends(get_db),
):
    """
    Retrieve the active Standard Commercial Invoice Review Session for an import file.
    """
    return CargoXStandardInvoiceService.get_session_by_file(db, import_file_id)


@router.get("/standard-invoice/sessions", response_model=List[StandardInvoiceSessionResponse])
def list_standard_invoice_sessions(
    search: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    import_file_id: Optional[int] = Query(None),
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    """
    List all Standard Commercial Invoice Review Sessions with search and status filtering.
    """
    return CargoXStandardInvoiceService.list_sessions(
        db, search=search, status=status, import_file_id=import_file_id, limit=limit, offset=offset
    )


@router.put("/standard-invoice/session/{session_id}/status", response_model=StandardInvoiceSessionResponse)
def update_standard_invoice_session_status(
    session_id: int,
    payload: StandardInvoiceStatusUpdateRequest,
    db: Session = Depends(get_db),
):
    """
    Update session status (Approve, Reject, Under Review) with mandatory justification validation.
    """
    return CargoXStandardInvoiceService.update_session_status(db, session_id, payload, updated_by="ADMIN")


# ============================================================================
# CGX-003: Multi-Path Extraction Engine Endpoints
# ============================================================================

import io
import zipfile
from fastapi.responses import Response
from .schemas import (
    ExtractionRequest,
    ExtractionResponse,
    CustomsInvoiceTrackCreate,
    CustomsInvoiceTrackUpdate,
    CustomsInvoiceTrackResponse,
    StandardInvoicePayload,
    # CGX-004
    DualExtractionRequest,
    DualExtractionResponse,
    DualCustomsTrackCreate,
    PackingListPayload,
)
from .service import CargoXExtractionEngine
from .dual_extraction_service import CargoXDualExtractionEngine
from .excel_invoice_service import (
    generate_standard_invoice_excel_bytes,
    generate_customs_packing_list_excel_bytes,
)
from .excel_packing_list_service import generate_packing_list_excel_bytes


@router.post("/standard-invoice/extract/{import_file_id}", response_model=ExtractionResponse)
def extract_invoice_multi_mode(
    import_file_id: int,
    request: ExtractionRequest,
    db: Session = Depends(get_db),
):
    """
    CGX-003: محرك الاستخراج متعدد المسارات.

    يدعم 4 modes للاستخراج:
    - all_consolidated: ملف واحد — بنود مجمعة بـ HS Code (weighted average price)
    - all_detailed: ملف واحد — بنود مفصلة
    - per_invoice_consolidated: ملف منفصل لكل فاتورة — مجمع
    - per_invoice_detailed: ملف منفصل لكل فاتورة — مفصل
    """
    return CargoXExtractionEngine.extract(db, import_file_id, request)


@router.post("/standard-invoice/generate-zip/{import_file_id}")
def generate_invoice_zip(
    import_file_id: int,
    request: ExtractionRequest,
    db: Session = Depends(get_db),
):
    """
    CGX-003: تحميل ملفات Excel كـ ZIP أو ملف Excel أصلي مباشرة.
    - لو mode = all_* → ملف Excel أصلي واحد (.xlsx) مباشرة حتى لا يتعطل في Microsoft Excel
    - لو mode = per_invoice_* → ZIP يحتوي على ملف لكل فاتورة
    """
    extraction = CargoXExtractionEngine.extract(db, import_file_id, request)

    # إذا كان المطلوب ملف موحد (all_consolidated أو all_detailed) وله نتيجة واحدة
    # يتم إرجاع ملف Excel الأصلي مباشرة بصيغة xlsx لتجنب تلف الملف في Microsoft Excel
    if request.mode.startswith("all_") and len(extraction.results) == 1:
        excel_bytes = generate_standard_invoice_excel_bytes(extraction.results[0].payload)
        safe_inv = (extraction.results[0].invoice_number or f"Invoice_{import_file_id}").replace("/", "-").replace("\\", "-")
        return Response(
            content=excel_bytes,
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            headers={
                "Content-Disposition": f"attachment; filename=Commercial_Invoice_{safe_inv}.xlsx"
            },
        )

    zip_buffer = io.BytesIO()
    with zipfile.ZipFile(zip_buffer, "w", zipfile.ZIP_DEFLATED) as zf:
        for result in extraction.results:
            excel_bytes = generate_standard_invoice_excel_bytes(result.payload)
            safe_inv = (result.invoice_number or f"Invoice_{result.payload.invoice_number or import_file_id}").replace("/", "-").replace("\\", "-")
            filename = f"Commercial_Invoice_{safe_inv}.xlsx"
            zf.writestr(filename, excel_bytes)

    zip_buffer.seek(0)
    return Response(
        content=zip_buffer.read(),
        media_type="application/zip",
        headers={
            "Content-Disposition": f"attachment; filename=CargoX_Invoices_IMP{import_file_id}_{request.mode}.zip"
        },
    )



@router.post("/customs-track/create", response_model=CustomsInvoiceTrackResponse)
def create_customs_invoice_track(
    payload: CustomsInvoiceTrackCreate,
    db: Session = Depends(get_db),
):
    """
    CGX-003: إنشاء وحفظ نسخة جمركية (Customs Invoice Track) مستقلة.
    يتم تطبيق weighted average price لكل HS Code وحفظ الـ snapshot في DB.
    """
    return CargoXExtractionEngine.create_customs_track(db, payload, created_by="ADMIN")


@router.get("/customs-track/by-file/{import_file_id}", response_model=List[CustomsInvoiceTrackResponse])
def list_customs_tracks_by_file(
    import_file_id: int,
    db: Session = Depends(get_db),
):
    """
    CGX-003: قائمة كافة النسخ الجمركية المحفوظة لملف استيراد معين.
    """
    return CargoXStandardInvoiceService.list_customs_tracks_by_file(db, import_file_id)


@router.get("/customs-track/{track_id}", response_model=CustomsInvoiceTrackResponse)
def get_customs_track_by_id(
    track_id: int,
    db: Session = Depends(get_db),
):
    """
    الحصول على تفاصيل مسار جمركي معين.
    """
    return CargoXStandardInvoiceService.get_customs_track_by_id(db, track_id)


@router.put("/customs-track/{track_id}", response_model=CustomsInvoiceTrackResponse)
def update_customs_track_by_id(
    track_id: int,
    payload: CustomsInvoiceTrackUpdate,
    db: Session = Depends(get_db),
):
    """
    تعديل مسار جمركي (الحالة، الملاحظات، القيم).
    """
    return CargoXExtractionEngine.update_customs_track(
        db, track_id, payload.model_dump(exclude_unset=True), updated_by="ADMIN"
    )


@router.delete("/customs-track/{track_id}")
def delete_customs_track_by_id(
    track_id: int,
    db: Session = Depends(get_db),
):
    """
    حذف منطقي (Soft Delete) لمسار جمركي.
    """
    CargoXExtractionEngine.delete_customs_track(db, track_id, deleted_by="ADMIN")
    return {"status": "success", "message": f"تم حذف المسار الجمركي {track_id} بنجاح."}


@router.get("/customs-track/{track_id}/export-excel")
def export_customs_track_excel(
    track_id: int,
    db: Session = Depends(get_db),
):
    """
    تحميل ملف Excel التجاري المعتمد الخاص بالمسار الجمركي.
    """
    track = CargoXStandardInvoiceService.get_customs_track_by_id(db, track_id)

    data = track.customs_invoice_data
    if isinstance(data, list) and len(data) > 0:
        data = data[0]
    elif not isinstance(data, dict):
        data = {}

    payload = StandardInvoicePayload(**data) if data else StandardInvoicePayload()
    excel_bytes = generate_standard_invoice_excel_bytes(payload)
    return Response(
        content=excel_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={
            "Content-Disposition": f"attachment; filename=Customs_Invoice_{track.track_code}.xlsx"
        },
    )


@router.get("/customs-track/{track_id}/export-packing-list-excel")
def export_customs_track_packing_list_excel(
    track_id: int,
    structure: str = Query("by_hs_code", description="هيكل الطرود: by_hs_code | flat | by_pallet | by_carton"),
    db: Session = Depends(get_db),
):
    """
    CGX-003/CGX-004: تحميل Excel قائمة التعبئة الجمركية.
    يدعم تحديد هيكل الطرود: by_hs_code | flat | by_pallet | by_carton.
    """
    track = CargoXStandardInvoiceService.get_customs_track_by_id(db, track_id)

    # استخدام customs_packing_list_data إن وجد، وإلا بناء من الفاتورة
    pl_data = track.customs_packing_list_data
    if pl_data and isinstance(pl_data, dict) and "items" in pl_data:
        # بيانات من CGX-003 / CGX-004 (PackingListPayload-like)
        from .schemas import PackingListLineItem
        raw_items = pl_data.get("items") or []
        items = []
        for idx, itm in enumerate(raw_items, start=1):
            if isinstance(itm, dict):
                items.append(
                    PackingListLineItem(
                        line_number=int(itm.get("line_number") or idx),
                        package_ref=str(itm.get("package_ref") or itm.get("package_no") or f"PKG-{idx:02d}"),
                        hs_code=str(itm.get("hs_code") or ""),
                        description=str(itm.get("description") or ""),
                        manufacturer=itm.get("manufacturer"),
                        quantity=float(itm.get("quantity") or 0.0),
                        qty_unit=str(itm.get("qty_unit") or "PCS"),
                        net_weight_kg=float(itm.get("net_weight_kg") or 0.0),
                        gross_weight_kg=float(itm.get("gross_weight_kg") or 0.0),
                        invoice_number=itm.get("invoice_number"),
                        pallet_number=itm.get("pallet_number"),
                        carton_numbers=itm.get("carton_numbers"),
                        dimensions_cm=itm.get("dimensions_cm"),
                    )
                )
        pl_payload = PackingListPayload(
            acid_number=pl_data.get("acid_number"),
            seller_name=pl_data.get("seller_name"),
            buyer_name=pl_data.get("buyer_name"),
            packing_list_ref=pl_data.get("packing_list_ref") or pl_data.get("track_code"),
            total_packages=pl_data.get("total_packages") or len(items),
            total_gross_weight_kg=pl_data.get("total_gross_weight") or pl_data.get("total_gross_weight_kg") or 0.0,
            total_net_weight_kg=pl_data.get("total_net_weight") or pl_data.get("total_net_weight_kg") or 0.0,
            structure=structure,
            items=items,
        )
    else:
        # fallback: بناء من بيانات الفاتورة
        inv_data = track.customs_invoice_data
        if isinstance(inv_data, list) and len(inv_data) > 0:
            inv_data = inv_data[0]
        elif not isinstance(inv_data, dict):
            inv_data = {}
        inv_payload = StandardInvoicePayload(**inv_data) if inv_data else StandardInvoicePayload()
        from .schemas import PackingListLineItem
        items = [
            PackingListLineItem(
                line_number=i + 1,
                package_ref=f"PKG-{i+1:02d}",
                hs_code=itm.hs_code or "",
                description=itm.description or "",
                manufacturer=itm.manufacturer,
                quantity=itm.quantity,
                qty_unit=itm.qty_unit,
                net_weight_kg=itm.net_weight_kg,
                gross_weight_kg=itm.gross_weight_kg,
            )
            for i, itm in enumerate(inv_payload.items)
        ]
        pl_payload = PackingListPayload(
            acid_number=inv_payload.acid_number,
            seller_name=inv_payload.seller_name,
            buyer_name=inv_payload.buyer_name,
            total_packages=len(items),
            total_gross_weight_kg=inv_payload.gross_weight,
            total_net_weight_kg=inv_payload.net_weight,
            structure=structure,
            items=items,
        )

    excel_bytes = generate_packing_list_excel_bytes(
        payload=pl_payload,
        structure=structure,
        track_code=track.track_code,
        mode_label=f"{track.packing_list_mode or 'legacy'} / {structure}",
    )
    return Response(
        content=excel_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={
            "Content-Disposition": f"attachment; filename=Customs_Packing_List_{track.track_code}_{structure}.xlsx"
        },
    )


# ============================================================================
# CGX-004: Dual Extraction Engine Endpoints
# ============================================================================

@router.post("/standard-invoice/extract-dual/{import_file_id}", response_model=DualExtractionResponse)
def extract_dual_mode(
    import_file_id: int,
    request: DualExtractionRequest,
    db: Session = Depends(get_db),
):
    """
    CGX-004: محرك الاستخراج المزدوج.
    يستخرج الفاتورة التجارية وقائمة التعبئة الجمركية بمسارات مستقلة.

    الفاتورة: 4 modes × 3 grouping = 12 تشكيلة
    الباكينج ليست: 4 modes × 4 structures = 16 تشكيلة
    """
    return CargoXDualExtractionEngine.extract_dual(db, import_file_id, request)


@router.post("/standard-invoice/generate-dual-zip/{import_file_id}")
def generate_dual_zip(
    import_file_id: int,
    request: DualExtractionRequest,
    db: Session = Depends(get_db),
):
    """
    CGX-004: تحميل ZIP يحتوي على ملفات Excel للفاتورة والباكينج ليست بشكل مستقل.

    هيكل ZIP:
    ├── Invoice/
    │   └── Commercial_Invoice_*.xlsx
    └── PackingList/
        └── Customs_Packing_List_*.xlsx
    """
    dual_response = CargoXDualExtractionEngine.extract_dual(db, import_file_id, request)

    zip_buffer = io.BytesIO()
    with zipfile.ZipFile(zip_buffer, "w", zipfile.ZIP_DEFLATED) as zf:
        # --- Invoice files ---
        for result in dual_response.invoice_results:
            excel_bytes = generate_standard_invoice_excel_bytes(result.payload)
            safe_inv = (result.invoice_number or f"Invoice_{import_file_id}").replace("/", "-").replace("\\", "-")
            zf.writestr(f"Invoice/Commercial_Invoice_{safe_inv}.xlsx", excel_bytes)

        # --- Packing List files ---
        for pl_result in dual_response.packing_list_results:
            from .schemas import PackingListLineItem
            pl_payload = pl_result.payload
            pl_excel_bytes = generate_packing_list_excel_bytes(
                payload=pl_payload,
                structure=request.packing_list_structure,
                track_code=pl_result.packing_list_ref or "PL",
                mode_label=request.packing_list_mode,
            )
            safe_pl = (pl_result.packing_list_ref or f"PL_{import_file_id}").replace("/", "-")
            zf.writestr(f"PackingList/Customs_Packing_List_{safe_pl}.xlsx", pl_excel_bytes)

    zip_buffer.seek(0)
    return Response(
        content=zip_buffer.read(),
        media_type="application/zip",
        headers={
            "Content-Disposition": f"attachment; filename=CargoX_Dual_IMP{import_file_id}_{request.invoice_mode}_{request.packing_list_mode}.zip"
        },
    )


@router.post("/customs-track/create-dual", response_model=CustomsInvoiceTrackResponse)
def create_dual_customs_track(
    payload: DualCustomsTrackCreate,
    db: Session = Depends(get_db),
):
    """
    CGX-004: إنشاء مسار جمركي مزدوج.
    يحفظ فاتورة جمركية + قائمة تعبئة جمركية بمسارات استخراج مستقلة في DB.
    """
    return CargoXDualExtractionEngine.create_dual_customs_track(db, payload, created_by="ADMIN")

