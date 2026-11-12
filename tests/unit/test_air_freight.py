"""Air freight suite (Trello 6wcX4CQ6): shipment mode / sub-mode taxonomy, divisor-based volumetric and
chargeable weight with unit conversion, AWB number validation, AWB records (validation, duplicates, soft
delete / restore), airport storage counter and the draft AWB review engine."""
from datetime import date

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main  # noqa: F401  (registers every model on Base)
from database.database import Base
from modules.air_freight import service as svc
from modules.air_freight import validators as val
from modules.air_freight.schemas import (
    AirPackageLine,
    AirShipmentRecordCreate,
    AirShipmentRecordUpdate,
    ChargeableWeightRequest,
    DraftAwbInput,
    DraftAwbReviewCreate,
    DraftAwbReviewDecision,
)
from modules.common import cargo_math, shipment_modes
from modules.common import system_parameters as sp
from modules.common.errors import CodedHTTPException
from modules.external_service_providers.model import ExternalServiceProvider
from modules.import_files.model import ImportFile
from modules.transport_locations.model import TransportLocation

VALID_AWB = "17612345675"  # serial 1234567 mod 7 = 5


@pytest.fixture
def db():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    session = sessionmaker(bind=engine)()
    session.add_all([
        ImportFile(import_file_id=1, import_file_code="IMP-2026-001", company_name="Sorour Logistics",
                   supplier_name="Shenzhen Audio Co"),
        TransportLocation(location_id=1, un_locode="CNSZX", location_name="Shenzhen Bao'an", location_type="Airport",
                          country="China", city="Shenzhen"),
        TransportLocation(location_id=2, un_locode="EGCAI", location_name="Cairo International",
                          location_type="Airport", country="Egypt", city="Cairo"),
        TransportLocation(location_id=3, un_locode="EGALY", location_name="Alexandria Port", location_type="Sea Port",
                          country="Egypt", city="Alexandria"),
        ExternalServiceProvider(provider_id=1, partner_code="PRT-000001", partner_name="Emirates SkyCargo",
                                partner_type="Airline"),
    ])
    session.commit()
    yield session
    session.close()
    engine.dispose()


def _code(exc_info) -> str:
    return exc_info.value.detail["code"]


def _record(db, **overrides):
    data = dict(import_file_id=1, mawb_number="176-1234 5675", airline_id=1, origin_airport_id=1,
                destination_airport_id=2, pieces_count=2, gross_weight_kg=40.0)
    data.update(overrides)
    return svc.create_air_record(db, AirShipmentRecordCreate(**data), "agent")


# ── Shipment mode taxonomy (mode + sub_mode, no flat ACID codes) ─────────────

@pytest.mark.parametrize("legacy, expected", [
    ("Sea FCL", ("SEA", "FCL")),
    ("Sea LCL", ("SEA", "LCL")),
    ("Air", ("AIR", None)),
    ("Courier", ("COURIER", None)),
    ("Land", ("LAND", None)),
    ("Multimodal", ("MULTIMODAL", None)),
    ("ocean", ("SEA", None)),
    ("Sea Break Bulk", ("SEA", "BREAK_BULK")),
    ("", (None, None)),
    (None, (None, None)),
    ("Rail", (None, None)),
])
def test_split_legacy_mode(legacy, expected):
    assert shipment_modes.split_legacy_mode(legacy) == expected


def test_validate_mode_pair_accepts_codes_and_rejects_foreign_sub_mode():
    assert shipment_modes.validate_mode_pair("air", "general cargo") == ("AIR", "GENERAL_CARGO")
    assert shipment_modes.validate_mode_pair("SEA", None) == ("SEA", None)
    with pytest.raises(ValueError):
        shipment_modes.validate_mode_pair("AIR", "FCL")
    with pytest.raises(ValueError):
        shipment_modes.validate_mode_pair(None, None)
    with pytest.raises(ValueError):
        shipment_modes.normalize_mode("Rail")


def test_acid_status_is_not_part_of_the_taxonomy():
    every_code = set(shipment_modes.MODES) | {s for subs in shipment_modes.SUB_MODES.values() for s in subs}
    assert not any("EXEMPT" in c or "COMMERCIAL" in c for c in every_code)
    assert shipment_modes.is_weight_billed("Courier") and not shipment_modes.is_weight_billed("Sea FCL")


# ── Unit conversion & volumetric weight ──────────────────────────────────────

def test_weight_units():
    assert cargo_math.to_kg(100, "lb") == pytest.approx(45.359237)
    assert cargo_math.to_kg(10, "KGS") == 10
    assert cargo_math.normalize_weight_unit(None) == "kg"
    with pytest.raises(ValueError):
        cargo_math.normalize_weight_unit("ton")


@pytest.mark.parametrize("dims, unit", [((100, 50, 60), "cm"), ((1000, 500, 600), "mm"), ((1, 0.5, 0.6), "m")])
def test_divisor_volumetric_weight_is_unit_independent(dims, unit):
    assert cargo_math.divisor_volumetric_weight_kg(*dims, unit, 2, 6000) == pytest.approx(100.0)


@pytest.mark.parametrize("dims, qty, divisor", [((0, 50, 60), 1, 6000), ((10, 10, 10), 0, 6000), ((10, 10, 10), 1, 0)])
def test_divisor_volumetric_weight_unknown_inputs_give_zero(dims, qty, divisor):
    assert cargo_math.divisor_volumetric_weight_kg(*dims, "cm", qty, divisor) == 0.0


def test_chargeable_weight_volumetric_wins():
    result = svc.compute_chargeable_weight([AirPackageLine(length=100, width=50, height=60, quantity=2, gross_weight=20)], 6000)
    assert (result.gross_weight_kg, result.volumetric_weight_kg, result.chargeable_weight_kg) == (40.0, 100.0, 100.0)
    assert result.basis == "VOLUMETRIC" and result.pieces_count == 2 and result.volume_cbm == 0.6


def test_chargeable_weight_gross_wins_with_lb_and_courier_divisor():
    line = AirPackageLine(length=20, width=20, height=20, quantity=1, gross_weight=22.0462, weight_unit="lb")
    result = svc.compute_chargeable_weight([line], 5000, "COURIER")
    assert result.volumetric_weight_kg == 1.6 and result.gross_weight_kg == 10.0
    assert result.chargeable_weight_kg == 10.0 and result.basis == "GROSS"


def test_chargeable_weight_uses_total_gross_when_packages_are_not_weighed():
    result = svc.compute_chargeable_weight([AirPackageLine(length=10, width=10, height=10)], 6000, total_gross_weight_kg=5)
    assert result.gross_weight_kg == 5 and result.chargeable_weight_kg == 5


def test_chargeable_weight_rejects_non_positive_divisor():
    with pytest.raises(ValueError):
        svc.compute_chargeable_weight([], 0)


def test_calculate_uses_configured_divisors(db):
    pkg = [AirPackageLine(length=100, width=100, height=100)]
    assert svc.calculate_chargeable_weight(db, ChargeableWeightRequest(packages=pkg)).divisor == 6000
    assert svc.calculate_chargeable_weight(db, ChargeableWeightRequest(shipment_mode="COURIER", packages=pkg)).divisor == 5000
    db.add(sp.SystemParameter(param_key=sp.AIR_VOLUMETRIC_DIVISOR, param_value="5000"))
    db.commit()
    assert svc.calculate_chargeable_weight(db, ChargeableWeightRequest(packages=pkg)).volumetric_weight_kg == 200.0
    override = ChargeableWeightRequest(packages=pkg, divisor=4000)
    assert svc.calculate_chargeable_weight(db, override).volumetric_weight_kg == 250.0
    with pytest.raises(CodedHTTPException) as exc:
        svc.calculate_chargeable_weight(db, ChargeableWeightRequest(shipment_mode="SEA", packages=pkg))
    assert _code(exc) == "AIR_MODE_INVALID"


def test_parameter_defaults_equal_module_constants():
    pairs = {
        sp.AIR_VOLUMETRIC_DIVISOR: sp.DEFAULT_AIR_VOLUMETRIC_DIVISOR,
        sp.COURIER_VOLUMETRIC_DIVISOR: sp.DEFAULT_COURIER_VOLUMETRIC_DIVISOR,
        sp.AIR_FREE_STORAGE_DAYS: sp.DEFAULT_AIR_FREE_STORAGE_DAYS,
        sp.AIR_AWB_WEIGHT_TOLERANCE_PCT: sp.DEFAULT_AIR_AWB_WEIGHT_TOLERANCE_PCT,
    }
    for key, constant in pairs.items():
        assert float(sp.DEFAULT_PARAMETERS[key][0]) == constant, key


# ── AWB number ───────────────────────────────────────────────────────────────

@pytest.mark.parametrize("raw, expected", [
    ("17612345675", ("17612345675", "176", None)),
    ("176-1234 5675", ("17612345675", "176", None)),
    ("176-12345676", (None, None, "AIR_AWB_CHECK_DIGIT_INVALID")),
    ("176-1234567", (None, None, "AIR_AWB_FORMAT_INVALID")),
    ("176-1234567A", (None, None, "AIR_AWB_FORMAT_INVALID")),
    ("  ", (None, None, None)),
    (None, (None, None, None)),
])
def test_parse_awb_number(raw, expected):
    assert val.parse_awb_number(raw) == expected


def test_format_awb_number():
    assert val.format_awb_number(VALID_AWB) == "176-12345675"


# ── AWB records ──────────────────────────────────────────────────────────────

def test_create_record_normalises_and_derives_weights(db):
    rec = _record(db, package_lines=[{"length": 1, "width": 0.5, "height": 0.6, "dimension_unit": "m",
                                      "quantity": 2, "gross_weight": 20}])
    assert rec.air_record_code == "AWB-000001"
    assert (rec.mawb_number, rec.airline_prefix, rec.shipment_mode) == (VALID_AWB, "176", "AIR")
    assert (rec.pieces_count, rec.gross_weight_kg, rec.volumetric_weight_kg, rec.chargeable_weight_kg) == (2, 40.0, 100.0, 100.0)
    assert rec.volumetric_divisor == 6000 and rec.volume_cbm == 0.6 and rec.created_by == "agent"


def test_record_without_packages_charges_gross(db):
    rec = _record(db, mawb_number=None, package_lines=None)
    assert rec.chargeable_weight_kg == 40.0 and rec.volumetric_weight_kg is None and rec.mawb_number is None


def test_progressive_entry_allows_empty_record(db):
    rec = svc.create_air_record(db, AirShipmentRecordCreate(import_file_id=1, shipment_mode="Courier",
                                                            shipment_sub_mode="express"), "agent")
    assert (rec.shipment_mode, rec.shipment_sub_mode, rec.chargeable_weight_kg) == ("COURIER", "EXPRESS", None)


@pytest.mark.parametrize("overrides, code", [
    ({"import_file_id": 99}, "AIR_IMPORT_FILE_NOT_FOUND"),
    ({"mawb_number": "176-12345676"}, "AIR_AWB_CHECK_DIGIT_INVALID"),
    ({"shipment_mode": "Sea FCL"}, "AIR_MODE_INVALID"),
    ({"shipment_sub_mode": "FCL"}, "AIR_SUB_MODE_INVALID"),
    ({"destination_airport_id": 3}, "AIR_LOCATION_NOT_AIRPORT"),
    ({"origin_airport_id": 42}, "AIR_AIRPORT_NOT_FOUND"),
    ({"destination_airport_id": 1}, "AIR_SAME_AIRPORTS"),
    ({"airline_id": 42}, "AIR_AIRLINE_NOT_FOUND"),
    ({"flight_date": date(2026, 11, 10), "arrival_date": date(2026, 11, 9)}, "AIR_DATES_INVALID"),
])
def test_create_record_validation(db, overrides, code):
    with pytest.raises(CodedHTTPException) as exc:
        _record(db, **overrides)
    assert _code(exc) == code


def test_duplicate_awb_detected_including_soft_deleted(db):
    first = _record(db)
    with pytest.raises(CodedHTTPException) as exc:
        _record(db, mawb_number="17612345675")
    assert _code(exc) == "AIR_AWB_DUPLICATE" and exc.value.detail["air_record_code"] == first.air_record_code
    assert _record(db, hawb_number="HAWB-1").hawb_number == "HAWB-1"  # same master, different house
    svc.soft_delete_air_record(db, first.air_record_id, "agent")
    with pytest.raises(CodedHTTPException):
        _record(db)


def test_soft_delete_and_restore(db):
    rec = _record(db)
    deleted = svc.soft_delete_air_record(db, rec.air_record_id, "boss")
    assert deleted.is_active is False and deleted.deleted_by == "boss" and deleted.deleted_at is not None
    assert svc.list_air_records(db, 1) == []
    assert len(svc.list_air_records(db, 1, include_inactive=True)) == 1
    with pytest.raises(CodedHTTPException) as exc:
        svc.get_air_record(db, rec.air_record_id)
    assert _code(exc) == "AIR_RECORD_NOT_FOUND"
    restored = svc.restore_air_record(db, rec.air_record_id, "boss")
    assert restored.is_active is True and restored.deleted_at is None


def test_update_recomputes_weights_and_mode_divisor(db):
    rec = _record(db, package_lines=[{"length": 100, "width": 50, "height": 60, "quantity": 2, "gross_weight": 20}])
    updated = svc.update_air_record(db, rec.air_record_id, AirShipmentRecordUpdate(shipment_mode="COURIER"), "boss")
    assert updated.volumetric_divisor == 5000 and updated.volumetric_weight_kg == 120.0
    assert updated.chargeable_weight_kg == 120.0 and updated.mawb_number == VALID_AWB and updated.updated_by == "boss"
    cleared = svc.update_air_record(db, rec.air_record_id, AirShipmentRecordUpdate(package_lines=[]), "boss")
    assert cleared.volumetric_weight_kg is None and cleared.chargeable_weight_kg == 40.0


# ── Airport storage counter ──────────────────────────────────────────────────

@pytest.mark.parametrize("on, state, remaining, chargeable", [
    (date(2026, 11, 9), "NOT_STARTED", None, 0),
    (date(2026, 11, 10), "FREE", 2, 0),
    (date(2026, 11, 12), "LAST_DAY", 0, 0),
    (date(2026, 11, 15), "CHARGEABLE", -3, 3),
])
def test_storage_status(on, state, remaining, chargeable):
    s = svc.compute_storage_status(date(2026, 11, 10), 3, on)
    assert (s.status, s.days_remaining, s.chargeable_days) == (state, remaining, chargeable)
    if state != "NOT_STARTED":
        assert s.free_until == date(2026, 11, 12)


def test_storage_zero_free_days_charges_from_day_one():
    s = svc.compute_storage_status(date(2026, 11, 10), 0, date(2026, 11, 10))
    assert s.status == "CHARGEABLE" and s.chargeable_days == 1


def test_storage_uses_configured_default(db):
    rec = _record(db, airport_storage_start_date=date(2026, 11, 10))
    assert svc.storage_status_of(db, rec, date(2026, 11, 12)).status == "LAST_DAY"
    assert svc.compute_storage_status(None, 3, date(2026, 11, 12)).status == "NOT_STARTED"


# ── Draft AWB review engine ──────────────────────────────────────────────────

def _good_draft(**overrides) -> DraftAwbInput:
    data = dict(awb_number="176-12345675", shipper_name="Shenzhen Audio Co.", consignee_name="SOROUR LOGISTICS",
                origin_airport_code="SZX", destination_airport_code="EGCAI", pieces_count=2, gross_weight_kg=40.1,
                chargeable_weight_kg=100.0, goods_description="Audio equipment")
    data.update(overrides)
    return DraftAwbInput(**data)


@pytest.fixture
def air_record(db):
    return _record(db, goods_description="Audio equipment",
                   package_lines=[{"length": 100, "width": 50, "height": 60, "quantity": 2, "gross_weight": 20}])


def test_clean_draft_is_reviewed_without_blockers(db, air_record):
    review = svc.create_review(db, DraftAwbReviewCreate(air_record_id=air_record.air_record_id, draft=_good_draft()), "agent")
    assert review.status == "REVIEWED" and review.has_blocking_mismatch is False and review.open_discrepancies_count == 0
    assert review.awb_review_code == "AWBR-000001" and review.version_number == 1
    assert all(item["status"] == "MATCH" for item in review.checklist_data)
    approved = svc.decide_review(db, review.awb_review_id, DraftAwbReviewDecision(decision="APPROVE"), "boss")
    assert approved.status == "APPROVED" and approved.approved_by == "boss"
    with pytest.raises(CodedHTTPException) as exc:
        svc.decide_review(db, review.awb_review_id, DraftAwbReviewDecision(decision="REJECT"), "boss")
    assert _code(exc) == "AIR_REVIEW_ALREADY_DECIDED"


def test_blocking_mismatches_require_revision_and_block_approval(db, air_record):
    draft = _good_draft(awb_number="176-12345676", consignee_name="Another Trading", pieces_count=3,
                        gross_weight_kg=45, chargeable_weight_kg=130, destination_airport_code="ALY")
    review = svc.create_review(db, DraftAwbReviewCreate(air_record_id=air_record.air_record_id, draft=draft), "agent")
    codes = [r["code"] for r in review.blocking_reasons_coded]
    assert review.status == "REVISION_REQUIRED" and review.open_discrepancies_count == 6
    assert codes.count("AIR_REVIEW_WEIGHT_OUT_OF_TOLERANCE") == 2
    assert "AIR_AWB_CHECK_DIGIT_INVALID" in codes and codes.count("AIR_REVIEW_FIELD_MISMATCH") == 3
    with pytest.raises(CodedHTTPException) as exc:
        svc.decide_review(db, review.awb_review_id, DraftAwbReviewDecision(decision="APPROVE"), "boss")
    assert _code(exc) == "AIR_REVIEW_BLOCKING_MISMATCH"
    second = svc.create_review(db, DraftAwbReviewCreate(air_record_id=air_record.air_record_id, draft=_good_draft()), "agent")
    assert second.version_number == 2
    assert [r.version_number for r in svc.list_reviews(db, air_record.air_record_id)] == [2, 1]


def test_warnings_do_not_block():
    reference = {"awb_number": VALID_AWB, "consignee_name": "Sorour Logistics", "shipper_name": "Shenzhen Audio",
                 "origin_airport_code": "CNSZX", "destination_airport_code": "EGCAI", "pieces_count": 2,
                 "gross_weight_kg": 40.0, "chargeable_weight_kg": 100.0, "goods_description": "Audio equipment"}
    draft = _good_draft(shipper_name="Totally Different Exporter", chargeable_weight_kg=90,
                        goods_description="Steel pipes", gross_weight_kg=40.0)
    checklist, blocking = svc.review_draft_awb(draft, reference, 0.5)
    by_check = {c["check"]: c for c in checklist}
    assert blocking == []
    assert by_check["shipper_name"]["status"] == "WARNING"
    assert by_check["chargeable_weight_kg"]["status"] == "WARNING"  # under-declared: not an overcharge
    assert by_check["goods_description"]["status"] == "WARNING"


def test_missing_draft_fields_block_and_unknown_reference_warns():
    reference = {"awb_number": None, "consignee_name": "Sorour Logistics", "pieces_count": None,
                 "gross_weight_kg": None, "chargeable_weight_kg": None,
                 "origin_airport_code": None, "destination_airport_code": "EGCAI"}
    checklist, blocking = svc.review_draft_awb(DraftAwbInput(awb_number=VALID_AWB, pieces_count=2), reference, 0.5)
    missing = {r["params"]["field"] for r in blocking if r["code"] == "AIR_REVIEW_FIELD_MISSING"}
    assert missing == {"consignee_name", "origin_airport_code", "destination_airport_code", "gross_weight_kg"}
    assert {c["check"]: c["status"] for c in checklist}["awb_number"] == "WARNING"


@pytest.mark.parametrize("draft, locode, ok", [("CAI", "EGCAI", True), ("egcai", "EGCAI", True), ("ALY", "EGCAI", False),
                                               ("", "EGCAI", False)])
def test_airport_code_matches(draft, locode, ok):
    assert svc.airport_code_matches(draft, locode) is ok


def test_review_of_unknown_record_and_review(db):
    with pytest.raises(CodedHTTPException) as exc:
        svc.create_review(db, DraftAwbReviewCreate(air_record_id=99, draft=_good_draft()), "agent")
    assert _code(exc) == "AIR_RECORD_NOT_FOUND"
    with pytest.raises(CodedHTTPException) as exc:
        svc.decide_review(db, 99, DraftAwbReviewDecision(decision="APPROVE"), "agent")
    assert _code(exc) == "AIR_REVIEW_NOT_FOUND"
