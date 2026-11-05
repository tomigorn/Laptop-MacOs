#!/opt/homebrew/bin/bash
# window-manager/restart-launcher.sh with stubbed yabai, skhd, pgrep and osascript: the banner tells what really happened.
#   window-manager/tests/restart-launcher.sh
set -uo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)/restart-launcher.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/wm-restart.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
export PATH="$WORK/bin:$PATH" LOG="$WORK/log"

for tool in yabai skhd; do
  cat > "$WORK/bin/$tool" <<STUB
#!/bin/sh
echo "$tool \$*" >> "\$LOG"
exit 0
STUB
done
cat > "$WORK/bin/pgrep" <<'STUB'
#!/bin/sh
case " ${DOWN:-} " in *" $2 "*) exit 1 ;; esac
exit 0
STUB
cat > "$WORK/bin/sleep" <<'STUB'
#!/bin/sh
STUB
cat > "$WORK/bin/osascript" <<'STUB'
#!/bin/sh
echo "$2" > "$LOG.banner"
STUB
chmod +x "$WORK/bin/"*

fails=0
check() {  # check <name> <condition...>
  local name="$1"; shift
  if "$@"; then echo "PASS  $name"; else echo "FAIL  $name"; fails=$((fails + 1)); fi
}
contains() { [[ "$1" == *"$2"* ]]; }
lacks() { [[ "$1" != *"$2"* ]]; }
banner() { cat "$LOG.banner" 2>/dev/null; }
run() { rm -f "$LOG" "$LOG.banner"; bash "$SRC"; }

# the stubs must come first on PATH, or this test would restart the real services
run
check "restarts the stubbed yabai" contains "$(cat "$LOG")" "yabai --restart-service"
check "restarts the stubbed skhd" contains "$(cat "$LOG")" "skhd --restart-service"

check "both running: says restarted" contains "$(banner)" "yabai + skhd restarted"
check "both running: reloaded title" contains "$(banner)" "Window manager reloaded"

DOWN=yabai run
check "yabai down: names it" contains "$(banner)" "yabai is not running"
check "yabai down: failure title" contains "$(banner)" "Window manager restart failed"
check "yabai down: no success text" lacks "$(banner)" "restarted\""

DOWN=skhd run
check "skhd down: names it" contains "$(banner)" "skhd is not running"
check "skhd down: failure title" contains "$(banner)" "Window manager restart failed"

DOWN="yabai skhd" run
check "both down: names both" contains "$(banner)" "yabai skhd is not running"

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
