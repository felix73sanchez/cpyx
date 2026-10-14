# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Felix Sanchez <felixsanchez73@outlook.com>

# shellcheck shell=bash
# =============================================================================
# ui.sh - colores y mensajes en pantalla
# =============================================================================

# Inicializa los colores. Respeta NO_COLOR y desactiva si no hay terminal.
ui::init() {
    C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""
    E_RESET=""; E_RED=""; E_YELLOW=""

    if [[ -z ${NO_COLOR:-} && ${TERM:-} != dumb ]]; then
        if [[ -t 1 ]]; then
            C_RESET=$'\e[0m';  C_BOLD=$'\e[1m'
            C_RED=$'\e[31m';   C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'
            C_BLUE=$'\e[34m';  C_CYAN=$'\e[36m'
        fi
        if [[ -t 2 ]]; then
            E_RESET=$'\e[0m'; E_RED=$'\e[31m'; E_YELLOW=$'\e[33m'
        fi
    fi
}

ui::info()  { printf '%s\n' "$*"; }
ui::blank() { printf '\n'; }
ui::note()  { printf '%s->%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
ui::warn()  { printf '%sAviso:%s %s\n' "$E_YELLOW" "$E_RESET" "$*" >&2; }
ui::error() { printf '%sError:%s %s\n' "$E_RED" "$E_RESET" "$*" >&2; }

# ui::die CODIGO MENSAJE... - muestra el error y termina
ui::die() {
    local code=$1; shift
    ui::error "$*"
    exit "$code"
}

ui::banner() {
    printf '%s%s==================== %s ====================%s\n' \
        "$C_BOLD" "$C_BLUE" "$1" "$C_RESET"
}

ui::rule() {
    printf '%s%s======================================================%s\n' \
        "$C_BOLD" "$C_BLUE" "$C_RESET"
}

# ui::kv ETIQUETA VALOR - línea "Etiqueta: valor" alineada
ui::kv() {
    printf '%s%-8s:%s %s\n' "$C_CYAN" "$1" "$C_RESET" "$2"
}

# ui::confirm PREGUNTA - devuelve 0 si el usuario responde s/y
ui::confirm() {
    local reply
    read -r -p "$1 [s/N] " reply || return 1
    [[ $reply =~ ^[sSyY]$ ]]
}
