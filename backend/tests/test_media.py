from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.core.config import Settings, get_settings
from app.core.permissions import Role

VIDEO = b"\x00\x00\x00\x18ftypmp42" + bytes(range(256)) * 40  # ~10 KB


@pytest.fixture()
def media_root(client: TestClient, tmp_path: Path) -> Path:
    client.app.dependency_overrides[get_settings] = lambda: Settings(media_root=str(tmp_path), max_upload_mb=1)
    return tmp_path


def _upload(client: TestClient, name: str, content: bytes, content_type: str):
    return client.post("/media", files={"file": (name, content, content_type)})


def test_upload_stores_a_random_name_and_serves_it(client: TestClient, media_root: Path) -> None:
    response = _upload(client, "Mi video.mp4", VIDEO, "video/mp4")
    assert response.status_code == 201, response.text
    body = response.json()
    assert body["size"] == len(VIDEO)
    assert body["content_type"] == "video/mp4"
    name = body["url"].removeprefix("/media/")
    assert body["url"].startswith("/media/") and name.endswith(".mp4") and len(name) == 36
    assert (media_root / name).read_bytes() == VIDEO
    assert [p.name for p in media_root.iterdir()] == [name]  # no leftover .part file

    downloaded = client.get(body["url"])
    assert downloaded.status_code == 200
    assert downloaded.content == VIDEO
    assert downloaded.headers["content-type"] == "video/mp4"


def test_download_supports_range_requests(client: TestClient, media_root: Path) -> None:
    url = _upload(client, "clip.webm", VIDEO, "video/webm").json()["url"]
    partial = client.get(url, headers={"Range": "bytes=100-199"})
    assert partial.status_code == 206
    assert partial.content == VIDEO[100:200]
    assert partial.headers["content-range"] == f"bytes 100-199/{len(VIDEO)}"
    assert partial.headers["accept-ranges"] == "bytes"


def test_images_are_accepted(client: TestClient, media_root: Path) -> None:
    for name, content_type in [("a.png", "image/png"), ("b.JPG", "image/jpeg"), ("c.webp", "image/webp"), ("d.gif", "image/gif")]:
        response = _upload(client, name, b"imagen", content_type)
        assert response.status_code == 201, (name, response.text)
        assert response.json()["url"].endswith(Path(name).suffix.lower())


@pytest.mark.parametrize(
    ("name", "content_type"),
    [("virus.exe", "application/octet-stream"), ("video.mp4", "text/html"), ("pagina.html", "text/html"), ("sin-extension", "video/mp4")],
)
def test_rejects_types_not_allowed(client: TestClient, media_root: Path, name: str, content_type: str) -> None:
    response = _upload(client, name, b"contenido", content_type)
    assert response.status_code == 415
    assert "Solo se pueden subir" in response.json()["detail"]
    assert list(media_root.iterdir()) == []


def test_rejects_files_over_the_limit(client: TestClient, media_root: Path) -> None:
    response = _upload(client, "grande.mp4", b"0" * (1024 * 1024 + 1), "video/mp4")
    assert response.status_code == 413
    assert response.json()["detail"] == "El archivo supera el máximo permitido de 1 MB."
    assert list(media_root.iterdir()) == []


def test_only_course_managers_upload(client: TestClient, media_root: Path) -> None:
    client.act_as(Role.ALUMNO, "cobrador1", "Ofertas")
    assert _upload(client, "v.mp4", VIDEO, "video/mp4").status_code == 403
    client.act_as(Role.SUPERVISOR, "sup")
    assert _upload(client, "v.mp4", VIDEO, "video/mp4").status_code == 403


def test_unknown_or_unsafe_names_are_not_served(client: TestClient, media_root: Path) -> None:
    (media_root / "secreto.txt").write_text("x")
    assert client.get("/media/secreto.txt").status_code == 404
    assert client.get("/media/" + "0" * 32 + ".mp4").status_code == 404


def test_download_needs_no_token_but_upload_does(real_auth_client: TestClient, tmp_path: Path) -> None:
    real_auth_client.app.dependency_overrides[get_settings] = lambda: Settings(media_root=str(tmp_path))
    name = "a" * 32 + ".mp4"
    (tmp_path / name).write_bytes(VIDEO)
    assert real_auth_client.get(f"/media/{name}").status_code == 200
    assert _upload(real_auth_client, "v.mp4", VIDEO, "video/mp4").status_code == 401


def test_uploaded_video_path_is_a_valid_lesson_video(client: TestClient, media_root: Path) -> None:
    url = _upload(client, "v.mp4", VIDEO, "video/mp4").json()["url"]
    payload = {
        "title": "Con video subido",
        "stores": ["Ofertas"],
        "lessons": [
            {
                "title": "L1",
                "summary": "s",
                "theory": "t",
                "sort_order": 1,
                "theory_videos": [{"url": url, "sort_order": 1}],
                "questions": [
                    {
                        "prompt": "¿Qué viste?",
                        "sort_order": 1,
                        "video_url": url,
                        "options": [
                            {"label": "Bien", "is_correct": True, "sort_order": 1},
                            {"label": "Mal", "sort_order": 2},
                        ],
                    }
                ],
            }
        ],
    }
    response = client.post("/courses", json=payload)
    assert response.status_code == 201, response.text
    lesson = response.json()["lessons"][0]
    assert lesson["questions"][0]["video_url"] == url
    assert lesson["theory_videos"][0]["url"] == url
    bad = {**payload}
    bad["lessons"] = [{**payload["lessons"][0], "theory_videos": [{"url": "/media/../../etc/passwd", "sort_order": 1}]}]
    assert client.post("/courses", json=bad).status_code == 422
