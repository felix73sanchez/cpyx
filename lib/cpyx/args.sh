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

${C_BOLD}Opciones:${C_RESET}
  -n, --dry-run       Simulación: muestra qué se copiaría sin copiar nada
  -d, --delete        Borra en el destino lo que no exista en el origen
  -y, --yes           No pedir confirmación (necesario con --delete sin terminal)
  -x, --exclude PAT   Excluir patrón (repetible: -x '*.tmp' -x node_modules)
  -l, --log ARCHIVO   Guardar el log en ARCHIVO
                      (por defecto: \${XDG_STATE_HOME:-~/.local/state}/cpyx/FECHA.log)
  -L, --no-log        No guardar log
  -V, --version       Mostrar la versión
  -h, --help          Mostrar esta ayuda

${C_BOLD}Ejemplos:${C_RESET}
  ${CPYX_NAME} ~/docs /mnt/backup/docs
  ${CPYX_NAME} -n -x '*.log' -x .git /var/www /mnt/backup/www
  ${CPYX_NAME} usuario@servidor:/datos /mnt/local/datos

${C_BOLD}Nota:${C_RESET} el origen se copia siempre como directorio completo (con todo su
contenido dentro de una carpeta del mismo nombre en el destino). Una barra "/" final
en el origen se ignora automáticamente.

${C_BOLD}Entorno:${C_RESET}
  NO_COLOR          Desactiva los colores
  CPYX_KEEP_LOGS    Logs que se conservan en el directorio por defecto (30)
  CPYX_PROGRESS     0 desactiva la barra de progreso (por defecto 1)
EOF
}

# Guarda el valor de una opción que lo requiere (-x / -l)
args::_set_value() {
    case $1 in
        -x|--exclude) CPYX_EXCLUDES+=("$2") ;;
        -l|--log)     CPYX_LOG_FILE=$2 ;;
    esac
}

# args::parse "$@" - rellena las variables CPYX_*
args::parse() {
    local -a pos=()
    local arg cluster flag val

    while (( $# )); do
        arg=$1; shift
        case $arg in
            --) pos+=("$@"); break ;;
            --help)     CPYX_ACTION=help ;;
            --version)  CPYX_ACTION=version ;;
            --dry-run)  CPYX_DRY_RUN=1 ;;
            --delete)   CPYX_DELETE=1 ;;
            --yes)      CPYX_ASSUME_YES=1 ;;
            --no-log)   CPYX_NO_LOG=1 ;;
            --exclude=*|--log=*)
                args::_set_value "${arg%%=*}" "${arg#*=}" ;;
            --exclude|--log)
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
                        n) CPYX_DRY_RUN=1 ;;
                        d) CPYX_DELETE=1 ;;
                        y) CPYX_ASSUME_YES=1 ;;
                        L) CPYX_NO_LOG=1 ;;
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
    fi
}
