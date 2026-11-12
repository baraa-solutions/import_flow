"""
Notification audience ↔ RBAC role mapping.

Producers address notifications with business audience names (``target_role``) that are not always RBAC role
codes: LOGISTICS_OFFICER, COORDINATOR, CUSTOMS_BROKER, and the legacy MANAGER / OPERATOR strings. This module is
the single place that maps them to the role codes of ROLES_CONFIG, so a LOGISTICS_OPERATOR user is recognised as
the audience of a LOGISTICS_OFFICER notification.
"""
from typing import Dict, FrozenSet, Iterable, Set

AUDIENCE_ALL = "ALL"

# Audience name written by producers -> RBAC role code (modules/auth/seed_rbac.ROLES_CONFIG).
# Names that already are role codes (ADMIN, GENERAL_MANAGER, LOGISTICS_OPERATOR, CUSTOMS_OFFICER, FINANCE_OFFICER,
# AUDITOR_VIEWER) map to themselves and need no entry.
AUDIENCE_ROLE_ALIASES: Dict[str, str] = {
    "LOGISTICS_OFFICER": "LOGISTICS_OPERATOR",
    "COORDINATOR": "LOGISTICS_OPERATOR",
    "OPERATOR": "LOGISTICS_OPERATOR",  # legacy users.role value
    "CUSTOMS_BROKER": "CUSTOMS_OFFICER",
    "MANAGER": "GENERAL_MANAGER",  # legacy users.role value
}


def canonical_role(name: str) -> str:
    """RBAC role code for an audience name or role string (upper-cased; unknown names map to themselves)."""
    key = (name or "").strip().upper()
    return AUDIENCE_ROLE_ALIASES.get(key, key)


def canonical_roles(names: Iterable[str]) -> Set[str]:
    return {canonical_role(n) for n in names if n and n.strip()}


def audience_names_for_roles(role_codes: Iterable[str]) -> FrozenSet[str]:
    """Every raw target_role value addressed to one of ``role_codes``: ALL, the codes themselves and their aliases."""
    codes = canonical_roles(role_codes)
    aliases = {alias for alias, code in AUDIENCE_ROLE_ALIASES.items() if code in codes}
    return frozenset({AUDIENCE_ALL} | codes | aliases)


def is_addressed_to(target_role: str, role_codes: Iterable[str]) -> bool:
    """True when a notification with ``target_role`` is meant for a user holding ``role_codes``."""
    target = canonical_role(target_role or AUDIENCE_ALL)
    return target == AUDIENCE_ALL or target in canonical_roles(role_codes)
