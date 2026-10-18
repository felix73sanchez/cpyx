# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y
versionado según [SemVer](https://semver.org/lang/es/).

## [Sin publicar]

### Añadido
- `uninstall.sh`: desinstalador independiente con detección de prefix, elevación sudo/doas y soporte `DESTDIR`.

### Modificado
- `validate.sh` auto-instala dependencias faltantes (`rsync`, `bash`, `pv`) usando el gestor de paquetes detectado.

## [1.1.3] - 2026-10-18

### Corregido
- `update.sh`: sincroniza lib/ antes que bin/ para evitar estados inconsistentes.
- `update.sh`: verifica que el binario funcione después de actualizar.

### Añadido
- `update.sh`: `-v` como alias para mostrar la versión del binario instalado.

## [1.1.2] - 2026-10-18

### Corregido
- `update.sh`: corrige `mkdir -p` que fallaba cuando el binario ya existía como archivo.
- `update.sh`: sincroniza completions en los subdirectorios correctos de `share/`.

## [1.1.1] - 2026-10-18

### Modificado
- `update.sh` usa `rsync --delete` incremental en vez de desinstalar + instalar (no destructivo, preserva la instalación).

## [1.1.0] - 2026-10-18

### Añadido
- Barra de progreso visual propia (bloques Unicode, porcentaje, tamaño, velocidad y ETA)
  dibujada en stderr a partir de `rsync --info=progress2`, con el archivo en curso.
- Colores por estado (amarillo copiando, verde completado), iconos y nombre truncado.
- Bloque de error con causa probable (permiso de lectura/escritura, sin espacio, ruta ausente).
- Nuevo módulo `lib/cpyx/progress.sh`; `pv` como dependencia opcional con fallback a rsync.
- Variable de entorno `CPYX_PROGRESS` para desactivar la barra.

### Modificado
- `rsync.sh` separa la barra (stderr/tty) del listado y los errores (log).

## [1.0.0] - 2026-10-14

### Añadido
- Copia con `rsync` con barra de progreso global, detalle de cada archivo y estadísticas finales.
- Opciones cortas agrupables y largas: `-n/--dry-run`, `-d/--delete`, `-y/--yes`,
  `-x/--exclude`, `-l/--log`, `-L/--no-log`, `-V/--version`, `-h/--help`.
- Confirmación antes de `--delete`; sin terminal exige `-y`.
- Log por defecto en `~/.local/state/cpyx/` con rotación (`CPYX_KEEP_LOGS`).
- Códigos de salida sysexits y manejo de Ctrl+C (los parciales se conservan).
- Soporte para rsync antiguo (< 3.1) con progreso por archivo.
- Estructura modular: `bin/cpyx` + `lib/cpyx/*.sh`.
- Instalador universal (`install.sh`) con detección de gestor de paquetes, `--prefix`,
  `--user`, `DESTDIR` y desinstalación.
- Autocompletado para bash, zsh y fish.
- Suite de pruebas en `tests/run.sh`.

[Sin publicar]: ../../compare/v1.0.0...HEAD
[1.0.0]: ../../releases/tag/v1.0.0
