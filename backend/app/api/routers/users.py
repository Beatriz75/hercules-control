from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import require_permission
from app.core.permissions import Permission, Role
from app.core.security import hash_password
from app.db.session import get_db
from app.models.user import User
from app.schemas.user import PasswordReset, UserCreate, UserRead, UserUpdate

router = APIRouter(prefix="/users", tags=["users"])

AdminUser = Annotated[User, Depends(require_permission(Permission.USERS_MANAGE))]


def _get_user_or_404(db: Session, user_id: int) -> User:
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No se encontró el usuario.")
    return user


@router.get("", response_model=list[UserRead])
def list_users(_: AdminUser, db: Session = Depends(get_db)) -> list[User]:
    return list(db.scalars(select(User).order_by(User.username)))


@router.post("", response_model=UserRead, status_code=status.HTTP_201_CREATED)
def create_user(payload: UserCreate, _: AdminUser, db: Session = Depends(get_db)) -> User:
    username = payload.username.lower()
    if db.scalar(select(User).where(User.username == username)) is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Ya existe un usuario con ese nombre de usuario.")
    user = User(
        username=username,
        full_name=payload.full_name,
        password_hash=hash_password(payload.password),
        role=payload.role,
        store_code=payload.store_code,
        active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.patch("/{user_id}", response_model=UserRead)
def update_user(user_id: int, payload: UserUpdate, admin: AdminUser, db: Session = Depends(get_db)) -> User:
    user = _get_user_or_404(db, user_id)
    changes = payload.model_dump(exclude_unset=True)

    removes_own_access = changes.get("active") is False or changes.get("role", Role.ADMINISTRADOR) != Role.ADMINISTRADOR
    if user.id == admin.id and removes_own_access:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No puedes desactivarte ni quitarte el rol de administrador a ti mismo.")

    for key, value in changes.items():
        setattr(user, key, value)
    if user.role == Role.ALUMNO and not user.store_code:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Un alumno debe tener una tienda asignada.")

    db.commit()
    db.refresh(user)
    return user


@router.post("/{user_id}/password", status_code=status.HTTP_204_NO_CONTENT)
def reset_password(user_id: int, payload: PasswordReset, _: AdminUser, db: Session = Depends(get_db)) -> None:
    user = _get_user_or_404(db, user_id)
    user.password_hash = hash_password(payload.password)
    db.commit()
