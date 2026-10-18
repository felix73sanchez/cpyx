# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Felix Sanchez <felixsanchez73@outlook.com>

# shellcheck shell=bash
# =============================================================================
# core.sh - constantes, códigos de salida, configuración por defecto
# =============================================================================

readonly CPYX_NAME="cpyx"
readonly CPYX_VERSION="1.1.4"

# Códigos de salida (convención sysexits.h)
readonly EX_USAGE=64        # uso incorrecto de la línea de comandos
readonly EX_NOINPUT=66      # el origen no existe
readonly EX_UNAVAILABLE=69  # falta una dependencia (rsync)
readonly EX_CANTCREAT=73    # no se pudo crear el destino
readonly EX_INTERRUPT=130   # interrumpido con Ctrl+C

# Cantidad de logs que se conservan en el directorio por defecto
CPYX_KEEP_LOGS="${CPYX_KEEP_LOGS:-30}"

# Barra de progreso visual (1 = activada, 0 = desactivada)
CPYX_PROGRESS="${CPYX_PROGRESS:-1}"

# Restablece toda la configuración de ejecución a sus valores por defecto
core::reset_config() {
    CPYX_ACTION="run"          # run | help | version
    CPYX_SRC=""
    CPYX_DST=""
    CPYX_DRY_RUN=0
    CPYX_DELETE=0
    CPYX_ASSUME_YES=0
    CPYX_NO_LOG=0
    CPYX_LOG_FILE=""
    CPYX_EXCLUDES=()
    CPYX_RSYNC_VERSION=""
    CPYX_RSYNC_MODERN=0
    CPYX_RSYNC_ARGS=()
    CPYX_STATUS=0
    CPYX_ELAPSED=0
    CPYX_HAS_PV=0            # pv opcional instalado
    CPYX_TOTAL_BYTES=0       # tamaño total de la copia (origen local)
    CPYX_TOTAL_FILES=0       # nº de archivos de la copia (origen local)
    CPYX_TMPFILES=()         # temporales a borrar al salir
}

# ¿Es una ruta remota (host:ruta)? Igual que rsync: hay ":" antes de cualquier "/"
core::is_remote() {
    [[ $1 =~ ^[^/]+: ]]
}
