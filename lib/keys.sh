fusho_target_user() {
  printf '%s\n' "${1%%@*}"
}

fusho_target_host() {
  case "$1" in
  *@*) printf '%s\n' "${1#*@}" ;;
  *) printf 'github\n' ;;
  esac
}

fusho_keys_url() {
  local user host
  user=$(fusho_target_user "$1")
  host=$(fusho_target_host "$1")
  case "$host" in
  github) printf '%s/%s.keys\n' "$FUSHO_GITHUB_BASE" "$user" ;;
  gitlab) printf 'https://gitlab.com/%s.keys\n' "$user" ;;
  codeberg) printf 'https://codeberg.org/%s.keys\n' "$user" ;;
  sourcehut | srht) printf 'https://meta.sr.ht/~%s.keys\n' "$user" ;;
  bitbucket)
    fusho_die "Bitbucket publishes no public SSH key endpoint, so fusho cannot look '${user}' up. ask them for a public key file and pass it with --keys-file."
    ;;
  *) printf 'https://%s/%s.keys\n' "$host" "$user" ;;
  esac
}

fusho_fetch_keys() {
  local target="$1" dest="$2"
  local code url
  url=$(fusho_keys_url "$target")
  if ! code=$(curl -sSL -o "$dest" -w '%{http_code}' --max-time "$FUSHO_HTTP_TIMEOUT" "$url" 2>/dev/null); then
    fusho_die "could not reach ${url}. check your network connection."
  fi
  case "$code" in
  200) ;;
  404) fusho_die "no account '$(fusho_target_user "$target")' at $(fusho_target_host "$target")." ;;
  *) fusho_die "unexpected HTTP ${code} while fetching keys from ${url}." ;;
  esac
}

fusho_supported_keys() {
  awk '$1 == "ssh-ed25519" || $1 == "ssh-rsa" { print }' "$1"
}

fusho_unsupported_types() {
  awk 'NF > 1 && $1 != "ssh-ed25519" && $1 != "ssh-rsa" { print $1 }' "$1" | sort -u | tr '\n' ' '
}

fusho_fingerprints() {
  ssh-keygen -lf "$1" 2>/dev/null | awk '{print $2}'
}

fusho_require_keys() {
  local user="$1" raw="$2" supported="$3"
  local unsupported
  if [ ! -s "$raw" ]; then
    fusho_die "'${user}' has no SSH keys published. ask them to add one to their account."
  fi
  if [ ! -s "$supported" ]; then
    unsupported=$(fusho_unsupported_types "$raw")
    fusho_die "'${user}' publishes no key fusho can encrypt to. found: ${unsupported}only ssh-ed25519 and ssh-rsa are supported."
  fi
}

fusho_fingerprint_matches() {
  local fingerprint="$1" prefix="$2"
  if [ -z "$prefix" ]; then
    return 0
  fi
  case "$fingerprint" in
  "$prefix"*) return 0 ;;
  "SHA256:$prefix"*) return 0 ;;
  *) return 1 ;;
  esac
}

fusho_select_keys() {
  local supported="$1" prefix="$2" selected="$3" selected_fps="$4"
  local line index=0
  local all_fps="${selected_fps}.all"
  : >"$selected"
  : >"$selected_fps"
  fusho_fingerprints "$supported" >"$all_fps"
  while IFS= read -r line; do
    index=$((index + 1))
    if fusho_fingerprint_matches "$line" "$prefix"; then
      sed -n "${index}p" "$supported" >>"$selected"
      printf '%s\n' "$line" >>"$selected_fps"
    fi
  done <"$all_fps"
}

fusho_reject_bad_pin() {
  local user="$1" prefix="$2" supported="$3" selected_fps="$4"
  local count
  count=$(wc -l <"$selected_fps" | tr -d ' ')
  if [ "$count" -eq 0 ]; then
    printf 'fusho: no key of %s matches fingerprint prefix %s. available:\n' "$user" "$prefix" >&2
    fusho_fingerprints "$supported" >&2
    exit 1
  fi
  if [ "$count" -gt 1 ]; then
    printf 'fusho: fingerprint prefix %s is ambiguous for %s. it matches:\n' "$prefix" "$user" >&2
    cat "$selected_fps" >&2
    exit 1
  fi
}

fusho_key_type() {
  awk 'NR == 1 { print $1 }' "$1"
}

fusho_warn_weak_keys() {
  local supported="$1" target="$2"
  local bits type
  ssh-keygen -lf "$supported" 2>/dev/null | while IFS= read -r line; do
    bits=$(printf '%s' "$line" | awk '{print $1}')
    type=$(printf '%s' "$line" | awk '{type=$NF; gsub(/[()]/, "", type); print type}')
    if [ "$type" = "RSA" ] && [ "$bits" -lt "$FUSHO_MIN_RSA_BITS" ]; then
      fusho_warn "'${target}' publishes a ${bits}-bit RSA key, below the ${FUSHO_MIN_RSA_BITS}-bit floor. ask them to rotate to ed25519."
    fi
  done
}
