"""
Unit tests for BE01-T20: Arabic user-facing messages in Phase 01 validators.
Verifies that all validation exceptions in Phase 01 modules (cbm_calculator, shipping_scenarios,
customs_consultation, freight_quotations) produce user-facing error details containing Arabic text (regex [؀-ۿ]).
"""
import ast
import re
import pytest
from datetime import date
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.cbm_calculator.validators import CBMValidator
from modules.cbm_calculator.schemas import CBMItemCreate
from modules.shipping_scenarios.validators import ShippingScenarioValidator
from modules.shipping_scenarios.schemas import ShippingEvaluationCreate, ShippingScenarioItemCreate
from modules.customs_consultation.validators import validate_checklist_items, validate_expense_code_unique
from modules.customs_consultation.model import ClearanceExpenseType
from modules.freight_quotations.validators import validate_quotation_dates


ARABIC_REGEX = re.compile(r"[\u0600-\u06FF]")


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()


def test_cbm_validator_arabic_messages():
    # 1. Empty items
    with pytest.raises(HTTPException) as exc:
        CBMValidator.validate_items([])
    assert ARABIC_REGEX.search(exc.value.detail)

    # 2. Zero quantity
    item_zero_qty = CBMItemCreate.model_construct(
        package_type="Carton",
        quantity=0,
        length_cm=10.0,
        width_cm=10.0,
        height_cm=10.0,
        gross_weight_per_unit_kg=5.0,
    )
    with pytest.raises(HTTPException) as exc:
        CBMValidator.validate_items([item_zero_qty])
    assert ARABIC_REGEX.search(exc.value.detail)

    # 3. Negative dimensions
    class DummyItem:
        quantity = 1
        length_cm = -5.0
        width_cm = 10.0
        height_cm = 10.0
        gross_weight_per_unit_kg = 5.0

    with pytest.raises(HTTPException) as exc:
        CBMValidator.validate_items([DummyItem()])
    assert ARABIC_REGEX.search(exc.value.detail)


def test_shipping_scenarios_validator_arabic_messages():
    # 1. Negative avg form 4 days
    payload = ShippingEvaluationCreate.model_construct(
        avg_form4_days=-1,
        avg_clearance_days=2,
        cargo_ready_date=date(2026, 10, 1),
    )
    with pytest.raises(HTTPException) as exc:
        ShippingScenarioValidator.validate_evaluation_create(payload)
    assert ARABIC_REGEX.search(exc.value.detail)

    # 2. Sailing before CRD
    item_early_sail = ShippingScenarioItemCreate.model_construct(
        provider_name="Carrier",
        vessel_name="Vessel",
        sailing_date=date(2026, 9, 20),
        estimated_arrival_date=date(2026, 10, 10),
        expected_line_delay_days=0,
    )
    with pytest.raises(HTTPException) as exc:
        ShippingScenarioValidator.validate_scenario_items(
            date(2026, 10, 1), [item_early_sail]
        )
    assert ARABIC_REGEX.search(exc.value.detail)


def test_customs_consultation_validator_arabic_messages(db_session):
    # 1. Invalid checklist status
    with pytest.raises(HTTPException) as exc:
        validate_checklist_items([{"status": "InvalidStatus"}])
    assert ARABIC_REGEX.search(exc.value.detail)

    # 2. Duplicate expense code
    db_session.add(ClearanceExpenseType(expense_code="EXP-001", name_ar="مصروف تجريبي", name_en="Test Expense"))
    db_session.commit()
    with pytest.raises(HTTPException) as exc:
        validate_expense_code_unique(db_session, "EXP-001")
    assert ARABIC_REGEX.search(exc.value.detail)


def test_freight_quotations_validator_arabic_messages():
    # Sailing before CRD
    with pytest.raises(HTTPException) as exc:
        validate_quotation_dates(date(2026, 10, 5), date(2026, 10, 1), date(2026, 10, 20))
    assert ARABIC_REGEX.search(exc.value.detail)

    # Arrival before sailing
    with pytest.raises(HTTPException) as exc:
        validate_quotation_dates(date(2026, 10, 1), date(2026, 10, 10), date(2026, 10, 8))
    assert ARABIC_REGEX.search(exc.value.detail)


def test_static_ast_phase_01_validators_arabic_purity():
    """Static AST check verifying all HTTPException details in Phase 01 modules contain Arabic text."""
    import glob
    modules = [
        "modules/cbm_calculator/validators.py",
        "modules/shipping_scenarios/validators.py",
        "modules/customs_consultation/validators.py",
        "modules/freight_quotations/validators.py",
    ]
    for filepath in modules:
        with open(filepath, "r", encoding="utf-8") as f:
            tree = ast.parse(f.read(), filename=filepath)
        for node in ast.walk(tree):
            if isinstance(node, ast.Raise) and isinstance(node.exc, ast.Call):
                func_name = getattr(node.exc.func, "id", getattr(node.exc.func, "attr", None))
                if func_name == "HTTPException":
                    for kw in node.exc.keywords:
                        if kw.arg == "detail":
                            detail_str = ast.unparse(kw.value)
                            assert ARABIC_REGEX.search(detail_str), (
                                f"Non-Arabic error message found in {filepath}:{node.lineno} -> {detail_str}"
                            )
