# Propuesta local de issues web

Este documento es un backlog local para aprobacion. No representa issues publicados en GitHub.

## Alcance de las issues

Las issues cubren solo la primera etapa web:

1. Dashboard
2. Empleados
3. Candidatos
4. Auditorias
5. Rendimiento
6. Reportes
7. Lineas WhatsApp
8. Configuracion

Quedan fuera: Cobros, Deudas, Comprobantes como modulo independiente, Cuentas autorizadas, Pagos a empleados, Usuarios CRM, Integraciones bancarias, Validacion SPEI y Antifraude financiero.

## Primeras 15 issues propuestas

### WEB-001 - Definir shell web con sidebar de 8 modulos

Objetivo: crear la estructura de navegacion Flutter Web con sidebar izquierdo.

Aceptacion:

- el sidebar lista solo los ocho modulos aprobados;
- no existen entradas ocultas, deshabilitadas ni placeholders para modulos excluidos;
- el modulo activo queda resaltado.

Milestone: M1

### WEB-002 - Crear contrato inicial de rutas frontend

Objetivo: definir rutas por modulo aprobado.

Aceptacion:

- cada modulo aprobado tiene ruta base;
- las rutas requieren permisos;
- no hay rutas para temas excluidos.

Milestone: M1

### WEB-003 - Levantar backend FastAPI base

Objetivo: crear API base con healthcheck y estructura por capas.

Aceptacion:

- existe endpoint de healthcheck;
- hay estructura para routers, schemas, services y repositories;
- la API corre en Docker Compose.

Milestone: M1

### WEB-004 - Configurar PostgreSQL y Alembic

Objetivo: preparar persistencia web.

Aceptacion:

- Docker Compose levanta PostgreSQL;
- Alembic ejecuta migracion inicial;
- no se crean tablas financieras excluidas.

Milestone: M1

### WEB-005 - Implementar autenticacion inicial

Objetivo: permitir login seguro para usuarios internos de la herramienta web.

Aceptacion:

- usuario puede iniciar sesion;
- endpoints protegidos rechazan acceso anonimo;
- no se modelan Usuarios CRM.

Milestone: M2

### WEB-006 - Implementar roles y permisos base

Objetivo: crear administrador, supervisor, auditor y consulta gerencial.

Aceptacion:

- cada rol tiene permisos iniciales documentados;
- frontend oculta acciones no permitidas;
- backend valida permisos por endpoint.

Milestone: M2

### WEB-007 - Crear CRUD de empleados

Objetivo: administrar empleados operativos.

Aceptacion:

- se puede crear, editar y consultar empleado;
- se conserva estado/historial basico;
- supervisor accede segun permisos.

Milestone: M3

### WEB-008 - Crear CRUD de candidatos

Objetivo: administrar candidatos y etapas.

Aceptacion:

- se puede crear y editar candidato;
- se puede cambiar etapa;
- se puede marcar aprobado/rechazado.

Milestone: M3

### WEB-009 - Convertir candidato aprobado en empleado

Objetivo: conectar Candidatos con Empleados.

Aceptacion:

- candidato aprobado puede generar empleado;
- queda referencia entre candidato y empleado;
- no se duplica empleado si ya fue convertido.

Milestone: M3

### WEB-010 - Crear plantillas de auditoria

Objetivo: configurar checklists auditables.

Aceptacion:

- administrador crea plantilla;
- plantilla contiene criterios ordenados;
- plantilla puede activarse/desactivarse.

Milestone: M4

### WEB-011 - Registrar auditoria operativa

Objetivo: ejecutar auditorias sobre empleados o areas.

Aceptacion:

- auditor crea auditoria desde plantilla;
- se guardan respuestas y score;
- se pueden registrar hallazgos.

Milestone: M4

### WEB-012 - Capturar irregularidades desde auditoria

Objetivo: registrar hallazgos accionables.

Aceptacion:

- irregularidad tiene severidad, categoria, descripcion y estado;
- queda asociada a auditoria y empleado cuando aplique;
- aparece como fuente para Rendimiento.

Milestone: M4

### WEB-013 - Registrar metrica manual de comprobantes diarios

Objetivo: permitir la metrica solo dentro de Auditorias/Rendimiento.

Aceptacion:

- se guarda como `performance_metrics.metric_code = daily_receipts`;
- no aparece como modulo del sidebar;
- no valida comprobantes, bancos ni SPEI.

Milestone: M4

### WEB-014 - Mostrar rendimiento por empleado y periodo

Objetivo: consultar scores e irregularidades.

Aceptacion:

- se filtra por empleado y periodo;
- se ven auditorias, irregularidades y metricas autorizadas;
- auditor solo ve rendimiento autorizado.

Milestone: M5

### WEB-015 - Gestionar lineas WhatsApp y asignaciones

Objetivo: controlar lineas y su historial.

Aceptacion:

- se registra linea;
- se asigna, retira y reasigna a empleados;
- se consulta historial de asignaciones.

Milestone: M7

## Dependencias de las primeras issues

| Issue | Depende de |
| --- | --- |
| WEB-001 | M0 aprobado |
| WEB-002 | WEB-001 |
| WEB-003 | M0 aprobado |
| WEB-004 | WEB-003 |
| WEB-005 | WEB-003, WEB-004 |
| WEB-006 | WEB-005 |
| WEB-007 | WEB-006 |
| WEB-008 | WEB-006 |
| WEB-009 | WEB-007, WEB-008 |
| WEB-010 | WEB-006 |
| WEB-011 | WEB-007, WEB-010 |
| WEB-012 | WEB-011 |
| WEB-013 | WEB-011 |
| WEB-014 | WEB-007, WEB-011, WEB-012, WEB-013 |
| WEB-015 | WEB-007, WEB-006 |
