# Requisitos web - Hercules Control

## Objetivo

Construir una herramienta web para auditoria, supervision de personal y control operativo.

## Alcance funcional aprobado

La primera etapa incluye exclusivamente estos modulos:

1. Dashboard
2. Empleados
3. Candidatos
4. Auditorias
5. Rendimiento
6. Reportes
7. Lineas WhatsApp
8. Configuracion

## Fuera de alcance obligatorio

No se deben planificar interfaces, entidades principales, milestones ni issues para:

- Cobros
- Deudas
- Comprobantes como modulo independiente
- Cuentas autorizadas
- Pagos a empleados
- Usuarios CRM
- Integraciones bancarias
- Validacion SPEI
- Antifraude financiero

Regla critica: `Comprobantes diarios` solo puede aparecer como metrica manual de Auditorias/Rendimiento.

## RF-01 Dashboard

Debe mostrar indicadores de control operativo:

- empleados activos, altas y bajas;
- candidatos por etapa;
- auditorias abiertas, cerradas y vencidas;
- irregularidades por severidad;
- rendimiento por empleado, equipo, tienda o periodo;
- lineas WhatsApp activas, asignadas y sin asignar;
- reportes recientes y alertas operativas.

El rol `consulta gerencial` accede en modo solo lectura.

## RF-02 Empleados

Debe permitir gestionar empleados con:

- datos personales y contacto;
- rol operativo interno;
- tienda, equipo o area;
- fecha de ingreso y baja;
- estado;
- observaciones;
- historial de cambios relevantes.

Regla: no se elimina historial operativo de empleados.

## RF-03 Candidatos

Debe permitir registrar candidatos con:

- datos de contacto;
- puesto o area de interes;
- etapa del proceso;
- responsable;
- fecha de alta;
- notas;
- resultado final.

Debe permitir convertir un candidato aprobado en empleado sin perder trazabilidad.

## RF-04 Auditorias

Debe permitir crear auditorias configurables con:

- tipo de auditoria;
- empleado auditado o area;
- auditor responsable;
- fecha;
- checklist configurable;
- hallazgos;
- irregularidades;
- evidencia textual o referencias internas;
- estado.

Debe permitir capturar `Comprobantes diarios` como metrica manual cuando aplique al control operativo. Esa metrica no valida comprobantes ni genera un modulo financiero.

## RF-05 Rendimiento

Debe consolidar metricas operativas desde auditorias, irregularidades y capturas manuales autorizadas:

- score por empleado;
- tendencia por periodo;
- faltas o irregularidades;
- comparacion por tienda, equipo o rol;
- metricas manuales como `Comprobantes diarios` cuando correspondan.

Debe respetar permisos por rol y alcance de consulta.

## RF-06 Reportes

Debe permitir crear y consultar reportes operativos:

- reporte de auditorias;
- reporte de rendimiento;
- reporte de irregularidades;
- reporte de empleados y candidatos;
- reporte de lineas WhatsApp.

La exportacion puede planificarse dentro del modulo Reportes si no introduce modulos excluidos.

## RF-07 Lineas WhatsApp

Debe permitir:

- registrar lineas WhatsApp;
- asignar lineas a empleados;
- retirar y reasignar lineas;
- consultar historial de asignaciones;
- detectar lineas sin asignar;
- detectar empleados activos sin linea asignada.

No debe integrarse con WhatsApp Business en esta etapa. Es control operativo manual.

## RF-08 Configuracion

Debe permitir administrar:

- usuarios internos de la herramienta web;
- roles y permisos iniciales;
- catalogos operativos;
- tipos de auditoria;
- criterios de rendimiento;
- parametros visibles del dashboard;
- bitacora de auditoria del sistema.

Nota: `usuarios internos de la herramienta web` no equivale a `Usuarios CRM`, que queda fuera de alcance.

## Roles y permisos

| Rol | Permisos base |
| --- | --- |
| administrador | Configuracion y acceso completo. |
| supervisor | Empleados, candidatos, auditorias, rendimiento y reportes segun permisos. |
| auditor | Crear auditorias, registrar irregularidades, consultar rendimiento autorizado y crear reportes. |
| consulta gerencial | Dashboard, estadisticas y reportes solo lectura. |

## Requisitos de interfaz

- Flutter Web con diseno desktop.
- Sidebar izquierdo fijo o colapsable.
- Sidebar limitado a los ocho modulos aprobados.
- Navegacion estructurada sin modulos futuros ocultos.
- Tablas legibles, filtros visibles y estados claros.
- Dashboard orientado a supervision, no a finanzas.

## Requisitos no funcionales

### Frontend

- Flutter Web y Dart.
- Manejo de estado justificado antes de implementarlo.
- Separacion entre UI, estado y acceso a API.

### Backend

- FastAPI y Python.
- API REST.
- Esquemas Pydantic para entrada y salida.
- Servicios para reglas de negocio.
- Repositorios para acceso a datos.

### Base de datos

- PostgreSQL.
- Alembic para migraciones.
- Indices para busqueda por fechas, empleados, auditorias y estados.

### Infraestructura

- Docker.
- Docker Compose.
- Variables de entorno.
- Despliegue en servidor.
- HTTPS en produccion.

## Criterios de aceptacion de plan

- El plan contiene solo los ocho modulos aprobados.
- El sidebar no incluye placeholders de modulos excluidos.
- Las dependencias entre modulos estan documentadas.
- Las primeras issues son pequenas y verificables.
- El modelo de datos no contiene tablas principales para temas financieros excluidos.
- `Comprobantes diarios` aparece solo como metrica manual dentro de Auditorias/Rendimiento.
