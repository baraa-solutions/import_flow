"""Production Mock Guard (NLv0Dpj5) at the CargoX service / API level.

- Simulated seals are persisted with integration_mode='MOCK' and flagged is_simulated in responses.
- A production build with default config refuses to seal from the mock client and changes nothing.
- GET /api/v1/integrations/status feeds the Flutter Integration Status panel.
"""
import pytest
from fastapi.testclient import TestClient

from main import app
from modules.cargox.schemas import (
    CargoXDocumentCreate,
    CargoXEnvelopeCreate,
    CargoXEnvelopeResponse,
    CargoXSealAndTransferRequest,
)
from modules.cargox.service import CargoXService
from modules.integrations import integration_mode as guard
from modules.integrations.integration_mode import IntegrationProvider, MockIntegrationBlockedError


def _envelope_payload() -> CargoXEnvelopeCreate:
    return CargoXEnvelopeCreate(
        acid_number="7595528271020219999",
        importer_company_name="Guard Test Importer",
        supplier_name="Guard Test Supplier",
        supplier_cargox_id="CX-GUARD-1",
        bl_number="GUARD123456",
        documents=[
            CargoXDocumentCreate(doc_type=doc_type, file_name=f"{i}.pdf", verified_against_acid=True)
            for i, doc_type in enumerate(["Commercial Invoice", "Packing List", "Draft B/L"])
        ],
    )


@pytest.fixture
def clean_mode_env(monkeypatch):
    for provider in IntegrationProvider:
        monkeypatch.delenv(guard.mode_env_key(provider), raising=False)


def test_simulated_seal_is_persisted_and_flagged(db_session, clean_mode_env, monkeypatch):
    monkeypatch.setattr(guard, "is_frozen_build", lambda: False)
    envelope = CargoXService.create_envelope(db_session, _envelope_payload())
    assert envelope.integration_mode == "MOCK"
    assert CargoXEnvelopeResponse.model_validate(envelope).is_simulated is True

    res = CargoXService.seal_and_transfer_to_customs(
        db_session, envelope.envelope_id, CargoXSealAndTransferRequest()
    )
    assert res.is_simulated is True
    assert res.integration_mode == "MOCK"
    assert "محاكاة" in res.message
    db_session.refresh(envelope)
    assert envelope.integration_mode == "MOCK"


def test_request_cannot_choose_mode(db_session, clean_mode_env, monkeypatch):
    """The deprecated request ``mode`` is ignored: asking for LIVE still runs the configured MOCK."""
    monkeypatch.setattr(guard, "is_frozen_build", lambda: False)
    envelope = CargoXService.create_envelope(db_session, _envelope_payload())
    res = CargoXService.seal_and_transfer_to_customs(
        db_session, envelope.envelope_id, CargoXSealAndTransferRequest(mode="LIVE")
    )
    assert res.integration_mode == "MOCK" and res.is_simulated is True


def test_production_build_refuses_mock_seal_without_state_change(db_session, clean_mode_env, monkeypatch):
    monkeypatch.setattr(guard, "is_frozen_build", lambda: False)
    envelope = CargoXService.create_envelope(db_session, _envelope_payload())
    status_before = envelope.status

    monkeypatch.setattr(guard, "is_frozen_build", lambda: True)
    monkeypatch.delenv("ALLOW_MOCK_INTEGRATIONS", raising=False)
    with pytest.raises(MockIntegrationBlockedError):
        CargoXService.seal_and_transfer_to_customs(
            db_session, envelope.envelope_id, CargoXSealAndTransferRequest()
        )
    db_session.refresh(envelope)
    assert envelope.status == status_before
    assert envelope.status != "ACCEPTED_BY_CUSTOMS"
    assert envelope.all_documents_sealed is False


def test_production_build_creates_local_envelope_without_fake_hash(db_session, clean_mode_env, monkeypatch):
    monkeypatch.setattr(guard, "is_frozen_build", lambda: True)
    monkeypatch.delenv("ALLOW_MOCK_INTEGRATIONS", raising=False)
    envelope = CargoXService.create_envelope(db_session, _envelope_payload())
    assert envelope.blockchain_tx_hash is None
    assert envelope.pki_signature is None
    assert envelope.integration_mode is None


def test_integration_status_endpoint(clean_mode_env, monkeypatch):
    monkeypatch.setattr(guard, "is_frozen_build", lambda: False)
    with TestClient(app) as client:
        response = client.get("/api/v1/integrations/status")
    assert response.status_code == 200
    data = response.json()
    assert data["any_simulated"] is True
    providers = {p["provider"]: p for p in data["providers"]}
    assert set(providers) == {"NAFEZA", "CARGOX", "PKI", "GOEIC"}
    assert providers["NAFEZA"]["integration_mode"] == "MOCK"
    assert providers["NAFEZA"]["is_simulated"] is True


def test_acid_endpoint_returns_503_in_production_build(clean_mode_env, monkeypatch):
    monkeypatch.setattr(guard, "is_frozen_build", lambda: True)
    monkeypatch.delenv("ALLOW_MOCK_INTEGRATIONS", raising=False)
    with TestClient(app) as client:
        response = client.post("/api/v1/integrations/nafeza/request-acid", json={
            "importer_id": "IMP-1",
            "exporter_id": "EXP-1",
            "exporter_country_code": "CN",
            "tariff_hs_codes": ["8471.30.00"],
            "invoice_value_usd": 1000.0,
        })
    assert response.status_code == 503
    assert response.json()["detail"]["code"] == "MOCK_INTEGRATION_BLOCKED"
