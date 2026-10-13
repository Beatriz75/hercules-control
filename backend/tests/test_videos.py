from fastapi.testclient import TestClient

from app.core.permissions import Role

YOUTUBE = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"


def _payload(question_video: str | None = None, theory_videos: list | None = None) -> dict:
    return {
        "title": "Videos",
        "stores": ["Ofertas"],
        "lessons": [
            {
                "title": "L1",
                "summary": "s",
                "theory": "t",
                "sort_order": 1,
                "theory_videos": theory_videos or [],
                "questions": [
                    {
                        "prompt": "Mira el video y responde",
                        "sort_order": 1,
                        "video_url": question_video,
                        "options": [
                            {"label": "Bien", "is_correct": True, "sort_order": 1},
                            {"label": "Mal", "sort_order": 2},
                        ],
                    }
                ],
            }
        ],
    }


def test_videos_in_theory_and_questions_reach_the_student(client: TestClient) -> None:
    client.act_as(Role.ADMINISTRADOR, "admin")
    course = client.post(
        "/courses",
        json=_payload(YOUTUBE, [{"url": "https://drive.google.com/file/d/abc/view", "title": "Cómo validar", "sort_order": 1}]),
    ).json()
    lesson = course["lessons"][0]
    assert lesson["theory_videos"][0]["title"] == "Cómo validar"
    assert lesson["questions"][0]["video_url"] == YOUTUBE
    assert client.get("/questions").json()[0]["video_url"] == YOUTUBE

    client.act_as(Role.ALUMNO, "cobrador1", "Ofertas")
    assigned = client.get("/courses/assigned").json()
    assert assigned[0]["lessons"][0]["theory_videos"][0]["url"].startswith("https://drive.google.com")
    started = client.post("/training-attempts/start", json={"lesson_id": lesson["id"]}).json()
    assert started["questions"][0]["video_url"] == YOUTUBE


def test_editing_keeps_and_changes_videos(client: TestClient) -> None:
    client.act_as(Role.ADMINISTRADOR, "admin")
    course = client.post("/courses", json=_payload(YOUTUBE)).json()
    question = course["lessons"][0]["questions"][0]
    body = {
        "prompt": question["prompt"],
        "video_url": "https://vimeo.com/123456",
        "options": [{"id": o["id"], "label": o["label"], "is_correct": o["is_correct"], "sort_order": o["sort_order"]} for o in question["options"]],
    }
    assert client.put(f"/questions/{question['id']}", json=body).json()["video_url"] == "https://vimeo.com/123456"
    assert client.put(f"/questions/{question['id']}", json=body | {"video_url": ""}).json()["video_url"] is None


def test_rejects_unsupported_video_links(client: TestClient) -> None:
    client.act_as(Role.ADMINISTRADOR, "admin")
    bad_host = client.post("/courses", json=_payload("https://example.com/video"))
    assert bad_host.status_code == 422
    assert "YouTube, Google Drive, Vimeo" in bad_host.json()["detail"][0]["msg"]
    no_scheme = client.post("/courses", json=_payload(None, [{"url": "youtube.com/watch?v=x", "sort_order": 1}]))
    assert no_scheme.status_code == 422
    assert "http" in no_scheme.json()["detail"][0]["msg"]
    mp4 = client.post("/courses", json=_payload("https://cdn.ejemplo.com/curso/clase1.mp4"))
    assert mp4.status_code == 201
