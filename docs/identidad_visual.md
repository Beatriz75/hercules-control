# Identidad visual de Hércules Control

Línea elegida: **Fuerza y control**. Seria y de mando: evoca a Hércules (columnas, escudo) sin caricatura.

## Logo

Escudo azul marino con borde dorado interior y una **H dorada formada por dos columnas acanaladas unidas por un dintel**.

| Archivo | Uso |
|---------|-----|
| `assets/brand/logo_mark.svg` | Símbolo solo (escudo). Avatar, favicon, encabezados pequeños. |
| `assets/brand/logo_wordmark.svg` | Símbolo + "HÉRCULES" (marino, negrita) + "CONTROL" (dorado, espaciado). Pantalla de inicio, documentos, manual. |
| `assets/brand/logo_512.png` | Versión PNG del símbolo para la app. |
| `web/favicon.svg`, `web/favicon.png`, `web/icons/*` | Íconos del navegador y de la app instalada (los "maskable" llevan fondo marino). |

Todos salen de una sola geometría: `tool/brand/generate_logo.py`. Para cambiar el logo se edita ese script y se vuelve a correr (`python tool/brand/generate_logo.py`); no se retocan los PNG a mano.

Reglas:
- Espacio libre alrededor del símbolo: al menos el ancho de una columna de la H.
- Tamaño mínimo del símbolo: 24 px. Por debajo, usar solo el favicon.
- Sobre fondo marino oscuro el escudo se mantiene; el borde dorado lo separa del fondo.
- No cambiar los colores, no deformar, no agregar sombras ni contornos.

## Colores

| Nombre | Hex | Uso |
|--------|-----|-----|
| Azul marino | `#0E2A47` | Color principal: barra lateral, títulos, botones principales. |
| Marino profundo | `#081B30` | Fondos oscuros, íconos maskable. |
| Dorado | `#C9A227` | Acento: elemento seleccionado, logo, detalles de logro (lección aprobada). |
| Dorado claro | `#E3C15A` | Estados hover del dorado. |
| Azul señal | `#2897FF` | Enlaces, información, foco de campos. |
| Fondo | `#F3F6FA` | Fondo general de pantallas. |
| Bordes | `#D9E2EC` | Bordes de campos y tarjetas. |
| Éxito | `#1E8E5A` | Aprobado, guardado. |
| Advertencia | `#D98E04` | Avisos, falta poco. |
| Error | `#C0392B` | Errores y acciones destructivas. |

Contraste: el texto sobre dorado va en marino, nunca en blanco. El texto sobre marino va en blanco.

## Tipografía

- App: la tipografía del sistema (Roboto / Segoe UI), títulos en negrita.
- Logotipo: Montserrat ExtraBold para "HÉRCULES" y SemiBold espaciado para "CONTROL" (con respaldo Segoe UI / Arial).

## Tono de los mensajes

- En español, de tú, frases cortas y concretas.
- Los errores dicen qué pasó y qué hacer: "La contraseña actual no es correcta.", "Completa la lección anterior (teoría y práctica) antes de continuar."
- Sin tecnicismos ni códigos para el usuario final.
