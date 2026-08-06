# Roadmap web

## Estado actual

Existe un MVP Flutter desktop con SQLite local. Sirve como referencia visual y funcional, pero la nueva etapa aprobada es web y queda acotada a auditoria, supervision de personal y control operativo.

## Alcance cerrado para la primera etapa

Modulos exclusivos:

1. Dashboard
2. Empleados
3. Candidatos
4. Auditorias
5. Rendimiento
6. Reportes
7. Lineas WhatsApp
8. Configuracion

## Fuera de alcance

No se planifican milestones, backlog ni interfaces para:

- Cobros
- Deudas
- Comprobantes como modulo independiente
- Cuentas autorizadas
- Pagos a empleados
- Usuarios CRM
- Integraciones bancarias
- Validacion SPEI
- Antifraude financiero

## Milestones

### M0 - Analisis y arquitectura

- confirmar alcance funcional;
- definir arquitectura Flutter Web + FastAPI + PostgreSQL;
- elegir manejo de estado del frontend con justificacion;
- definir modelo de dominio inicial;
- confirmar permisos iniciales.

### M1 - Infraestructura web

- crear estructura frontend web;
- crear estructura backend FastAPI;
- configurar PostgreSQL y Alembic;
- preparar Docker Compose;
- definir variables de entorno.

### M2 - Autenticacion y permisos

- login inicial;
- roles: administrador, supervisor, auditor y consulta gerencial;
- permisos por modulo y accion;
- proteccion de rutas y endpoints;
- bitacora base de acciones sensibles.

### M3 - Empleados y candidatos

- CRUD de empleados;
- historial de estado;
- CRUD de candidatos;
- etapas de seleccion;
- conversion de candidato aprobado a empleado.

### M4 - Auditorias configurables

- plantillas de auditoria;
- criterios configurables;
- creacion de auditorias;
- captura de hallazgos e irregularidades;
- metrica manual `Comprobantes diarios` solo dentro de auditoria/rendimiento.

### M5 - Rendimiento e irregularidades

- calculo de score operativo;
- vistas por empleado, equipo, tienda y periodo;
- seguimiento de irregularidades;
- tendencias y alertas.

### M6 - Reportes

- reportes operativos por auditorias;
- reportes de rendimiento;
- reportes de empleados/candidatos;
- reportes de lineas WhatsApp;
- filtros por periodo, estado y responsable.

### M7 - Lineas WhatsApp

- registro de lineas;
- asignacion, retiro y reasignacion;
- historial por linea y empleado;
- alertas de lineas sin asignar y empleados sin linea.

### M8 - Dashboard

- indicadores agregados;
- tarjetas de estado;
- tendencias basicas;
- alertas operativas;
- vista solo lectura para consulta gerencial.

### M9 - Configuracion y auditoria del sistema

- administracion de roles y permisos;
- catalogos operativos;
- tipos de auditoria;
- criterios de rendimiento;
- revision de bitacora del sistema.

### M10 - Pruebas y despliegue

- pruebas frontend y backend;
- validacion de permisos;
- pruebas de migraciones;
- hardening de configuracion;
- despliegue con HTTPS en servidor.

## Dependencias principales

- Configuracion y permisos desbloquean el resto de modulos.
- Empleados desbloquea Auditorias, Rendimiento y Lineas WhatsApp.
- Candidatos depende de Configuracion y se conecta con Empleados.
- Auditorias alimenta Rendimiento y Reportes.
- Rendimiento alimenta Dashboard y Reportes.
- Lineas WhatsApp alimenta Dashboard y Reportes.
- Dashboard debe implementarse despues de contar con datos base o mocks contractuales.

## Reutilizacion del MVP desktop

Partes reutilizables como referencia:

- layout de sidebar izquierdo;
- componentes visuales de `core/widgets`;
- patrones de dashboard con metric cards y graficas;
- pantallas de Empleados, Reportes y Lineas como insumo UX;
- logica operativa de evaluaciones/estadisticas para nutrir Auditorias y Rendimiento.

Partes no reutilizables en la planificacion web:

- SQLite como persistencia final;
- modulos financieros excluidos;
- navegacion actual con secciones fuera de alcance;
- cierre semanal como modulo independiente.

## Proxima aprobacion requerida

Revisar `docs/web_issues.md` y aprobar las primeras 15 issues pequenas antes de iniciar implementacion.
