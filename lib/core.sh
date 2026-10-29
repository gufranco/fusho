#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${FUSHO_LIB:?}/state.sh"

FUSHO_VERSION="3.0.0"

fusho_version() {
  printf '%s\n' "${FUSHO_VERSION}"
}

fusho_wrap() {
  awk -v width="${FUSHO_WIDTH}" -v indent="$1" '
    function pad(n,   s) {
      s = ""
      while (n-- > 0) { s = s " " }
      return s
    }
    length($0) <= width { print; next }
    {
      match($0, /^ */)
      n = split($0, word, " ")
      out = substr($0, 1, RLENGTH) word[1]
      for (i = 2; i <= n; i++) {
        if (length(out) + 1 + length(word[i]) > width) {
          print out
          out = pad(indent) word[i]
        } else {
          out = out " " word[i]
        }
      }
      print out
    }'
}

fusho_terminal() {
  [ "${FUSHO_TERMINAL:-}" = 1 ] || [ -t 1 ]
}

fusho_say() {
  fusho_s_text="$2"
  if [ "${#fusho_s_text}" -le "${FUSHO_WIDTH}" ] || ! fusho_terminal; then
    printf '%s\n' "${fusho_s_text}"
    return 0
  fi
  printf '%s\n' "${fusho_s_text}" | fusho_wrap "$1"
}

fusho_die() {
  fusho_say 0 "fusho: $1" >&2
  exit "${2:-1}"
}

fusho_warn() {
  fusho_say 0 "fusho: $1" >&2
}

fusho_cleanup() {
  if [ -n "${FUSHO_WORKSPACE}" ]; then
    rm -rf "${FUSHO_WORKSPACE}"
    FUSHO_WORKSPACE=""
  fi
}

fusho_init_workspace() {
  if [ -z "${FUSHO_WORKSPACE}" ]; then
    FUSHO_WORKSPACE=$(mktemp -d "${TMPDIR:-/tmp}/fusho-XXXXXX")
    chmod 700 "${FUSHO_WORKSPACE}"
  fi
}

fusho_have() {
  command -v "$1" >/dev/null 2>&1
}

fusho_openssl_flavor() {
  fusho_of_version=""
  if ! fusho_have openssl; then
    printf 'absent\n'
    return 0
  fi
  fusho_of_version=$(openssl version 2>/dev/null || printf 'unknown')
  case "${fusho_of_version}" in
  LibreSSL*) printf 'libressl\n' ;;
  OpenSSL*) printf 'openssl\n' ;;
  *) printf 'unknown\n' ;;
  esac
}
