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

    if (( CPYX_RESTORE_MODE )); then
        if (( CPYX_RSYNC_MODERN )); then
            CPYX_RSYNC_ARGS+=(--info=progress2,stats2 "--out-format=%t  %i  %n%L")
        else
            CPYX_RSYNC_ARGS+=(--progress --stats)
        fi
        if (( CPYX_DRY_RUN )); then CPYX_RSYNC_ARGS+=(--dry-run); fi
        [[ -n $CPYX_BWLIMIT ]] && CPYX_RSYNC_ARGS+=(--bwlimit="$CPYX_BWLIMIT")
        local pat
        for pat in ${CPYX_EXCLUDES[@]+"${CPYX_EXCLUDES[@]}"}; do
            CPYX_RSYNC_ARGS+=("--exclude=$pat")
        done
        return
    fi

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
        [[ -n $CPYX_BWLIMIT ]] && CPYX_RSYNC_ARGS+=(--bwlimit="$CPYX_BWLIMIT")
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
    [[ -n $CPYX_BWLIMIT ]] && CPYX_RSYNC_ARGS+=(--bwlimit="$CPYX_BWLIMIT")

    local pat
    for pat in ${CPYX_EXCLUDES[@]+"${CPYX_EXCLUDES[@]}"}; do
        CPYX_RSYNC_ARGS+=("--exclude=$pat")
    done
}

rsync::backup_prune() {
    (( CPYX_BACKUP_MODE && CPYX_STATUS == 0 && ! CPYX_DRY_RUN )) || return 0
    local root=$CPYX_BACKUP_ROOT
    local -a snaps=()
    mapfile -t snaps < <(core::backup_list "$root")
    local count=${#snaps[@]}
    (( count == 0 )) && return 0

    local -a to_keep=()
    local -A keep_map=()

    if (( CPYX_BACKUP_KEEP_DAILY || CPYX_BACKUP_KEEP_WEEKLY || CPYX_BACKUP_KEEP_MONTHLY )); then
        local s date_part ymd ym ywd seen_daily seen_weekly seen_monthly
        local daily=0 weekly=0 monthly=0

        for (( i=count-1; i>=0; i-- )); do
            s="${snaps[$i]}"
            date_part="${s%%_*}"
            [[ -z $date_part ]] && continue
            ymd="$date_part"
            ym="${date_part:0:7}"
            ywd="$(date -d "${date_part//_/ }" +%G-%V 2>/dev/null || echo "")"

            if (( CPYX_BACKUP_KEEP_DAILY > 0 && daily < CPYX_BACKUP_KEEP_DAILY )); then
                if [[ -z ${seen_daily[$ymd]+x} ]]; then
                    seen_daily[$ymd]=1
                    keep_map["$s"]=1
                    to_keep+=("$s")
                    ((daily++))
                    continue
                fi
            fi

            if (( CPYX_BACKUP_KEEP_WEEKLY > 0 && weekly < CPYX_BACKUP_KEEP_WEEKLY )); then
                if [[ -n $ywd && -z ${seen_weekly[$ywd]+x} ]]; then
                    seen_weekly[$ywd]=1
                    if [[ -z ${keep_map[$s]+x} ]]; then
                        keep_map["$s"]=1
                        to_keep+=("$s")
                    fi
                    ((weekly++))
                    continue
                fi
            fi

            if (( CPYX_BACKUP_KEEP_MONTHLY > 0 && monthly < CPYX_BACKUP_KEEP_MONTHLY )); then
                if [[ -z ${seen_monthly[$ym]+x} ]]; then
                    seen_monthly[$ym]=1
                    if [[ -z ${keep_map[$s]+x} ]]; then
                        keep_map["$s"]=1
                        to_keep+=("$s")
                    fi
                    ((monthly++))
                    continue
                fi
            fi
        done

        # Siempre conservar latest
        local latest_base
        latest_base=$(basename "$(readlink -f "$CPYX_BACKUP_LATEST" 2>/dev/null)" 2>/dev/null)
        [[ -n $latest_base ]] && keep_map["$latest_base"]=1

        local -a to_delete_list=()
        for s in "${snaps[@]}"; do
            [[ -n ${keep_map[$s]+x} ]] && continue
            to_delete_list+=("$s")
        done

        (( ${#to_delete_list[@]} == 0 )) && return 0

        ui::note "Rotación por política: conservando ${#keep_map[@]} snapshot(s), borrando ${#to_delete_list[@]}"
        local freed=0 sz
        for s in "${to_delete_list[@]}"; do
            local snap_path="$root/$s"
            [[ -z $snap_path ]] && continue
            [[ -n $latest_base && $s == "$latest_base" ]] && continue
            sz=$(du -sb "$snap_path" 2>/dev/null | awk '{print $1}')
            [[ -n $sz ]] && freed=$(( freed + sz ))
            ui::warn "Eliminando snapshot antiguo: $s"
            rm -rf -- "$snap_path"
        done

        if (( freed > 0 )); then
            local freed_h
            if (( freed >= 1073741824 )); then freed_h="$(awk "BEGIN {printf \"%.1f\", $freed/1073741824}") GB"
            elif (( freed >= 1048576 )); then freed_h="$(awk "BEGIN {printf \"%.1f\", $freed/1048576}") MB"
            elif (( freed >= 1024 )); then freed_h="$(awk "BEGIN {printf \"%.1f\", $freed/1024}") KB"
            else freed_h="${freed} B"; fi
            ui::note "Espacio liberado: $freed_h"
        fi
        return
    fi

    # Modo simple --keep
    (( CPYX_BACKUP_KEEP == 0 )) && return 0
    local keep=$CPYX_BACKUP_KEEP
    (( count <= keep )) && return 0
    local to_delete=$(( count - keep ))
    ui::note "Rotación: borrando $to_delete snapshot(s) antiguo(s), conservando $keep"
    local freed=0 sz
    local i latest_base
    latest_base=$(basename "$(readlink -f "$CPYX_BACKUP_LATEST" 2>/dev/null)" 2>/dev/null)
    for (( i=0; i<to_delete; i++ )); do
        local snap="$root/${snaps[$i]}"
        [[ -z $snap ]] && continue
        [[ -n $latest_base && "${snaps[$i]}" == "$latest_base" ]] && continue
        sz=$(du -sb "$snap" 2>/dev/null | awk '{print $1}')
        [[ -n $sz ]] && freed=$(( freed + sz ))
        ui::warn "Eliminando snapshot antiguo: ${snaps[$i]}"
        rm -rf -- "$snap"
    done

    if (( freed > 0 )); then
        local freed_h
        if (( freed >= 1073741824 )); then freed_h="$(awk "BEGIN {printf \"%.1f\", $freed/1073741824}") GB"
        elif (( freed >= 1048576 )); then freed_h="$(awk "BEGIN {printf \"%.1f\", $freed/1048576}") MB"
        elif (( freed >= 1024 )); then freed_h="$(awk "BEGIN {printf \"%.1f\", $freed/1024}") KB"
        else freed_h="${freed} B"; fi
        ui::note "Espacio liberado: $freed_h"
    fi
}

rsync::backup_stats() {
    (( CPYX_BACKUP_MODE && CPYX_STATUS == 0 && ! CPYX_DRY_RUN )) || return 0
    command -v du >/dev/null 2>&1 || return 0
    local snap=$CPYX_BACKUP_SNAPSHOT
    [[ -d $snap ]] || return 0
    local apparent real saved saved_pct
    apparent=$(du -sh --apparent-size "$snap" 2>/dev/null | awk '{print $1}')
    real=$(du -sh "$snap" 2>/dev/null | awk '{print $1}')
    [[ -z $apparent || -z $real ]] && return 0
    # Cálculo aproximado en bytes para porcentaje
    local a b
    a=$(du -sb --apparent-size "$snap" 2>/dev/null | awk '{print $1}')
    b=$(du -sb "$snap" 2>/dev/null | awk '{print $1}')
    if [[ -n $a && -n $b && $a -gt 0 ]]; then
        saved=$(( a - b ))
        saved_pct=$(( saved * 100 / a ))
        local saved_h
        if (( saved >= 1073741824 )); then saved_h="$(awk "BEGIN {printf \"%.1f\", $saved/1073741824}") GB"
        elif (( saved >= 1048576 )); then saved_h="$(awk "BEGIN {printf \"%.1f\", $saved/1048576}") MB"
        elif (( saved >= 1024 )); then saved_h="$(awk "BEGIN {printf \"%.1f\", $saved/1024}") KB"
        else saved_h="${saved} B"; fi
        ui::note "Tamaño aparente: $apparent | En disco: $real | Ahorrado con hardlinks: $saved_h ($saved_pct%)"
    else
        ui::note "Tamaño aparente: $apparent | En disco: $real"
    fi
}

rsync::backup_finalize() {
    (( CPYX_BACKUP_MODE && CPYX_STATUS == 0 && ! CPYX_DRY_RUN )) || return 0
    # Actualizar symlink latest de forma atómica
    local tmp_link
    tmp_link=$(mktemp -u "$CPYX_BACKUP_ROOT/.latest.XXXXXX")
    ln -sfn "$(basename "$CPYX_BACKUP_SNAPSHOT")" "$tmp_link"
    mv -f "$tmp_link" "$CPYX_BACKUP_LATEST"
    ui::note "latest -> $(basename "$CPYX_BACKUP_SNAPSHOT")"
    rsync::backup_stats
}

# Ejecuta rsync. Deja el código de salida en CPYX_STATUS y la duración en
#   CPYX_ELAPSED. Con tty y colores dibuja la barra de progreso en stderr y
#   guarda listado/errores en el log; si no, usa la salida básica de rsync.
rsync::run() {
    local start=$SECONDS
    local status=0

    if (( CPYX_RESTORE_MODE )); then
        [[ -e $CPYX_SRC ]] || ui::die "$EX_NOINPUT" "Snapshot/origen de restauración no existe: $CPYX_SRC"
        if [[ ! -d $CPYX_DST ]]; then
            if (( CPYX_DRY_RUN )); then
                ui::warn "El destino no existe y se crearía: $CPYX_DST"
            else
                ui::note "Creando destino: $CPYX_DST"
                mkdir -p -- "$CPYX_DST" || ui::die "$EX_CANTCREAT" "No se pudo crear el destino: $CPYX_DST"
            fi
        fi
        if (( ! CPYX_DRY_RUN && ! CPYX_ASSUME_YES && -t 0 )); then
            ui::warn "Restaurando desde snapshot (puede sobrescribir archivos en destino)."
            ui::confirm "¿Continuar?" || { ui::note "Cancelado."; exit 1; }
        fi
    fi

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
