Source common.tape
Output scratch.gif
Set Height 1300
Hide
Type ". ./setup.sh"
Enter
Sleep 3s
Show
Sleep 800ms
Type "fusho keys octocat"
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
Type "fusho send octocat hi --no-clipboard >/dev/null 2>&1; cp -f rotated.keys forge/octocat.keys; clear"
Enter
Sleep 4s
Show
Sleep 800ms
Type "fusho send octocat hi"
Enter
Sleep 5s
Screenshot refused.png
Sleep 1s
Hide
Type "clear"
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
