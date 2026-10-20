# Hércules Control

Herramienta web interna para capacitar y controlar al personal de las tiendas (Ofertas y Mexi).

## Estado actual: v1.1.0

La app se adapta a celular y tablet, y las prácticas explican los errores y muestran notas e intentos al personal (ver [notas de la v1.1.0](docs/releases/v1.1.0.md)). Incluye:

- **Inicio de sesión y 5 roles**: Administrador, Supervisor, Consulta gerencial, Auditor y Alumno/Cobrador. Los permisos se revisan en el servidor en cada acción.
- **Usuarios** (Administrador): altas, rol, tienda, activar/desactivar y restablecer contraseña.
- **Cursos**: catálogo y editor por tienda, teoría con imágenes y videos (por enlace o **subidos a Hércules**), prácticas calificadas en el servidor con preguntas al azar, desbloqueo de lecciones en orden y **Avance de alumnos**.
- **Banco de preguntas**: todas las preguntas de todos los cursos con filtros, buscador por texto o código (P1, P2…) y aviso de preguntas parecidas.

El menú muestra solo **Cursos**, **Banco de preguntas** y **Usuarios** (según el rol). Los demás módulos (Dashboard, Empleados, Candidatos, Auditorías, Rendimiento, Reportes, Líneas WhatsApp, Configuración) siguen en el código pero ocultos a propósito hasta su versión.

## Desplegar

Requisitos: un servidor con Docker y Docker Compose, y un dominio con HTTPS delante. Guía completa: [docs/DEPLOY.md](docs/DEPLOY.md).

```bash
git clone https://github.com/Beatriz75/hercules-control.git && cd hercules-control
git checkout v1.1.0
cp .env.example .env      # completar POSTGRES_PASSWORD, AUTH_SECRET_KEY e INITIAL_ADMIN_PASSWORD
docker compose up -d --build
docker compose ps         # db, backend y web en "running"; backend y web en "healthy"
```

- **Servicios**: `db` (PostgreSQL 16), `backend` (FastAPI) y `web` (Flutter web servido con nginx, que reenvía `/api` al backend).
- **Puertos**: la app y la API se publican juntas en `WEB_PORT` (por defecto `8080`; la API en `/api`). Postgres y el backend no publican puertos. En desarrollo, `docker-compose.dev.yml` publica la API en `8000`.
- **Datos que no se pueden perder**: los volúmenes `postgres_data` (base de datos) y `media_data` (videos e imágenes subidos). **Respaldar los dos** (ver DEPLOY.md).
- **Migraciones**: Alembic; se aplican solas al arrancar el backend.
- **Notas de cada versión** (qué cambió, variables nuevas, pasos manuales, cómo revertir): [docs/releases/](docs/releases/).

## Manuales de usuario

- [Manual del Administrador](docs/Manual_del_Administrador_Hercules_Control_v1.1.0.docx): alta de cobradores, usuarios, publicar y editar cursos, banco de preguntas, explicaciones, avance, intentos y preguntas más falladas.
- [Manual del Cobrador](docs/Manual_del_Cobrador_Hercules_Control_v1.1.0.docx): primer día, teoría, práctica (con respuesta correcta y porqué al fallar), uso en el celular y qué hacer si algo falla.
- [Manual general (todos los roles)](docs/Manual_de_usuario_Hercules_Control_v1.1.0.docx).

## Cómo colaboramos

- Ramas: `main` (solo producción, entra por pull request), `develop` (integración), `feature/…`, `fix/…`, `hotfix/…`.
- Versiones `vMAYOR.MENOR.PARCHE`: cada despliegue es una etiqueta de Git, una Release en GitHub y la misma etiqueta en las imágenes Docker (`APP_VERSION`).
- Ninguna clave va en el repositorio: todo se configura en `.env` (plantilla en [.env.example](.env.example)).
- Reglas completas: [.claude/skills/colaboracion-desarrollo-despliegue/SKILL.md](.claude/skills/colaboracion-desarrollo-despliegue/SKILL.md).

## Stack

- **Frontend**: Flutter web (Dart).
- **Backend**: FastAPI (Python), Pydantic, SQLAlchemy y sesiones con JWT.
- **Base de datos**: PostgreSQL con migraciones Alembic.
- **Infraestructura**: Docker y Docker Compose, nginx, variables de entorno, HTTPS en producción.

## Siguientes versiones

- **Examen de simulación** al terminar el curso: un día de trabajo reducido con 5 a 10 pedidos ficticios. Ver [docs/diseno_examen_simulacion.md](docs/diseno_examen_simulacion.md) (diseño de interfaces pendiente).
- Habilitar uno por uno los módulos ocultos, pasando sus datos al backend (hoy Empleados, Líneas y Reportes guardan sus datos solo en el navegador).

Fuera de alcance de la etapa web: cobros, deudas, comprobantes como módulo propio, cuentas autorizadas, pagos a empleados, integraciones bancarias, validación SPEI y antifraude financiero. `Comprobantes diarios` queda solo como métrica manual dentro de Auditorías/Rendimiento.

## Documentación de diseño

- [Visión del proyecto](docs/project_overview.md)
- [Requisitos web](docs/requirements.md)
- [Arquitectura web](docs/mvp_architecture.md)
- [Modelo de datos web](docs/data_model.md)
- [Identidad visual](docs/identidad_visual.md)
- [Guía de ejecución](docs/runbook.md)
- [Guía funcional](docs/user_guide.md)
- [Métrica manual de comprobantes diarios](docs/weekly_reports.md)
- [Roadmap web](docs/roadmap.md)
- [Propuesta local de issues web](docs/web_issues.md)
