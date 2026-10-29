# shellcheck shell=bash
# shellcheck disable=SC2207

_fusho() {
  local cur prev commands send_opts read_opts
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD - 1]}"
  commands="send read keys doctor version help"
  send_opts="--to --keys-file --key --json --sign --accept-new-key --qr --expires --no-banner --no-clipboard"
  read_opts="--identity --identity-command --clipboard --require-signature --ignore-expiry"

  case "${prev}" in
  --keys-file | --identity)
    COMPREPLY=($(compgen -f -- "${cur}"))
    return
    ;;
  *) ;;
  esac

  if [[ "${COMP_CWORD}" -eq 1 ]]; then
    COMPREPLY=($(compgen -W "${commands}" -- "${cur}"))
    return
  fi

  case "${COMP_WORDS[1]}" in
  send) COMPREPLY=($(compgen -W "${send_opts}" -- "${cur}")) ;;
  read) COMPREPLY=($(compgen -W "${read_opts}" -- "${cur}")) ;;
  *) COMPREPLY=() ;;
  esac
}

complete -F _fusho fusho
