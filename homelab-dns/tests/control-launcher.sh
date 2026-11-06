#!/opt/homebrew/bin/bash
# homelab-dns/control-launcher.sh with stubbed osascript: flag set or cleared by the name it runs under, notification text.
#   homelab-dns/tests/control-launcher.sh
set -uo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/control-launcher.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/state"
export PATH="$WORK/bin:$PATH" CALLS="$WORK/calls"
cat > "$WORK/bin/osascript" <<'STUB'
#!/bin/sh
echo "$*" >> "$CALLS"
STUB
chmod +x "$WORK/bin/osascript"

sed "s|^STATE_DIR=.*|STATE_DIR=\"$WORK/state\"|" "$DIR/control-launcher.sh" > "$WORK/network-stop"
grep -q "^STATE_DIR=\"$WORK/state\"" "$WORK/network-stop" || { echo "FAIL  STATE_DIR substitution"; exit 1; }
cp "$WORK/network-stop" "$WORK/network-start"
chmod +x "$WORK/network-stop" "$WORK/network-start"

fails=0
check() {  # check <name> <condition...>
  local name="$1"; shift
  if "$@"; then echo "PASS  $name"; else echo "FAIL  $name"; fails=$((fails + 1)); fi
}
contains() { [[ "$1" == *"$2"* ]]; }
calls() { [ -f "$CALLS" ] && cat "$CALLS" || true; }

"$WORK/network-stop"
check "stop: flag set" test -e "$WORK/state/stopped"
check "stop: notifies" contains "$(calls)" "Stopped"
rm -f "$CALLS"; "$WORK/network-stop"
check "stop twice: says so" contains "$(calls)" "Already stopped"
check "stop twice: flag still set" test -e "$WORK/state/stopped"

rm -f "$CALLS"; "$WORK/network-start"
check "start: flag gone" test ! -e "$WORK/state/stopped"
check "start: notifies" contains "$(calls)" "Started"
rm -f "$CALLS"; "$WORK/network-start"
check "start twice: says so" contains "$(calls)" "Already running"

rmdir "$WORK/state"; rm -f "$CALLS"; "$WORK/network-stop"; rc=$?
check "not installed: tells to install" contains "$(calls)" "install.sh"
check "not installed: exit 1" test "$rc" -eq 1

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
