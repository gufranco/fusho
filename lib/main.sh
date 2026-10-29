#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${FUSHO_LIB:?}/state.sh"

fusho_menu() {
  fusho_m_choice=""
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

fusho_main() {
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
  version | --version | -V | -v) fusho_cmd_version ;;
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
