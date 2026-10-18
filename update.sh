#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Felix Sanchez <felixsanchez73@outlook.com>
#
# =============================================================================
# cpyx updater - full reinstall via git.
#
# Usage:
#   ./update.sh              Update from origin (main or master)
#   ./update.sh --yes        Skip confirmation prompts
#   ./update.sh --prefix=DIR Pass DIR to install.sh (reinstall location)
#   ./update.sh --user       Pass --user to install.sh
#
# DESTDIR: prepends a staging root (for packagers); passed to install.sh.
# =============================================================================

set -eu

NAME="cpyx"
ROOT=$(cd "$(dirname "$0")" && pwd)
DESTDIR="${DESTDIR:-}"
export DESTDIR
ASSUME_YES=0
INSTALL_ARGS=()
PREFIX_ARG=""

msg()   { printf '\033[36m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[32m OK\033[0m %s\n' "$*"; }
warn()  { printf '\033[33m !!\033[0m %s\n' "$*"; }
fail()  { printf '\033[31m ERR\033[0m %s\n' "$*" >&2; exit 1; }
has_command() { command -v "$1" >/dev/null 2>&1; }

for arg in "$@"; do
    case "$arg" in
        --yes|-y) ASSUME_YES=1 ;;
        --user) INSTALL_ARGS+=("--user") ;;
        --prefix=*) INSTALL_ARGS+=("$arg"); PREFIX_ARG="${arg#--prefix=}" ;;
        -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

# ---- Helpers -----------------------------------------------------------------
confirm() {
    if [ "$ASSUME_YES" -eq 1 ]; then return 0; fi
    printf '%s [y/N] ' "$1" >&2
    IFS= read -r res || true
    case "$res" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

get_version() {
    sed -n 's/^readonly CPYX_VERSION="\([^"]*\)".*/\1/p' "$ROOT/lib/cpyx/core.sh"
}

detect_prefix() {
    local prefixes=("$HOME/.local" /usr/local /usr)
    if [ -n "${PREFIX_ARG:-}" ]; then
        prefixes=("$PREFIX_ARG")
    fi
    for p in "${prefixes[@]}"; do
        if [ -f "$DESTDIR$p/bin/$NAME" ]; then
            echo "$p"
            return 0
        fi
    done
    return 1
}

reinstall() {
    local prefix
    if ! prefix=$(detect_prefix); then
        msg "No existing installation found. Running fresh install..."
        # shellcheck disable=SC2086
        if ! "$ROOT/install.sh" ${INSTALL_ARGS[@]+"${INSTALL_ARGS[@]}"}; then
            fail "Failed to install $NAME."
        fi
        ok "cpyx installed $(get_version)"
        "$ROOT/bin/cpyx" --version
        return
    fi

    msg "Updating $NAME in $DESTDIR$prefix (incremental rsync)..."

    local SUDO=""
    if [ "$(id -u)" -ne 0 ]; then
        has_command sudo && SUDO="sudo"
        has_command doas && SUDO="doas"
    fi

    # Incremental update: only changed files are synced, preserving existing install
    # Sync binary (parent dir must exist)
    mkdir -p "$DESTDIR$prefix/bin"
    # shellcheck disable=SC2086
    $SUDO rsync -a --delete --itemize-changes "$ROOT/bin/$NAME" "$DESTDIR$prefix/bin/$NAME"

    # Sync lib modules
    mkdir -p "$DESTDIR$prefix/lib"
    # shellcheck disable=SC2086
    $SUDO rsync -a --delete --itemize-changes "$ROOT/lib" "$DESTDIR$prefix/lib"

    # Sync completions into correct subdirectories
    mkdir -p "$DESTDIR$prefix/share/bash-completion/completions"
    mkdir -p "$DESTDIR$prefix/share/fish/vendor_completions.d"
    mkdir -p "$DESTDIR$prefix/share/zsh/site-functions"
    # shellcheck disable=SC2086
    $SUDO rsync -a --delete --itemize-changes "$ROOT/completions/$NAME.bash" "$DESTDIR$prefix/share/bash-completion/completions/$NAME"
    # shellcheck disable=SC2086
    $SUDO rsync -a --delete --itemize-changes "$ROOT/completions/$NAME.fish" "$DESTDIR$prefix/share/fish/vendor_completions.d/$NAME.fish"
    # shellcheck disable=SC2086
    $SUDO rsync -a --delete --itemize-changes "$ROOT/completions/_$NAME" "$DESTDIR$prefix/share/zsh/site-functions/_$NAME"

    ok "cpyx updated to $(get_version)"
    "$DESTDIR$prefix/bin/$NAME" --version
}

# ---- Preconditions -----------------------------------------------------------
[ -f "$ROOT/lib/cpyx/core.sh" ] || fail "lib/cpyx/core.sh not found next to updater ($ROOT)."
[ -f "$ROOT/install.sh" ]        || fail "install.sh not found next to updater ($ROOT)."

has_command git || fail "git is required to update $NAME."
git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || fail "Not a git repository: $ROOT"
git -C "$ROOT" remote get-url origin >/dev/null 2>&1 \
    || fail "No 'origin' remote configured."

# ---- Default branch (main or master) -----------------------------------------
BRANCH=""
if b=$(git -C "$ROOT" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null); then
    BRANCH="${b#origin/}"
elif b=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null); then
    [ "$b" != "HEAD" ] && BRANCH="$b"
fi
if [ -z "$BRANCH" ]; then
    for candidate in main master; do
        if git -C "$ROOT" rev-parse --verify --quiet "origin/$candidate" >/dev/null; then
            BRANCH="$candidate"
            break
        fi
    done
fi
[ -n "$BRANCH" ] || fail "Could not determine the default branch (main/master)."
UPSTREAM="origin/$BRANCH"

msg "Updating $NAME from $UPSTREAM"

# ---- Fetch -------------------------------------------------------------------
if ! git -C "$ROOT" fetch --prune origin; then
    fail "Could not fetch from origin (network or permission problem)."
fi

LOCAL=$(git -C "$ROOT" rev-parse HEAD)
REMOTE=$(git -C "$ROOT" rev-parse "$UPSTREAM" 2>/dev/null) \
    || fail "Remote branch $UPSTREAM not found after fetch."

# ---- Compare -----------------------------------------------------------------
if [ "$LOCAL" = "$REMOTE" ]; then
    ok "Already up to date (cpyx $(get_version))."
    if confirm "Force reinstall anyway?"; then
        reinstall
    fi
    exit 0
fi

if ! git -C "$ROOT" merge-base --is-ancestor "$LOCAL" "$REMOTE"; then
    warn "Your local branch has diverged from $UPSTREAM."
    warn "Resolve it manually, for example:"
    echo "    git -C '$ROOT' log --oneline --left-right '$UPSTREAM...HEAD'"
    exit 1
fi

COMMITS=$(git -C "$ROOT" log --oneline "$LOCAL..$REMOTE" | wc -l)
msg "New commits ($COMMITS):"
git -C "$ROOT" log --oneline "$LOCAL..$REMOTE"

if ! confirm "Pull these changes and reinstall?"; then
    warn "Aborted; no changes were applied."
    exit 1
fi

# ---- Pull --------------------------------------------------------------------
if ! git -C "$ROOT" pull --ff-only origin "$BRANCH"; then
    fail "Could not fast-forward $BRANCH."
fi

reinstall
