#!/usr/bin/env bash
# Regenerates the three app icons with window-manager's generator. Then run build-launchers.sh.
#   homelab-dns/make-icons.sh
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
GEN="$SRC_DIR/../window-manager/make-icon.sh"

while read -r symbol name; do
    "$GEN" "$symbol" "$name"
    mv "$SRC_DIR/../window-manager/$name.icns" "$SRC_DIR/$name.icns"
done <<'ICONS'
list.bullet.rectangle LogIcon
stop.fill StopIcon
play.fill StartIcon
ICONS
