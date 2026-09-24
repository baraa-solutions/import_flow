"""
ImportFlow ERP — Central Configuration & Settings
Loads environment variables from .env if present.
"""
import os
from pathlib import Path
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent
ENV_PATH = BASE_DIR / ".env"
if ENV_PATH.exists():
    load_dotenv(ENV_PATH)

_secret = os.getenv("SECRET_KEY", "")
if not _secret or len(_secret) < 32:
    import secrets
    _secret = secrets.token_hex(32)
    # Persist the generated secret to .env if possible
    try:
        with open(ENV_PATH, "a", encoding="utf-8") as f:
            f.write(f"\nSECRET_KEY={_secret}\nALLOW_DEV_AUTH_BYPASS=false\n")
    except Exception:
        pass

SECRET_KEY: str = _secret

# SECURITY: Strictly False in production to enforce JWT Bearer tokens on all endpoints.
ALLOW_DEV_AUTH_BYPASS = os.getenv("ALLOW_DEV_AUTH_BYPASS", "false").lower() in ("true", "1")
DEBUG = os.getenv("DEBUG", "false").lower() in ("true", "1")
# Swagger UI / ReDoc / openapi.json are disabled unless explicitly enabled (they expose the route map).
ENABLE_API_DOCS = os.getenv("ENABLE_API_DOCS", "false").lower() in ("true", "1")
DATABASE_PATH = os.getenv("DATABASE_PATH", str(BASE_DIR / "sorour_logistics.db"))
_admin_pass = os.getenv("ADMIN_INITIAL_PASSWORD", "")
if not _admin_pass:
    import secrets
    _admin_pass = secrets.token_urlsafe(16) + "A1!"
    try:
        with open(ENV_PATH, "a", encoding="utf-8") as f:
            f.write(f"\nADMIN_INITIAL_PASSWORD={_admin_pass}\n")
    except Exception:
        pass

ADMIN_INITIAL_PASSWORD = _admin_pass

# Authentication & Session Lifetime (7 days for Desktop ERP, 14 days refresh grace period)
JWT_ACCESS_TOKEN_EXPIRE_SECONDS = int(os.getenv("JWT_ACCESS_TOKEN_EXPIRE_SECONDS", str(86400 * 7)))
JWT_REFRESH_GRACE_PERIOD_SECONDS = int(os.getenv("JWT_REFRESH_GRACE_PERIOD_SECONDS", str(86400 * 14)))
