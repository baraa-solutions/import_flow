"""
Business Validators for Logistics Operational Rules
"""

from datetime import date
from typing import Optional


def validate_no_self_verify(rule, verified_by_user_id: Optional[int]) -> None:
    """
    Enforces Maker-Checker principle:
    The user who created or proposed the rule cannot be the one who verifies it.
    """
    if (
        rule.created_by_user_id is not None
        and verified_by_user_id is not None
        and rule.created_by_user_id == verified_by_user_id
    ):
        raise ValueError(
            "Maker-Checker violation: A rule cannot be verified by the user who created it."
        )


def validate_effective_dates(
    effective_from: Optional[date], effective_to: Optional[date]
) -> None:
    """
    Validates that effective_to is not earlier than effective_from.
    """
    if effective_from and effective_to and effective_to < effective_from:
        raise ValueError(
            f"Invalid date range: effective_to ({effective_to}) cannot be earlier than effective_from ({effective_from})."
        )


def validate_scope(scope_type: str, scope_id: Optional[int]) -> None:
    """
    Validates that non-global rules specify an entity target.
    """
    if scope_type != "GLOBAL" and scope_id is None:
        raise ValueError(f"scope_id is required when scope_type is '{scope_type}'.")
