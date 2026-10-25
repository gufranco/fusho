FUSHO_SED_KEYBITS='s/.*Public-Key: (\([0-9][0-9]*\) bit).*/\1/p'

fusho_rsa_capacity() {
  local pem="$1"
  local bits
  bits=$(openssl pkey -pubin -in "$pem" -text -noout 2>/dev/null | sed -n "$FUSHO_SED_KEYBITS" | head -1)
  if [ -z "$bits" ]; then
    bits=$(openssl rsa -pubin -in "$pem" -text -noout 2>/dev/null | sed -n "$FUSHO_SED_KEYBITS" | head -1)
  fi
  if [ -z "$bits" ]; then
    fusho_die "could not determine the recipient RSA key size."
  fi
  printf '%s\n' "$((bits / 8 - FUSHO_OAEP_OVERHEAD))"
}

fusho_encrypt_age() {
  local selected="$1" plaintext="$2" ciphertext="$3"
  if ! age -R "$selected" -o "$ciphertext" <"$plaintext" 2>/dev/null; then
    fusho_die "age failed to encrypt the message."
  fi
}

fusho_encrypt_openssl() {
  local selected="$1" plaintext="$2" ciphertext="$3" work="$4"
  local pem="${work}/recipient.pem" capacity size
  if [ "$(fusho_key_type "$selected")" != "ssh-rsa" ]; then
    fusho_die "age is not installed and the recipient key is not RSA. install age (brew install age, apt install age) to send to this recipient."
  fi
  if ! ssh-keygen -e -m PKCS8 -f "$selected" >"$pem" 2>/dev/null; then
    fusho_die "could not convert the recipient SSH key to PKCS8."
  fi
  capacity=$(fusho_rsa_capacity "$pem") || exit 1
  size=$(wc -c <"$plaintext" | tr -d ' ')
  if [ "$size" -gt "$capacity" ]; then
    fusho_die "message is ${size} bytes but this RSA key can carry only ${capacity}. install age to remove the limit."
  fi
  if ! openssl pkeyutl -encrypt -pubin -inkey "$pem" \
    -pkeyopt rsa_padding_mode:oaep -in "$plaintext" -out "$ciphertext" 2>/dev/null; then
    fusho_die "openssl failed to encrypt the message."
  fi
}
fusho_decrypt_age() {
  local identity="$1" ciphertext="$2"
  if ! age -d -i "$identity" "$ciphertext"; then
    fusho_die "decryption failed. the message may be corrupt, altered, or addressed to a different key."
  fi
}

fusho_decrypt_openssl() {
  local identity="$1" ciphertext="$2"
  if ! openssl pkeyutl -decrypt -inkey "$identity" \
    -pkeyopt rsa_padding_mode:oaep -in "$ciphertext" 2>/dev/null; then
    fusho_die "decryption failed. if your private key begins with 'BEGIN OPENSSH PRIVATE KEY', convert it with: ssh-keygen -p -m PEM -f ${identity}"
  fi
}
