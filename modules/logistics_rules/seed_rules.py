"""
Seed Initial Logistics Operational Rules
Idempotently inserts initial domain rules with UNVERIFIED status,
NULL verified values, and conservative defaults.
"""

from typing import List, Dict, Any
from sqlalchemy.orm import Session
from modules.logistics_rules.model import LogisticsOperationalRule


INITIAL_RULES: List[Dict[str, Any]] = [
    {
        "rule_key": "APPARENT_DAMAGE_NOTICE_HOURS",
        "rule_name_ar": "مهلة إخطار التلف الظاهر",
        "rule_name_en": "Apparent Damage Notice Hours",
        "conservative_default": "0",
        "verified_value": None,
        "value_unit": "HOURS",
        "enforcement_level": "WARNING",
        "source_ref": "Hague-Visby Art. III(3), Hamburg Art. 19(1)",
    },
    {
        "rule_key": "CONCEALED_DAMAGE_NOTICE_DAYS",
        "rule_name_ar": "مهلة إخطار التلف المستتر (أيام تقويمية)",
        "rule_name_en": "Concealed Damage Notice Days (Calendar)",
        "conservative_default": "3",
        "verified_value": None,
        "value_unit": "DAYS",
        "enforcement_level": "WARNING",
        "source_ref": "Hague-Visby Art. III(6) — 3 calendar days",
    },
    {
        "rule_key": "CLAIM_SUIT_TIME_BAR_MONTHS",
        "rule_name_ar": "مهلة رفع الدعوى (الأقصر)",
        "rule_name_en": "Claim Suit Time Bar (shorter)",
        "conservative_default": "12",
        "verified_value": None,
        "value_unit": "MONTHS",
        "enforcement_level": "WARNING",
        "source_ref": "Hague-Visby Art. III(6) — 1 year; Hamburg Art. 20 — 2 years",
    },
    {
        "rule_key": "PRE_CLEARANCE_ADVANCE_PAYMENT_PCT",
        "rule_name_ar": "نسبة السداد المسبق للتخليص",
        "rule_name_en": "Pre-Clearance Advance Payment %",
        "conservative_default": None,
        "verified_value": None,
        "value_unit": "PERCENTAGE",
        "enforcement_level": "INFO",
        "source_ref": "Law 207/2020 Art. ~199 — percentage unconfirmed, verify with broker",
    },
    {
        "rule_key": "ROAD_MAX_PAYLOAD_20FT_KG",
        "rule_name_ar": "الحمولة القصوى للشاحنة 20 قدم (كجم)",
        "rule_name_en": "Road Max Payload 20ft (kg)",
        "conservative_default": None,
        "verified_value": None,
        "value_unit": "KG",
        "enforcement_level": "WARNING",
        "source_ref": "Egyptian road transport regulations — verify with transport authority",
    },
    {
        "rule_key": "BANK_FORM4_BLOCKS_CUSTOMS",
        "rule_name_ar": "نموذج 4 البنكي يحجب الإفراج الجمركي",
        "rule_name_en": "Bank Form 4 Blocks Customs Release",
        "conservative_default": None,
        "verified_value": None,
        "value_unit": "BOOLEAN",
        "enforcement_level": "WARNING",
        "source_ref": "Unconfirmed — verify with bank and customs broker",
    },
    {
        "rule_key": "FREE_DAYS_DEMURRAGE_DEFAULT",
        "rule_name_ar": "أيام السماح — Demurrage (افتراضي)",
        "rule_name_en": "Free Days Demurrage (Default)",
        "conservative_default": None,
        "verified_value": None,
        "value_unit": "DAYS",
        "enforcement_level": "WARNING",
        "source_ref": "Varies by shipping line — verify per B/L",
    },
    {
        "rule_key": "FREE_DAYS_DETENTION_DEFAULT",
        "rule_name_ar": "أيام السماح — Detention (افتراضي)",
        "rule_name_en": "Free Days Detention (Default)",
        "conservative_default": None,
        "verified_value": None,
        "value_unit": "DAYS",
        "enforcement_level": "WARNING",
        "source_ref": "Varies by shipping line — verify per B/L",
    },
    {
        "rule_key": "DO_BLOCKS_DECLARATION_46",
        "rule_name_ar": "E-D/O يحجب إعداد الإقرار الجمركي",
        "rule_name_en": "E-D/O Blocks Customs Declaration Start",
        "conservative_default": None,
        "verified_value": None,
        "value_unit": "BOOLEAN",
        "enforcement_level": "WARNING",
        "source_ref": "Unconfirmed — verify with customs broker",
    },
    {
        "rule_key": "ACID_MIN_VALIDITY_DAYS",
        "rule_name_ar": "الحد الأدنى لصلاحية ACID (أيام)",
        "rule_name_en": "ACID Minimum Validity Days",
        "conservative_default": None,
        "verified_value": None,
        "value_unit": "DAYS",
        "enforcement_level": "WARNING",
        "source_ref": "Nafeza platform requirements — verify current policy",
    },
    {
        "rule_key": "MARINE_INSURANCE_MIN_COVERAGE_PCT",
        "rule_name_ar": "الحد الأدنى لتغطية التأمين البحري (%)",
        "rule_name_en": "Marine Insurance Minimum Coverage %",
        "conservative_default": "110",
        "verified_value": None,
        "value_unit": "PERCENTAGE",
        "enforcement_level": "WARNING",
        "source_ref": "ICC A Clauses standard practice (CIF + 10%)",
    },
    {
        "rule_key": "CUSTOMS_FX_RATE_SOURCE",
        "rule_name_ar": "مصدر سعر الصرف الجمركي",
        "rule_name_en": "Customs FX Rate Source",
        "conservative_default": None,
        "verified_value": None,
        "value_unit": "TEXT",
        "enforcement_level": "INFO",
        "source_ref": "Egyptian Customs — CBE weekly rate — verify current policy",
    },
]


def seed_logistics_rules(db: Session) -> int:
    """
    Seeds initial operational rules idempotently.
    Returns the count of new rules inserted.
    """
    inserted = 0
    for r in INITIAL_RULES:
        existing = (
            db.query(LogisticsOperationalRule)
            .filter(
                LogisticsOperationalRule.rule_key == r["rule_key"],
                LogisticsOperationalRule.scope_type == "GLOBAL",
                LogisticsOperationalRule.is_latest.is_(True),
            )
            .first()
        )
        if not existing:
            new_rule = LogisticsOperationalRule(
                rule_key=r["rule_key"],
                rule_name_ar=r["rule_name_ar"],
                rule_name_en=r["rule_name_en"],
                scope_type="GLOBAL",
                scope_id=None,
                conservative_default=r["conservative_default"],
                verified_value=r["verified_value"],
                value_unit=r["value_unit"],
                enforcement_level=r["enforcement_level"],
                verification_status="UNVERIFIED",
                source_ref=r.get("source_ref"),
                version_id=1,
                is_latest=True,
                is_active=True,
            )
            db.add(new_rule)
            inserted += 1

    if inserted > 0:
        db.commit()
    return inserted
