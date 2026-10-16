"""Video links accepted in lessons and questions (embedded by the app, not stored on the server)."""

import re
from urllib.parse import urlparse

ALLOWED_VIDEO_HOSTS = (
    "youtube.com",
    "www.youtube.com",
    "m.youtube.com",
    "youtu.be",
    "drive.google.com",
    "vimeo.com",
    "player.vimeo.com",
)

# Videos uploaded to Hércules (POST /media) are stored as a relative path.
UPLOADED_VIDEO = re.compile(r"^/media/[0-9a-f]{32}\.(mp4|webm)$")


def validate_video_url(url: str | None) -> str | None:
    if url is None:
        return None
    url = url.strip()
    if not url:
        return None
    if UPLOADED_VIDEO.match(url):
        return url
    parsed = urlparse(url)
    if parsed.scheme not in ("http", "https") or not parsed.netloc:
        raise ValueError("El enlace del video debe empezar con http:// o https://.")
    host = parsed.netloc.lower().split(":")[0]
    if host in ALLOWED_VIDEO_HOSTS or parsed.path.lower().endswith((".mp4", ".webm")):
        return url
    raise ValueError("El video debe ser un enlace de YouTube, Google Drive, Vimeo, un archivo .mp4 / .webm o un video subido a Hércules.")
