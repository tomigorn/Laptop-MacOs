#!/usr/bin/env bash
# Builds ~/Applications/ethernet wifi network log.app, symlinked back into this repo. No sudo.
#   homelab-dns/build-log-launcher.sh
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$HOME/Applications/ethernet wifi network log.app"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
chmod +x "$SRC_DIR/log-launcher.sh"
ln -sf "$SRC_DIR/log-launcher.sh" "$APP_DIR/Contents/MacOS/ethernet-wifi-network-log"
ln -sf "$SRC_DIR/log-Info.plist" "$APP_DIR/Contents/Info.plist"
printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DIR"

echo "built: $APP_DIR"
echo "Spotlight: type 'ethernet', 'wifi' or 'network log'"
