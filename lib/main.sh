fusho_menu() {
  local choice=""
  printf '%s\n' "What would you like to do?" "  1) send a message" "  2) read a message" "  3) list someone's keys" "  4) check this machine" >&2
  choice=$(fusho_prompt "Choice [1]") || exit 1
  case "${choice:-1}" in
  1) fusho_cmd_send ;;
  2) fusho_cmd_read ;;
  3) fusho_cmd_keys ;;
  4) fusho_cmd_doctor ;;
  *) fusho_die "unknown choice '${choice}'. run 'fusho help' for usage." ;;
  esac
}

fusho_main() {
  local command="${1:-}"
  if [ $# -gt 0 ]; then
    shift
  fi
  case "$command" in
  send) fusho_cmd_send "$@" ;;
  read) fusho_cmd_read "$@" ;;
  keys) fusho_cmd_keys "$@" ;;
  keys-url) fusho_keys_url "${1:-}" ;;
  doctor) fusho_cmd_doctor ;;
  version | --version | -v) fusho_cmd_version ;;
  help | --help | -h) fusho_usage ;;
  "")
    if fusho_interactive; then
      fusho_menu
    else
      fusho_usage && exit 1
    fi
    ;;
  *) fusho_die "unknown command '${command}'. run 'fusho help' for usage." ;;
  esac
}

fusho_require_local

trap fusho_cleanup EXIT
trap 'fusho_cleanup; exit 130' INT
trap 'fusho_cleanup; exit 143' TERM
trap 'fusho_cleanup; exit 129' HUP

fusho_main "$@"
