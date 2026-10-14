#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Felix Sanchez <felixsanchez73@outlook.com>

# =============================================================================
# Pruebas de cpyx (sin dependencias externas). Uso: bash tests/run.sh
# =============================================================================

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CPYX="$ROOT/bin/cpyx"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

export XDG_STATE_HOME="$WORK/state"
export NO_COLOR=1

PASS=0
FAIL=0
OUT=""
RC=0

# run CMD... -> deja la salida en OUT y el código en RC (sin terminal en stdin)
run() { OUT="$("$@" 2>&1 </dev/null)"; RC=$?; }

check() {
    local desc=$1; shift
    if "$@"; then
        PASS=$((PASS + 1)); printf '  ok   %s\n' "$desc"
    else
        FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$desc"
        printf '       rc=%s salida: %s\n' "$RC" "$OUT"
    fi
}

rc_is() { [[ $RC -eq $1 ]]; }
has()   { [[ $OUT == *"$1"* ]]; }

fresh() {
    rm -rf "$WORK/src" "$WORK/dst" "$WORK/state"
    mkdir -p "$WORK/src/sub"
    echo uno > "$WORK/src/a.txt"
    echo dos > "$WORK/src/sub/b.txt"
    echo tmp > "$WORK/src/x.tmp"
}

echo "== Opciones básicas"
run "$CPYX" --version
check "--version imprime 'cpyx 1.0.0'" has "cpyx 1.0.0"
check "--version sale con 0" rc_is 0

run "$CPYX" -h
check "-h muestra el uso" has "Uso:"
check "-h sale con 0" rc_is 0

run "$CPYX"
check "sin argumentos sale con 64" rc_is 64

run "$CPYX" --nope a b
check "opción larga desconocida sale con 64" rc_is 64

run "$CPYX" -Q a b
check "opción corta desconocida sale con 64" rc_is 64

run "$CPYX" -x
check "-x sin valor sale con 64" rc_is 64

run "$CPYX" -L /no/existe/jamas "$WORK/dst"
check "origen inexistente sale con 66" rc_is 66

echo "== Copia"
fresh
run "$CPYX" -L "$WORK/src/" "$WORK/dst"
check "copia correcta sale con 0" rc_is 0
check "copia a.txt" test -f "$WORK/dst/a.txt"
check "copia subcarpetas" test -f "$WORK/dst/sub/b.txt"
check "crea el destino si no existe" test -d "$WORK/dst"
check "muestra el resumen" has "RESULTADO"

fresh
run "$CPYX" -L -x '*.tmp' "$WORK/src/" "$WORK/dst"
check "-x excluye *.tmp" test ! -e "$WORK/dst/x.tmp"
check "-x no excluye lo demás" test -f "$WORK/dst/a.txt"

fresh
run "$CPYX" -L --exclude=sub "$WORK/src/" "$WORK/dst"
check "--exclude=PAT excluye la carpeta" test ! -e "$WORK/dst/sub"

fresh
run "$CPYX" -L -x'*.tmp' "$WORK/src/" "$WORK/dst"
check "-xPAT (valor pegado) funciona" test ! -e "$WORK/dst/x.tmp"

echo "== Simulación"
fresh
run "$CPYX" -n -L "$WORK/src/" "$WORK/dst"
check "-n sale con 0" rc_is 0
check "-n no copia nada" test ! -e "$WORK/dst"
check "-n lo indica en pantalla" has "SIMULACIÓN"

echo "== Borrado (--delete)"
fresh
mkdir -p "$WORK/dst"; echo sobra > "$WORK/dst/extra.txt"
run "$CPYX" -L -d "$WORK/src/" "$WORK/dst"
check "-d sin terminal ni -y sale con 64" rc_is 64
check "-d sin -y no borra nada" test -f "$WORK/dst/extra.txt"

run "$CPYX" -L -dy "$WORK/src/" "$WORK/dst"
check "-dy (agrupadas) sale con 0" rc_is 0
check "-dy borra lo sobrante" test ! -e "$WORK/dst/extra.txt"

fresh
mkdir -p "$WORK/dst"; echo sobra > "$WORK/dst/extra.txt"
run "$CPYX" -L -nd "$WORK/src/" "$WORK/dst"
check "-nd no pide confirmación (es simulación)" rc_is 0
check "-nd no borra" test -f "$WORK/dst/extra.txt"

echo "== Rutas"
fresh
run "$CPYX" -L "$WORK/src" "$WORK/src/"
check "mismo origen y destino sale con 64" rc_is 64

fresh
mkdir -p "$WORK/-raro"; echo z > "$WORK/-raro/f"
cd "$WORK" || exit 1
run "$CPYX" -L -- -raro/ "$WORK/out"
cd - >/dev/null || exit 1
check "'--' permite rutas que empiezan con guion" test -f "$WORK/out/f"

echo "== Logs"
fresh
run "$CPYX" "$WORK/src/" "$WORK/dst"
has_default_log() { compgen -G "$WORK/state/cpyx/*.log" >/dev/null; }
check "crea log por defecto en XDG_STATE_HOME" has_default_log

fresh
run "$CPYX" --log="$WORK/logs/nuevo/mi.log" "$WORK/src/" "$WORK/dst"
check "--log crea el directorio y el archivo" test -s "$WORK/logs/nuevo/mi.log"

fresh
rm -rf "$WORK/state"
run "$CPYX" -L "$WORK/src/" "$WORK/dst"
check "-L no crea log" test ! -e "$WORK/state"

echo "== Enlace simbólico"
ln -s "$CPYX" "$WORK/enlace"
run "$WORK/enlace" --version
check "funciona vía symlink" has "cpyx 1.0.0"

echo
echo "Resultado: $PASS correctas, $FAIL fallidas"
[[ $FAIL -eq 0 ]]
