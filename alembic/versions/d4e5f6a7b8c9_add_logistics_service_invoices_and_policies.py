"""Add logistics service invoices, insurance policies, advance payments, and knock-offs

Creates tables:
1. insurance_policies
2. logistics_service_invoices
3. logistics_invoice_lines
4. logistics_invoice_containers
5. clearance_advance_payments
6. clearance_advance_settlements
7. logistics_payment_vouchers
8. invoice_knockoffs

Revision ID: d4e5f6a7b8c9
Revises: c3d4e5f6a7b8
Create Date: 2026-10-10 01:00:00.000000
"""

from typing import Sequence, Union
import sqlalchemy as sa
from alembic import op

revision: str = "d4e5f6a7b8c9"
down_revision: Union[str, Sequence[str], None] = "c3d4e5f6a7b8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    # 1. insurance_policies
    if "insurance_policies" not in tables:
        op.create_table(
            "insurance_policies",
            sa.Column("policy_id", sa.Integer(), autoincrement=True, nullable=False),
            sa.Column("policy_code", sa.String(50), nullable=False),
            sa.Column("shipment_id", sa.Integer(), nullable=False),
            sa.Column("bl_number", sa.String(100), nullable=True),
            sa.Column("insurance_company_id", sa.Integer(), nullable=False),
            sa.Column("insurance_company_name", sa.String(255), nullable=False),
            sa.Column("policy_number", sa.String(100), nullable=False),
            sa.Column("policy_date", sa.DateTime(), nullable=False),
            sa.Column("coverage_start", sa.Date(), nullable=True),
            sa.Column("coverage_end", sa.Date(), nullable=True),
            sa.Column("coverage_type", sa.String(50), server_default="all_risks", nullable=False),
            sa.Column("insured_value_fx", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("insured_value_currency", sa.String(10), server_default="USD", nullable=False),
            sa.Column("premium_rate", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("premium_amount_fx", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("exchange_rate", sa.Float(), server_default="1.0", nullable=False),
            sa.Column("premium_amount_egp", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("stamp_duty_egp", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("supervisory_fee_egp", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("net_premium_egp", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("beneficiary", sa.String(255), nullable=True),
            sa.Column("status", sa.String(50), server_default="draft", nullable=False),
            sa.Column("claim_reference", sa.String(100), nullable=True),
            sa.Column("claim_amount_egp", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("claim_status", sa.String(50), nullable=True),
            sa.Column("invoice_generated", sa.Boolean(), server_default="0", nullable=False),
            sa.Column("notes", sa.Text(), nullable=True),
            sa.Column("is_active", sa.Boolean(), server_default="1", nullable=False),
            sa.Column("deleted_at", sa.DateTime(), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("created_by", sa.String(100), server_default="System", nullable=False),
            sa.Column("updated_at", sa.DateTime(), nullable=False),
            sa.Column("updated_by", sa.String(100), server_default="System", nullable=False),
            sa.ForeignKeyConstraint(["insurance_company_id"], ["external_service_providers.provider_id"]),
            sa.ForeignKeyConstraint(["shipment_id"], ["import_files.import_file_id"]),
            sa.PrimaryKeyConstraint("policy_id"),
        )
        op.create_index("ix_insurance_policies_policy_id", "insurance_policies", ["policy_id"])
        op.create_index("ix_insurance_policies_policy_code", "insurance_policies", ["policy_code"], unique=True)
        op.create_index("ix_insurance_policies_shipment_id", "insurance_policies", ["shipment_id"])
        op.create_index("ix_insurance_policies_bl_number", "insurance_policies", ["bl_number"])
        op.create_index("ix_insurance_policies_insurance_company_id", "insurance_policies", ["insurance_company_id"])
        op.create_index("ix_insurance_policies_policy_number", "insurance_policies", ["policy_number"])
        op.create_index("ix_insurance_policies_status", "insurance_policies", ["status"])
        op.create_index("ix_insurance_policies_is_active", "insurance_policies", ["is_active"])

    # 2. logistics_service_invoices
    if "logistics_service_invoices" not in tables:
        op.create_table(
            "logistics_service_invoices",
            sa.Column("invoice_id", sa.Integer(), autoincrement=True, nullable=False),
            sa.Column("invoice_code", sa.String(50), nullable=False),
            sa.Column("shipment_id", sa.Integer(), nullable=False),
            sa.Column("bl_number", sa.String(100), nullable=True),
            sa.Column("partner_id", sa.Integer(), nullable=False),
            sa.Column("partner_type", sa.String(50), nullable=False),
            sa.Column("partner_name", sa.String(255), nullable=False),
            sa.Column("invoice_number", sa.String(100), nullable=False),
            sa.Column("invoice_date", sa.DateTime(), nullable=False),
            sa.Column("currency", sa.String(10), server_default="EGP", nullable=False),
            sa.Column("total_amount_fx", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("exchange_rate", sa.Float(), server_default="1.0", nullable=False),
            sa.Column("total_amount_egp", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("vat_included", sa.Boolean(), server_default="0", nullable=False),
            sa.Column("vat_amount", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("wht_deducted", sa.Boolean(), server_default="0", nullable=False),
            sa.Column("wht_amount", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("net_payable_egp", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("paid_amount_egp", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("remaining_amount_egp", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("payment_status", sa.String(50), server_default="UNPAID", nullable=False),
            sa.Column("status", sa.String(50), server_default="DRAFT", nullable=False),
            sa.Column("approval_status", sa.String(50), server_default="PENDING", nullable=False),
            sa.Column("insurance_policy_id", sa.Integer(), nullable=True),
            sa.Column("document_url", sa.String(500), nullable=True),
            sa.Column("notes", sa.Text(), nullable=True),
            sa.Column("is_active", sa.Boolean(), server_default="1", nullable=False),
            sa.Column("deleted_at", sa.DateTime(), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("created_by", sa.String(100), server_default="System", nullable=False),
            sa.Column("updated_at", sa.DateTime(), nullable=False),
            sa.Column("updated_by", sa.String(100), server_default="System", nullable=False),
            sa.ForeignKeyConstraint(["insurance_policy_id"], ["insurance_policies.policy_id"]),
            sa.ForeignKeyConstraint(["partner_id"], ["external_service_providers.provider_id"]),
            sa.ForeignKeyConstraint(["shipment_id"], ["import_files.import_file_id"]),
            sa.PrimaryKeyConstraint("invoice_id"),
        )
        op.create_index("ix_logistics_service_invoices_invoice_id", "logistics_service_invoices", ["invoice_id"])
        op.create_index("ix_logistics_service_invoices_invoice_code", "logistics_service_invoices", ["invoice_code"], unique=True)
        op.create_index("ix_logistics_service_invoices_shipment_id", "logistics_service_invoices", ["shipment_id"])
        op.create_index("ix_logistics_service_invoices_bl_number", "logistics_service_invoices", ["bl_number"])
        op.create_index("ix_logistics_service_invoices_partner_id", "logistics_service_invoices", ["partner_id"])
        op.create_index("ix_logistics_service_invoices_partner_type", "logistics_service_invoices", ["partner_type"])
        op.create_index("ix_logistics_service_invoices_invoice_number", "logistics_service_invoices", ["invoice_number"])
        op.create_index("ix_logistics_service_invoices_payment_status", "logistics_service_invoices", ["payment_status"])
        op.create_index("ix_logistics_service_invoices_status", "logistics_service_invoices", ["status"])
        op.create_index("ix_logistics_service_invoices_insurance_policy_id", "logistics_service_invoices", ["insurance_policy_id"])
        op.create_index("ix_logistics_service_invoices_is_active", "logistics_service_invoices", ["is_active"])

    # 3. logistics_invoice_lines
    if "logistics_invoice_lines" not in tables:
        op.create_table(
            "logistics_invoice_lines",
            sa.Column("line_id", sa.Integer(), autoincrement=True, nullable=False),
            sa.Column("invoice_id", sa.Integer(), nullable=False),
            sa.Column("expense_code", sa.String(50), nullable=True),
            sa.Column("line_description", sa.String(255), nullable=False),
            sa.Column("line_group", sa.String(50), nullable=True),
            sa.Column("quantity", sa.Float(), server_default="1.0", nullable=False),
            sa.Column("unit_price_fx", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("currency", sa.String(10), server_default="EGP", nullable=False),
            sa.Column("amount_fx", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("exchange_rate", sa.Float(), server_default="1.0", nullable=False),
            sa.Column("amount_egp", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("tax_type", sa.String(50), server_default="professional_fee", nullable=False),
            sa.Column("vat_rate", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("vat_amount", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("wht_rate", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("wht_amount", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("net_amount_egp", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("is_from_quotation", sa.Boolean(), server_default="0", nullable=False),
            sa.Column("is_active", sa.Boolean(), server_default="1", nullable=False),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(["expense_code"], ["expense_catalog.code"]),
            sa.ForeignKeyConstraint(["invoice_id"], ["logistics_service_invoices.invoice_id"]),
            sa.PrimaryKeyConstraint("line_id"),
        )
        op.create_index("ix_logistics_invoice_lines_line_id", "logistics_invoice_lines", ["line_id"])
        op.create_index("ix_logistics_invoice_lines_invoice_id", "logistics_invoice_lines", ["invoice_id"])
        op.create_index("ix_logistics_invoice_lines_expense_code", "logistics_invoice_lines", ["expense_code"])

    # 4. logistics_invoice_containers
    if "logistics_invoice_containers" not in tables:
        op.create_table(
            "logistics_invoice_containers",
            sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
            sa.Column("invoice_id", sa.Integer(), nullable=False),
            sa.Column("shipment_id", sa.Integer(), nullable=False),
            sa.Column("bl_number", sa.String(100), nullable=False),
            sa.Column("container_number", sa.String(50), nullable=False),
            sa.Column("seal_number", sa.String(50), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(["invoice_id"], ["logistics_service_invoices.invoice_id"]),
            sa.ForeignKeyConstraint(["shipment_id"], ["import_files.import_file_id"]),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("invoice_id", "container_number", name="uq_invoice_container"),
        )
        op.create_index("ix_logistics_invoice_containers_id", "logistics_invoice_containers", ["id"])
        op.create_index("ix_logistics_invoice_containers_invoice_id", "logistics_invoice_containers", ["invoice_id"])
        op.create_index("ix_logistics_invoice_containers_shipment_id", "logistics_invoice_containers", ["shipment_id"])
        op.create_index("ix_logistics_invoice_containers_bl_number", "logistics_invoice_containers", ["bl_number"])
        op.create_index("ix_logistics_invoice_containers_container_number", "logistics_invoice_containers", ["container_number"])

    # 5. clearance_advance_payments
    if "clearance_advance_payments" not in tables:
        op.create_table(
            "clearance_advance_payments",
            sa.Column("advance_id", sa.Integer(), autoincrement=True, nullable=False),
            sa.Column("advance_code", sa.String(50), nullable=False),
            sa.Column("shipment_id", sa.Integer(), nullable=False),
            sa.Column("bl_number", sa.String(100), nullable=True),
            sa.Column("clearance_partner_id", sa.Integer(), nullable=False),
            sa.Column("clearance_partner_name", sa.String(255), nullable=False),
            sa.Column("amount", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("currency", sa.String(10), server_default="EGP", nullable=False),
            sa.Column("exchange_rate", sa.Float(), server_default="1.0", nullable=False),
            sa.Column("amount_egp", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("payment_date", sa.DateTime(), nullable=False),
            sa.Column("cbe_rate_date", sa.Date(), nullable=True),
            sa.Column("disbursed_by", sa.String(100), server_default="Finance", nullable=False),
            sa.Column("settled_amount_egp", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("remaining_amount_egp", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("status", sa.String(50), server_default="pending", nullable=False),
            sa.Column("notes", sa.Text(), nullable=True),
            sa.Column("is_active", sa.Boolean(), server_default="1", nullable=False),
            sa.Column("deleted_at", sa.DateTime(), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("created_by", sa.String(100), server_default="System", nullable=False),
            sa.ForeignKeyConstraint(["clearance_partner_id"], ["external_service_providers.provider_id"]),
            sa.ForeignKeyConstraint(["shipment_id"], ["import_files.import_file_id"]),
            sa.PrimaryKeyConstraint("advance_id"),
        )
        op.create_index("ix_clearance_advance_payments_advance_id", "clearance_advance_payments", ["advance_id"])
        op.create_index("ix_clearance_advance_payments_advance_code", "clearance_advance_payments", ["advance_code"], unique=True)
        op.create_index("ix_clearance_advance_payments_shipment_id", "clearance_advance_payments", ["shipment_id"])
        op.create_index("ix_clearance_advance_payments_bl_number", "clearance_advance_payments", ["bl_number"])
        op.create_index("ix_clearance_advance_payments_clearance_partner_id", "clearance_advance_payments", ["clearance_partner_id"])
        op.create_index("ix_clearance_advance_payments_status", "clearance_advance_payments", ["status"])

    # 6. clearance_advance_settlements
    if "clearance_advance_settlements" not in tables:
        op.create_table(
            "clearance_advance_settlements",
            sa.Column("settlement_id", sa.Integer(), autoincrement=True, nullable=False),
            sa.Column("advance_id", sa.Integer(), nullable=False),
            sa.Column("invoice_id", sa.Integer(), nullable=False),
            sa.Column("settled_amount_egp", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("settlement_date", sa.DateTime(), nullable=False),
            sa.Column("notes", sa.Text(), nullable=True),
            sa.ForeignKeyConstraint(["advance_id"], ["clearance_advance_payments.advance_id"]),
            sa.ForeignKeyConstraint(["invoice_id"], ["logistics_service_invoices.invoice_id"]),
            sa.PrimaryKeyConstraint("settlement_id"),
        )
        op.create_index("ix_clearance_advance_settlements_settlement_id", "clearance_advance_settlements", ["settlement_id"])
        op.create_index("ix_clearance_advance_settlements_advance_id", "clearance_advance_settlements", ["advance_id"])
        op.create_index("ix_clearance_advance_settlements_invoice_id", "clearance_advance_settlements", ["invoice_id"])

    # 7. logistics_payment_vouchers
    if "logistics_payment_vouchers" not in tables:
        op.create_table(
            "logistics_payment_vouchers",
            sa.Column("voucher_id", sa.Integer(), autoincrement=True, nullable=False),
            sa.Column("voucher_code", sa.String(50), nullable=False),
            sa.Column("shipment_id", sa.Integer(), nullable=True),
            sa.Column("partner_id", sa.Integer(), nullable=False),
            sa.Column("partner_name", sa.String(255), nullable=False),
            sa.Column("payment_date", sa.DateTime(), nullable=False),
            sa.Column("amount", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("currency", sa.String(10), server_default="EGP", nullable=False),
            sa.Column("exchange_rate", sa.Float(), server_default="1.0", nullable=False),
            sa.Column("amount_egp", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("cbe_rate_date", sa.Date(), nullable=True),
            sa.Column("payment_method", sa.String(50), server_default="BANK_TRANSFER", nullable=False),
            sa.Column("bank_reference", sa.String(100), nullable=True),
            sa.Column("allocated_amount_egp", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("unallocated_amount_egp", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("status", sa.String(50), server_default="CONFIRMED", nullable=False),
            sa.Column("notes", sa.Text(), nullable=True),
            sa.Column("is_active", sa.Boolean(), server_default="1", nullable=False),
            sa.Column("deleted_at", sa.DateTime(), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("created_by", sa.String(100), server_default="System", nullable=False),
            sa.ForeignKeyConstraint(["partner_id"], ["external_service_providers.provider_id"]),
            sa.ForeignKeyConstraint(["shipment_id"], ["import_files.import_file_id"]),
            sa.PrimaryKeyConstraint("voucher_id"),
        )
        op.create_index("ix_logistics_payment_vouchers_voucher_id", "logistics_payment_vouchers", ["voucher_id"])
        op.create_index("ix_logistics_payment_vouchers_voucher_code", "logistics_payment_vouchers", ["voucher_code"], unique=True)
        op.create_index("ix_logistics_payment_vouchers_shipment_id", "logistics_payment_vouchers", ["shipment_id"])
        op.create_index("ix_logistics_payment_vouchers_partner_id", "logistics_payment_vouchers", ["partner_id"])
        op.create_index("ix_logistics_payment_vouchers_status", "logistics_payment_vouchers", ["status"])

    # 8. invoice_knockoffs
    if "invoice_knockoffs" not in tables:
        op.create_table(
            "invoice_knockoffs",
            sa.Column("knockoff_id", sa.Integer(), autoincrement=True, nullable=False),
            sa.Column("voucher_id", sa.Integer(), nullable=False),
            sa.Column("invoice_id", sa.Integer(), nullable=False),
            sa.Column("knocked_amount_egp", sa.Float(), server_default="0.0", nullable=False),
            sa.Column("knock_date", sa.DateTime(), nullable=False),
            sa.Column("notes", sa.String(255), nullable=True),
            sa.ForeignKeyConstraint(["invoice_id"], ["logistics_service_invoices.invoice_id"]),
            sa.ForeignKeyConstraint(["voucher_id"], ["logistics_payment_vouchers.voucher_id"]),
            sa.PrimaryKeyConstraint("knockoff_id"),
        )
        op.create_index("ix_invoice_knockoffs_knockoff_id", "invoice_knockoffs", ["knockoff_id"])
        op.create_index("ix_invoice_knockoffs_voucher_id", "invoice_knockoffs", ["voucher_id"])
        op.create_index("ix_invoice_knockoffs_invoice_id", "invoice_knockoffs", ["invoice_id"])


def downgrade() -> None:
    op.drop_table("invoice_knockoffs")
    op.drop_table("logistics_payment_vouchers")
    op.drop_table("clearance_advance_settlements")
    op.drop_table("clearance_advance_payments")
    op.drop_table("logistics_invoice_containers")
    op.drop_table("logistics_invoice_lines")
    op.drop_table("logistics_service_invoices")
    op.drop_table("insurance_policies")
