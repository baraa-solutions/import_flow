"""
SQLAlchemy models of the air freight suite.

- ``air_shipment_records``: one Air Waybill (master AWB, optional house AWB) of an import file, the air
  counterpart of ``cargo_shipping_records``. Airline and airports are master-data FKs (GP-003), weights are
  stored with their components (gross, volumetric, chargeable, divisor) and the package lines they came from.
- ``draft_awb_review_sessions``: one review of a draft AWB against the shipment record (counterpart of
  ``draft_bl_review_sessions``): the comparison checklist, blocking reasons and approval.

Both tables soft-delete (``is_active`` / ``deleted_at`` / ``deleted_by``); nothing cascades on delete.
"""
from datetime import datetime, timezone

from sqlalchemy import (
    JSON,
    Boolean,
    Column,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    text,
)

from database.database import Base


def _now() -> datetime:
    return datetime.now(timezone.utc)


class AirShipmentRecord(Base):
    __tablename__ = "air_shipment_records"

    air_record_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    air_record_code = Column(String(30), nullable=False, unique=True, index=True)  # AWB-000001

    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=False, index=True)

    # Taxonomy (modules/common/shipment_modes): mode AIR / COURIER + optional sub-mode.
    shipment_mode = Column(String(20), nullable=False, default="AIR", server_default=text("'AIR'"))
    shipment_sub_mode = Column(String(30), nullable=True)

    # Air Waybill identifiers. MAWB = 11 digits (3-digit airline prefix + 7-digit serial + mod-7 check digit).
    mawb_number = Column(String(11), nullable=True)
    hawb_number = Column(String(50), nullable=True)
    airline_prefix = Column(String(3), nullable=True, index=True)

    airline_id = Column(Integer, ForeignKey("external_service_providers.provider_id"), nullable=True, index=True)
    origin_airport_id = Column(Integer, ForeignKey("transport_locations.location_id"), nullable=True, index=True)
    destination_airport_id = Column(Integer, ForeignKey("transport_locations.location_id"), nullable=True, index=True)

    flight_number = Column(String(20), nullable=True)
    flight_date = Column(Date, nullable=True)
    arrival_date = Column(Date, nullable=True)

    # Measurements (kg / CBM). Weight components are kept, not only the chargeable figure.
    pieces_count = Column(Integer, nullable=True)
    gross_weight_kg = Column(Float, nullable=True)
    volume_cbm = Column(Float, nullable=True)
    volumetric_weight_kg = Column(Float, nullable=True)
    chargeable_weight_kg = Column(Float, nullable=True)
    volumetric_divisor = Column(Float, nullable=True)
    package_lines = Column(JSON, nullable=True)  # [{length, width, height, dimension_unit, quantity, gross_weight, weight_unit}]

    # Airport release & storage.
    air_release_no = Column(String(100), nullable=True)
    airport_storage_start_date = Column(Date, nullable=True)
    free_storage_days = Column(Integer, nullable=True)

    goods_description = Column(Text, nullable=True)
    notes = Column(Text, nullable=True)

    is_active = Column(Boolean, nullable=False, default=True, server_default=text("1"), index=True)
    created_at = Column(DateTime, nullable=False, default=_now)
    updated_at = Column(DateTime, nullable=False, default=_now, onupdate=_now)
    created_by = Column(String(100), nullable=True)
    updated_by = Column(String(100), nullable=True)
    deleted_at = Column(DateTime, nullable=True)
    deleted_by = Column(String(100), nullable=True)

    __table_args__ = (
        # One master AWB is one physical consignment; NULL (not known yet) repeats freely.
        UniqueConstraint("mawb_number", "hawb_number", name="uq_air_shipment_records_mawb_hawb"),
    )


class DraftAwbReviewSession(Base):
    __tablename__ = "draft_awb_review_sessions"

    awb_review_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    awb_review_code = Column(String(30), nullable=False, unique=True, index=True)  # AWBR-000001

    air_record_id = Column(Integer, ForeignKey("air_shipment_records.air_record_id"), nullable=False, index=True)
    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=False, index=True)

    version_number = Column(Integer, nullable=False, default=1)
    draft_awb_number = Column(String(20), nullable=True)

    draft_input_data = Column(JSON, nullable=True)  # the draft as entered
    system_snapshot_data = Column(JSON, nullable=True)  # reference values at review time
    checklist_data = Column(JSON, nullable=True)  # [{check, status, draft_value, system_value, blocking}]
    blocking_reasons_coded = Column(JSON, nullable=True)  # [{code, params}]
    has_blocking_mismatch = Column(Boolean, nullable=False, default=False)
    open_discrepancies_count = Column(Integer, nullable=False, default=0)

    # REVISION_REQUIRED | REVIEWED | APPROVED | REJECTED
    status = Column(String(30), nullable=False, default="REVIEWED", index=True)
    reviewed_by = Column(String(100), nullable=True)
    reviewed_at = Column(DateTime, nullable=True)
    approved_by = Column(String(100), nullable=True)
    approved_at = Column(DateTime, nullable=True)
    decision_notes = Column(Text, nullable=True)

    is_active = Column(Boolean, nullable=False, default=True, server_default=text("1"), index=True)
    created_at = Column(DateTime, nullable=False, default=_now)
    updated_at = Column(DateTime, nullable=False, default=_now, onupdate=_now)
    created_by = Column(String(100), nullable=True)
    updated_by = Column(String(100), nullable=True)
    deleted_at = Column(DateTime, nullable=True)
    deleted_by = Column(String(100), nullable=True)
