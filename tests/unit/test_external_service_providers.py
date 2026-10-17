"""
Targeted test suite for modules/external_service_providers.

Re-exports and exercises test suites from test_partners.py and test_partner_kpi_scorecard.py
to ensure automated pattern matching and execution by scripts/ci/guardrails.py pr-gate.
"""

from tests.unit.test_partners import TestExternalServiceProviderService
from tests.unit.test_partner_kpi_scorecard import (
    TestPartnerKPIScorecard,
    db_session,
    client,
)

__all__ = [
    "TestExternalServiceProviderService",
    "TestPartnerKPIScorecard",
    "db_session",
    "client",
]
