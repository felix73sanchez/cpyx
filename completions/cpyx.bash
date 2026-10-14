# shellcheck shell=bash
# Autocompletado de cpyx para bash
_cpyx() {
    local cur prev opts
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="-n --dry-run -d --delete -y --yes -x --exclude -l --log -L --no-log -V --version -h --help"

    case "$prev" in
        -l|--log) mapfile -t COMPREPLY < <(compgen -f -- "$cur"); return ;;
        -x|--exclude) return ;;
    esac

    if [[ $cur == -* ]]; then
        mapfile -t COMPREPLY < <(compgen -W "$opts" -- "$cur")
    else
        mapfile -t COMPREPLY < <(compgen -f -- "$cur")
    fi
}
complete -o filenames -F _cpyx cpyx
