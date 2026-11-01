# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Felix Sanchez <felixsanchez73@outlook.com>

# shellcheck shell=bash
# =============================================================================
# main.sh - orquestación del flujo completo
# =============================================================================

main::on_interrupt() {
    ui::blank
    ui::warn "Interrumpido. Los archivos parciales se conservan: vuelve a ejecutar para reanudar."
    exit "$EX_INTERRUPT"
}

main::self_update() {
    local updater=""
    local -a candidates=(
        "$BIN_DIR/../update.sh"
        "${LIBDIR:-}/update.sh"
        "$(dirname "${LIBDIR:-}")/update.sh"
        "$HOME/.local/lib/cpyx/update.sh"
        "/usr/local/lib/cpyx/update.sh"
        "/usr/lib/cpyx/update.sh"
        "$HOME/.local/share/cpyx/update.sh"
        "/usr/local/share/cpyx/update.sh"
    )
    local c
    for c in "${candidates[@]}"; do
        if [[ -f $c ]]; then
            updater="$(readlink -f "$c")"
            break
        fi
    done
    if [[ -z $updater ]]; then
        ui::die "$EX_UNAVAILABLE" "No se encontró update.sh. Clona el repositorio y ejecuta ./update.sh manualmente."
    fi
    ui::note "Actualizando con: $updater"
    exec bash "$updater" "$@"
}

main() {
    trap main::on_interrupt INT TERM

    ui::init
    core::reset_config
    args::parse "$@"

    case $CPYX_ACTION in
        help)    args::usage;                              return 0 ;;
        version) printf '%s %s\n' "$CPYX_NAME" "$CPYX_VERSION"; return 0 ;;
        update)  main::self_update "$@";                   return $? ;;
    esac

    validate::require_rsync
    validate::require_pv
    validate::paths
    validate::confirm_delete
    validate::acquire_lock
    validate::disk_space
    log::init

    report::header
    rsync::build_args
    rsync::run
    report::footer

    return "$CPYX_STATUS"
}
