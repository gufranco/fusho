#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${FUSHO_LIB:?}/state.sh"

fusho_clipboard_copy() {
  local file="$1"
  if [ -n "$FUSHO_CLIPBOARD_COPY" ]; then
    $FUSHO_CLIPBOARD_COPY <"$file" >/dev/null 2>&1 && printf '%s\n' "$FUSHO_CLIPBOARD_COPY" && return 0
  fi
  if fusho_have pbcopy; then
    pbcopy <"$file" && printf 'pbcopy\n' && return 0
  fi
  if fusho_have wl-copy; then
    wl-copy <"$file" && printf 'wl-copy\n' && return 0
  fi
  if fusho_have xclip; then
    xclip -selection clipboard <"$file" && printf 'xclip\n' && return 0
  fi
  if fusho_have xsel; then
    xsel --clipboard --input <"$file" && printf 'xsel\n' && return 0
  fi
  return 1
}

fusho_read_plaintext() {
  local dest="$1" message="$2"
  if [ -n "$message" ]; then
    printf '%s\n' "$message" >"$dest"
  else
    if fusho_interactive; then
      printf '%s\n' "Type the message, then press Ctrl-D on an empty line:" >&2
    fi
    cat >"$dest"
  fi
  if [ ! -s "$dest" ]; then
    fusho_die "refusing to send an empty message."
  fi
}

fusho_clipboard_paste() {
  if [ -n "$FUSHO_CLIPBOARD_PASTE" ]; then
    $FUSHO_CLIPBOARD_PASTE && return 0
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
  local copier="$1" armor="$2" seconds="$3" expected
  if [ "$seconds" -le 0 ]; then
    return 0
  fi
  expected=$(cat "$armor")
  (
    sleep "$seconds"
    if [ "$(fusho_clipboard_paste 2>/dev/null)" = "$expected" ]; then
      # shellcheck disable=SC2086
      printf '' | $copier >/dev/null 2>&1 || true
    fi
  ) >/dev/null 2>&1 &
}

fusho_compress() {
  local plain="$1" dest="$2"
  if ! fusho_have gzip; then
    return 1
  fi
  if ! gzip -c "$plain" >"$dest" 2>/dev/null; then
    return 1
  fi
  if [ "$(wc -c <"$dest" | tr -d " ")" -ge "$(wc -c <"$plain" | tr -d " ")" ]; then
    return 1
  fi
  return 0
}

fusho_decompress() {
  local src="$1"
  if ! fusho_have gunzip; then
    fusho_die "this message is compressed and gunzip is not installed."
  fi
  gunzip -c "$src"
}

fusho_emit_qr() {
  local armor="$1"
  if ! fusho_have qrencode; then
    fusho_die "--qr needs qrencode. install it with: brew install qrencode, or apt install qrencode."
  fi
  if [ "$(wc -c <"$armor" | tr -d " ")" -gt 2900 ]; then
    fusho_die "the message is too large for a QR code. send it as text instead."
  fi
  qrencode -t ANSIUTF8 <"$armor"
}

fusho_interactive() {
  [ "${FUSHO_INTERACTIVE:-}" = 1 ] && return 0
  [ -t 0 ]
}

fusho_prompt() {
  local answer=""
  printf '%s: ' "$1" >&2
  IFS= read -r answer || [ -n "$answer" ] || return 1
  printf '%s\n' "$answer"
}

fusho_prompt_required() {
  local tries=0 answer=""
  while [ "$tries" -lt 3 ]; do
    answer=$(fusho_prompt "$1") || fusho_die "$2"
    if [ -n "$answer" ]; then
      printf '%s\n' "$answer"
      return 0
    fi
    tries=$((tries + 1))
  done
  fusho_die "$2"
}

fusho_has_armor() {
  local line=""
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
    *"$FUSHO_ARMOR_BEGIN"*) return 0 ;;
    *) ;;
    esac
  done <"$1"
  return 1
}
