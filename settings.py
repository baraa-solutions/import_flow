"""
ImportFlow ERP — Central Configuration & Settings
Loads environment variables from .env if present.

The .env file lives in ``utils.db_safety.app_base_dir()``: next to backend.exe in the frozen
build (never the PyInstaller temp dir), the repo root otherwise. Secrets generated here are
appended to that file once, so they survive restarts.
"""
import logging
import os
import secrets
from pathlib import Path

from dotenv import load_dotenv

from utils.db_safety import app_base_dir, is_frozen_build

_logger = logging.getLogger("settings")

BASE_DIR = app_base_dir()
ENV_PATH = BASE_DIR / ".env"

# True only inside the PyInstaller executable. Deliberately not overridable by env (R7).
IS_PRODUCTION_BUILD: bool = is_frozen_build()


def _env_file_defines(env_path: Path, key: str) -> bool:
    if not env_path.exists():
        return False
    try:
        with open(env_path, "r", encoding="utf-8") as fh:
            return any(line.strip().startswith(f"{key}=") for line in fh)
    except OSError:
        return False


def _append_env_lines(env_path: Path, lines: dict) -> bool:
    """Append KEY=value lines to .env. Returns False (and logs loudly) when the file is not writable."""
    try:
        env_path.parent.mkdir(parents=True, exist_ok=True)
        with open(env_path, "a", encoding="utf-8") as fh:
            fh.write("\n" + "".join(f"{k}={v}\n" for k, v in lines.items()))
        return True
    except OSError as exc:
        _logger.error(
            "Could not persist %s to %s (%s); the value is valid for this process only.",
            ", ".join(lines), env_path, exc,
        )
        return False


def load_or_create_secret_key(env_path: Path) -> str:
    """Return SECRET_KEY from the environment/.env, generating and persisting one on first run."""
    secret = os.getenv("SECRET_KEY", "")
    if secret and len(secret) >= 32:
        return secret
    secret = secrets.token_hex(32)
    new_lines = {"SECRET_KEY": secret}
    if not _env_file_defines(env_path, "ALLOW_DEV_AUTH_BYPASS"):
        new_lines["ALLOW_DEV_AUTH_BYPASS"] = "false"
    _append_env_lines(env_path, new_lines)
    os.environ["SECRET_KEY"] = secret
    return secret


def load_or_create_admin_password(env_path: Path) -> str:
    """Initial admin password, kept in memory only. It is written to .env only when it is actually
    used to seed the first admin user (persist_admin_initial_password), and removed from .env in the
    frozen build once the admin has changed it (remove_env_key)."""
    password = os.getenv("ADMIN_INITIAL_PASSWORD", "")
    if password:
        return password
    password = secrets.token_urlsafe(16) + "A1!"
    os.environ["ADMIN_INITIAL_PASSWORD"] = password
    return password


def persist_admin_initial_password(env_path: Path, password: str) -> bool:
    """Record the seeded admin password in .env (once) so the operator can read it for first login."""
    if _env_file_defines(env_path, "ADMIN_INITIAL_PASSWORD"):
        return True
    return _append_env_lines(env_path, {"ADMIN_INITIAL_PASSWORD": password})


def remove_env_key(env_path: Path, key: str) -> bool:
    """Remove every ``KEY=`` line from .env, keeping all other lines. Returns True if a line was removed."""
    if not _env_file_defines(env_path, key):
        return False
    try:
        with open(env_path, "r", encoding="utf-8") as fh:
            lines = fh.readlines()
        kept = [line for line in lines if not line.strip().startswith(f"{key}=")]
        tmp_path = env_path.with_name(env_path.name + ".tmp")
        with open(tmp_path, "w", encoding="utf-8") as fh:
            fh.writelines(kept)
        tmp_path.replace(env_path)
        return True
    except OSError as exc:
        _logger.error("Could not remove %s from %s: %s", key, env_path, exc)
        return False


def resolve_dev_auth_bypass(is_production_build: bool) -> bool:
    """ALLOW_DEV_AUTH_BYPASS from env/.env, but never in the production build (the laptop's .env is
    user-writable, so a stray ALLOW_DEV_AUTH_BYPASS=true there must not disable authentication)."""
    requested = os.getenv("ALLOW_DEV_AUTH_BYPASS", "false").lower() in ("true", "1")
    if requested and is_production_build:
        _logger.critical(
            "ALLOW_DEV_AUTH_BYPASS is set in the production build and has been IGNORED: "
            "authentication stays enforced. Remove it from %s.", ENV_PATH,
        )
        return False
    return requested


if ENV_PATH.exists():
    load_dotenv(ENV_PATH)

SECRET_KEY: str = load_or_create_secret_key(ENV_PATH)

# SECURITY: Strictly False in production to enforce JWT Bearer tokens on all endpoints.
# Forced False in the frozen build whatever .env says.
ALLOW_DEV_AUTH_BYPASS = resolve_dev_auth_bypass(IS_PRODUCTION_BUILD)
DEBUG = os.getenv("DEBUG", "false").lower() in ("true", "1")
# Swagger UI / ReDoc / openapi.json are disabled unless explicitly enabled (they expose the route map).
ENABLE_API_DOCS = os.getenv("ENABLE_API_DOCS", "false").lower() in ("true", "1")
DATABASE_PATH = os.getenv("DATABASE_PATH", str(BASE_DIR / "sorour_logistics.db"))

ADMIN_INITIAL_PASSWORD = load_or_create_admin_password(ENV_PATH)

# Authentication & Session Lifetime (7 days for Desktop ERP, 14 days refresh grace period)
JWT_ACCESS_TOKEN_EXPIRE_SECONDS = int(os.getenv("JWT_ACCESS_TOKEN_EXPIRE_SECONDS", str(86400 * 7)))
JWT_REFRESH_GRACE_PERIOD_SECONDS = int(os.getenv("JWT_REFRESH_GRACE_PERIOD_SECONDS", str(86400 * 14)))
