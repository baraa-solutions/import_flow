"""
Business Service for Logistics Operational Rules
"""

from datetime import date, datetime, timezone
from typing import Any, Dict, List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.logistics_rules.model import LogisticsOperationalRule
from modules.logistics_rules.repository import LogisticsRulesRepository
from modules.logistics_rules.schemas import (
    EffectiveRuleOut,
    FieldQuestionOut,
    LogisticsRuleCreate,
    LogisticsRuleOut,
    LogisticsRuleUpdate,
    LogisticsRuleVerify,
)
from modules.logistics_rules.validators import (
    validate_effective_dates,
    validate_no_self_verify,
    validate_scope,
)


class LogisticsRulesService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = LogisticsRulesRepository(db)

    @staticmethod
    def apply_safety_guard(
        rule: LogisticsOperationalRule,
    ) -> Tuple[str, bool, Optional[str]]:
        """
        Safety Guard:
        Downgrades enforcement_level from BLOCKING to WARNING if any of the following apply:
        1. verification_status != 'VERIFIED'
        2. verified_value IS NULL or empty
        3. effective_to is expired (< today)
        4. review_due_on has lapsed (< today)
        """
        raw_level = rule.enforcement_level or "WARNING"
        if raw_level != "BLOCKING":
            return raw_level, False, None

        today = date.today()

        if rule.verification_status != "VERIFIED":
            return (
                "WARNING",
                True,
                f"Rule is not officially verified (status: {rule.verification_status}). Degraded to WARNING.",
            )

        if not rule.verified_value or not str(rule.verified_value).strip():
            return (
                "WARNING",
                True,
                "Rule has no verified value established (verified_value is NULL). Degraded to WARNING.",
            )

        if rule.effective_to and rule.effective_to < today:
            return (
                "WARNING",
                True,
                f"Rule validity period expired on {rule.effective_to}. Degraded to WARNING.",
            )

        if rule.review_due_on and rule.review_due_on < today:
            return (
                "WARNING",
                True,
                f"Rule review was due on {rule.review_due_on} and is overdue. Degraded to WARNING.",
            )

        return "BLOCKING", False, None

    def enrich_rule_out(self, rule: LogisticsOperationalRule) -> LogisticsRuleOut:
        effective_level, triggered, reason = self.apply_safety_guard(rule)
        rule_dict = {
            c.name: getattr(rule, c.name) for c in rule.__table__.columns
        }
        rule_dict["effective_enforcement_level"] = effective_level
        rule_dict["safety_guard_triggered"] = triggered
        rule_dict["guard_reason"] = reason
        return LogisticsRuleOut.model_validate(rule_dict)

    def list_rules(
        self,
        scope_type: Optional[str] = None,
        verification_status: Optional[str] = None,
        is_latest: bool = True,
        skip: int = 0,
        limit: int = 100,
    ) -> Tuple[List[LogisticsRuleOut], int]:
        items, total = self.repo.list_rules(
            scope_type=scope_type,
            verification_status=verification_status,
            is_latest=is_latest,
            skip=skip,
            limit=limit,
        )
        return [self.enrich_rule_out(r) for r in items], total

    def get_rule_by_id(self, rule_id: int) -> LogisticsRuleOut:
        rule = self.repo.get_rule_by_id(rule_id)
        if not rule:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Logistics operational rule {rule_id} not found",
            )
        return self.enrich_rule_out(rule)

    def get_effective_rule(
        self,
        rule_key: str,
        scope_type: str = "GLOBAL",
        scope_id: Optional[int] = None,
    ) -> EffectiveRuleOut:
        """
        Resolves effective operational rule by key:
        1. Queries specific scope (e.g. SHIPPING_LINE with scope_id)
        2. Falls back to GLOBAL scope
        3. Applies safety guard to compute effective enforcement and active value
        """
        rule = None
        if scope_type != "GLOBAL" and scope_id is not None:
            rule = self.repo.get_rule_by_key(
                rule_key=rule_key, scope_type=scope_type, scope_id=scope_id, is_latest=True
            )

        if not rule:
            rule = self.repo.get_rule_by_key(
                rule_key=rule_key, scope_type="GLOBAL", scope_id=None, is_latest=True
            )

        if not rule:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Operational rule '{rule_key}' is not defined in system rules catalog",
            )

        effective_level, triggered, reason = self.apply_safety_guard(rule)

        # Decide effective value
        today = date.today()
        is_verified_valid = (
            rule.verification_status == "VERIFIED"
            and rule.verified_value is not None
            and bool(str(rule.verified_value).strip())
            and (not rule.effective_to or rule.effective_to >= today)
            and (not rule.review_due_on or rule.review_due_on >= today)
        )

        if is_verified_valid:
            active_value = rule.verified_value
            value_source = "VERIFIED"
        elif rule.conservative_default is not None:
            active_value = rule.conservative_default
            value_source = "CONSERVATIVE_DEFAULT"
        else:
            active_value = None
            value_source = "NONE"

        return EffectiveRuleOut(
            rule_key=rule.rule_key,
            rule_name_ar=rule.rule_name_ar,
            rule_name_en=rule.rule_name_en,
            scope_type=rule.scope_type,
            scope_id=rule.scope_id,
            raw_enforcement_level=rule.enforcement_level,
            effective_enforcement_level=effective_level,
            safety_guard_triggered=triggered,
            guard_reason=reason,
            value=active_value,
            value_source=value_source,
            value_unit=rule.value_unit,
            verification_status=rule.verification_status,
            evidence_ref=rule.evidence_ref,
            source_ref=rule.source_ref,
        )

    def create_rule(
        self, payload: LogisticsRuleCreate, current_user_id: Optional[int] = None
    ) -> LogisticsRuleOut:
        validate_effective_dates(payload.effective_from, payload.effective_to)
        validate_scope(payload.scope_type.value, payload.scope_id)

        # Check existing active latest rule
        existing = self.repo.get_rule_by_key(
            rule_key=payload.rule_key,
            scope_type=payload.scope_type.value,
            scope_id=payload.scope_id,
            is_latest=True,
        )
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Rule '{payload.rule_key}' already exists for scope {payload.scope_type.value}:{payload.scope_id}. Use update to create a new version.",
            )

        data = payload.model_dump()
        data["scope_type"] = payload.scope_type.value
        data["value_unit"] = payload.value_unit.value
        data["enforcement_level"] = payload.enforcement_level.value
        data["verification_status"] = "UNVERIFIED"

        rule = self.repo.create_rule(data, created_by_user_id=current_user_id)
        return self.enrich_rule_out(rule)

    def update_rule(
        self,
        rule_id: int,
        payload: LogisticsRuleUpdate,
        current_user_id: Optional[int] = None,
    ) -> LogisticsRuleOut:
        old_rule = self.repo.get_rule_by_id(rule_id)
        if not old_rule:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Logistics operational rule {rule_id} not found",
            )

        dump = payload.model_dump(exclude_unset=True)
        eff_from = dump.get("effective_from", old_rule.effective_from)
        eff_to = dump.get("effective_to", old_rule.effective_to)
        validate_effective_dates(eff_from, eff_to)

        scope_type = dump.get("scope_type", old_rule.scope_type)
        if hasattr(scope_type, "value"):
            scope_type = scope_type.value
            dump["scope_type"] = scope_type
        scope_id = dump.get("scope_id", old_rule.scope_id)
        validate_scope(scope_type, scope_id)

        if "value_unit" in dump and hasattr(dump["value_unit"], "value"):
            dump["value_unit"] = dump["value_unit"].value
        if "enforcement_level" in dump and hasattr(dump["enforcement_level"], "value"):
            dump["enforcement_level"] = dump["enforcement_level"].value

        new_rule = self.repo.update_rule_version(
            old_rule=old_rule, update_data=dump, updated_by_user_id=current_user_id
        )
        return self.enrich_rule_out(new_rule)

    def verify_rule(
        self,
        rule_id: int,
        payload: LogisticsRuleVerify,
        current_user_id: Optional[int],
    ) -> LogisticsRuleOut:
        rule = self.repo.get_rule_by_id(rule_id)
        if not rule:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Logistics operational rule {rule_id} not found",
            )

        # Maker-Checker validation
        try:
            validate_no_self_verify(rule, current_user_id)
        except ValueError as e:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=str(e),
            )

        verified_rule = self.repo.verify_rule(
            rule=rule,
            verified_value=payload.verified_value,
            verified_by_user_id=current_user_id or 1,
            evidence_ref=payload.evidence_ref,
            source_ref=payload.source_ref,
            review_due_on=payload.review_due_on,
        )
        return self.enrich_rule_out(verified_rule)

    def get_rules_for_export(self) -> List[FieldQuestionOut]:
        unverified = self.repo.get_unverified_rules_for_export()
        questions = []
        for r in unverified:
            party, q_text = self._classify_question(r)
            questions.append(
                FieldQuestionOut(
                    rule_key=r.rule_key,
                    rule_name_ar=r.rule_name_ar,
                    rule_name_en=r.rule_name_en,
                    value_unit=r.value_unit,
                    conservative_default=r.conservative_default,
                    suggested_party=party,
                    source_ref=r.source_ref,
                    question_text_ar=q_text,
                )
            )
        return questions

    @staticmethod
    def _classify_question(rule: LogisticsOperationalRule) -> Tuple[str, str]:
        key = rule.rule_key.upper()
        if key in (
            "APPARENT_DAMAGE_NOTICE_HOURS",
            "CONCEALED_DAMAGE_NOTICE_DAYS",
            "CLAIM_SUIT_TIME_BAR_MONTHS",
        ):
            party = "المستشار القانوني / محامي بحري"
            q_text = f"ما هي المهلة القانونية الدقيقة المعتمدة لـ '{rule.rule_name_ar}' وسندها بموجب مشارطات الشحن المعتمدة؟"
        elif "BANK" in key or "FORM4" in key:
            party = "البنك المعتمد / القطاع المصرفي"
            q_text = f"هل إجراء '{rule.rule_name_ar}' إلزامي لإنهاء الإفراج الجمركي أم يتم الإفراج بضمان؟"
        elif "ACID" in key or "DO_" in key or "PRE_CLEARANCE" in key or "CUSTOMS" in key:
            party = "المخلص الجمركي المعتمد"
            q_text = f"ما هو التطبيق الفعلي لقاعدة '{rule.rule_name_ar}' في المركز اللوجستي لمنظومة نافذة؟"
        elif "DEMURRAGE" in key or "DETENTION" in key or "SHIPPING_LINE" in key:
            party = "التوكيل الملاحي"
            q_text = f"ما هي سياسة احتساب '{rule.rule_name_ar}' وفترات السماح الرسمية المطبقة؟"
        elif "INSURANCE" in key:
            party = "شركة التأمين البحري"
            q_text = f"ما هو الحد الأدنى ونسبة التغطية والشروط المطلوبة لـ '{rule.rule_name_ar}'؟"
        elif "ROAD" in key or "PAYLOAD" in key or "TRANSPORT" in key:
            party = "شركات النقل البري / هيئة الطرق"
            q_text = f"ما هي الحدود القصوى الرسمية المقررة لـ '{rule.rule_name_ar}' على الطرق البرية المصرية؟"
        else:
            party = "الجهة المختصة"
            q_text = f"يرجى تحديد المعيار الرسمي الموثق لـ '{rule.rule_name_ar}'."
        return party, q_text
