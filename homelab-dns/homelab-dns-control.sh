#!/bin/sh
# Run by launchd when Network Stop or Network Start changes the flag folder.
set -u

PRIORITY="/usr/local/sbin/net-priority.sh"
ACTOR="/usr/local/sbin/homelab-dns.sh"

"${PRIORITY}" control
"${ACTOR}" control
