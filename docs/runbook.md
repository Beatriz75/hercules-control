# Guia de ejecucion web planificada

## Estado

Este documento describe la ejecucion esperada para la etapa web planificada. La implementacion actual sigue siendo un MVP Flutter desktop local.

## Stack objetivo

- Frontend: Flutter Web y Dart.
- Backend: FastAPI y Python.
- Base de datos: PostgreSQL.
- Migraciones: Alembic.
- Infraestructura: Docker y Docker Compose.
- Produccion: servidor con HTTPS.

## Desarrollo local esperado

Comando objetivo pendiente de implementacion:

```powershell
docker compose up --build
```

Servicios esperados:

- frontend web;
- backend API;
- PostgreSQL;
- migraciones Alembic.

## Variables de entorno esperadas

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
pytest
alembic upgrade head
```

Infraestructura:

```powershell
docker compose config
docker compose up --build
```

## Restriccion de alcance

La configuracion local y de despliegue no debe crear servicios ni variables para integraciones bancarias, validacion SPEI, antifraude financiero o modulos financieros excluidos.
