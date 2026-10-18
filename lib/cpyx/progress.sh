# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Felix Sanchez <felixsanchez73@outlook.com>

# shellcheck shell=bash
# =============================================================================
# progress.sh - barra de progreso visual y detalle por archivo
#   Funciones puras de formato (human_size, truncate, bar) y el dibujado en
#   vivo a partir de la salida de `rsync --info=progress2`.
#   La barra se escribe en stderr (el tty); el listado y los errores van al log.
# =============================================================================

# progress::human_size BYTES -> "12.3 MB" | "456 B"
progress::human_size() {
    local bytes=${1:-0}
    [[ $bytes =~ ^[0-9]+$ ]] || bytes=0
    if   (( bytes >= 1073741824 )); then
        awk -v b="$bytes" 'BEGIN {printf "%.1f GB", b/1073741824}'
    elif (( bytes >= 1048576 )); then
        awk -v b="$bytes" 'BEGIN {printf "%.1f MB", b/1048576}'
    elif (( bytes >= 1024 )); then
        awk -v b="$bytes" 'BEGIN {printf "%.1f KB", b/1024}'
    else
        printf '%s B' "$bytes"
    fi
}

# progress::truncate NOMBRE ANCHO -> nombre de como mucho ANCHO columnas
progress::truncate() {
    local name=${1:-} max=${2:-40}
    (( ${#name} > max )) && { printf '%s...' "${name:0:max-3}"; return 0; }
    printf '%-*s' "$max" "$name"
}

# progress::bar PORCENTAJE ANCHO -> "[████░░░░░░]"
progress::bar() {
    local pct=${1:-0} width=${2:-20}
    [[ $pct =~ ^[0-9]+$ ]] || pct=0
    (( pct > 100 )) && pct=100
    local filled empty i out="["
    filled=$(( pct * width / 100 ))
    empty=$(( width - filled ))
    for ((i = 0; i < filled; i++)); do out+="█"; done
    for ((i = 0; i < empty;  i++)); do out+="░"; done
    printf '%s]' "$out"
}

# progress::active - 1 si hay que dibujar la barra: tty en stderr, colores
#   disponibles y rsync moderno (--info=progress2). En caso contrario se usa la
#   salida básica de rsync.
progress::active() {
    (( CPYX_PROGRESS )) || return 1
    (( CPYX_RSYNC_MODERN )) || return 1
    [[ -t 2 ]] || return 1
    [[ -z ${NO_COLOR:-} ]] || return 1
    [[ ${TERM:-dumb} == dumb ]] && return 1
    return 0
}

# progress::compute_totals SRC - rellena CPYX_TOTAL_BYTES / CPYX_TOTAL_FILES
progress::compute_totals() {
    local src=${1:-}
    CPYX_TOTAL_BYTES=0
    CPYX_TOTAL_FILES=0
    [[ -d $src ]] || return 0
    if command -v du >/dev/null 2>&1; then
        CPYX_TOTAL_BYTES=$(du -sb -- "$src" 2>/dev/null | awk '{print $1}') || CPYX_TOTAL_BYTES=0
    fi
    if command -v find >/dev/null 2>&1; then
        CPYX_TOTAL_FILES=$(find -- "$src" -type f 2>/dev/null | wc -l) || CPYX_TOTAL_FILES=0
    fi
    [[ $CPYX_TOTAL_BYTES =~ ^[0-9]+$ ]] || CPYX_TOTAL_BYTES=0
    [[ $CPYX_TOTAL_FILES =~ ^[0-9]+$ ]] || CPYX_TOTAL_FILES=0
}

# progress::set_outfile ARCHIVO - fichero donde rsync escribe el listado
progress::set_outfile() { CPYX_PROGRESS_OUT=${1:-}; }

# Nombre del archivo que rsync está procesando ahora mismo (última línea -v)
progress::_current_file() {
    local f=${CPYX_PROGRESS_OUT:-}
    [[ -n $f && -f $f ]] || return 0
    local name
    # Localiza el código de itemize (<,>,c,h,*,.) y toma lo que le sigue,
    # sea con %t ("2026/10/18 13:01:04  >f+++  nombre") o sin él (">f+++  nombre")
    name=$(awk '{
        for (i = 1; i <= NF; i++) if ($i ~ /^[<>.ch*]/) {
            out = ""
            for (j = i + 1; j <= NF; j++) out = out $j " "
            sub(/ $/, "", out); print out; next
        }
    }' < "$f" 2>/dev/null | tail -n1) || true
    [[ -n $name ]] && printf '%s' "$name"
}

# progress::draw LINEA - parsea una línea de --info=progress2 y dibuja la barra
progress::draw() {
    local line=${1:-}
    local pct speed eta
    pct=$(printf '%s' "$line" | awk '{print $2}' | tr -d '%')
    speed=$(printf '%s' "$line" | awk '{print $3}')
    eta=$(printf '%s' "$line" | awk '{print $4}')
    [[ $pct =~ ^[0-9]+$ ]] || pct=0

    local icon="📄" color=$C_YELLOW
    (( pct >= 100 )) && { icon="✅"; color=$C_GREEN; }

    local out
    out="$(printf '\r%s%s%s %s %3d%%' "$color" "$icon" "$C_RESET" "$(progress::bar "$pct" 20)" "$pct")"

    if (( CPYX_TOTAL_BYTES > 0 )); then
        out+="  $(progress::human_size $(( CPYX_TOTAL_BYTES * pct / 100 )))"
        out+=" / $(progress::human_size "$CPYX_TOTAL_BYTES")"
    fi
    if [[ -n $speed && $speed != "-" ]]; then
        out+="  $speed"
    fi
    if [[ -n $eta && $eta != "-" && $eta != "0:00:00" ]]; then
        out+="  ETA $eta"
    fi

    local file
    file=$(progress::_current_file)
    [[ -n $file ]] && out+="  $(progress::truncate "$file" 30)"

    printf '%s' "$out" >&2
}

# progress::watch PID FICHERO - dibuja la barra mientras PID viva
progress::watch() {
    local pid=$1 file=$2 last="" cur
    while kill -0 "$pid" 2>/dev/null; do
        cur=$(tr '\r' '\n' < "$file" 2>/dev/null | grep -E '^[[:space:]]+[0-9]' | tail -n1) || true
        if [[ -n $cur && $cur != "$last" ]]; then
            progress::draw "$cur"
            last=$cur
        fi
        sleep 0.2
    done
    # La última actualización puede quedar sin dibujar al salir rsync
    cur=$(tr '\r' '\n' < "$file" 2>/dev/null | grep -E '^[[:space:]]+[0-9]' | tail -n1) || true
    [[ -n $cur ]] && progress::draw "$cur"
}

# progress::finish - termina la línea de la barra
progress::finish() { printf '\n' >&2; }

# progress::write_log FICHERO_SALIDA FICHERO_ERROR - guarda listado y errores
progress::write_log() {
    local outf=$1 errf=$2 log=${CPYX_LOG_FILE:-}
    [[ -n $log ]] || return 0
    # Listado y estadísticas, sin las líneas de progreso (éstas llevan sangrado)
    if [[ -s $outf ]]; then
        tr '\r' '\n' < "$outf" | grep -vE '^[[:space:]]+[0-9]' >>"$log" || true
    fi
    local err
    err=$(tr '\r' '\n' < "$errf" 2>/dev/null | grep -vE '^[[:space:]]*$' | tail -n 20) || true
    if [[ -n $err ]]; then
        { printf '\n--- errores de rsync ---\n'; printf '%s\n' "$err"; } >>"$log" || true
    fi
}

# progress::render_error STATUS SRC DST FICHERO_ERROR - error con causa probable
progress::render_error() {
    local status=$1 src=$2 dst=$3 errf=$4
    local detail
    detail=$(tr '\r' '\n' < "$errf" 2>/dev/null | grep -vE '^[[:space:]]*$' | tail -n 5) || true

    ui::error "rsync terminó con código de errores: $status"
    printf '%s  Origen :%s %s\n' "$E_RED" "$E_RESET" "$src" >&2
    printf '%s  Destino:%s %s\n' "$E_RED" "$E_RESET" "$dst" >&2
    if [[ -n $detail ]]; then
        printf '%s  Detalle:%s %s\n' "$E_RED" "$E_RESET" \
            "$(printf '%s' "$detail" | tr '\n' ' ')" >&2
    fi

    local cause=""
    if [[ -n $detail ]]; then
        if [[ $detail == *"No such file"* || $detail == *"no such file"* ]]; then
            cause="Una ruta no existe (¿se borró durante la copia?)."
        elif [[ $detail == *"Permission denied"* ]]; then
            cause="Permisos insuficientes en origen o destino."
        elif [[ $detail == *"read only"* || $detail == *"Read-only"* ]]; then
            cause="El destino es de sólo lectura."
        elif [[ $detail == *"No space left"* ]]; then
            cause="Sin espacio en el destino."
        fi
    fi
    if [[ -z $cause ]]; then
        if [[ -n $src && -e $src && ! -r $src ]]; then
            cause="Sin permisos de lectura en el origen."
        elif [[ -d $dst && ! -w $dst ]]; then
            cause="Sin permisos de escritura en el destino."
        fi
    fi
    [[ -n $cause ]] && printf '%s  Causa  :%s %s\n' "$E_RED" "$E_RESET" "$cause" >&2
}
