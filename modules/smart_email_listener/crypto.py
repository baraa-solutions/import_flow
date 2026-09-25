"""
ImportFlow ERP — Smart Email Listener Credential Encryption Helper
Provides symmetric encryption for stored mailbox and SMTP passwords at rest using Fernet.
Fully backward-compatible with legacy plaintext passwords.

Key history: builds before the DB-safety fix never had SECRET_KEY in os.environ in the frozen
build, so passwords saved on the laptop were encrypted with LEGACY_FALLBACK_SECRET. Decryption
therefore tries the current SECRET_KEY first and then the legacy key (MultiFernet); encryption
always uses the current key, so a password is moved to the current key the next time it is saved.
"""
import base64
import hashlib
import logging
import os
from typing import List

from cryptography.fernet import Fernet, InvalidToken, MultiFernet

logger = logging.getLogger("smart_email_listener.crypto")

# Hard-coded fallback used by older builds when SECRET_KEY was not in the environment.
# Kept for DECRYPTION ONLY; never used to encrypt new values.
LEGACY_FALLBACK_SECRET = "ImportFlow_ERP_Secret_Key_2026_Secure_RBAC"
ENC_PREFIX = "enc:"


def _fernet_for(secret: str) -> Fernet:
    key_32 = hashlib.sha256(secret.encode("utf-8")).digest()
    return Fernet(base64.urlsafe_b64encode(key_32))


def _current_secret() -> str:
    return os.getenv("SECRET_KEY", "") or LEGACY_FALLBACK_SECRET


def _get_fernet_cipher() -> Fernet:
    """Cipher for NEW encryptions: always the current SECRET_KEY."""
    return _fernet_for(_current_secret())


def _get_decrypt_cipher() -> MultiFernet:
    """Current key first, then the legacy fallback key."""
    secrets_in_order: List[str] = [_current_secret()]
    if LEGACY_FALLBACK_SECRET not in secrets_in_order:
        secrets_in_order.append(LEGACY_FALLBACK_SECRET)
    return MultiFernet([_fernet_for(s) for s in secrets_in_order])


def is_encrypted_with_current_key(stored_password: str) -> bool:
    if not stored_password or not stored_password.startswith(ENC_PREFIX):
        return False
    try:
        _get_fernet_cipher().decrypt(stored_password[len(ENC_PREFIX):].encode("utf-8"))
        return True
    except InvalidToken:
        return False


def encrypt_email_password(plain_password: str) -> str:
    """Encrypts a plaintext password with the current key. An already-encrypted value is
    re-encrypted with the current key when it was made with an older key."""
    if not plain_password:
        return ""
    if plain_password.startswith(ENC_PREFIX):
        return rotate_email_password(plain_password)
    token = _get_fernet_cipher().encrypt(plain_password.encode("utf-8")).decode("utf-8")
    return f"{ENC_PREFIX}{token}"


def rotate_email_password(stored_password: str) -> str:
    """Re-encrypt a stored ``enc:`` value with the current key. Undecryptable values are returned
    unchanged (never destroyed)."""
    if not stored_password or not stored_password.startswith(ENC_PREFIX):
        return stored_password
    try:
        rotated = _get_decrypt_cipher().rotate(stored_password[len(ENC_PREFIX):].encode("utf-8"))
        return f"{ENC_PREFIX}{rotated.decode('utf-8')}"
    except InvalidToken:
        logger.warning("Stored mailbox password could not be decrypted with any known key; left unchanged.")
        return stored_password


def decrypt_email_password(stored_password: str) -> str:
    """Decrypts a stored password. If stored as plaintext (legacy), returns as-is."""
    if not stored_password:
        return ""
    if not stored_password.startswith(ENC_PREFIX):
        return stored_password
    try:
        return _get_decrypt_cipher().decrypt(stored_password[len(ENC_PREFIX):].encode("utf-8")).decode("utf-8")
    except InvalidToken:
        logger.warning("Stored mailbox password could not be decrypted with any known key; "
                       "the mailbox password must be re-entered.")
        return stored_password
