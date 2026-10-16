from fastapi.testclient import TestClient


def _question(prompt: str = "Question", sort_order: int = 1) -> dict:
    return {
        "prompt": prompt,
        "sort_order": sort_order,
        "options": [
            {"label": "Correct", "is_correct": True, "sort_order": 1},
            {"label": "Incorrect", "is_correct": False, "sort_order": 2},
        ],
    }


def _lesson(title: str = "Lesson", sort_order: int = 1) -> dict:
    return {
        "title": title,
        "summary": "Summary",
        "theory": "Theory text",
        "sort_order": sort_order,
        "questions": [_question(sort_order=1)],
    }


def _course_payload(**overrides) -> dict:
    payload = {
        "title": "Ruta Ofertas",
        "description": "Training for the Ofertas store",
        "stores": ["Ofertas"],
        "lessons": [_lesson()],
    }
    payload.update(overrides)
    return payload


def test_create_course_returns_ordered_lessons_and_questions(client: TestClient) -> None:
    response = client.post(
        "/courses",
        json=_course_payload(
            lessons=[
                _lesson("Second lesson", sort_order=2),
                _lesson("First lesson", sort_order=1),
            ]
        ),
    )

    assert response.status_code == 201
    body = response.json()
    assert body["title"] == "Ruta Ofertas"
    assert body["active"] is True
    assert [lesson["sort_order"] for lesson in body["lessons"]] == [1, 2]
    assert [lesson["title"] for lesson in body["lessons"]] == ["First lesson", "Second lesson"]
    assert body["lessons"][0]["questions"][0]["options"][0]["is_correct"] is True


def test_create_course_with_theory_images(client: TestClient) -> None:
    payload = _course_payload(
        lessons=[
            {
                **_lesson(),
                "theory_images": [{"url": "https://example.com/a.png", "sort_order": 1}],
            }
        ]
    )

    response = client.post("/courses", json=payload)

    assert response.status_code == 201
    assert response.json()["lessons"][0]["theory_images"][0]["url"] == "https://example.com/a.png"


def test_list_and_get_course(client: TestClient) -> None:
    created = client.post("/courses", json=_course_payload()).json()

    list_response = client.get("/courses")
    get_response = client.get(f"/courses/{created['id']}")

    assert list_response.status_code == 200
    assert [course["id"] for course in list_response.json()] == [created["id"]]
    assert get_response.status_code == 200
    assert get_response.json()["stores"][0]["store_code"] == "Ofertas"


def test_replace_course_rewrites_lessons(client: TestClient) -> None:
    created = client.post("/courses", json=_course_payload()).json()

    response = client.put(
        f"/courses/{created['id']}",
        json=_course_payload(
            title="Ruta Ofertas actualizada",
            stores=["Ofertas", "Mexi"],
            lessons=[_lesson("Updated lesson", sort_order=1)],
        ),
    )

    assert response.status_code == 200
    body = response.json()
    assert body["title"] == "Ruta Ofertas actualizada"
    assert sorted(store["store_code"] for store in body["stores"]) == ["Mexi", "Ofertas"]
    assert [lesson["title"] for lesson in body["lessons"]] == ["Updated lesson"]


def test_update_course_active_state(client: TestClient) -> None:
    created = client.post("/courses", json=_course_payload()).json()

    response = client.patch(f"/courses/{created['id']}/active", json={"is_active": False})

    assert response.status_code == 200
    assert response.json()["active"] is False


def test_rejects_course_without_stores(client: TestClient) -> None:
    response = client.post("/courses", json=_course_payload(stores=[]))

    assert response.status_code == 422


def test_rejects_lesson_without_questions(client: TestClient) -> None:
    response = client.post(
        "/courses",
        json=_course_payload(lessons=[{**_lesson(), "questions": []}]),
    )

    assert response.status_code == 422


def test_rejects_question_with_single_option(client: TestClient) -> None:
    response = client.post(
        "/courses",
        json=_course_payload(
            lessons=[
                {
                    **_lesson(),
                    "questions": [
                        {
                            "prompt": "Invalid",
                            "sort_order": 1,
                            "options": [{"label": "Only one", "is_correct": True, "sort_order": 1}],
                        }
                    ],
                }
            ]
        ),
    )

    assert response.status_code == 422


def test_rejects_single_answer_mode_without_exactly_one_correct_option(client: TestClient) -> None:
    response = client.post(
        "/courses",
        json=_course_payload(
            lessons=[
                {
                    **_lesson(),
                    "questions": [
                        {
                            "prompt": "Invalid",
                            "sort_order": 1,
                            "options": [
                                {"label": "First", "is_correct": True, "sort_order": 1},
                                {"label": "Second", "is_correct": True, "sort_order": 2},
                            ],
                        }
                    ],
                }
            ]
        ),
    )

    assert response.status_code == 422


def test_rejects_duplicate_lesson_sort_orders(client: TestClient) -> None:
    response = client.post(
        "/courses",
        json=_course_payload(
            lessons=[_lesson("First", sort_order=1), _lesson("Second", sort_order=1)]
        ),
    )

    assert response.status_code == 422


def test_get_missing_course_returns_404(client: TestClient) -> None:
    response = client.get("/courses/999")

    assert response.status_code == 404
