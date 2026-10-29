#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
unprefixed=$(cat "${root}"/bin/fusho "${root}"/lib/*.sh |
  grep -oE '[$][{]?[A-Z][A-Z0-9_]*' | sed 's/^[$][{]*//' | sort -u |
  grep -v '^FUSHO_' | grep -vxE 'HOME|PATH|TMPDIR|NF|SSH_AUTH_SOCK|XDG_CONFIG_HOME|ZSH_VERSION' || true)
if [ -n "${unprefixed}" ]; then
  printf 'environment variable without the FUSHO_ prefix:\n%s\n' "${unprefixed}" >&2
  exit 1
fi
