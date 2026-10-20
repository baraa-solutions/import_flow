"""Add terminals, carriers, and historical rate cards with progressive tiers (MD-TERM-CARR-001)

Creates tables:
1. terminals
2. terminal_storage_rates
3. carriers
4. carrier_demurrage_rates

Alters table:
- demurrage_trackings: adds carrier_id, terminal_id, ancillary_fees

Revision ID: b8c9d0e1f2a3
Revises: a7b8c9d0e1f2
Create Date: 2026-10-19 17:35:00.000000
"""

import json
from datetime import datetime, timezone, date
from typing import Sequence, Union
import sqlalchemy as sa
from alembic import op

revision: str = "b8c9d0e1f2a3"
down_revision: Union[str, Sequence[str], None] = "a7b8c9d0e1f2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    # 1. terminals
    if "terminals" not in tables:
        op.create_table(
            "terminals",
            sa.Column("terminal_id", sa.Integer(), autoincrement=True, nullable=False),
            sa.Column("terminal_code", sa.String(50), nullable=False),
            sa.Column("terminal_name", sa.String(150), nullable=False),
            sa.Column("terminal_name_en", sa.String(150), nullable=True),
            sa.Column("port_name", sa.String(100), nullable=False),
            sa.Column("country_code", sa.String(10), server_default="EG", nullable=False),
            sa.Column("notes", sa.Text(), nullable=True),
            sa.Column("is_active", sa.Boolean(), server_default="1", nullable=False),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("created_by", sa.String(100), nullable=True),
            sa.Column("updated_at", sa.DateTime(), nullable=False),
            sa.Column("updated_by", sa.String(100), nullable=True),
            sa.PrimaryKeyConstraint("terminal_id"),
        )
        op.create_index("ix_terminals_terminal_id", "terminals", ["terminal_id"])
        op.create_index("ix_terminals_terminal_code", "terminals", ["terminal_code"], unique=True)
        op.create_index("ix_terminals_port_name", "terminals", ["port_name"])
        op.create_index("ix_terminals_is_active", "terminals", ["is_active"])

    # 2. terminal_storage_rates
    if "terminal_storage_rates" not in tables:
        op.create_table(
            "terminal_storage_rates",
            sa.Column("rate_id", sa.Integer(), autoincrement=True, nullable=False),
            sa.Column("terminal_id", sa.Integer(), nullable=False),
            sa.Column("container_type", sa.String(50), nullable=False),
            sa.Column("free_days", sa.Integer(), server_default="7", nullable=False),
            sa.Column("storage_tiers", sa.JSON(), nullable=False),
            sa.Column("currency", sa.String(10), nullable=False),
            sa.Column("imo_free_days", sa.Integer(), server_default="0", nullable=False),
            sa.Column("imo_rate_multiplier", sa.Float(), server_default="2.0", nullable=False),
            sa.Column("effective_date", sa.Date(), nullable=False),
            sa.Column("notes", sa.Text(), nullable=True),
            sa.Column("is_active", sa.Boolean(), server_default="1", nullable=False),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("created_by", sa.String(100), nullable=True),
            sa.ForeignKeyConstraint(["terminal_id"], ["terminals.terminal_id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("rate_id"),
            sa.UniqueConstraint("terminal_id", "container_type", "effective_date", name="uq_terminal_storage_rate_date"),
        )
        op.create_index("ix_terminal_storage_rates_rate_id", "terminal_storage_rates", ["rate_id"])
        op.create_index("ix_terminal_storage_rates_terminal_id", "terminal_storage_rates", ["terminal_id"])
        op.create_index("ix_terminal_storage_rates_container_type", "terminal_storage_rates", ["container_type"])
        op.create_index("ix_terminal_storage_rates_effective_date", "terminal_storage_rates", ["effective_date"])
        op.create_index("ix_terminal_storage_rates_is_active", "terminal_storage_rates", ["is_active"])

    # 3. carriers
    if "carriers" not in tables:
        op.create_table(
            "carriers",
            sa.Column("carrier_id", sa.Integer(), autoincrement=True, nullable=False),
            sa.Column("carrier_code", sa.String(50), nullable=False),
            sa.Column("carrier_name", sa.String(150), nullable=False),
            sa.Column("carrier_name_ar", sa.String(150), nullable=True),
            sa.Column("scac_code", sa.String(10), nullable=True),
            sa.Column("notes", sa.Text(), nullable=True),
            sa.Column("is_active", sa.Boolean(), server_default="1", nullable=False),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("created_by", sa.String(100), nullable=True),
            sa.Column("updated_at", sa.DateTime(), nullable=False),
            sa.Column("updated_by", sa.String(100), nullable=True),
            sa.PrimaryKeyConstraint("carrier_id"),
        )
        op.create_index("ix_carriers_carrier_id", "carriers", ["carrier_id"])
        op.create_index("ix_carriers_carrier_code", "carriers", ["carrier_code"], unique=True)
        op.create_index("ix_carriers_scac_code", "carriers", ["scac_code"], unique=True)
        op.create_index("ix_carriers_is_active", "carriers", ["is_active"])

    # 4. carrier_demurrage_rates
    if "carrier_demurrage_rates" not in tables:
        op.create_table(
            "carrier_demurrage_rates",
            sa.Column("rate_id", sa.Integer(), autoincrement=True, nullable=False),
            sa.Column("carrier_id", sa.Integer(), nullable=False),
            sa.Column("container_type", sa.String(50), nullable=False),
            sa.Column("demurrage_free_days_standard", sa.Integer(), server_default="14", nullable=False),
            sa.Column("detention_free_days_standard", sa.Integer(), server_default="7", nullable=False),
            sa.Column("demurrage_tiers", sa.JSON(), nullable=False),
            sa.Column("detention_tiers", sa.JSON(), nullable=False),
            sa.Column("currency", sa.String(10), nullable=False),
            sa.Column("effective_date", sa.Date(), nullable=False),
            sa.Column("notes", sa.Text(), nullable=True),
            sa.Column("is_active", sa.Boolean(), server_default="1", nullable=False),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("created_by", sa.String(100), nullable=True),
            sa.ForeignKeyConstraint(["carrier_id"], ["carriers.carrier_id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("rate_id"),
            sa.UniqueConstraint("carrier_id", "container_type", "effective_date", name="uq_carrier_demurrage_rate_date"),
        )
        op.create_index("ix_carrier_demurrage_rates_rate_id", "carrier_demurrage_rates", ["rate_id"])
        op.create_index("ix_carrier_demurrage_rates_carrier_id", "carrier_demurrage_rates", ["carrier_id"])
        op.create_index("ix_carrier_demurrage_rates_container_type", "carrier_demurrage_rates", ["container_type"])
        op.create_index("ix_carrier_demurrage_rates_effective_date", "carrier_demurrage_rates", ["effective_date"])
        op.create_index("ix_carrier_demurrage_rates_is_active", "carrier_demurrage_rates", ["is_active"])

    # 5. Alter demurrage_trackings to add terminal_id, carrier_id, and ancillary_fees
    if "demurrage_trackings" in tables:
        cols = {c["name"].lower() for c in inspector.get_columns("demurrage_trackings")}
        with op.batch_alter_table("demurrage_trackings") as batch_op:
            if "carrier_id" not in cols:
                batch_op.add_column(sa.Column("carrier_id", sa.Integer(), nullable=True))
                batch_op.create_foreign_key("fk_demurrage_trackings_carrier_id", "carriers", ["carrier_id"], ["carrier_id"])
                batch_op.create_index("ix_demurrage_trackings_carrier_id", ["carrier_id"])
            if "terminal_id" not in cols:
                batch_op.add_column(sa.Column("terminal_id", sa.Integer(), nullable=True))
                batch_op.create_foreign_key("fk_demurrage_trackings_terminal_id", "terminals", ["terminal_id"], ["terminal_id"])
                batch_op.create_index("ix_demurrage_trackings_terminal_id", ["terminal_id"])
            if "ancillary_fees" not in cols:
                batch_op.add_column(sa.Column("ancillary_fees", sa.JSON(), server_default="[]", nullable=False))

    # 6. Seed Baseline Data for Terminals, Carriers, and Rates
    _seed_initial_data()


def _seed_initial_data() -> None:
    bind = op.get_bind()
    now = datetime.now(timezone.utc)
    base_date = date(2026, 1, 1)

    terminals_tbl = sa.table(
        "terminals",
        sa.column("terminal_id", sa.Integer),
        sa.column("terminal_code", sa.String),
        sa.column("terminal_name", sa.String),
        sa.column("terminal_name_en", sa.String),
        sa.column("port_name", sa.String),
        sa.column("country_code", sa.String),
        sa.column("notes", sa.Text),
        sa.column("is_active", sa.Boolean),
        sa.column("created_at", sa.DateTime),
        sa.column("created_by", sa.String),
        sa.column("updated_at", sa.DateTime),
        sa.column("updated_by", sa.String),
    )

    storage_rates_tbl = sa.table(
        "terminal_storage_rates",
        sa.column("terminal_id", sa.Integer),
        sa.column("container_type", sa.String),
        sa.column("free_days", sa.Integer),
        sa.column("storage_tiers", sa.JSON),
        sa.column("currency", sa.String),
        sa.column("imo_free_days", sa.Integer),
        sa.column("imo_rate_multiplier", sa.Float),
        sa.column("effective_date", sa.Date),
        sa.column("notes", sa.Text),
        sa.column("is_active", sa.Boolean),
        sa.column("created_at", sa.DateTime),
        sa.column("created_by", sa.String),
    )

    carriers_tbl = sa.table(
        "carriers",
        sa.column("carrier_id", sa.Integer),
        sa.column("carrier_code", sa.String),
        sa.column("carrier_name", sa.String),
        sa.column("carrier_name_ar", sa.String),
        sa.column("scac_code", sa.String),
        sa.column("notes", sa.Text),
        sa.column("is_active", sa.Boolean),
        sa.column("created_at", sa.DateTime),
        sa.column("created_by", sa.String),
        sa.column("updated_at", sa.DateTime),
        sa.column("updated_by", sa.String),
    )

    demurrage_rates_tbl = sa.table(
        "carrier_demurrage_rates",
        sa.column("carrier_id", sa.Integer),
        sa.column("container_type", sa.String),
        sa.column("demurrage_free_days_standard", sa.Integer),
        sa.column("detention_free_days_standard", sa.Integer),
        sa.column("demurrage_tiers", sa.JSON),
        sa.column("detention_tiers", sa.JSON),
        sa.column("currency", sa.String),
        sa.column("effective_date", sa.Date),
        sa.column("notes", sa.Text),
        sa.column("is_active", sa.Boolean),
        sa.column("created_at", sa.DateTime),
        sa.column("created_by", sa.String),
    )

    # Insert Terminals
    terminals_data = [
        {"terminal_id": 1, "terminal_code": "AICTC-ALEX", "terminal_name": "شركة الإسكندرية لتداول الحاويات (محطة الإسكندرية)", "terminal_name_en": "Alexandria Container Handling Co. (Alex Port)", "port_name": "Alexandria", "country_code": "EG", "notes": "المحطة الوطنية التاريخية بميناء الإسكندرية", "is_active": True, "created_at": now, "created_by": "System", "updated_at": now, "updated_by": "System"},
        {"terminal_id": 2, "terminal_code": "AICTC-DKH", "terminal_name": "شركة الإسكندرية لتداول الحاويات (محطة الدخيلة)", "terminal_name_en": "Alexandria Container Handling Co. (Dekheila Port)", "port_name": "Dekheila", "country_code": "EG", "notes": "محطة الدخيلة التابعة لـ AICTC", "is_active": True, "created_at": now, "created_by": "System", "updated_at": now, "updated_by": "System"},
        {"terminal_id": 3, "terminal_code": "TMT-ALEX", "terminal_name": "محطة تحيا مصر متعددة الأغراض (TMT)", "terminal_name_en": "Tahya Misr Multipurpose Terminal", "port_name": "Alexandria", "country_code": "EG", "notes": "مشغلة بالشراكة مع CMA CGM", "is_active": True, "created_at": now, "created_by": "System", "updated_at": now, "updated_by": "System"},
        {"terminal_id": 4, "terminal_code": "HPH-DKH", "terminal_name": "هاتشيسون بورتس الدخيلة (HPH)", "terminal_name_en": "Hutchison Ports Dekheila", "port_name": "Dekheila", "country_code": "EG", "notes": "مشغل محطة الحاويات العالمية بالدخيلة", "is_active": True, "created_at": now, "created_by": "System", "updated_at": now, "updated_by": "System"},
        {"terminal_id": 5, "terminal_code": "SCCT-PSD", "terminal_name": "شركة قناة السويس للحاويات (شرق بورسعيد)", "terminal_name_en": "Suez Canal Container Terminal (APM Terminals)", "port_name": "East Port Said", "country_code": "EG", "notes": "محطة شرق بورسعيد المحورية التابعة لمجموعة ميرسك", "is_active": True, "created_at": now, "created_by": "System", "updated_at": now, "updated_by": "System"},
        {"terminal_id": 6, "terminal_code": "DPW-SOK", "terminal_name": "موانئ دبي العالمية (السخنة)", "terminal_name_en": "DP World Sokhna", "port_name": "Sokhna", "country_code": "EG", "notes": "المحطة الرئيسية لميناء العين السخنة", "is_active": True, "created_at": now, "created_by": "System", "updated_at": now, "updated_by": "System"},
        {"terminal_id": 7, "terminal_code": "DCHC-DMT", "terminal_name": "دمياط لتداول الحاويات والبضائع", "terminal_name_en": "Damietta Container & Cargo Handling Co.", "port_name": "Damietta", "country_code": "EG", "notes": "محطة ميناء دمياط الوطنية", "is_active": True, "created_at": now, "created_by": "System", "updated_at": now, "updated_by": "System"},
    ]
    op.bulk_insert(terminals_tbl, terminals_data)

    # Insert Storage Rates (Baseline from golden tariff analysis)
    aictc_40_tiers = [
        {"from_day": 8, "to_day": 14, "rate_per_day": 36.0},
        {"from_day": 15, "to_day": 21, "rate_per_day": 40.0},
        {"from_day": 22, "to_day": None, "rate_per_day": 45.0},
    ]
    aictc_20_tiers = [
        {"from_day": 8, "to_day": 14, "rate_per_day": 18.0},
        {"from_day": 15, "to_day": 21, "rate_per_day": 20.0},
        {"from_day": 22, "to_day": None, "rate_per_day": 23.0},
    ]

    storage_rates_data = [
        # AICTC-ALEX (Terminal 1)
        {"terminal_id": 1, "container_type": "40ft DRY", "free_days": 7, "storage_tiers": aictc_40_tiers, "currency": "USD", "imo_free_days": 1, "imo_rate_multiplier": 2.0, "effective_date": base_date, "notes": "تعريفة AICTC المعتمدة 2026 للحاويات 40 قدم", "is_active": True, "created_at": now, "created_by": "System"},
        {"terminal_id": 1, "container_type": "40ft High Cube", "free_days": 7, "storage_tiers": aictc_40_tiers, "currency": "USD", "imo_free_days": 1, "imo_rate_multiplier": 2.0, "effective_date": base_date, "notes": "تعريفة AICTC المعتمدة 2026 للحاويات 40HC", "is_active": True, "created_at": now, "created_by": "System"},
        {"terminal_id": 1, "container_type": "20ft DRY", "free_days": 7, "storage_tiers": aictc_20_tiers, "currency": "USD", "imo_free_days": 1, "imo_rate_multiplier": 2.0, "effective_date": base_date, "notes": "تعريفة AICTC المعتمدة 2026 للحاويات 20 قدم", "is_active": True, "created_at": now, "created_by": "System"},
        # AICTC-DKH (Terminal 2)
        {"terminal_id": 2, "container_type": "40ft DRY", "free_days": 7, "storage_tiers": aictc_40_tiers, "currency": "USD", "imo_free_days": 1, "imo_rate_multiplier": 2.0, "effective_date": base_date, "notes": "تعريفة الدخيلة AICTC للحاويات 40 قدم", "is_active": True, "created_at": now, "created_by": "System"},
        {"terminal_id": 2, "container_type": "20ft DRY", "free_days": 7, "storage_tiers": aictc_20_tiers, "currency": "USD", "imo_free_days": 1, "imo_rate_multiplier": 2.0, "effective_date": base_date, "notes": "تعريفة الدخيلة AICTC للحاويات 20 قدم", "is_active": True, "created_at": now, "created_by": "System"},
        # TMT-ALEX (Terminal 3)
        {"terminal_id": 3, "container_type": "40ft DRY", "free_days": 7, "storage_tiers": aictc_40_tiers, "currency": "USD", "imo_free_days": 1, "imo_rate_multiplier": 2.0, "effective_date": base_date, "notes": "تعريفة محطة تحيا مصر للحاويات 40 قدم", "is_active": True, "created_at": now, "created_by": "System"},
        {"terminal_id": 3, "container_type": "20ft DRY", "free_days": 7, "storage_tiers": aictc_20_tiers, "currency": "USD", "imo_free_days": 1, "imo_rate_multiplier": 2.0, "effective_date": base_date, "notes": "تعريفة محطة تحيا مصر للحاويات 20 قدم", "is_active": True, "created_at": now, "created_by": "System"},
    ]
    op.bulk_insert(storage_rates_tbl, storage_rates_data)

    # Insert Carriers
    carriers_data = [
        {"carrier_id": 1, "carrier_code": "MSC", "carrier_name": "Mediterranean Shipping Company", "carrier_name_ar": "شركة إم إس سي للملاحة البحرية", "scac_code": "MSCU", "notes": "أكبر خط ملاحي للحاويات في العالم", "is_active": True, "created_at": now, "created_by": "System", "updated_at": now, "updated_by": "System"},
        {"carrier_id": 2, "carrier_code": "MAERSK", "carrier_name": "Maersk Line (A.P. Moller)", "carrier_name_ar": "ميرسك لاين", "scac_code": "MAEU", "notes": "مجموعة ميرسك العالمية ومحطة SCCT", "is_active": True, "created_at": now, "created_by": "System", "updated_at": now, "updated_by": "System"},
        {"carrier_id": 3, "carrier_code": "CMA-CGM", "carrier_name": "CMA CGM Group", "carrier_name_ar": "سي إم إيه سي جي إم", "scac_code": "CMDU", "notes": "المشغل الرئيسي لمحطة تحيا مصر", "is_active": True, "created_at": now, "created_by": "System", "updated_at": now, "updated_by": "System"},
        {"carrier_id": 4, "carrier_code": "HAPAG", "carrier_name": "Hapag-Lloyd", "carrier_name_ar": "هاباج لويد", "scac_code": "HLCU", "notes": "خط ألماني بارز بالموانئ المصرية", "is_active": True, "created_at": now, "created_by": "System", "updated_at": now, "updated_by": "System"},
        {"carrier_id": 5, "carrier_code": "COSCO", "carrier_name": "COSCO Shipping Lines", "carrier_name_ar": "كوسكو للملاحة", "scac_code": "COSU", "notes": "الخط الصيني الرئيسي", "is_active": True, "created_at": now, "created_by": "System", "updated_at": now, "updated_by": "System"},
        {"carrier_id": 6, "carrier_code": "ONE", "carrier_name": "Ocean Network Express", "carrier_name_ar": "أوشن نتورك إكسبريس (ONE)", "scac_code": "ONEY", "notes": "التحالف الياباني الموحد", "is_active": True, "created_at": now, "created_by": "System", "updated_at": now, "updated_by": "System"},
    ]
    op.bulk_insert(carriers_tbl, carriers_data)

    # Insert Demurrage Rates (Baseline)
    msc_40_dem_tiers = [
        {"from_day": 1, "to_day": 7, "rate_per_day": 40.0},
        {"from_day": 8, "to_day": 14, "rate_per_day": 70.0},
        {"from_day": 15, "to_day": 21, "rate_per_day": 120.0},
        {"from_day": 22, "to_day": None, "rate_per_day": 165.0},
    ]
    msc_40_det_tiers = [
        {"from_day": 1, "to_day": 7, "rate_per_day": 35.0},
        {"from_day": 8, "to_day": 14, "rate_per_day": 65.0},
        {"from_day": 15, "to_day": None, "rate_per_day": 110.0},
    ]

    msc_20_dem_tiers = [
        {"from_day": 1, "to_day": 7, "rate_per_day": 20.0},
        {"from_day": 8, "to_day": 14, "rate_per_day": 35.0},
        {"from_day": 15, "to_day": 21, "rate_per_day": 60.0},
        {"from_day": 22, "to_day": None, "rate_per_day": 85.0},
    ]
    msc_20_det_tiers = [
        {"from_day": 1, "to_day": 7, "rate_per_day": 18.0},
        {"from_day": 8, "to_day": 14, "rate_per_day": 35.0},
        {"from_day": 15, "to_day": None, "rate_per_day": 55.0},
    ]

    demurrage_rates_data = [
        # MSC (Carrier 1)
        {"carrier_id": 1, "container_type": "40ft DRY", "demurrage_free_days_standard": 14, "detention_free_days_standard": 7, "demurrage_tiers": msc_40_dem_tiers, "detention_tiers": msc_40_det_tiers, "currency": "USD", "effective_date": base_date, "notes": "تعريفة MSC مصر الرسمية 2026 للحاويات 40 قدم", "is_active": True, "created_at": now, "created_by": "System"},
        {"carrier_id": 1, "container_type": "40ft High Cube", "demurrage_free_days_standard": 14, "detention_free_days_standard": 7, "demurrage_tiers": msc_40_dem_tiers, "detention_tiers": msc_40_det_tiers, "currency": "USD", "effective_date": base_date, "notes": "تعريفة MSC مصر الرسمية 2026 للحاويات 40HC", "is_active": True, "created_at": now, "created_by": "System"},
        {"carrier_id": 1, "container_type": "20ft DRY", "demurrage_free_days_standard": 14, "detention_free_days_standard": 7, "demurrage_tiers": msc_20_dem_tiers, "detention_tiers": msc_20_det_tiers, "currency": "USD", "effective_date": base_date, "notes": "تعريفة MSC مصر الرسمية 2026 للحاويات 20 قدم", "is_active": True, "created_at": now, "created_by": "System"},
        # MAERSK (Carrier 2)
        {"carrier_id": 2, "container_type": "40ft DRY", "demurrage_free_days_standard": 14, "detention_free_days_standard": 7, "demurrage_tiers": msc_40_dem_tiers, "detention_tiers": msc_40_det_tiers, "currency": "USD", "effective_date": base_date, "notes": "تعريفة ميرسك مصر الرسمية 2026 للحاويات 40 قدم", "is_active": True, "created_at": now, "created_by": "System"},
        {"carrier_id": 2, "container_type": "20ft DRY", "demurrage_free_days_standard": 14, "detention_free_days_standard": 7, "demurrage_tiers": msc_20_dem_tiers, "detention_tiers": msc_20_det_tiers, "currency": "USD", "effective_date": base_date, "notes": "تعريفة ميرسك مصر الرسمية 2026 للحاويات 20 قدم", "is_active": True, "created_at": now, "created_by": "System"},
    ]
    op.bulk_insert(demurrage_rates_tbl, demurrage_rates_data)


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    if "demurrage_trackings" in tables:
        indices = {idx["name"] for idx in inspector.get_indexes("demurrage_trackings")}
        with op.batch_alter_table("demurrage_trackings") as batch_op:
            if "ix_demurrage_trackings_terminal_id" in indices:
                batch_op.drop_index("ix_demurrage_trackings_terminal_id")
            if "ix_demurrage_trackings_carrier_id" in indices:
                batch_op.drop_index("ix_demurrage_trackings_carrier_id")
            batch_op.drop_column("ancillary_fees")
            batch_op.drop_column("terminal_id")
            batch_op.drop_column("carrier_id")

    if "carrier_demurrage_rates" in tables:
        op.drop_table("carrier_demurrage_rates")
    if "carriers" in tables:
        op.drop_table("carriers")
    if "terminal_storage_rates" in tables:
        op.drop_table("terminal_storage_rates")
    if "terminals" in tables:
        op.drop_table("terminals")
