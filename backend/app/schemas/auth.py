from pydantic import BaseModel


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class CurrentUserRead(BaseModel):
    id: int
    username: str
    full_name: str
    role: str
    store_code: str | None
    permissions: list[str]
