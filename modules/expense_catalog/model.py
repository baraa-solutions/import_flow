"""
Expense Catalog Model (AI-EXPENSE-CATALOG-002)
Canonical reference catalog for Egyptian customs clearance, transport, port handling, and logistics expenses.
"""

from __future__ import annotations

from datetime import datetime, timezone
from sqlalchemy import Boolean, DateTime, String, JSON
from sqlalchemy.orm import Mapped, mapped_column

from database.database import Base


class ExpenseCatalog(Base):
    """
    Coded reference catalog for clearance and logistics expenses.
    Single Source of Truth (SSOT) preventing hallucinated or guess-based extraction.
    """

    __tablename__ = "expense_catalog"

    code: Mapped[str] = mapped_column(
        String(30), primary_key=True, index=True, nullable=False
    )
    canonical_name_ar: Mapped[str] = mapped_column(
        String(255), nullable=False, index=True
    )
    canonical_name_en: Mapped[str | None] = mapped_column(
        String(255), nullable=True
    )
    category: Mapped[str] = mapped_column(
        String(50), nullable=False, index=True
    )  # Clearance Fees | Procedures & Approvals | Inland Transport | Port & Handling | Other Fees
    unit_type: Mapped[str] = mapped_column(
        String(30), nullable=False, default="fixed"
    )  # fixed | per_ton | per_container | per_vehicle | per_night | per_invoice | per_shipment | range
    allow_composite: Mapped[bool] = mapped_column(
        Boolean, default=False, nullable=False
    )
    recognition_patterns: Mapped[list] = mapped_column(
        JSON, default=list, nullable=False
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean, default=True, index=True, nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )
    created_by: Mapped[str | None] = mapped_column(String(100), nullable=True)
    updated_by: Mapped[str | None] = mapped_column(String(100), nullable=True)
