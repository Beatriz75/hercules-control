# Guía de ejecución

El despliegue, la ejecución local, las variables de entorno y las copias de seguridad están en [DEPLOY.md](DEPLOY.md).

Resumen:

```bash
cp .env.example .env          # completar POSTGRES_PASSWORD, AUTH_SECRET_KEY e INITIAL_ADMIN_PASSWORD
docker compose up -d --build  # app en http://localhost:8080, API en /api
```

Validación:

```bash
flutter analyze && flutter test
cd backend && python -m pytest
docker compose config
```

## Restricción de alcance

La configuración local y de despliegue no debe crear servicios ni variables para integraciones bancarias, validación SPEI, antifraude financiero o módulos financieros excluidos.
