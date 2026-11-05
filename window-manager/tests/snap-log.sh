#!/opt/homebrew/bin/bash
# Failures of a window move end up in the snap log, against stubbed yabai.
#   window-manager/tests/snap-log.sh
set -uo pipefail

SNAP="$(cd "$(dirname "$0")/../config" && pwd)/yabai-snap.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/snap-log.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"

cat > "$WORK/bin/yabai" <<'EOF'
#!/bin/sh
case "$*" in
  "-m query --displays")
    [ -z "${NO_DISPLAYS:-}" ] || exit 1
    cat "$FIXTURE_DISPLAYS" ;;
  "-m query --windows --window")
    if [ -n "${NO_WINDOW:-}" ]; then echo "could not retrieve window details." >&2; exit 1; fi
    cat "$FIXTURE_WINDOW" ;;
  "-m query --windows --window"*) cat "$FIXTURE_WINDOW" ;;
  *"--display east"*)
    if [ -n "${DISPLAY_FAILS:-}" ]; then echo "could not locate a eastward display." >&2; exit 1; fi ;;
  *"--display west"*)
    if [ -n "${DISPLAY_FAILS:-}" ]; then echo "could not locate a westward display." >&2; exit 1; fi ;;
  *"--grid"*)
    if [ -n "${GRID_FAILS:-}" ]; then echo "could not locate the window to act on!" >&2; exit 1; fi ;;
esac
exit 0
EOF
cat > "$WORK/bin/ioreg" <<'EOF'
#!/bin/sh
EOF
chmod +x "$WORK/bin/yabai" "$WORK/bin/ioreg"

export PATH="$WORK/bin:$PATH"
export FIXTURE_DISPLAYS="$WORK/displays.json" FIXTURE_WINDOW="$WORK/window.json"
export YABAI_ZONES_FILE="$WORK/zones.conf" YABAI_SNAP_LOG="$WORK/snap.log"

LAPTOP=37D8832A-2D66-02CA-B9F7-8F30A301B230
printf '%s\n' "monitor $LAPTOP  MacBook  laptop" "layout MacBook 50 50" > "$YABAI_ZONES_FILE"
printf '[{"index":1,"uuid":"%s","frame":{"x":0.0000,"y":0.0000,"w":1470.0000,"h":956.0000},"has-focus":true}]' "$LAPTOP" > "$FIXTURE_DISPLAYS"

# window <x> <w>: window 42 of app Teams on display 1
window() { printf '{"id":42,"app":"Teams","display":1,"frame":{"x":%s.0000,"y":0.0000,"w":%s.0000,"h":900.0000}}' "$1" "$2" > "$FIXTURE_WINDOW"; }
snaplog() { [ -f "$YABAI_SNAP_LOG" ] && cat "$YABAI_SNAP_LOG"; }
reset() { rm -f "$YABAI_SNAP_LOG"; }

fails=0
check() {  # check <name> <condition...>
  local name="$1"; shift
  if "$@"; then echo "PASS  $name"; else echo "FAIL  $name"; fails=$((fails + 1)); fi
}
contains() { [[ "$1" == *"$2"* ]]; }
empty() { [ -z "$1" ]; }
same() { [ "$1" = "$2" ]; }

# 1. a move inside the screen logs nothing
reset; window 0 735
"$SNAP" right
check "1 no log entry" empty "$(snaplog)"

# 2. no screen to the east: yabai's message, direction and window are logged
reset; window 735 735
DISPLAY_FAILS=1 "$SNAP" right
check "2 direction" contains "$(snaplog)" "--display east failed"
check "2 yabai message" contains "$(snaplog)" "could not locate a eastward display."
check "2 window" contains "$(snaplog)" "Teams"
check "2 command" contains "$(snaplog)" " right: "
check "2 one entry only" same "$(snaplog | wc -l | tr -d ' ')" 1

# 3. same to the west
reset; window 0 735
DISPLAY_FAILS=1 "$SNAP" left
check "3 direction" contains "$(snaplog)" "--display west failed"

# 4. yabai accepts the move but the window stays on its screen
reset; window 735 735
"$SNAP" right
check "4 stayed logged" contains "$(snaplog)" "still on display 1"

# 5. no focused window yabai can act on: the silent exit leaves a line
reset; window 0 735
NO_WINDOW=1 "$SNAP" right
check "5 no window" contains "$(snaplog)" "no window to act on"
check "5 yabai message" contains "$(snaplog)" "could not retrieve window details."

# 6. yabai not answering
reset
NO_DISPLAYS=1 "$SNAP" right
check "6 yabai down" contains "$(snaplog)" "yabai not answering"

# 7. an uncaught failure is logged with its message
reset; window 0 735
GRID_FAILS=1 "$SNAP" right
check "7 yabai message" contains "$(snaplog)" "could not locate the window to act on!"
check "7 failed line" contains "$(snaplog)" "failed at line"
check "7 one failed line" same "$(snaplog | grep -c 'failed at line')" 1

# 8. entries carry date and time
reset; window 735 735
DISPLAY_FAILS=1 "$SNAP" right
check "8 timestamp" contains "$(snaplog)" "$(date +%F) "

# 9. display commands stay out of the log and keep stderr
reset
out="$("$SNAP" arrange 2>&1)"
check "9 arrange stderr" contains "$out" "no arrange line"
check "9 no log entry" empty "$(snaplog)"

# 10. default path: private, under the home folder
HOME_LOG="$WORK/home/.local/state/yabai/snap.log"
mkdir -p "$WORK/home"; window 735 735
env -u YABAI_SNAP_LOG HOME="$WORK/home" DISPLAY_FAILS=1 "$SNAP" right
check "10 default path" contains "$(cat "$HOME_LOG" 2>/dev/null)" "--display east failed"
check "10 folder private" same "$(stat -f %Lp "$(dirname "$HOME_LOG")" 2>/dev/null)" 700
check "10 file private" same "$(stat -f %Lp "$HOME_LOG" 2>/dev/null)" 600

# 11. it outlives reboots, so it stays small and keeps the newest lines
reset; window 735 735
{ for ((i = 0; i < 25000; i++)); do echo "2026-01-01 00:00:00 right: old line to fill the log up $i"; done; echo "newest old line"; } > "$YABAI_SNAP_LOG"
DISPLAY_FAILS=1 "$SNAP" right
check "11 trimmed" [ "$(wc -c < "$YABAI_SNAP_LOG")" -lt 1048576 ]
check "11 newest old line kept" contains "$(snaplog)" "newest old line"
check "11 new entry written" contains "$(snaplog)" "--display east failed"

# 12. Homebrew's jq, also when another jq comes first on PATH
if [ -x /opt/homebrew/bin/jq ]; then
  mkdir -p "$WORK/otherjq"
  printf '#!/bin/sh\ntouch "%s"\nexec /opt/homebrew/bin/jq "$@"\n' "$WORK/otherjq/used" > "$WORK/otherjq/jq"
  chmod +x "$WORK/otherjq/jq"
  reset; window 0 735
  PATH="$WORK/otherjq:$PATH" "$SNAP" right
  check "12 other jq not used" [ ! -e "$WORK/otherjq/used" ]
fi

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
