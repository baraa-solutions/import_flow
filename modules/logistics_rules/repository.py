"""
Database Repository for Logistics Operational Rules
"""

from datetime import date, datetime, timezone
from typing import List, Optional, Tuple
from sqlalchemy import desc, select, func
from sqlalchemy.orm import Session

from modules.logistics_rules.model import LogisticsOperationalRule


class LogisticsRulesRepository:
    def __init__(self, db: Session):
        self.db = db

    def list_rules(
        self,
        scope_type: Optional[str] = None,
        verification_status: Optional[str] = None,
        is_latest: bool = True,
        skip: int = 0,
        limit: int = 100,
    ) -> Tuple[List[LogisticsOperationalRule], int]:
        query = select(LogisticsOperationalRule).where(
            LogisticsOperationalRule.is_active.is_(True)
        )
        if is_latest:
            query = query.where(LogisticsOperationalRule.is_latest.is_(True))
        if scope_type:
            query = query.where(LogisticsOperationalRule.scope_type == scope_type)
        if verification_status:
            query = query.where(
                LogisticsOperationalRule.verification_status == verification_status
            )

        total_stmt = select(func.count()).select_from(query.subquery())
        total = self.db.execute(total_stmt).scalar_one()

        items_stmt = (
            query.order_by(
                LogisticsOperationalRule.rule_key,
                desc(LogisticsOperationalRule.version_id),
            )
            .offset(skip)
            .limit(limit)
        )
        items = list(self.db.execute(items_stmt).scalars().all())
        return items, total

    def get_rule_by_id(self, rule_id: int) -> Optional[LogisticsOperationalRule]:
        return self.db.execute(
            select(LogisticsOperationalRule).where(
                LogisticsOperationalRule.id == rule_id,
                LogisticsOperationalRule.is_active.is_(True),
            )
        ).scalar_one_or_none()

    def get_rule_by_key(
        self,
        rule_key: str,
        scope_type: str = "GLOBAL",
        scope_id: Optional[int] = None,
        is_latest: bool = True,
    ) -> Optional[LogisticsOperationalRule]:
        query = select(LogisticsOperationalRule).where(
            LogisticsOperationalRule.rule_key == rule_key,
            LogisticsOperationalRule.scope_type == scope_type,
            LogisticsOperationalRule.is_active.is_(True),
        )
        if scope_id is not None:
            query = query.where(LogisticsOperationalRule.scope_id == scope_id)
        else:
            query = query.where(LogisticsOperationalRule.scope_id.is_(None))

        if is_latest:
            query = query.where(LogisticsOperationalRule.is_latest.is_(True))

        return self.db.execute(query.order_by(desc(LogisticsOperationalRule.version_id))).scalars().first()

    def create_rule(
        self,
        data: dict,
        created_by_user_id: Optional[int] = None,
    ) -> LogisticsOperationalRule:
        rule = LogisticsOperationalRule(
            **data,
            version_id=1,
            is_latest=True,
            is_active=True,
            created_by_user_id=created_by_user_id,
        )
        self.db.add(rule)
        self.db.commit()
        self.db.refresh(rule)
        return rule

    def update_rule_version(
        self,
        old_rule: LogisticsOperationalRule,
        update_data: dict,
        updated_by_user_id: Optional[int] = None,
    ) -> LogisticsOperationalRule:
        """
        Creates a new immutable version of the rule and archives the prior version.
        """
        now = datetime.now(timezone.utc)
        today = date.today()

        # Archive old rule
        old_rule.is_latest = False
        if not old_rule.effective_to or old_rule.effective_to > today:
            old_rule.effective_to = today
        old_rule.updated_at = now

        # Build new rule data from old merged with updates
        new_data = {
            "rule_key": old_rule.rule_key,
            "rule_name_ar": update_data.get("rule_name_ar", old_rule.rule_name_ar),
            "rule_name_en": update_data.get("rule_name_en", old_rule.rule_name_en),
            "scope_type": update_data.get("scope_type", old_rule.scope_type),
            "scope_id": update_data.get("scope_id", old_rule.scope_id),
            "conservative_default": update_data.get(
                "conservative_default", old_rule.conservative_default
            ),
            "verified_value": update_data.get(
                "verified_value", old_rule.verified_value
            ),
            "value_unit": update_data.get("value_unit", old_rule.value_unit),
            "enforcement_level": update_data.get(
                "enforcement_level", old_rule.enforcement_level
            ),
            "verification_status": (
                "UNVERIFIED"
                if "verified_value" in update_data and update_data["verified_value"] != old_rule.verified_value
                else old_rule.verification_status
            ),
            "verified_by_user_id": (
                None
                if "verified_value" in update_data and update_data["verified_value"] != old_rule.verified_value
                else old_rule.verified_by_user_id
            ),
            "verified_on": (
                None
                if "verified_value" in update_data and update_data["verified_value"] != old_rule.verified_value
                else old_rule.verified_on
            ),
            "evidence_ref": update_data.get("evidence_ref", old_rule.evidence_ref),
            "source_ref": update_data.get("source_ref", old_rule.source_ref),
            "effective_from": update_data.get("effective_from", today),
            "effective_to": update_data.get("effective_to", None),
            "review_due_on": update_data.get("review_due_on", old_rule.review_due_on),
            "version_id": old_rule.version_id + 1,
            "is_latest": True,
            "is_active": True,
            "created_by_user_id": updated_by_user_id,
        }

        new_rule = LogisticsOperationalRule(**new_data)
        self.db.add(new_rule)
        self.db.commit()
        self.db.refresh(new_rule)
        return new_rule

    def verify_rule(
        self,
        rule: LogisticsOperationalRule,
        verified_value: str,
        verified_by_user_id: int,
        evidence_ref: Optional[str] = None,
        source_ref: Optional[str] = None,
        review_due_on: Optional[date] = None,
    ) -> LogisticsOperationalRule:
        rule.verified_value = verified_value
        rule.verification_status = "VERIFIED"
        rule.verified_by_user_id = verified_by_user_id
        rule.verified_on = datetime.now(timezone.utc)
        if evidence_ref:
            rule.evidence_ref = evidence_ref
        if source_ref:
            rule.source_ref = source_ref
        if review_due_on:
            rule.review_due_on = review_due_on
        rule.updated_at = datetime.now(timezone.utc)

        self.db.commit()
        self.db.refresh(rule)
        return rule

    def get_unverified_rules_for_export(self) -> List[LogisticsOperationalRule]:
        stmt = (
            select(LogisticsOperationalRule)
            .where(
                LogisticsOperationalRule.is_latest.is_(True),
                LogisticsOperationalRule.is_active.is_(True),
                LogisticsOperationalRule.verification_status != "VERIFIED",
            )
            .order_by(LogisticsOperationalRule.rule_key)
        )
        return list(self.db.execute(stmt).scalars().all())
