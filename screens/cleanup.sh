#!/bin/sh
set -u

pkill -f 'http.server 8765' 2>/dev/null
rm -rf /Users/Shared/demo
