import base64
import hashlib
import hmac
import json
import logging
import secrets
import time
import re
from typing import Optional, Tuple

logger = logging.getLogger(__name__)

from settings import SECRET_KEY, JWT_ACCESS_TOKEN_EXPIRE_SECONDS, JWT_REFRESH_GRACE_PERIOD_SECONDS


def validate_password_strength(password: str) -> Tuple[bool, Optional[str]]:
    """
    Validates password strength according to enterprise security policy:
    - Minimum 8 characters, maximum 128 characters
    - At least one letter (a-z or A-Z)
    - At least one digit (0-9)
    """
    if not password or len(password) < 8:
        return False, "كلمة المرور يجب أن تتكون من 8 أحرف على الأقل."
    if len(password) > 128:
        return False, "كلمة المرور يجب ألا تتجاوز 128 حرفاً."
    if not re.search(r"[A-Za-z]", password):
        return False, "كلمة المرور يجب أن تحتوي على حرف أبجدي واحد على الأقل."
    if not re.search(r"\d", password):
        return False, "كلمة المرور يجب أن تحتوي على رقم واحد على الأقل."
    return True, None


def hash_password(password: str) -> str:
    """
    Hashes password using PBKDF2-HMAC-SHA256 with 600,000 iterations and random salt.
    Format: pbkdf2_sha256$<iterations>$<salt_hex>$<hash_hex>
    """
    salt = secrets.token_hex(16)
    iterations = 600_000
    derived = hashlib.pbkdf2_hmac(
        'sha256',
        password.encode('utf-8'),
        salt.encode('utf-8'),
        iterations
    ).hex()
    return f"pbkdf2_sha256${iterations}${salt}${derived}"


def verify_password(plain_password: str, hashed_password: str, username: Optional[str] = None) -> bool:
    """
    Verifies a plain password against a stored hash.
    Supports modern PBKDF2 and seamlessly verifies legacy SHA-256 hashes.
    """
    if not hashed_password:
        return False

    if hashed_password.startswith("pbkdf2_sha256$"):
        parts = hashed_password.split("$")
        if len(parts) == 4:
            try:
                iterations = int(parts[1])
                salt = parts[2]
                stored_hash = parts[3]
                computed = hashlib.pbkdf2_hmac(
                    'sha256',
                    plain_password.encode('utf-8'),
                    salt.encode('utf-8'),
                    iterations
                ).hex()
                return hmac.compare_digest(computed, stored_hash)
            except Exception:
                return False

    # Legacy SHA-256 fallback (importflow_salt_v1)
    legacy_salt = "importflow_salt_v1"
    legacy_hash = hashlib.sha256((plain_password + legacy_salt).encode('utf-8')).hexdigest()
    matched = hmac.compare_digest(legacy_hash, hashed_password)
    if matched:
        logger.warning("Legacy SHA-256 password verified for user %s; password needs upgrade", username or "<unknown>")
    return matched



def create_access_token(data: dict, expires_in_seconds: Optional[int] = None) -> str:
    if expires_in_seconds is None:
        expires_in_seconds = JWT_ACCESS_TOKEN_EXPIRE_SECONDS

    to_encode = data.copy()
    to_encode.update({"exp": int(time.time()) + expires_in_seconds})
    if "jti" not in to_encode:
        to_encode["jti"] = secrets.token_hex(8)


    header = json.dumps({"alg": "HS256", "typ": "JWT"}).encode('utf-8')
    payload = json.dumps(to_encode).encode('utf-8')

    b64_header = base64.urlsafe_b64encode(header).decode('utf-8').rstrip("=")
    b64_payload = base64.urlsafe_b64encode(payload).decode('utf-8').rstrip("=")

    signature_input = f"{b64_header}.{b64_payload}"
    # S-006 fix: use proper HMAC-SHA256, not raw SHA256(data+key)
    signature = hmac.new(
        SECRET_KEY.encode('utf-8'),
        signature_input.encode('utf-8'),
        hashlib.sha256
    ).hexdigest()

    return f"{signature_input}.{signature}"


def decode_access_token(
    token: str,
    check_revocation: bool = True,
    ignore_expiration: bool = False,
    max_grace_period_seconds: Optional[int] = None,
) -> Optional[dict]:
    try:
        parts = token.split(".")
        if len(parts) != 3:
            return None

        b64_header, b64_payload, signature = parts
        signature_input = f"{b64_header}.{b64_payload}"
        # S-006 fix: verify with proper HMAC-SHA256
        expected_signature = hmac.new(
            SECRET_KEY.encode('utf-8'),
            signature_input.encode('utf-8'),
            hashlib.sha256
        ).hexdigest()

        if not hmac.compare_digest(signature, expected_signature):
            return None

        # Pad payload if needed
        padded_payload = b64_payload + "=" * (-len(b64_payload) % 4)
        payload_bytes = base64.urlsafe_b64decode(padded_payload)
        payload = json.loads(payload_bytes.decode('utf-8'))

        now = int(time.time())
        token_exp = payload.get("exp", 0)

        if not ignore_expiration:
            if token_exp < now:
                return None  # Expired
        else:
            # Enforce max grace period even when ignoring expiration for silent refresh
            grace = max_grace_period_seconds if max_grace_period_seconds is not None else JWT_REFRESH_GRACE_PERIOD_SECONDS
            if token_exp + grace < now:
                return None  # Expired beyond allowed refresh grace window

        # Check token revocation
        if check_revocation and token_revocation_manager.is_revoked(token):
            return None  # Token revoked via logout

        return payload
    except Exception:
        return None


# ─── Token Revocation & Server-Side Session Invalidation ─────────────────────

import threading
from datetime import datetime, timedelta, timezone


def revocation_expiry(exp_ts: Optional[int]) -> datetime:
    """
    How long a revoked token must stay blacklisted: until it can no longer be used anywhere, i.e. its own
    expiry PLUS the refresh grace period (an expired token is still accepted by /auth/refresh inside that
    window, so purging the entry at `exp` would let a refreshed or logged-out token be replayed).
    """
    if exp_ts:
        base = datetime.fromtimestamp(int(exp_ts), tz=timezone.utc)
    else:
        base = datetime.now(timezone.utc) + timedelta(seconds=JWT_ACCESS_TOKEN_EXPIRE_SECONDS)
    return base + timedelta(seconds=JWT_REFRESH_GRACE_PERIOD_SECONDS)


def hash_token(token: str) -> str:
    """Returns SHA-256 hash of a JWT token string."""
    return hashlib.sha256(token.encode('utf-8')).hexdigest()


class TokenRevocationManager:
    """
    Manages in-memory and database-backed revoked token blacklist.
    Provides 0ms in-memory lookup for every incoming request.
    """
    def __init__(self):
        self._revoked_hashes = set()
        self._lock = threading.Lock()
        self._initialized = False

    def ensure_loaded(self):
        if self._initialized:
            return
        try:
            from database.database import SessionLocal
            db = SessionLocal()
            try:
                self.init_from_db(db)
            finally:
                db.close()
        except Exception:
            logger.exception("Failed to connect to database in ensure_loaded")

    def init_from_db(self, db):
        with self._lock:
            if self._initialized:
                return
            try:
                from modules.auth.revoked_token_model import RevokedToken
                now_utc = datetime.now(timezone.utc)
                # Purge expired entries
                db.query(RevokedToken).filter(RevokedToken.expires_at < now_utc).delete()
                db.commit()
                # Load active revoked tokens into fast memory set
                rows = db.query(RevokedToken.token_hash).filter(RevokedToken.expires_at >= now_utc).all()
                self._revoked_hashes = {r[0] for r in rows}
                self._initialized = True
            except Exception:
                logger.exception("Failed to initialize revoked tokens from database")

    def revoke(self, token: str, user_id: Optional[int], expires_at: datetime, db):
        t_hash = hash_token(token)
        with self._lock:
            self._revoked_hashes.add(t_hash)

        try:
            from modules.auth.revoked_token_model import RevokedToken
            rev = RevokedToken(
                token_hash=t_hash,
                user_id=user_id,
                revoked_at=datetime.now(timezone.utc),
                expires_at=expires_at,
            )
            db.add(rev)
            db.commit()
        except Exception:
            db.rollback()
            logger.exception("Failed to persist revoked token to database")
            raise

    def is_revoked(self, token: str) -> bool:
        self.ensure_loaded()
        t_hash = hash_token(token)
        with self._lock:
            return t_hash in self._revoked_hashes



token_revocation_manager = TokenRevocationManager()


