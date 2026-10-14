#!/bin/sh
# =============================================================================
# Instalador de cpyx - funciona en cualquier Linux.
#
# Uso:
#   ./install.sh                 Instala (en /usr/local si hay sudo/root,
#                                si no, en ~/.local)
#   ./install.sh --user          Instala solo para tu usuario (~/.local)
#   ./install.sh --prefix=DIR    Instala bajo DIR (bin/, lib/cpyx/, share/)
#   ./install.sh --no-deps       No instalar dependencias (rsync, bash)
#   ./install.sh --uninstall     Desinstala
#
# Variable DESTDIR: antepone una raiz de staging (para empaquetadores).
# =============================================================================

set -eu

NOMBRE="cpyx"
RAIZ=$(cd "$(dirname "$0")" && pwd)
PREFIX=""
ACCION="instalar"
SOLO_USUARIO=0
PREFIX_EXPLICITO=""
SIN_DEPS=0
DESTDIR="${DESTDIR:-}"

for arg in "$@"; do
    case "$arg" in
        --user) SOLO_USUARIO=1 ;;
        --prefix=*) PREFIX="${arg#--prefix=}"; PREFIX_EXPLICITO=1 ;;
        --no-deps) SIN_DEPS=1 ;;
        --uninstall|--desinstalar) ACCION="desinstalar" ;;
        -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Opcion desconocida: $arg" >&2; exit 1 ;;
    esac
done

msg()   { printf '\033[36m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[32m OK\033[0m %s\n' "$*"; }
warn()  { printf '\033[33m !!\033[0m %s\n' "$*"; }
fail()  { printf '\033[31mERR\033[0m %s\n' "$*" >&2; exit 1; }
existe() { command -v "$1" >/dev/null 2>&1; }

# ---- Elevacion de privilegios ----------------------------------------------
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if existe sudo; then SUDO="sudo"
    elif existe doas; then SUDO="doas"
    fi
fi

# ---- Prefijo de instalacion -------------------------------------------------
if [ -z "$PREFIX" ]; then
    if [ "$SOLO_USUARIO" -eq 1 ]; then
        PREFIX="$HOME/.local"
    elif [ "$(id -u)" -eq 0 ] || [ -n "$SUDO" ]; then
        PREFIX="/usr/local"
    else
        PREFIX="$HOME/.local"
    fi
fi

# El primer ancestro existente decide si hace falta elevar privilegios
ancestro_escribible() {
    d="$1"
    while [ ! -d "$d" ]; do d=$(dirname "$d"); done
    [ -w "$d" ]
}

USA_SUDO=0
if ! ancestro_escribible "$DESTDIR$PREFIX"; then
    if [ -n "$SUDO" ]; then USA_SUDO=1
    else fail "Sin permisos para escribir en $DESTDIR$PREFIX (usa --user o sudo)."
    fi
fi

ejecutar() {
    if [ "$USA_SUDO" -eq 1 ]; then $SUDO "$@"; else "$@"; fi
}

BIN="$DESTDIR$PREFIX/bin"
LIB="$DESTDIR$PREFIX/lib/$NOMBRE"
BASHC="$DESTDIR$PREFIX/share/bash-completion/completions"
FISHC="$DESTDIR$PREFIX/share/fish/vendor_completions.d"
ZSHC="$DESTDIR$PREFIX/share/zsh/site-functions"

# ---- Desinstalar ------------------------------------------------------------
if [ "$ACCION" = "desinstalar" ]; then
    if [ -n "${PREFIX_EXPLICITO:-}" ] || [ "$SOLO_USUARIO" -eq 1 ]; then
        PREFIJOS="$PREFIX"
    else
        PREFIJOS="$PREFIX /usr/local $HOME/.local"
    fi
    for p in $PREFIJOS; do
        encontrado=0
        for objetivo in "$DESTDIR$p/bin/$NOMBRE" "$DESTDIR$p/lib/$NOMBRE" \
                        "$DESTDIR$p/share/bash-completion/completions/$NOMBRE" \
                        "$DESTDIR$p/share/fish/vendor_completions.d/$NOMBRE.fish" \
                        "$DESTDIR$p/share/zsh/site-functions/_$NOMBRE"; do
            if [ -e "$objetivo" ]; then
                encontrado=1
                if [ -w "$(dirname "$objetivo")" ]; then rm -rf "$objetivo"
                elif [ -n "$SUDO" ]; then $SUDO rm -rf "$objetivo"
                else warn "Sin permisos para borrar $objetivo"; fi
            fi
        done
        [ "$encontrado" -eq 1 ] && ok "Eliminado de $p"
    done
    msg "Los logs (si los hay) siguen en ~/.local/state/cpyx/"
    exit 0
fi

# ---- Dependencias -----------------------------------------------------------
ejecutar_pkg() {
    if [ "$(id -u)" -eq 0 ]; then "$@"
    elif [ -n "$SUDO" ]; then $SUDO "$@"
    else fail "Se necesitan permisos de administrador para instalar paquetes."
    fi
}

instalar_paquetes() {
    if existe pacman;         then ejecutar_pkg pacman -S --needed --noconfirm "$@"
    elif existe apt-get;      then ejecutar_pkg apt-get update -qq && ejecutar_pkg apt-get install -y "$@"
    elif existe dnf;          then ejecutar_pkg dnf install -y "$@"
    elif existe yum;          then ejecutar_pkg yum install -y "$@"
    elif existe zypper;       then ejecutar_pkg zypper --non-interactive install "$@"
    elif existe apk;          then ejecutar_pkg apk add "$@"
    elif existe xbps-install; then ejecutar_pkg xbps-install -Sy "$@"
    elif existe emerge;       then ejecutar_pkg emerge --noreplace "$@"
    elif existe nix-env;      then nix-env -iA nixpkgs.rsync nixpkgs.bash
    else return 1
    fi
}

if [ "$SIN_DEPS" -eq 0 ]; then
    FALTAN=""
    existe rsync || FALTAN="$FALTAN rsync"
    existe bash  || FALTAN="$FALTAN bash"
    if [ -n "$FALTAN" ]; then
        msg "Faltan dependencias:$FALTAN"
        # shellcheck disable=SC2086
        instalar_paquetes $FALTAN || fail "No detecte tu gestor de paquetes. Instala manualmente:$FALTAN"
        ok "Dependencias instaladas"
    else
        ok "rsync y bash ya estan instalados"
    fi
fi

# ---- Copiar archivos --------------------------------------------------------
[ -f "$RAIZ/bin/$NOMBRE" ] && [ -d "$RAIZ/lib/$NOMBRE" ] \
    || fail "No encuentro bin/ y lib/ junto al instalador ($RAIZ)"

msg "Instalando $NOMBRE en $DESTDIR$PREFIX"
ejecutar mkdir -p "$BIN" "$LIB" "$BASHC" "$FISHC" "$ZSHC"
ejecutar install -m 0755 "$RAIZ/bin/$NOMBRE" "$BIN/$NOMBRE"
for f in "$RAIZ/lib/$NOMBRE"/*.sh; do
    ejecutar install -m 0644 "$f" "$LIB/$(basename "$f")"
done
ejecutar install -m 0644 "$RAIZ/completions/$NOMBRE.bash" "$BASHC/$NOMBRE"
ejecutar install -m 0644 "$RAIZ/completions/$NOMBRE.fish" "$FISHC/$NOMBRE.fish"
ejecutar install -m 0644 "$RAIZ/completions/_$NOMBRE" "$ZSHC/_$NOMBRE"
ok "Instalado: $BIN/$NOMBRE"

# ---- Verificar PATH ---------------------------------------------------------
case ":$PATH:" in
    *":$PREFIX/bin:"*) ;;
    *)
        warn "$PREFIX/bin no esta en tu PATH."
        echo "    bash/zsh: export PATH=\"$PREFIX/bin:\$PATH\""
        echo "    fish:     fish_add_path $PREFIX/bin"
        ;;
esac

case "$PREFIX" in
    /usr|/usr/local) ;;
    *)
        echo
        msg "Autocompletado de zsh: agrega esto a ~/.zshrc, antes de compinit:"
        echo "    fpath=($PREFIX/share/zsh/site-functions \$fpath)"
        ;;
esac

echo
ok "Listo. Prueba con:  $NOMBRE --help"
