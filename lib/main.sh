#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${FUSHO_LIB:?}/state.sh"

fusho_menu() {
  fusho_m_choice=""
  if fusho_ui_prompts; then
    fusho_menu_gum
    return
  fi
  printf '%s\n' "What would you like to do?" "  1) send a message" "  2) read a message" "  3) list someone's keys" "  4) check this machine" >&2
  fusho_m_choice=$(fusho_prompt "Choice [1]") || exit 1
  case "${fusho_m_choice:-1}" in
  1) fusho_cmd_send ;;
  2) fusho_cmd_read ;;
  3) fusho_cmd_keys ;;
  4) fusho_cmd_doctor ;;
  *) fusho_die "unknown choice '${fusho_m_choice}'. run 'fusho help' for usage." ;;
  esac
}

fusho_menu_gum() {
  fusho_mg_choice=""
  fusho_ui_header
  fusho_mg_choice=$(fusho_ui_choose "What would you like to do?" "Send a message" "Read a message" \
    "List someone's keys" "Check this machine" "Help") || exit 1
  case "${fusho_mg_choice}" in
  "Send a message") fusho_cmd_send ;;
  "Read a message") fusho_cmd_read ;;
  "List someone's keys") fusho_cmd_keys ;;
  "Check this machine") fusho_cmd_doctor ;;
  "Help") fusho_usage ;;
  *) exit 1 ;;
  esac
}

fusho_main() {
  fusho_m2_count=$#
  fusho_m2_literal=0
  while [ "${fusho_m2_count}" -gt 0 ]; do
    fusho_m2_arg=$1
    shift
    fusho_m2_count=$((fusho_m2_count - 1))
    case "${fusho_m2_literal}:${fusho_m2_arg}" in
    0:--) fusho_m2_literal=1 ;;
    0:--theme=*)
      FUSHO_THEME=${fusho_m2_arg#--theme=}
      continue
      ;;
    0:--theme)
      fusho_need_value --theme "$((fusho_m2_count + 1))"
      FUSHO_THEME=$1
      shift
      fusho_m2_count=$((fusho_m2_count - 1))
      continue
      ;;
    *) ;;
    esac
    set -- "$@" "${fusho_m2_arg}"
  done
  fusho_ui_setup || fusho_die "${FUSHO_UI_PROBLEM}"
  fusho_dispatch "$@"
}

fusho_dispatch() {
  fusho_m2_command="${1:-}"
  if [ $# -gt 0 ]; then
    shift
  fi
  case "${fusho_m2_command}" in
  send) fusho_cmd_send "$@" ;;
  read) fusho_cmd_read "$@" ;;
  keys) fusho_cmd_keys "$@" ;;
  keys-url) fusho_keys_url "${1:-}" ;;
  doctor) fusho_cmd_doctor ;;
  version | --version | -V) fusho_cmd_version ;;
  help | --help | -h) fusho_usage ;;
  "")
    if fusho_interactive; then
      fusho_menu
    else
      fusho_die "no command given. run 'fusho help' for usage."
    fi
    ;;
  -*) fusho_die "unknown option '${fusho_m2_command}'. run 'fusho help' for usage." ;;
  *) fusho_die "unknown command '${fusho_m2_command}'. run 'fusho help' for usage." ;;
  esac
}
