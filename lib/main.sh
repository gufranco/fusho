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
  "") fusho_usage && exit 1 ;;
  *) fusho_die "unknown command '${command}'. run 'fusho help' for usage." ;;
  esac
}

fusho_require_local

trap fusho_cleanup EXIT
trap 'fusho_cleanup; exit 130' INT
trap 'fusho_cleanup; exit 143' TERM
trap 'fusho_cleanup; exit 129' HUP

fusho_main "$@"
