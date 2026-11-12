"""Production Mock Guard (Trello NLv0Dpj5).

A production (frozen) build with the default config must never produce a "sent / signed / sealed"
result from a mock client; simulation results are always flagged; webhooks with fake signatures are
rejected; the integration mode comes from settings, not from the request.
"""
import pytest

from modules.integrations import integration_mode as guard
from modules.integrations.cargox_client import CargoXIntegrationClient
from modules.integrations.integration_mode import (
    IntegrationAdapterUnavailableError,
    IntegrationMode,
    IntegrationProvider,
    MockIntegrationBlockedError,
    ensure_mode_allowed,
    integration_status_report,
    is_simulated_mode,
    parse_integration_mode,
    resolve_integration_mode,
)
from modules.integrations.nafeza_client import NafezaIntegrationClient
from modules.integrations.pki_signer import PKISignerService


ACID_ARGS = dict(
    importer_id="IMP-1",
    exporter_id="EXP-1",
    exporter_country_code="CN",
    tariff_hs_codes=["8471.30.00"],
    invoice_value_usd=1000.0,
)


@pytest.fixture
def production_build(monkeypatch):
    """Simulate the PyInstaller build with the default config (no ALLOW_MOCK_INTEGRATIONS)."""
    monkeypatch.setattr(guard, "is_frozen_build", lambda: True)
    monkeypatch.delenv("ALLOW_MOCK_INTEGRATIONS", raising=False)
    for provider in IntegrationProvider:
        monkeypatch.delenv(guard.mode_env_key(provider), raising=False)


@pytest.fixture
def development_build(monkeypatch):
    monkeypatch.setattr(guard, "is_frozen_build", lambda: False)
    for provider in IntegrationProvider:
        monkeypatch.delenv(guard.mode_env_key(provider), raising=False)


class TestModeParsing:
    @pytest.mark.parametrize("raw,expected", [
        (None, IntegrationMode.MOCK),
        ("", IntegrationMode.MOCK),
        ("mock", IntegrationMode.MOCK),
        ("STAGING", IntegrationMode.SANDBOX),
        ("sandbox", IntegrationMode.SANDBOX),
        ("PRODUCTION", IntegrationMode.LIVE),
        ("live", IntegrationMode.LIVE),
        ("garbage", IntegrationMode.MOCK),
    ])
    def test_parse_integration_mode(self, raw, expected):
        assert parse_integration_mode(raw) == expected

    def test_mode_read_from_settings_not_constructor(self, development_build, monkeypatch):
        monkeypatch.setenv("NAFEZA_INTEGRATION_MODE", "LIVE")
        assert NafezaIntegrationClient().mode == "LIVE"
        monkeypatch.setenv("NAFEZA_INTEGRATION_MODE", "MOCK")
        assert NafezaIntegrationClient().mode == "MOCK"

    def test_is_simulated_mode(self):
        assert is_simulated_mode("MOCK") is True
        assert is_simulated_mode("LIVE") is False
        assert is_simulated_mode(None) is False


class TestDevelopmentSimulation:
    def test_nafeza_acid_is_flagged_simulated(self, development_build):
        res = NafezaIntegrationClient().request_acid_number(**ACID_ARGS)
        assert res["is_simulated"] is True
        assert res["integration_mode"] == "MOCK"
        assert res["simulation_notice"]
        assert res["pki_signature"]["is_simulated"] is True

    def test_cargox_results_are_flagged_simulated(self, development_build):
        client = CargoXIntegrationClient()
        env = client.create_envelope("2026-ACID-1", "IMP", "CGX-EXP", ["Commercial Invoice"])
        transfer = client.transfer_envelope_to_customs(env["envelope_id"], "BL-1")
        assert env["is_simulated"] is True and env["integration_mode"] == "MOCK"
        assert transfer["is_simulated"] is True and transfer["integration_mode"] == "MOCK"

    def test_pki_mock_signature_flagged_and_verifiable(self, development_build):
        signer = PKISignerService()
        payload = {"a": 1}
        sig = signer.sign_payload(payload)
        assert sig["is_simulated"] is True
        assert signer.verify_signature(payload, sig["signature_b64"]) is True
        assert signer.verify_signature({"a": 2}, sig["signature_b64"]) is False
        assert signer.verify_signature(payload, "Zm9vYmFy") is False
        assert signer.verify_signature(payload, "") is False


class TestProductionBuildBlocksMocks:
    def test_ensure_mode_allowed_blocks_mock(self, production_build):
        with pytest.raises(MockIntegrationBlockedError) as exc:
            ensure_mode_allowed(IntegrationProvider.NAFEZA, IntegrationMode.MOCK)
        assert exc.value.status_code == 503
        assert exc.value.detail["code"] == "MOCK_INTEGRATION_BLOCKED"

    def test_nafeza_acid_blocked(self, production_build):
        with pytest.raises(MockIntegrationBlockedError):
            NafezaIntegrationClient().request_acid_number(**ACID_ARGS)

    def test_explicit_mock_override_still_blocked(self, production_build):
        with pytest.raises(MockIntegrationBlockedError):
            NafezaIntegrationClient(mode="MOCK").request_acid_number(**ACID_ARGS)

    def test_cargox_create_and_transfer_blocked(self, production_build):
        client = CargoXIntegrationClient()
        with pytest.raises(MockIntegrationBlockedError):
            client.create_envelope("2026-ACID-1", "IMP", "CGX-EXP", ["Commercial Invoice"])
        with pytest.raises(MockIntegrationBlockedError):
            client.transfer_envelope_to_customs("CGX-ENV-1", "BL-1")

    def test_pki_sign_blocked(self, production_build):
        with pytest.raises(MockIntegrationBlockedError):
            PKISignerService().sign_payload({"a": 1})

    def test_allow_flag_enables_flagged_simulation(self, production_build, monkeypatch):
        monkeypatch.setenv("ALLOW_MOCK_INTEGRATIONS", "true")
        res = NafezaIntegrationClient().request_acid_number(**ACID_ARGS)
        assert res["is_simulated"] is True

    def test_local_tariff_operations_not_blocked(self, production_build):
        # Parsing pasted tariff text is local work, not a call to Nafeza: constructing the client is allowed.
        assert NafezaIntegrationClient().mode == "MOCK"


class TestNoFakeLiveMode:
    @pytest.mark.parametrize("mode", ["SANDBOX", "LIVE"])
    def test_live_and_sandbox_refused_without_real_adapter(self, development_build, monkeypatch, mode):
        monkeypatch.setenv("NAFEZA_INTEGRATION_MODE", mode)
        monkeypatch.setenv("CARGOX_INTEGRATION_MODE", mode)
        monkeypatch.setenv("PKI_INTEGRATION_MODE", mode)
        with pytest.raises(IntegrationAdapterUnavailableError):
            NafezaIntegrationClient().request_acid_number(**ACID_ARGS)
        with pytest.raises(IntegrationAdapterUnavailableError):
            CargoXIntegrationClient().transfer_envelope_to_customs("CGX-ENV-1", "BL-1")
        with pytest.raises(IntegrationAdapterUnavailableError):
            PKISignerService().sign_payload({"a": 1})

    def test_resolve_integration_mode_applies_guard(self, production_build):
        with pytest.raises(MockIntegrationBlockedError):
            resolve_integration_mode(IntegrationProvider.CARGOX)


class TestWebhookVerification:
    @pytest.mark.parametrize("signature", ["", "short", "x" * 11, "a" * 256, "sha256=deadbeef" * 4])
    def test_any_fake_signature_rejected(self, development_build, signature):
        assert NafezaIntegrationClient().verify_webhook_signature("{}", signature) is False


class TestStatusReport:
    def test_dev_report_marks_all_simulated_and_available(self, development_build):
        report = {s.provider: s for s in integration_status_report()}
        assert set(report) == {p.value for p in IntegrationProvider}
        assert all(s.is_simulated and s.is_available for s in report.values())

    def test_production_report_marks_mock_unavailable(self, production_build):
        report = integration_status_report()
        assert all(s.is_simulated and not s.is_available for s in report)
        assert all("ALLOW_MOCK_INTEGRATIONS" in s.message for s in report)
