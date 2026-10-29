FUSHO_VERSION="2.3.0"
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
FUSHO_WIDTH=80

fusho_wrap() {
  awk -v width="$FUSHO_WIDTH" -v indent="$1" '
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
  local text="$2"
  if [ "${#text}" -le "$FUSHO_WIDTH" ] || ! fusho_terminal; then
    printf '%s\n' "$text"
    return 0
  fi
  printf '%s\n' "$text" | fusho_wrap "$1"
}

fusho_die() {
  fusho_say 0 "fusho: $1" >&2
  exit "${2:-1}"
}

fusho_warn() {
  fusho_say 0 "fusho: $1" >&2
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
  [ "${probe:-}" = "ok" ]
}

fusho_require_local() {
  if ! fusho_probe_local 2>/dev/null; then
    printf 'fusho: this shell does not support "local".\n' >&2
    printf '  ksh93 and Solaris sh are the usual cause. run fusho with /bin/sh instead:\n' >&2
    printf '    sh %s <arguments>\n' "$0" >&2
    exit 1
  fi
}
