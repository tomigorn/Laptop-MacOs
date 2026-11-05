#!/opt/homebrew/bin/bash
# left, right, fill and extend in yabai-snap.sh, against a stubbed yabai that remembers the window, under bash 5 and macOS bash 3.2.
#   window-manager/tests/walk.sh
set -uo pipefail

SNAP="$(cd "$(dirname "$0")/../config" && pwd)/yabai-snap.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/walk.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"

cat > "$WORK/bin/yabai" <<'EOF'
#!/bin/sh
case "$*" in
  "-m query --displays") cat "$FIXTURE_DISPLAYS" ;;
  "-m query --windows --window"*)
    if [ -n "${NO_WINDOW:-}" ]; then echo "could not retrieve window details." >&2; exit 1; fi
    read -r d x w < "$FIXTURE_STATE"
    printf '{"id":42,"app":"Teams","display":%s,"frame":{"x":%s.0000,"y":33.0000,"w":%s.0000,"h":864.0000}}' "$d" "$x" "$w" ;;
  "-m window "*)
    echo "$*" >> "$FIXTURE_LOG"
    read -r d x w < "$FIXTURE_STATE"
    case "$*" in
      *"--display "*)
        if [ -n "${DISPLAY_FAILS:-}" ]; then echo "could not locate a display." >&2; exit 1; fi
        [ -n "${STAYS:-}" ] || case "$*" in
          *east*) echo "2 $x $w" > "$FIXTURE_STATE" ;;
          *west*) echo "1 $x $w" > "$FIXTURE_STATE" ;;
        esac ;;
      *"--grid "*) [ -z "${GRID_FRAME:-}" ] || echo "$d $GRID_FRAME" > "$FIXTURE_STATE" ;;
    esac ;;
esac
exit 0
EOF
cat > "$WORK/bin/ioreg" <<'EOF'
#!/bin/sh
EOF
chmod +x "$WORK/bin/yabai" "$WORK/bin/ioreg"

export PATH="$WORK/bin:$PATH"
export FIXTURE_DISPLAYS="$WORK/displays.json" FIXTURE_STATE="$WORK/state" FIXTURE_LOG="$WORK/log"
export YABAI_ZONES_FILE="$WORK/zones.conf" YABAI_SNAP_LOG="$WORK/snap.log"

LAPTOP=37D8832A-2D66-02CA-B9F7-8F30A301B230
HP=AAAAAAAA-1111-2222-3333-444444444444
printf '[{"index":1,"uuid":"%s","frame":{"x":0.0000,"y":0.0000,"w":1470.0000,"h":956.0000},"has-focus":true},{"index":2,"uuid":"%s","frame":{"x":1470.0000,"y":-484.0000,"w":3440.0000,"h":1440.0000},"has-focus":false}]' "$LAPTOP" "$HP" > "$FIXTURE_DISPLAYS"

MAC_L=1:100:0:0:50:1 MAC_R=1:100:50:0:50:1 HP_L=1:100:0:0:65:1 HP_R=1:100:65:0:35:1

layout() { printf '%s\n' "monitor $LAPTOP  MacBook  laptop" "monitor $HP  HP  office" "layout MacBook $1" "layout HP 65 35" > "$YABAI_ZONES_FILE"; }
# at <display> <x> <w>: where the focused window is
at() { echo "$*" > "$FIXTURE_STATE"; rm -f "$FIXTURE_LOG"; }
# yabai's calls without the height fix-up, one per line
moves() { [ -f "$FIXTURE_LOG" ] && grep -v -- '--resize' "$FIXTURE_LOG" | sed -e 's/^-m window //' -e 's/^42 //'; }

fails=0
check() {  # check <name> <condition...>
  local name="$1"; shift
  if "$@"; then echo "PASS  $name"; else echo "FAIL  $name"; fails=$((fails + 1)); fi
}
same() { [ "$1" = "$2" ]; }
contains() { [[ "$1" == *"$2"* ]]; }
lacks() { [[ "$1" != *"$2"* ]]; }

suite() {
  local v="$1" shell="$2"
  snap() { "$shell" "$SNAP" "$@" 2>/dev/null; }

  layout "50 50"

  at 1 0 735; snap right
  check "$v right moves to the next zone" same "$(moves)" "--grid $MAC_R"
  at 2 3706 1204; snap left
  check "$v left moves to the previous zone" same "$(moves)" "--grid $HP_L"

  at 1 735 735; snap right
  check "$v right from the last zone crosses to the first zone there" same "$(moves)" $'--display east\n--grid '"$HP_L"$'\n--focus 42'
  at 2 1470 2236; snap left
  check "$v left from the first zone crosses to the last zone there" same "$(moves)" $'--display west\n--grid '"$MAC_R"$'\n--focus 42'

  at 2 3706 1204; DISPLAY_FAILS=1 snap right
  check "$v no screen east keeps the zone" same "$(moves)" $'--display east\n--grid '"$HP_R"
  at 1 0 735; DISPLAY_FAILS=1 snap left
  check "$v no screen west keeps the zone" same "$(moves)" $'--display west\n--grid '"$MAC_L"

  at 1 735 735; STAYS=1 snap right
  check "$v accepted move that stays keeps the zone, right" same "$(moves)" $'--display east\n--grid '"$MAC_R"
  at 2 1470 2236; STAYS=1 snap left
  check "$v accepted move that stays keeps the zone, left" same "$(moves)" $'--display west\n--grid '"$HP_L"

  at 1 0 1470; GRID_FRAME="735 735" snap right
  check "$v filled window goes to the right zone here" same "$(moves)" "--grid $MAC_R"
  at 1 0 1470; GRID_FRAME="0 735" snap left
  check "$v filled window goes to the left zone here" same "$(moves)" "--grid $MAC_L"
  at 1 200 500; GRID_FRAME="735 735" snap right
  check "$v free window goes to the right zone here" same "$(moves)" "--grid $MAC_R"

  at 1 735 1000; snap right
  check "$v window too wide for its zone still crosses east" same "$(moves)" $'--grid '"$MAC_R"$'\n--display east\n--grid '"$HP_L"$'\n--focus 42'
  at 2 1470 3000; snap left
  check "$v window too wide for its zone still crosses west" same "$(moves)" $'--grid '"$HP_L"$'\n--display west\n--grid '"$MAC_R"$'\n--focus 42'
  at 1 0 1000; GRID_FRAME="735 1000" snap right
  check "$v window too wide moves within the screen first" same "$(moves)" "--grid $MAC_R"

  at 1 0 735; snap extend-right
  check "$v extend-right grows into the next zone" same "$(moves)" "--grid 1:100:0:0:100:1"
  at 1 735 735; snap extend-left
  check "$v extend-left grows into the previous zone" same "$(moves)" "--grid 1:100:0:0:100:1"
  at 1 735 735; snap extend-right
  check "$v extend-right stops at the last zone" same "$(moves)" "--grid $MAC_R"
  at 1 0 735; snap extend-left
  check "$v extend-left stops at the first zone" same "$(moves)" "--grid $MAC_L"

  layout "25 50 25"
  at 1 0 367; snap extend-right
  check "$v extend-right, three zones" same "$(moves)" "--grid 1:100:0:0:75:1"
  at 1 1102 368; snap extend-left
  check "$v extend-left, three zones" same "$(moves)" "--grid 1:100:25:0:75:1"

  layout "50 50"
  at 1 0 735; snap fill
  check "$v fill" same "$(moves)" "--grid 1:1:0:0:1:1"
  at 1 0 735; NO_WINDOW=1 snap right
  check "$v no window, no move" same "$(moves)" ""
  at 1 0 735; NO_WINDOW=1 snap fill
  check "$v no window, no fill" same "$(moves)" ""

  layout "50 50 # halves"
  at 1 735 735; snap right
  check "$v comment on a layout line adds no zones" same "$(moves)" $'--display east\n--grid '"$HP_L"$'\n--focus 42'
  local out; out="$("$shell" "$SNAP" connected 2>&1)"
  check "$v connected shows the sizes" contains "$out" "50 50"
  check "$v connected leaves the comment out" lacks "$out" "halves"
}

suite "bash5" /opt/homebrew/bin/bash
suite "bash3" /bin/bash

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
