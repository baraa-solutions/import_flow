"""Backend listen-port resolution shared by `main.py` (`__main__`) and `backend_runner.py`.

The installed production backend listens on 127.0.0.1:28080. A developer running from source on the
same machine sets `PORT` (for example `set PORT=28090`) so the two never collide. An invalid `PORT`
fails fast instead of silently falling back to 28080, because that fallback is exactly the collision
this setting prevents.
"""
import os
from typing import Mapping, Optional

PORT_ENV_VAR = "PORT"
DEFAULT_PORT = 28080
MIN_PORT = 1
MAX_PORT = 65535


class InvalidPortError(ValueError):
    """Raised when the PORT environment variable holds something other than an integer 1..65535."""


def resolve_port(environ: Optional[Mapping[str, str]] = None) -> int:
    """Return the port from `PORT`, or 28080 when it is unset, empty or whitespace."""
    env = os.environ if environ is None else environ
    raw = env.get(PORT_ENV_VAR) or ""
    value = raw.strip()
    if not value:
        return DEFAULT_PORT
    prefix = f"Invalid {PORT_ENV_VAR} environment variable value {raw!r}: "
    # int() accepts "+80", "8_0" and full-width digits: require plain ASCII digits only.
    if not (value.isascii() and value.isdigit()):
        raise InvalidPortError(
            f"{prefix}expected an integer between {MIN_PORT} and {MAX_PORT} (default {DEFAULT_PORT} when unset)."
        )
    port = int(value)
    if not MIN_PORT <= port <= MAX_PORT:
        raise InvalidPortError(f"{prefix}port must be between {MIN_PORT} and {MAX_PORT}.")
    return port
