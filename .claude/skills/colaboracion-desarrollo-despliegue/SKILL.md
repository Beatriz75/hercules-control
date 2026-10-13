---
name: colaboracion-desarrollo-despliegue
description: Usar al desarrollar, versionar o desplegar un sistema dockerizado entre dos personas (desarrollador y responsable de despliegue) con GitHub: ramas, releases, migraciones, variables y rollback.
---

# Colaboración desarrollo–despliegue con Docker y GitHub

## Contexto

En este proyecto colaboran dos personas:

- **Desarrollador**: escribe el código, corrige errores, agrega módulos y prepara cada versión.
- **Responsable de despliegue**: administra el servidor, configura variables reales, aplica actualizaciones en producción, hace respaldos y revierte si algo falla.

Docker es el contrato entre ambos: el desarrollador garantiza que "esta imagen, con estas variables, funciona"; el responsable garantiza que "el servidor le da a la imagen lo que necesita". GitHub es la única fuente de verdad del código.

El objetivo de esta skill es evitar los conflictos típicos: versiones confusas, variables faltantes, migraciones que rompen la base de datos, datos perdidos, despliegues sin forma de regresar y cambios que el otro no conocía.

## Cuándo aplicar esta skill

- Crear o modificar `Dockerfile`, `docker-compose.yml`, `.dockerignore` o `.env.example`.
- Agregar un módulo, corregir un error o cambiar dependencias.
- Cualquier cambio en la estructura de la base de datos.
- Preparar una versión para producción (pull request a `main`, etiqueta, notas de versión).
- Desplegar, actualizar o revertir en producción.
- Revisar un pull request antes de unirlo.

## Reglas fijas del proyecto

### 1. Ramas

- `main`: solo lo que está listo para producción. Protegida: no se hace push directo, solo entra por pull request.
- `develop`: integración del trabajo en curso.
- `feature/<nombre>`: módulos o funciones nuevas (p. ej. `feature/modulo-reportes`).
- `fix/<nombre>`: correcciones normales.
- `hotfix/<nombre>`: correcciones urgentes de producción; salen de `main` y regresan a `main` y a `develop`.
- Los mensajes de commit describen qué y por qué, en español, en una línea clara (p. ej. `fix: corrige cálculo de totales en reporte mensual`).

### 2. Versiones

- Versionado semántico `vMAYOR.MENOR.PARCHE`:
  - PARCHE: correcciones sin cambios de comportamiento esperado.
  - MENOR: módulos o funciones nuevas compatibles.
  - MAYOR: cambios que rompen compatibilidad o requieren intervención manual importante.
- Cada despliegue a producción corresponde a una etiqueta de Git y a una Release en GitHub.
- La imagen de Docker lleva la misma etiqueta que la versión (`mi-app:v1.4.0`). Nunca se despliega solo con `latest`.

### 3. Configuración y secretos

- Ninguna contraseña, clave de API, token o dirección de servidor real va en el código ni en el repositorio.
- Toda la configuración se lee de variables de entorno.
- Cada variable nueva o modificada se agrega a `.env.example` con un comentario que explique para qué sirve y un valor de ejemplo no real, y se anota en las notas de versión.
- `.env` está en `.gitignore` y en `.dockerignore`.

### 4. Base de datos

- Todo cambio de estructura se hace mediante migraciones del framework (Django, Laravel, Alembic, Prisma, etc.). Nunca a mano en producción.
- Nunca se edita una migración que ya se aplicó en producción; se crea una nueva.
- Nunca se pide borrar y recrear la base de datos de producción.
- Las migraciones deben ser seguras con datos existentes:
  - Agregar antes de quitar: primero se agrega la columna o tabla nueva, se migra la información y, en una versión posterior, se elimina lo viejo.
  - Renombrar en dos pasos (agregar nueva, copiar, quitar vieja) cuando hay datos.
  - Columnas nuevas obligatorias deben tener valor por defecto o un paso de llenado.
- Toda migración destructiva (borra columnas, tablas o datos) se marca explícitamente en las notas de versión como **requiere respaldo**.

### 5. Datos persistentes

- Todo lo que no se puede perder vive en volúmenes nombrados o rutas montadas: la base de datos, los archivos que suben los usuarios, y cualquier otro dato generado.
- Nada importante se guarda solo dentro del sistema de archivos del contenedor.
- Si un módulo nuevo empieza a guardar archivos, se agrega su volumen al `docker-compose.yml` y se avisa en las notas de versión.

### 6. Imagen y dependencias

- La imagen base usa una versión específica (p. ej. `python:3.11-slim`, no `python:latest`).
- Las dependencias quedan fijadas con archivo de bloqueo (`requirements.txt` con versiones, `package-lock.json`, `composer.lock`, `poetry.lock`, etc.).
- `.dockerignore` excluye `.git`, `.env`, `node_modules`, cachés, archivos de prueba pesados y respaldos.
- El contenedor de la aplicación incluye un `healthcheck` o una ruta de salud (p. ej. `/health`) para verificar que arrancó bien.
- Los puertos expuestos están documentados en el README; si cambian, se anota en las notas de versión.

## Checklist del desarrollador antes de abrir un pull request a `main`

1. El sistema se construye y arranca desde cero con `docker compose up -d --build` en la máquina del desarrollador.
2. Las migraciones nuevas se aplican sin error sobre una copia de la base con datos, no solo sobre una base vacía.
3. No hay secretos en el diff.
4. `.env.example` está actualizado con toda variable nueva.
5. `docker-compose.yml` refleja servicios, puertos y volúmenes nuevos.
6. Las dependencias nuevas están fijadas en el archivo de bloqueo.
7. Se actualizó el número de versión y se redactaron las notas de versión con la plantilla de abajo.
8. El pull request describe qué cambió y si requiere acciones manuales del responsable de despliegue.

## Plantilla de notas de versión

Usar esta plantilla en la descripción del pull request y en la Release de GitHub:

```markdown
## vX.Y.Z — AAAA-MM-DD

### Qué cambió
- ...

### Módulos nuevos
- ... (o "Ninguno")

### Correcciones
- ...

### Base de datos
- Migraciones: Sí / No
- ¿Destructivas?: Sí / No  → si Sí: RESPALDO OBLIGATORIO antes de desplegar
- Detalle: ...

### Variables de entorno
- Nuevas: `NOMBRE` — para qué sirve — valor esperado
- Modificadas / eliminadas: ...

### Docker
- Cambios en servicios, puertos o volúmenes: ...

### Pasos manuales para el despliegue
- ... (o "Ninguno")

### Cómo revertir
- Volver a la imagen vX.Y.Z-anterior. ¿La migración es reversible?: Sí / No
```

## Procedimiento de despliegue (responsable de despliegue)

1. Leer las notas de versión completas.
2. Configurar en el servidor las variables de entorno nuevas antes de actualizar.
3. Respaldar la base de datos y los volúmenes de archivos. Obligatorio si hay migraciones.
4. Traer la versión:
   - Si se construye en el servidor: `git fetch --tags && git checkout vX.Y.Z` y luego `docker compose up -d --build`.
   - Si se usa un registro de imágenes: actualizar la etiqueta en `docker-compose.yml` (o en la variable correspondiente) y ejecutar `docker compose pull && docker compose up -d`.
5. Aplicar migraciones con el comando del framework, si no se aplican automáticamente al arrancar.
6. Verificar: `docker compose ps`, revisar logs (`docker compose logs --tail=100 app`) y probar la ruta de salud y las funciones principales.
7. Avisar al desarrollador que la versión quedó en producción, o reportar el problema con logs.

## Procedimiento de reversión

1. Volver a la etiqueta o imagen anterior y ejecutar `docker compose up -d`.
2. Si la versión fallida aplicó migraciones:
   - Si son reversibles, revertirlas con el comando del framework.
   - Si no lo son, restaurar el respaldo tomado antes del despliegue.
3. Registrar qué falló en un issue de GitHub para que el desarrollador lo corrija en una rama `hotfix/`.

## Cómo debe actuar Claude al usar esta skill

- Antes de proponer cambios, identificar el lenguaje, framework y sistema de migraciones del proyecto leyendo sus archivos; si no se puede determinar, preguntar.
- Cada vez que modifique o revise código, comprobar si el cambio introduce alguna de estas cosas y, si es así, actualizar también los archivos correspondientes y las notas de versión:
  - variables de entorno nuevas → `.env.example`
  - cambios de estructura de datos → migración
  - nuevos servicios, puertos o archivos persistentes → `docker-compose.yml` y volúmenes
  - dependencias nuevas → archivo de bloqueo
- Advertir de forma explícita cuando detecte: secretos en el código, migraciones destructivas, uso de `latest`, datos guardados fuera de volúmenes, edición de migraciones ya aplicadas o push directo a `main`.
- Al preparar una versión, proponer el número de versión según las reglas y llenar la plantilla de notas de versión.
- No ejecutar comandos contra producción; generar las instrucciones para que el responsable de despliegue las ejecute.
- Responder en español y con explicaciones claras para alguien que no es experto en infraestructura.
