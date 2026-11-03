"""
SQLAlchemy Model for Cargo Claims, Time-Bars & Legal Reservations
(رادار مواعيد المطالبات القانونية وسقوط حق الدعوى والتأمين ومحاضر المعاينة)
Covers:
- Time-Bars (سقوط حق الدعوى بالتقادم - سنة واحدة بحري Art. 244)
- Latent Damage Notice (إخطار العيب الخفي / التلف المستتر - مهلة 3 أيام للخط الملاحي)
- Apparent Damage Notice (إخطار التلف الظاهر - فوري عند التسليم)
- Official Reservation Letters (خطابات التحفظ الرسمية)
- Joint Survey Reports (محاضر المعاينة المشتركة)
- Cargo Claims & Insurance Recoveries (مطالبات التعويض والتسويات)
"""

from datetime import datetime, timezone
from sqlalchemy import (
    Column,
    Integer,
    String,
    Text,
    Boolean,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Index,
    func,
    text,
)
from sqlalchemy.orm import relationship
from database.database import Base


class CargoClaimAndReservation(Base):
    """
    Tracks statutory legal notice time-bars, carrier latent/apparent damage notices,
    joint survey scheduling, official reservation letters, and recovery claims
    against shipping lines, freight forwarders, port terminals, and cargo underwriters.
    """

    __tablename__ = "cargo_claims_and_reservations"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    claim_code = Column(String(50), nullable=False, unique=True, index=True)
    import_file_id = Column(
        Integer,
        ForeignKey("import_files.import_file_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    shipment_id = Column(Integer, nullable=True)

    # Claim Category: CARRIER_DAMAGE, CARRIER_SHORTAGE, PORT_DAMAGE, INSURANCE_RECOVERY, GENERAL_AVERAGE
    claim_type = Column(String(50), nullable=False, index=True)
    # Damage Nature: APPARENT (ظاهر), LATENT (مستتر / خفي)
    damage_nature = Column(String(30), nullable=False)

    # Statutory Timelines & Deadlines
    delivery_date = Column(Date, nullable=True)
    latent_notice_deadline = Column(Date, nullable=True)  # Delivery + 3 days
    apparent_notice_date = Column(Date, nullable=True)
    time_bar_statute_of_limitations_date = Column(Date, nullable=False, index=True)  # Delivery + 1 year

    # Claim Status: DRAFT, RESERVATION_ISSUED, SURVEY_SCHEDULED, SURVEY_COMPLETED, CLAIM_SUBMITTED, SETTLED, REJECTED, TIME_BARRED
    status = Column(
        String(50),
        nullable=False,
        default="RESERVATION_ISSUED",
        server_default=text("'RESERVATION_ISSUED'"),
        index=True,
    )

    # Reservation Letter Details
    reservation_letter_ref = Column(String(100), nullable=True)
    reservation_letter_date = Column(Date, nullable=True)
    target_party = Column(String(100), nullable=False)  # Shipping Line / Forwarder / Port Terminal / Insurer

    # Joint Survey (المعاينة المشتركة)
    survey_requested = Column(Boolean, nullable=False, default=False, server_default=text("0"))
    survey_date = Column(Date, nullable=True)
    surveyor_company = Column(String(150), nullable=True)
    survey_report_ref = Column(String(100), nullable=True)

    # Financial Claim & Settlement
    claimed_amount = Column(Float, nullable=False, default=0.0, server_default=text("0.0"))
    claimed_currency = Column(
        String(10),
        nullable=False,
        default="USD",
        server_default=text("'USD'"),
    )
    settled_amount = Column(Float, nullable=False, default=0.0, server_default=text("0.0"))
    settlement_date = Column(Date, nullable=True)

    # Operational Notes
    notes = Column(Text, nullable=True)

    # Audit & Soft Delete
    is_deleted = Column(Boolean, nullable=False, default=False, server_default=text("0"), index=True)
    created_at = Column(
        DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
    )
    updated_at = Column(
        DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
    )
    created_by_user_id = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True)
    updated_by_user_id = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True)

    # Relationships
    import_file = relationship("ImportFile", foreign_keys=[import_file_id])
