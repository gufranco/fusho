#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${FUSHO_LIB:?}/state.sh"

fusho_trust_store() {
  fusho_ts_base="${XDG_CONFIG_HOME:-${HOME}/.config}"
  fusho_ts_dir="${fusho_ts_base}/fusho"
  if [ ! -e "${fusho_ts_dir}" ] && [ -d "${fusho_ts_base}/${FUSHO_LEGACY_NAME}" ]; then
    mv -f "${fusho_ts_base}/${FUSHO_LEGACY_NAME}" "${fusho_ts_dir}"
  fi
  mkdir -p "${fusho_ts_dir}"
  chmod 700 "${fusho_ts_dir}" 2>/dev/null || true
  printf '%s/known_recipients\n' "${fusho_ts_dir}"
}

fusho_trust_known() {
  awk -v target="$1" '$1 == target { print $2 }' "$2" | sort | tr '\n' ' '
}

fusho_trust_pin() {
  fusho_tp_target="$1"
  fusho_tp_fps="$2"
  fusho_tp_store="$3"
  fusho_tp_next="${fusho_tp_store}.next"
  if ! (
    umask 077
    awk -v target="${fusho_tp_target}" '$1 != target' "${fusho_tp_store}" >"${fusho_tp_next}" &&
      awk -v target="${fusho_tp_target}" 'NF > 0 { print target" "$0 }' "${fusho_tp_fps}" >>"${fusho_tp_next}"
  ) || ! mv -f "${fusho_tp_next}" "${fusho_tp_store}"; then
    rm -f "${fusho_tp_next}"
    fusho_die "could not save the pinned keys for '${fusho_tp_target}'. the earlier pins are unchanged."
  fi
}

fusho_trust_check() {
  fusho_tc_target="$1"
  fusho_tc_fps="$2"
  fusho_tc_accept_new="$3"
  fusho_tc_store=""
  fusho_tc_known=""
  fusho_tc_current=""
  fusho_tc_line=""
  fusho_tc_store=$(fusho_trust_store)
  if [ ! -f "${fusho_tc_store}" ]; then
    : >"${fusho_tc_store}"
    chmod 600 "${fusho_tc_store}" 2>/dev/null || true
  fi
  fusho_tc_known=$(fusho_trust_known "${fusho_tc_target}" "${fusho_tc_store}")
  fusho_tc_current=$(sort "${fusho_tc_fps}" | tr '\n' ' ')
  if [ -z "${fusho_tc_known}" ]; then
    fusho_trust_pin "${fusho_tc_target}" "${fusho_tc_fps}" "${fusho_tc_store}"
    fusho_warn "first message to '${fusho_tc_target}'. verify these fingerprints out of band:"
    while IFS= read -r fusho_tc_line; do
      if [ -n "${fusho_tc_line}" ]; then
        printf '  %s\n' "${fusho_tc_line}" >&2
      fi
    done <"${fusho_tc_fps}"
    return 0
  fi
  if [ "${fusho_tc_known}" = "${fusho_tc_current}" ]; then
    return 0
  fi
  if [ "${fusho_tc_accept_new}" -eq 1 ]; then
    fusho_trust_pin "${fusho_tc_target}" "${fusho_tc_fps}" "${fusho_tc_store}"
    fusho_warn "accepted new keys for '${fusho_tc_target}'."
    return 0
  fi
  fusho_say 0 "fusho: the keys published by ${fusho_tc_target} changed since you last messaged them." >&2
  printf '  pinned:  %s\n' "${fusho_tc_known}" >&2
  printf '  current: %s\n' "${fusho_tc_current}" >&2
  printf '  a key rotation looks exactly like an account takeover from here.\n' >&2
  printf '  check the fingerprint with them out of band, then re-run with --accept-new-key\n' >&2
  exit 1
}
