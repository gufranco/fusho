export PS1='$ '
export PATH="/Users/Shared/demo/bin:${SCREENS_REPO:?}/bin:${PATH}"
unset KODOUGU_THEME FUSHO_THEME KODOUGU_ACCENT NO_COLOR
export HOME="/Users/Shared/demo/home"
(/usr/bin/python3 -m http.server 8765 --bind 127.0.0.1 --directory /Users/Shared/demo/forge >/dev/null 2>&1 &)
export FUSHO_GITHUB_BASE=http://127.0.0.1:8765
cd /Users/Shared/demo || return 1
clear
