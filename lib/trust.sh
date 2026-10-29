#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${FUSHO_LIB:?}/state.sh"

fusho_trust_store() {
  local base="${XDG_CONFIG_HOME:-${HOME}/.config}"
  local dir="${base}/fusho"
  if [ ! -e "$dir" ] && [ -d "${base}/${FUSHO_LEGACY_NAME}" ]; then
    mv -f "${base}/${FUSHO_LEGACY_NAME}" "$dir"
  fi
  mkdir -p "$dir"
  chmod 700 "$dir" 2>/dev/null || true
  printf '%s/known_recipients\n' "$dir"
}

fusho_trust_known() {
  awk -v target="$1" '$1 == target { print $2 }' "$2" | sort | tr '\n' ' '
}

fusho_trust_record() {
  local target="$1" fps="$2" store="$3"
  awk -v target="$target" 'NF > 0 { print target" "$0 }' "$fps" >>"$store"
}

fusho_trust_forget() {
  local target="$1" store="$2"
  local kept="${store}.kept"
  awk -v target="$target" '$1 != target' "$store" >"$kept"
  mv "$kept" "$store"
}

fusho_trust_check() {
  local target="$1" fps="$2" accept_new="$3"
  local store known current line
  store=$(fusho_trust_store)
  if [ ! -f "$store" ]; then
    : >"$store"
    chmod 600 "$store" 2>/dev/null || true
  fi
  known=$(fusho_trust_known "$target" "$store")
  current=$(sort "$fps" | tr '\n' ' ')
  if [ -z "$known" ]; then
    fusho_trust_record "$target" "$fps" "$store"
    fusho_warn "first message to '${target}'. verify these fingerprints out of band:"
    while IFS= read -r line; do
      if [ -n "$line" ]; then
        printf '  %s\n' "$line" >&2
      fi
    done <"$fps"
    return 0
  fi
  if [ "$known" = "$current" ]; then
    return 0
  fi
  if [ "$accept_new" -eq 1 ]; then
    fusho_trust_forget "$target" "$store"
    fusho_trust_record "$target" "$fps" "$store"
    fusho_warn "accepted new keys for '${target}'."
    return 0
  fi
  fusho_say 0 "fusho: the keys published by $target changed since you last messaged them." >&2
  printf '  pinned:  %s\n' "$known" >&2
  printf '  current: %s\n' "$current" >&2
  printf '  a key rotation looks exactly like an account takeover from here.\n' >&2
  printf '  check the fingerprint with them out of band, then re-run with --accept-new-key\n' >&2
  exit 1
}
