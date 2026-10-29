#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${FUSHO_LIB:?}/state.sh"

fusho_sign_identity() {
  fusho_si_target="$1"
  fusho_si_work="$2"
  fusho_si_raw=""
  fusho_si_supported=""
  fusho_si_fingerprint=""
  fusho_si_identity=""
  fusho_si_raw="${fusho_si_work}/from.keys"
  fusho_si_supported="${fusho_si_work}/from.supported"
  fusho_fetch_keys "${fusho_si_target}" "${fusho_si_raw}"
  fusho_supported_keys "${fusho_si_raw}" >"${fusho_si_supported}"
  fusho_require_keys "${fusho_si_target}" "${fusho_si_raw}" "${fusho_si_supported}"
  fusho_fingerprints "${fusho_si_raw}" >"${fusho_si_work}/from.fps"
  while IFS= read -r fusho_si_fingerprint; do
    if fusho_si_identity=$(fusho_find_identity "${fusho_si_fingerprint}"); then
      printf '%s\n' "${fusho_si_identity}"
      return 0
    fi
  done <"${fusho_si_work}/from.fps"
  fusho_die "no local private key matches a key published by '${fusho_si_target}', so fusho cannot sign as them."
}

fusho_sign_ciphertext() {
  fusho_sc_identity="$1"
  fusho_sc_ciphertext="$2"
  fusho_sc_sigfile="$3"
  if ! ssh-keygen -Y sign -f "${fusho_sc_identity}" -n "${FUSHO_SIG_NAMESPACE}" "${fusho_sc_ciphertext}" >/dev/null 2>&1; then
    fusho_die "signing failed with identity '${fusho_sc_identity}'."
  fi
  mv "${fusho_sc_ciphertext}.sig" "${fusho_sc_sigfile}"
}

fusho_allowed_signers() {
  fusho_as_from="$1"
  fusho_as_raw="$2"
  fusho_as_allowed="$3"
  fusho_as_line=""
  : >"${fusho_as_allowed}"
  while IFS= read -r fusho_as_line; do
    if [ -n "${fusho_as_line}" ]; then
      printf '%s %s\n' "${fusho_as_from}" "${fusho_as_line}" >>"${fusho_as_allowed}"
    fi
  done <"${fusho_as_raw}"
}

fusho_verify_namespace() {
  ssh-keygen -Y verify -f "$1" -I "$2" -n "$5" -s "$3" <"$4" >/dev/null 2>&1
}

fusho_verify_signature() {
  fusho_vs_from="$1"
  fusho_vs_ciphertext="$2"
  fusho_vs_sigfile="$3"
  fusho_vs_work="$4"
  fusho_vs_raw=""
  fusho_vs_allowed=""
  fusho_vs_raw="${fusho_vs_work}/signer.keys"
  fusho_vs_allowed="${fusho_vs_work}/allowed_signers"
  fusho_fetch_keys "${fusho_vs_from}" "${fusho_vs_raw}"
  fusho_allowed_signers "${fusho_vs_from}" "${fusho_vs_raw}" "${fusho_vs_allowed}"
  if ! fusho_verify_namespace "${fusho_vs_allowed}" "${fusho_vs_from}" "${fusho_vs_sigfile}" "${fusho_vs_ciphertext}" "${FUSHO_SIG_NAMESPACE}" &&
    ! fusho_verify_namespace "${fusho_vs_allowed}" "${fusho_vs_from}" "${fusho_vs_sigfile}" "${fusho_vs_ciphertext}" "${FUSHO_LEGACY_NAME}"; then
    fusho_die "the signature does not match any key published by '${fusho_vs_from}'. do not trust this message."
  fi
  fusho_warn "signature verified against a key published by '${fusho_vs_from}'."
}
