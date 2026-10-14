# shellcheck shell=bash
# =============================================================================
# main.sh - orquestación del flujo completo
# =============================================================================

main::on_interrupt() {
    ui::blank
    ui::warn "Interrumpido. Los archivos parciales se conservan: vuelve a ejecutar para reanudar."
    exit "$EX_INTERRUPT"
}

main() {
    trap main::on_interrupt INT TERM

    ui::init
    core::reset_config
    args::parse "$@"

    case $CPYX_ACTION in
        help)    args::usage;                              return 0 ;;
        version) printf '%s %s\n' "$CPYX_NAME" "$CPYX_VERSION"; return 0 ;;
    esac

    validate::require_rsync
    validate::paths
    validate::confirm_delete
    log::init

    report::header
    rsync::build_args
    rsync::run
    report::footer

    return "$CPYX_STATUS"
}
