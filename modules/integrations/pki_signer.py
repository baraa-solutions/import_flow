import base64
import hashlib
import json
from datetime import datetime, timezone
from typing import Dict, Any, Optional

from .integration_mode import (
    IntegrationProvider,
    ensure_mode_allowed,
    select_integration_mode,
    simulation_flags,
)

MOCK_SIGNATURE_PREFIX = "MOCK_PKI_SIG_SHA256_"


class PKISignerService:
    """
    Egyptian Customs PKI & E-Signature Token Engine (CAdES-BES / CMS SignedData for Nafeza and CargoX).

    Only the simulated (MOCK) signer exists today; its signatures are flagged ``is_simulated`` and are
    refused in the production build unless ALLOW_MOCK_INTEGRATIONS is set. Real X.509 / hardware-token
    signing (Egypt Trust / FixedMisr) is the Phase 3 card; until then SANDBOX / LIVE raise instead of
    producing a fake sha256 "signature".
    """

    def __init__(self, mode: Optional[str] = None):
        self.integration_mode = select_integration_mode(IntegrationProvider.PKI, mode)
        self.mode = self.integration_mode.value

    def sign_payload(self, payload: Dict[str, Any], certificate_pem: str = None) -> Dict[str, Any]:
        """Signs a JSON payload and returns the signature envelope (simulated in MOCK mode)."""
        ensure_mode_allowed(IntegrationProvider.PKI, self.integration_mode)

        serialized_bytes = json.dumps(payload, sort_keys=True).encode("utf-8")
        hash_digest = hashlib.sha256(serialized_bytes).hexdigest()

        dummy_signature = f"{MOCK_SIGNATURE_PREFIX}{hash_digest[:16]}_{int(datetime.now(timezone.utc).timestamp())}"
        encoded_signature = base64.b64encode(dummy_signature.encode("utf-8")).decode("utf-8")

        return {
            "algorithm": "SHA256withRSA",
            "signed_at": datetime.now(timezone.utc).isoformat(),
            "digest_sha256": hash_digest,
            "signature_b64": encoded_signature,
            "certificate_issuer": "Egyptian Customs Authority Authority (ECA-PKI Root CA)",
            "pki_mode": self.mode,
            **simulation_flags(self.integration_mode),
        }

    def verify_signature(self, payload: Dict[str, Any], signature_b64: str) -> bool:
        """Accepts only the simulated signatures this signer produced for the same payload.

        Real certificate verification is not implemented, so any other signature is rejected."""
        if not signature_b64:
            return False
        try:
            decoded = base64.b64decode(signature_b64, validate=True).decode("utf-8")
        except (ValueError, UnicodeDecodeError):
            return False
        digest = hashlib.sha256(json.dumps(payload, sort_keys=True).encode("utf-8")).hexdigest()
        return decoded.startswith(f"{MOCK_SIGNATURE_PREFIX}{digest[:16]}_")
