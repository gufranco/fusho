FUSHO_VERSION="1.8.0"
FUSHO_FORMAT_VERSION="1"
FUSHO_GITHUB_BASE="${FUSHO_GITHUB_BASE:-https://github.com}"
FUSHO_HTTP_TIMEOUT="${FUSHO_HTTP_TIMEOUT:-10}"
FUSHO_ARMOR_BEGIN="-----BEGIN FUSHO MESSAGE-----"
FUSHO_ARMOR_END="-----END FUSHO MESSAGE-----"
FUSHO_OAEP_OVERHEAD=42
FUSHO_SIG_NAMESPACE="fusho"
FUSHO_LEGACY_NAME="osm"
FUSHO_MIN_RSA_BITS="${FUSHO_MIN_RSA_BITS:-3072}"
FUSHO_CLIPBOARD_TIMEOUT="${FUSHO_CLIPBOARD_TIMEOUT:-90}"
FUSHO_CLIPBOARD_COPY="${FUSHO_CLIPBOARD_COPY:-}"
FUSHO_CLIPBOARD_PASTE="${FUSHO_CLIPBOARD_PASTE:-}"
FUSHO_BANNER="${FUSHO_BANNER:-1}"
FUSHO_WORKSPACE=""

fusho_die() {
  printf 'fusho: %s\n' "$1" >&2
  exit "${2:-1}"
}

fusho_warn() {
  printf 'fusho: %s\n' "$1" >&2
}

fusho_cleanup() {
  if [ -n "$FUSHO_WORKSPACE" ]; then
    rm -rf "$FUSHO_WORKSPACE"
    FUSHO_WORKSPACE=""
  fi
}

fusho_init_workspace() {
  if [ -z "$FUSHO_WORKSPACE" ]; then
    FUSHO_WORKSPACE=$(mktemp -d "${TMPDIR:-/tmp}/fusho-XXXXXX")
    chmod 700 "$FUSHO_WORKSPACE"
  fi
}

fusho_have() {
  command -v "$1" >/dev/null 2>&1
}

fusho_openssl_flavor() {
  local version
  if ! fusho_have openssl; then
    printf 'absent\n'
    return 0
  fi
  version=$(openssl version 2>/dev/null || printf 'unknown')
  case "$version" in
  LibreSSL*) printf 'libressl\n' ;;
  OpenSSL*) printf 'openssl\n' ;;
  *) printf 'unknown\n' ;;
  esac
}

fusho_probe_local() {
  local probe="ok"
  [ "$probe" = "ok" ]
}

fusho_require_local() {
  if ! fusho_probe_local 2>/dev/null; then
    printf 'fusho: this shell does not support "local".\n' >&2
    printf '  ksh93 and Solaris sh are the usual cause. run fusho with /bin/sh instead:\n' >&2
    printf '    sh %s <arguments>\n' "$0" >&2
    exit 1
  fi
}
