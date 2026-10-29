#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${FUSHO_LIB:?}/state.sh"

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
  fusho_ku_user=""
  fusho_ku_host=""
  fusho_ku_user=$(fusho_target_user "$1")
  fusho_ku_host=$(fusho_target_host "$1")
  case "${fusho_ku_host}" in
  github) printf '%s/%s.keys\n' "${FUSHO_GITHUB_BASE}" "${fusho_ku_user}" ;;
  gitlab) printf 'https://gitlab.com/%s.keys\n' "${fusho_ku_user}" ;;
  codeberg) printf 'https://codeberg.org/%s.keys\n' "${fusho_ku_user}" ;;
  sourcehut | srht) printf 'https://meta.sr.ht/~%s.keys\n' "${fusho_ku_user}" ;;
  bitbucket)
    fusho_die "Bitbucket publishes no public SSH key endpoint, so fusho cannot look '${fusho_ku_user}' up. ask them for a public key file and pass it with --keys-file."
    ;;
  *) printf 'https://%s/%s.keys\n' "${fusho_ku_host}" "${fusho_ku_user}" ;;
  esac
}

fusho_fetch_keys() {
  fusho_fk_target="$1"
  fusho_fk_dest="$2"
  fusho_fk_code=""
  fusho_fk_url=""
  fusho_fk_url=$(fusho_keys_url "${fusho_fk_target}")
  if ! fusho_fk_code=$(curl -sSL -o "${fusho_fk_dest}" -w '%{http_code}' --max-time "${FUSHO_HTTP_TIMEOUT}" "${fusho_fk_url}" 2>/dev/null); then
    fusho_die "could not reach ${fusho_fk_url}. check your network connection."
  fi
  case "${fusho_fk_code}" in
  200) ;;
  404)
    fusho_fk_user=$(fusho_target_user "${fusho_fk_target}")
    fusho_fk_host=$(fusho_target_host "${fusho_fk_target}")
    fusho_die "no account '${fusho_fk_user}' at ${fusho_fk_host}."
    ;;
  *) fusho_die "unexpected HTTP ${fusho_fk_code} while fetching keys from ${fusho_fk_url}." ;;
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
  fusho_rk_user="$1"
  fusho_rk_raw="$2"
  fusho_rk_supported="$3"
  fusho_rk_unsupported=""
  if [ ! -s "${fusho_rk_raw}" ]; then
    fusho_die "'${fusho_rk_user}' has no SSH keys published. ask them to add one to their account."
  fi
  if [ ! -s "${fusho_rk_supported}" ]; then
    fusho_rk_unsupported=$(fusho_unsupported_types "${fusho_rk_raw}")
    fusho_die "'${fusho_rk_user}' publishes no key fusho can encrypt to. found: ${fusho_rk_unsupported}only ssh-ed25519 and ssh-rsa are supported."
  fi
}

fusho_fingerprint_matches() {
  fusho_fm_fingerprint="$1"
  fusho_fm_prefix="$2"
  if [ -z "${fusho_fm_prefix}" ]; then
    return 0
  fi
  case "${fusho_fm_fingerprint}" in
  "${fusho_fm_prefix}"*) return 0 ;;
  "SHA256:${fusho_fm_prefix}"*) return 0 ;;
  *) return 1 ;;
  esac
}

fusho_select_keys() {
  fusho_sk_supported="$1"
  fusho_sk_prefix="$2"
  fusho_sk_selected="$3"
  fusho_sk_selected_fps="$4"
  fusho_sk_line=""
  fusho_sk_index=0
  fusho_sk_all_fps="${fusho_sk_selected_fps}.all"
  : >"${fusho_sk_selected}"
  : >"${fusho_sk_selected_fps}"
  fusho_fingerprints "${fusho_sk_supported}" >"${fusho_sk_all_fps}"
  while IFS= read -r fusho_sk_line; do
    fusho_sk_index=$((fusho_sk_index + 1))
    if fusho_fingerprint_matches "${fusho_sk_line}" "${fusho_sk_prefix}"; then
      sed -n "${fusho_sk_index}p" "${fusho_sk_supported}" >>"${fusho_sk_selected}"
      printf '%s\n' "${fusho_sk_line}" >>"${fusho_sk_selected_fps}"
    fi
  done <"${fusho_sk_all_fps}"
}

fusho_reject_bad_pin() {
  fusho_rbp_user="$1"
  fusho_rbp_prefix="$2"
  fusho_rbp_supported="$3"
  fusho_rbp_selected_fps="$4"
  fusho_rbp_count=""
  fusho_rbp_count=$(wc -l <"${fusho_rbp_selected_fps}" | tr -d ' ')
  if [ "${fusho_rbp_count}" -eq 0 ]; then
    fusho_say 0 "fusho: no key of ${fusho_rbp_user} matches fingerprint prefix ${fusho_rbp_prefix}. available:" >&2
    fusho_fingerprints "${fusho_rbp_supported}" >&2
    exit 1
  fi
  if [ "${fusho_rbp_count}" -gt 1 ]; then
    fusho_say 0 "fusho: fingerprint prefix ${fusho_rbp_prefix} is ambiguous for ${fusho_rbp_user}. it matches:" >&2
    cat "${fusho_rbp_selected_fps}" >&2
    exit 1
  fi
}

fusho_key_type() {
  awk 'NR == 1 { print $1 }' "$1"
}

fusho_warn_weak_keys() {
  fusho_wwk_supported="$1"
  fusho_wwk_target="$2"
  fusho_wwk_bits=""
  fusho_wwk_type=""
  ssh-keygen -lf "${fusho_wwk_supported}" 2>/dev/null | while IFS= read -r line; do
    fusho_wwk_bits=$(printf '%s' "${line}" | awk '{print $1}')
    fusho_wwk_type=$(printf '%s' "${line}" | awk '{type=$NF; gsub(/[()]/, "", type); print type}')
    if [ "${fusho_wwk_type}" = "RSA" ] && [ "${fusho_wwk_bits}" -lt "${FUSHO_MIN_RSA_BITS}" ]; then
      fusho_warn "warning: '${fusho_wwk_target}' publishes a ${fusho_wwk_bits}-bit RSA key, below the ${FUSHO_MIN_RSA_BITS}-bit floor. ask them to rotate to ed25519."
    fi
  done
}
