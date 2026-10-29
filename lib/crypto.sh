#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${FUSHO_LIB:?}/state.sh"

FUSHO_SED_KEYBITS='s/.*Public-Key: (\([0-9][0-9]*\) bit).*/\1/p'

fusho_rsa_capacity() {
  fusho_rc_pem="$1"
  fusho_rc_bits=""
  fusho_rc_bits=$(openssl pkey -pubin -in "${fusho_rc_pem}" -text -noout 2>/dev/null | sed -n "${FUSHO_SED_KEYBITS}" | head -1)
  if [ -z "${fusho_rc_bits}" ]; then
    fusho_rc_bits=$(openssl rsa -pubin -in "${fusho_rc_pem}" -text -noout 2>/dev/null | sed -n "${FUSHO_SED_KEYBITS}" | head -1)
  fi
  if [ -z "${fusho_rc_bits}" ]; then
    fusho_die "could not determine the recipient RSA key size."
  fi
  printf '%s\n' "$((fusho_rc_bits / 8 - FUSHO_OAEP_OVERHEAD))"
}

fusho_encrypt_age() {
  fusho_ea2_selected="$1"
  fusho_ea2_plaintext="$2"
  fusho_ea2_ciphertext="$3"
  if ! age -R "${fusho_ea2_selected}" -o "${fusho_ea2_ciphertext}" <"${fusho_ea2_plaintext}" 2>/dev/null; then
    fusho_die "age failed to encrypt the message."
  fi
}

fusho_encrypt_openssl() {
  fusho_eo_selected="$1"
  fusho_eo_plaintext="$2"
  fusho_eo_ciphertext="$3"
  fusho_eo_work="$4"
  fusho_eo_pem="${fusho_eo_work}/recipient.pem"
  fusho_eo_capacity=""
  fusho_eo_size=""
  fusho_eo_type=$(fusho_key_type "${fusho_eo_selected}")
  if [ "${fusho_eo_type}" != "ssh-rsa" ]; then
    fusho_die "age is not installed and the recipient key is not RSA. install age (brew install age, apt install age) to send to this recipient."
  fi
  if ! ssh-keygen -e -m PKCS8 -f "${fusho_eo_selected}" >"${fusho_eo_pem}" 2>/dev/null; then
    fusho_die "could not convert the recipient SSH key to PKCS8."
  fi
  fusho_eo_capacity=$(fusho_rsa_capacity "${fusho_eo_pem}") || exit 1
  fusho_eo_size=$(wc -c <"${fusho_eo_plaintext}" | tr -d ' ')
  if [ "${fusho_eo_size}" -gt "${fusho_eo_capacity}" ]; then
    fusho_die "message is ${fusho_eo_size} bytes but this RSA key can carry only ${fusho_eo_capacity}. install age to remove the limit."
  fi
  if ! openssl pkeyutl -encrypt -pubin -inkey "${fusho_eo_pem}" \
    -pkeyopt rsa_padding_mode:oaep -in "${fusho_eo_plaintext}" -out "${fusho_eo_ciphertext}" 2>/dev/null; then
    fusho_die "openssl failed to encrypt the message."
  fi
}
fusho_decrypt_age() {
  fusho_da_identity="$1"
  fusho_da_ciphertext="$2"
  if ! age -d -i "${fusho_da_identity}" "${fusho_da_ciphertext}"; then
    fusho_die "decryption failed. the message may be corrupt, altered, or addressed to a different key."
  fi
}

fusho_decrypt_openssl() {
  fusho_do_identity="$1"
  fusho_do_ciphertext="$2"
  if ! openssl pkeyutl -decrypt -inkey "${fusho_do_identity}" \
    -pkeyopt rsa_padding_mode:oaep -in "${fusho_do_ciphertext}" 2>/dev/null; then
    fusho_die "decryption failed. if your private key begins with 'BEGIN OPENSSH PRIVATE KEY', convert it with: ssh-keygen -p -m PEM -f ${fusho_do_identity}"
  fi
}
