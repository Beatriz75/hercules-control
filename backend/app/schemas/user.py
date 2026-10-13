from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.core.permissions import Role

USERNAME_PATTERN = r"^[A-Za-z0-9._-]+$"


class UserCreate(BaseModel):
    username: str = Field(min_length=3, max_length=60, pattern=USERNAME_PATTERN)
    full_name: str = Field(min_length=1, max_length=120)
    password: str = Field(min_length=8, max_length=128)
    role: Role
    store_code: str | None = Field(default=None, max_length=60)

    @model_validator(mode="after")
    def validate_store(self) -> "UserCreate":
        if self.role == Role.ALUMNO and not self.store_code:
            raise ValueError("Un alumno debe tener una tienda asignada.")
        return self


class UserUpdate(BaseModel):
    full_name: str | None = Field(default=None, min_length=1, max_length=120)
    role: Role | None = None
    store_code: str | None = Field(default=None, max_length=60)
    active: bool | None = None


class PasswordReset(BaseModel):
    password: str = Field(min_length=8, max_length=128)


class PasswordChange(BaseModel):
    current_password: str
    new_password: str = Field(min_length=8, max_length=128)


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    username: str
    full_name: str
    role: str
    store_code: str | None
    active: bool
    created_at: datetime
    updated_at: datetime
