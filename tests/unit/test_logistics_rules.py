"""
Unit Tests for Logistics Operational Rules & Safety Guards
"""

from datetime import date, datetime, timedelta, timezone
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.logistics_rules.model import LogisticsOperationalRule
from modules.logistics_rules.repository import LogisticsRulesRepository
from modules.logistics_rules.schemas import (
    EnforcementLevel,
    LogisticsRuleCreate,
    LogisticsRuleUpdate,
    LogisticsRuleVerify,
    ScopeType,
    ValueUnit,
)
from modules.logistics_rules.seed_rules import INITIAL_RULES, seed_logistics_rules
from modules.logistics_rules.service import LogisticsRulesService
from modules.logistics_rules.validators import validate_no_self_verify


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    try:
        yield session
    finally:
        session.close()


def test_safety_guard_blocks_blocking_when_unverified(db_session):
    """
    Rule configured with BLOCKING but verification_status is UNVERIFIED
    must be downgraded to WARNING and trigger the safety guard flag.
    """
    rule = LogisticsOperationalRule(
        rule_key="TEST_RULE_1",
        rule_name_ar="قاعدة تجريبية 1",
        rule_name_en="Test Rule 1",
        scope_type="GLOBAL",
        value_unit="DAYS",
        enforcement_level="BLOCKING",
        verification_status="UNVERIFIED",
        conservative_default="3",
        verified_value=None,
    )
    db_session.add(rule)
    db_session.commit()

    effective_level, triggered, reason = LogisticsRulesService.apply_safety_guard(rule)
    assert effective_level == "WARNING"
    assert triggered is True
    assert "not officially verified" in reason


def test_safety_guard_keeps_warning_when_unverified(db_session):
    """
    Rule configured with WARNING and UNVERIFIED remains WARNING without being flagged as degraded.
    """
    rule = LogisticsOperationalRule(
        rule_key="TEST_RULE_2",
        rule_name_ar="قاعدة تجريبية 2",
        rule_name_en="Test Rule 2",
        scope_type="GLOBAL",
        value_unit="DAYS",
        enforcement_level="WARNING",
        verification_status="UNVERIFIED",
        conservative_default="3",
    )
    db_session.add(rule)
    db_session.commit()

    effective_level, triggered, reason = LogisticsRulesService.apply_safety_guard(rule)
    assert effective_level == "WARNING"
    assert triggered is False
    assert reason is None


def test_safety_guard_allows_blocking_when_verified(db_session):
    """
    Rule configured with BLOCKING and officially VERIFIED with a non-null verified value
    and valid dates maintains BLOCKING enforcement.
    """
    rule = LogisticsOperationalRule(
        rule_key="TEST_RULE_3",
        rule_name_ar="قاعدة موثقة",
        rule_name_en="Verified Rule",
        scope_type="GLOBAL",
        value_unit="DAYS",
        enforcement_level="BLOCKING",
        verification_status="VERIFIED",
        verified_value="14",
        effective_from=date.today() - timedelta(days=5),
        effective_to=date.today() + timedelta(days=100),
        review_due_on=date.today() + timedelta(days=50),
    )
    db_session.add(rule)
    db_session.commit()

    effective_level, triggered, reason = LogisticsRulesService.apply_safety_guard(rule)
    assert effective_level == "BLOCKING"
    assert triggered is False
    assert reason is None


def test_safety_guard_triggers_when_verified_value_null(db_session):
    """
    Even if status is VERIFIED, if verified_value is NULL or blank,
    BLOCKING must degrade to WARNING.
    """
    rule = LogisticsOperationalRule(
        rule_key="TEST_RULE_4",
        rule_name_ar="قاعدة بدون قيمة",
        rule_name_en="Rule without value",
        scope_type="GLOBAL",
        value_unit="DAYS",
        enforcement_level="BLOCKING",
        verification_status="VERIFIED",
        verified_value=None,
    )
    db_session.add(rule)
    db_session.commit()

    effective_level, triggered, reason = LogisticsRulesService.apply_safety_guard(rule)
    assert effective_level == "WARNING"
    assert triggered is True
    assert "verified_value is NULL" in reason


def test_safety_guard_triggers_when_expired(db_session):
    """
    A verified rule whose effective_to has passed degrades BLOCKING to WARNING.
    """
    rule = LogisticsOperationalRule(
        rule_key="TEST_RULE_5",
        rule_name_ar="قاعدة منتهية",
        rule_name_en="Expired Rule",
        scope_type="GLOBAL",
        value_unit="DAYS",
        enforcement_level="BLOCKING",
        verification_status="VERIFIED",
        verified_value="14",
        effective_from=date.today() - timedelta(days=60),
        effective_to=date.today() - timedelta(days=1),  # Expired yesterday
    )
    db_session.add(rule)
    db_session.commit()

    effective_level, triggered, reason = LogisticsRulesService.apply_safety_guard(rule)
    assert effective_level == "WARNING"
    assert triggered is True
    assert "expired on" in reason


def test_safety_guard_triggers_when_review_overdue(db_session):
    """
    A verified rule whose review_due_on has lapsed degrades BLOCKING to WARNING.
    """
    rule = LogisticsOperationalRule(
        rule_key="TEST_RULE_6",
        rule_name_ar="قاعدة متأخرة المراجعة",
        rule_name_en="Review Overdue Rule",
        scope_type="GLOBAL",
        value_unit="PERCENTAGE",
        enforcement_level="BLOCKING",
        verification_status="VERIFIED",
        verified_value="30",
        review_due_on=date.today() - timedelta(days=2),  # Due 2 days ago
    )
    db_session.add(rule)
    db_session.commit()

    effective_level, triggered, reason = LogisticsRulesService.apply_safety_guard(rule)
    assert effective_level == "WARNING"
    assert triggered is True
    assert "overdue" in reason


def test_maker_checker_rejects_self_verify(db_session):
    """
    Maker-Checker enforcement:
    A user cannot verify a rule they created.
    """
    rule = LogisticsOperationalRule(
        rule_key="TEST_MC",
        rule_name_ar="قاعدة صانع-مدقق",
        rule_name_en="Maker Checker Rule",
        scope_type="GLOBAL",
        value_unit="DAYS",
        created_by_user_id=10,
    )

    # Verifying by user 10 (same user) must raise ValueError
    with pytest.raises(ValueError, match="Maker-Checker violation"):
        validate_no_self_verify(rule, verified_by_user_id=10)

    # Verifying by user 20 (different user) must succeed
    validate_no_self_verify(rule, verified_by_user_id=20)


def test_create_rule_version_increments(db_session):
    """
    Updating a rule must archive the existing version (is_latest=False)
    and create a new active version with version_id=2 (is_latest=True).
    """
    service = LogisticsRulesService(db_session)
    create_dto = LogisticsRuleCreate(
        rule_key="DEMURRAGE_FREE_DAYS_TEST",
        rule_name_ar="أيام سماح الغرامات",
        rule_name_en="Demurrage Free Days",
        scope_type=ScopeType.GLOBAL,
        value_unit=ValueUnit.DAYS,
        enforcement_level=EnforcementLevel.WARNING,
        conservative_default="14",
    )

    created = service.create_rule(create_dto, current_user_id=1)
    assert created.version_id == 1
    assert created.is_latest is True

    update_dto = LogisticsRuleUpdate(
        conservative_default="21",
    )
    updated = service.update_rule(
        rule_id=created.id, payload=update_dto, current_user_id=2
    )

    assert updated.version_id == 2
    assert updated.is_latest is True
    assert updated.conservative_default == "21"

    # Verify old version in DB is closed
    old_version = (
        db_session.query(LogisticsOperationalRule)
        .filter(
            LogisticsOperationalRule.rule_key == "DEMURRAGE_FREE_DAYS_TEST",
            LogisticsOperationalRule.version_id == 1,
        )
        .first()
    )
    assert old_version.is_latest is False
    assert old_version.effective_to is not None


def test_seed_logistics_rules_idempotent(db_session):
    """
    Tests that seeding rules inserts all 12 initial rules and is idempotent on repeat calls.
    """
    count1 = seed_logistics_rules(db_session)
    assert count1 == len(INITIAL_RULES)
    assert count1 == 12

    # Second run should insert 0 new rules
    count2 = seed_logistics_rules(db_session)
    assert count2 == 0
