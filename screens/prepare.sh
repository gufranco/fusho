#!/bin/sh
set -eu

: "${SCREENS_REPO:?}"
demo=/Users/Shared/demo
rm -rf "${demo}"
mkdir -p "${demo}/bin"
mkdir -p "${demo}/home/.ssh" "${demo}/forge"
ssh-keygen -q -t ed25519 -N '' -C 'ana@laptop' -f "${demo}/home/.ssh/id_ed25519"
cp -f "${demo}/home/.ssh/id_ed25519.pub" "${demo}/ana.pub"
cp -f "${demo}/ana.pub" "${demo}/forge/octocat.keys"
ssh-keygen -q -t ed25519 -N '' -C 'ben@desktop' -f "${demo}/ben"
cp -f "${demo}/ben.pub" "${demo}/rotated.keys"
printf '#!/bin/sh\ncat >/dev/null\n' >"${demo}/bin/pbcopy"
chmod +x "${demo}/bin/pbcopy"
