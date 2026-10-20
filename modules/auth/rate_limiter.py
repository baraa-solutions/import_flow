"""
Rate Limiter for Sensitive Authentication Endpoints (Brute-Force & Credential-Stuffing Defense)
"""
import time
import threading
from collections import defaultdict
from typing import Dict, List
from fastapi import Request, HTTPException, status


class LoginRateLimiter:
    def __init__(self, max_attempts: int = 5, window_seconds: int = 60, lockout_seconds: int = 60):
        self.max_attempts = max_attempts
        self.window_seconds = window_seconds
        self.lockout_seconds = lockout_seconds
        self._lock = threading.Lock()
        self._failures: Dict[str, List[float]] = defaultdict(list)
        self._lockouts: Dict[str, float] = {}

    def _get_client_ip(self, request: Request) -> str:
        client_host = request.client.host if request.client else "127.0.0.1"
        try:
            import settings
            trusted_proxies = getattr(settings, "TRUSTED_PROXY_IPS", [])
        except Exception:
            trusted_proxies = []
        if client_host in trusted_proxies:
            forwarded = request.headers.get("x-forwarded-for")
            if forwarded:
                return forwarded.split(",")[0].strip()
        return client_host

    def check_rate_limit(self, request: Request):
        self.check_key(self._get_client_ip(request))

    def _prune_stale_keys(self, now: float):
        window_start = now - self.window_seconds
        stale_keys = [
            k for k, timestamps in self._failures.items()
            if not timestamps or timestamps[-1] <= window_start
        ]
        for k in stale_keys:
            if self._lockouts.get(k, 0) <= now:
                self._failures.pop(k, None)
                self._lockouts.pop(k, None)

    def check_key(self, client_ip: str):
        """Raise 429 while `client_ip` (an IP, or any other key such as a user id) is locked out."""
        now = time.time()

        with self._lock:
            self._prune_stale_keys(now)

            # Check active lockout
            lockout_until = self._lockouts.get(client_ip, 0)
            if now < lockout_until:
                retry_after = int(lockout_until - now) + 1
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail=f"تم تجاوز عدد محاولات تسجيل الدخول المسموح بها. يرجى الانتظار {retry_after} ثانية والمحاولة لاحقاً.",
                    headers={"Retry-After": str(retry_after)},
                )

            # Prune failures older than sliding window
            window_start = now - self.window_seconds
            self._failures[client_ip] = [t for t in self._failures[client_ip] if t > window_start]

            if len(self._failures[client_ip]) >= self.max_attempts:
                self._lockouts[client_ip] = now + self.lockout_seconds
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail=f"تم تجاوز الحد الأقصى للمحاولات ({self.max_attempts} محاولات). تم حظر الطلبات مؤقتاً لمدة {self.lockout_seconds} ثانية.",
                    headers={"Retry-After": str(self.lockout_seconds)},
                )

    def record_failure(self, request: Request):
        self.record_failure_key(self._get_client_ip(request))

    def record_success(self, request: Request):
        self.record_success_key(self._get_client_ip(request))

    def record_failure_key(self, key: str):
        now = time.time()
        with self._lock:
            self._failures[key].append(now)

    def record_success_key(self, key: str):
        with self._lock:
            self._failures.pop(key, None)
            self._lockouts.pop(key, None)

    def reset_all(self):
        """For testing cleanup"""
        with self._lock:
            self._failures.clear()
            self._lockouts.clear()


login_limiter = LoginRateLimiter(max_attempts=5, window_seconds=60, lockout_seconds=60)
