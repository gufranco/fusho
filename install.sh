#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
artifact="${root}/dist/fusho"
target_dir=${FUSHO_PREFIX:-$HOME/.local/bin}

if [[ ! -f "$artifact" ]]; then
  bash "${root}/build.sh"
fi

mkdir -p "$target_dir"
install -m 0755 "$artifact" "${target_dir}/fusho"

printf 'installed %s\n' "${target_dir}/fusho"

man_dir=${FUSHO_MAN_DIR:-${target_dir%/bin}/share/man/man1}
if mkdir -p "$man_dir" 2>/dev/null && install -m 0644 "${root}/man/fusho.1" "${man_dir}/fusho.1" 2>/dev/null; then
  printf 'installed %s\n' "${man_dir}/fusho.1"
fi

completion_dir=${FUSHO_COMPLETION_DIR:-${target_dir%/bin}/share/bash-completion/completions}
if mkdir -p "$completion_dir" 2>/dev/null && install -m 0644 "${root}/completions/fusho.bash" "${completion_dir}/fusho" 2>/dev/null; then
  printf 'installed %s\n' "${completion_dir}/fusho"
fi

zsh_dir=${FUSHO_ZSH_COMPLETION_DIR:-${target_dir%/bin}/share/zsh/site-functions}
if mkdir -p "$zsh_dir" 2>/dev/null && install -m 0644 "${root}/completions/_fusho" "${zsh_dir}/_fusho" 2>/dev/null; then
  printf 'installed %s\n' "${zsh_dir}/_fusho"
fi

case ":${PATH}:" in
*":${target_dir}:"*) ;;
*)
  printf '\n%s is not on your PATH. add this to your shell profile:\n' "$target_dir"
  # shellcheck disable=SC2016
  printf '  export PATH="%s:$PATH"\n' "$target_dir"
  ;;
esac
