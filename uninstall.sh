#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Felix Sanchez <felixsanchez73@outlook.com>
#
# =============================================================================
# cpyx uninstaller - fully independent.
#
# Usage:
#   ./uninstall.sh              Uninstall (searches /usr/local and ~/.local)
#   ./uninstall.sh --user       Only remove the ~/.local installation
#   ./uninstall.sh --prefix=DIR Only remove the installation under DIR
#   ./uninstall.sh --no-deps    Accepted for compatibility; no-op here
#   ./uninstall.sh --uninstall   Redundant: this IS the uninstaller
#
# DESTDIR: prepends a staging root (for packagers).
# Does NOT remove logs; they stay in ~/.local/state/cpyx/.
# =============================================================================

set -eu

NAME="cpyx"
ROOT=$(cd "$(dirname "$0")" && pwd)
PREFIX=""
USER_ONLY=0
EXPLICIT_PREFIX=""
NO_DEPS=0
DESTDIR="${DESTDIR:-}"
export DESTDIR

msg()   { printf '\033[36m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[32m OK\033[0m %s\n' "$*"; }
warn()  { printf '\033[33m !!\033[0m %s\n' "$*"; }
fail()  { printf '\033[31m ERR\033[0m %s\n' "$*" >&2; exit 1; }
has_command() { command -v "$1" >/dev/null 2>&1; }

for arg in "$@"; do
    case "$arg" in
        --user) USER_ONLY=1 ;;
        --prefix=*) PREFIX="${arg#--prefix=}"; EXPLICIT_PREFIX=1 ;;
        --no-deps) NO_DEPS=1 ;;
        --uninstall|--desinstalar)
            msg "Note: this is the uninstaller itself; --uninstall is redundant."
            ;;
        -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

# ---- Privilege elevation ----------------------------------------------------
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if has_command sudo; then SUDO="sudo"
    elif has_command doas; then SUDO="doas"
    fi
fi

# ---- Installation prefix ----------------------------------------------------
if [ -z "$PREFIX" ]; then
    if [ "$USER_ONLY" -eq 1 ]; then
        PREFIX="$HOME/.local"
    elif [ "$(id -u)" -eq 0 ] || [ -n "$SUDO" ]; then
        PREFIX="/usr/local"
    else
        PREFIX="$HOME/.local"
    fi
fi

# ---- Prefixes to search -----------------------------------------------------
if [ -n "$EXPLICIT_PREFIX" ] || [ "$USER_ONLY" -eq 1 ]; then
    PREFIXES="$PREFIX"
else
    PREFIXES="$PREFIX /usr/local $HOME/.local"
fi

msg "Uninstalling $NAME (searching: $PREFIXES)"

FOUND=0
for p in $PREFIXES; do
    found_prefix=0
    for target in "$DESTDIR$p/bin/$NAME" "$DESTDIR$p/lib/$NAME" \
                  "$DESTDIR$p/share/bash-completions/completions/$NAME" \
                  "$DESTDIR$p/share/fish/vendor_completions.d/$NAME.fish" \
                  "$DESTDIR$p/share/zsh/site-functions/_$NAME"; do
        if [ -e "$target" ]; then
            FOUND=1
            found_prefix=1
            if [ -w "$(dirname "$target")" ]; then
                rm -rf "$target"
            elif [ -n "$SUDO" ]; then
                $SUDO rm -rf "$target"
            else
                warn "Cannot remove $target (no permission); rerun with sudo."
                continue
            fi
            ok "Removed $target"
        fi
    done
    if [ "$found_prefix" -eq 1 ]; then
        msg "Removed from $p"
    fi
done

if [ "$FOUND" -eq 0 ]; then
    msg "$NAME is not installed in any of the searched prefixes."
else
    msg "Logs (if any) remain in ~/.local/state/cpyx/"
fi

exit 0
