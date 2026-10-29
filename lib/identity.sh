#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${FUSHO_LIB:?}/state.sh"

fusho_find_identity() {
  fusho_fi_wanted="$1"
  fusho_fi_pub=""
  fusho_fi_priv=""
  fusho_fi_fingerprint=""
  for fusho_fi_pub in "${HOME}"/.ssh/*.pub; do
    if [ ! -f "${fusho_fi_pub}" ]; then
      continue
    fi
    fusho_fi_fingerprint=$(ssh-keygen -lf "${fusho_fi_pub}" 2>/dev/null | awk '{print $2}')
    fusho_fi_priv="${fusho_fi_pub%.pub}"
    if [ "${fusho_fi_fingerprint}" = "${fusho_fi_wanted}" ] && [ -f "${fusho_fi_priv}" ]; then
      printf '%s\n' "${fusho_fi_priv}"
      return 0
    fi
  done
  return 1
}

fusho_resolve_identity() {
  fusho_ri_keyfile="$1"
  fusho_ri_override="$2"
  fusho_ri_fingerprint=""
  fusho_ri_identity=""
  if [ -n "${fusho_ri_override}" ]; then
    if [ ! -f "${fusho_ri_override}" ]; then
      fusho_die "identity file '${fusho_ri_override}' does not exist."
    fi
    printf '%s\n' "${fusho_ri_override}"
    return 0
  fi
  while IFS= read -r fusho_ri_fingerprint; do
    if fusho_ri_identity=$(fusho_find_identity "${fusho_ri_fingerprint}"); then
      printf '%s\n' "${fusho_ri_identity}"
      return 0
    fi
  done <"${fusho_ri_keyfile}"
  printf 'fusho: no local private key matches this message. it was addressed to:\n' >&2
  sed 's/^/  /' "${fusho_ri_keyfile}" >&2
  fusho_explain_agent "${fusho_ri_keyfile}"
  exit 1
}

fusho_identity_is_encrypted() {
  ! ssh-keygen -y -f "$1" -P "" >/dev/null 2>&1
}

fusho_require_passphrase_channel() {
  fusho_rpc_identity="$1"
  if ! fusho_identity_is_encrypted "${fusho_rpc_identity}"; then
    return 0
  fi
  if (true </dev/tty) 2>/dev/null; then
    return 0
  fi
  fusho_die "'${fusho_rpc_identity}' is passphrase protected and there is no terminal to prompt on. run fusho from an interactive shell, or pass an unencrypted key with --identity."
}

fusho_agent_fingerprints() {
  fusho_af_dest="$1"
  : >"${fusho_af_dest}"
  if [ -z "${SSH_AUTH_SOCK:-}" ]; then
    return 1
  fi
  ssh-add -l 2>/dev/null | awk '{print $2}' >"${fusho_af_dest}" || true
  [ -s "${fusho_af_dest}" ]
}

fusho_explain_agent() {
  fusho_ea3_keyfile="$1"
  fusho_ea3_agentfile="${FUSHO_WORKSPACE}/agent.fps"
  if ! fusho_agent_fingerprints "${fusho_ea3_agentfile}"; then
    return 0
  fi
  if ! grep -q -F -f "${fusho_ea3_keyfile}" "${fusho_ea3_agentfile}" 2>/dev/null; then
    return 0
  fi
  printf '\n' >&2
  printf 'your ssh agent does hold one of these keys, so this message is addressed to you.\n' >&2
  printf 'age can only decrypt with a key file, and an agent such as 1Password never hands\n' >&2
  printf 'over the private half, so fusho cannot use it directly. two ways through:\n' >&2
  printf '\n' >&2
  printf '  fusho read --identity-command "op read op://Private/ssh-key/private-key"\n' >&2
  printf '  fusho read --identity ~/.ssh/id_ed25519\n' >&2
  printf '\n' >&2
  printf 'the first keeps the key out of your disk. fusho writes it to a private temporary\n' >&2
  printf 'file and deletes it when it exits.\n' >&2
}
