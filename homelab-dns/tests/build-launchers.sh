#!/opt/homebrew/bin/bash
# homelab-dns/build-launchers.sh with a temp HOME and stubbed lsregister: bundles, names, icons, old app removed.
#   homelab-dns/tests/build-launchers.sh
set -uo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/build-launchers.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
export HOME="$WORK/home" CALLS="$WORK/calls"
mkdir -p "$HOME/Applications/ethernet wifi network log.app/Contents"
cat > "$WORK/lsregister" <<'STUB'
#!/bin/sh
echo "lsregister $*" >> "$CALLS"
STUB
chmod +x "$WORK/lsregister"
export LSREGISTER="$WORK/lsregister"

fails=0
check() {  # check <name> <condition...>
  local name="$1"; shift
  if "$@"; then echo "PASS  $name"; else echo "FAIL  $name"; fails=$((fails + 1)); fi
}
eq() { [ "$1" = "$2" ]; }
contains() { [[ "$1" == *"$2"* ]]; }

"$DIR/build-launchers.sh" >/dev/null
check "build exits 0" test "$?" -eq 0
check "old app removed" test ! -e "$HOME/Applications/ethernet wifi network log.app"
check "old app unregistered" contains "$(cat "$CALLS")" "lsregister -u $HOME/Applications/ethernet wifi network log.app"

while IFS='|' read -r app exe plist icon; do
  a="$HOME/Applications/$app.app/Contents"
  check "$app: executable links into the repo" test -x "$a/MacOS/$exe"
  check "$app: plist executable matches" eq "$(plutil -extract CFBundleExecutable raw "$DIR/$plist")" "$exe"
  check "$app: plist icon matches" eq "$(plutil -extract CFBundleIconFile raw "$DIR/$plist")" "$icon"
  check "$app: display name" eq "$(plutil -extract CFBundleDisplayName raw "$DIR/$plist")" "$app"
  check "$app: icon in the bundle" test -s "$a/Resources/$icon.icns"
  check "$app: registered" contains "$(cat "$CALLS")" "lsregister -f $HOME/Applications/$app.app"
done <<'APPS'
Network Log|network-log|log-Info.plist|LogIcon
Network Stop|network-stop|stop-Info.plist|StopIcon
Network Start|network-start|start-Info.plist|StartIcon
APPS

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
