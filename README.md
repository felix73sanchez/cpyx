# cpyx

Copiador rápido y seguro con barras de progreso, logs detallados y **copias incrementales con hardlinks**.

Ideal para mover archivos entre discos, crear backups con ahorro de espacio o sincronizar carpetas sin complicarte con comandos complejos.

## ¿Para qué sirve?

- **Copia normal** — Copia carpetas completas con seguimiento visual, velocidad, ETA y resumen al finalizar
- **Backup incremental** — Crea snapshots diarios/por ejecución con hardlinks. Si no cambia un archivo, no se duplica, se enlaza
- **Seguro** — Comprobación de espacio, bloqueo contra ejecuciones simultáneas, confirmación antes de borrar
- **Práctico** — Exclusiones, límite de velocidad, logs automáticos, rotación de backups

## Instalación

```bash
./install.sh              # /usr/local (con sudo) o ~/.local (sin privilegios)
./install.sh --user       # solo para tu usuario
./install.sh --prefix=/opt/cpyx
./install.sh --uninstall
```

El instalador detecta automáticamente las dependencias necesarias e instala lo que falte con tu gestor de paquetes.

## Uso rápido

```bash
# Copia normal
cpyx ~/Documentos /mnt/backup/Documentos

# Backup incremental con rotación (conservar últimos 7)
cpyx ~/Documentos /mnt/backups --backup --keep 7

# Simular sin copiar nada
cpyx ~/Documentos /mnt/backup/Documentos --dry-run

# Ver snapshots guardados
cpyx --backup-list /mnt/backups
```

## Opciones principales

| Opción | Descripción |
|---|---|
| `-n`, `--dry-run` | Simular copia sin escribir nada |
| `-d`, `--delete` | Sincronizar destino borrando lo que ya no existe en origen |
| `-y`, `--yes` | No pedir confirmación |
| `-x`, `--exclude PAT` | Excluir archivos o carpetas |
| `-X`, `--exclude-from ARCHIVO` | Excluir desde un archivo |
| `-l`, `--log ARCHIVO` | Guardar registro detallado |
| `-L`, `--no-log` | No guardar registro |
| `-q`, `--quiet` | Modo silencioso (ideal para scripts/cron) |
| `-b`, `--backup` | Crear snapshot incremental con hardlinks |
| `--backup-list` | Listar snapshots existentes |
| `--keep N` | Conservar solo los últimos N snapshots |
| `--keep-daily N` / `--keep-weekly N` / `--keep-monthly N` | Rotación por política |
| `--bwlimit RATE` | Limitar velocidad (ej: `2M`, `500k`) |
| `-u`, `--update` | Actualizar a la última versión |
| `-v`, `-V`, `--version` | Ver versión |
| `-h`, `--help` | Ver ayuda completa |

Las opciones cortas se pueden agrupar (`-ndy`). Usa `--` para rutas que empiecen con guion.

## Backups incrementales

Cuando usas `--backup`, cpyx guarda cada copia como un snapshot independiente con su fecha:

```text
/mnt/backups/
├── 2026-11-01_14-30-22/
├── 2026-11-01_18-45-10/
├── 2026-11-02_09-12-03/
└── latest -> 2026-11-02_09-12-03
```

Los archivos sin cambios usan **hardlinks** con el snapshot anterior. Cada snapshot se puede explorar como si fuera una copia completa, pero ocupa mucho menos espacio.

## Actualización

```bash
cpyx --update
```

## Dependencias

Solo necesita `bash`. El instalador se encarga de asegurar `rsync` (y opcionalmente `pv`) para el funcionamiento óptimo.

## Licencia

GPL-3.0-or-later
