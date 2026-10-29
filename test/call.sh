#!/bin/sh
[ -n "${ZSH_VERSION:-}" ] && emulate sh

FUSHO_LIB="$(cd "$(dirname "$0")/../lib" && pwd)" || exit 1

# shellcheck source=SCRIPTDIR/../lib/core.sh
. "${FUSHO_LIB}/core.sh"
# shellcheck source=SCRIPTDIR/../lib/armor.sh
. "${FUSHO_LIB}/armor.sh"
# shellcheck source=SCRIPTDIR/../lib/commands.sh
. "${FUSHO_LIB}/commands.sh"

"$@"
