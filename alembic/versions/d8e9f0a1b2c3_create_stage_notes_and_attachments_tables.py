"""create_stage_notes_and_attachments_tables

Revision ID: d8e9f0a1b2c3
Revises: c7d8e9f0a1b2
Create Date: 2026-10-21
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


revision: str = 'd8e9f0a1b2c3'
down_revision: Union[str, Sequence[str], None] = 'c7d8e9f0a1b2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = inspector.get_table_names()

    # 1. stage_notes
    if 'stage_notes' not in tables:
        op.create_table(
            'stage_notes',
            sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('screen_code', sa.String(length=100), nullable=False),
            sa.Column('record_id', sa.Integer(), nullable=True),
            sa.Column('stage_code', sa.String(length=50), nullable=True),
            sa.Column('note_text', sa.Text(), nullable=False),
            sa.Column('created_by', sa.String(length=100), nullable=False),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
        )
        op.create_index('ix_stage_notes_screen_code', 'stage_notes', ['screen_code'])
        op.create_index('ix_stage_notes_record_id', 'stage_notes', ['record_id'])
        op.create_index('ix_stage_notes_stage_code', 'stage_notes', ['stage_code'])

    # 2. stage_note_attachments
    if 'stage_note_attachments' not in tables:
        op.create_table(
            'stage_note_attachments',
            sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('note_id', sa.Integer(), sa.ForeignKey('stage_notes.id', ondelete='CASCADE'), nullable=False),
            sa.Column('file_name', sa.String(length=255), nullable=False),
            sa.Column('file_path', sa.String(length=500), nullable=False),
            sa.Column('file_size_bytes', sa.Integer(), nullable=False, server_default=sa.text('0')),
            sa.Column('file_type', sa.String(length=50), nullable=False, server_default=sa.text("'generic'")),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
        )
        op.create_index('ix_stage_note_attachments_note_id', 'stage_note_attachments', ['note_id'])


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = inspector.get_table_names()

    if 'stage_note_attachments' in tables:
        op.drop_table('stage_note_attachments')
    if 'stage_notes' in tables:
        op.drop_table('stage_notes')
