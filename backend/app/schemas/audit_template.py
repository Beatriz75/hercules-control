from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, model_validator


class AuditTemplateCriterionCreate(BaseModel):
    label: str = Field(min_length=1, max_length=200)
    sort_order: int = Field(ge=1)
    is_required: bool = True


class AuditTemplateCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    description: str | None = None
    is_active: bool = True
    criteria: list[AuditTemplateCriterionCreate] = Field(min_length=1)

    @model_validator(mode="after")
    def validate_unique_sort_orders(self) -> "AuditTemplateCreate":
        sort_orders = [criterion.sort_order for criterion in self.criteria]
        if len(sort_orders) != len(set(sort_orders)):
            raise ValueError("criteria sort_order values must be unique")
        return self


class AuditTemplateActiveUpdate(BaseModel):
    is_active: bool


class AuditTemplateCriterionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    label: str
    sort_order: int
    is_required: bool
    created_at: datetime
    updated_at: datetime


class AuditTemplateRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: str | None
    is_active: bool
    created_at: datetime
    updated_at: datetime
    criteria: list[AuditTemplateCriterionRead]
