"""
Unit Tests for Wave 1:
- Regulatory Matrix (Proactive Compliance & Agency Requirements)
- Trade Finance (Import Letters of Credit, Bank Charges & FX Hedging)
- Customs Broker Custody & Settlement (Advances & White/Red Receipts)
"""

from datetime import date, datetime, timezone
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.external_service_providers.model import ExternalServiceProvider
from modules.import_files.model import ImportFile

# Regulatory Matrix
from modules.regulatory_matrix.model import HsCodeRegulatoryRequirement
from modules.regulatory_matrix.repository import RegulatoryMatrixRepository
from modules.regulatory_matrix.schemas import HsCodeRegulatoryCreate, HsCodeRegulatoryUpdate
from modules.regulatory_matrix.service import RegulatoryMatrixService

# Trade Finance
from modules.trade_finance.model import FxHedgingAndVariance, ImportFinanceInstrument, LcBankCharge
from modules.trade_finance.repository import TradeFinanceRepository
from modules.trade_finance.schemas import (
    FxHedgingAndVarianceCreate,
    FxHedgingAndVarianceUpdate,
    ImportFinanceInstrumentCreate,
    ImportFinanceInstrumentUpdate,
    LcBankChargeCreate,
)
from modules.trade_finance.service import TradeFinanceService

# Broker Custody
from modules.broker_custody.model import (
    BrokerCustodyAdvance,
    BrokerExpenseItem,
    BrokerSettlementReceipt,
    CustomsBrokerAdvance,
)
from modules.broker_custody.repository import BrokerCustodyRepository
from modules.broker_custody.schemas import (
    BrokerCustodyAdvanceCreate,
    BrokerExpenseItemCreate,
    BrokerSettlementReceiptCreate,
    BrokerSettlementReceiptUpdate,
    CustomsBrokerAdvanceCreate,
    CustomsBrokerAdvanceUpdate,
)
from modules.broker_custody.service import BrokerCustodyService


# In-memory test DB
test_engine = create_engine(
    "sqlite:///:memory:",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSession = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)


@pytest.fixture
def db():
    Base.metadata.create_all(bind=test_engine)
    session = TestingSession()

    # Seed broker
    broker = ExternalServiceProvider(
        provider_id=10,
        partner_code="BRK-001",
        partner_name="مكتب الصفا للتخليص الجمركي",
        partner_type="Customs Broker",
        is_active=True,
    )
    session.add(broker)

    # Seed import file
    file = ImportFile(
        import_file_id=101,
        import_file_code="IMP-2026-1001",
        company_name="شركة النيل للصناعات الغذائية",
        supplier_name="Global Trade Corp",
        is_active=True,
    )
    session.add(file)
    session.commit()

    try:
        yield session
    finally:
        session.rollback()
        session.close()
        Base.metadata.drop_all(bind=test_engine)


# ===========================================================================
# 1. Regulatory Matrix Tests
# ===========================================================================
def test_create_regulatory_requirement_success(db):
    service = RegulatoryMatrixService(db)
    payload = HsCodeRegulatoryCreate(
        hs_code="0402.10.00",
        agency_code="NFSA",
        agency_name_ar="الهيئة القومية لسلامة الغذاء",
        agency_name_en="National Food Safety Authority",
        stage_timing="PRE_ARRIVAL",
        required_documents="شهادة صحية بيطرية، شهادة مطابقة، إخطار شحنة مسبق",
        inspection_type="LAB_SAMPLING",
        regulatory_notes="سحب عينات مخبرية للتأكد من خلو الشحنة من السموم الفطرية",
        is_mandatory=True,
    )
    req = service.create_requirement(payload, current_user="admin")
    assert req.id is not None
    assert req.hs_code == "0402.10.00"
    assert req.agency_code == "NFSA"
    assert req.is_mandatory is True
    assert req.is_active is True


def test_create_regulatory_requirement_invalid_hs_code(db):
    service = RegulatoryMatrixService(db)
    payload = HsCodeRegulatoryCreate(
        hs_code="12",  # Too short (< 4 digits)
        agency_code="GOEIC",
        agency_name_ar="الرقابة على الصادرات والواردات",
        agency_name_en="GOEIC",
        stage_timing="PRE_ARRIVAL",
    )
    with pytest.raises(HTTPException) as exc_info:
        service.create_requirement(payload)
    assert exc_info.value.status_code == 422


def test_create_regulatory_requirement_duplicate_conflict(db):
    service = RegulatoryMatrixService(db)
    payload = HsCodeRegulatoryCreate(
        hs_code="8471.30.00",
        agency_code="NTRA",
        agency_name_ar="الجهاز القومي لتنظيم الاتصالات",
        agency_name_en="NTRA",
        stage_timing="PRE_ACID",
    )
    service.create_requirement(payload, current_user="user1")

    # Second creation with identical hs_code + agency + stage_timing must fail
    with pytest.raises(HTTPException) as exc_info:
        service.create_requirement(payload, current_user="user2")
    assert exc_info.value.status_code == 409


def test_list_and_filter_regulatory_matrix(db):
    service = RegulatoryMatrixService(db)
    # Add requirements
    service.create_requirement(
        HsCodeRegulatoryCreate(
            hs_code="8517.12.00",
            agency_code="NTRA",
            agency_name_ar="تنظيم الاتصالات",
            agency_name_en="NTRA",
            stage_timing="PRE_ACID",
        )
    )
    service.create_requirement(
        HsCodeRegulatoryCreate(
            hs_code="0201.10.00",
            agency_code="QUARANTINE",
            agency_name_ar="الحجر البيطري",
            agency_name_en="Veterinary Quarantine",
            stage_timing="CUSTOMS_EXAMINATION",
        )
    )

    # Filter by agency
    items, total = service.list_requirements(agency_code="NTRA")
    assert total == 1
    assert items[0].agency_code == "NTRA"

    # Filter by HS code
    by_hs = service.get_requirements_for_hs_code("0201.10.00")
    assert len(by_hs) == 1
    assert by_hs[0].agency_code == "QUARANTINE"


def test_soft_delete_regulatory_requirement(db):
    service = RegulatoryMatrixService(db)
    req = service.create_requirement(
        HsCodeRegulatoryCreate(
            hs_code="8708.29.00",
            agency_code="EOS",
            agency_name_ar="المواصفات والجودة",
            agency_name_en="EOS",
            stage_timing="CUSTOMS_EXAMINATION",
        )
    )
    service.delete_requirement(req.id, current_user="admin")

    with pytest.raises(HTTPException) as exc_info:
        service.get_requirement(req.id)
    assert exc_info.value.status_code == 404


# ===========================================================================
# 2. Trade Finance Tests
# ===========================================================================
def test_create_finance_instrument_lc(db):
    service = TradeFinanceService(db)
    payload = ImportFinanceInstrumentCreate(
        instrument_type="LC",
        instrument_number="LC-2026-NBE-0089",
        import_file_id=101,
        issuing_bank="البنك الأهلي المصري",
        advising_bank="Commerzbank Frankfurt",
        currency="EUR",
        amount=150000.0,
        issue_date=date(2026, 11, 1),
        expiry_date=date(2027, 2, 1),
        shipment_deadline=date(2027, 1, 15),
        presentation_period_days=21,
        payment_terms="دفع عند الإطلاع مع تعزيز بنكي مؤكد",
        tolerance_percentage=5.0,
    )
    inst = service.create_instrument(payload, current_user="finance_officer")
    assert inst.id is not None
    assert inst.instrument_number == "LC-2026-NBE-0089"
    assert inst.status == "DRAFT"
    assert inst.amount == 150000.0


def test_finance_instrument_date_validation(db):
    service = TradeFinanceService(db)
    # Expiry before issue date must fail
    payload = ImportFinanceInstrumentCreate(
        instrument_type="LC",
        instrument_number="LC-INVALID-DATES",
        import_file_id=101,
        issuing_bank="بنك مصر",
        currency="USD",
        amount=50000.0,
        issue_date=date(2026, 12, 1),
        expiry_date=date(2026, 11, 1),  # Earlier!
    )
    with pytest.raises(HTTPException) as exc_info:
        service.create_instrument(payload)
    assert exc_info.value.status_code == 422


def test_add_bank_charges_to_instrument(db):
    service = TradeFinanceService(db)
    inst = service.create_instrument(
        ImportFinanceInstrumentCreate(
            instrument_type="LC",
            instrument_number="LC-CHARGES-01",
            import_file_id=101,
            issuing_bank="بنك القاهرة",
            currency="USD",
            amount=80000.0,
        )
    )

    charge = service.add_bank_charge(
        inst.id,
        LcBankChargeCreate(
            charge_type="SWIFT_CHARGE",
            currency="USD",
            amount=50.0,
            amount_egp=2450.0,
            debit_date=date(2026, 11, 2),
            swift_reference="SWIFT-MT700-9921",
        ),
        current_user="finance_admin",
    )
    assert charge.id is not None
    assert charge.finance_instrument_id == inst.id
    assert charge.amount_egp == 2450.0

    # Retrieve instrument with charges
    fetched = service.get_instrument(inst.id)
    assert len(fetched.charges) == 1
    assert fetched.charges[0].charge_type == "SWIFT_CHARGE"


def test_fx_hedging_and_variance_calculation(db):
    service = TradeFinanceService(db)
    inst = service.create_instrument(
        ImportFinanceInstrumentCreate(
            instrument_type="LC",
            instrument_number="LC-FX-001",
            import_file_id=101,
            issuing_bank="البنك التجاري الدولي CIB",
            currency="USD",
            amount=100000.0,
        )
    )

    # 1. Initial Booking at rate 49.00
    fx_payload = FxHedgingAndVarianceCreate(
        foreign_currency="USD",
        original_amount=100000.0,
        booking_date=date(2026, 11, 1),
        booking_rate=49.00,
    )
    fx = service.add_fx_record(inst.id, fx_payload, current_user="treasury_mgr")
    assert fx.booking_total_egp == 4900000.0
    assert fx.variance_amount_egp == 0.0
    assert fx.variance_nature == "NEUTRAL"

    # 2. Settlement with rate increase to 50.25 (Loss)
    updated = service.update_fx_record(
        fx.id,
        FxHedgingAndVarianceUpdate(
            settlement_date=date(2026, 12, 1),
            settlement_rate=50.25,
        ),
    )
    assert updated.settlement_total_egp == 5025000.0
    assert updated.variance_amount_egp == 125000.0  # 5,025,000 - 4,900,000
    assert updated.variance_nature == "UNFAVORABLE_LOSS"

    # 3. Settlement with rate decrease to 48.50 (Gain)
    gain_updated = service.update_fx_record(
        fx.id,
        FxHedgingAndVarianceUpdate(
            settlement_rate=48.50,
        ),
    )
    assert gain_updated.variance_amount_egp == -50000.0  # 4,850,000 - 4,900,000
    assert gain_updated.variance_nature == "FAVORABLE_GAIN"


# ===========================================================================
# 3. Customs Broker Advances & Receipts Tests
# ===========================================================================
def test_create_customs_broker_advance(db):
    service = BrokerCustodyService(db)
    payload = CustomsBrokerAdvanceCreate(
        import_file_id=101,
        broker_id=10,
        advance_amount=50000.0,
        disbursement_date=date(2026, 11, 1),
        payment_method="BANK_TRANSFER",
        notes="دفعة عهدة أولى لسداد الرسوم الجمركية ومصاريف الفحص",
    )
    adv = service.create_customs_advance(payload, current_user="accountant")
    assert adv.id is not None
    assert adv.advance_code.startswith("CADV-")
    assert adv.advance_amount == 50000.0
    assert adv.remaining_balance == 50000.0
    assert adv.status == "OPEN"
    assert adv.broker_name == "مكتب الصفا للتخليص الجمركي"


def test_add_white_red_and_broker_fee_receipts_and_reconciliation(db):
    service = BrokerCustodyService(db)
    adv = service.create_customs_advance(
        CustomsBrokerAdvanceCreate(
            import_file_id=101,
            broker_id=10,
            advance_amount=60000.0,
            disbursement_date=date(2026, 11, 1),
        )
    )

    # 1. White Receipt (Customs duties: 30,000 EGP, 0% WHT)
    r_white = service.add_settlement_receipt(
        adv.id,
        BrokerSettlementReceiptCreate(
            receipt_type="WHITE_RECEIPT_CUSTOMS_DUTIES",
            receipt_number="EGP-CUST-88319",
            receipt_date=date(2026, 11, 2),
            issuing_entity="مصلحة الجمارك المصرية - جمرك الإسكندرية",
            amount=30000.0,
            tax_withholding_rate=0.0,
        ),
    )
    assert r_white.net_amount == 30000.0

    # Verify advance status is now PARTIALLY_SETTLED
    adv_fetched = service.get_customs_advance(adv.id)
    assert adv_fetched.status == "PARTIALLY_SETTLED"
    assert adv_fetched.settled_amount == 30000.0
    assert adv_fetched.remaining_balance == 30000.0

    # 2. Red Receipt (Inspection & examination: 5,000 EGP)
    service.add_settlement_receipt(
        adv.id,
        BrokerSettlementReceiptCreate(
            receipt_type="RED_RECEIPT_EXAMINATION_INSPECTION",
            receipt_number="EXAM-RED-4421",
            receipt_date=date(2026, 11, 3),
            issuing_entity="هيئة الرقابة على الصادرات والواردات",
            amount=5000.0,
            tax_withholding_rate=0.0,
        ),
    )

    # 3. Broker Service Fee Invoice (10,000 EGP with 1% Form 41 WHT = 100 EGP tax, net = 9,900 EGP)
    r_fee = service.add_settlement_receipt(
        adv.id,
        BrokerSettlementReceiptCreate(
            receipt_type="BROKER_SERVICE_FEE",
            receipt_number="INV-BRK-2026-90",
            receipt_date=date(2026, 11, 4),
            issuing_entity="مكتب الصفا للتخليص الجمركي",
            amount=10000.0,
            tax_withholding_rate=0.01,
        ),
    )
    assert r_fee.tax_withheld_amount == 100.0
    assert r_fee.net_amount == 9900.0

    # 4. Port Authority Receipt (15,100 EGP) -> Total net settled = 30000 + 5000 + 9900 + 15100 = 60,000 EGP
    service.add_settlement_receipt(
        adv.id,
        BrokerSettlementReceiptCreate(
            receipt_type="PORT_AUTHORITY_RECEIPT",
            receipt_number="PORT-ALX-7712",
            receipt_date=date(2026, 11, 4),
            issuing_entity="هيئة ميناء الإسكندرية",
            amount=15100.0,
            tax_withholding_rate=0.0,
        ),
    )

    # Check that advance is fully settled
    adv_final = service.get_customs_advance(adv.id)
    assert adv_final.settled_amount == 60000.0
    assert adv_final.remaining_balance == 0.0
    assert adv_final.status == "SETTLED"

    # Reconciliation report
    recon = service.reconcile_customs_settlement(adv.id)
    assert recon.advance_amount == 60000.0
    assert recon.total_tax_withheld == 100.0
    assert recon.total_net_settled == 60000.0
    assert recon.variance_amount == 0.0
    assert recon.white_receipts_total == 30000.0
    assert recon.red_receipts_total == 5000.0
    assert recon.port_receipts_total == 15100.0
    assert recon.broker_fees_total == 9900.0


def test_legacy_broker_custody_compatibility(db):
    """Ensures existing BrokerCustodyAdvance and BrokerExpenseItem continue to work 100%"""
    service = BrokerCustodyService(db)
    legacy_adv = service.create_advance(
        BrokerCustodyAdvanceCreate(
            import_file_id=101,
            broker_id=10,
            advance_amount=20000.0,
            disbursement_date=date(2026, 11, 1),
            payment_method="BANK_TRANSFER",
        )
    )
    assert legacy_adv.advance_id is not None
    assert legacy_adv.advance_code.startswith("ADV-")

    # Add legacy expense
    item = service.add_expense_item(
        legacy_adv.advance_id,
        BrokerExpenseItemCreate(
            expense_category="OFFICIAL_DUTIES_TAXES",
            amount=5000.0,
            tax_withholding_rate=0.01,
            approval_status="APPROVED",
        ),
    )
    assert item.item_id is not None
    assert item.net_settled_amount == 4950.0

    recon = service.reconcile_settlement(legacy_adv.advance_id)
    assert recon.total_expenses_claimed == 5000.0
    assert recon.total_tax_withheld_w41 == 50.0
    assert recon.total_net_settled == 4950.0
