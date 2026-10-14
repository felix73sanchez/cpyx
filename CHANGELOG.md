# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y
versionado según [SemVer](https://semver.org/lang/es/).

## [Sin publicar]

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
