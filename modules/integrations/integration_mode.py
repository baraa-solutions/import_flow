"""
Production Mock Guard (card NLv0Dpj5).

Single source of truth for how each external integration (Nafeza, CargoX, PKI, GOEIC) runs, so the
system never presents a simulated Nafeza / CargoX / PKI result as a real one.

Rules:
- The mode comes from settings (``<PROVIDER>_INTEGRATION_MODE`` in the environment / .env), never from
  a constructor default or from the API request. Default: ``MOCK``.
- ``MOCK`` results are always flagged (``is_simulated=True`` + ``integration_mode='MOCK'``).
- In the production (frozen) build ``MOCK`` is refused unless ``ALLOW_MOCK_INTEGRATIONS=true`` is set
  explicitly, so a default install cannot produce a "sent / signed / sealed" status from a mock client.
- ``SANDBOX`` / ``LIVE`` are refused until the real HTTP adapters and X.509 signing exist (Phase 3):
  the previous "production" code paths were fakes too (random ACID, sha256 "signature").

The guard errors subclass ``HTTPException`` (503) so any caller, router or service, returns a clear
error to the client without needing a dedicated exception handler.
"""
from __future__ import annotations

import logging
import os
from dataclasses import dataclass
from enum import Enum
from typing import Any, Dict, List, Optional

from fastapi import HTTPException, status

from utils.db_safety import is_frozen_build

_logger = logging.getLogger("integrations.mode")

ALLOW_MOCK_ENV = "ALLOW_MOCK_INTEGRATIONS"
_TRUE_VALUES = {"1", "true", "yes", "on"}


class IntegrationProvider(str, Enum):
    NAFEZA = "NAFEZA"
    CARGOX = "CARGOX"
    PKI = "PKI"
    GOEIC = "GOEIC"


class IntegrationMode(str, Enum):
    MOCK = "MOCK"
    SANDBOX = "SANDBOX"
    LIVE = "LIVE"


# Legacy spellings still sent by older clients / stored in old configs.
_MODE_ALIASES = {
    "MOCK": IntegrationMode.MOCK,
    "SIMULATION": IntegrationMode.MOCK,
    "SANDBOX": IntegrationMode.SANDBOX,
    "STAGING": IntegrationMode.SANDBOX,
    "LIVE": IntegrationMode.LIVE,
    "PRODUCTION": IntegrationMode.LIVE,
}

# Providers that have a real adapter. Empty until Phase 3 (real HTTP adapters + X.509 signing).
REAL_ADAPTER_PROVIDERS: frozenset = frozenset()

SIMULATION_NOTICE_AR = "وضع المحاكاة — لم يتم الإرسال فعلياً إلى نافذة / CargoX"
SIMULATION_NOTICE_EN = "Simulation mode - not sent to Nafeza/CargoX"


class IntegrationModeError(HTTPException):
    """Base guard error: the integration cannot run in the configured mode (HTTP 503)."""

    error_code = "INTEGRATION_MODE_ERROR"

    def __init__(self, provider: IntegrationProvider, mode: IntegrationMode, message: str):
        self.provider = provider
        self.mode = mode
        super().__init__(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                "code": self.error_code,
                "provider": provider.value,
                "integration_mode": mode.value,
                "message": message,
            },
        )


class MockIntegrationBlockedError(IntegrationModeError):
    """Production build refuses a MOCK client unless ALLOW_MOCK_INTEGRATIONS is set."""

    error_code = "MOCK_INTEGRATION_BLOCKED"


class IntegrationAdapterUnavailableError(IntegrationModeError):
    """SANDBOX / LIVE requested but no real adapter exists for the provider yet."""

    error_code = "INTEGRATION_ADAPTER_UNAVAILABLE"


def parse_integration_mode(raw: Optional[str]) -> IntegrationMode:
    """Normalise a mode string; unknown / empty values fall back to MOCK (the safe, flagged mode)."""
    if not raw:
        return IntegrationMode.MOCK
    mode = _MODE_ALIASES.get(str(raw).strip().upper())
    if mode is None:
        _logger.warning("Unknown integration mode %r; falling back to MOCK.", raw)
        return IntegrationMode.MOCK
    return mode


def mode_env_key(provider: IntegrationProvider) -> str:
    return f"{provider.value}_INTEGRATION_MODE"


def configured_mode(provider: IntegrationProvider) -> IntegrationMode:
    """Mode configured in settings for the provider (env / .env), MOCK when unset."""
    return parse_integration_mode(os.getenv(mode_env_key(provider)))


def mock_integrations_allowed() -> bool:
    return os.getenv(ALLOW_MOCK_ENV, "").strip().lower() in _TRUE_VALUES


def _production_build(is_production_build: Optional[bool]) -> bool:
    return is_frozen_build() if is_production_build is None else is_production_build


def ensure_mode_allowed(
    provider: IntegrationProvider,
    mode: IntegrationMode,
    is_production_build: Optional[bool] = None,
) -> None:
    """Raise when the provider must not run in ``mode``; returns silently otherwise."""
    if mode == IntegrationMode.MOCK:
        if _production_build(is_production_build) and not mock_integrations_allowed():
            raise MockIntegrationBlockedError(
                provider,
                mode,
                f"{provider.value} integration is in simulation (MOCK) mode and simulation is disabled in "
                f"the production build. Configure a real adapter or set {ALLOW_MOCK_ENV}=true explicitly.",
            )
        return
    if provider not in REAL_ADAPTER_PROVIDERS:
        raise IntegrationAdapterUnavailableError(
            provider,
            mode,
            f"{provider.value} integration mode {mode.value} is not available: no real adapter is "
            f"implemented yet. Nothing was sent.",
        )


def resolve_integration_mode(
    provider: IntegrationProvider,
    explicit_mode: Optional[str] = None,
    is_production_build: Optional[bool] = None,
) -> IntegrationMode:
    """Mode a client must run in. ``explicit_mode`` (code / tests only) overrides settings; the guard
    is applied either way, so an explicit MOCK is still refused in the production build."""
    mode = select_integration_mode(provider, explicit_mode)
    ensure_mode_allowed(provider, mode, is_production_build)
    return mode


def select_integration_mode(provider: IntegrationProvider, explicit_mode: Optional[str] = None) -> IntegrationMode:
    """Mode without applying the guard: used by client constructors so local, non-remote operations
    (e.g. parsing pasted Nafeza tariff text) keep working; remote operations call ``ensure_mode_allowed``."""
    return parse_integration_mode(explicit_mode) if explicit_mode else configured_mode(provider)


def is_simulated_mode(mode: Optional[str]) -> bool:
    return parse_integration_mode(mode) == IntegrationMode.MOCK if mode else False


def simulation_flags(mode: IntegrationMode) -> Dict[str, Any]:
    """Fields every client result carries so the API and UI can tell a simulation from a real call."""
    simulated = mode == IntegrationMode.MOCK
    return {
        "integration_mode": mode.value,
        "is_simulated": simulated,
        "simulation_notice": SIMULATION_NOTICE_EN if simulated else None,
    }


@dataclass(frozen=True)
class ProviderStatus:
    provider: str
    integration_mode: str
    is_simulated: bool
    is_available: bool
    message: str


def provider_status(provider: IntegrationProvider, is_production_build: Optional[bool] = None) -> ProviderStatus:
    mode = configured_mode(provider)
    try:
        ensure_mode_allowed(provider, mode, is_production_build)
        available, message = True, (SIMULATION_NOTICE_EN if mode == IntegrationMode.MOCK else "Live adapter")
    except IntegrationModeError as exc:
        available, message = False, exc.detail["message"]
    return ProviderStatus(
        provider=provider.value,
        integration_mode=mode.value,
        is_simulated=mode == IntegrationMode.MOCK,
        is_available=available,
        message=message,
    )


def integration_status_report(is_production_build: Optional[bool] = None) -> List[ProviderStatus]:
    return [provider_status(p, is_production_build) for p in IntegrationProvider]
