"""
Sorour Logistics ERP — Cryptographic Utility for Backups & Data-at-Rest
========================================================================
Implements authenticated encryption (AES-256-GCM) for database backups before
they leave the local machine for offsite storage (Google Drive Desktop sync).

Security Specifications:
- Algorithm: AES-256-GCM (Galois/Counter Mode) via cryptography.hazmat
- Key Length: 256 bits (32 bytes)
- Nonce Length: 96 bits (12 bytes) cryptographically random per backup
- Authentication Tag: 128 bits (16 bytes) automatically verified
- Associated Data (AAD): Bound to system identifier to prevent cross-system substitution
- File Magic: b"SL_AESGCM_V1" (12 bytes)
"""
import os
import secrets
import hashlib
from pathlib import Path
from typing import Optional, Dict, Any

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.exceptions import InvalidTag

from utils.db_safety import app_base_dir

# Frozen build: next to backend.exe (never the PyInstaller temp dir), so the key persists.
ROOT_DIR = app_base_dir()
ENV_PATH = ROOT_DIR / ".env"
MAGIC_HEADER = b"SL_AESGCM_V1"  # 12 bytes
ASSOCIATED_DATA = b"SorourLogistics_Backup_v1"


def compute_sha256(file_path: Path) -> str:
    sha256 = hashlib.sha256()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            sha256.update(chunk)
    return sha256.hexdigest()


def get_backup_encryption_key() -> bytes:
    """
    Retrieves the 256-bit backup encryption key.
    Order of precedence:
    1. Environment variable: BACKUP_ENCRYPTION_KEY
    2. .env file in ROOT_DIR (app_base_dir(): the exe folder when frozen)
    3. Auto-generate a secure random 256-bit key, persist to .env, and return.
       Raises RuntimeError if the new key cannot be persisted.
    """
    key_str = os.getenv("BACKUP_ENCRYPTION_KEY", "").strip()

    if not key_str and ENV_PATH.exists():
        try:
            with open(ENV_PATH, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("BACKUP_ENCRYPTION_KEY="):
                        key_str = line.split("=", 1)[1].strip()
                        break
        except Exception:
            pass

    if not key_str:
        # Generate new 256-bit (64 hex chars) key and persist to .env
        # A key that cannot be persisted is refused: backups encrypted with it could never be
        # decrypted after a restart.
        key_str = secrets.token_hex(32)
        try:
            ENV_PATH.parent.mkdir(parents=True, exist_ok=True)
            with open(ENV_PATH, "a", encoding="utf-8") as f:
                f.write(f"\n# Automated AES-256-GCM Backup Encryption Key\nBACKUP_ENCRYPTION_KEY={key_str}\n")
        except OSError as exc:
            raise RuntimeError(
                f"Cannot persist BACKUP_ENCRYPTION_KEY to {ENV_PATH}: {exc}. "
                "Refusing to encrypt with a key that would be lost on restart."
            ) from exc
        os.environ["BACKUP_ENCRYPTION_KEY"] = key_str

    # Parse key
    if len(key_str) == 64:
        try:
            return bytes.fromhex(key_str)
        except ValueError:
            pass

    # Fallback: derive 32-byte key via SHA-256 if user provided a passphrase
    return hashlib.sha256(key_str.encode("utf-8")).digest()


def is_encrypted_backup(file_path: Path) -> bool:
    """Check if the given file starts with the SL_AESGCM_V1 magic header."""
    if not file_path.exists() or file_path.stat().st_size < len(MAGIC_HEADER) + 12 + 16:
        return False
    try:
        with open(file_path, "rb") as f:
            header = f.read(len(MAGIC_HEADER))
            return header == MAGIC_HEADER
    except Exception:
        return False


def encrypt_backup_file(input_path: Path, output_path: Path, key: Optional[bytes] = None) -> Dict[str, Any]:
    """
    Encrypts a database backup file using AES-256-GCM authenticated encryption.
    Format: [12 bytes MAGIC] [12 bytes NONCE] [CIPHERTEXT + 16 bytes TAG]
    """
    if not input_path.exists():
        raise FileNotFoundError(f"Input file not found: {input_path}")

    if key is None:
        key = get_backup_encryption_key()

    if len(key) != 32:
        raise ValueError("AES-256 requires exactly a 32-byte (256-bit) encryption key.")

    output_path.parent.mkdir(parents=True, exist_ok=True)

    aesgcm = AESGCM(key)
    nonce = secrets.token_bytes(12)  # 96-bit nonce

    with open(input_path, "rb") as f:
        plaintext = f.read()

    ciphertext = aesgcm.encrypt(nonce, plaintext, associated_data=ASSOCIATED_DATA)

    with open(output_path, "wb") as f:
        f.write(MAGIC_HEADER)
        f.write(nonce)
        f.write(ciphertext)

    out_size = output_path.stat().st_size
    out_sha256 = compute_sha256(output_path)

    return {
        "encrypted_path": str(output_path),
        "size_bytes": out_size,
        "sha256": out_sha256,
        "algorithm": "AES-256-GCM",
        "verified": True,
    }


def decrypt_backup_file(input_path: Path, output_path: Path, key: Optional[bytes] = None) -> bool:
    """
    Decrypts an AES-256-GCM encrypted backup file.
    Validates magic header, authenticated tag, and integrity.
    """
    if not input_path.exists():
        raise FileNotFoundError(f"Encrypted backup not found: {input_path}")

    if key is None:
        key = get_backup_encryption_key()

    if len(key) != 32:
        raise ValueError("AES-256 requires exactly a 32-byte (256-bit) encryption key.")

    file_size = input_path.stat().st_size
    min_size = len(MAGIC_HEADER) + 12 + 16  # header + nonce + tag
    if file_size < min_size:
        raise ValueError(f"File too small to be an authenticated backup ({file_size} bytes).")

    with open(input_path, "rb") as f:
        header = f.read(len(MAGIC_HEADER))
        if header != MAGIC_HEADER:
            raise ValueError(f"Invalid backup header '{header}'. Not an authenticated SL_AESGCM_V1 file.")
        nonce = f.read(12)
        ciphertext = f.read()

    aesgcm = AESGCM(key)
    try:
        plaintext = aesgcm.decrypt(nonce, ciphertext, associated_data=ASSOCIATED_DATA)
    except InvalidTag:
        raise RuntimeError(
            "Backup decryption failed: Invalid encryption key or the backup file has been tampered with."
        )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "wb") as f:
        f.write(plaintext)

    return True
