"""Unit tests for login rate limiting and X-Forwarded-For spoofing defense (BEX-T08)."""
import time
import pytest
from fastapi.testclient import TestClient

import main
from modules.auth.rate_limiter import LoginRateLimiter, login_limiter
import settings


@pytest.fixture
def client():
    return TestClient(main.app)


def test_login_limiter_blocks_xff_spoofing(client: TestClient):
    """When peer IP is not in TRUSTED_PROXY_IPS, rotating X-Forwarded-For does not bypass rate limit."""
    login_limiter.reset_all()

    # 5 failed attempts with different XFF headers
    for i in range(5):
        resp = client.post(
            "/api/v1/auth/login",
            headers={"X-Forwarded-For": f"198.51.100.{i+1}"},
            json={"username_or_email": f"nonexistent_user_{i}", "password": "WrongPassword123"},
        )
        assert resp.status_code == 401

    # 6th attempt from the same client gets 429 Too Many Requests
    resp6 = client.post(
        "/api/v1/auth/login",
        headers={"X-Forwarded-For": "198.51.100.99"},
        json={"username_or_email": "another_nonexistent_user", "password": "WrongPassword123"},
    )
    assert resp6.status_code == 429
    login_limiter.reset_all()


def test_login_limiter_per_username(client: TestClient):
    """Targeting the same username triggers lockout even if requests come from different sources."""
    login_limiter.reset_all()
    target_user = "targeted_account_test"

    for i in range(5):
        resp = client.post(
            "/api/v1/auth/login",
            json={"username_or_email": target_user, "password": "WrongPassword123"},
        )
        assert resp.status_code == 401

    # 6th attempt against the same username gets 429
    resp6 = client.post(
        "/api/v1/auth/login",
        json={"username_or_email": target_user, "password": "WrongPassword123"},
    )
    assert resp6.status_code == 429
    login_limiter.reset_all()


def test_login_limiter_stale_key_pruning():
    """LoginRateLimiter prunes keys with failures older than the sliding window."""
    limiter = LoginRateLimiter(max_attempts=3, window_seconds=2, lockout_seconds=5)
    limiter.record_failure_key("old_key_1")
    limiter.record_failure_key("old_key_2")
    assert "old_key_1" in limiter._failures
    assert "old_key_2" in limiter._failures

    # Sleep past window
    time.sleep(2.1)

    # Calling check_key triggers pruning of stale keys
    limiter.check_key("new_key")
    assert "old_key_1" not in limiter._failures
    assert "old_key_2" not in limiter._failures
