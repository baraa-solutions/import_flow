"""
Unit tests for BE09-T14:
Hygiene: soft-delete fields wiring, incoterm validation, justification check, and dependency list permissions.
"""
from datetime import datetime, timezone, date
import pytest
from fastapi import HTTPException
from pydantic import ValidationError
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

import main  # Registers all SQLAlchemy models on Base.metadata
from database.database import Base
from modules.auth.security import create_access_token, hash_password
from modules.auth.seed_rbac import seed_rbac
from modules.financial_settlement.model import LandedCostSettlementRecord
from modules.financial_settlement.repository import soft_delete_settlement, restore_settlement
from modules.financial_settlement.schemas import (
    FinancialSettlementCreate,
    FinancialSettlementUpdate,
    FinancialSettlementResponse,
)
from modules.financial_settlement.service import (
    soft_delete_settlement_service,
    restore_settlement_service,
)
from modules.import_files.model import ImportFile
from modules.recalculation.model import RecalculationDependencyMap
from modules.recalculation.schemas import RecalculationApplyRequest
from modules.recalculation.service import apply, list_dependencies
from modules.users.model import Role, User


@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(autocommit=False, autoflush=False, bind=engine)()
    seed_rbac(session)

    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def _user_with_role(db: Session, username: str, role_code: str) -> User:
    role = db.query(Role).filter_by(role_code=role_code).one()
    u = User(
        username=username,
        email=f"{username}@example.com",
        hashed_password=hash_password("secret123"),
        full_name=username,
        role="ADMIN" if role_code == "ADMIN" else "OPERATOR",
        role_id=role.role_id,
        is_active=True,
    )
    db.add(u)
    db.commit()
    db.refresh(u)
    return u


def _seed_file(db: Session, code: str = "IMP-2026-T14") -> ImportFile:
    imp = ImportFile(
        import_file_code=code,
        company_name="Test Company",
        supplier_name="Test Supplier",
        shipment_mode="Sea",
        incoterm_code="FOB",
        priority="Normal",
        shipment_category="Commercial",
        status="Under Processing",
        is_active=True,
    )
    db.add(imp)
    db.commit()
    db.refresh(imp)
    return imp


def _seed_settlement(db: Session, imp: ImportFile) -> LandedCostSettlementRecord:
    rec = LandedCostSettlementRecord(
        settlement_code="LCS-2026-T14",
        import_file_id=imp.import_file_id,
        total_fob_egp=100000.0,
        total_expenses_egp=20000.0,
        total_landed_cost_egp=120000.0,
        average_markup_factor=1.2,
        status="Calculated",
        accountant_name="Kamal",
        is_active=True,
    )
    db.add(rec)
    db.commit()
    db.refresh(rec)
    return rec


# ==============================================================================
# 1. Soft-delete and restore fields wiring (BE09-F17)
# ==============================================================================

def test_soft_delete_sets_deleted_fields_and_restore_clears_them(db: Session):
    imp = _seed_file(db)
    rec = _seed_settlement(db, imp)

    assert rec.is_active is True
    assert rec.deleted_at is None
    assert rec.deleted_by is None

    # 1. Soft delete
    soft_delete_settlement_service(db, rec.settlement_id, actor="ahmed_ops")
    db.refresh(rec)

    assert rec.is_active is False
    assert rec.deleted_at is not None
    assert rec.deleted_by == "ahmed_ops"
    assert rec.updated_by == "ahmed_ops"

    # 2. Restore
    restore_settlement_service(db, rec.settlement_id, actor="kamal_lead")
    db.refresh(rec)

    assert rec.is_active is True
    assert rec.deleted_at is None
    assert rec.deleted_by is None
    assert rec.updated_by == "kamal_lead"


# ==============================================================================
# 2. Incoterm validation on create and update (BE09-F18)
# ==============================================================================

def test_incoterm_validation_rejects_unknown_with_422():
    # Unknown incoterm on Create raises ValidationError (HTTP 422 in FastAPI)
    with pytest.raises(ValidationError) as exc:
        FinancialSettlementCreate(import_file_id=1, incoterm_code="XYZ")
    assert "incoterm_code" in str(exc.value)

    # Valid incoterm in lowercase is normalized to uppercase
    created = FinancialSettlementCreate(import_file_id=1, incoterm_code="cif")
    assert created.incoterm_code == "CIF"

    # Unknown incoterm on Update raises ValidationError
    with pytest.raises(ValidationError) as exc_up:
        FinancialSettlementUpdate(incoterm_code="INVALID_TERM")
    assert "incoterm_code" in str(exc_up.value)

    # Valid update
    updated = FinancialSettlementUpdate(incoterm_code="fob")
    assert updated.incoterm_code == "FOB"


# ==============================================================================
# 3. Hard-block check rejects whitespace-only justification (BE09-F20)
# ==============================================================================

def test_recalculation_hard_block_rejects_whitespace_justification(db: Session, monkeypatch):
    imp = _seed_file(db)
    rec = _seed_settlement(db, imp)
    admin = _user_with_role(db, "admin_user", "ADMIN")

    # Seed a dependency that creates a hard block
    dep = RecalculationDependencyMap(
        target_entity_type="financial_settlement",
        target_field="total_fob_egp",
        source_entity_type="purchase_orders",
        source_field="total_amount_fob_egp",
        join_key="import_file_id",
        aggregation_function="sum",
        is_active=True,
    )
    db.add(dep)
    db.commit()

    # Monkeypatch evaluated dependencies to return a hard block
    from modules.recalculation.service import RecalculationPreviewItem
    fake_evaluated = [
        RecalculationPreviewItem(
            field_name="total_fob_egp",
            label_ar="إجمالي فوب",
            label_en="Total FOB",
            old_value=100000.0,
            new_value=150000.0,
            variance_amount=50000.0,
            variance_percentage=50.0,
            status="OK",
            is_hard_block=True,
            threshold_percentage=5.0,
            source_entity_type="purchase_orders",
            dependency_id=dep.id,
        )
    ]
    monkeypatch.setattr("modules.recalculation.service._evaluate_dependencies", lambda *args, **kwargs: fake_evaluated)

    # Apply with whitespace-only justification -> 400
    with pytest.raises(HTTPException) as exc:
        apply(
            db,
            RecalculationApplyRequest(
                target_entity_type="financial_settlement",
                target_entity_id=rec.settlement_id,
                source_page="financial_settlement",
                justification="     ",
            ),
            current_user=admin,
        )
    assert exc.value.status_code == 400
    assert "يجب تقديم مبرر كتابي لإتمام المزامنة" in exc.value.detail


# ==============================================================================
# 4. Dependency list filters by user permissions (BE09-F21)
# ==============================================================================

def test_list_dependencies_filters_by_viewable_target_entities(db: Session):
    # Seed dependencies for two target types
    db.add_all([
        RecalculationDependencyMap(
            target_entity_type="financial_settlement",
            target_field="total_fob_egp",
            source_entity_type="purchase_orders",
            source_field="total_amount_fob_egp",
            join_key="import_file_id",
            aggregation_function="sum",
            is_active=True,
        ),
        RecalculationDependencyMap(
            target_entity_type="import_budget",
            target_field="estimated_freight_cost_egp",
            source_entity_type="shipping_scenarios",
            source_field="total_quotation_amount",
            join_key="import_file_id",
            aggregation_function="max",
            is_active=True,
        ),
    ])
    db.commit()

    # User with financial_settlement.view only (e.g. CUSTOMS_SPECIALIST or a custom role)
    # Let's create custom users with distinct permissions
    from modules.users.model import Permission, RolePermission
    custom_role = Role(role_code="SETTLEMENT_ONLY", name_en="Settlement Specialist", name_ar="أخصائي تسويات", is_active=True)
    db.add(custom_role)
    db.commit()

    perm = db.query(Permission).filter(Permission.permission_code == "financial_settlement.view").first()
    if not perm:
        perm = Permission(
            permission_code="financial_settlement.view",
            module_name="financial_settlement",
            action="view",
            name_en="View Financial Settlement",
            name_ar="عرض التسويات المالية",
        )
        db.add(perm)
        db.commit()

    db.add(RolePermission(role_id=custom_role.role_id, permission_id=perm.permission_id))
    db.commit()

    user_settlement_only = User(
        username="settlement_viewer",
        email="settlement_viewer@example.com",
        full_name="Settlement Viewer",
        hashed_password="dummy_hash_for_test",
        role_id=custom_role.role_id,
        is_active=True,
    )
    db.add(user_settlement_only)
    db.commit()
    db.refresh(user_settlement_only)

    deps = list_dependencies(db, user_settlement_only)
    target_types = {d.target_entity_type for d in deps}
    assert "financial_settlement" in target_types
    assert "import_budget" not in target_types  # Filtered out because user lacks financial_approval.view
