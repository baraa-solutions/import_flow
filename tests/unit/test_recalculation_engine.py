"""
Unit Tests — Centralized Recalculation Engine (CRE-001)
Tests cover:
  - preview() with no variance
  - preview() with variance below threshold
  - preview() with variance above threshold (Hard Block)
  - apply() without permission → 403
  - apply() with Hard Block and no justification → 400
  - apply() with Draft budget → action_taken='auto_updated'
  - apply() with Approved budget → action_taken='revision_created', old=Superseded
  - SoD: upstream_modified_by == performer on Approved budget → 403
  - upsert_dependency() is idempotent
"""

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from unittest.mock import patch, MagicMock
from fastapi import HTTPException

# ── DB Setup ──────────────────────────────────────────────────────────────────

from database.database import Base
from modules.recalculation.model import RecalculationDependencyMap, RecalculationLog
from modules.financial_approval.model import ImportBudgetApproval, BudgetVarianceSetting
from modules.users.model import User

TEST_DB_URL = "sqlite:///:memory:"


@pytest.fixture(scope="session")
def engine():
    eng = create_engine(TEST_DB_URL, connect_args={"check_same_thread": False})
    # Import all models so create_all creates every table
    from modules.import_companies.model import ImportCompany
    from modules.import_files.model import ImportFile
    from modules.purchase_orders.model import PurchaseOrder
    from modules.customs_consultation.model import CustomsConsultationSession
    from modules.shipping_scenarios.model import ShippingEvaluationSession, ShippingScenarioItem
    from modules.financial_settlement.model import LandedCostSettlementRecord
    Base.metadata.create_all(bind=eng)
    return eng



@pytest.fixture
def db(engine) -> Session:
    """Each test gets a fresh transactional session that is rolled back afterwards."""
    connection = engine.connect()
    transaction = connection.begin()
    TestSession = sessionmaker(bind=connection)
    session = TestSession()
    yield session
    session.close()
    transaction.rollback()
    connection.close()


# ── Helpers ───────────────────────────────────────────────────────────────────

def make_user(db: Session, username: str = "test_user", role: str = "FINANCE_OFFICER") -> User:
    u = User(
        username=username,
        full_name="Test User",
        email=f"{username}@test.com",
        role=role,
        is_active=True,
        hashed_password="hashed",
    )
    db.add(u)
    db.flush()
    return u


def make_budget(
    db: Session,
    status: str = "Draft",
    import_file_id: int = 1,
    invoice_egp: float = 100_000.0,
    freight_egp: float = 20_000.0,
    customs_egp: float = 15_000.0,
    clearance_egp: float = 5_000.0,
    upstream_modified_by: str = None,
) -> ImportBudgetApproval:
    b = ImportBudgetApproval(
        budget_code="BDG-TEST-001",
        title="Test Budget",
        budget_status=status,
        import_file_id=import_file_id,
        invoice_amount_egp=invoice_egp,
        invoice_amount_foreign=0.0,
        invoice_currency="USD",
        freight_cost_egp=freight_egp,
        freight_cost_foreign=0.0,
        freight_currency="USD",
        customs_duties_egp=customs_egp,
        clearance_inland_egp=clearance_egp,
        exchange_rate=50.0,
        total_budget_egp=invoice_egp + freight_egp + customs_egp + clearance_egp,
        is_active=True,
        upstream_modified_by=upstream_modified_by,
        revision_number=1,
        has_unresolved_variance=False,
    )
    db.add(b)
    db.flush()
    return b



def seed_deps(db: Session):
    """Seeds the 4 dependency rows needed for import_budget recalculation."""
    from modules.recalculation.seed_dependencies import DEPENDENCY_SEEDS
    import modules.recalculation.repository as repo
    for seed in DEPENDENCY_SEEDS:
        repo.upsert_dependency(db=db, **seed)
    db.flush()


def seed_variance_setting(db: Session, threshold_pct: float = 5.0):
    s = BudgetVarianceSetting(
        setting_key="variance_threshold_percentage",
        setting_value=str(threshold_pct),
        description="Hard Block threshold for recalculation engine",
        updated_by="test_seed",
    )
    db.add(s)
    db.flush()



# ── 1. upsert_dependency is idempotent ────────────────────────────────────────

def test_upsert_dependency_is_idempotent(db: Session):
    """Calling upsert_dependency twice for the same key should not create duplicates."""
    import modules.recalculation.repository as repo

    kwargs = dict(
        target_entity_type="import_budget",
        target_field="freight_cost_egp",
        source_entity_type="shipping_scenarios",
        source_field="total_quotation_amount",
        join_key="import_file_id",
        aggregation_function="max",
        blocked_statuses=["Budget Approved"],
        required_permission="budget.sync_variance",
        label_ar="نولون",
        label_en="Freight",
        display_order=1,
    )

    repo.upsert_dependency(db=db, **kwargs)
    repo.upsert_dependency(db=db, **kwargs)

    count = db.query(RecalculationDependencyMap).filter_by(
        target_entity_type="import_budget",
        target_field="freight_cost_egp",
        source_entity_type="shipping_scenarios",
    ).count()
    assert count == 1, f"Expected 1 row, got {count}"


# ── 2. preview() with no variance ─────────────────────────────────────────────

def test_preview_no_variance(db: Session):
    """When live values equal stored values, has_any_variance is False."""
    seed_deps(db)
    seed_variance_setting(db, threshold_pct=5.0)
    budget = make_budget(db, status="Draft", invoice_egp=100_000.0)

    with (
        patch("modules.recalculation.service._fetch_from_customs_consultation", return_value=0.0),
        patch("modules.recalculation.service._fetch_from_shipping_scenarios", return_value=0.0),
        patch("modules.recalculation.service._fetch_from_purchase_orders", return_value=0.0),
    ):
        # Set customs and clearance to 0 to match mocked fetch
        budget.customs_duties_egp = 0.0
        budget.clearance_inland_egp = 0.0
        budget.freight_cost_egp = 0.0
        budget.invoice_amount_egp = 0.0
        db.flush()

        from modules.recalculation import service
        result = service.preview(
            db=db,
            target_entity_type="import_budget",
            target_entity_id=budget.budget_id,
            source_page="TestSuite",
            performed_by="test_user",
        )

    assert result.has_any_variance is False
    assert result.has_hard_block is False
    assert result.can_apply is True


# ── 3. preview() with variance below threshold ────────────────────────────────

def test_preview_soft_variance(db: Session):
    """Variance below threshold: has_any_variance=True, has_hard_block=False."""
    seed_deps(db)
    seed_variance_setting(db, threshold_pct=5.0)
    # customs=10_000, clearance=5_000, freight=20_000, invoice=100_000
    budget = make_budget(db, status="Draft", customs_egp=10_000.0, clearance_egp=5_000.0)

    def _customs_fetcher(db, join_key_value, source_field, aggregation):
        """Return 3% more than stored value — below threshold."""
        if source_field == "estimated_duties_egp":
            return 10_300.0  # 3% above 10_000
        if source_field == "total_broker_fees_egp":
            return 5_150.0   # 3% above 5_000
        return 0.0

    def _shipping_fetcher(db, join_key_value, source_field, aggregation):
        return 20_000.0  # No change

    def _po_fetcher(db, join_key_value, source_field, aggregation):
        return 100_000.0  # No change

    from modules.recalculation import service
    with (
        patch.object(service, "_SOURCE_FETCHERS", {
            "customs_consultation": _customs_fetcher,
            "shipping_scenarios": _shipping_fetcher,
            "purchase_orders": _po_fetcher,
        }),
    ):
        result = service.preview(
            db=db,
            target_entity_type="import_budget",
            target_entity_id=budget.budget_id,
            source_page="TestSuite",
            performed_by="test_user",
        )

    assert result.has_any_variance is True
    assert result.has_hard_block is False
    assert result.can_apply is True


# ── 4. preview() with variance above threshold (Hard Block) ───────────────────

def test_preview_hard_block(db: Session):
    """Variance above threshold triggers Hard Block — justification required."""
    seed_deps(db)
    seed_variance_setting(db, threshold_pct=5.0)
    budget = make_budget(db, status="Draft", customs_egp=10_000.0, clearance_egp=5_000.0)

    def _customs_fetcher(db, join_key_value, source_field, aggregation):
        if source_field == "estimated_duties_egp":
            return 15_000.0   # 50% above 10_000 → Hard Block
        if source_field == "total_broker_fees_egp":
            return 5_150.0    # 3% above 5_000 — below threshold
        return 0.0

    def _no_change_fetcher(db, join_key_value, source_field, aggregation):
        return 0.0  # Unchanged

    from modules.recalculation import service
    with patch.object(service, "_SOURCE_FETCHERS", {
        "customs_consultation": _customs_fetcher,
        "shipping_scenarios": lambda *a: 20_000.0,
        "purchase_orders": lambda *a: 100_000.0,
    }):
        result = service.preview(
            db=db,
            target_entity_type="import_budget",
            target_entity_id=budget.budget_id,
            source_page="TestSuite",
            performed_by="test_user",
        )

    assert result.has_hard_block is True
    assert result.max_variance_pct > 5.0




# ── 5. apply() without permission → 403 ──────────────────────────────────────

def test_apply_without_permission_raises_403(db: Session):
    """User without budget.sync_variance permission cannot apply."""
    seed_deps(db)
    seed_variance_setting(db, threshold_pct=5.0)
    budget = make_budget(db, status="Draft")
    user = make_user(db, username="no_perm_user", role="VIEWER")

    from modules.recalculation import service
    from modules.recalculation.schemas import RecalculationApplyRequest

    request = RecalculationApplyRequest(
        target_entity_type="import_budget",
        target_entity_id=budget.budget_id,
        source_page="TestSuite",
    )

    with pytest.raises(HTTPException) as exc_info:
        service.apply(db=db, request=request, current_user=user)

    assert exc_info.value.status_code == 403


# ── 6. apply() Hard Block with no justification → 400 ────────────────────────

def test_apply_hard_block_no_justification_raises_400(db: Session):
    """Hard Block variance without justification must be rejected with 400."""
    from modules.recalculation import service
    from modules.recalculation.schemas import RecalculationApplyRequest

    seed_deps(db)
    seed_variance_setting(db, threshold_pct=5.0)
    budget = make_budget(db, status="Draft", customs_egp=10_000.0, clearance_egp=5_000.0)
    user = make_user(db, role="FINANCE_OFFICER")

    # 100% variance on customs_duties → hard block
    def _customs_fetcher(db, join_key_value, source_field, aggregation):
        if source_field == "estimated_duties_egp":
            return 20_000.0  # 100% above 10_000 → Hard Block
        return 5_000.0       # No change on clearance

    with (
        patch("modules.recalculation.service.has_user_permission", return_value=True),
        patch.object(service, "_SOURCE_FETCHERS", {
            "customs_consultation": _customs_fetcher,
            "shipping_scenarios": lambda *a: 20_000.0,
            "purchase_orders": lambda *a: 100_000.0,
        }),
    ):
        request = RecalculationApplyRequest(
            target_entity_type="import_budget",
            target_entity_id=budget.budget_id,
            source_page="TestSuite",
            # No justification provided
        )

        with pytest.raises(HTTPException) as exc_info:
            service.apply(db=db, request=request, current_user=user)

    assert exc_info.value.status_code == 400
    assert "مبرر" in exc_info.value.detail or "justification" in exc_info.value.detail.lower()


# ── 7. apply() with Draft budget → auto_updated ───────────────────────────────

def test_apply_draft_budget_auto_updated(db: Session):
    """Applying to a Draft budget updates it in-place with action_taken='auto_updated'."""
    from modules.recalculation import service
    from modules.recalculation.schemas import RecalculationApplyRequest

    seed_deps(db)
    seed_variance_setting(db, threshold_pct=5.0)
    budget = make_budget(
        db, status="Draft",
        customs_egp=10_000.0, clearance_egp=5_000.0,
        freight_egp=20_000.0, invoice_egp=100_000.0,
    )
    original_id = budget.budget_id
    user = make_user(db, role="FINANCE_OFFICER")

    # 2% variance on customs only — below threshold
    def _customs_fetcher(db, join_key_value, source_field, aggregation):
        if source_field == "estimated_duties_egp":
            return 10_200.0   # 2% above 10_000
        return 5_000.0        # No change on clearance

    with (
        patch("modules.recalculation.service.has_user_permission", return_value=True),
        patch.object(service, "_SOURCE_FETCHERS", {
            "customs_consultation": _customs_fetcher,
            "shipping_scenarios": lambda *a: 20_000.0,
            "purchase_orders": lambda *a: 100_000.0,
        }),
    ):
        request = RecalculationApplyRequest(
            target_entity_type="import_budget",
            target_entity_id=budget.budget_id,
            source_page="TestSuite",
        )

        result = service.apply(db=db, request=request, current_user=user)

    assert result.action_taken == "auto_updated"
    assert result.revision_created is False
    assert result.target_entity_id == original_id
    db.refresh(budget)
    assert float(budget.customs_duties_egp) == pytest.approx(10_200.0, abs=1.0)


# ── 8. apply() with Approved budget → revision_created ───────────────────────

def test_apply_approved_budget_creates_revision(db: Session):
    """Applying to an Approved budget creates a new Revision and Supersedes the original."""
    from modules.recalculation import service
    from modules.recalculation.schemas import RecalculationApplyRequest

    seed_deps(db)
    seed_variance_setting(db, threshold_pct=5.0)
    budget = make_budget(
        db, status="Budget Approved",
        customs_egp=10_000.0, clearance_egp=5_000.0,
        freight_egp=20_000.0, invoice_egp=100_000.0,
    )
    original_id = budget.budget_id
    user = make_user(db, role="GENERAL_MANAGER")

    # 2% variance on customs — below threshold, no justification needed
    def _customs_fetcher(db, join_key_value, source_field, aggregation):
        if source_field == "estimated_duties_egp":
            return 10_200.0
        return 5_000.0

    with (
        patch("modules.recalculation.service.has_user_permission", return_value=True),
        patch.object(service, "_SOURCE_FETCHERS", {
            "customs_consultation": _customs_fetcher,
            "shipping_scenarios": lambda *a: 20_000.0,
            "purchase_orders": lambda *a: 100_000.0,
        }),
    ):
        request = RecalculationApplyRequest(
            target_entity_type="import_budget",
            target_entity_id=budget.budget_id,
            source_page="TestSuite",
        )

        result = service.apply(db=db, request=request, current_user=user)

    assert result.revision_created is True
    assert result.action_taken == "revision_created"
    assert result.new_entity_id is not None
    assert result.new_entity_id != original_id

    # Original must be Superseded
    db.refresh(budget)
    assert budget.budget_status == "Superseded"
    assert budget.is_active is False


# ── 9. SoD: upstream_modified_by == performer on Approved budget → 403 ────────

def test_apply_sod_violation_approved_budget(db: Session):
    """
    If the user who last modified the upstream costs is the same person trying
    to sync an Approved budget, the SoD rule must block with 403.
    """
    from modules.recalculation import service
    from modules.recalculation.schemas import RecalculationApplyRequest

    seed_deps(db)
    seed_variance_setting(db, threshold_pct=5.0)
    budget = make_budget(
        db,
        status="Budget Approved",
        customs_egp=10_000.0,
        clearance_egp=5_000.0,
        upstream_modified_by="finance_user",
    )
    user = make_user(db, username="finance_user", role="GENERAL_MANAGER")

    def _customs_fetcher(db, join_key_value, source_field, aggregation):
        if source_field == "estimated_duties_egp":
            return 10_200.0
        return 5_000.0

    with (
        patch("modules.recalculation.service.has_user_permission", return_value=True),
        patch.object(service, "_SOURCE_FETCHERS", {
            "customs_consultation": _customs_fetcher,
            "shipping_scenarios": lambda *a: 20_000.0,
            "purchase_orders": lambda *a: 100_000.0,
        }),
    ):
        request = RecalculationApplyRequest(
            target_entity_type="import_budget",
            target_entity_id=budget.budget_id,
            source_page="TestSuite",
        )

        with pytest.raises(HTTPException) as exc_info:
            service.apply(db=db, request=request, current_user=user)

    assert exc_info.value.status_code == 403
    assert "فصل المهام" in exc_info.value.detail or "SoD" in exc_info.value.detail


# ── Helpers for Financial Settlement ──────────────────────────────────────────

def make_settlement(
    db: Session,
    status: str = "Draft",
    import_file_id: int = 1,
    fob_egp: float = 100_000.0,
    freight_egp: float = 20_000.0,
    customs_egp: float = 15_000.0,
    clearance_egp: float = 5_000.0,
):
    from modules.financial_settlement.model import LandedCostSettlementRecord
    exp = [
        {"invoice_no": "INV-FRT-01", "category": "Freight", "provider_name": "Maersk", "currency": "EGP", "amount_fx": freight_egp, "exchange_rate": 1.0, "amount_egp": freight_egp, "allocation_rule": "Volume-Based"},
        {"invoice_no": "INV-CUS-01", "category": "Customs Duty", "provider_name": "Customs Authority", "currency": "EGP", "amount_fx": customs_egp, "exchange_rate": 1.0, "amount_egp": customs_egp, "allocation_rule": "Value-Based"},
        {"invoice_no": "INV-CLR-01", "category": "Brokerage", "provider_name": "Nabil Broker", "currency": "EGP", "amount_fx": clearance_egp, "exchange_rate": 1.0, "amount_egp": clearance_egp, "allocation_rule": "Equal"},
    ]
    items = [
        {"item_code": "ITM-01", "item_name": "Cargo Valves", "qty": 100, "fob_unit_egp": fob_egp / 100.0, "fob_total_egp": fob_egp, "cbm": 10.0, "gross_weight_kg": 1000.0}
    ]
    tot_exp = freight_egp + customs_egp + clearance_egp
    rec = LandedCostSettlementRecord(
        settlement_code="LCS-TEST-001",
        import_file_id=import_file_id,
        incoterm_code="FOB",
        expense_invoices=exp,
        total_fob_egp=fob_egp,
        total_expenses_egp=tot_exp,
        total_landed_cost_egp=fob_egp + tot_exp,
        average_markup_factor=(fob_egp + tot_exp) / fob_egp if fob_egp > 0 else 1.0,
        item_landed_costs=items,
        status=status,
        accountant_name="Kamal",
        is_active=True,
    )
    db.add(rec)
    db.flush()
    return rec


# ── 10. Financial Settlement: preview detects variances ───────────────────────

def test_financial_settlement_preview_variance(db: Session):
    """Preview on financial_settlement should detect live FOB variance (expenses are not overwritten)."""
    seed_deps(db)
    seed_variance_setting(db, threshold_pct=5.0)
    settlement = make_settlement(db, status="Draft", fob_egp=100_000.0, customs_egp=15_000.0)

    # 3% variance on PO FOB (103,000 vs 100,000), customs changes in consultation should be ignored
    def _customs_fetcher(db, join_key_value, source_field, aggregation):
        if source_field == "estimated_duties_egp":
            return 15_450.0  # 3% increase, but retired for settlement
        return 5_000.0       # clearance unchanged

    from modules.recalculation import service
    with patch.object(service, "_SOURCE_FETCHERS", {
        "customs_consultation": _customs_fetcher,
        "shipping_scenarios": lambda *a: 20_000.0,
        "purchase_orders": lambda *a: 103_000.0,
    }):
        result = service.preview(
            db=db,
            target_entity_type="financial_settlement",
            target_entity_id=settlement.settlement_id,
            source_page="SettlementTest",
            performed_by="test_user",
        )

    assert result.has_any_variance is True
    assert result.has_hard_block is False
    assert result.can_apply is True
    assert len(result.items) == 1
    assert result.items[0].field_name == "total_fob_egp"
    assert result.items[0].old_value == 100_000.0
    assert result.items[0].new_value == 103_000.0
    assert result.items[0].variance_amount == 3_000.0


# ── 11. Financial Settlement: apply recalculates engine ───────────────────────

def test_financial_settlement_apply_recalculates_engine(db: Session):
    """Applying live FOB to financial settlement runs calculate_landed_cost_engine without modifying expenses."""
    from modules.recalculation import service
    from modules.recalculation.schemas import RecalculationApplyRequest

    seed_deps(db)
    seed_variance_setting(db, threshold_pct=5.0)
    settlement = make_settlement(
        db, status="Draft",
        fob_egp=100_000.0, freight_egp=20_000.0,
        customs_egp=15_000.0, clearance_egp=5_000.0,
    )
    user = make_user(db, role="FINANCE_OFFICER")

    with (
        patch("modules.recalculation.service.has_user_permission", return_value=True),
        patch.object(service, "_SOURCE_FETCHERS", {
            "customs_consultation": lambda *a: 15_300.0,
            "shipping_scenarios": lambda *a: 20_000.0,
            "purchase_orders": lambda *a: 103_000.0,
        }),
    ):
        request = RecalculationApplyRequest(
            target_entity_type="financial_settlement",
            target_entity_id=settlement.settlement_id,
            source_page="SettlementTest",
        )
        result = service.apply(db=db, request=request, current_user=user)

    assert result.action_taken == "recalculated"
    db.refresh(settlement)
    assert settlement.status == "Calculated"
    assert settlement.total_fob_egp == pytest.approx(103_000.0, abs=1.0)
    # Actual expenses remain untouched: 20,000 + 15,000 + 5,000 = 40,000
    assert settlement.total_expenses_egp == pytest.approx(40_000.0, abs=1.0)
    assert settlement.total_landed_cost_egp == pytest.approx(143_000.0, abs=1.0)
    assert settlement.average_markup_factor == pytest.approx(143_000.0 / 103_000.0, abs=0.01)


# ── 12. Financial Settlement: Hard Block on Approved status ───────────────────

def test_financial_settlement_approved_hard_block(db: Session):
    """Approved settlement with >5% FOB variance requires justification."""
    from modules.recalculation import service
    from modules.recalculation.schemas import RecalculationApplyRequest

    seed_deps(db)
    seed_variance_setting(db, threshold_pct=5.0)
    settlement = make_settlement(
        db, status="Approved",
        fob_egp=100_000.0, freight_egp=20_000.0,
        customs_egp=15_000.0, clearance_egp=5_000.0,
    )
    user = make_user(db, role="GENERAL_MANAGER")

    # 50% increase on FOB (150_000 vs 100_000) → Hard Block
    with (
        patch("modules.recalculation.service.has_user_permission", return_value=True),
        patch.object(service, "_SOURCE_FETCHERS", {
            "customs_consultation": lambda *a: 15_000.0,
            "shipping_scenarios": lambda *a: 20_000.0,
            "purchase_orders": lambda *a: 150_000.0,
        }),
    ):

        request_no_just = RecalculationApplyRequest(
            target_entity_type="financial_settlement",
            target_entity_id=settlement.settlement_id,
            source_page="SettlementTest",
        )

        with pytest.raises(HTTPException) as exc_info:
            service.apply(db=db, request=request_no_just, current_user=user)

        assert exc_info.value.status_code == 400

        # Now supply justification → Should succeed!
        request_with_just = RecalculationApplyRequest(
            target_entity_type="financial_settlement",
            target_entity_id=settlement.settlement_id,
            source_page="SettlementTest",
            justification="PO revised after vendor renegotiation",
        )
        result = service.apply(db=db, request=request_with_just, current_user=user)

    assert result.action_taken == "recalculated"
    db.refresh(settlement)
    assert settlement.status == "Calculated"
    assert settlement.total_fob_egp == pytest.approx(150_000.0, abs=1.0)
    assert settlement.total_expenses_egp == pytest.approx(40_000.0, abs=1.0)


# ── 13. Financial Settlement: Expense Seeds Retired & Actual Costs Preserved ──

def test_seed_dependencies_retires_settlement_expense_seeds(db: Session):
    """run_seed deactivates retired settlement expense seeds while leaving FOB and budget seeds active."""
    import modules.recalculation.repository as repo
    from modules.recalculation.seed_dependencies import run_seed, RETIRED_DEPENDENCY_SEEDS

    # First, simulate a legacy DB where retired seeds were already inserted as active
    for retired in RETIRED_DEPENDENCY_SEEDS:
        repo.upsert_dependency(db=db, **retired)
    db.flush()

    # Verify they were active before run_seed
    active_before = repo.get_active_dependencies_for_target(db, "financial_settlement")
    assert len(active_before) == 3

    # Run seed
    run_seed(db)

    # Now verify financial_settlement only has total_fob_egp
    active_after = repo.get_active_dependencies_for_target(db, "financial_settlement")
    assert len(active_after) == 1
    assert active_after[0].target_field == "total_fob_egp"

    # Verify import_budget has its 4 dependencies untouched
    budget_deps = repo.get_active_dependencies_for_target(db, "import_budget")
    assert len(budget_deps) == 4
    budget_target_fields = {d.target_field for d in budget_deps}
    assert budget_target_fields == {
        "clearance_inland_egp",
        "customs_duties_egp",
        "freight_cost_egp",
        "invoice_amount_egp",
    }

    # Verify retired seeds exist in DB but is_active is False
    for retired in RETIRED_DEPENDENCY_SEEDS:
        row = (
            db.query(RecalculationDependencyMap)
            .filter_by(
                target_entity_type=retired["target_entity_type"],
                target_field=retired["target_field"],
                source_entity_type=retired["source_entity_type"],
                source_field=retired["source_field"],
            )
            .first()
        )
        assert row is not None
        assert row.is_active is False


def test_financial_settlement_recalculation_preserves_actual_expenses(db: Session):
    """
    Settlement with actual Customs Duty expense of 100,000 EGP and customs consultation
    with estimated_duties_egp = 80,000:
    After run_seed, preview has NO customs_duties_egp item, apply is no_op when PO FOB matches,
    and actual expense rows remain untouched.
    """
    from modules.recalculation import service
    from modules.recalculation.seed_dependencies import run_seed
    from modules.recalculation.schemas import RecalculationApplyRequest
    from modules.financial_settlement.service import settlement_field_total

    run_seed(db)
    seed_variance_setting(db, threshold_pct=5.0)

    # Create settlement with actual customs duty 100,000 EGP
    settlement = make_settlement(
        db, status="Draft",
        fob_egp=100_000.0,
        freight_egp=20_000.0,
        customs_egp=100_000.0,
        clearance_egp=5_000.0,
    )
    user = make_user(db, role="FINANCE_OFFICER")

    # Upstream values: estimated duties = 80,000 (different from actual 100,000)
    # Freight scenario = 25,000 (different from actual 20,000)
    # PO FOB = 100,000 (matches settlement FOB)
    with (
        patch("modules.recalculation.service.has_user_permission", return_value=True),
        patch.object(service, "_SOURCE_FETCHERS", {
            "customs_consultation": lambda *a: 80_000.0,
            "shipping_scenarios": lambda *a: 25_000.0,
            "purchase_orders": lambda *a: 100_000.0,
        }),
    ):
        preview_res = service.preview(
            db=db,
            target_entity_type="financial_settlement",
            target_entity_id=settlement.settlement_id,
            source_page="SettlementTest",
            performed_by="test_user",
        )

        # 1. Preview has NO customs_duties_egp item, NO freight, NO clearance
        preview_field_names = [item.field_name for item in preview_res.items]
        assert "customs_duties_egp" not in preview_field_names
        assert "freight_cost_egp" not in preview_field_names
        assert "clearance_fees_egp" not in preview_field_names
        assert preview_field_names == ["total_fob_egp"]

        # Because PO FOB matches (100,000 == 100,000), no variance
        assert preview_res.has_any_variance is False

        # 2. Apply is no_op when PO FOB matches
        request = RecalculationApplyRequest(
            target_entity_type="financial_settlement",
            target_entity_id=settlement.settlement_id,
            source_page="SettlementTest",
        )
        apply_res = service.apply(db=db, request=request, current_user=user)

        assert apply_res.action_taken == "no_op"
        assert apply_res.applied_changes == []

    # 3. Verify actual expense rows in settlement are preserved untouched
    db.refresh(settlement)
    assert settlement_field_total(settlement.expense_invoices, "Customs Duty") == 100_000.0 or settlement_field_total(settlement.expense_invoices, "customs_duties_egp") == 100_000.0
    assert settlement.total_expenses_egp == pytest.approx(125_000.0, abs=1.0)
    assert settlement.total_landed_cost_egp == pytest.approx(225_000.0, abs=1.0)



