#!/opt/homebrew/bin/bash
# homelab-dns/log-launcher.sh with stubbed open: script folder plus log link in a new VS Code window, fallback by app name.
#   homelab-dns/tests/log-launcher.sh
set -uo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)/log-launcher.sh"
FOLDER="$(dirname "$SRC")"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/log-launcher.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
export PATH="$WORK/bin:$PATH" CALLS="$WORK/calls"

cat > "$WORK/bin/open" <<'STUB'
#!/bin/sh
echo "open $*" >> "$CALLS"
case "$*" in "-n -b "*) exit "${OPEN_B_RC:-0}" ;; esac
exit 0
STUB
chmod +x "$WORK/bin/open"

fails=0
check() {  # check <name> <condition...>
  local name="$1"; shift
  if "$@"; then echo "PASS  $name"; else echo "FAIL  $name"; fails=$((fails + 1)); fi
}
eq() { [ "$1" = "$2" ]; }
calls() { [ -f "$CALLS" ] && cat "$CALLS" || true; }

BUNDLE="open -n -b com.microsoft.VSCode --args --new-window $FOLDER $FOLDER/homelab-dns.log"
BY_NAME="open -n -a Visual Studio Code --args --new-window $FOLDER $FOLDER/homelab-dns.log"

rm -f "$CALLS"
bash "$SRC"; rc=$?
check "opens the script folder and the log link in a new window" eq "$(calls)" "$BUNDLE"
check "exit 0" test "$rc" -eq 0

rm -f "$CALLS"
OPEN_B_RC=1 bash "$SRC"
check "bundle id fails: falls back to app name" eq "$(calls)" "$BUNDLE"$'\n'"$BY_NAME"

rm -f "$CALLS"
ln -s "$SRC" "$WORK/app-executable"
bash "$WORK/app-executable"
check "started through the app's symlink: still the repo folder" eq "$(calls)" "$BUNDLE"

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
