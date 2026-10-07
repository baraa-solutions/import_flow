from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, Date, DateTime, Numeric, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from database.database import Base


# ==================================================
# MD-004: Currencies & Exchange Rates Master
# ==================================================

class Currency(Base):

    __tablename__ = "currencies"

    # Primary Key
    currency_id = Column(Integer, primary_key=True, autoincrement=True, index=True)

    # ISO 4217 Currency Code (e.g. EGP, USD, EUR, GBP, CNY, JPY, SAR, AED, CHF)
    currency_code = Column(String(3), nullable=False, unique=True, index=True)

    # Details
    currency_name = Column(String(100), nullable=False)
    currency_symbol = Column(String(10), nullable=False)
    is_base_currency = Column(Boolean, default=False, nullable=False)  # EGP is Base Currency
    decimal_places = Column(Integer, default=2, nullable=False)

    # Soft Delete
    is_active = Column(Boolean, default=True, nullable=False)

    # Audit Trail
    created_by = Column(String(100), nullable=True)
    updated_by = Column(String(100), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # Relationships
    exchange_rates = relationship("ExchangeRate", back_populates="currency", cascade="all, delete-orphan")


class ExchangeRate(Base):

    __tablename__ = "exchange_rates"

    # Primary Key
    rate_id = Column(Integer, primary_key=True, autoincrement=True, index=True)

    # Foreign Key
    currency_id = Column(Integer, ForeignKey("currencies.currency_id"), nullable=False, index=True)

    # Rates against Base Currency (EGP)
    commercial_rate = Column(Numeric(12, 4), nullable=False)  # Bank Commercial Rate (سعر البنك)
    customs_rate = Column(Numeric(12, 4), nullable=False)     # Official Egyptian Customs Rate (سعر الصرف الجمركي)

    effective_date = Column(Date, nullable=False, index=True)
    is_active = Column(Boolean, default=True, nullable=False)

    # Audit Trail
    created_by = Column(String(100), default="System", nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    # Relationships
    currency = relationship("Currency", back_populates="exchange_rates")
