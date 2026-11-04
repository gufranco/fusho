#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${FUSHO_LIB:?}/state.sh"

FUSHO_VERSION="3.1.0"

fusho_version() {
  printf '%s\n' "${FUSHO_VERSION}"
}

fusho_say() {
  printf '%s\n' "$1"
}

fusho_die() {
  if fusho_ui_err; then
    fusho_ui_log ERROR "$1"
    exit "${2:-1}"
  fi
  fusho_say "fusho: $1" >&2
  exit "${2:-1}"
}

fusho_warn() {
  if ! fusho_ui_err; then
    fusho_say "fusho: $1" >&2
    return 0
  fi
  case "$1" in
  "warning: "*) fusho_ui_log WARN "${1#warning: }" ;;
  *) fusho_ui_log INFO "$1" ;;
  esac
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
