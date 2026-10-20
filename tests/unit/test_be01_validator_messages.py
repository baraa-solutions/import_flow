"""
Test BE01-T20: Arabic user-facing messages in Phase 01 validators.
Verifies that validation exceptions in cbm_calculator, shipping_scenarios,
customs_consultation, and freight_quotations have Arabic user-facing details (regex [؀-ۿ]).
"""
import re
from datetime import date
import pytest
from fastapi import HTTPException

from modules.cbm_calculator.validators import CBMValidator
from modules.cbm_calculator.schemas import CBMItemCreate
from modules.shipping_scenarios.validators import ShippingScenarioValidator
from modules.shipping_scenarios.schemas import ShippingEvaluationCreate, ShippingScenarioItemCreate
from modules.customs_consultation.validators import validate_checklist_items
from modules.freight_quotations.validators import validate_quotation_dates

ARABIC_REGEX = re.compile(r"[\u0600-\u06FF]")


def assert_arabic(exc_info):
    detail = exc_info.value.detail
    if isinstance(detail, dict):
        text = detail.get("message", "") or detail.get("detail", "")
    else:
        text = str(detail)
    assert ARABIC_REGEX.search(text) is not None, f"Expected Arabic text in detail: '{text}'"


def test_cbm_validator_arabic_messages():
    # Empty items
    with pytest.raises(HTTPException) as exc:
        CBMValidator.validate_items([])
    assert_arabic(exc)

    # Negative quantity
    item = CBMItemCreate.model_construct(
        package_type="Carton",
        quantity=0,
        length_cm=10,
        width_cm=10,
        height_cm=10,
        gross_weight_per_unit_kg=5,
    )
    with pytest.raises(HTTPException) as exc:
        CBMValidator.validate_items([item])
    assert_arabic(exc)

    # Negative dimensions
    item_dim = CBMItemCreate.model_construct(
        package_type="Carton",
        quantity=1,
        length=0,
        width=10,
        height=10,
        unit="cm",
        gross_weight_per_unit_kg=5,
    )
    with pytest.raises(HTTPException) as exc:
        CBMValidator.validate_items([item_dim])
    assert_arabic(exc)

    # Negative weight
    item_wt = CBMItemCreate.model_construct(
        package_type="Carton",
        quantity=1,
        length=10,
        width=10,
        height=10,
        unit="cm",
        gross_weight_per_unit_kg=-1,
    )
    with pytest.raises(HTTPException) as exc:
        CBMValidator.validate_items([item_wt])
    assert_arabic(exc)


def test_shipping_scenarios_validator_arabic_messages():
    # Negative form4 days
    payload = ShippingEvaluationCreate.model_construct(
        evaluation_code="SE-001",
        cargo_ready_date=date(2026, 10, 1),
        avg_form4_days=-1,
        avg_clearance_days=2,
    )
    with pytest.raises(HTTPException) as exc:
        ShippingScenarioValidator.validate_evaluation_create(payload)
    assert_arabic(exc)

    # Negative clearance days
    payload.avg_form4_days = 2
    payload.avg_clearance_days = -1
    with pytest.raises(HTTPException) as exc:
        ShippingScenarioValidator.validate_evaluation_create(payload)
    assert_arabic(exc)

    # Sailing date before CRD
    crd = date(2026, 10, 10)
    item = ShippingScenarioItemCreate(
        provider_id=1,
        provider_name="Maersk",
        vessel_name="Maersk Mc-Kinney",
        sailing_date=date(2026, 10, 5),
        estimated_arrival_date=date(2026, 10, 20),
        expected_line_delay_days=0,
    )
    with pytest.raises(HTTPException) as exc:
        ShippingScenarioValidator.validate_scenario_items(crd, [item])
    assert_arabic(exc)

    # ETA before sailing date
    item.sailing_date = date(2026, 10, 12)
    item.estimated_arrival_date = date(2026, 10, 11)
    with pytest.raises(HTTPException) as exc:
        ShippingScenarioValidator.validate_scenario_items(crd, [item])
    assert_arabic(exc)


def test_customs_consultation_validator_arabic_messages():
    with pytest.raises(HTTPException) as exc:
        validate_checklist_items([{"status": "InvalidStatus"}])
    assert_arabic(exc)


def test_freight_quotations_validator_arabic_messages():
    with pytest.raises(HTTPException) as exc:
        validate_quotation_dates(date(2026, 10, 10), date(2026, 10, 5), date(2026, 10, 20))
    assert_arabic(exc)

    with pytest.raises(HTTPException) as exc:
        validate_quotation_dates(date(2026, 10, 10), date(2026, 10, 12), date(2026, 10, 11))
    assert_arabic(exc)
