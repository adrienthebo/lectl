#!/usr/bin/env bash

readonly _CACHE_DIR
_CACHE_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../cache")"

CACHE_EXPIRATION=$(( 60 * 60 * 24 ))

case "$(uname)" in
    Darwin)
        readonly _STAT_MODIFIED_FMT="-f %m"
        ;;

    Linux)
        readonly _STAT_MODIFIED_FMT="--format %y"
        ;;
    *)
        echo "Error: unknown platform $(uname), cannot determine file stat format" 1>&2
        exit
        ;;
esac


__lectl_debug() {
    if [[ -n $LECTL_DEBUG ]]; then
        echo "debug: ${@}" 1>&2
    fi
}

_cache_curl() {
    cachefile="${_CACHE_DIR}/${1}"
    shift
    argv=$@

    [[ -d $_CACHE_DIR ]] || mkdir $_CACHE_DIR
    [[ -d $(dirname "$cachefile") ]] || mkdir "$(dirname "${cachefile}")"

    if [[ -f $cachefile ]]; then
        now="$(date +%s)"
        # shellcheck disable=SC2086
        lastmodified=$(stat $_STAT_MODIFIED_FMT $cachefile)

        if [[ $(( now - lastmodified )) -le $CACHE_EXPIRATION ]]; then
            __lectl_debug "cache hit ($cachefile) for $argv"
            cat "$cachefile"
            return 0
        else
            __lectl_debug "cache expired ($cachefile) for $argv"
            rm "${cachefile}"
        fi
    else
        __lectl_debug "cache miss (${cachefile}) for $argv"
    fi

    __lectl_debug curl $argv
    # shellcheck disable=SC2086
    curl $argv | tee "$cachefile"
    rc=$?
    if [[ rc -ne 0 ]]; then
        __lectl_debug "curl $argv failed, removing cache $cachefile"
        rm "$cachefile"
        return $rc
    fi
}
