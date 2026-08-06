# Vision del proyecto web

## Objetivo

Hercules Control Web sera una herramienta interna para auditoria, supervision de personal y control operativo.

La primera etapa no busca cubrir todo el negocio. Busca ordenar la operacion diaria con una base web multiusuario, permisos iniciales y datos centralizados.

## Alcance aprobado

Modulos exclusivos de la primera etapa:

1. Dashboard
2. Empleados
3. Candidatos
4. Auditorias
5. Rendimiento
6. Reportes
7. Lineas WhatsApp
8. Configuracion

El sidebar debe mostrar solo estos ocho modulos. No se planifican modulos futuros ocultos, deshabilitados ni accesos anticipados.

## Fuera de alcance

Quedan excluidos de plan, arquitectura, backlog, milestones e interfaces:

- Cobros
- Deudas
- Comprobantes como modulo independiente
- Cuentas autorizadas
- Pagos a empleados
- Usuarios CRM
- Integraciones bancarias
- Validacion SPEI
- Antifraude financiero

`Comprobantes diarios` se conserva solo como metrica manual dentro de Auditorias/Rendimiento. No valida pagos, no consulta bancos y no representa un modulo financiero.

## Problema a resolver

La operacion necesita control visible y consistente sobre:

- empleados activos, bajas y responsabilidades;
- candidatos y seguimiento de seleccion;
- auditorias operativas configurables;
- irregularidades y rendimiento por persona, tienda o periodo;
- reportes gerenciales y operativos;
- lineas WhatsApp asignadas a personal;
- configuracion basica de permisos, catalogos y parametros.

## Principios

- Web primero, con diseno de escritorio.
- Arquitectura clara entre frontend, API, dominio y persistencia.
- Permisos desde el inicio para evitar controles informales.
- Auditoria operativa, no financiera.
- Captura manual cuando el dato de origen necesite limpieza humana.

## Roles iniciales

| Rol | Acceso esperado |
| --- | --- |
| administrador | Configuracion y acceso completo. |
| supervisor | Empleados, candidatos, auditorias, rendimiento y reportes segun permisos. |
| auditor | Crear auditorias, registrar irregularidades, consultar rendimiento autorizado y crear reportes. |
| consulta gerencial | Dashboard, estadisticas y reportes solo lectura. |
