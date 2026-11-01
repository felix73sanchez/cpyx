# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Felix Sanchez <felixsanchez73@outlook.com>

# shellcheck shell=bash
# =============================================================================
# args.sh - ayuda y análisis de la línea de comandos
#   Soporta opciones cortas agrupables (-ndy), largas (--dry-run, --log=ARCH),
#   y "--" para marcar el fin de las opciones.
# =============================================================================

args::usage() {
    cat <<EOF
${C_BOLD}${CPYX_NAME} ${CPYX_VERSION}${C_RESET} - copia con rsync, barra de progreso y detalles

${C_BOLD}Uso:${C_RESET}
  ${CPYX_NAME} [opciones] ORIGEN DESTINO
  ${CPYX_NAME} [opciones] ORIGEN DESTINO -b [--keep N]

${C_BOLD}Opciones:${C_RESET}
  -n, --dry-run       Simulación: muestra qué se copiaría sin copiar nada
  -d, --delete        Borra en el destino lo que no exista en el origen
  -y, --yes           No pedir confirmación (necesario con --delete sin terminal)
  -x, --exclude PAT   Excluir patrón (repetible: -x '*.tmp' -x node_modules)
  -X, --exclude-from ARCHIVO
                      Leer patrones de exclusión desde archivo
  -l, --log ARCHIVO   Guardar el log en ARCHIVO
                      (por defecto: \${XDG_STATE_HOME:-~/.local/state}/cpyx/FECHA.log)
  -L, --no-log        No guardar log
  -b, --backup        Modo backup incremental con hardlinks (usa DESTINO como raíz)
  --keep N            En modo backup, conservar solo los últimos N snapshots
  --bwlimit RATE      Limitar ancho de banda (K,M,G). Ej: --bwlimit=2M
  -u, --update        Actualizar cpyx a la última versión desde el repositorio
  -V, --version       Mostrar la versión
  -h, --help          Mostrar esta ayuda

${C_BOLD}Ejemplos:${C_RESET}
  ${CPYX_NAME} ~/docs /mnt/backup/docs
  ${CPYX_NAME} -n -x '*.log' -x .git /var/www /mnt/backup/www
  ${CPYX_NAME} ~/Documentos /mnt/backups --backup --keep 7
  ${CPYX_NAME} usuario@servidor:/datos /mnt/local/datos

${C_BOLD}Nota:${C_RESET}
  Por defecto el origen se copia siempre como directorio completo (con todo su
  contenido dentro de una carpeta del mismo nombre en el destino). Una barra "/" final
  en el origen se ignora automáticamente.
  En modo backup (--backup), DESTINO es la raíz de snapshots. Solo rutas locales soportadas.

${C_BOLD}Entorno:${C_RESET}
  NO_COLOR          Desactiva los colores
  CPYX_KEEP_LOGS    Logs que se conservan en el directorio por defecto (30)
  CPYX_PROGRESS     0 desactiva la barra de progreso (por defecto 1)
EOF
}

# Guarda el valor de una opción que lo requiere (-x / -l / -X / --keep / --bwlimit)
args::_set_value() {
    case $1 in
        -x|--exclude)         CPYX_EXCLUDES+=("$2") ;;
        -X|--exclude-from)    args::_load_excludes_from "$2" ;;
        -l|--log)             CPYX_LOG_FILE=$2 ;;
        --keep)               CPYX_BACKUP_KEEP=$2 ;;
        --keep-daily)         CPYX_BACKUP_KEEP_DAILY=$2 ;;
        --keep-weekly)        CPYX_BACKUP_KEEP_WEEKLY=$2 ;;
        --keep-monthly)       CPYX_BACKUP_KEEP_MONTHLY=$2 ;;
        --bwlimit)            CPYX_BWLIMIT=$2 ;;
    esac
}

args::_load_excludes_from() {
    local file=$1
    [[ -f $file ]] || ui::die "$EX_NOINPUT" "Archivo de exclusiones no existe: $file"
    [[ -r $file ]] || ui::die "$EX_USAGE" "Sin permiso de lectura: $file"
    local line
    while IFS= read -r line || [[ -n $line ]]; do
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z $line ]] && continue
        [[ $line == \#* ]] && continue
        CPYX_EXCLUDES+=("$line")
    done < "$file"
}

# args::parse "$@" - rellena las variables CPYX_*
args::parse() {
      local -a pos=()
    local arg cluster flag val

    while (( $# )); do
        arg=$1; shift
        case $arg in
            --) pos+=("$@"); break ;;
            --help)        CPYX_ACTION=help ;;
            --version)     CPYX_ACTION=version ;;
            --backup-list) CPYX_ACTION=backup-list ;;
            -r|--restore)  CPYX_ACTION=restore; CPYX_RESTORE_MODE=1 ;;
            --dry-run)     CPYX_DRY_RUN=1 ;;
            --delete)      CPYX_DELETE=1 ;;
            --yes)         CPYX_ASSUME_YES=1 ;;
            --no-log)      CPYX_NO_LOG=1 ;;
            -q|--quiet)    CPYX_QUIET=1 ;;
            -b|--backup)   CPYX_BACKUP_MODE=1 ;;
            -u|--update)   CPYX_ACTION=update ;;
            --exclude=*|--log=*|--keep=*|--bwlimit=*|--exclude-from=*|--keep-daily=*|--keep-weekly=*|--keep-monthly=*)
                args::_set_value "${arg%%=*}" "${arg#*=}" ;;
            --exclude|--log|--keep|--bwlimit|--exclude-from|--keep-daily|--keep-weekly|--keep-monthly)
                (( $# )) || ui::die "$EX_USAGE" "La opción $arg requiere un argumento"
                args::_set_value "$arg" "$1"; shift ;;
            --*)
                ui::die "$EX_USAGE" "Opción desconocida: $arg (usa --help)" ;;
            -?*)
                cluster=${arg#-}
                while [[ -n $cluster ]]; do
                    flag=${cluster:0:1}; cluster=${cluster:1}
                    case $flag in
                        h) CPYX_ACTION=help ;;
                        v|V) CPYX_ACTION=version ;;
                        u) CPYX_ACTION=update ;;
                        r) CPYX_ACTION=restore; CPYX_RESTORE_MODE=1 ;;
                        n) CPYX_DRY_RUN=1 ;;
                        d) CPYX_DELETE=1 ;;
                        y) CPYX_ASSUME_YES=1 ;;
                        L) CPYX_NO_LOG=1 ;;
                        q) CPYX_QUIET=1 ;;
                        b) CPYX_BACKUP_MODE=1 ;;
                        X) 
                            if [[ -n $cluster ]]; then
                                val=$cluster; cluster=""
                            elif (( $# )); then
                                val=$1; shift
                            else
                                ui::die "$EX_USAGE" "La opción -X requiere un argumento"
                            fi
                            args::_set_value "-X" "$val" ;;
                        x|l)
                            if [[ -n $cluster ]]; then
                                val=$cluster; cluster=""
                            elif (( $# )); then
                                val=$1; shift
                            else
                                ui::die "$EX_USAGE" "La opción -$flag requiere un argumento"
                            fi
                            args::_set_value "-$flag" "$val" ;;
                        *)
                            ui::die "$EX_USAGE" "Opción desconocida: -$flag (usa --help)" ;;
                    esac
                done ;;
            *) pos+=("$arg") ;;
        esac
    done

    if [[ $CPYX_ACTION == backup-list ]]; then
        if (( ${#pos[@]} != 1 )); then
            ui::die "$EX_USAGE" "--backup-list requiere la raíz de backups como argumento"
        fi
        CPYX_BACKUP_ROOT=${pos[0]}
        return
    fi

    if [[ $CPYX_ACTION == restore ]]; then
        if (( ${#pos[@]} != 2 )); then
            ui::die "$EX_USAGE" "--restore requiere ORIGEN(SNAPSHOT) y DESTINO. Usa '${CPYX_NAME} --help' para ver la ayuda."
        fi
        CPYX_SRC=${pos[0]}
        CPYX_DST=${pos[1]}
        if [[ -d $CPYX_SRC && $CPYX_SRC == */ ]]; then
            CPYX_SRC="${CPYX_SRC%/}"
        fi
        if [[ -n $CPYX_BWLIMIT ]]; then
            if ! [[ $CPYX_BWLIMIT =~ ^[0-9]+[kKmMgG]?$ ]]; then
                ui::die "$EX_USAGE" "--bwlimit debe ser un valor como 1000, 2M, 500k"
            fi
        fi
        return
    fi

    if [[ $CPYX_ACTION == run ]]; then
        if (( ${#pos[@]} != 2 )); then
            ui::die "$EX_USAGE" "Se requieren ORIGEN y DESTINO. Usa '${CPYX_NAME} --help' para ver la ayuda."
        fi
        CPYX_SRC=${pos[0]}
        CPYX_DST=${pos[1]}
        # Quitar barra final del origen: siempre copiar el directorio entero,
        # no solo su contenido (más intuitivo que la convención de rsync)
        if [[ -d $CPYX_SRC && $CPYX_SRC == */ ]]; then
            CPYX_SRC="${CPYX_SRC%/}"
        fi

        # Validar --keep
        for k in CPYX_BACKUP_KEEP CPYX_BACKUP_KEEP_DAILY CPYX_BACKUP_KEEP_WEEKLY CPYX_BACKUP_KEEP_MONTHLY; do
            if (( ${!k} )); then
                if ! [[ ${!k} =~ ^[1-9][0-9]*$ ]]; then
                    ui::die "$EX_USAGE" "--keep requiere un número entero positivo"
                fi
            fi
        done
        if [[ -n $CPYX_BWLIMIT ]]; then
            if ! [[ $CPYX_BWLIMIT =~ ^[0-9]+[kKmMgG]?$ ]]; then
                ui::die "$EX_USAGE" "--bwlimit debe ser un valor como 1000, 2M, 500k"
            fi
        fi
    fi
}
