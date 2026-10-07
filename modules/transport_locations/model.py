from datetime import datetime, timezone
from sqlalchemy import Boolean, Column, DateTime, Integer, String
from database.database import Base


# ==================================================
# MD-009: Transport Locations (Sea Ports, Airports, Dry Ports, Land Borders)
# ==================================================

class TransportLocation(Base):
    __tablename__ = "transport_locations"

    location_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    un_locode = Column(String(10), nullable=False, unique=True, index=True)
    location_name = Column(String(200), nullable=False)
    location_type = Column(String(50), nullable=False, index=True)  # Sea Port, Airport, Dry Port, Land Border, ICD, Rail Terminal
    country = Column(String(100), nullable=False, index=True)
    city = Column(String(100), nullable=False)
    notes = Column(String(500), nullable=True)

    is_active = Column(Boolean, default=True, nullable=False, index=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    created_by = Column(String(100), nullable=True)
    updated_by = Column(String(100), nullable=True)


# ==================================================
# Countries of Origin Master Table (بلاد المنشأ)
# ==================================================

class Country(Base):
    __tablename__ = "countries"

    country_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    country_code = Column(String(10), nullable=False, unique=True, index=True)  # ISO Alpha-2/Alpha-3 Code (e.g. EG, US, CN)
    country_name = Column(String(150), nullable=False, index=True)              # English Name
    country_name_ar = Column(String(150), nullable=True)                       # Arabic Name (optional)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )


# ==================================================
# World Cities Master Table (جدول المدن)
# ==================================================

class City(Base):
    __tablename__ = "cities"

    city_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    city_code = Column(String(20), nullable=False, unique=True, index=True)   # UN/LOCODE / City Code (e.g. ADALV, AEAUH, EGALY)
    city_name = Column(String(150), nullable=False, index=True)              # City Name
    country_code = Column(String(10), nullable=True, index=True)             # Country Code (e.g. AD, AE, EG, AU)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
