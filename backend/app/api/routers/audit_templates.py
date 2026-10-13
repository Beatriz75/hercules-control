from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.api.deps import require_permission
from app.core.permissions import Permission
from app.db.session import get_db
from app.models.audit_template import AuditTemplate, AuditTemplateCriterion
from app.schemas.audit_template import (
    AuditTemplateActiveUpdate,
    AuditTemplateCreate,
    AuditTemplateRead,
)

router = APIRouter(prefix="/audit-templates", tags=["audit-templates"])


def _get_template_or_404(db: Session, template_id: int) -> AuditTemplate:
    template = db.scalar(
        select(AuditTemplate)
        .options(selectinload(AuditTemplate.criteria))
        .where(AuditTemplate.id == template_id)
    )
    if template is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No se encontró la plantilla de auditoría.")
    return template


@router.post(
    "",
    response_model=AuditTemplateRead,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(require_permission(Permission.AUDITS_MANAGE))],
)
def create_audit_template(payload: AuditTemplateCreate, db: Session = Depends(get_db)) -> AuditTemplate:
    template = AuditTemplate(
        name=payload.name,
        description=payload.description,
        is_active=payload.is_active,
        criteria=[
            AuditTemplateCriterion(
                label=criterion.label,
                sort_order=criterion.sort_order,
                is_required=criterion.is_required,
            )
            for criterion in sorted(payload.criteria, key=lambda item: item.sort_order)
        ],
    )
    db.add(template)
    db.commit()
    db.refresh(template)
    return _get_template_or_404(db, template.id)


@router.get("", response_model=list[AuditTemplateRead], dependencies=[Depends(require_permission(Permission.AUDITS_VIEW))])
def list_audit_templates(db: Session = Depends(get_db)) -> list[AuditTemplate]:
    return list(
        db.scalars(
            select(AuditTemplate)
            .options(selectinload(AuditTemplate.criteria))
            .order_by(AuditTemplate.id)
        )
    )


@router.get("/{template_id}", response_model=AuditTemplateRead, dependencies=[Depends(require_permission(Permission.AUDITS_VIEW))])
def get_audit_template(template_id: int, db: Session = Depends(get_db)) -> AuditTemplate:
    return _get_template_or_404(db, template_id)


@router.patch(
    "/{template_id}/active",
    response_model=AuditTemplateRead,
    dependencies=[Depends(require_permission(Permission.AUDITS_MANAGE))],
)
def update_audit_template_active(
    template_id: int,
    payload: AuditTemplateActiveUpdate,
    db: Session = Depends(get_db),
) -> AuditTemplate:
    template = _get_template_or_404(db, template_id)
    template.is_active = payload.is_active
    db.commit()
    db.refresh(template)
    return _get_template_or_404(db, template.id)
