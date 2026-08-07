from datetime import datetime

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.audit_template import AuditTemplate, AuditTemplateCriterion


class OperationalAudit(Base):
    __tablename__ = "operational_audits"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    template_id: Mapped[int] = mapped_column(ForeignKey("audit_templates.id"), nullable=False, index=True)
    target_type: Mapped[str] = mapped_column(String(20), nullable=False)
    target_reference: Mapped[str] = mapped_column(String(120), nullable=False)
    auditor_name: Mapped[str] = mapped_column(String(120), nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, server_default="completed")
    score: Mapped[float | None] = mapped_column(Float(), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text(), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    template: Mapped[AuditTemplate] = relationship()
    answers: Mapped[list["OperationalAuditAnswer"]] = relationship(
        back_populates="audit",
        cascade="all, delete-orphan",
        order_by="OperationalAuditAnswer.sort_order",
    )
    findings: Mapped[list["OperationalAuditFinding"]] = relationship(
        back_populates="audit",
        cascade="all, delete-orphan",
        order_by="OperationalAuditFinding.id",
    )


class OperationalAuditAnswer(Base):
    __tablename__ = "operational_audit_answers"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    audit_id: Mapped[int] = mapped_column(
        ForeignKey("operational_audits.id", ondelete="CASCADE"), nullable=False, index=True
    )
    criterion_id: Mapped[int] = mapped_column(ForeignKey("audit_template_criteria.id"), nullable=False, index=True)
    answer_text: Mapped[str | None] = mapped_column(Text(), nullable=True)
    answer_score: Mapped[float | None] = mapped_column(Float(), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text(), nullable=True)
    criterion_label: Mapped[str] = mapped_column(String(200), nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    audit: Mapped[OperationalAudit] = relationship(back_populates="answers")
    criterion: Mapped[AuditTemplateCriterion] = relationship()


class OperationalAuditFinding(Base):
    __tablename__ = "operational_audit_findings"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    audit_id: Mapped[int] = mapped_column(
        ForeignKey("operational_audits.id", ondelete="CASCADE"), nullable=False, index=True
    )
    severity: Mapped[str] = mapped_column(String(20), nullable=False)
    finding_type: Mapped[str | None] = mapped_column(String(80), nullable=True)
    description: Mapped[str] = mapped_column(Text(), nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, server_default="open")
    employee_reference: Mapped[str | None] = mapped_column(String(120), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    audit: Mapped[OperationalAudit] = relationship(back_populates="findings")
