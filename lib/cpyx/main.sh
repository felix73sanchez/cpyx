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

main::backup_list() {
    local root=$1
    [[ -d $root ]] || ui::die "$EX_NOINPUT" "Raíz de backups no existe: $root"
    ui::init
    local latest
    latest=$(readlink -f "$root/latest" 2>/dev/null || true)
    printf '%s\n' "Snapshots en: $root"
    printf '%s\n' "----------------------------------------"
    local -a snaps=()
    mapfile -t snaps < <(core::backup_list "$root")
    if (( ${#snaps[@]} == 0 )); then
        printf '%s\n' "(ninguno)"
        return 0
    fi
    local s snap_dir size
    for s in "${snaps[@]}"; do
        snap_dir="$root/$s"
        if [[ -n $latest && "$(readlink -f "$snap_dir")" == "$latest" ]]; then
            printf '%s\n' "  * $s  (latest)"
        else
            printf '%s\n' "    $s"
        fi
    done
    printf '%s\n' "----------------------------------------"
    size=$(du -sh "$root" 2>/dev/null | awk '{print $1}')
    printf '%s\n' "Total usado: $size"
}

main() {
    trap main::on_interrupt INT TERM

    ui::init
    core::reset_config
    args::parse "$@"

    case $CPYX_ACTION in
        help)        args::usage;                              return 0 ;;
        version)     printf '%s %s\n' "$CPYX_NAME" "$CPYX_VERSION"; return 0 ;;
        update)      main::self_update "$@";                   return $? ;;
        backup-list) main::backup_list "$CPYX_BACKUP_ROOT";    return 0 ;;
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
