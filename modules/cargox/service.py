"""
CargoX & ACI Dispatch Hub Service Layer (CGX-001 / CGX-002 / CGX-003)
Unified Coordinator & Primary Facade delegating to domain-specific sub-services:
- cargox_envelope_service.py: Envelope lifecycle, state management, Nafeza transfer
- cargox_blockchain_service.py: Blockchain tx validation, cryptographic attestation, manifest
- cargox_document_service.py: Document extraction, PDF/XML processing, Standard Invoice, Extraction Engine
"""

from typing import List, Optional, Dict, Any
from sqlalchemy.orm import Session

from .model import CargoXEnvelope
from .schemas import (
    CargoXEnvelopeCreate,
    CargoXEnvelopeUpdate,
    CargoXSealAndTransferRequest,
    CargoXSealAndTransferResponse,
    CargoXAcidVerificationReport,
    DigitalManifestResponse,
)

# Domain-specific sub-services
from .cargox_blockchain_service import (
    CargoXBlockchainService,
    normalize_pki_signature,
)
from .cargox_envelope_service import CargoXEnvelopeService
from .cargox_document_service import (
    CargoXDocumentService,
    CargoXStandardInvoiceService,
    CargoXExtractionEngine,
)

# Backward-compatibility alias
_normalize_pki_signature = normalize_pki_signature


class CargoXService:
    """
    Unified Coordinator & Facade for CargoX ACI Dispatch Hub.
    Maintains 100% backward-compatibility with all existing router endpoints and callers.
    """

    @staticmethod
    def create_envelope(
        db: Session,
        payload: CargoXEnvelopeCreate,
        created_by: str = "SYSTEM",
    ) -> CargoXEnvelope:
        return CargoXEnvelopeService.create_envelope(db, payload, created_by=created_by)

    @staticmethod
    def get_envelopes(
        db: Session,
        search: Optional[str] = None,
        status: Optional[str] = None,
        import_file_id: Optional[int] = None,
        supplier_id: Optional[int] = None,
        include_inactive: bool = False,
        limit: int = 100,
        offset: int = 0,
    ) -> List[CargoXEnvelope]:
        return CargoXEnvelopeService.get_envelopes(
            db=db,
            search=search,
            status=status,
            import_file_id=import_file_id,
            supplier_id=supplier_id,
            include_inactive=include_inactive,
            limit=limit,
            offset=offset,
        )

    @staticmethod
    def get_envelope_by_id(db: Session, envelope_id: int) -> CargoXEnvelope:
        return CargoXEnvelopeService.get_envelope_by_id(db, envelope_id)

    @staticmethod
    def update_envelope(
        db: Session,
        envelope_id: int,
        payload: CargoXEnvelopeUpdate,
        updated_by: str = "SYSTEM",
    ) -> CargoXEnvelope:
        return CargoXEnvelopeService.update_envelope(
            db, envelope_id, payload, updated_by=updated_by
        )

    @staticmethod
    def seal_and_transfer_to_customs(
        db: Session,
        envelope_id: int,
        request: CargoXSealAndTransferRequest,
        updated_by: str = "SYSTEM",
    ) -> CargoXSealAndTransferResponse:
        return CargoXEnvelopeService.seal_and_transfer_to_customs(
            db, envelope_id, request, updated_by=updated_by
        )

    @staticmethod
    def _handle_cargox_seal_transfer_workflow(
        db: Session,
        envelope: CargoXEnvelope,
        updated_by: str = "SYSTEM",
    ) -> None:
        return CargoXEnvelopeService._handle_cargox_seal_transfer_workflow(
            db, envelope, updated_by=updated_by
        )

    @staticmethod
    def verify_acid_consistency(db: Session, envelope_id: int) -> CargoXAcidVerificationReport:
        return CargoXEnvelopeService.verify_acid_consistency(db, envelope_id)

    @staticmethod
    def generate_digital_manifest(db: Session, envelope_id: int) -> DigitalManifestResponse:
        return CargoXBlockchainService.generate_digital_manifest(db, envelope_id)

    @staticmethod
    def _build_digital_manifest_payload(envelope: CargoXEnvelope) -> Dict[str, Any]:
        return CargoXBlockchainService.build_digital_manifest_payload(envelope)

    @staticmethod
    def soft_delete_envelope(
        db: Session,
        envelope_id: int,
        deleted_by: str = "SYSTEM",
    ) -> CargoXEnvelope:
        return CargoXEnvelopeService.soft_delete_envelope(
            db, envelope_id, deleted_by=deleted_by
        )

    @staticmethod
    def restore_envelope(
        db: Session,
        envelope_id: int,
        restored_by: str = "SYSTEM",
    ) -> CargoXEnvelope:
        return CargoXEnvelopeService.restore_envelope(
            db, envelope_id, restored_by=restored_by
        )


__all__ = [
    "CargoXService",
    "CargoXEnvelopeService",
    "CargoXBlockchainService",
    "CargoXDocumentService",
    "CargoXStandardInvoiceService",
    "CargoXExtractionEngine",
    "_normalize_pki_signature",
    "normalize_pki_signature",
]
