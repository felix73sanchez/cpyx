# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Felix Sanchez <felixsanchez73@outlook.com>

# shellcheck shell=bash
# =============================================================================
# validate.sh - comprobaciones previas: dependencias, rutas, confirmaciones
# =============================================================================

# Verifica que rsync exista y detecta si soporta la barra de progreso global
validate::require_rsync() {
    if ! command -v rsync >/dev/null 2>&1; then
        ui::die "$EX_UNAVAILABLE" \
            "rsync no está instalado. Ejecuta install.sh o instálalo con tu gestor de paquetes."
    fi

    local first
    first="$(rsync --version 2>/dev/null | head -n1)" || true
    CPYX_RSYNC_VERSION="$(printf '%s' "$first" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)"

    # --info=progress2 (progreso global) requiere rsync >= 3.1.0
    CPYX_RSYNC_MODERN=0
    if [[ -n $CPYX_RSYNC_VERSION ]]; then
        local major minor rest
        major=${CPYX_RSYNC_VERSION%%.*}
        rest=${CPYX_RSYNC_VERSION#*.}
        minor=${rest%%.*}
        if (( major > 3 || (major == 3 && minor >= 1) )); then
            CPYX_RSYNC_MODERN=1
        fi
    fi
}

# Comprueba origen y destino; crea el destino local si hace falta
validate::paths() {
    local src_remote=0 dst_remote=0
    if core::is_remote "$CPYX_SRC"; then src_remote=1; fi
    if core::is_remote "$CPYX_DST"; then dst_remote=1; fi

    if (( ! src_remote )) && [[ ! -e $CPYX_SRC ]]; then
        ui::die "$EX_NOINPUT" "El origen no existe: $CPYX_SRC"
    fi

    # Origen y destino locales que apuntan al mismo lugar
    if (( ! src_remote && ! dst_remote )) && [[ -d $CPYX_DST ]] \
        && command -v realpath >/dev/null 2>&1; then
        if [[ "$(realpath -- "$CPYX_SRC")" == "$(realpath -- "$CPYX_DST")" ]]; then
            ui::die "$EX_USAGE" "El origen y el destino son la misma ruta: $CPYX_SRC"
        fi
    fi

    if (( ! dst_remote )) && [[ ! -d $CPYX_DST ]]; then
        if (( CPYX_DRY_RUN )); then
            ui::warn "El destino no existe y se crearía: $CPYX_DST"
        else
            ui::note "El destino no existe, creándolo: $CPYX_DST"
            if ! mkdir -p -- "$CPYX_DST" 2>/dev/null; then
                ui::die "$EX_CANTCREAT" "No se pudo crear el destino: $CPYX_DST"
            fi
        fi
    fi
}

# --delete es destructivo: exige confirmación salvo simulación o --yes
validate::confirm_delete() {
    if (( ! CPYX_DELETE || CPYX_DRY_RUN || CPYX_ASSUME_YES )); then
        return 0
    fi

    if [[ -t 0 ]]; then
        ui::warn "--delete borrará en el destino todo lo que no exista en el origen."
        if ! ui::confirm "¿Continuar?"; then
            ui::note "Cancelado."
            exit 1
        fi
    else
        ui::die "$EX_USAGE" "--delete requiere confirmación; sin terminal usa -y/--yes."
    fi
}
