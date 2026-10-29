#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${FUSHO_LIB:?}/state.sh"

fusho_sign_identity() {
  local target="$1" work="$2"
  local raw supported fingerprint identity
  raw="${work}/from.keys"
  supported="${work}/from.supported"
  fusho_fetch_keys "$target" "$raw"
  fusho_supported_keys "$raw" >"$supported"
  fusho_require_keys "$target" "$raw" "$supported"
  fusho_fingerprints "$raw" >"${work}/from.fps"
  while IFS= read -r fingerprint; do
    if identity=$(fusho_find_identity "$fingerprint"); then
      printf '%s\n' "$identity"
      return 0
    fi
  done <"${work}/from.fps"
  fusho_die "no local private key matches a key published by '${target}', so fusho cannot sign as them."
}

fusho_sign_ciphertext() {
  local identity="$1" ciphertext="$2" sigfile="$3"
  if ! ssh-keygen -Y sign -f "$identity" -n "$FUSHO_SIG_NAMESPACE" "$ciphertext" >/dev/null 2>&1; then
    fusho_die "signing failed with identity '${identity}'."
  fi
  mv "${ciphertext}.sig" "$sigfile"
}

fusho_allowed_signers() {
  local from="$1" raw="$2" allowed="$3"
  local line
  : >"$allowed"
  while IFS= read -r line; do
    if [ -n "$line" ]; then
      printf '%s %s\n' "$from" "$line" >>"$allowed"
    fi
  done <"$raw"
}

fusho_verify_namespace() {
  ssh-keygen -Y verify -f "$1" -I "$2" -n "$5" -s "$3" <"$4" >/dev/null 2>&1
}

fusho_verify_signature() {
  local from="$1" ciphertext="$2" sigfile="$3" work="$4"
  local raw allowed
  raw="${work}/signer.keys"
  allowed="${work}/allowed_signers"
  fusho_fetch_keys "$from" "$raw"
  fusho_allowed_signers "$from" "$raw" "$allowed"
  if ! fusho_verify_namespace "$allowed" "$from" "$sigfile" "$ciphertext" "$FUSHO_SIG_NAMESPACE" &&
    ! fusho_verify_namespace "$allowed" "$from" "$sigfile" "$ciphertext" "$FUSHO_LEGACY_NAME"; then
    fusho_die "the signature does not match any key published by '${from}'. do not trust this message."
  fi
  fusho_warn "signature verified against a key published by '${from}'."
}
