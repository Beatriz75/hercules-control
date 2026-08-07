"""Create operational audits.

Revision ID: 20260806_0003
Revises: 20260806_0002
Create Date: 2026-08-06 00:20:00
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "20260806_0003"
down_revision: str | None = "20260806_0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "operational_audits",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("template_id", sa.Integer(), nullable=False),
        sa.Column("target_type", sa.String(length=20), nullable=False),
        sa.Column("target_reference", sa.String(length=120), nullable=False),
        sa.Column("auditor_name", sa.String(length=120), nullable=False),
        sa.Column("status", sa.String(length=20), server_default="completed", nullable=False),
        sa.Column("score", sa.Float(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["template_id"], ["audit_templates.id"]),
    )
    op.create_index("ix_operational_audits_template_id", "operational_audits", ["template_id"])

    op.create_table(
        "operational_audit_answers",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("audit_id", sa.Integer(), nullable=False),
        sa.Column("criterion_id", sa.Integer(), nullable=False),
        sa.Column("answer_text", sa.Text(), nullable=True),
        sa.Column("answer_score", sa.Float(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("criterion_label", sa.String(length=200), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["audit_id"], ["operational_audits.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["criterion_id"], ["audit_template_criteria.id"]),
    )
    op.create_index("ix_operational_audit_answers_audit_id", "operational_audit_answers", ["audit_id"])
    op.create_index(
        "ix_operational_audit_answers_criterion_id",
        "operational_audit_answers",
        ["criterion_id"],
    )

    op.create_table(
        "operational_audit_findings",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("audit_id", sa.Integer(), nullable=False),
        sa.Column("severity", sa.String(length=20), nullable=False),
        sa.Column("finding_type", sa.String(length=80), nullable=True),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("status", sa.String(length=20), server_default="open", nullable=False),
        sa.Column("employee_reference", sa.String(length=120), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["audit_id"], ["operational_audits.id"], ondelete="CASCADE"),
    )
    op.create_index("ix_operational_audit_findings_audit_id", "operational_audit_findings", ["audit_id"])


def downgrade() -> None:
    op.drop_index("ix_operational_audit_findings_audit_id", table_name="operational_audit_findings")
    op.drop_table("operational_audit_findings")
    op.drop_index("ix_operational_audit_answers_criterion_id", table_name="operational_audit_answers")
    op.drop_index("ix_operational_audit_answers_audit_id", table_name="operational_audit_answers")
    op.drop_table("operational_audit_answers")
    op.drop_index("ix_operational_audits_template_id", table_name="operational_audits")
    op.drop_table("operational_audits")
