#!/bin/sh
set -eu

version=${1:?version required}
root=$(cd "$(dirname "$0")/.." && pwd)
core="${root}/lib/core.sh"

if ! grep -q '^FUSHO_VERSION=' "${core}"; then
  printf 'no FUSHO_VERSION assignment found in %s\n' "${core}" >&2
  exit 1
fi

tmp=$(mktemp "${TMPDIR:-/tmp}/fusho-version-XXXXXX")
sed "s/^FUSHO_VERSION=\".*\"$/FUSHO_VERSION=\"${version}\"/" "${core}" >"${tmp}"
cat "${tmp}" >"${core}"
rm -f "${tmp}"

reported=$("${root}/bin/fusho" --version)
printf 'version set to %s\n' "${reported}"
