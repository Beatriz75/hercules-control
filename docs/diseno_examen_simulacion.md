# Examen de simulación — diseño (pendiente de implementar)

> **Estado:** diseño funcional. Falta el **diseño de interfaces** (pantallas del simulador) y la implementación. Este documento fija qué se va a construir para que el diseño de interfaces y el desarrollo partan de lo mismo.

## 1. Qué es

Al terminar todas las lecciones de su curso, el aspirante (rol **Alumno/Cobrador**) presenta un **examen de simulación**: un **día de trabajo reducido**, con **5 a 10 pedidos ficticios**, en el que debe hacer lo mismo que hará con clientes reales, dentro de un entorno simulado de Hércules Control.

Aprobarlo es la condición para pasar de **candidato a plantilla** (guías de curso de Ofertas y Mexi, «Evaluación práctica final»: «La candidata recibe un embudo simulado con mensajes, comprobantes, devoluciones, reporte de entrega y un duplicado. Debe ejecutar el flujo completo y explicar sus decisiones»).

Nada del simulador toca sistemas reales: no hay Kommo, WhatsApp, Telegram, Rocket Chat ni Banxico reales. Todo se imita dentro de Hércules.

## 2. Cuándo se habilita

- Cuando el alumno tiene **todas las lecciones del curso completas** (teoría leída y práctica aprobada).
- Una vez por intento; si reprueba, se habilita un **segundo intento supervisado** después de la recuperación que asigne el supervisor (regla de las guías).
- Tiempo límite configurable por el administrador (sugerido: 60–90 minutos para 5–10 pedidos).

## 3. Qué se simula

El alumno recibe un **embudo** con sus pedidos y trabaja como en un día real. Cada pedido es un **caso** con una situación prediseñada:

| Tipo de caso | Qué debe hacer el alumno | Qué se evalúa |
|---|---|---|
| Cliente que paga por transferencia | Conversar, enviar la cuenta correcta, validar en «Banxico simulado» | Cuenta tomada del enlace oficial (no de un texto guardado); detectar **LIQUIDADO** vs **DEVUELTO**; fecha, monto, cuenta destino |
| Cliente que paga en OXXO | Pedir el vale en «Rocket Chat simulado», enviarlo, validar el recibo | Que la **referencia** coincida con el vale; imagen legible |
| Comprobante falso o dudoso | No aprobarlo | Error crítico si lo aprueba |
| Devolución por daño | Pedir evidencia y paquetería, llenar «Devolución por», derivar | Orden del flujo; campo de Kommo lleno |
| Devolución por decisión propia | Cobrar $150, no subirlo a Telegram, pedir fotos y paquetería | Que **no** suba ese comprobante a Telegram |
| No reconoce la entrega | Pedir evidencia, decidir reporte o insistir según la distancia (1000 m Ofertas / 800 m Mexi), llenar «Reporte por», registrar en el Excel | Umbral correcto de su tienda |
| Falla salvable | Ofrecer descuento dentro de los límites de su tienda | No inventar montos |
| Cliente que no responde | Llamadas según su tienda, notas con capturas, decidir Nivel 3 | Cadencia y expediente antes de escalar |
| Duplicado | Detectar que otro cobrador ya atendió al cliente | Detener, documentar, no presionar dos veces |
| Chat vencido (Ofertas) | Llamar e invitar a escribir; responder por la misma línea | Línea correcta |

Cada examen arma **5 a 10 casos al azar** de un banco de escenarios, cuidando que haya al menos: un pago válido, un comprobante dudoso, una incidencia (devolución o reporte) y un duplicado.

## 4. Interfaces a diseñar

Se va a hacer un **diseño de interfaces** específico para el simulador. Pantallas previstas:

1. **Portada del examen**: reglas, tiempo, número de pedidos, botón «Empezar». Aviso de que el examen no muestra respuestas correctas hasta terminar.
2. **Embudo simulado (tipo Kommo)**: columnas Entregados → Contestaron/Chats → Te pago mañana → Comprobantes → Devoluciones / Reportes / Nivel 3 / Deudores. Tarjetas arrastrables con el pedido y el cliente. Al mover una tarjeta a Devoluciones, Reportes o Deudores, la tarjeta exige el seleccionable **Devolución por / Reporte por / Deudor por**.
3. **Chat simulado (tipo WhatsApp)**: el cliente ficticio responde según un guion ramificado; selector de línea (Ofertas: DG Doo / API); reloj de 24 h para chats vencidos; botón de llamada que abre el registro de llamada.
4. **Banxico simulado**: formulario como el CEP real que devuelve un resultado prediseñado (Liquidado, Devuelto o no encontrado).
5. **Telegram simulado**: subida de imagen + descripción con validación de los cuatro datos (orden, monto, nombre, tarjeta destino/OXXO). **Sin** opción de editar ni borrar: para corregir hay que «consultar al encargado».
6. **Rocket Chat simulado**: grupos para pedir vales de OXXO, evidencias de entrega, rastreo (Evidencias) y para entregar comprobantes, reportes y devoluciones por lotes en Cobranza.
7. **Excel de reportes simulado**: fila del mes en curso con validación de campos.
8. **Página de formas de pago simulada**: las cuentas cambian entre intentos, para comprobar que el alumno las consulta cada vez.
9. **Resultado**: puntaje por estación, errores críticos detectados, decisiones con su explicación y la respuesta esperada.
10. **Vista del supervisor**: lista de exámenes, detalle paso a paso de lo que hizo el alumno (bitácora), revisión manual de las explicaciones y aprobación final; asignar recuperación y segundo intento.
11. **Editor de escenarios (Administrador)**: crear casos con guion del cliente, imágenes (comprobantes, vales, mapas), resultado de Banxico y respuesta esperada.

## 5. Calificación

Basada en la tabla de estaciones de las guías de curso:

| Estación | Tarea observable | Puntos |
|---|---|---|
| 1. Priorización | Detectar chats pendientes y ordenar por urgencia | 10 |
| 2. Conversación | Trato cordial, ortografía y objetivo de cobro | 15 |
| 3. Comprobante | Validar datos, detectar fraude y registrar | 20 |
| 4. Incidencia | Resolver devolución, discrepancia o reporte según evidencia | 15 |
| 5. CRM | Mover etapa, cerrar bot si aplica, notas, campos de motivo y estado | 15 |
| 6. Evidencias | Subir y entregar con datos completos | 10 |
| 7. Línea | Uso seguro de la línea | 15 |

- **Aprobación:** mínimo **80/100** y **ningún error crítico**.
- **Errores críticos** (reprueban aunque el puntaje alcance): dar una cuenta no autorizada; aprobar un comprobante inválido (incluido un DEVUELTO en Banxico); editar o borrar un comprobante en Telegram; omitir evidencia en una devolución; mover a Devoluciones/Reportes/Deudores sin llenar el campo de motivo; alterar datos; escalar a Nivel 3 sin tratamiento suficiente.
- La parte automática (estaciones 1, 3, 4, 5, 6) la califica el sistema; la conversación y las explicaciones las revisa el supervisor.

## 6. Roles

| Rol | Puede |
|---|---|
| Alumno/Cobrador | Presentar el examen cuando terminó el curso; ver su resultado al final |
| Supervisor | Ver exámenes de alumnos, revisar la parte manual, aprobar o asignar recuperación |
| Administrador | Todo lo anterior + crear y editar escenarios y la configuración del examen |
| Consulta gerencial | Ver resultados (solo lectura) |

Permisos nuevos previstos: `simulation.take`, `simulation.review`, `simulation.manage`.

## 7. Datos (borrador)

- `simulation_scenarios`: tipo de caso, tienda (Ofertas/Mexi/ambas), guion del cliente (JSON de pasos y ramas), adjuntos (comprobante, vale, mapa), resultado Banxico simulado, respuesta esperada y puntos por estación.
- `simulation_exams`: alumno, curso, fecha, tiempo límite, estado (en curso, por revisar, aprobado, reprobado), puntaje y errores críticos.
- `simulation_exam_cases`: casos sorteados para ese examen.
- `simulation_events`: bitácora de cada acción del alumno (mensaje enviado, tarjeta movida, campo llenado, validación, subida) con hora; es la base de la calificación y de la revisión del supervisor.

## 8. Fases propuestas

1. **Diseño de interfaces** de las pantallas de la sección 4 (prototipo navegable).
2. Modelo de datos, editor de escenarios y banco inicial de 15–20 escenarios por tienda tomados de las guías.
3. Simulador del alumno (embudo, chat, Banxico, Telegram, Rocket Chat, Excel) con bitácora.
4. Calificación automática + revisión del supervisor + resultado.
5. Prueba piloto con candidatos reales y ajuste de tiempos y puntajes.

## 9. Pendiente de definir con la encargada

- Tiempo límite y cantidad exacta de pedidos (5 o 10) por tienda.
- Si el segundo intento usa escenarios distintos (recomendado).
- Quién aprueba finalmente el paso a plantilla (supervisor o administrador) y si eso actualiza los documentos de cobradores automáticamente.
