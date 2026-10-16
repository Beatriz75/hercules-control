# Despliegue de Hércules Control

Guía para el desarrollador que pone la aplicación en un servidor. Primera entrega: **inicio de sesión, roles y permisos, y el módulo Cursos**. El resto de módulos existe en el código pero está oculto.

## Qué se despliega

```
navegador ──HTTPS──► proxy con TLS (Caddy, Traefik, balanceador…) ──HTTP──► web:80 (nginx)
                                                                       │
                                                       /         → app Flutter web (archivos estáticos)
                                                       /api/...  → backend:8000 (FastAPI)  ──► db:5432 (PostgreSQL 16)
```

`docker-compose.yml` define tres servicios:

| Servicio  | Imagen / build              | Publicado            | Función |
|-----------|-----------------------------|----------------------|---------|
| `db`      | `postgres:16-alpine`        | no                   | Datos. Volumen `postgres_data`. |
| `backend` | `backend/Dockerfile`        | no (solo red interna) | API. Al arrancar aplica migraciones (`alembic upgrade head`) y crea el primer administrador si no hay usuarios. |
| `web`     | `Dockerfile.web`            | `${WEB_PORT:-8080}`  | Compila Flutter web y lo sirve con nginx; reenvía `/api/` al backend. |

La app y la API comparten dominio, así que no hace falta CORS en producción.

## Requisitos del servidor

- Linux con Docker Engine 24+ y el plugin Docker Compose v2.
- 2 vCPU y 2 GB de RAM como mínimo. La compilación de Flutter dentro de `Dockerfile.web` es lo que más memoria usa; si el servidor es chico, se puede construir la imagen en otra máquina y subirla a un registro.
- Un dominio apuntando al servidor y un proxy con HTTPS delante (ver más abajo).

## Primer despliegue

```bash
git clone <repo> hercules-control && cd hercules-control
git checkout <rama o tag a desplegar>

cp .env.example .env
# Editar .env:
#   APP_VERSION             la misma etiqueta de Git que se despliega (p. ej. v1.0.0)
#   POSTGRES_PASSWORD       clave larga
#   AUTH_SECRET_KEY         python3 -c "import secrets; print(secrets.token_urlsafe(48))"
#   INITIAL_ADMIN_PASSWORD  clave del primer administrador (8+ caracteres)

docker compose up -d --build
docker compose ps            # los tres servicios en "running"; backend en "healthy"
curl http://localhost:8080/api/health
```

Después entrar en `https://<dominio>` con `INITIAL_ADMIN_USERNAME` / `INITIAL_ADMIN_PASSWORD`, cambiar la contraseña desde el menú del usuario y crear el resto de usuarios en **Usuarios**. Luego se puede borrar `INITIAL_ADMIN_PASSWORD` del `.env`: el administrador inicial solo se crea cuando la tabla de usuarios está vacía.

Con `ENVIRONMENT=production` el backend **no arranca** si `AUTH_SECRET_KEY` está vacía, tiene el valor de ejemplo o mide menos de 32 caracteres.

## HTTPS

El contenedor `web` escucha HTTP en `WEB_PORT`. El TLS se pone delante. Ejemplo con Caddy instalado en el host, que saca y renueva el certificado solo:

```
# /etc/caddy/Caddyfile
hercules.ejemplo.com {
    reverse_proxy 127.0.0.1:8080
}
```

En ese caso conviene publicar el puerto solo en local: `WEB_PORT=127.0.0.1:8080`.

## Variables de entorno (`.env`)

| Variable | Obligatoria | Por defecto | Uso |
|----------|-------------|-------------|-----|
| `APP_VERSION` | sí | — | Etiqueta de las imágenes Docker; igual a la etiqueta de Git desplegada. |
| `POSTGRES_PASSWORD` | sí | — | Clave de PostgreSQL. |
| `POSTGRES_DB`, `POSTGRES_USER` | no | `hercules_control`, `hercules` | |
| `AUTH_SECRET_KEY` | sí | — | Firma de los tokens de sesión (JWT HS256). Si se cambia, todos los usuarios tienen que volver a iniciar sesión. |
| `ENVIRONMENT` | no | `production` | `production` activa la validación de la clave. |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | no | `480` | Duración de la sesión. |
| `INITIAL_ADMIN_USERNAME` / `INITIAL_ADMIN_PASSWORD` / `INITIAL_ADMIN_FULL_NAME` | la clave solo en el primer arranque | `admin` / — / `Administrador` | Primer administrador. |
| `WEB_PORT` | no | `8080` | Puerto (o `ip:puerto`) donde se publica nginx. |
| `ALLOWED_ORIGINS` | no | vacío | Orígenes CORS separados por coma. Solo si la app web se sirve desde otro dominio. |

## Actualizar a una versión nueva

Cada versión trae sus notas en `docs/releases/vX.Y.Z.md`; leerlas antes (variables nuevas, migraciones, pasos manuales).

```bash
# 1. Respaldo de la base (ver "Copias de seguridad")
git fetch --tags && git checkout vX.Y.Z
# 2. Cambiar APP_VERSION=vX.Y.Z en .env y agregar las variables nuevas
docker compose up -d --build
docker compose ps && docker compose logs --tail=100 backend
```

Para revertir: `git checkout <versión anterior>`, volver `APP_VERSION` a esa etiqueta y `docker compose up -d`. Si la versión fallida aplicó una migración no reversible, restaurar el respaldo.

Las migraciones se aplican solas al arrancar el backend. nginx no guarda en caché `index.html` ni `flutter_bootstrap.js`, así que los navegadores toman la versión nueva al recargar.

## Copias de seguridad

La información está en dos lugares y hay que respaldar los dos:

- PostgreSQL: usuarios, cursos, preguntas y avance (incluidas las imágenes pegadas en las lecciones, guardadas como data URL dentro del curso).
- Volumen `media_data`: los videos e imágenes subidos desde el editor del curso.

```bash
# Respaldo (programarlo con cron, por ejemplo cada noche)
docker compose exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > respaldo_$(date +%F).dump

# Restaurar sobre una base vacía
docker compose exec -T db sh -c 'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists' < respaldo_AAAA-MM-DD.dump

# Respaldo de los archivos subidos
docker compose exec -T backend tar czf - -C /data/media . > media_$(date +%F).tar.gz

# Restaurar los archivos subidos
docker compose exec -T backend tar xzf - -C /data/media < media_AAAA-MM-DD.tar.gz
```

## Roles y permisos

Los roles son fijos y están en `backend/app/core/permissions.py`. El backend es quien decide: cada endpoint pide un permiso y la app solo oculta lo que el usuario no puede usar.

| Rol | Clave | En esta entrega puede |
|-----|-------|------------------------|
| Administrador | `administrador` | Todo: usuarios, crear y editar cursos, ver avance. |
| Supervisor | `supervisor` | Ver el catálogo de cursos y el avance de los alumnos. |
| Auditor | `auditor` | Auditorías (módulo oculto en esta entrega). |
| Consulta gerencial | `consulta_gerencial` | Ver cursos y avance, solo lectura. |
| Alumno / Cobrador | `alumno` | Solo los cursos de su tienda: leer la teoría y hacer la práctica. |

Detalles:

- El alumno tiene una tienda (`store_code`: `Ofertas` o `Mexi`). Solo ve los cursos activos y publicados asignados a esa tienda, y la API nunca le envía cuál es la respuesta correcta: la práctica se califica en el servidor.
- Un administrador no puede desactivarse ni quitarse el rol a sí mismo.
- Al editar un curso, las lecciones y preguntas que se quitan quedan ocultas, no se borran, para no perder el avance ni el historial de respuestas.

## API

- Documentación interactiva: `https://<dominio>/api/docs`.
- Inicio de sesión: `POST /api/auth/token` (formulario `username`, `password`) → `access_token`. Mandar `Authorization: Bearer <token>` en el resto de llamadas.
- `GET /api/health` no pide sesión.

## Desarrollo local

Backend (Python 3.12+):

```bash
cd backend
python -m venv .venv && .venv/bin/pip install -r requirements-dev.txt   # en Windows: .venv\Scripts\pip
.venv/bin/python -m pytest
```

API y base de datos en Docker con el puerto 8000 publicado, y Flutter apuntando a ella:

```bash
cp .env.example .env    # completar las claves
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d db backend
flutter run -d chrome --web-port 5000 --dart-define=API_BASE_URL=http://localhost:8000
```

Validación del frontend: `flutter analyze` y `flutter test`.

## Problemas frecuentes

- **`backend` se reinicia en bucle**: `docker compose logs backend`. Lo más común es `AUTH_SECRET_KEY` faltante o corta, o que `POSTGRES_PASSWORD` cambió después de crear el volumen (la clave de Postgres solo se aplica la primera vez; para cambiarla hay que usar `ALTER USER` dentro de la base).
- **`bootstrap_admin: set INITIAL_ADMIN_USERNAME and INITIAL_ADMIN_PASSWORD`**: no hay usuarios y falta la clave del primer administrador en `.env`.
- **La app muestra "Usuario o contraseña incorrectos" con la clave correcta**: el usuario está desactivado; otro administrador puede reactivarlo.
- **Error 413 al guardar un curso**: las imágenes pegadas pesan más de lo permitido; subir `client_max_body_size` en `deploy/nginx.conf`.
