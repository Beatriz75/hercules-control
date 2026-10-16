"""Files uploaded from the course editor (lesson/question videos and images).

POST /media stores the file under MEDIA_ROOT with a random, unguessable name.
GET /media/<file> serves it without a token (a <video>/<img> tag can't send
headers; the random name is the protection) and supports HTTP Range so the
player can seek.
"""

import os
import re
import uuid
from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, UploadFile, status
from fastapi.responses import FileResponse

from app.api.deps import require_permission
from app.core.config import Settings, get_settings
from app.core.permissions import Permission
from app.models.user import User

router = APIRouter(prefix="/media", tags=["media"])

CourseManager = Annotated[User, Depends(require_permission(Permission.COURSES_MANAGE))]

# Extension -> content type served, plus the content types accepted on upload.
ALLOWED_TYPES: dict[str, tuple[str, frozenset[str]]] = {
    ".mp4": ("video/mp4", frozenset({"video/mp4"})),
    ".webm": ("video/webm", frozenset({"video/webm"})),
    ".png": ("image/png", frozenset({"image/png"})),
    ".jpg": ("image/jpeg", frozenset({"image/jpeg", "image/jpg", "image/pjpeg"})),
    ".jpeg": ("image/jpeg", frozenset({"image/jpeg", "image/jpg", "image/pjpeg"})),
    ".webp": ("image/webp", frozenset({"image/webp"})),
    ".gif": ("image/gif", frozenset({"image/gif"})),
}
STORED_NAME = re.compile(r"^[0-9a-f]{32}\.(mp4|webm|png|jpg|jpeg|webp|gif)$")
CHUNK_SIZE = 1024 * 1024
UNSUPPORTED = "Solo se pueden subir videos .mp4 / .webm o imágenes .png, .jpg, .jpeg, .webp o .gif."


def _too_large(limit_mb: int) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
        detail=f"El archivo supera el máximo permitido de {limit_mb} MB.",
    )


@router.post("", status_code=status.HTTP_201_CREATED)
async def upload_media(
    request: Request,
    file: UploadFile,
    _: CourseManager,
    settings: Annotated[Settings, Depends(get_settings)],
) -> dict:
    limit = settings.max_upload_mb * 1024 * 1024
    declared = request.headers.get("content-length")
    if declared and declared.isdigit() and int(declared) > limit + CHUNK_SIZE:
        raise _too_large(settings.max_upload_mb)

    extension = Path(file.filename or "").suffix.lower()
    content_type = (file.content_type or "").split(";")[0].strip().lower()
    allowed = ALLOWED_TYPES.get(extension)
    if allowed is None or content_type not in allowed[1]:
        raise HTTPException(status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, detail=UNSUPPORTED)

    media_root = Path(settings.media_root)
    media_root.mkdir(parents=True, exist_ok=True)
    name = f"{uuid.uuid4().hex}{extension}"
    target = media_root / name
    partial = media_root / f".{name}.part"
    size = 0
    try:
        with partial.open("wb") as out:
            while chunk := await file.read(CHUNK_SIZE):
                size += len(chunk)
                if size > limit:
                    raise _too_large(settings.max_upload_mb)
                out.write(chunk)
        if size == 0:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="El archivo está vacío.")
        os.replace(partial, target)
    finally:
        partial.unlink(missing_ok=True)
        await file.close()
    return {"url": f"/media/{name}", "size": size, "content_type": allowed[0]}


@router.get("/{name}")
def get_media(name: str, settings: Annotated[Settings, Depends(get_settings)]) -> FileResponse:
    path = Path(settings.media_root) / name
    if not STORED_NAME.match(name) or not path.is_file():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="El archivo no existe.")
    return FileResponse(
        path,
        media_type=ALLOWED_TYPES[path.suffix.lower()][0],
        headers={"Cache-Control": "public, max-age=31536000, immutable"},
    )
