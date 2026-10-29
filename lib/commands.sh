#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${FUSHO_LIB:?}/state.sh"

fusho_cmd_send() {
  fusho_cs_prefix=""
  fusho_cs_message=""
  fusho_cs_no_clipboard=0
  fusho_cs_target=""
  fusho_cs_literal=0
  fusho_cs_targets=""
  fusho_cs_keyfiles=""
  fusho_cs_as_json=0
  fusho_cs_sign_as=""
  fusho_cs_accept_new=0
  fusho_cs_want_qr=0
  fusho_cs_expires=""
  fusho_cs_no_banner=0
  fusho_cs_split=""
  while [ $# -gt 0 ]; do
    if [ "${fusho_cs_literal}" -eq 0 ]; then
      case "$1" in
      --*=*)
        fusho_cs_split=$1
        shift
        set -- "${fusho_cs_split%%=*}" "${fusho_cs_split#*=}" "$@"
        continue
        ;;
      --key)
        fusho_need_value "$1" "$#"
        fusho_cs_prefix=${2:-}
        shift 2
        continue
        ;;
      --to)
        fusho_need_value "$1" "$#"
        fusho_cs_targets="${fusho_cs_targets}${2:-}
"
        shift 2
        continue
        ;;
      --keys-file)
        fusho_need_value "$1" "$#"
        if [ ! -f "${2:-}" ]; then
          fusho_die "key file '${2:-}' does not exist."
        fi
        fusho_cs_keyfiles="${fusho_cs_keyfiles}${2}
"
        shift 2
        continue
        ;;
      --json)
        fusho_cs_as_json=1
        shift
        continue
        ;;
      --sign)
        fusho_need_value "$1" "$#"
        fusho_cs_sign_as=${2:-}
        shift 2
        continue
        ;;
      --accept-new-key)
        fusho_cs_accept_new=1
        shift
        continue
        ;;
      --qr)
        fusho_cs_want_qr=1
        shift
        continue
        ;;
      --no-banner)
        fusho_cs_no_banner=1
        shift
        continue
        ;;
      --expires)
        fusho_need_value "$1" "$#"
        fusho_cs_expires=$(fusho_expiry_stamp "${2:-}") || exit 1
        shift 2
        continue
        ;;
      --no-clipboard)
        fusho_cs_no_clipboard=1
        shift
        continue
        ;;
      --)
        fusho_cs_literal=1
        shift
        continue
        ;;
      -*) fusho_die "unknown option '$1'. run 'fusho help' for usage." ;;
      *) ;;
      esac
    fi
    if [ -z "${fusho_cs_target}" ] && [ -z "${fusho_cs_targets}" ]; then fusho_cs_target=$1; else fusho_cs_message=$1; fi
    shift
  done
  if [ -n "${fusho_cs_target}" ]; then
    case "${fusho_cs_target}" in
    *:*)
      fusho_cs_prefix=${fusho_cs_target#*:}
      fusho_cs_target=${fusho_cs_target%%:*}
      ;;
    *) ;;
    esac
    fusho_cs_targets="${fusho_cs_target}
${fusho_cs_targets}"
  fi
  if [ -z "${fusho_cs_targets}" ] && [ -z "${fusho_cs_keyfiles}" ] && fusho_interactive; then
    fusho_cs_target=$(fusho_prompt_required "Send to, a GitHub user or user@host" "no recipient given. run 'fusho help' for usage.") || exit 1
    fusho_cs_targets="${fusho_cs_target}
"
  fi
  if [ -z "${fusho_cs_targets}" ] && [ -z "${fusho_cs_keyfiles}" ]; then
    fusho_die "no recipient given. run 'fusho help' for usage."
  fi
  fusho_send_run "${fusho_cs_targets}" "${fusho_cs_keyfiles}" "${fusho_cs_prefix}" "${fusho_cs_message}" "${fusho_cs_no_clipboard}" "${fusho_cs_as_json}" "${fusho_cs_sign_as}" "${fusho_cs_accept_new}" "${fusho_cs_want_qr}" "${fusho_cs_expires}" "${fusho_cs_no_banner}"
}

fusho_need_value() {
  if [ "$2" -lt 2 ]; then
    fusho_die "option '$1' needs a value. run 'fusho help' for usage."
  fi
}

fusho_send_run() {
  fusho_sr_targets="$1"
  fusho_sr_keyfiles="$2"
  fusho_sr_prefix="$3"
  fusho_sr_message="$4"
  fusho_sr_no_clipboard="$5"
  fusho_sr_as_json="$6"
  fusho_sr_sign_as="$7"
  fusho_sr_accept_new="$8"
  fusho_sr_want_qr="$9"
  shift 9
  fusho_sr_expires="$1"
  fusho_sr_no_banner="$2"
  fusho_sr_work=""
  fusho_sr_supported=""
  fusho_sr_selected=""
  fusho_sr_selected_fps=""
  fusho_sr_plaintext=""
  fusho_sr_ciphertext=""
  fusho_sr_armor=""
  fusho_sr_alg=""
  fusho_sr_copier=""
  fusho_sr_tofile=""
  fusho_sr_sigfile=""
  fusho_sr_signature=""
  fusho_sr_encoding=""
  fusho_sr_compressed=""
  fusho_sr_signer=""
  fusho_sr_delivery=""
  fusho_init_workspace
  fusho_sr_work="${FUSHO_WORKSPACE}"
  fusho_sr_supported="${fusho_sr_work}/supported.keys"
  fusho_sr_selected="${fusho_sr_work}/selected.keys"
  fusho_sr_selected_fps="${fusho_sr_work}/selected.fps"
  fusho_sr_plaintext="${fusho_sr_work}/plain"
  fusho_sr_ciphertext="${fusho_sr_work}/cipher"
  fusho_sr_armor="${fusho_sr_work}/armor"
  fusho_sr_tofile="${fusho_sr_work}/recipients"
  fusho_collect_recipients "${fusho_sr_targets}" "${fusho_sr_keyfiles}" "${fusho_sr_supported}" "${fusho_sr_tofile}" "${fusho_sr_work}" "${fusho_sr_accept_new}"
  fusho_select_keys "${fusho_sr_supported}" "${fusho_sr_prefix}" "${fusho_sr_selected}" "${fusho_sr_selected_fps}"
  if [ -n "${fusho_sr_prefix}" ]; then
    fusho_sr_first=$(head -1 "${fusho_sr_tofile}")
    fusho_reject_bad_pin "${fusho_sr_first}" "${fusho_sr_prefix}" "${fusho_sr_supported}" "${fusho_sr_selected_fps}"
  fi
  fusho_read_plaintext "${fusho_sr_plaintext}" "${fusho_sr_message}"
  fusho_sr_compressed="${fusho_sr_work}/plain.gz"
  if fusho_compress "${fusho_sr_plaintext}" "${fusho_sr_compressed}"; then
    fusho_sr_encoding="gzip"
    mv "${fusho_sr_compressed}" "${fusho_sr_plaintext}"
  fi
  if fusho_have age; then
    fusho_sr_alg="age"
    fusho_encrypt_age "${fusho_sr_selected}" "${fusho_sr_plaintext}" "${fusho_sr_ciphertext}"
  else
    fusho_sr_alg="rsa-oaep-sha1"
    fusho_warn "warning: age is not installed. falling back to RSA, which is size limited and provides no integrity check."
    fusho_encrypt_openssl "${fusho_sr_selected}" "${fusho_sr_plaintext}" "${fusho_sr_ciphertext}" "${fusho_sr_work}"
  fi
  if [ -n "${fusho_sr_sign_as}" ]; then
    fusho_sr_sigfile="${fusho_sr_work}/signature"
    fusho_sr_signer=$(fusho_sign_identity "${fusho_sr_sign_as}" "${fusho_sr_work}") || exit 1
    fusho_sign_ciphertext "${fusho_sr_signer}" "${fusho_sr_ciphertext}" "${fusho_sr_sigfile}"
    fusho_sr_signature=$(openssl base64 -A -in "${fusho_sr_sigfile}")
  fi
  fusho_emit_armor "${fusho_sr_alg}" "${fusho_sr_tofile}" "${fusho_sr_selected_fps}" "${fusho_sr_ciphertext}" "${fusho_sr_sign_as}" "${fusho_sr_signature}" "${fusho_sr_encoding}" "${fusho_sr_expires}" >"${fusho_sr_armor}"
  fusho_sr_delivery="${fusho_sr_work}/delivery"
  if [ "${fusho_sr_no_banner}" -eq 0 ] && fusho_banner_enabled; then
    {
      fusho_emit_banner
      printf '\n'
      cat "${fusho_sr_armor}"
    } >"${fusho_sr_delivery}"
  else
    cat "${fusho_sr_armor}" >"${fusho_sr_delivery}"
  fi
  if [ "${fusho_sr_as_json}" -eq 1 ]; then
    fusho_emit_json "${fusho_sr_alg}" "${fusho_sr_tofile}" "${fusho_sr_selected_fps}" "${fusho_sr_armor}"
  elif [ "${fusho_sr_want_qr}" -eq 1 ]; then
    fusho_emit_qr "${fusho_sr_armor}"
  else
    cat "${fusho_sr_delivery}"
  fi
  if [ "${fusho_sr_no_clipboard}" -eq 0 ]; then
    if fusho_sr_copier=$(fusho_clipboard_copy "${fusho_sr_delivery}"); then
      fusho_warn "copied to the clipboard with ${fusho_sr_copier}."
      fusho_clipboard_clear_later "${fusho_sr_copier}" "${fusho_sr_delivery}" "${FUSHO_CLIPBOARD_TIMEOUT}"
    else
      fusho_warn "no clipboard tool found. copy the block above manually."
    fi
  fi
}

fusho_collect_recipients() {
  fusho_cr_targets="$1"
  fusho_cr_keyfiles="$2"
  fusho_cr_supported="$3"
  fusho_cr_tofile="$4"
  fusho_cr_work="$5"
  fusho_cr_accept_new="$6"
  fusho_cr_target=""
  fusho_cr_keyfile=""
  fusho_cr_raw=""
  fusho_cr_one=""
  fusho_cr_count=""
  : >"${fusho_cr_supported}"
  : >"${fusho_cr_tofile}"
  printf '%s' "${fusho_cr_targets}" | while IFS= read -r fusho_cr_target; do
    if [ -z "${fusho_cr_target}" ]; then continue; fi
    fusho_cr_raw="${fusho_cr_work}/raw-$(printf '%s' "${fusho_cr_target}" | tr -c 'a-zA-Z0-9' '_')"
    fusho_cr_one="${fusho_cr_raw}.supported"
    fusho_fetch_keys "${fusho_cr_target}" "${fusho_cr_raw}"
    fusho_supported_keys "${fusho_cr_raw}" >"${fusho_cr_one}"
    fusho_require_keys "${fusho_cr_target}" "${fusho_cr_raw}" "${fusho_cr_one}"
    fusho_fingerprints "${fusho_cr_one}" >"${fusho_cr_one}.fps"
    fusho_warn_weak_keys "${fusho_cr_one}" "${fusho_cr_target}"
    fusho_trust_check "${fusho_cr_target}" "${fusho_cr_one}.fps" "${fusho_cr_accept_new}"
    cat "${fusho_cr_one}" >>"${fusho_cr_supported}"
    printf '%s\n' "${fusho_cr_target}" >>"${fusho_cr_tofile}"
  done
  printf '%s' "${fusho_cr_keyfiles}" | while IFS= read -r fusho_cr_keyfile; do
    if [ -z "${fusho_cr_keyfile}" ]; then continue; fi
    fusho_supported_keys "${fusho_cr_keyfile}" >>"${fusho_cr_supported}"
    printf '%s\n' "$(basename "${fusho_cr_keyfile}")" >>"${fusho_cr_tofile}"
  done
  if [ ! -s "${fusho_cr_supported}" ]; then
    fusho_die "no usable recipient key was collected."
  fi
  fusho_cr_count=$(wc -l <"${fusho_cr_supported}" | tr -d ' ')
  if [ "${fusho_cr_count}" -eq 0 ]; then
    fusho_die "no usable recipient key was collected."
  fi
}

fusho_cmd_read() {
  fusho_cr2_source=""
  fusho_cr2_identity_override=""
  fusho_cr2_literal=0
  fusho_cr2_from_clipboard=0
  fusho_cr2_require_sig=0
  fusho_cr2_ignore_expiry=0
  fusho_cr2_identity_command=""
  fusho_cr2_split=""
  while [ $# -gt 0 ]; do
    if [ "${fusho_cr2_literal}" -eq 0 ]; then
      case "$1" in
      --*=*)
        fusho_cr2_split=$1
        shift
        set -- "${fusho_cr2_split%%=*}" "${fusho_cr2_split#*=}" "$@"
        continue
        ;;
      --identity)
        fusho_need_value "$1" "$#"
        fusho_cr2_identity_override=${2:-}
        shift 2
        continue
        ;;
      --identity-command)
        fusho_need_value "$1" "$#"
        fusho_cr2_identity_command=${2:-}
        shift 2
        continue
        ;;
      --clipboard)
        fusho_cr2_from_clipboard=1
        shift
        continue
        ;;
      --require-signature)
        fusho_cr2_require_sig=1
        shift
        continue
        ;;
      --ignore-expiry)
        fusho_cr2_ignore_expiry=1
        shift
        continue
        ;;
      --)
        fusho_cr2_literal=1
        shift
        continue
        ;;
      -*) fusho_die "unknown option '$1'. run 'fusho help' for usage." ;;
      *) ;;
      esac
    fi
    fusho_cr2_source=$1
    shift
  done
  fusho_read_run "${fusho_cr2_source}" "${fusho_cr2_identity_override}" "${fusho_cr2_from_clipboard}" "${fusho_cr2_require_sig}" "${fusho_cr2_ignore_expiry}" "${fusho_cr2_identity_command}"
}

fusho_read_run() {
  fusho_rr_source="$1"
  fusho_rr_identity_override="$2"
  fusho_rr_from_clipboard="$3"
  fusho_rr_require_sig="$4"
  fusho_rr_ignore_expiry="$5"
  fusho_rr_identity_command="$6"
  fusho_rr_work=""
  fusho_rr_input=""
  fusho_rr_keys=""
  fusho_rr_ciphertext=""
  fusho_rr_alg=""
  fusho_rr_identity=""
  fusho_rr_from=""
  fusho_rr_signature=""
  fusho_rr_sigfile=""
  fusho_init_workspace
  fusho_rr_work="${FUSHO_WORKSPACE}"
  fusho_rr_input="${fusho_rr_work}/input"
  fusho_rr_keys="${fusho_rr_work}/addressed.fps"
  fusho_rr_ciphertext="${fusho_rr_work}/cipher"
  if [ -n "${fusho_rr_source}" ]; then
    if [ ! -f "${fusho_rr_source}" ]; then
      fusho_die "file '${fusho_rr_source}' does not exist."
    fi
    tr -d '\r' <"${fusho_rr_source}" >"${fusho_rr_input}"
  elif [ "${fusho_rr_from_clipboard}" -eq 1 ] || fusho_interactive; then
    if fusho_clipboard_paste >"${fusho_rr_input}.clipboard" 2>/dev/null && fusho_has_armor "${fusho_rr_input}.clipboard"; then
      tr -d '\r' <"${fusho_rr_input}.clipboard" >"${fusho_rr_input}"
      fusho_warn "reading the message from the clipboard."
    elif [ "${fusho_rr_from_clipboard}" -eq 0 ] && fusho_interactive; then
      printf '%s\n' "Paste the fusho message, then press Ctrl-D on an empty line:" >&2
      tr -d '\r' >"${fusho_rr_input}"
    else
      fusho_die "nothing to read. pipe a message in, pass a file, or copy one to the clipboard."
    fi
  else
    tr -d '\r' >"${fusho_rr_input}"
  fi
  fusho_require_armor "${fusho_rr_input}"
  fusho_armor_field "${fusho_rr_input}" "key" >"${fusho_rr_keys}"
  if [ ! -s "${fusho_rr_keys}" ]; then
    fusho_die "the fusho message has no key header, so fusho cannot tell which identity to use."
  fi
  fusho_rr_alg=$(fusho_armor_field "${fusho_rr_input}" "alg" | head -1)
  fusho_armor_body "${fusho_rr_input}" | tr -d '\n' >"${fusho_rr_work}/body"
  if ! fusho_base64_valid "${fusho_rr_work}/body" || ! openssl base64 -d -A -in "${fusho_rr_work}/body" -out "${fusho_rr_ciphertext}" 2>/dev/null; then
    fusho_die "the message body is not valid base64. the paste may be incomplete."
  fi
  fusho_rr_from=$(fusho_armor_field "${fusho_rr_input}" "from" | head -1)
  fusho_rr_signature=$(fusho_armor_field "${fusho_rr_input}" "sig" | head -1)
  if [ -n "${fusho_rr_from}" ] && [ -n "${fusho_rr_signature}" ]; then
    fusho_rr_sigfile="${fusho_rr_work}/signature"
    printf '%s' "${fusho_rr_signature}" | openssl base64 -d -A -out "${fusho_rr_sigfile}"
    fusho_verify_signature "${fusho_rr_from}" "${fusho_rr_ciphertext}" "${fusho_rr_sigfile}" "${fusho_rr_work}"
  elif [ "${fusho_rr_require_sig}" -eq 1 ]; then
    fusho_die "this message carries no signature and --require-signature was given."
  fi
  fusho_rr_expiry=$(fusho_armor_field "${fusho_rr_input}" "exp" | head -1)
  fusho_check_expiry "${fusho_rr_expiry}" "${fusho_rr_ignore_expiry}"
  if [ -n "${fusho_rr_identity_command}" ]; then
    fusho_rr_identity="${fusho_rr_work}/identity"
    if ! (umask 077 && ${fusho_rr_identity_command} >"${fusho_rr_identity}"); then
      fusho_die "the identity command failed: ${fusho_rr_identity_command}"
    fi
    if [ ! -s "${fusho_rr_identity}" ]; then
      fusho_die "the identity command produced nothing: ${fusho_rr_identity_command}"
    fi
  else
    fusho_rr_identity=$(fusho_resolve_identity "${fusho_rr_keys}" "${fusho_rr_identity_override}") || exit 1
    fusho_require_passphrase_channel "${fusho_rr_identity}"
  fi
  case "${fusho_rr_alg}" in
  age)
    if ! fusho_have age; then
      fusho_die "this message needs age to open. install it with: brew install age, or apt install age."
    fi
    fusho_decrypt_age "${fusho_rr_identity}" "${fusho_rr_ciphertext}" >"${fusho_rr_work}/plainout"
    ;;
  rsa-oaep-sha1) fusho_decrypt_openssl "${fusho_rr_identity}" "${fusho_rr_ciphertext}" >"${fusho_rr_work}/plainout" ;;
  *) fusho_die "unknown algorithm '${fusho_rr_alg}'. this message may come from a newer fusho." ;;
  esac
  fusho_rr_encoding=$(fusho_armor_field "${fusho_rr_input}" "enc" | head -1)
  if [ "${fusho_rr_encoding}" = "gzip" ]; then
    fusho_decompress "${fusho_rr_work}/plainout"
  else
    cat "${fusho_rr_work}/plainout"
  fi
}

fusho_cmd_keys() {
  fusho_ck_user="${1:-}"
  fusho_ck_work=""
  fusho_ck_raw=""
  fusho_ck_supported=""
  if [ -z "${fusho_ck_user}" ] && fusho_interactive; then
    fusho_ck_user=$(fusho_prompt_required "Whose keys, a GitHub user or user@host" "no user given. run 'fusho help' for usage.") || exit 1
  fi
  if [ -z "${fusho_ck_user}" ]; then
    fusho_die "no user given. run 'fusho help' for usage."
  fi
  fusho_init_workspace
  fusho_ck_work="${FUSHO_WORKSPACE}"
  fusho_ck_raw="${fusho_ck_work}/raw.keys"
  fusho_ck_supported="${fusho_ck_work}/supported.keys"
  fusho_fetch_keys "${fusho_ck_user}" "${fusho_ck_raw}"
  fusho_supported_keys "${fusho_ck_raw}" >"${fusho_ck_supported}"
  fusho_require_keys "${fusho_ck_user}" "${fusho_ck_raw}" "${fusho_ck_supported}"
  ssh-keygen -lf "${fusho_ck_supported}" | awk '{type=$NF; gsub(/[()]/, "", type); printf "%-10s %s %s bits\n", type, $2, $1}'
}

fusho_doctor_line() {
  fusho_dl_label="$1"
  fusho_dl_state="$2"
  fusho_dl_detail="$3"
  printf '%-18s %-8s %s\n' "${fusho_dl_label}" "${fusho_dl_state}" "${fusho_dl_detail}"
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
  fusho_tf_raw=""
  fusho_tf_text=""
  fusho_tf_version=""
  fusho_tf_name=""
  fusho_tf_os=""
  fusho_tf_raw=$("$1" --version 2>&1 </dev/null) || true
  fusho_tf_text=$(printf '%s\n' "${fusho_tf_raw}" | sed -n '1p')
  fusho_tf_version=$(fusho_flavor_version "${fusho_tf_text}")
  fusho_tf_os=${FUSHO_OS:-}
  [ -n "${fusho_tf_os}" ] || fusho_tf_os=$(uname -s)
  case "${fusho_tf_text}" in
  *uutils*) fusho_tf_name=uutils ;;
  *BusyBox*) fusho_tf_name=busybox ;;
  *GNU* | *GLIBC* | *"(coreutils)"* | *"(diffutils)"*) fusho_tf_name=gnu ;;
  *mawk*) fusho_tf_name=mawk ;;
  *"awk version"* | *"(Darwin)"*) fusho_tf_name=bsd ;;
  *)
    fusho_tf_version=""
    case "$1:${fusho_tf_os}" in
    *uutils*:* | */cargo/*:*) fusho_tf_name=uutils ;;
    *:Darwin | *:*BSD) fusho_tf_name=bsd ;;
    *) fusho_tf_name=unknown ;;
    esac
    ;;
  esac
  printf '%s%s\n' "${fusho_tf_name}" "${fusho_tf_version:+ ${fusho_tf_version}}"
}

fusho_doctor_tool() {
  fusho_dt_name="$1"
  fusho_dt_remedy="$2"
  fusho_dt_note="${3:-}"
  fusho_dt_found=""
  fusho_dt_found=$(command -v "${fusho_dt_name}" 2>/dev/null || true)
  if [ -n "${fusho_dt_found}" ]; then
    fusho_doctor_line "${fusho_dt_name}" "ok" "${fusho_dt_found}${fusho_dt_note:+, ${fusho_dt_note}}"
    return 0
  fi
  fusho_doctor_line "${fusho_dt_name}" "missing" "${fusho_dt_remedy}"
  return 1
}

fusho_cmd_doctor() {
  fusho_cd_failures=0
  fusho_cd_flavor=""
  fusho_cd_note=""
  fusho_cd_tool=""
  if fusho_have age; then
    fusho_cd_note=$(age --version 2>/dev/null || true)
  fi
  fusho_doctor_tool age "install with: brew install age, or apt install age" "${fusho_cd_note}" || fusho_cd_failures=$((fusho_cd_failures + 1))
  fusho_doctor_tool curl "curl is required to fetch keys from GitHub" || fusho_cd_failures=$((fusho_cd_failures + 1))
  fusho_doctor_tool ssh-keygen "install openssh" || fusho_cd_failures=$((fusho_cd_failures + 1))
  for fusho_cd_tool in awk sed tr date; do
    fusho_cd_note=""
    if fusho_have "${fusho_cd_tool}"; then
      fusho_cd_path=$(command -v "${fusho_cd_tool}")
      fusho_cd_note=$(fusho_tool_flavor "${fusho_cd_path}")
    fi
    fusho_doctor_tool "${fusho_cd_tool}" "required" "${fusho_cd_note}" || fusho_cd_failures=$((fusho_cd_failures + 1))
  done
  fusho_cd_flavor=$(fusho_openssl_flavor)
  case "${fusho_cd_flavor}" in
  openssl) fusho_cd_note="OpenSSL" ;;
  libressl) fusho_cd_note="LibreSSL. the RSA fallback pins OAEP to SHA-1 so it interoperates with OpenSSL" ;;
  *) fusho_cd_note="" ;;
  esac
  fusho_doctor_tool openssl "install openssl" "${fusho_cd_note}" || fusho_cd_failures=$((fusho_cd_failures + 1))
  fusho_doctor_identities
  if [ "${fusho_cd_failures}" -gt 0 ]; then
    exit 1
  fi
}

fusho_doctor_identities() {
  fusho_di_pub=""
  fusho_di_count=0
  for fusho_di_pub in "${HOME}"/.ssh/*.pub; do
    if [ -f "${fusho_di_pub}" ] && [ -f "${fusho_di_pub%.pub}" ]; then
      fusho_di_count=$((fusho_di_count + 1))
    fi
  done
  if [ "${fusho_di_count}" -gt 0 ]; then
    fusho_doctor_line "identities" "ok" "${fusho_di_count} usable key pair(s) under ~/.ssh"
  else
    fusho_doctor_line "identities" "warn" "no key pair found under ~/.ssh. you can receive nothing until you add one"
  fi
}

fusho_cmd_version() {
  fusho_cv_engine=""
  fusho_cv_engine="rsa-oaep-sha1 via $(fusho_openssl_flavor)"
  if fusho_have age; then
    fusho_cv_engine="age"
  fi
  fusho_cv_version=$(fusho_version)
  printf 'fusho %s\nengine: %s\n' "${fusho_cv_version}" "${fusho_cv_engine}"
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
