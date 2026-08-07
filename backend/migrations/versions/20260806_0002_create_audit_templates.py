"""Create audit templates.

Revision ID: 20260806_0002
Revises: 20260806_0001
Create Date: 2026-08-06 00:10:00
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "20260806_0002"
down_revision: str | None = "20260806_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "audit_templates",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("is_active", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_table(
        "audit_template_criteria",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("template_id", sa.Integer(), nullable=False),
        sa.Column("label", sa.String(length=200), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.Column("is_required", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["template_id"], ["audit_templates.id"], ondelete="CASCADE"),
        sa.UniqueConstraint(
            "template_id",
            "sort_order",
            name="uq_audit_template_criteria_template_sort_order",
        ),
    )
    op.create_index(
        "ix_audit_template_criteria_template_id",
        "audit_template_criteria",
        ["template_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_audit_template_criteria_template_id", table_name="audit_template_criteria")
    op.drop_table("audit_template_criteria")
    op.drop_table("audit_templates")
