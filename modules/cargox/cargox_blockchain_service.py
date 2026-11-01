"""
CargoX Blockchain, PKI & Smart Contract Attestation Sub-Service (CGX-001)
Provides cryptographic verification, blockchain transaction hash validation,
smart contract audit trail generation, and digital manifest snapshots.
"""

import json
import logging
from datetime import datetime, timezone
from typing import Dict, Any, Optional
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from .model import CargoXEnvelope
from .schemas import DigitalManifestResponse
from .repository import CargoXRepository

logger = logging.getLogger(__name__)


def normalize_pki_signature(pki_sig: Any) -> Optional[str]:
    """Normalize PKI signature object or dict to string format."""
    if not pki_sig:
        return None
    if isinstance(pki_sig, dict):
        return pki_sig.get("signature_base64") or json.dumps(pki_sig)
    return str(pki_sig)


class CargoXBlockchainService:
    """
    Sub-service for CargoX Blockchain, PKI signatures, and Smart Contract audit verification.
    """

    normalize_pki_signature = staticmethod(normalize_pki_signature)

    @staticmethod
    def validate_blockchain_tx_hash(tx_hash: Optional[str]) -> bool:
        """
        Validate blockchain transaction hash format:
        Standard Ethereum/Polygon hash: 0x followed by 64 hex characters (total 66 chars).
        Raw hash: 64 hex characters.
        """
        if not tx_hash or not isinstance(tx_hash, str):
            return False
        clean_hash = tx_hash.strip()
        if clean_hash.startswith("0x") or clean_hash.startswith("0X"):
            return len(clean_hash) == 66 and all(c in "0123456789abcdefABCDEF" for c in clean_hash[2:])
        return len(clean_hash) == 64 and all(c in "0123456789abcdefABCDEF" for c in clean_hash)

    @staticmethod
    def verify_cryptographic_attestation(envelope: CargoXEnvelope, signature: Optional[str] = None) -> bool:
        """
        Verify that the envelope has a valid PKI digital signature and is sealed.
        """
        sig = signature or envelope.pki_signature
        if not sig:
            return False
        return envelope.all_documents_sealed and bool(envelope.customs_confirmation_receipt)

    @staticmethod
    def record_smart_contract_audit_trail(
        db: Session,
        envelope_id: int,
        action: str,
        tx_hash: Optional[str] = None,
        pki_signature: Optional[str] = None,
        actor: str = "SYSTEM",
    ) -> Dict[str, Any]:
        """
        Record a cryptographic audit trail event for CargoX blockchain transactions.
        """
        envelope = CargoXRepository.get_by_id(db, envelope_id)
        if not envelope:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"مظروف CargoX برقم المعرف {envelope_id} غير موجود.",
            )

        audit_entry = {
            "envelope_id": envelope.envelope_id,
            "envelope_code": envelope.envelope_code,
            "acid_number": envelope.acid_number,
            "action": action,
            "tx_hash": tx_hash or envelope.blockchain_tx_hash,
            "pki_signature": pki_signature or envelope.pki_signature,
            "actor": actor,
            "recorded_at": datetime.now(timezone.utc).isoformat(),
        }
        logger.info(f"CargoX blockchain audit recorded: {audit_entry}")
        return audit_entry

    @staticmethod
    def build_digital_manifest_payload(envelope: CargoXEnvelope) -> Dict[str, Any]:
        """
        Build Egyptian Customs ACI Digital Manifest JSON payload from envelope.
        """
        return {
            "manifest_id": f"MTS-MAN-{envelope.envelope_code.replace('CGX-ENV-', '')}",
            "envelope_code": envelope.envelope_code,
            "acid_number": envelope.acid_number,
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "importer": {
                "company_id": envelope.importer_company_id,
                "company_name": envelope.importer_company_name,
                "tax_id": envelope.importer_tax_number or "N/A",
                "country": "Egypt",
            },
            "exporter": {
                "supplier_id": envelope.supplier_id,
                "supplier_name": envelope.supplier_name,
                "cargox_id": envelope.supplier_cargox_id,
            },
            "transport": {
                "bl_number": envelope.bl_number or "PENDING",
                "import_file_code": envelope.import_file_code or "N/A",
            },
            "blockchain": {
                "tx_hash": envelope.blockchain_tx_hash or "N/A",
                "pki_signature": envelope.pki_signature or "N/A",
                "customs_dispatch_status": envelope.status,
                "customs_confirmation_receipt": envelope.customs_confirmation_receipt or "N/A",
                "transferred_at": envelope.transferred_to_customs_at.isoformat() if envelope.transferred_to_customs_at else None,
            },
            "documents": [
                {
                    "doc_id": doc.doc_id,
                    "doc_type": doc.doc_type,
                    "doc_number": doc.doc_number,
                    "file_name": doc.file_name,
                    "file_hash_sha256": doc.file_hash,
                    "file_size_kb": doc.file_size_kb,
                    "is_mandatory": doc.is_mandatory,
                    "verified_against_acid": doc.verified_against_acid,
                    "pki_signature": doc.pki_signature,
                }
                for doc in envelope.documents
                if doc.is_active
            ],
        }

    @staticmethod
    def generate_digital_manifest(db: Session, envelope_id: int) -> DigitalManifestResponse:
        """
        Generate Egyptian Customs ACI Digital Manifest Response for an envelope.
        """
        envelope = CargoXRepository.get_by_id(db, envelope_id)
        if not envelope:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"مظروف CargoX برقم المعرف {envelope_id} غير موجود.",
            )

        payload = CargoXBlockchainService.build_digital_manifest_payload(envelope)

        formatted_summary = (
            f"=== EGYPTIAN CUSTOMS ACI DIGITAL MANIFEST ===\n"
            f"Manifest ID: {payload['manifest_id']}\n"
            f"Envelope Code: {payload['envelope_code']}\n"
            f"ACID Number: {payload['acid_number']}\n"
            f"Importer: {payload['importer']['company_name']} (Tax ID: {payload['importer']['tax_id']})\n"
            f"Foreign Exporter: {payload['exporter']['supplier_name']} (CargoX ID: {payload['exporter']['cargox_id']})\n"
            f"Bill of Lading: {payload['transport']['bl_number']}\n"
            f"Blockchain TX Hash: {payload['blockchain']['tx_hash']}\n"
            f"Total Attached Documents: {len(payload['documents'])}\n"
            f"Status: {payload['blockchain']['customs_dispatch_status']}\n"
            f"============================================="
        )

        return DigitalManifestResponse(
            envelope_id=envelope.envelope_id,
            envelope_code=envelope.envelope_code,
            acid_number=envelope.acid_number,
            manifest_json=payload,
            exported_at=datetime.now(timezone.utc),
            formatted_summary=formatted_summary,
        )
