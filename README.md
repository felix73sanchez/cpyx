# cpyx

Copia archivos entre rutas con `rsync`, mostrando barra de progreso global,
detalle de cada archivo, estadísticas y un log. Funciona en cualquier Linux con
`bash` y `rsync`.

## Instalación

```bash
./install.sh              # /usr/local (con sudo) o ~/.local (sin privilegios)
./install.sh --user       # solo para tu usuario
./install.sh --prefix=/opt/cpyx
./install.sh --uninstall
```

El instalador detecta tu gestor de paquetes (pacman, apt, dnf, yum, zypper, apk,
xbps, emerge, nix) e instala `rsync` y `bash` si faltan. También instala el
autocompletado para bash, zsh y fish.

## Uso

```bash
cpyx [opciones] ORIGEN DESTINO
```

| Opción | Descripción |
|---|---|
| `-n`, `--dry-run` | Simulación: no copia nada |
| `-d`, `--delete` | Borra en destino lo que no exista en origen (pide confirmación) |
| `-y`, `--yes` | No pedir confirmación |
| `-x`, `--exclude PAT` | Excluir patrón (repetible) |
| `-l`, `--log ARCHIVO` | Guardar el log en ARCHIVO |
| `-L`, `--no-log` | No guardar log |
| `-V`, `--version` | Versión |
| `-h`, `--help` | Ayuda |

Las opciones cortas se pueden agrupar (`-ndy`). Se admite `--` para rutas que
empiezan con guion.

```bash
cpyx ~/docs /mnt/backup/docs
cpyx -n -x '*.log' -x .git /var/www /mnt/backup/www
cpyx usuario@servidor:/datos /mnt/local/datos
```

Igual que rsync, un origen con `/` al final copia el **contenido** de la carpeta;
sin `/` copia la carpeta misma dentro del destino.

## Códigos de salida

| Código | Significado |
|---|---|
| 0 | Éxito |
| 1 | Cancelado por el usuario |
| 64 | Uso incorrecto |
| 66 | El origen no existe |
| 69 | Falta una dependencia |
| 73 | No se pudo crear el destino |
| 130 | Interrumpido (Ctrl+C) |
| otro | Código de error de rsync |

## Licencia

Este proyecto se distribuye bajo la licencia **GNU General Public License v3.0 o posterior**
(GPL-3.0-or-later). Consulta el archivo [LICENSE](LICENSE).

## Estructura

```
bin/cpyx            Punto de entrada: carga módulos y llama a main()
lib/cpyx/
  core.sh           Constantes, códigos de salida, configuración por defecto
  ui.sh             Colores y mensajes
  log.sh            Ubicación, creación y rotación de logs
  args.sh           Ayuda y análisis de argumentos
  validate.sh       Dependencias, rutas y confirmaciones
  rsync.sh          Construcción de argumentos y ejecución
  report.sh         Resumen previo y resultado final
  main.sh           Orquestación del flujo
completions/        Autocompletado (bash, zsh, fish)
tests/run.sh        Pruebas
install.sh          Instalador / desinstalador
```

## Autocompletado

El instalador deja los archivos en `share/`: `bash-completion/completions/cpyx`,
`zsh/site-functions/_cpyx` y `fish/vendor_completions.d/cpyx.fish`.

En zsh, con el prefijo `/usr` o `/usr/local` funciona solo (reinicia la shell).
Con `~/.local` agrega esto a `~/.zshrc`, antes de `compinit`:

```zsh
fpath=(~/.local/share/zsh/site-functions $fpath)
autoload -Uz compinit && compinit
```

## Entorno

- `NO_COLOR`: desactiva los colores.
- `CPYX_KEEP_LOGS`: logs que se conservan en el directorio por defecto (30).
- `CPYX_PROGRESS`: `0` desactiva la barra de progreso (por defecto `1`).
- `CPYX_LIBDIR`: ruta alternativa a la biblioteca de módulos.
- Los logs van a `${XDG_STATE_HOME:-~/.local/state}/cpyx/`.

## Versionado

Usa [SemVer](https://semver.org/lang/es/) (`MAYOR.MENOR.PARCHE`). La versión vive en
`lib/cpyx/core.sh` (`CPYX_VERSION`) y cada versión publicada lleva un tag `vX.Y.Z`.
Los cambios se registran en `CHANGELOG.md`.

## Pruebas

```bash
bash tests/run.sh
```
