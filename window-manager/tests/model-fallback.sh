#!/opt/homebrew/bin/bash
# Model fallback in yabai-snap.sh, against stubbed yabai and ioreg.
#   window-manager/tests/model-fallback.sh
set -uo pipefail

SNAP="$(cd "$(dirname "$0")/../config" && pwd)/yabai-snap.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/model-fallback.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"

cat > "$WORK/bin/yabai" <<'EOF'
#!/bin/sh
case "$*" in
  "-m query --displays") cat "$FIXTURE_DISPLAYS" ;;
  "-m query --windows --window") [ -s "$FIXTURE_WINDOW" ] && cat "$FIXTURE_WINDOW" ;;
  "-m window "*) echo "$*" >> "$FIXTURE_LOG" ;;
esac
exit 0
EOF
cat > "$WORK/bin/ioreg" <<'EOF'
#!/bin/sh
echo ioreg >> "$FIXTURE_LOG"
cat "$FIXTURE_IOREG"
EOF
chmod +x "$WORK/bin/yabai" "$WORK/bin/ioreg"

export PATH="$WORK/bin:$PATH"
export FIXTURE_DISPLAYS="$WORK/displays.json" FIXTURE_IOREG="$WORK/ioreg.txt"
export FIXTURE_WINDOW="$WORK/window.json" FIXTURE_LOG="$WORK/log"
export YABAI_ZONES_FILE="$WORK/zones.conf" YABAI_SNAP_LOG="$WORK/snap.log"

LAPTOP=37D8832A-2D66-02CA-B9F7-8F30A301B230
HP=AAAAAAAA-1111-2222-3333-444444444444
DELL=BBBBBBBB-1111-2222-3333-444444444444

ioreg_laptop='    | |   "DisplayAttributes" = {"ProductAttributes"={"ManufacturerID"="00-10-fa","ProductID"=62900604580929}}'
ioreg_hp='    | |   "DisplayAttributes" = {"PortID"=16,"ProductAttributes"={"ManufacturerID"="HPN","ProductName"="HP E34m G4","ProductID"=14166},"NativeFormatHorizontalPixels"=3440,"AspectRatio"=17,"NativeFormatVerticalPixels"=1440}'
ioreg_dell='    | |   "DisplayAttributes" = {"ProductAttributes"={"ProductName"="DELL U2723QE","ProductID"=1},"NativeFormatHorizontalPixels"=3840,"NativeFormatVerticalPixels"=2160}'

disp() { printf '{"index":%s,"uuid":"%s","frame":{"x":%s,"y":0.0000,"w":%s,"h":%s},"has-focus":%s}' "$@"; }

# setup <displays...> : writes displays.json (laptop first) and resets the rest
setup() {
  local IFS=,
  printf '[%s]\n' "$(disp 1 "$LAPTOP" 0 1470.0000 956.0000 true)${*:+,$*}" > "$FIXTURE_DISPLAYS"
  printf '%s\n' "$ioreg_laptop" "$ioreg_hp" "$ioreg_dell" > "$FIXTURE_IOREG"
  : > "$FIXTURE_WINDOW"; : > "$FIXTURE_LOG"
}
hp_disp()   { disp 2 "$HP" 1470 3440.0000 1440.0000 false; }
dell_disp() { disp 3 "$DELL" 4910 2560.0000 1440.0000 false; }

zones() {
  cat > "$YABAI_ZONES_FILE"
  printf '%s\n' "# --- Monitors" "monitor $LAPTOP  MacBook  laptop" >> "$YABAI_ZONES_FILE"
  printf '%s\n' "layout MacBook 50 50" "layout default 50 50" >> "$YABAI_ZONES_FILE"
}

run() { OUT="$("$SNAP" "$@" 2>&1)"; }
row() { printf '%s\n' "$OUT" | grep -- "$1"; }

fails=0
check() {  # check <name> <condition...>
  local name="$1"; shift
  if "$@"; then echo "PASS  $name"; else echo "FAIL  $name"; fails=$((fails + 1)); fi
}
matches() { [[ "$1" =~ $2 ]]; }
monitor_lines() { grep -cE "^(\* |  )?monitor $1" "$YABAI_ZONES_FILE"; }

# 1. UUID named with its own layout wins over a model rule
setup "$(hp_disp)"
zones <<EOF
monitor $HP  HP  home
layout HP 40 60
model HP-E34m-G4 Shared
layout Shared 30 70
EOF
run connected
check "1 own layout wins over model rule" matches "$(row "$HP")" ' HP +home +40 60 +HP-E34m-G4$'
check "1 laptop has no model" matches "$(row "$LAPTOP")" ' MacBook +laptop +50 50 +-$'

# 2. unknown UUID + matching model rule -> rule's layout, not registered
setup "$(hp_disp)"
zones <<EOF
model HP-E34m-G4 Shared
layout Shared 30 70
EOF
run connected
check "2 unknown UUID uses model rule" matches "$(row "$HP")" ' - +- +30 70 +HP-E34m-G4$'
check "2 unknown UUID not registered" [ "$(monitor_lines "$HP")" = 0 ]

# 3. UUID registered as mon-XXXX (no layout) + model rule -> rule's layout
setup "$(hp_disp)"
zones <<EOF
monitor $HP  mon-AAAAAAAA  unknown    # 3440pt, first seen 2026-10-01
model HP-E34m-G4 Shared
layout Shared 30 70
EOF
run connected
check "3 mon- UUID uses model rule" matches "$(row "$HP")" ' mon-AAAAAAAA +unknown +30 70 +HP-E34m-G4$'
check "3 no extra monitor line" [ "$(monitor_lines "$HP")" = 1 ]

# 4. unknown UUID, no rule -> default layout, registered with product name
setup "$(hp_disp)"
zones < /dev/null
run connected
check "4 no rule uses default" matches "$(row "$HP")" ' mon-AAAAAAAA +unknown +50 50 +HP-E34m-G4$'
check "4 registered with product name" grep -q "^\* monitor $HP  mon-AAAAAAAA          unknown                  # 3440pt, HP-E34m-G4, first seen [0-9-]*$" "$YABAI_ZONES_FILE"
check "4 laptop not registered again" [ "$(monitor_lines "$LAPTOP")" = 1 ]

# 5. two externals, different models and aspect ratios -> each its own rule
setup "$(hp_disp)" "$(dell_disp)"
zones <<EOF
model HP-E34m-G4 Wide
model DELL-U2723QE Square
layout Wide 25 50 25
layout Square 60 40
EOF
run connected
check "5 HP gets its rule" matches "$(row "$HP")" ' 25 50 25 +HP-E34m-G4$'
check "5 Dell gets its rule" matches "$(row "$DELL")" ' 60 40 +DELL-U2723QE$'
check "5 neither registered" [ "$(monitor_lines "$HP")$(monitor_lines "$DELL")" = 00 ]

# 6. two connected monitors of the same ratio but different models -> no model
setup "$(hp_disp)"
printf '%s\n' "$ioreg_hp" "${ioreg_hp/HP E34m G4/LG 34WN80C}" > "$FIXTURE_IOREG"
zones <<EOF
model HP-E34m-G4 Shared
layout Shared 30 70
EOF
run connected
check "6 ambiguous model falls back to default" matches "$(row "$HP")" ' mon-AAAAAAAA +unknown +50 50 +-$'

# 7. snapping uses the model rule's zones
setup "$(hp_disp)"
echo '{"id":42,"display":2,"frame":{"x":1470,"y":0,"w":3440,"h":1440}}' > "$FIXTURE_WINDOW"
zones <<EOF
model HP-E34m-G4 Shared
layout Shared 30 70
EOF
run left
check "7 snap left uses model rule zone" grep -q -- "--grid 1:100:0:0:30:1" "$FIXTURE_LOG"

# 8. snapping on a display with its own layout never calls ioreg
setup
echo '{"id":42,"display":1,"frame":{"x":0,"y":0,"w":1470,"h":956}}' > "$FIXTURE_WINDOW"
zones < /dev/null
run left
check "8 own layout snaps without ioreg" [ "$(grep -c ioreg "$FIXTURE_LOG")" = 0 ]
check "8 snap left uses own layout" grep -q -- "--grid 1:100:0:0:50:1" "$FIXTURE_LOG"

# 9. the connected block goes to connected.txt next to zones.conf, never into zones.conf
setup "$(hp_disp)"
zones <<EOF
monitor $HP  HP  home
layout HP 40 60
EOF
run connected
before="$(cat "$YABAI_ZONES_FILE")"
run connected
check "9 zones.conf unchanged once marks are current" [ "$(cat "$YABAI_ZONES_FILE")" = "$before" ]
check "9 connected.txt written" grep -q "Currently connected" "$(dirname "$YABAI_ZONES_FILE")/connected.txt"
check "9 connected.txt lists HP" grep -q "$HP" "$(dirname "$YABAI_ZONES_FILE")/connected.txt"

# 10. a new monitor is registered right after the last monitor line, not at the end of the file
setup "$(hp_disp)"
zones < /dev/null
echo "arrange home bottom MacBook" >> "$YABAI_ZONES_FILE"
run connected
check "10 registered after the last monitor line" [ "$(grep -A1 "monitor $LAPTOP" "$YABAI_ZONES_FILE" | sed -n 2p | cut -d" " -f3)" = "$HP" ]
check "10 file still ends with the arrange line" [ "$(tail -n1 "$YABAI_ZONES_FILE")" = "arrange home bottom MacBook" ]

# 11. registering keeps a symlinked zones.conf a symlink
setup "$(hp_disp)"
zones < /dev/null
mv "$YABAI_ZONES_FILE" "$WORK/real.conf"; ln -s "$WORK/real.conf" "$YABAI_ZONES_FILE"
run connected
check "11 zones.conf still a symlink" [ -L "$YABAI_ZONES_FILE" ]
check "11 registered in the link target" [ "$(monitor_lines "$HP")" = 1 ]
rm -f "$YABAI_ZONES_FILE" "$WORK/real.conf"

# 12. connected monitor lines get "* ", disconnected ones lose it
setup
zones <<EOF
* monitor $HP  HP  home
EOF
run connected
check "12 connected laptop marked" grep -q "^\* monitor $LAPTOP  MacBook  laptop$" "$YABAI_ZONES_FILE"
check "12 disconnected HP unmarked" grep -q "^  monitor $HP  HP  home$" "$YABAI_ZONES_FILE"

# 13. a marked line is still read as a monitor line
setup "$(hp_disp)"
zones <<EOF
* monitor $HP  HP  home
layout HP 40 60
EOF
run connected
check "13 marked line keeps its layout" matches "$(row "$HP")" ' HP +home +40 60 +HP-E34m-G4$'
check "13 not registered again" [ "$(grep -c "$HP" "$YABAI_ZONES_FILE")" = 1 ]

# 14. a model line is marked while a screen without its own line uses it
setup "$(hp_disp)"
zones <<EOF
model HP-E34m-G4 Shared home
* model DELL-U2723QE Square
layout Shared 30 70
EOF
run connected
check "14 used model rule marked" grep -q "^\* model HP-E34m-G4 Shared home$" "$YABAI_ZONES_FILE"
check "14 unused model rule unmarked" grep -q "^  model DELL-U2723QE Square$" "$YABAI_ZONES_FILE"
check "14 marked rule still applies" matches "$(row "$HP")" ' - +- +30 70 +HP-E34m-G4$'
check "14 marked rule still blocks registering" [ "$(monitor_lines "$HP")" = 0 ]

# 15. registering goes after the last monitor line even when it is marked
setup
zones < /dev/null
printf '%s\n' "* monitor $HP  HP  home" >> "$YABAI_ZONES_FILE"
setup "$(hp_disp)" "$(dell_disp)"
run connected
check "15 registered after the marked line" [ "$(grep -A1 "monitor $HP" "$YABAI_ZONES_FILE" | sed -n 2p | cut -d' ' -f3)" = "$DELL" ]

# 16. no layout lines at all: zones fall back to 50 50 and still cross displays
setup
printf '%s\n' "monitor $LAPTOP  MacBook  laptop" > "$YABAI_ZONES_FILE"
echo '{"id":42,"display":1,"frame":{"x":735,"y":0,"w":735,"h":956}}' > "$FIXTURE_WINDOW"
run left
check "16 fallback snaps to the left half" grep -q -- "--grid 1:100:0:0:50:1" "$FIXTURE_LOG"
: > "$FIXTURE_LOG"
echo '{"id":42,"display":1,"frame":{"x":0,"y":0,"w":735,"h":956}}' > "$FIXTURE_WINDOW"
run left
check "16 fallback left zone crosses west" grep -q -- "--display west" "$FIXTURE_LOG"

# 17. concurrent runs never empty zones.conf (several fire at once on yabai start)
lost=0
for round in 1 2 3 4 5 6 7 8 9 10; do
  setup "$(hp_disp)" "$(dell_disp)"
  zones <<EOF
* monitor $HP  HP  home
layout HP 40 60
EOF
  for i in 1 2 3 4 5 6 7 8; do "$SNAP" connected >/dev/null 2>&1 & done
  wait
  grep -q "^layout MacBook 50 50$" "$YABAI_ZONES_FILE" || lost=$((lost + 1))
done
check "17 concurrent runs keep the layouts" [ "$lost" = 0 ]

# 18. rewriting keeps the file mode
setup "$(hp_disp)"
zones < /dev/null
chmod 644 "$YABAI_ZONES_FILE"
run connected
check "18 mode kept" [ "$(stat -f %Lp "$YABAI_ZONES_FILE")" = 644 ]

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
