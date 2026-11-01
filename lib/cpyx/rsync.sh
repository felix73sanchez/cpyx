# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Felix Sanchez <felixsanchez73@outlook.com>

# shellcheck shell=bash
# =============================================================================
# rsync.sh - construcción de argumentos y ejecución de rsync
# =============================================================================

# Construye CPYX_RSYNC_ARGS a partir de la configuración
#   -a        modo archivo (recursivo, permisos, fechas, enlaces, owner, grupo)
#   -h        tamaños legibles
#   -v -i     lista cada archivo y qué cambió en él
#   --partial conserva archivos parciales si se interrumpe (reanudable)
rsync::build_args() {
    CPYX_RSYNC_ARGS=(-ahvi --partial)

    if (( CPYX_BACKUP_MODE )); then
        # En modo backup siempre reflejamos el estado exacto del origen
        CPYX_DELETE=1
        if (( CPYX_RSYNC_MODERN )); then
            CPYX_RSYNC_ARGS+=(--info=progress2,stats2 "--out-format=%t  %i  %n%L")
        else
            CPYX_RSYNC_ARGS+=(--progress --stats)
        fi
        if (( CPYX_DRY_RUN )); then CPYX_RSYNC_ARGS+=(--dry-run); fi
        CPYX_RSYNC_ARGS+=(--delete)
        # Buscar snapshot previo vía symlink latest/
        if [[ -L $CPYX_BACKUP_LATEST || -d $CPYX_BACKUP_LATEST ]]; then
            local link_target latest_real snap_real
            link_target=$(readlink -f "$CPYX_BACKUP_LATEST" 2>/dev/null || true)
            if [[ -n $link_target && -d $link_target ]]; then
                latest_real=$(readlink -f "$link_target" 2>/dev/null || echo "$link_target")
                snap_real=$(readlink -f "$CPYX_BACKUP_SNAPSHOT" 2>/dev/null || echo "$CPYX_BACKUP_SNAPSHOT")
                local latest_dev snap_dev
                latest_dev=$(stat -c %d "$link_target" 2>/dev/null || echo x)
                snap_dev=$(stat -c %d "$CPYX_BACKUP_ROOT" 2>/dev/null || echo y)
                if [[ $latest_dev == "$snap_dev" ]]; then
                    CPYX_RSYNC_ARGS+=(--link-dest="$link_target")
                    ui::note "Usando hardlinks desde: $(basename "$link_target")"
                else
                    ui::warn "latest está en otro filesystem. Se hará copia completa (sin hardlinks)."
                fi
            fi
        fi
        local pat
        for pat in ${CPYX_EXCLUDES[@]+"${CPYX_EXCLUDES[@]}"}; do
            CPYX_RSYNC_ARGS+=("--exclude=$pat")
        done
        return
    fi

    if (( CPYX_RSYNC_MODERN )); then
        CPYX_RSYNC_ARGS+=(--info=progress2,stats2 "--out-format=%t  %i  %n%L")
    else
        CPYX_RSYNC_ARGS+=(--progress --stats)
    fi

    if (( CPYX_DRY_RUN )); then CPYX_RSYNC_ARGS+=(--dry-run); fi
    if (( CPYX_DELETE ));  then CPYX_RSYNC_ARGS+=(--delete);  fi

    local pat
    for pat in ${CPYX_EXCLUDES[@]+"${CPYX_EXCLUDES[@]}"}; do
        CPYX_RSYNC_ARGS+=("--exclude=$pat")
    done
}

rsync::backup_prune() {
    (( CPYX_BACKUP_MODE && CPYX_BACKUP_KEEP > 0 && CPYX_STATUS == 0 && ! CPYX_DRY_RUN )) || return 0
    local root=$CPYX_BACKUP_ROOT
    local keep=$CPYX_BACKUP_KEEP
    local -a snaps=()
    mapfile -t snaps < <(core::backup_list "$root")
    local count=${#snaps[@]}
    (( count <= keep )) && return 0
    local to_delete=$(( count - keep ))
    local i
    ui::note "Rotación: borrando $to_delete snapshot(s) antiguo(s), conservando $keep"
    for (( i=0; i<to_delete; i++ )); do
        local snap="$root/${snaps[$i]}"
        [[ -z $snap ]] && continue
        [[ "$snap" == "$(readlink -f "$CPYX_BACKUP_LATEST" 2>/dev/null)" ]] && continue
        ui::warn "Eliminando snapshot antiguo: ${snaps[$i]}"
        rm -rf -- "$snap"
    done
}

rsync::backup_finalize() {
    (( CPYX_BACKUP_MODE && CPYX_STATUS == 0 && ! CPYX_DRY_RUN )) || return 0
    # Actualizar symlink latest de forma atómica
    local tmp_link
    tmp_link=$(mktemp -u "$CPYX_BACKUP_ROOT/.latest.XXXXXX")
    ln -sfn "$(basename "$CPYX_BACKUP_SNAPSHOT")" "$tmp_link"
    mv -f "$tmp_link" "$CPYX_BACKUP_LATEST"
    ui::note "latest -> $(basename "$CPYX_BACKUP_SNAPSHOT")"
}

# Ejecuta rsync. Deja el código de salida en CPYX_STATUS y la duración en
#   CPYX_ELAPSED. Con tty y colores dibuja la barra de progreso en stderr y
#   guarda listado/errores en el log; si no, usa la salida básica de rsync.
rsync::run() {
    local start=$SECONDS
    local status=0

    if (( CPYX_BACKUP_MODE )); then
        if (( CPYX_DRY_RUN )); then
            ui::warn "Modo backup en dry-run: no se crearán snapshots"
        else
            mkdir -p -- "$CPYX_BACKUP_SNAPSHOT" || ui::die "$EX_CANTCREAT" "No se pudo crear snapshot: $CPYX_BACKUP_SNAPSHOT"
            ui::note "Snapshot: $(basename "$CPYX_BACKUP_SNAPSHOT")"
        fi
        CPYX_DST=$CPYX_BACKUP_SNAPSHOT
    fi

    if progress::active && [[ -d $CPYX_SRC ]]; then
        progress::compute_totals "$CPYX_SRC"
    fi

    if progress::active; then
        local tmpdir outf errf rpid render_pid
        tmpdir="$(mktemp -d)"
        CPYX_TMPFILES+=("$tmpdir")
        outf="$tmpdir/out"
        errf="$tmpdir/err"
        progress::set_outfile "$outf"

        set +e
        rsync "${CPYX_RSYNC_ARGS[@]}" -- "$CPYX_SRC" "$CPYX_DST" \
            >"$outf" 2>"$errf" &
        rpid=$!
        progress::watch "$rpid" "$outf" &
        render_pid=$!
        wait "$rpid"; status=$?
        wait "$render_pid" 2>/dev/null
        set -e

        progress::finish
        if (( status != 0 )); then
            progress::render_error "$status" "$CPYX_SRC" "$CPYX_DST" "$errf"
        fi
        if (( ! CPYX_NO_LOG )); then
            progress::write_log "$outf" "$errf"
        fi
        progress::set_outfile ""
    else
        set +e
        if (( CPYX_NO_LOG )); then
            rsync "${CPYX_RSYNC_ARGS[@]}" -- "$CPYX_SRC" "$CPYX_DST"
            status=$?
        else
            rsync "${CPYX_RSYNC_ARGS[@]}" -- "$CPYX_SRC" "$CPYX_DST" 2>&1 | tee -- "$CPYX_LOG_FILE"
            status=${PIPESTATUS[0]}
        fi
        set -e
    fi

    CPYX_STATUS=$status
    CPYX_ELAPSED=$(( SECONDS - start ))

    rsync::backup_finalize
    rsync::backup_prune
}
