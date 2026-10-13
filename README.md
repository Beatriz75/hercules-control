# Hercules Control

Herramienta web interna para auditoria, supervision de personal y control operativo.

La primera etapa web queda limitada a ocho modulos aprobados. No incluye modulos financieros, integraciones bancarias ni validacion de comprobantes.

## Estado actual: v1.0.0

Primera versión desplegable: inicio de sesión, 5 roles (Administrador, Supervisor, Auditor, Consulta gerencial, Alumno/Cobrador), **Usuarios** y **Cursos**. Los demás módulos están en el código pero ocultos en la navegación hasta su versión.

- Despliegue: [docs/DEPLOY.md](docs/DEPLOY.md)
- Notas de versión: [docs/releases/](docs/releases/)
- Puertos: la app y la API se publican juntas en `WEB_PORT` (por defecto `8080`; la API en `/api`). Postgres y el backend no publican puertos. En desarrollo, `docker-compose.dev.yml` publica la API en `8000`.
- Ramas y versiones: ver la skill `.claude/skills/colaboracion-desarrollo-despliegue/SKILL.md`.

## Documentacion

- [Vision del proyecto](docs/project_overview.md)
- [Guia de ejecucion](docs/runbook.md)
- [Guia funcional](docs/user_guide.md)
- [Requisitos web](docs/requirements.md)
- [Arquitectura web](docs/mvp_architecture.md)
- [Modelo de datos web](docs/data_model.md)
- [Metrica manual de comprobantes diarios](docs/weekly_reports.md)
- [Roadmap web](docs/roadmap.md)
- [Propuesta local de issues web](docs/web_issues.md)

## Alcance aprobado de la primera etapa web

El sidebar web debe contener exclusivamente:

1. Dashboard
2. Empleados
3. Candidatos
4. Auditorias
5. Rendimiento
6. Reportes
7. Lineas WhatsApp
8. Configuracion

No deben existir modulos futuros ocultos, deshabilitados ni placeholders en la navegacion inicial.

## Fuera de alcance en esta etapa

Estos temas no forman parte del plan, arquitectura, backlog, milestones ni interfaces iniciales:

- Cobros
- Deudas
- Comprobantes como modulo independiente
- Cuentas autorizadas
- Pagos a empleados
- Usuarios CRM
- Integraciones bancarias
- Validacion SPEI
- Antifraude financiero

Regla critica: `Comprobantes diarios` queda unicamente como metrica manual dentro de Auditorias/Rendimiento. No es modulo financiero ni flujo de validacion de comprobantes.

## Stack web planificado

- Frontend: Flutter Web, Dart, layout desktop, sidebar izquierdo, navegacion estructurada y manejo de estado justificado.
- Backend: FastAPI, Python, API REST, Pydantic, servicios y repositorios.
- Base de datos: PostgreSQL con Alembic.
- Infraestructura: Docker, Docker Compose, variables de entorno, despliegue en servidor y HTTPS en produccion.

## MVP Flutter desktop reutilizable

El MVP actual de Flutter desktop puede aportar patrones y piezas reutilizables para la web:

- shell visual con sidebar izquierdo colapsable y modulo activo resaltado;
- componentes compartidos de UI como paneles, tarjetas metricas, badges y graficas simples;
- pantallas de Dashboard, Empleados, Reportes y Lineas como referencia funcional;
- criterios de auditoria/rendimiento derivados de evaluaciones diarias y estadisticas semanales;
- repositorios y entidades existentes como insumo conceptual para el modelo web.

La reutilizacion es de diseno y logica de negocio. La etapa web debe planificarse con backend FastAPI y PostgreSQL, no como extension directa de SQLite local.
