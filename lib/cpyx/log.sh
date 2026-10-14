# shellcheck shell=bash
# =============================================================================
# log.sh - ubicación, creación y rotación del archivo de log
# =============================================================================

# Directorio de logs por defecto (XDG)
log::default_dir() {
    printf '%s' "${XDG_STATE_HOME:-$HOME/.local/state}/cpyx"
}

# Deja CPYX_LOG_FILE listo para usarse, o desactiva el log si no se puede
log::init() {
    if (( CPYX_NO_LOG )); then
        return 0
    fi

    local dir
    if [[ -z $CPYX_LOG_FILE ]]; then
        dir="$(log::default_dir)"
        if ! mkdir -p -- "$dir" 2>/dev/null; then
            ui::warn "No se pudo crear $dir; el log queda desactivado."
            CPYX_NO_LOG=1
            return 0
        fi
        CPYX_LOG_FILE="$dir/$(date +%Y%m%d_%H%M%S).log"
        log::prune "$dir"
    else
        dir="$(dirname -- "$CPYX_LOG_FILE")"
        if ! mkdir -p -- "$dir" 2>/dev/null; then
            ui::die "$EX_CANTCREAT" "No se pudo crear el directorio del log: $dir"
        fi
    fi
}

# Conserva solo los últimos CPYX_KEEP_LOGS logs del directorio por defecto
log::prune() {
    local dir=$1 keep=$CPYX_KEEP_LOGS
    if [[ ! $keep =~ ^[0-9]+$ ]]; then
        keep=30
    fi
    # shellcheck disable=SC2012
    { ls -1t -- "$dir"/*.log 2>/dev/null | tail -n +"$((keep + 1))" | while IFS= read -r old; do
        rm -f -- "$old"
    done; } || true
    return 0
}
