from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.api.deps import require_permission
from app.core.permissions import Permission
from app.db.session import get_db
from app.models.audit_template import AuditTemplate
from app.models.operational_audit import OperationalAudit, OperationalAuditAnswer
from app.schemas.operational_audit import (
    OperationalAuditCreate,
    OperationalAuditRead,
)

router = APIRouter(prefix="/operational-audits", tags=["operational-audits"])


def _get_audit_or_404(db: Session, audit_id: int) -> OperationalAudit:
    audit = db.scalar(
        select(OperationalAudit)
        .options(selectinload(OperationalAudit.answers), selectinload(OperationalAudit.findings))
        .where(OperationalAudit.id == audit_id)
    )
    if audit is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No se encontró la auditoría.")
    return audit


@router.post(
    "",
    response_model=OperationalAuditRead,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(require_permission(Permission.AUDITS_CREATE))],
)
def create_operational_audit(
    payload: OperationalAuditCreate,
    db: Session = Depends(get_db),
) -> OperationalAudit:
    template = db.scalar(
        select(AuditTemplate)
        .options(selectinload(AuditTemplate.criteria))
        .where(AuditTemplate.id == payload.template_id)
    )
    if template is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No se encontró la plantilla de auditoría.")
    if not template.is_active:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="La plantilla de auditoría está inactiva.")

    criteria_by_id = {criterion.id: criterion for criterion in template.criteria}
    invalid_criterion_ids = [
        answer.criterion_id for answer in payload.answers if answer.criterion_id not in criteria_by_id
    ]
    if invalid_criterion_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Las respuestas deben corresponder a criterios de la plantilla elegida.",
        )

    required_criterion_ids = {criterion.id for criterion in template.criteria if criterion.is_required}
    answered_criterion_ids = {answer.criterion_id for answer in payload.answers}
    if missing_criterion_ids := required_criterion_ids - answered_criterion_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Faltan respuestas de criterios obligatorios: {sorted(missing_criterion_ids)}",
        )

    answer_scores = [answer.answer_score for answer in payload.answers if answer.answer_score is not None]
    score = payload.score
    if score is None and answer_scores:
        score = sum(answer_scores) / len(answer_scores)

    audit = OperationalAudit(
        template_id=payload.template_id,
        target_type=payload.target_type,
        target_reference=payload.target_reference,
        auditor_name=payload.auditor_name,
        status=payload.status,
        score=score,
        notes=payload.notes,
        completed_at=datetime.now(UTC) if payload.status == "completed" else None,
        answers=[
            OperationalAuditAnswer(
                criterion_id=answer.criterion_id,
                answer_text=answer.answer_text,
                answer_score=answer.answer_score,
                notes=answer.notes,
                criterion_label=criteria_by_id[answer.criterion_id].label,
                sort_order=criteria_by_id[answer.criterion_id].sort_order,
            )
            for answer in sorted(payload.answers, key=lambda item: criteria_by_id[item.criterion_id].sort_order)
        ],
    )
    db.add(audit)
    db.commit()
    db.refresh(audit)
    return _get_audit_or_404(db, audit.id)


@router.get("", response_model=list[OperationalAuditRead], dependencies=[Depends(require_permission(Permission.AUDITS_VIEW))])
def list_operational_audits(db: Session = Depends(get_db)) -> list[OperationalAudit]:
    return list(
        db.scalars(
            select(OperationalAudit)
            .options(selectinload(OperationalAudit.answers), selectinload(OperationalAudit.findings))
            .order_by(OperationalAudit.id)
        )
    )


@router.get("/{audit_id}", response_model=OperationalAuditRead, dependencies=[Depends(require_permission(Permission.AUDITS_VIEW))])
def get_operational_audit(audit_id: int, db: Session = Depends(get_db)) -> OperationalAudit:
    return _get_audit_or_404(db, audit_id)
