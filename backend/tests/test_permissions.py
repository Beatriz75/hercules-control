from fastapi.testclient import TestClient

from tests.conftest import post_attempt

from app.core.permissions import ROLE_PERMISSIONS, Permission, Role


def _course_payload(title: str, stores: list[str], status: str = "active", active: bool = True) -> dict:
    return {
        "title": title,
        "status": status,
        "active": active,
        "stores": stores,
        "lessons": [
            {
                "title": "Leccion",
                "summary": "Summary",
                "theory": "Theory",
                "sort_order": 1,
                "questions": [
                    {
                        "prompt": "Pregunta",
                        "sort_order": 1,
                        "options": [
                            {"label": "Bien", "is_correct": True, "sort_order": 1},
                            {"label": "Mal", "is_correct": False, "sort_order": 2},
                        ],
                    }
                ],
            }
        ],
    }


def _create_course(client: TestClient, *args, **kwargs) -> dict:
    client.act_as(Role.ADMINISTRADOR, "admin")
    response = client.post("/courses", json=_course_payload(*args, **kwargs))
    assert response.status_code == 201
    return response.json()


def test_every_role_has_permissions_defined() -> None:
    assert set(ROLE_PERMISSIONS) == set(Role)
    assert Permission.USERS_MANAGE in ROLE_PERMISSIONS[Role.ADMINISTRADOR]
    assert ROLE_PERMISSIONS[Role.ALUMNO] == {Permission.COURSES_TAKE}


def test_only_admin_manages_courses(client: TestClient) -> None:
    for role in (Role.SUPERVISOR, Role.AUDITOR, Role.CONSULTA_GERENCIAL, Role.ALUMNO):
        client.act_as(role, "someone", "Ofertas")
        response = client.post("/courses", json=_course_payload("X", ["Ofertas"]))
        assert response.status_code == 403, role


def test_course_catalog_visibility_by_role(client: TestClient) -> None:
    _create_course(client, "Ruta", ["Ofertas"])

    for role, expected in (
        (Role.SUPERVISOR, 200),
        (Role.CONSULTA_GERENCIAL, 200),
        (Role.AUDITOR, 403),
        (Role.ALUMNO, 403),
    ):
        client.act_as(role, "someone", "Ofertas")
        assert client.get("/courses").status_code == expected, role


def test_student_sees_only_published_courses_of_their_store_without_answers(client: TestClient) -> None:
    _create_course(client, "Ofertas activo", ["Ofertas"])
    _create_course(client, "Mexi activo", ["Mexi"])
    _create_course(client, "Ofertas borrador", ["Ofertas"], status="draft")
    _create_course(client, "Ofertas inactivo", ["Ofertas"], active=False)
    _create_course(client, "Compartido", ["Ofertas", "Mexi"])

    client.act_as(Role.ALUMNO, "cobrador1", "Ofertas")
    response = client.get("/courses/assigned")

    assert response.status_code == 200
    body = response.json()
    assert [course["title"] for course in body] == ["Ofertas activo", "Compartido"]
    lesson = body[0]["lessons"][0]
    assert "questions" not in lesson  # the bank is only revealed per practice
    assert lesson["question_bank_size"] == 1
    assert lesson["questions_per_attempt"] == 1

    started = client.post("/training-attempts/start", json={"lesson_id": lesson["id"]})
    assert started.status_code == 201
    assert "is_correct" not in started.json()["questions"][0]["options"][0]


def test_staff_cannot_use_student_endpoints(client: TestClient) -> None:
    course = _create_course(client, "Ruta", ["Ofertas"])
    lesson_id = course["lessons"][0]["id"]

    client.act_as(Role.ADMINISTRADOR, "admin")
    assert client.get("/courses/assigned").status_code == 403
    assert client.patch(f"/lesson-progress/{lesson_id}/theory-completed").status_code == 403


def test_student_cannot_take_lessons_of_another_store(client: TestClient) -> None:
    course = _create_course(client, "Solo Mexi", ["Mexi"])
    lesson = course["lessons"][0]
    question = lesson["questions"][0]

    client.act_as(Role.ALUMNO, "cobrador1", "Ofertas")
    attempt = post_attempt(
        client,
        {
            "lesson_id": lesson["id"],
            "answers": [{"question_id": question["id"], "selected_option_ids": [question["options"][0]["id"]]}],
        },
    )
    assert attempt.status_code == 404
    assert client.patch(f"/lesson-progress/{lesson['id']}/theory-completed").status_code == 404


def test_student_only_sees_own_progress_and_staff_sees_everyone(client: TestClient) -> None:
    course = _create_course(client, "Ruta", ["Ofertas"])
    lesson = course["lessons"][0]
    question = lesson["questions"][0]
    payload = {
        "lesson_id": lesson["id"],
        "answers": [{"question_id": question["id"], "selected_option_ids": [question["options"][0]["id"]]}],
    }

    client.act_as(Role.ALUMNO, "cobrador1", "Ofertas")
    first = post_attempt(client, payload).json()
    assert first["employee_reference"] == "cobrador1"
    client.act_as(Role.ALUMNO, "cobrador2", "Ofertas")
    post_attempt(client, payload)

    # A student asking for someone else's data still gets only their own.
    mine = client.get("/training-attempts", params={"employee_reference": "cobrador1"}).json()
    assert {row["employee_reference"] for row in mine} == {"cobrador2"}
    assert client.get(f"/training-attempts/{first['id']}").status_code == 404
    progress = client.get("/lesson-progress", params={"employee_reference": "cobrador1"}).json()
    assert {row["employee_reference"] for row in progress} == {"cobrador2"}

    client.act_as(Role.SUPERVISOR, "sup")
    everyone = client.get("/training-attempts").json()
    assert {row["employee_reference"] for row in everyone} == {"cobrador1", "cobrador2"}
    assert client.get(f"/training-attempts/{first['id']}").status_code == 200
    assert post_attempt(client, payload).status_code == 403


def test_audit_endpoints_permissions(client: TestClient) -> None:
    client.act_as(Role.ALUMNO, "cobrador1", "Ofertas")
    assert client.get("/audit-templates").status_code == 403
    assert client.get("/operational-audits").status_code == 403

    client.act_as(Role.AUDITOR, "aud")
    assert client.get("/audit-templates").status_code == 200
    assert client.get("/operational-audits").status_code == 200
    assert client.post("/audit-templates", json={}).status_code == 403


def test_user_management_is_admin_only(client: TestClient) -> None:
    client.act_as(Role.SUPERVISOR, "sup")
    assert client.get("/users").status_code == 403

    client.act_as(Role.ADMINISTRADOR, "admin")
    created = client.post(
        "/users",
        json={"username": "Cobrador1", "full_name": "Cobrador Uno", "password": "pass-1234", "role": "alumno", "store_code": "Ofertas"},
    )
    assert created.status_code == 201
    user = created.json()
    assert user["username"] == "cobrador1"
    assert "password_hash" not in user

    duplicate = client.post(
        "/users",
        json={"username": "cobrador1", "full_name": "Otro", "password": "pass-1234", "role": "supervisor"},
    )
    assert duplicate.status_code == 409

    no_store = client.post(
        "/users", json={"username": "cobrador2", "full_name": "Sin tienda", "password": "pass-1234", "role": "alumno"}
    )
    assert no_store.status_code == 422
    bad_role = client.post(
        "/users", json={"username": "x-user", "full_name": "X", "password": "pass-1234", "role": "dios"}
    )
    assert bad_role.status_code == 422

    updated = client.patch(f"/users/{user['id']}", json={"active": False})
    assert updated.status_code == 200
    assert updated.json()["active"] is False
    assert client.patch(f"/users/{user['id']}", json={"store_code": None}).status_code == 422
    assert client.post(f"/users/{user['id']}/password", json={"password": "new-pass-1"}).status_code == 204
    assert [row["username"] for row in client.get("/users").json()] == ["cobrador1"]


def test_admin_cannot_remove_own_access(client: TestClient) -> None:
    client.act_as(Role.ADMINISTRADOR, "admin")
    created = client.post(
        "/users", json={"username": "jefa", "full_name": "Jefa", "password": "pass-1234", "role": "administrador"}
    ).json()

    client.act_as(Role.ADMINISTRADOR, "jefa", user_id=created["id"])

    assert client.patch(f"/users/{created['id']}", json={"active": False}).status_code == 400
    assert client.patch(f"/users/{created['id']}", json={"role": "supervisor"}).status_code == 400
    assert client.patch(f"/users/{created['id']}", json={"full_name": "Jefa Nueva"}).status_code == 200

