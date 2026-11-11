#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
unprefixed=$(cat "${root}"/bin/fusho "${root}"/lib/*.sh |
  grep -oE '[$][{]?[A-Z][A-Z0-9_]*' | sed 's/^[$][{]*//' | sort -u |
  grep -v '^FUSHO_' | grep -vxE 'HOME|PATH|TMPDIR|NF|SSH_AUTH_SOCK|XDG_CONFIG_HOME|ZSH_VERSION|KODOUGU_THEME|KODOUGU_ACCENT|NO_COLOR' || true)
if [ -n "${unprefixed}" ]; then
  printf 'environment variable without the FUSHO_ prefix:\n%s\n' "${unprefixed}" >&2
  exit 1
fi

forbidden=$(awk '
  /\$\(dd / && !/tr -d/ { print FILENAME ":" FNR ": a dd read into a variable keeps its NUL bytes" }
  /^[[:space:]]*\}[[:space:]]*>/ { print FILENAME ":" FNR ": a brace group closes on a redirect bashcov cannot count" }
  /done[[:space:]]+[0-9]+</ { print FILENAME ":" FNR ": a loop redirects a fixed descriptor bashcov can take" }
  /function[[:space:]]+(xor|and|or|compl|lshift|rshift|strftime|systime)[[:space:]]*\(/ { print FILENAME ":" FNR ": an awk function is named like a gawk built-in" }
  /while[[:space:]]+![[:space:]]+mkdir/ { print FILENAME ":" FNR ": a lock is taken with mkdir" }
  /wc -c[[:space:]]*</ { print FILENAME ":" FNR ": a file size is read with wc, which BusyBox counts in 32 bits" }
  /%\.\*\}\.bak|\$\/\.bak\// { print FILENAME ":" FNR ": a backup name drops the extension of the file it keeps" }
' "${root}"/bin/* "${root}"/lib/*.sh)
if [ -n "${forbidden}" ]; then
  printf 'code FAMILY.md forbids:\n%s\n' "${forbidden}" >&2
  exit 1
fi

waits=$(awk '/^[[:space:]]*wait[[:space:]]*$/ { print FILENAME ":" FNR ": a bare wait also waits for bats'"'"' timeout watchdog" }' "${root}"/test/*.bats "${root}"/test/*.bash)
if [ -n "${waits}" ]; then
  printf 'tests FAMILY.md forbids:\n%s\n' "${waits}" >&2
  exit 1
fi
