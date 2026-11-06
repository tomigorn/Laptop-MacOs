#!/usr/bin/env bash
# Builds Network Log, Network Stop and Network Start into ~/Applications, linked back into this repo. No sudo.
#   homelab-dns/build-launchers.sh
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
LSREGISTER="${LSREGISTER:-/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister}"
OLD_APP="$HOME/Applications/ethernet wifi network log.app"

build_app() {  # build_app <app> <script> <executable> <plist> <icon>
    local app_dir="$HOME/Applications/$1.app"
    rm -rf "$app_dir"
    mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
    chmod +x "$SRC_DIR/$2"
    ln -sf "$SRC_DIR/$2" "$app_dir/Contents/MacOS/$3"
    ln -sf "$SRC_DIR/$4" "$app_dir/Contents/Info.plist"
    printf 'APPL????' > "$app_dir/Contents/PkgInfo"
    cp "$SRC_DIR/$5.icns" "$app_dir/Contents/Resources/$5.icns"
    "$LSREGISTER" -f "$app_dir"
    echo "built: $app_dir"
}

if [ -e "$OLD_APP" ]; then
    "$LSREGISTER" -u "$OLD_APP" || true
    rm -rf "$OLD_APP"
fi

build_app "Network Log"   log-launcher.sh     network-log   log-Info.plist   LogIcon
build_app "Network Stop"  control-launcher.sh network-stop  stop-Info.plist  StopIcon
build_app "Network Start" control-launcher.sh network-start start-Info.plist StartIcon
ln -sfn /var/log/homelab-dns.log "$SRC_DIR/homelab-dns.log"
