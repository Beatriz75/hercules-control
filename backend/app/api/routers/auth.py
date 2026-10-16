from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.config import Settings, get_settings
from app.core.permissions import permissions_for
from app.core.security import create_access_token, hash_password, verify_password
from app.db.session import get_db
from app.models.user import User
from app.schemas.auth import CurrentUserRead, TokenResponse
from app.schemas.user import PasswordChange

router = APIRouter(prefix="/auth", tags=["auth"])


def build_current_user(user: User) -> CurrentUserRead:
    return CurrentUserRead(
        id=user.id,
        username=user.username,
        full_name=user.full_name,
        role=user.role,
        store_code=user.store_code,
        permissions=sorted(permissions_for(user.role)),
    )


@router.post("/token", response_model=TokenResponse)
def login_for_access_token(
    form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
    settings: Annotated[Settings, Depends(get_settings)],
    db: Annotated[Session, Depends(get_db)],
) -> TokenResponse:
    user = db.scalar(select(User).where(User.username == form_data.username.strip().lower()))
    if user is None or not user.active or not verify_password(form_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario o contraseña incorrectos.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return TokenResponse(access_token=create_access_token(user.id, settings))


@router.get("/me", response_model=CurrentUserRead)
def read_current_user(user: Annotated[User, Depends(get_current_user)]) -> CurrentUserRead:
    return build_current_user(user)


@router.post("/change-password", status_code=status.HTTP_204_NO_CONTENT)
def change_password(
    payload: PasswordChange,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> None:
    if not verify_password(payload.current_password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="La contraseña actual no es correcta.")
    user.password_hash = hash_password(payload.new_password)
    db.commit()
