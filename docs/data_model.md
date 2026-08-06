# Modelo de datos web

## Persistencia

Motor:

- PostgreSQL

Migraciones:

- Alembic

Acceso:

- repositorios desde backend FastAPI;
- servicios para reglas de negocio;
- esquemas Pydantic para contratos REST.

## Tablas principales planificadas

### users

Usuarios internos de Hercules Control Web.

Campos principales:

- `id`
- `name`
- `email`
- `password_hash`
- `status`
- `created_at`
- `updated_at`

### roles

Roles iniciales: administrador, supervisor, auditor y consulta gerencial.

Campos principales:

- `id`
- `code`
- `name`
- `description`

### permissions

Permisos por modulo y accion.

Campos principales:

- `id`
- `module_code`
- `action_code`
- `description`

### user_roles

Relacion entre usuarios y roles.

Campos principales:

- `user_id`
- `role_id`

### role_permissions

Relacion entre roles y permisos.

Campos principales:

- `role_id`
- `permission_id`

### employees

Empleados operativos.

Campos principales:

- `id`
- `full_name`
- `phone`
- `email`
- `operational_role`
- `store_or_team`
- `hire_date`
- `termination_date`
- `status`
- `notes`
- `created_at`
- `updated_at`

### candidates

Candidatos en proceso de seleccion.

Campos principales:

- `id`
- `full_name`
- `phone`
- `email`
- `target_role`
- `stage`
- `owner_user_id`
- `result`
- `converted_employee_id`
- `notes`
- `created_at`
- `updated_at`

### audit_templates

Plantillas configurables para auditorias.

Campos principales:

- `id`
- `name`
- `description`
- `active`
- `created_at`
- `updated_at`

### audit_template_items

Criterios o preguntas de una plantilla.

Campos principales:

- `id`
- `template_id`
- `label`
- `input_type`
- `required`
- `weight`
- `sort_order`

### audits

Auditorias realizadas.

Campos principales:

- `id`
- `template_id`
- `employee_id`
- `auditor_user_id`
- `audit_date`
- `status`
- `score`
- `notes`
- `created_at`
- `updated_at`

### audit_answers

Respuestas capturadas por criterio.

Campos principales:

- `id`
- `audit_id`
- `template_item_id`
- `value`
- `notes`

### audit_findings

Hallazgos e irregularidades operativas.

Campos principales:

- `id`
- `audit_id`
- `employee_id`
- `severity`
- `category`
- `description`
- `status`
- `created_at`
- `resolved_at`

### performance_metrics

Metricas de rendimiento calculadas o capturadas manualmente.

Campos principales:

- `id`
- `employee_id`
- `source_type`
- `source_id`
- `metric_code`
- `metric_label`
- `metric_value`
- `period_start`
- `period_end`
- `created_at`

Regla: `daily_receipts` o `Comprobantes diarios` solo puede existir como `metric_code` manual dentro de Auditorias/Rendimiento. No habilita tabla, modulo ni validacion financiera de comprobantes.

### reports

Reportes operativos generados por usuarios autorizados.

Campos principales:

- `id`
- `type`
- `title`
- `filters_json`
- `created_by_user_id`
- `created_at`

### whatsapp_lines

Lineas WhatsApp controladas manualmente.

Campos principales:

- `id`
- `phone_number`
- `alias`
- `status`
- `provider`
- `notes`
- `created_at`
- `updated_at`

### line_assignments

Historial de asignaciones de lineas a empleados.

Campos principales:

- `id`
- `line_id`
- `employee_id`
- `assigned_at`
- `removed_at`
- `status`

### system_audit_logs

Bitacora de acciones sensibles del sistema.

Campos principales:

- `id`
- `user_id`
- `action`
- `entity_type`
- `entity_id`
- `metadata_json`
- `created_at`

## Tablas excluidas en esta etapa

No se planifican tablas principales para:

- cobros;
- deudas;
- comprobantes financieros;
- cuentas autorizadas;
- pagos a empleados;
- usuarios CRM;
- integraciones bancarias;
- validacion SPEI;
- antifraude financiero.

## Indices iniciales

- `employees(status)`
- `candidates(stage, result)`
- `audits(audit_date, status)`
- `audit_findings(severity, status)`
- `performance_metrics(employee_id, metric_code, period_start, period_end)`
- `whatsapp_lines(status)`
- `line_assignments(line_id, employee_id, status)`
- `system_audit_logs(user_id, created_at)`
