"""Create the first administrator when the users table is empty.

Reads INITIAL_ADMIN_USERNAME / INITIAL_ADMIN_PASSWORD. Safe to run on every start:
it does nothing once any user exists.
"""

import os
import sys

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.permissions import Role
from app.core.security import hash_password
from app.db.session import get_engine
from app.models.user import User


def main() -> int:
    with Session(get_engine()) as db:
        if db.scalar(select(func.count()).select_from(User)):
            print("bootstrap_admin: users already exist, nothing to do")
            return 0

        username = os.getenv("INITIAL_ADMIN_USERNAME", "").strip().lower()
        password = os.getenv("INITIAL_ADMIN_PASSWORD", "")
        if not username or len(password) < 8:
            print("bootstrap_admin: set INITIAL_ADMIN_USERNAME and INITIAL_ADMIN_PASSWORD (8+ chars)", file=sys.stderr)
            return 1

        db.add(
            User(
                username=username,
                full_name=os.getenv("INITIAL_ADMIN_FULL_NAME", "Administrador"),
                password_hash=hash_password(password),
                role=Role.ADMINISTRADOR,
                active=True,
            )
        )
        db.commit()
        print(f"bootstrap_admin: created administrator '{username}'")
        return 0


if __name__ == "__main__":
    sys.exit(main())
