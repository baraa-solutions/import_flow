"""
Service Layer & Business Engine Coordinator Facade for Import Documentation & ACI (Phase 3 - BP-014 to BP-019).

Radically decomposed into focused, modular sub-services (<1,500 lines each):
- doc_common.py: Shared constants, status codes, and common helper utilities
- document_upload_ocr_service.py: OCR, spatial PDF parsing, and multi-format text extraction
- acid_session_service.py: ACID Registration & Nafeza ACI session management (BP-014)
- banking_document_service.py: Banking documents, Form 4 workflow, SWIFT coverage (BP-015)
- shipment_document_service.py: Shipment documents, CargoX endorsement, central archive (BP-016)
- draft_bl_service.py: Draft Bill of Lading (B/L) 5-stage review engine & approvals (BP-017)
- certificate_template_service.py: COO & Inspection draft templates & country heuristics (BP-018)
- certificate_review_service.py: COO & Inspection certificate reviews & cross-matching (BP-018)
- invoice_bl_match_service.py: Commercial invoice vs B/L cross-matching & sync (BP-019)
- po_reconciliation_service.py: PO packing reconciliation & final adjustments persistence (BP-019)
"""

from . import doc_common
from . import document_upload_ocr_service
from . import acid_session_service
from . import banking_document_service
from . import shipment_document_service
from . import draft_bl_service
from . import certificate_template_service
from . import certificate_review_service
from . import invoice_bl_match_service
from . import po_reconciliation_service

# Re-export all sub-service attributes into this Coordinator Facade module
_submodules = [
    doc_common,
    document_upload_ocr_service,
    acid_session_service,
    banking_document_service,
    shipment_document_service,
    draft_bl_service,
    certificate_template_service,
    certificate_review_service,
    invoice_bl_match_service,
    po_reconciliation_service,
]

for _sub in _submodules:
    for _k, _v in _sub.__dict__.items():
        if not _k.startswith('__'):
            globals()[_k] = _v

__all__ = [k for k in globals().keys() if not k.startswith('__')]
