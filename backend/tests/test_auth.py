from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.permissions import Role
from app.core.security import hash_password, verify_password
from app.models.user import User


def _add_user(engine, username: str, password: str, role: Role, store_code: str | None = None, active: bool = True) -> int:
    with Session(engine) as db:
        user = User(
            username=username,
            full_name=username.title(),
            password_hash=hash_password(password),
            role=role,
            store_code=store_code,
            active=active,
        )
        db.add(user)
        db.commit()
        return user.id


def _login(client: TestClient, username: str, password: str):
    return client.post("/auth/token", data={"username": username, "password": password})


def _auth_headers(client: TestClient, username: str, password: str) -> dict:
    token = _login(client, username, password).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_password_hash_round_trip() -> None:
    password_hash = hash_password("s3cret-pass")
    assert verify_password("s3cret-pass", password_hash)
    assert not verify_password("wrong-pass", password_hash)
    assert hash_password("s3cret-pass") != password_hash  # random salt


def test_login_returns_token_and_me_returns_permissions(engine, real_auth_client: TestClient) -> None:
    _add_user(engine, "admin", "admin-pass-1", Role.ADMINISTRADOR)

    response = _login(real_auth_client, "Admin", "admin-pass-1")
    assert response.status_code == 200
    assert response.json()["token_type"] == "bearer"

    me = real_auth_client.get("/auth/me", headers=_auth_headers(real_auth_client, "admin", "admin-pass-1"))
    assert me.status_code == 200
    body = me.json()
    assert body["username"] == "admin"
    assert body["role"] == "administrador"
    assert "users.manage" in body["permissions"]
    assert "courses.take" not in body["permissions"]


def test_login_rejects_wrong_password_and_inactive_user(engine, real_auth_client: TestClient) -> None:
    _add_user(engine, "ana", "ana-pass-123", Role.SUPERVISOR)
    _add_user(engine, "beto", "beto-pass-123", Role.SUPERVISOR, active=False)

    assert _login(real_auth_client, "ana", "nope-nope").status_code == 401
    assert _login(real_auth_client, "nadie", "whatever1").status_code == 401
    assert _login(real_auth_client, "beto", "beto-pass-123").status_code == 401


def test_protected_endpoints_require_token(real_auth_client: TestClient) -> None:
    assert real_auth_client.get("/courses").status_code == 401
    assert real_auth_client.get("/courses", headers={"Authorization": "Bearer garbage"}).status_code == 401
    assert real_auth_client.get("/health").status_code == 200


def test_deactivated_user_token_stops_working(engine, real_auth_client: TestClient) -> None:
    user_id = _add_user(engine, "caro", "caro-pass-123", Role.CONSULTA_GERENCIAL)
    headers = _auth_headers(real_auth_client, "caro", "caro-pass-123")
    assert real_auth_client.get("/auth/me", headers=headers).status_code == 200

    with Session(engine) as db:
        db.get(User, user_id).active = False
        db.commit()

    assert real_auth_client.get("/auth/me", headers=headers).status_code == 401


def test_change_password(engine, real_auth_client: TestClient) -> None:
    _add_user(engine, "dani", "old-pass-123", Role.ALUMNO, store_code="Ofertas")
    headers = _auth_headers(real_auth_client, "dani", "old-pass-123")

    wrong = real_auth_client.post(
        "/auth/change-password",
        json={"current_password": "bad-pass-123", "new_password": "new-pass-123"},
        headers=headers,
    )
    assert wrong.status_code == 400

    ok = real_auth_client.post(
        "/auth/change-password",
        json={"current_password": "old-pass-123", "new_password": "new-pass-123"},
        headers=headers,
    )
    assert ok.status_code == 204
    assert _login(real_auth_client, "dani", "old-pass-123").status_code == 401
    assert _login(real_auth_client, "dani", "new-pass-123").status_code == 200
