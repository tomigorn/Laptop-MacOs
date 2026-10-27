#!/opt/homebrew/bin/bash
# Fixed bottom gap in yabai-snap.sh (Dock not always detected), against stubbed yabai.
#   window-manager/tests/bottom.sh
set -uo pipefail

SNAP="$(cd "$(dirname "$0")/../config" && pwd)/yabai-snap.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/bottom.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"

cat > "$WORK/bin/yabai" <<'EOF'
#!/bin/sh
case "$*" in
  "-m query --displays") cat "$FIXTURE_DISPLAYS" ;;
  "-m query --windows --window"*) cat "$FIXTURE_WINDOW" ;;
  "-m window "*) echo "$*" >> "$FIXTURE_LOG" ;;
esac
exit 0
EOF
cat > "$WORK/bin/ioreg" <<'EOF'
#!/bin/sh
EOF
chmod +x "$WORK/bin/yabai" "$WORK/bin/ioreg"

export PATH="$WORK/bin:$PATH"
export FIXTURE_DISPLAYS="$WORK/displays.json" FIXTURE_WINDOW="$WORK/window.json" FIXTURE_LOG="$WORK/log"
export YABAI_ZONES_FILE="$WORK/zones.conf"

LAPTOP=37D8832A-2D66-02CA-B9F7-8F30A301B230

# setup <display y> <display h> <window y> <window h>: one display, window 42 as yabai left it after --grid
setup() {
  printf '[{"index":1,"uuid":"%s","frame":{"x":0.0000,"y":%s.0000,"w":1470.0000,"h":%s.0000},"has-focus":true}]' \
    "$LAPTOP" "$1" "$2" > "$FIXTURE_DISPLAYS"
  printf '{"id":42,"display":1,"frame":{"x":0.0000,"y":%s.0000,"w":1470.0000,"h":%s.0000}}' "$3" "$4" > "$FIXTURE_WINDOW"
  rm -f "$FIXTURE_LOG"
}
zones() { cat > "$YABAI_ZONES_FILE"; printf '%s\n' "monitor $LAPTOP  MacBook  laptop" "layout MacBook 50 50" >> "$YABAI_ZONES_FILE"; }
log() { [ -f "$FIXTURE_LOG" ] && cat "$FIXTURE_LOG"; }

fails=0
check() {  # check <name> <condition...>
  local name="$1"; shift
  if "$@"; then echo "PASS  $name"; else echo "FAIL  $name"; fails=$((fails + 1)); fi
}
contains() { [[ "$1" == *"$2"* ]]; }

# 1. Dock not detected: yabai fills down to the display bottom, bottom 59 cuts it
setup 0 956 33 923
zones <<< "bottom 59"
"$SNAP" fill
check "1 grid first" contains "$(log)" "-m window 42 --grid 1:1:0:0:1:1"
check "1 height ends 59pt above bottom" contains "$(log)" "-m window 42 --resize abs:1470:864"

# 2. no bottom line: default 59
setup 0 956 33 923
zones < /dev/null
"$SNAP" fill
check "2 default 59" contains "$(log)" "-m window 42 --resize abs:1470:864"

# 3. Dock detected (yabai already left room): same fixed height
setup 0 956 33 864
zones <<< "bottom 59"
"$SNAP" left
check "3 same height" contains "$(log)" "-m window 42 --resize abs:1470:864"

# 4. bottom 0, display not at the origin
setup -484 1440 -459 1415
zones <<< "bottom 0"
"$SNAP" fill
check "4 down to the bottom edge" contains "$(log)" "-m window 42 --resize abs:1470:1415"

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
