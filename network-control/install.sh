#!/opt/homebrew/bin/bash
# Builds NetworkControl, installs it to ~/Applications and opens it once so macOS registers the control. No sudo.
#   network-control/install.sh
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/Applications/NetworkControl.app"

team="$(security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject -nameopt multiline | awk -F'= ' '/organizationalUnitName/{print $2}')"
[ -n "$team" ] || { echo "no Apple Development certificate found" >&2; exit 1; }

cd "$DIR"
xcodebuild -project NetworkControl.xcodeproj -target NetworkControl -configuration Release \
  SYMROOT="$DIR/build" DEVELOPMENT_TEAM="$team" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Apple Development" \
  -quiet 2>/dev/null

mkdir -p "$HOME/Applications"
rm -rf "$DEST"
ditto "$DIR/build/Release/NetworkControl.app" "$DEST"
open "$DEST"

echo "installed: $DEST"
echo "next: Control Center > Edit Controls > Network in use"
