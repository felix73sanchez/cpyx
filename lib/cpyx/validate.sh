# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Felix Sanchez <felixsanchez73@outlook.com>

# shellcheck shell=bash
# =============================================================================
# validate.sh - comprobaciones previas: dependencias, rutas, confirmaciones
# =============================================================================

# Detecta el gestor de paquetes e instala dependencias faltantes (rsync, bash, pv)
validate::install_missing() {
    local faltan=()
    command -v rsync >/dev/null 2>&1 || faltan+=(rsync)
    command -v bash  >/dev/null 2>&1 || faltan+=(bash)
    command -v pv    >/dev/null 2>&1 || faltan+=(pv)

    if (( ${#faltan[@]} == 0 )); then
        return 0
    fi

    local SUDO=""
    if [ "$(id -u)" -ne 0 ]; then
        command -v sudo >/dev/null 2>&1 && SUDO="sudo"
        command -v doas >/dev/null 2>&1 && SUDO="doas"
    fi

    ui::note "Instalando dependencias: ${faltan[*]}"
    if command -v apt-get >/dev/null 2>&1; then
        $SUDO apt-get update -qq && $SUDO apt-get install -y "${faltan[@]}"
    elif command -v dnf >/dev/null 2>&1; then
        $SUDO dnf install -y "${faltan[@]}"
    elif command -v yum >/dev/null 2>&1; then
        $SUDO yum install -y "${faltan[@]}"
    elif command -v pacman >/dev/null 2>&1; then
        $SUDO pacman -S --needed --noconfirm "${faltan[@]}"
    elif command -v zypper >/dev/null 2>&1; then
        $SUDO zypper --non-interactive install "${faltan[@]}"
    elif command -v apk >/dev/null 2>&1; then
        $SUDO apk add "${faltan[@]}"
    elif command -v xbps-install >/dev/null 2>&1; then
        $SUDO xbps-install -Sy "${faltan[@]}"
    elif command -v emerge >/dev/null 2>&1; then
        $SUDO emerge --noreplace "${faltan[@]}"
    elif command -v nix-env >/dev/null 2>&1; then
        nix-env -iA nixpkgs.rsync nixpkgs.bash
    else
        ui::die "$EX_UNAVAILABLE" \
            "Gestor de paquetes no detectado. Instala manualmente: ${faltan[*]}"
    fi

    # Verificar que se instalaron correctamente
    local aun_faltan=()
    for dep in "${faltan[@]}"; do
        command -v "$dep" >/dev/null 2>&1 || aun_faltan+=("$dep")
    done
    if (( ${#aun_faltan[@]} > 0 )); then
        ui::die "$EX_UNAVAILABLE" \
            "No se pudieron instalar: ${aun_faltan[*]}. Instálalos manualmente."
    fi
    ui::note "Dependencias instaladas: ${faltan[*]}"
}

# Verifica que rsync exista y detecta si soporta la barra de progreso global
validate::require_rsync() {
    validate::install_missing

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

# Detecta pv de forma opcional. Si no está, la barra usa el progreso de rsync.
validate::require_pv() {
    CPYX_HAS_PV=0
    command -v pv >/dev/null 2>&1 && CPYX_HAS_PV=1
    return 0
}

validate::disk_space() {
    (( CPYX_DRY_RUN )) && return 0
    local src=$CPYX_SRC
    local dst=$CPYX_DST
    (( CPYX_BACKUP_MODE )) && dst=$CPYX_BACKUP_ROOT
    [[ -d $dst ]] || return 0
    command -v df >/dev/null 2>&1 || return 0
    command -v du >/dev/null 2>&1 || return 0
    local avail
    avail=$(df -P "$dst" 2>/dev/null | awk 'NR==2 {print $4}')
    [[ -z $avail ]] && return 0
    # Tamaño estimado del origen (no incluye hardlinks, solo advertencia)
    local needed_kb=0
    if [[ -d $src ]]; then
        needed_kb=$(du -sk "$src" 2>/dev/null | awk '{print $1}')
    elif [[ -f $src ]]; then
        needed_kb=$(( $(stat -c%s "$src" 2>/dev/null || echo 0) / 1024 ))
    fi
    (( needed_kb == 0 )) && return 0
    if (( needed_kb > avail )); then
        ui::warn "Espacio libre insuficiente en $(df -hP "$dst" | awk 'NR==2 {print $6}'): disponible ~$(df -hP "$dst" | awk 'NR==2 {print $4}'), necesario ~$(du -sh "$src" 2>/dev/null | awk '{print $1}')"
        if [[ -t 0 ]] && (( ! CPYX_ASSUME_YES )); then
            if ! ui::confirm "¿Continuar igualmente?"; then
                ui::note "Cancelado."
                exit 1
            fi
        fi
    fi
}

validate::acquire_lock() {
    local lock_root
    if (( CPYX_BACKUP_MODE )); then
        lock_root=$CPYX_BACKUP_ROOT
    else
        lock_root=$(dirname "$CPYX_DST")
    fi
    [[ -d $lock_root ]] || mkdir -p "$lock_root" 2>/dev/null || return 0
    local lockfile="$lock_root/.cpyx.lock"
    CPYX_TMPFILES+=("$lockfile")
    if (set -C; echo $$ > "$lockfile") 2>/dev/null; then
        return 0
    fi
    local pid
    pid=$(cat "$lockfile" 2>/dev/null)
    ui::die "$EX_USAGE" "Ya hay una instancia de cpyx en ejecución (PID $pid). Usa $lockfile para liberarlo si está colgado."
}

# Comprueba origen y destino; crea el destino local si hace falta
validate::paths() {
    local src_remote=0 dst_remote=0
    if core::is_remote "$CPYX_SRC"; then src_remote=1; fi
    if core::is_remote "$CPYX_DST"; then dst_remote=1; fi

    if (( CPYX_BACKUP_MODE )); then
        if (( src_remote || dst_remote )); then
            ui::die "$EX_USAGE" "El modo backup (--backup) solo soporta rutas locales por ahora"
        fi
        if [[ ! -d $CPYX_SRC ]]; then
            ui::die "$EX_NOINPUT" "El origen debe ser un directorio en modo backup: $CPYX_SRC"
        fi
        CPYX_BACKUP_ROOT=$CPYX_DST
        CPYX_BACKUP_LATEST="$CPYX_DST/latest"
        CPYX_BACKUP_SNAPSHOT="$CPYX_DST/$(core::backup_timestamp)"
        return
    fi

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
