"""Spanish messages for request validation errors (FastAPI/Pydantic 422 responses)."""

from fastapi import FastAPI, Request, status
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

FIELD_NAMES = {
    "username": "usuario",
    "password": "contraseña",
    "new_password": "contraseña nueva",
    "current_password": "contraseña actual",
    "full_name": "nombre",
    "role": "rol",
    "store_code": "tienda",
    "stores": "tiendas",
    "title": "título",
    "summary": "resumen",
    "theory": "teoría",
    "description": "descripción",
    "lessons": "lecciones",
    "questions": "preguntas",
    "options": "opciones",
    "prompt": "enunciado",
    "label": "texto de la opción",
    "required_approval_percent": "porcentaje de aprobación",
    "questions_per_attempt": "preguntas por práctica",
    "sort_order": "orden",
    "answers": "respuestas",
    "selected_option_ids": "opciones elegidas",
    "url": "imagen",
}


def _field(loc: tuple) -> str:
    names = [str(part) for part in loc if part not in ("body", "query", "path")]
    for part in reversed(names):
        if not part.isdigit():
            return FIELD_NAMES.get(part, part)
    return "dato"


def translate_error(error: dict) -> str:
    field = _field(tuple(error.get("loc", ())))
    kind = error.get("type", "")
    ctx = error.get("ctx") or {}
    if kind == "missing":
        return f"Falta el campo {field}."
    if kind == "string_too_short":
        minimum = ctx.get("min_length", 1)
        return f"El campo {field} no puede estar vacío." if minimum == 1 else f"El campo {field} debe tener al menos {minimum} caracteres."
    if kind == "string_too_long":
        return f"El campo {field} admite como máximo {ctx.get('max_length')} caracteres."
    if kind == "too_short":
        return f"Debe haber al menos {ctx.get('min_length', 1)} en {field}."
    if kind == "string_pattern_mismatch":
        if field == "usuario":
            return "El usuario solo puede tener letras, números, punto, guion y guion bajo (sin espacios ni acentos)."
        return f"El campo {field} tiene un formato no válido."
    if kind in ("greater_than_equal", "greater_than"):
        return f"El campo {field} debe ser mayor o igual a {ctx.get('ge', ctx.get('gt'))}."
    if kind in ("less_than_equal", "less_than"):
        return f"El campo {field} debe ser menor o igual a {ctx.get('le', ctx.get('lt'))}."
    if kind == "enum":
        return f"El valor de {field} no es válido."
    if kind in ("int_parsing", "int_type", "float_parsing"):
        return f"El campo {field} debe ser un número."
    if kind == "literal_error":
        return f"El valor de {field} no es válido."
    if kind == "value_error":
        message = str(error.get("msg", ""))
        return message.removeprefix("Value error, ")
    return f"El campo {field} no es válido."


def register_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(_: Request, exc: RequestValidationError) -> JSONResponse:
        detail = [
            {"loc": list(error.get("loc", ())), "msg": translate_error(error), "type": error.get("type")}
            for error in exc.errors()
        ]
        return JSONResponse(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, content=jsonable_encoder({"detail": detail}))
