# Guia de ejecucion web

## Estado

Este documento describe la ejecucion local de la etapa web. La API base FastAPI ya puede levantarse con Docker Compose; la persistencia sigue planificada para una issue posterior.

## Stack objetivo

- Frontend: Flutter Web y Dart.
- Backend: FastAPI y Python.
- Base de datos: PostgreSQL pendiente.
- Migraciones: Alembic pendiente.
- Infraestructura: Docker y Docker Compose.
- Produccion: servidor con HTTPS.

## Desarrollo local

Levantar la API base:

```powershell
docker compose up --build
```

Servicios actuales:

- backend API en `http://localhost:8000`.

Healthcheck:

```powershell
Invoke-RestMethod http://localhost:8000/health
```

## Variables de entorno planificadas

- `DATABASE_URL`
- `SECRET_KEY`
- `ALLOWED_ORIGINS`
- `ENVIRONMENT`
- `HTTPS_ENABLED`

## Validacion esperada

Frontend:

```powershell
flutter analyze
flutter test
```

Backend:

```powershell
cd backend
pip install -r requirements-dev.txt
pytest
```

Infraestructura:

```powershell
docker compose config
docker compose up --build
```

## Restriccion de alcance

La configuracion local y de despliegue no debe crear servicios ni variables para integraciones bancarias, validacion SPEI, antifraude financiero o modulos financieros excluidos.
