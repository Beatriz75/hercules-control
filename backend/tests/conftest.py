from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.api.deps import get_current_user
from app.core.permissions import Role
from app.db.base import Base
from app.db.session import get_db
from app.main import create_app
from app.models.user import User
import app.models  # noqa: F401


class ActingUser:
    """Which user the test client is acting as; tests switch it with `client.act_as(...)`."""

    def __init__(self) -> None:
        self.user = _fake_user(Role.ADMINISTRADOR, "admin")

    def __call__(self) -> User:
        return self.user


def _fake_user(role: Role, username: str, store_code: str | None = None, user_id: int | None = None) -> User:
    return User(id=user_id if user_id is not None else 100_000 + len(username), username=username, full_name=username, role=role, store_code=store_code, active=True)


@pytest.fixture()
def engine():
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    return engine


@pytest.fixture()
def client(engine) -> Generator[TestClient, None, None]:
    """Client authenticated by dependency override; defaults to an administrator."""

    def override_get_db() -> Generator[Session, None, None]:
        with Session(engine) as session:
            yield session

    acting = ActingUser()
    app = create_app()
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = acting

    with TestClient(app) as test_client:

        def act_as(role: Role, username: str = "user", store_code: str | None = None, user_id: int | None = None) -> None:
            acting.user = _fake_user(role, username, store_code, user_id)

        test_client.act_as = act_as  # type: ignore[attr-defined]
        yield test_client


@pytest.fixture()
def real_auth_client(engine) -> Generator[TestClient, None, None]:
    """Client with no auth override: requests go through real login and JWT checks."""

    def override_get_db() -> Generator[Session, None, None]:
        with Session(engine) as session:
            yield session

    app = create_app()
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client


def post_attempt(client: TestClient, payload: dict):
    """Start a practice for payload["lesson_id"] and submit payload["answers"] to it.

    Returns the start response when starting fails (e.g. 404/409), otherwise the submit response.
    """
    started = client.post("/training-attempts/start", json={"lesson_id": payload["lesson_id"]})
    if started.status_code != 201:
        return started
    return client.post(
        "/training-attempts", json={"session_id": started.json()["session_id"], "answers": payload["answers"]}
    )
