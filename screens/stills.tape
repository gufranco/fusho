Source common.tape
Output scratch.gif
Set Height 1300
Hide
Type ". ./setup.sh"
Enter
Sleep 1s
Show
Sleep 800ms
Type "fusho keys gufranco"
Enter
Sleep 5s
Screenshot keys.png
Sleep 1s
Hide
Type "clear"
Enter
Show
Sleep 800ms
Hide
Type "fusho send --keys-file ana.pub --no-clipboard 'The vinyl is in the blue box.' > note.txt 2>/dev/null; clear"
Enter
Sleep 3s
Show
Sleep 800ms
Type "fusho read note.txt"
Enter
Sleep 4s
Screenshot read.png
Sleep 1s
Hide
Type "clear"
Enter
Show
Sleep 800ms
Hide
Type "fusho send gufranco hi --no-clipboard >/dev/null 2>&1; (/usr/bin/python3 -m http.server 8765 --bind 127.0.0.1 --directory forge >/dev/null 2>&1 &); sleep 2; export FUSHO_GITHUB_BASE=http://127.0.0.1:8765; clear"
Enter
Sleep 9s
Show
Sleep 800ms
Type "fusho send gufranco hi"
Enter
Sleep 5s
Screenshot refused.png
Sleep 1s
Hide
Type "unset FUSHO_GITHUB_BASE; pkill -f 'http.server 8765'; clear"
Enter
Show
Sleep 800ms
Hide
Type "clear"
Enter
Show
Sleep 800ms
Type "fusho read"
Enter
Sleep 3s
Screenshot paste.png
Sleep 1s
Ctrl+C
Sleep 1s
Hide
Type "clear"
Enter
Show
Sleep 800ms
Type "fusho keys no-such-person-here"
Enter
Sleep 5s
Screenshot error.png
Sleep 1s
Hide
Type "clear"
Enter
Show
Sleep 800ms
Type "fusho doctor"
Enter
Sleep 10s
Screenshot doctor.png
Sleep 1s
Hide
Type "clear"
Enter
Show
Sleep 800ms
Type "for t in kodougu catppuccin-mocha dracula nord gruvbox tokyo-night; do fusho --theme $t version; done"
Enter
Sleep 8s
Screenshot themes.png
Sleep 1s
Sleep 1s
