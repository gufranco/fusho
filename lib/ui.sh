#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${FUSHO_LIB:?}/state.sh"

# shellcheck disable=SC2034
fusho_ui_set() {
  FUSHO_UI_ACCENT="$1"
  FUSHO_UI_OK="$2"
  FUSHO_UI_WARN="$3"
  FUSHO_UI_ERR="$4"
  FUSHO_UI_MUTED="$5"
  FUSHO_UI_TEXT="$6"
  FUSHO_UI_SURFACE="$7"
  FUSHO_UI_HELP="$8"
}

fusho_ui_palette() {
  case "$1" in
  kodougu) fusho_ui_set "#F25D94" "#50FA7B" "#FFB86C" "#FF5555" "#6C7086" "#CDD6F4" "#313244" pink ;;
  catppuccin-mocha) fusho_ui_set "#CBA6F7" "#A6E3A1" "#FAB387" "#F38BA8" "#6C7086" "#CDD6F4" "#313244" dark ;;
  catppuccin-latte) fusho_ui_set "#8839EF" "#40A02B" "#FE640B" "#D20F39" "#8C8FA1" "#4C4F69" "#CCD0DA" light ;;
  dracula) fusho_ui_set "#BD93F9" "#50FA7B" "#FFB86C" "#FF5555" "#6272A4" "#F8F8F2" "#44475A" dracula ;;
  nord) fusho_ui_set "#88C0D0" "#A3BE8C" "#EBCB8B" "#BF616A" "#4C566A" "#D8DEE9" "#3B4252" dark ;;
  gruvbox) fusho_ui_set "#FE8019" "#B8BB26" "#FABD2F" "#FB4934" "#928374" "#EBDBB2" "#3C3836" dark ;;
  tokyo-night) fusho_ui_set "#7AA2F7" "#9ECE6A" "#E0AF68" "#F7768E" "#565F89" "#C0CAF5" "#292E42" tokyo-night ;;
  mono) fusho_ui_set "" "" "" "" "" "" "" ascii ;;
  *) return 1 ;;
  esac
}

fusho_ui_is_colour() {
  case "$1" in
  \#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]) return 0 ;;
  *) return 1 ;;
  esac
}

# shellcheck disable=SC2034
fusho_ui_setup() {
  if ! fusho_ui_palette "${FUSHO_THEME}"; then
    fusho_ui_palette mono
    FUSHO_UI_PROBLEM="--theme must be one of ${FUSHO_UI_THEMES}, got: ${FUSHO_THEME}"
    return 1
  fi
  if [ -n "${FUSHO_ACCENT}" ] && ! fusho_ui_is_colour "${FUSHO_ACCENT}"; then
    FUSHO_UI_PROBLEM="KODOUGU_ACCENT must be a colour such as #CBA6F7, got: ${FUSHO_ACCENT}"
    return 1
  fi
  if [ -n "${FUSHO_ACCENT}" ]; then
    FUSHO_UI_ACCENT="${FUSHO_ACCENT}"
  fi
  if [ -n "${NO_COLOR:-}" ]; then
    fusho_ui_palette mono
  fi
}

fusho_ui_forced() {
  [ "${FUSHO_TEST_GUM:-}" = 1 ]
}

fusho_ui_has_gum() {
  command -v gum >/dev/null 2>&1
}

fusho_ui_prompts() {
  fusho_ui_forced && return 0
  [ -t 0 ] && [ -t 2 ] && fusho_ui_has_gum
}

fusho_ui_err() {
  fusho_ui_forced && return 0
  [ "${FUSHO_UI_STEP}" = 1 ] && return 0
  [ -t 2 ] && fusho_ui_has_gum
}

fusho_ui_out() {
  fusho_ui_forced && return 0
  [ -t 1 ] && fusho_ui_has_gum
}

fusho_gum() {
  if [ -n "${FUSHO_UI_TEXT}" ]; then
    CLICOLOR_FORCE=1 gum "$@"
    return
  fi
  gum "$@"
}

fusho_ui_ink() {
  fusho_ui_colour="$1"
  shift
  if [ -z "${fusho_ui_colour}" ]; then
    fusho_gum style "$@"
    return
  fi
  fusho_gum style --foreground "${fusho_ui_colour}" "$@"
}

fusho_ui_header() {
  fusho_uh_name=$(fusho_ui_ink "${FUSHO_UI_ACCENT}" --bold -- "fusho")
  fusho_uh_number=$(fusho_version | sed -n '1p')
  fusho_uh_number="${fusho_uh_number#fusho }"
  fusho_uh_version=$(fusho_ui_ink "${FUSHO_UI_MUTED}" -- "${fusho_uh_number}")
  fusho_uh_tagline=$(fusho_ui_ink "${FUSHO_UI_TEXT}" -- "${FUSHO_TAGLINE}")
  fusho_uh_top=$(fusho_gum join --horizontal "${fusho_uh_name}" "  " "${fusho_uh_version}")
  fusho_uh_body=$(fusho_gum join --vertical "${fusho_uh_top}" "${fusho_uh_tagline}")
  printf '\n' >&2
  fusho_gum style --border rounded --border-foreground "${FUSHO_UI_ACCENT}" --padding "0 2" -- "${fusho_uh_body}" >&2
  printf '\n' >&2
}

fusho_ui_title() {
  printf '\n' >&2
  fusho_ui_ink "${FUSHO_UI_ACCENT}" --bold -- "$1" >&2
  printf '\n' >&2
}

fusho_ui_titled() {
  if fusho_ui_prompts; then
    fusho_ui_title "$1"
  fi
}

fusho_ui_lower_first() {
  printf '%s\n' "$1" | awk 'NR == 1 { a = substr($0, 1, 1); b = substr($0, 2, 1); if (a != tolower(a) && b != toupper(b)) { $0 = tolower(a) substr($0, 2) } } { print }'
}

fusho_ui_log() {
  fusho_ul_level="$1"
  fusho_ul_text=$(fusho_ui_lower_first "$2")
  case "${fusho_ul_level}" in
  ERROR) fusho_ul_colour="${FUSHO_UI_ERR}" ;;
  WARN) fusho_ul_colour="${FUSHO_UI_WARN}" ;;
  *) fusho_ul_colour="${FUSHO_UI_OK}" ;;
  esac
  fusho_ul_label=$(fusho_ui_ink "${fusho_ul_colour}" --bold -- "${fusho_ul_level}")
  printf '%s fusho: %s\n' "${fusho_ul_label}" "${fusho_ul_text}" >&2
}

fusho_ui_choose() {
  fusho_uc_header="$1"
  shift
  fusho_gum choose --header "${fusho_uc_header}" --cursor "> " --height 14 \
    --cursor.foreground "${FUSHO_UI_ACCENT}" --selected.foreground "${FUSHO_UI_ACCENT}" \
    --header.foreground "${FUSHO_UI_TEXT}" "$@"
}

fusho_ui_input() {
  fusho_ui_header_text="$1"
  fusho_ui_placeholder="$2"
  shift 2
  fusho_gum input --header "${fusho_ui_header_text}" --placeholder "${fusho_ui_placeholder}" --prompt "> " \
    --prompt.foreground "${FUSHO_UI_ACCENT}" --cursor.foreground "${FUSHO_UI_ACCENT}" \
    --header.foreground "${FUSHO_UI_TEXT}" --placeholder.foreground "${FUSHO_UI_MUTED}" "$@"
}

fusho_ui_write() {
  fusho_gum write --header "$1" --placeholder "$2" --width 72 --height 8 --show-line-numbers \
    --cursor.foreground "${FUSHO_UI_ACCENT}" --header.foreground "${FUSHO_UI_TEXT}" \
    --placeholder.foreground "${FUSHO_UI_MUTED}"
}

fusho_ui_confirm() {
  fusho_ucf_prompt="$1"
  fusho_ucf_yes="$2"
  fusho_ucf_no="$3"
  shift 3
  fusho_gum confirm "${fusho_ucf_prompt}" --affirmative "${fusho_ucf_yes}" --negative "${fusho_ucf_no}" \
    --prompt.foreground "${FUSHO_UI_TEXT}" --selected.background "${FUSHO_UI_ACCENT}" \
    --unselected.background "${FUSHO_UI_SURFACE}" "$@"
}

fusho_ui_summary() {
  fusho_us2_pairs=$(($# / 2))
  while [ "${fusho_us2_pairs}" -gt 0 ]; do
    fusho_us2_label=$(printf '%-7s' "$1")
    fusho_us2_label=$(fusho_ui_ink "${FUSHO_UI_MUTED}" -- "${fusho_us2_label}")
    fusho_us2_value=$(fusho_ui_ink "${FUSHO_UI_TEXT}" --bold -- "$2")
    shift 2
    set -- "$@" "${fusho_us2_label} ${fusho_us2_value}"
    fusho_us2_pairs=$((fusho_us2_pairs - 1))
  done
  printf '\n'
  fusho_gum style --border rounded --border-foreground "${FUSHO_UI_MUTED}" --padding "0 1" -- "$@"
  printf '\n'
}

fusho_ui_spin() {
  fusho_us_title="$1"
  fusho_us_log="$2"
  shift 2
  (FUSHO_UI_STEP=1 && "$@") 2>"${fusho_us_log}" &
  fusho_us_pid=$!
  if ! fusho_ui_spin_wait "${fusho_us_title}" "${fusho_us_pid}"; then
    kill "${fusho_us_pid}" 2>/dev/null
    exit 130
  fi
  fusho_us_status=0
  wait "${fusho_us_pid}" || fusho_us_status=$?
  cat "${fusho_us_log}" >&2
  return "${fusho_us_status}"
}

fusho_ui_spin_wait() {
  # shellcheck disable=SC2016
  fusho_uw_loop='while kill -0 "$1" 2>/dev/null; do sleep 0.1; done'
  fusho_gum spin --spinner dot --spinner.foreground "${FUSHO_UI_ACCENT}" --title.foreground "${FUSHO_UI_TEXT}" --title "$1" -- sh -c "${fusho_uw_loop}" _ "$2" >&2
}

fusho_ui_table() {
  fusho_ut_line="-"
  if [ -n "${FUSHO_UI_TEXT}" ]; then
    fusho_ut_line=$(printf '\342\224\200')
  fi
  fusho_ut_body=$(fusho_ui_table_body "${fusho_ut_line}")
  fusho_gum style --border rounded --border-foreground "${FUSHO_UI_MUTED}" --padding "0 1" -- "${fusho_ut_body}"
}

fusho_ui_table_body() {
  LC_ALL=C awk -F '\t' -v acc="${FUSHO_UI_ACCENT}" -v ok="${FUSHO_UI_OK}" -v warn="${FUSHO_UI_WARN}" \
    -v bad="${FUSHO_UI_ERR}" -v txt="${FUSHO_UI_TEXT}" -v mut="${FUSHO_UI_MUTED}" -v dash="$1" \
    -f "${FUSHO_LIB}/table.awk"
}

fusho_ui_done() {
  printf '\n'
  fusho_ui_ink "${FUSHO_UI_OK}" --bold -- "$1"
}

fusho_ui_badge() {
  fusho_ub_colour="$1"
  shift
  if [ -z "${fusho_ub_colour}" ]; then
    fusho_gum style --bold --underline --padding "0 1" -- "$*"
    return
  fi
  fusho_gum style --background "${fusho_ub_colour}" --foreground "#1E1E2E" --bold --padding "0 1" -- "$*"
}

fusho_ui_chip() {
  if [ -z "${FUSHO_UI_SURFACE}" ]; then
    fusho_gum style --padding "0 1" -- "$1"
    return
  fi
  fusho_gum style --background "${FUSHO_UI_SURFACE}" --foreground "${FUSHO_UI_TEXT}" --padding "0 1" -- "$1"
}

fusho_ui_danger() {
  fusho_ud_title=$(fusho_ui_ink "${FUSHO_UI_ERR}" --bold -- "$1")
  shift
  fusho_gum style --border thick --border-foreground "${FUSHO_UI_ERR}" --padding "0 1" -- "${fusho_ud_title}" "$@" >&2
}

fusho_ui_markdown() {
  awk '
    NR == 1 {
      split($0, head, " - ")
      printf "# %s\n\n%s\n", head[1], head[2]
      next
    }
    /^[a-z][a-z ]*:$/ {
      if (open) { print "```" }
      printf "\n## %s\n\n```text\n", toupper(substr($0, 1, 1)) substr($0, 2, length($0) - 2)
      open = 1
      next
    }
    { print }
    END { if (open) { print "```" } }
  '
}
