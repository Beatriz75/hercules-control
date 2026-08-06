# Metrica manual de comprobantes diarios

## Decision

`Comprobantes diarios` no es un modulo independiente en la primera etapa web.

Solo se conserva como metrica manual dentro de Auditorias/Rendimiento cuando ayude a supervisar la operacion.

## Uso permitido

Puede registrarse como:

- campo manual en una auditoria;
- metrica operativa asociada a un empleado, equipo, tienda o periodo;
- dato visible en Rendimiento;
- dato agregado en Dashboard o Reportes si respeta permisos.

## Uso prohibido en esta etapa

No debe convertirse en:

- modulo financiero;
- validacion de comprobantes;
- flujo de conciliacion;
- integracion bancaria;
- validacion SPEI;
- antifraude financiero;
- reemplazo de Cobros o Deudas.

## Modelo sugerido

En base de datos debe vivir como metrica:

```text
performance_metrics.metric_code = daily_receipts
performance_metrics.metric_label = Comprobantes diarios
performance_metrics.metric_value = valor capturado manualmente
```

Debe tener referencia de periodo y empleado/equipo cuando corresponda.

## Validacion funcional

- Se puede capturar manualmente desde Auditorias si el tipo de auditoria lo habilita.
- Se puede consultar desde Rendimiento como indicador operativo.
- No aparece en el sidebar.
- No tiene rutas, permisos ni tablas propias como modulo independiente.
