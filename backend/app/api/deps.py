from collections.abc import Callable
from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.core.config import Settings, get_settings
from app.core.permissions import Permission, permissions_for
from app.core.security import decode_access_token
from app.db.session import get_db
from app.models.user import User

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")


def get_current_user(
    token: Annotated[str, Depends(oauth2_scheme)],
    settings: Annotated[Settings, Depends(get_settings)],
    db: Annotated[Session, Depends(get_db)],
) -> User:
    user_id = decode_access_token(token, settings)
    user = db.get(User, user_id) if user_id is not None else None
    if user is None or not user.active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Tu sesión no es válida o expiró. Vuelve a iniciar sesión.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user


def has_permission(user: User, permission: Permission) -> bool:
    return permission in permissions_for(user.role)


def require_permission(*permissions: Permission) -> Callable[..., User]:
    """Allow the request when the user has at least one of the given permissions."""

    def dependency(user: Annotated[User, Depends(get_current_user)]) -> User:
        if not any(has_permission(user, permission) for permission in permissions):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="No tienes permiso para realizar esta acción.")
        return user

    return dependency
