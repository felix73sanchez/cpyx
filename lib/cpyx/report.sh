# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Felix Sanchez <felixsanchez73@outlook.com>

# shellcheck shell=bash
# =============================================================================
# report.sh - resumen previo y resultado final
# =============================================================================

# report::fmt_duration SEGUNDOS -> HH:MM:SS
report::fmt_duration() {
    printf '%02d:%02d:%02d' $(( $1 / 3600 )) $(( ($1 % 3600) / 60 )) $(( $1 % 60 ))
}

report::header() {
    ui::banner "CPYX $CPYX_VERSION - fsxsystem"

    if (( CPYX_BACKUP_MODE )); then
        ui::kv "Modo"     "${C_CYAN}BACKUP INCREMENTAL${C_RESET}"
        ui::kv "Origen"   "$CPYX_SRC"
        ui::kv "Raíz"     "$CPYX_BACKUP_ROOT"
        if (( CPYX_DRY_RUN )); then
            ui::kv "Snapshot" "(simulación, no se crea)"
        else
            ui::kv "Snapshot" "$CPYX_BACKUP_SNAPSHOT"
        fi
        if [[ -L $CPYX_BACKUP_LATEST ]]; then
            ui::kv "latest"   "$(readlink -f "$CPYX_BACKUP_LATEST")"
        elif [[ -d $CPYX_BACKUP_LATEST ]]; then
            ui::kv "latest"   "$CPYX_BACKUP_LATEST"
        else
            ui::kv "latest"   "(ninguno - copia completa)"
        fi
        if (( CPYX_BACKUP_KEEP )); then
            ui::kv "Rotación" "conservar últimos $CPYX_BACKUP_KEEP"
        fi
    elif (( CPYX_RESTORE_MODE )); then
        ui::kv "Modo"     "${C_GREEN}RESTAURAR DESDE SNAPSHOT${C_RESET}"
        ui::kv "Origen"   "$CPYX_SRC"
        ui::kv "Destino"  "$CPYX_DST"
    else
        ui::kv "Origen"  "$CPYX_SRC"
        ui::kv "Destino" "$CPYX_DST"
    fi
    ui::kv "Inicio"  "$(date '+%Y-%m-%d %H:%M:%S')"

    if (( CPYX_NO_LOG )); then
        ui::kv "Log" "desactivado"
    else
        ui::kv "Log" "$CPYX_LOG_FILE"
    fi

    if (( ! CPYX_BACKUP_MODE && ! CPYX_RESTORE_MODE )); then
        if (( CPYX_DRY_RUN )); then
            ui::kv "Modo" "${C_YELLOW}SIMULACIÓN (no se copia nada)${C_RESET}"
        fi
        if (( CPYX_DELETE )); then
            ui::kv "Modo" "${C_RED}--delete activo (se borra en destino lo que no esté en origen)${C_RESET}"
        fi
    fi
    if (( CPYX_RESTORE_MODE && CPYX_DRY_RUN )); then
        ui::kv "Modo" "${C_YELLOW}SIMULACIÓN (no se copia nada)${C_RESET}"
    fi
    if (( ${#CPYX_EXCLUDES[@]} )); then
        ui::kv "Excluye" "$(IFS=,; printf '%s' "${CPYX_EXCLUDES[*]}")"
    fi
    [[ -n $CPYX_BWLIMIT ]] && ui::kv "Velocidad" "limitada a $CPYX_BWLIMIT"
    if (( ! CPYX_RSYNC_MODERN )); then
        ui::warn "rsync ${CPYX_RSYNC_VERSION:-desconocido} es antiguo: progreso por archivo en vez de global."
    fi

    ui::rule
    ui::blank
}

report::footer() {
    ui::blank
    ui::banner "RESULTADO"
    if (( CPYX_STATUS == 0 )); then
        ui::info "${C_GREEN}Completado correctamente.${C_RESET}"
    else
        ui::info "${C_RED}rsync terminó con código de error: ${CPYX_STATUS}${C_RESET}"
    fi
    ui::kv "Duración" "$(report::fmt_duration "$CPYX_ELAPSED")"
    if (( ! CPYX_NO_LOG )); then
        ui::kv "Log" "$CPYX_LOG_FILE"
    fi
    ui::rule
}
