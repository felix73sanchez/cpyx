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

# Ejecuta rsync. Deja el código de salida en CPYX_STATUS y la duración en
#   CPYX_ELAPSED. Con tty y colores dibuja la barra de progreso en stderr y
#   guarda listado/errores en el log; si no, usa la salida básica de rsync.
rsync::run() {
    local start=$SECONDS
    local status=0

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
}
