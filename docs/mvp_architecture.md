# Arquitectura web - Hercules Control

## Decision principal

La primera etapa web se planifica como una aplicacion Flutter Web con backend FastAPI y PostgreSQL. No es una simple publicacion del MVP desktop con SQLite.

## Modulos aprobados

El frontend debe exponer solo estos ocho modulos en el sidebar:

1. Dashboard
2. Empleados
3. Candidatos
4. Auditorias
5. Rendimiento
6. Reportes
7. Lineas WhatsApp
8. Configuracion

## Modulos excluidos

No se crean rutas, pantallas, entidades principales ni permisos para:

- Cobros
- Deudas
- Comprobantes como modulo independiente
- Cuentas autorizadas
- Pagos a empleados
- Usuarios CRM
- Integraciones bancarias
- Validacion SPEI
- Antifraude financiero

`Comprobantes diarios` solo puede modelarse como metrica manual asociada a Auditorias/Rendimiento.

## Frontend

Tecnologia:

- Flutter Web
- Dart

Estructura planificada:

- `app`: bootstrap, rutas, shell y providers globales.
- `features`: un paquete interno por modulo aprobado.
- `core`: tema, componentes compartidos, manejo de errores y cliente HTTP.
- `api`: DTOs y cliente REST tipado.

Navegacion:

- sidebar izquierdo desktop;
- rutas estructuradas por modulo;
- modulo activo resaltado;
- sin modulos ocultos o deshabilitados fuera del alcance.

Estado:

- definir manejo de estado en M0/M1 antes de implementarlo;
- justificarlo por formularios, filtros, sesion, permisos y cache de consultas;
- evitar estado global para datos estrictamente locales de una pantalla.

## Backend

Tecnologia:

- FastAPI
- Python
- Pydantic
- API REST

Capas:

- routers: endpoints por modulo;
- schemas: modelos Pydantic de request/response;
- services: reglas de negocio y permisos;
- repositories: acceso a PostgreSQL;
- models: modelos de persistencia;
- auth: autenticacion, sesion y permisos.

## Base de datos

Motor:

- PostgreSQL

Migraciones:

- Alembic

Principios:

- claves primarias UUID o identificadores consistentes;
- timestamps de creacion y actualizacion;
- soft delete o estados para entidades operativas con historial;
- bitacora de acciones sensibles;
- indices por fechas, estados y relaciones frecuentes.

## Modelo de dominio

Entidades principales:

- User: usuario interno de Hercules Control Web.
- Role: rol inicial del sistema.
- Permission: permiso por modulo y accion.
- Employee: empleado operativo.
- Candidate: candidato en proceso de seleccion.
- AuditTemplate: configuracion de checklist o criterio auditable.
- Audit: auditoria realizada.
- AuditFinding: hallazgo o irregularidad detectada.
- PerformanceMetric: metrica operativa calculada o capturada manualmente.
- Report: reporte operativo generado desde datos autorizados.
- WhatsAppLine: linea controlada manualmente.
- LineAssignment: historial de asignacion de linea a empleado.
- SystemAuditLog: bitacora de cambios del sistema.

Relaciones principales:

- `User n --- n Role`
- `Role n --- n Permission`
- `Employee 1 --- n Candidate` cuando un candidato se convierte en empleado mediante referencia opcional.
- `Employee 1 --- n Audit`
- `User 1 --- n Audit` como auditor responsable.
- `AuditTemplate 1 --- n Audit`
- `Audit 1 --- n AuditFinding`
- `Employee 1 --- n PerformanceMetric`
- `AuditFinding 1 --- n PerformanceMetric` cuando una metrica nace de una irregularidad.
- `WhatsAppLine 1 --- n LineAssignment`
- `Employee 1 --- n LineAssignment`
- `User 1 --- n SystemAuditLog`

## Dependencias entre modulos

| Modulo | Depende de | Motivo |
| --- | --- | --- |
| Dashboard | Empleados, Candidatos, Auditorias, Rendimiento, Reportes, Lineas WhatsApp | Resume datos operativos ya existentes. |
| Empleados | Configuracion | Usa roles operativos, tiendas/equipos y permisos. |
| Candidatos | Configuracion, Empleados | Usa etapas configurables y puede convertirse en empleado. |
| Auditorias | Empleados, Configuracion | Audita personas/areas y usa plantillas configurables. |
| Rendimiento | Empleados, Auditorias | Calcula metricas desde auditorias, hallazgos y capturas manuales. |
| Reportes | Empleados, Candidatos, Auditorias, Rendimiento, Lineas WhatsApp | Consolida informacion autorizada. |
| Lineas WhatsApp | Empleados, Configuracion | Asigna lineas a empleados y usa estados/catalogos. |
| Configuracion | Autenticacion y permisos | Es base transversal del sistema. |

## Infraestructura

- Dockerfile para frontend y backend.
- Docker Compose para desarrollo y despliegue inicial.
- Variables de entorno para secretos, base de datos, origenes permitidos y configuracion HTTPS.
- PostgreSQL como servicio persistente.
- HTTPS obligatorio en produccion.

## Reutilizacion del MVP Flutter desktop

Se puede reutilizar como referencia:

- shell con sidebar izquierdo y contenido dinamico;
- `core/widgets` para tarjetas metricas, paneles, badges y graficas;
- Dashboard, Empleados, Reportes y Lineas como base conceptual de pantallas;
- evaluaciones diarias y estadisticas semanales como insumo para Auditorias/Rendimiento;
- patrones de repositorio actuales como antecedente, no como persistencia final.

No se reutiliza como arquitectura final:

- SQLite local;
- modulos financieros excluidos;
- navegacion desktop con modulos no aprobados;
- repositorios locales como unica fuente de datos.
