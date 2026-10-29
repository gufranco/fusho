#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${FUSHO_LIB:?}/state.sh"

fusho_clipboard_copy() {
  fusho_cc_file="$1"
  if [ -n "${FUSHO_CLIPBOARD_COPY}" ]; then
    ${FUSHO_CLIPBOARD_COPY} <"${fusho_cc_file}" >/dev/null 2>&1 && printf '%s\n' "${FUSHO_CLIPBOARD_COPY}" && return 0
  fi
  if fusho_have pbcopy; then
    pbcopy <"${fusho_cc_file}" && printf 'pbcopy\n' && return 0
  fi
  if fusho_have wl-copy; then
    wl-copy <"${fusho_cc_file}" && printf 'wl-copy\n' && return 0
  fi
  if fusho_have xclip; then
    xclip -selection clipboard <"${fusho_cc_file}" && printf 'xclip\n' && return 0
  fi
  if fusho_have xsel; then
    xsel --clipboard --input <"${fusho_cc_file}" && printf 'xsel\n' && return 0
  fi
  return 1
}

fusho_read_plaintext() {
  fusho_rp_dest="$1"
  fusho_rp_message="$2"
  if [ -n "${fusho_rp_message}" ]; then
    printf '%s\n' "${fusho_rp_message}" >"${fusho_rp_dest}"
  else
    if fusho_interactive; then
      printf '%s\n' "Type the message, then press Ctrl-D on an empty line:" >&2
    fi
    cat >"${fusho_rp_dest}"
  fi
  if [ ! -s "${fusho_rp_dest}" ]; then
    fusho_die "refusing to send an empty message."
  fi
}

fusho_clipboard_paste() {
  if [ -n "${FUSHO_CLIPBOARD_PASTE}" ]; then
    ${FUSHO_CLIPBOARD_PASTE} && return 0
    return 1
  fi
  if fusho_have pbpaste; then
    pbpaste && return 0
  fi
  if fusho_have wl-paste; then
    wl-paste && return 0
  fi
  if fusho_have xclip; then
    xclip -selection clipboard -o && return 0
  fi
  if fusho_have xsel; then
    xsel --clipboard --output && return 0
  fi
  return 1
}

fusho_clipboard_clear_later() {
  fusho_ccl_copier="$1"
  fusho_ccl_armor="$2"
  fusho_ccl_seconds="$3"
  fusho_ccl_expected=""
  if [ "${fusho_ccl_seconds}" -le 0 ]; then
    return 0
  fi
  fusho_ccl_expected=$(cat "${fusho_ccl_armor}")
  (
    sleep "${fusho_ccl_seconds}"
    fusho_ccl_current=$(fusho_clipboard_paste 2>/dev/null) || fusho_ccl_current=""
    if [ "${fusho_ccl_current}" = "${fusho_ccl_expected}" ]; then
      # shellcheck disable=SC2086
      printf '' | ${fusho_ccl_copier} >/dev/null 2>&1 || true
    fi
  ) >/dev/null 2>&1 &
}

fusho_compress() {
  fusho_c_plain="$1"
  fusho_c_dest="$2"
  if ! fusho_have gzip; then
    return 1
  fi
  if ! gzip -c "${fusho_c_plain}" >"${fusho_c_dest}" 2>/dev/null; then
    return 1
  fi
  fusho_c_packed=$(wc -c <"${fusho_c_dest}" | tr -d " ")
  fusho_c_original=$(wc -c <"${fusho_c_plain}" | tr -d " ")
  if [ "${fusho_c_packed}" -ge "${fusho_c_original}" ]; then
    return 1
  fi
  return 0
}

fusho_decompress() {
  fusho_d_src="$1"
  if ! fusho_have gunzip; then
    fusho_die "this message is compressed and gunzip is not installed."
  fi
  gunzip -c "${fusho_d_src}"
}

fusho_emit_qr() {
  fusho_eq_armor="$1"
  if ! fusho_have qrencode; then
    fusho_die "--qr needs qrencode. install it with: brew install qrencode, or apt install qrencode."
  fi
  fusho_eq_size=$(wc -c <"${fusho_eq_armor}" | tr -d " ")
  if [ "${fusho_eq_size}" -gt 2900 ]; then
    fusho_die "the message is too large for a QR code. send it as text instead."
  fi
  qrencode -t ANSIUTF8 <"${fusho_eq_armor}"
}

fusho_interactive() {
  [ "${FUSHO_INTERACTIVE:-}" = 1 ] && return 0
  [ -t 0 ]
}

fusho_prompt() {
  fusho_p_answer=""
  printf '%s: ' "$1" >&2
  IFS= read -r fusho_p_answer || [ -n "${fusho_p_answer}" ] || return 1
  printf '%s\n' "${fusho_p_answer}"
}

fusho_prompt_required() {
  fusho_pr_tries=0
  fusho_pr_answer=""
  while [ "${fusho_pr_tries}" -lt 3 ]; do
    fusho_pr_answer=$(fusho_prompt "$1") || fusho_die "$2"
    if [ -n "${fusho_pr_answer}" ]; then
      printf '%s\n' "${fusho_pr_answer}"
      return 0
    fi
    fusho_pr_tries=$((fusho_pr_tries + 1))
  done
  fusho_die "$2"
}

fusho_has_armor() {
  fusho_ha_line=""
  while IFS= read -r fusho_ha_line || [ -n "${fusho_ha_line}" ]; do
    case "${fusho_ha_line}" in
    *"${FUSHO_ARMOR_BEGIN}"*) return 0 ;;
    *) ;;
    esac
  done <"$1"
  return 1
}
