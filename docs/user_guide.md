# Guia funcional web

## Navegacion

La aplicacion web debe usar un layout desktop con sidebar izquierdo.

El sidebar debe contener exclusivamente:

1. Dashboard
2. Empleados
3. Candidatos
4. Auditorias
5. Rendimiento
6. Reportes
7. Lineas WhatsApp
8. Configuracion

No debe mostrar modulos futuros ocultos, deshabilitados ni placeholders.

## Dashboard

Vista de supervision con indicadores operativos:

- empleados activos;
- candidatos por etapa;
- auditorias abiertas y cerradas;
- irregularidades por severidad;
- rendimiento por periodo;
- lineas WhatsApp asignadas y sin asignar;
- reportes recientes.

## Empleados

Permite administrar empleados y conservar historial operativo.

Funciones esperadas:

- alta y edicion de empleados;
- estado activo/inactivo;
- tienda, equipo o area;
- rol operativo;
- historial relevante;
- consulta segun permisos.

## Candidatos

Permite dar seguimiento a personas en proceso de seleccion.

Funciones esperadas:

- registrar candidato;
- asignar responsable;
- mover entre etapas;
- registrar resultado;
- convertir aprobado en empleado.

## Auditorias

Permite ejecutar auditorias operativas configurables.

Funciones esperadas:

- seleccionar plantilla;
- auditar empleado o area;
- capturar checklist;
- registrar hallazgos;
- registrar irregularidades;
- capturar metricas manuales autorizadas.

`Comprobantes diarios` solo puede capturarse como metrica manual de control operativo. No valida comprobantes ni abre flujo financiero.

## Rendimiento

Permite consultar desempeno operativo.

Funciones esperadas:

- score por empleado;
- tendencias por periodo;
- irregularidades abiertas y resueltas;
- comparacion por tienda, equipo o rol;
- metricas manuales provenientes de auditorias.

## Reportes

Permite consultar y generar reportes operativos.

Tipos iniciales:

- auditorias;
- rendimiento;
- irregularidades;
- empleados y candidatos;
- lineas WhatsApp.

Los reportes no deben incluir modulos financieros excluidos.

## Lineas WhatsApp

Control operativo manual de lineas WhatsApp.

Funciones esperadas:

- registrar linea;
- asignar a empleado;
- retirar asignacion;
- reasignar;
- consultar historial;
- detectar empleados activos sin linea;
- detectar lineas sin asignar.

## Configuracion

Permite administrar parametros del sistema.

Funciones esperadas:

- usuarios internos de Hercules Control Web;
- roles y permisos;
- catalogos operativos;
- tipos de auditoria;
- criterios de rendimiento;
- parametros del dashboard;
- bitacora del sistema.

`Usuarios CRM` queda fuera de alcance. La configuracion solo cubre usuarios de la herramienta web.
