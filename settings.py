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
from typing import Optional

from dotenv import dotenv_values, load_dotenv

from utils.db_safety import default_db_path, env_file_path, is_frozen_build

_logger = logging.getLogger("settings")

ENV_PATH = env_file_path()

# True only inside the PyInstaller executable. Deliberately not overridable by env (R7).
IS_PRODUCTION_BUILD: bool = is_frozen_build()


def env_file_defines(env_path: Path, key: str) -> bool:
    """True when .env has a ``KEY=`` line (False when the file is missing or unreadable)."""
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
    if not env_file_defines(env_path, "ALLOW_DEV_AUTH_BYPASS"):
        new_lines["ALLOW_DEV_AUTH_BYPASS"] = "false"
    _append_env_lines(env_path, new_lines)
    os.environ["SECRET_KEY"] = secret
    return secret


# Known first-login password of the admin seeded on an empty users table (CTO decision 2026-09-29).
# The seeded account has must_change_password=True, so it cannot use anything but the auth/me routes
# until the password is changed. Never written to .env.
DEFAULT_ADMIN_PASSWORD = "Admin@123"


def resolve_admin_initial_password(is_production_build: bool) -> str:
    """Password used to seed the first admin on an empty users table.

    Production build: always DEFAULT_ADMIN_PASSWORD. An old 2.1.x install left a random
    ADMIN_INITIAL_PASSWORD in its .env; a fresh DB next to it must still start with the documented default.
    Development: ADMIN_INITIAL_PASSWORD from env/.env when set, DEFAULT_ADMIN_PASSWORD otherwise."""
    if is_production_build:
        return DEFAULT_ADMIN_PASSWORD
    return os.getenv("ADMIN_INITIAL_PASSWORD", "") or DEFAULT_ADMIN_PASSWORD


def env_admin_initial_password(env_path: Path) -> Optional[str]:
    """The plaintext ADMIN_INITIAL_PASSWORD an old 2.1.x install wrote to .env.

    Used only by the leftover-line cleanup, which must compare against this value (not the seed default):
    an admin still using that generated password must keep the line, it is the only place it is written.
    Reads the .env file itself, falling back to the process environment ("" when neither has it).
    None when the .env line exists but cannot be read: callers then keep the line (fail closed)."""
    if env_file_defines(env_path, "ADMIN_INITIAL_PASSWORD"):
        try:
            value = dotenv_values(env_path).get("ADMIN_INITIAL_PASSWORD")
        except (OSError, UnicodeDecodeError) as exc:
            _logger.error("Could not read ADMIN_INITIAL_PASSWORD from %s: %s", env_path, exc)
            return None
        if value is not None:
            return value
    return os.getenv("ADMIN_INITIAL_PASSWORD", "")


def remove_env_key(env_path: Path, key: str) -> bool:
    """Remove every ``KEY=`` line from .env, keeping all other lines. Returns True if a line was removed."""
    if not env_file_defines(env_path, key):
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
DATABASE_PATH = os.getenv("DATABASE_PATH", str(default_db_path()))

ADMIN_INITIAL_PASSWORD = resolve_admin_initial_password(IS_PRODUCTION_BUILD)

# Authentication & Session Lifetime (7 days for Desktop ERP, 14 days refresh grace period)
JWT_ACCESS_TOKEN_EXPIRE_SECONDS = int(os.getenv("JWT_ACCESS_TOKEN_EXPIRE_SECONDS", str(86400 * 7)))
JWT_REFRESH_GRACE_PERIOD_SECONDS = int(os.getenv("JWT_REFRESH_GRACE_PERIOD_SECONDS", str(86400 * 14)))

# Trusted reverse proxy IPs (for X-Forwarded-For evaluation in login limiter)
raw_trusted = os.getenv("TRUSTED_PROXY_IPS", "")
TRUSTED_PROXY_IPS: list[str] = [ip.strip() for ip in raw_trusted.split(",") if ip.strip()]

