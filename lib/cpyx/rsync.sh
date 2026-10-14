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
# CPYX_ELAPSED. La salida se muestra en pantalla y, si hay log, también se guarda.
rsync::run() {
    local start=$SECONDS

    set +e
    if (( CPYX_NO_LOG )); then
        rsync "${CPYX_RSYNC_ARGS[@]}" -- "$CPYX_SRC" "$CPYX_DST"
        CPYX_STATUS=$?
    else
        rsync "${CPYX_RSYNC_ARGS[@]}" -- "$CPYX_SRC" "$CPYX_DST" 2>&1 | tee -- "$CPYX_LOG_FILE"
        CPYX_STATUS=${PIPESTATUS[0]}
    fi
    set -e

    CPYX_ELAPSED=$(( SECONDS - start ))
}
