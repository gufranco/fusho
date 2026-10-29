#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${FUSHO_LIB:?}/state.sh"

fusho_cmd_send() {
  local prefix="" message="" no_clipboard=0 target="" literal=0
  local targets="" keyfiles="" as_json=0 sign_as="" accept_new=0 want_qr=0 expires="" no_banner=0 split=""
  while [ $# -gt 0 ]; do
    if [ "$literal" -eq 0 ]; then
      case "$1" in
      --*=*)
        split=$1
        shift
        set -- "${split%%=*}" "${split#*=}" "$@"
        continue
        ;;
      --key)
        fusho_need_value "$1" "$#"
        prefix=${2:-}
        shift 2
        continue
        ;;
      --to)
        fusho_need_value "$1" "$#"
        targets="${targets}${2:-}
"
        shift 2
        continue
        ;;
      --keys-file)
        fusho_need_value "$1" "$#"
        if [ ! -f "${2:-}" ]; then
          fusho_die "key file '${2:-}' does not exist."
        fi
        keyfiles="${keyfiles}${2}
"
        shift 2
        continue
        ;;
      --json)
        as_json=1
        shift
        continue
        ;;
      --sign)
        fusho_need_value "$1" "$#"
        sign_as=${2:-}
        shift 2
        continue
        ;;
      --accept-new-key)
        accept_new=1
        shift
        continue
        ;;
      --qr)
        want_qr=1
        shift
        continue
        ;;
      --no-banner)
        no_banner=1
        shift
        continue
        ;;
      --expires)
        fusho_need_value "$1" "$#"
        expires=$(fusho_expiry_stamp "${2:-}") || exit 1
        shift 2
        continue
        ;;
      --no-clipboard)
        no_clipboard=1
        shift
        continue
        ;;
      --)
        literal=1
        shift
        continue
        ;;
      -*) fusho_die "unknown option '$1'. run 'fusho help' for usage." ;;
      *) ;;
      esac
    fi
    if [ -z "$target" ] && [ -z "$targets" ]; then target=$1; else message=$1; fi
    shift
  done
  if [ -n "$target" ]; then
    case "$target" in
    *:*)
      prefix=${target#*:}
      target=${target%%:*}
      ;;
    *) ;;
    esac
    targets="${target}
${targets}"
  fi
  if [ -z "$targets" ] && [ -z "$keyfiles" ] && fusho_interactive; then
    target=$(fusho_prompt_required "Send to, a GitHub user or user@host" "no recipient given. run 'fusho help' for usage.") || exit 1
    targets="${target}
"
  fi
  if [ -z "$targets" ] && [ -z "$keyfiles" ]; then
    fusho_die "no recipient given. run 'fusho help' for usage."
  fi
  fusho_send_run "$targets" "$keyfiles" "$prefix" "$message" "$no_clipboard" "$as_json" "$sign_as" "$accept_new" "$want_qr" "$expires" "$no_banner"
}

fusho_need_value() {
  if [ "$2" -lt 2 ]; then
    fusho_die "option '$1' needs a value. run 'fusho help' for usage."
  fi
}

fusho_send_run() {
  local targets="$1" keyfiles="$2" prefix="$3" message="$4" no_clipboard="$5" as_json="$6"
  local sign_as="$7" accept_new="$8" want_qr="$9"
  shift 9
  local expires="$1" no_banner="$2"
  local work supported selected selected_fps plaintext ciphertext armor alg copier tofile
  local sigfile="" signature="" encoding="" compressed="" signer="" delivery=""
  fusho_init_workspace
  work="$FUSHO_WORKSPACE"
  supported="${work}/supported.keys"
  selected="${work}/selected.keys"
  selected_fps="${work}/selected.fps"
  plaintext="${work}/plain"
  ciphertext="${work}/cipher"
  armor="${work}/armor"
  tofile="${work}/recipients"
  fusho_collect_recipients "$targets" "$keyfiles" "$supported" "$tofile" "$work" "$accept_new"
  fusho_select_keys "$supported" "$prefix" "$selected" "$selected_fps"
  if [ -n "$prefix" ]; then
    fusho_reject_bad_pin "$(head -1 "$tofile")" "$prefix" "$supported" "$selected_fps"
  fi
  fusho_read_plaintext "$plaintext" "$message"
  compressed="${work}/plain.gz"
  if fusho_compress "$plaintext" "$compressed"; then
    encoding="gzip"
    mv "$compressed" "$plaintext"
  fi
  if fusho_have age; then
    alg="age"
    fusho_encrypt_age "$selected" "$plaintext" "$ciphertext"
  else
    alg="rsa-oaep-sha1"
    fusho_warn "warning: age is not installed. falling back to RSA, which is size limited and provides no integrity check."
    fusho_encrypt_openssl "$selected" "$plaintext" "$ciphertext" "$work"
  fi
  if [ -n "$sign_as" ]; then
    sigfile="${work}/signature"
    signer=$(fusho_sign_identity "$sign_as" "$work") || exit 1
    fusho_sign_ciphertext "$signer" "$ciphertext" "$sigfile"
    signature=$(openssl base64 -A -in "$sigfile")
  fi
  fusho_emit_armor "$alg" "$tofile" "$selected_fps" "$ciphertext" "$sign_as" "$signature" "$encoding" "$expires" >"$armor"
  delivery="${work}/delivery"
  if [ "$no_banner" -eq 0 ] && fusho_banner_enabled; then
    {
      fusho_emit_banner
      printf '\n'
      cat "$armor"
    } >"$delivery"
  else
    cat "$armor" >"$delivery"
  fi
  if [ "$as_json" -eq 1 ]; then
    fusho_emit_json "$alg" "$tofile" "$selected_fps" "$armor"
  elif [ "$want_qr" -eq 1 ]; then
    fusho_emit_qr "$armor"
  else
    cat "$delivery"
  fi
  if [ "$no_clipboard" -eq 0 ]; then
    if copier=$(fusho_clipboard_copy "$delivery"); then
      fusho_warn "copied to the clipboard with ${copier}."
      fusho_clipboard_clear_later "$copier" "$delivery" "$FUSHO_CLIPBOARD_TIMEOUT"
    else
      fusho_warn "no clipboard tool found. copy the block above manually."
    fi
  fi
}

fusho_collect_recipients() {
  local targets="$1" keyfiles="$2" supported="$3" tofile="$4" work="$5" accept_new="$6"
  local target keyfile raw one count
  : >"$supported"
  : >"$tofile"
  printf '%s' "$targets" | while IFS= read -r target; do
    if [ -z "$target" ]; then continue; fi
    raw="${work}/raw-$(printf '%s' "$target" | tr -c 'a-zA-Z0-9' '_')"
    one="${raw}.supported"
    fusho_fetch_keys "$target" "$raw"
    fusho_supported_keys "$raw" >"$one"
    fusho_require_keys "$target" "$raw" "$one"
    fusho_fingerprints "$one" >"${one}.fps"
    fusho_warn_weak_keys "$one" "$target"
    fusho_trust_check "$target" "${one}.fps" "$accept_new"
    cat "$one" >>"$supported"
    printf '%s\n' "$target" >>"$tofile"
  done
  printf '%s' "$keyfiles" | while IFS= read -r keyfile; do
    if [ -z "$keyfile" ]; then continue; fi
    fusho_supported_keys "$keyfile" >>"$supported"
    printf '%s\n' "$(basename "$keyfile")" >>"$tofile"
  done
  if [ ! -s "$supported" ]; then
    fusho_die "no usable recipient key was collected."
  fi
  count=$(wc -l <"$supported" | tr -d ' ')
  if [ "$count" -eq 0 ]; then
    fusho_die "no usable recipient key was collected."
  fi
}

fusho_cmd_read() {
  local source="" identity_override="" literal=0 from_clipboard=0 require_sig=0 ignore_expiry=0
  local identity_command="" split=""
  while [ $# -gt 0 ]; do
    if [ "$literal" -eq 0 ]; then
      case "$1" in
      --*=*)
        split=$1
        shift
        set -- "${split%%=*}" "${split#*=}" "$@"
        continue
        ;;
      --identity)
        fusho_need_value "$1" "$#"
        identity_override=${2:-}
        shift 2
        continue
        ;;
      --identity-command)
        fusho_need_value "$1" "$#"
        identity_command=${2:-}
        shift 2
        continue
        ;;
      --clipboard)
        from_clipboard=1
        shift
        continue
        ;;
      --require-signature)
        require_sig=1
        shift
        continue
        ;;
      --ignore-expiry)
        ignore_expiry=1
        shift
        continue
        ;;
      --)
        literal=1
        shift
        continue
        ;;
      -*) fusho_die "unknown option '$1'. run 'fusho help' for usage." ;;
      *) ;;
      esac
    fi
    source=$1
    shift
  done
  fusho_read_run "$source" "$identity_override" "$from_clipboard" "$require_sig" "$ignore_expiry" "$identity_command"
}

fusho_read_run() {
  local source="$1" identity_override="$2" from_clipboard="$3" require_sig="$4" ignore_expiry="$5"
  local identity_command="$6"
  local work input keys ciphertext alg identity from signature sigfile
  fusho_init_workspace
  work="$FUSHO_WORKSPACE"
  input="${work}/input"
  keys="${work}/addressed.fps"
  ciphertext="${work}/cipher"
  if [ -n "$source" ]; then
    if [ ! -f "$source" ]; then
      fusho_die "file '${source}' does not exist."
    fi
    tr -d '\r' <"$source" >"$input"
  elif [ "$from_clipboard" -eq 1 ] || fusho_interactive; then
    if fusho_clipboard_paste >"${input}.clipboard" 2>/dev/null && fusho_has_armor "${input}.clipboard"; then
      tr -d '\r' <"${input}.clipboard" >"$input"
      fusho_warn "reading the message from the clipboard."
    elif [ "$from_clipboard" -eq 0 ] && fusho_interactive; then
      printf '%s\n' "Paste the fusho message, then press Ctrl-D on an empty line:" >&2
      tr -d '\r' >"$input"
    else
      fusho_die "nothing to read. pipe a message in, pass a file, or copy one to the clipboard."
    fi
  else
    tr -d '\r' >"$input"
  fi
  fusho_require_armor "$input"
  fusho_armor_field "$input" "key" >"$keys"
  if [ ! -s "$keys" ]; then
    fusho_die "the fusho message has no key header, so fusho cannot tell which identity to use."
  fi
  alg=$(fusho_armor_field "$input" "alg" | head -1)
  if ! fusho_armor_body "$input" | tr -d '\n' | openssl base64 -d -A -out "$ciphertext" 2>/dev/null; then
    fusho_die "the message body is not valid base64. the paste may be incomplete."
  fi
  from=$(fusho_armor_field "$input" "from" | head -1)
  signature=$(fusho_armor_field "$input" "sig" | head -1)
  if [ -n "$from" ] && [ -n "$signature" ]; then
    sigfile="${work}/signature"
    printf '%s' "$signature" | openssl base64 -d -A -out "$sigfile"
    fusho_verify_signature "$from" "$ciphertext" "$sigfile" "$work"
  elif [ "$require_sig" -eq 1 ]; then
    fusho_die "this message carries no signature and --require-signature was given."
  fi
  fusho_check_expiry "$(fusho_armor_field "$input" "exp" | head -1)" "$ignore_expiry"
  if [ -n "$identity_command" ]; then
    identity="${work}/identity"
    if ! (umask 077 && $identity_command >"$identity"); then
      fusho_die "the identity command failed: ${identity_command}"
    fi
    if [ ! -s "$identity" ]; then
      fusho_die "the identity command produced nothing: ${identity_command}"
    fi
  else
    identity=$(fusho_resolve_identity "$keys" "$identity_override") || exit 1
    fusho_require_passphrase_channel "$identity"
  fi
  case "$alg" in
  age)
    if ! fusho_have age; then
      fusho_die "this message needs age to open. install it with: brew install age, or apt install age."
    fi
    fusho_decrypt_age "$identity" "$ciphertext" >"${work}/plainout"
    ;;
  rsa-oaep-sha1) fusho_decrypt_openssl "$identity" "$ciphertext" >"${work}/plainout" ;;
  *) fusho_die "unknown algorithm '${alg}'. this message may come from a newer fusho." ;;
  esac
  if [ "$(fusho_armor_field "$input" "enc" | head -1)" = "gzip" ]; then
    fusho_decompress "${work}/plainout"
  else
    cat "${work}/plainout"
  fi
}

fusho_cmd_keys() {
  local user="${1:-}"
  local work raw supported
  if [ -z "$user" ] && fusho_interactive; then
    user=$(fusho_prompt_required "Whose keys, a GitHub user or user@host" "no user given. run 'fusho help' for usage.") || exit 1
  fi
  if [ -z "$user" ]; then
    fusho_die "no user given. run 'fusho help' for usage."
  fi
  fusho_init_workspace
  work="$FUSHO_WORKSPACE"
  raw="${work}/raw.keys"
  supported="${work}/supported.keys"
  fusho_fetch_keys "$user" "$raw"
  fusho_supported_keys "$raw" >"$supported"
  fusho_require_keys "$user" "$raw" "$supported"
  ssh-keygen -lf "$supported" | awk '{type=$NF; gsub(/[()]/, "", type); printf "%-10s %s %s bits\n", type, $2, $1}'
}

fusho_doctor_line() {
  local label="$1" state="$2" detail="$3"
  printf '%-18s %-8s %s\n' "$label" "$state" "$detail"
}

fusho_flavor_version() {
  printf '%s\n' "$1" | awk '{
    for (i = 1; i <= NF; i++) {
      t = $i
      gsub(/[,;()]/, "", t)
      sub(/^v/, "", t)
      if (t ~ /^[0-9]+(\.[0-9]+)+[a-z0-9]*$/ || t ~ /^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]$/) { print t; exit }
    }
  }'
}

fusho_tool_flavor() {
  local raw text version name os
  raw=$("$1" --version 2>&1 </dev/null) || true
  text=$(printf '%s\n' "$raw" | sed -n '1p')
  version=$(fusho_flavor_version "$text")
  os=${FUSHO_OS:-}
  [ -n "$os" ] || os=$(uname -s)
  case "$text" in
  *uutils*) name=uutils ;;
  *BusyBox*) name=busybox ;;
  *GNU* | *GLIBC* | *"(coreutils)"* | *"(diffutils)"*) name=gnu ;;
  *mawk*) name=mawk ;;
  *"awk version"* | *"(Darwin)"*) name=bsd ;;
  *)
    version=""
    case "$1:$os" in
    *uutils*:* | */cargo/*:*) name=uutils ;;
    *:Darwin | *:*BSD) name=bsd ;;
    *) name=unknown ;;
    esac
    ;;
  esac
  printf '%s%s\n' "$name" "${version:+ $version}"
}

fusho_doctor_tool() {
  local name="$1" remedy="$2" note="${3:-}" found
  found=$(command -v "$name" 2>/dev/null || true)
  if [ -n "$found" ]; then
    fusho_doctor_line "$name" "ok" "${found}${note:+, ${note}}"
    return 0
  fi
  fusho_doctor_line "$name" "missing" "$remedy"
  return 1
}

fusho_cmd_doctor() {
  local failures=0 flavor note="" tool
  if fusho_have age; then
    note=$(age --version 2>/dev/null || true)
  fi
  fusho_doctor_tool age "install with: brew install age, or apt install age" "$note" || failures=$((failures + 1))
  fusho_doctor_tool curl "curl is required to fetch keys from GitHub" || failures=$((failures + 1))
  fusho_doctor_tool ssh-keygen "install openssh" || failures=$((failures + 1))
  for tool in awk sed tr date; do
    note=""
    if fusho_have "$tool"; then
      note=$(fusho_tool_flavor "$(command -v "$tool")")
    fi
    fusho_doctor_tool "$tool" "required" "$note" || failures=$((failures + 1))
  done
  flavor=$(fusho_openssl_flavor)
  case "$flavor" in
  openssl) note="OpenSSL" ;;
  libressl) note="LibreSSL. the RSA fallback pins OAEP to SHA-1 so it interoperates with OpenSSL" ;;
  *) note="" ;;
  esac
  fusho_doctor_tool openssl "install openssl" "$note" || failures=$((failures + 1))
  fusho_doctor_identities
  if [ "$failures" -gt 0 ]; then
    exit 1
  fi
}

fusho_doctor_identities() {
  local pub count=0
  for pub in "$HOME"/.ssh/*.pub; do
    if [ -f "$pub" ] && [ -f "${pub%.pub}" ]; then
      count=$((count + 1))
    fi
  done
  if [ "$count" -gt 0 ]; then
    fusho_doctor_line "identities" "ok" "${count} usable key pair(s) under ~/.ssh"
  else
    fusho_doctor_line "identities" "warn" "no key pair found under ~/.ssh. you can receive nothing until you add one"
  fi
}

fusho_cmd_version() {
  local engine
  engine="rsa-oaep-sha1 via $(fusho_openssl_flavor)"
  if fusho_have age; then
    engine="age"
  fi
  printf 'fusho %s\nengine: %s\n' "$(fusho_version)" "$engine"
}

fusho_usage() {
  cat <<'USAGE'
fusho - send encrypted messages through any chat, using GitHub SSH keys

usage:
  fusho                       ask what to do, step by step
  fusho send <user>[@host][:<fingerprint-prefix>] [message]
                              encrypt a message to one or more people
  fusho read [file]           decrypt a message from a file, a pipe or the
                              clipboard
  fusho keys <user>[@host]    list the keys someone publishes
  fusho doctor                check the tools fusho needs
  fusho version               print the version and the encryption engine
  fusho help                  print this page

options:
  --to <target>       add a recipient. repeat for several
  --keys-file <path>  add recipients from a local public key file
  --key <prefix>      encrypt to one key only, chosen by fingerprint prefix
  --json              print machine readable output
  --sign <you>        sign as a user whose published key you hold
  --accept-new-key    accept a recipient whose pinned keys changed
  --qr                print the message as a QR code instead of text
  --expires <when>    mark the message stale after 30m, 6h, 7d and so on
  --no-banner         omit the short note telling the recipient what this is
  --identity <path>   decrypt with a specific private key
  --identity-command <cmd>  read the private key from a command, for a key
                      that lives in a secret manager rather than on disk
  --clipboard         read the message from the clipboard
  --require-signature refuse a message that carries no signature
  --ignore-expiry     open a message the sender marked as expired
  --no-clipboard      do not copy the result to the clipboard

hosts:
  github is the default. gitlab, codeberg and sourcehut are known, and any
  other value is treated as a self-hosted forge serving <host>/<user>.keys.
  Bitbucket has no public key endpoint, so use --keys-file for it.

notes:
  Run fusho, send, read or keys in a terminal without the values they need
  and fusho asks for each one. Every value can still be given on the command
  line, which is what scripts should do.

  Passing the message as an argument makes it visible to other users of this
  machine through the process list. Piping it on stdin avoids that.

examples:
  fusho send alice 'database password: correct-horse'
  fusho send bob@gitlab 'works across forges'
  fusho send --to alice --to bob@codeberg 'one message, two people'
  fusho send --sign you alice 'signed, so alice knows it came from you'
  printf 'secret' | fusho send alice
  pbpaste | fusho read
  fusho read message.txt
USAGE
}
