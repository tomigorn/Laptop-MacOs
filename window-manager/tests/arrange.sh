#!/opt/homebrew/bin/bash
# "arrange" in yabai-snap.sh, against stubbed yabai, ioreg and displayplacer.
#   window-manager/tests/arrange.sh
set -uo pipefail

SNAP="$(cd "$(dirname "$0")/../config" && pwd)/yabai-snap.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/arrange.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"

cat > "$WORK/bin/yabai" <<'EOF'
#!/bin/sh
case "$*" in
  "-m query --displays") cat "$FIXTURE_DISPLAYS" ;;
  "-m query --windows --window") [ -s "$FIXTURE_WINDOW" ] && cat "$FIXTURE_WINDOW" ;;
esac
exit 0
EOF
cat > "$WORK/bin/ioreg" <<'EOF'
#!/bin/sh
cat "$FIXTURE_IOREG"
EOF
cat > "$WORK/bin/displayplacer" <<'EOF'
#!/bin/sh
if [ "$1" = list ]; then cat "$FIXTURE_LIST"; exit 0; fi
for a in "$@"; do echo "$a"; done > "$FIXTURE_APPLIED"
EOF
chmod +x "$WORK/bin/yabai" "$WORK/bin/ioreg" "$WORK/bin/displayplacer"

export PATH="$WORK/bin:$PATH"
export FIXTURE_DISPLAYS="$WORK/displays.json" FIXTURE_IOREG="$WORK/ioreg.txt"
export FIXTURE_WINDOW="$WORK/window.json" FIXTURE_LIST="$WORK/list.txt" FIXTURE_APPLIED="$WORK/applied"
export YABAI_ZONES_FILE="$WORK/zones.conf"

LAPTOP=37D8832A-2D66-02CA-B9F7-8F30A301B230
HP=9EF24336-093D-4B36-8D24-BA95A65D1EEB
DELL=BBBBBBBB-1111-2222-3333-444444444444

ioreg_hp='    | |   "DisplayAttributes" = {"PortID"=16,"ProductAttributes"={"ManufacturerID"="HPN","ProductName"="HP E34m G4","ProductID"=14166},"NativeFormatHorizontalPixels"=3440,"AspectRatio"=17,"NativeFormatVerticalPixels"=1440}'
ioreg_dell='    | |   "DisplayAttributes" = {"ProductAttributes"={"ProductName"="DELL U2723QE","ProductID"=1},"NativeFormatHorizontalPixels"=3840,"NativeFormatVerticalPixels"=2160}'

# screen <uuid> <w> <h> <x> <y> <res> <scaling> <hz>
LAPTOP_AT() { echo "$LAPTOP 1470 956 $1 $2 1470x956 on 60"; }
HP_AT()     { echo "$HP 3440 1440 $1 $2 3440x1440 off 75"; }
DELL_AT()   { echo "$DELL 2560 1440 $1 $2 2560x1440 on 60"; }

# setup <screen>... : yabai displays, ioreg and the displayplacer list for these screens
setup() {
  local s i=0 sep="" json="" cmd="displayplacer" uuid w h x y res sc hz
  : > "$FIXTURE_LIST"
  for s in "$@"; do
    read -r uuid w h x y res sc hz <<<"$s"
    i=$((i + 1))
    json+="$sep$(printf '{"index":%s,"uuid":"%s","frame":{"x":%s.0000,"y":%s.0000,"w":%s.0000,"h":%s.0000},"has-focus":%s}' \
      "$i" "$uuid" "$x" "$y" "$w" "$h" "$([ "$i" = 1 ] && echo true || echo false)")"; sep=","
    { echo "Persistent screen id: $uuid"; echo "Contextual screen id: $i"; echo "Resolution: $res"
      echo "Scaling: $sc"; echo "Origin: ($x,$y)$([ "$x,$y" = 0,0 ] && echo ' - main display')"
      echo "Rotation: 0"; echo "Enabled: true"; echo; } >> "$FIXTURE_LIST"
    cmd+=" \"id:$uuid res:$res hz:$hz color_depth:8 enabled:true scaling:$sc origin:($x,$y) degree:0\""
  done
  echo "[$json]" > "$FIXTURE_DISPLAYS"
  { echo "Execute the command below to set your screens to the current arrangement. If screen ids are switching, please run \`displayplacer --help\` for info on using contextual or serial ids instead of persistent ids."
    echo; echo "$cmd"; } >> "$FIXTURE_LIST"
  printf '%s\n' "$ioreg_hp" "$ioreg_dell" > "$FIXTURE_IOREG"
  : > "$FIXTURE_WINDOW"; rm -f "$FIXTURE_APPLIED"
}

# zones: stdin plus the laptop line and layouts
zones() {
  cat > "$YABAI_ZONES_FILE"
  printf '%s\n' "monitor $LAPTOP  MacBook  laptop" "layout MacBook 50 50" "layout default 50 50" >> "$YABAI_ZONES_FILE"
}
fixed_desk() {
  printf '%s\n' "monitor $HP  Work-HP-Ultrawide  Work5-WEV" "monitor $DELL  Work-Dell  Work5-WEV" \
    "layout Work-HP-Ultrawide 25 50 25" "layout Work-Dell 50 50"
}

run() { OUT="$("$SNAP" "$@" 2>"$WORK/err")"; RC=$?; ERR="$(cat "$WORK/err")"; }
applied() { [ -f "$FIXTURE_APPLIED" ] && cat "$FIXTURE_APPLIED"; }
arg_for() { applied | grep "^id:$1 "; }

fails=0
check() {  # check <name> <condition...>
  local name="$1"; shift
  if "$@"; then echo "PASS  $name"; else echo "FAIL  $name"; fails=$((fails + 1)); fi
}
same() { [ "$1" = "$2" ]; }
contains() { [[ "$1" == *"$2"* ]]; }
not_applied() { [ ! -f "$FIXTURE_APPLIED" ]; }

# 1. fixed desk, bottom aligned, laptop main
setup "$(LAPTOP_AT 0 0)" "$(HP_AT 1470 -484)" "$(DELL_AT 4910 -484)"
zones <<EOF
$(fixed_desk)
arrange Work5-WEV bottom Work-Dell Work-HP-Ultrawide MacBook
EOF
run arrange
check "1 exit 0" same "$RC" 0
check "1 three args applied" same "$(applied | wc -l | tr -d ' ')" 3
check "1 Dell origin" same "$(arg_for "$DELL")" "id:$DELL res:2560x1440 hz:60 color_depth:8 enabled:true scaling:on origin:(-6000,-484) degree:0"
check "1 HP origin" same "$(arg_for "$HP")" "id:$HP res:3440x1440 hz:75 color_depth:8 enabled:true scaling:off origin:(-3440,-484) degree:0"
check "1 laptop stays main" same "$(arg_for "$LAPTOP")" "id:$LAPTOP res:1470x956 hz:60 color_depth:8 enabled:true scaling:on origin:(0,0) degree:0"
check "1 keeps displayplacer order" same "$(applied | cut -d' ' -f1 | tr '\n' ' ')" "id:$LAPTOP id:$HP id:$DELL "
check "1 prints applied command" contains "$OUT" "\"id:$DELL res:2560x1440 hz:60 color_depth:8 enabled:true scaling:on origin:(-6000,-484) degree:0\""

# 2. open office: unknown UUID matched by model rule with location
setup "$(LAPTOP_AT 0 0)" "$(HP_AT 1470 0)"
zones <<EOF
model HP-E34m-G4 Work-HP-Ultrawide open-office
arrange Work5-WEV bottom Work-Dell Work-HP-Ultrawide MacBook
arrange open-office bottom Work-HP-Ultrawide MacBook
EOF
run arrange
check "2 HP left of laptop" contains "$(arg_for "$HP")" "origin:(-3440,-484) "
check "2 laptop stays main" contains "$(arg_for "$LAPTOP")" "origin:(0,0) "

# 3. no matching arrange line
setup "$(LAPTOP_AT 0 0)" "$(HP_AT 1470 0)"
zones <<EOF
model HP-E34m-G4 Work-HP-Ultrawide open-office
arrange Work5-WEV bottom Work-HP-Ultrawide MacBook
EOF
run arrange
check "3 exit 0" same "$RC" 0
check "3 note on stderr" contains "$ERR" "no arrange line for the connected screens"
check "3 displayplacer not called" not_applied

# 4. already arranged
setup "$(LAPTOP_AT 0 0)" "$(HP_AT -3440 -484)" "$(DELL_AT -6000 -484)"
zones <<EOF
$(fixed_desk)
arrange Work5-WEV bottom Work-Dell Work-HP-Ultrawide MacBook
EOF
run arrange
check "4 says already arranged" contains "$OUT$ERR" "already arranged"
check "4 displayplacer not called" not_applied

# 5. top alignment
setup "$(LAPTOP_AT 0 0)" "$(HP_AT 1470 -484)" "$(DELL_AT 4910 -484)"
zones <<EOF
$(fixed_desk)
arrange Work5-WEV top Work-Dell Work-HP-Ultrawide MacBook
EOF
run arrange
check "5 top Dell" contains "$(arg_for "$DELL")" "origin:(-6000,0) "
check "5 top HP" contains "$(arg_for "$HP")" "origin:(-3440,0) "
check "5 top laptop" contains "$(arg_for "$LAPTOP")" "origin:(0,0) "

# 6. center alignment
setup "$(LAPTOP_AT 0 0)" "$(HP_AT 1470 -484)" "$(DELL_AT 4910 -484)"
zones <<EOF
$(fixed_desk)
arrange Work5-WEV center Work-Dell Work-HP-Ultrawide MacBook
EOF
run arrange
check "6 center Dell" contains "$(arg_for "$DELL")" "origin:(-6000,-242) "
check "6 center HP" contains "$(arg_for "$HP")" "origin:(-3440,-242) "
check "6 center laptop" contains "$(arg_for "$LAPTOP")" "origin:(0,0) "

# 7. a line with fewer names than connected screens is skipped
setup "$(LAPTOP_AT 0 0)" "$(HP_AT 1470 -484)" "$(DELL_AT 4910 -484)"
zones <<EOF
$(fixed_desk)
arrange Work5-WEV top Work-HP-Ultrawide MacBook
arrange Work5-WEV bottom Work-HP-Ultrawide Work-Dell MacBook
EOF
run arrange
check "7 short line skipped" contains "$(arg_for "$DELL")" "origin:(-2560,-484) "
check "7 full line used" contains "$(arg_for "$HP")" "origin:(-6000,-484) "

setup "$(LAPTOP_AT 0 0)" "$(HP_AT 1470 -484)" "$(DELL_AT 4910 -484)"
zones <<EOF
$(fixed_desk)
arrange Work5-WEV bottom Work-HP-Ultrawide MacBook
EOF
run arrange
check "7 only short line -> none" contains "$ERR" "no arrange line for the connected screens"
check "7 displayplacer not called" not_applied

# 8. main is not the leftmost-listed screen: shift keeps the main at (0,0)
setup "$(HP_AT 0 0)" "$(LAPTOP_AT 3440 0)" "$(DELL_AT 4910 0)"
zones <<EOF
$(fixed_desk)
arrange Work5-WEV bottom Work-Dell Work-HP-Ultrawide MacBook
EOF
run arrange
check "8 HP main stays (0,0)" contains "$(arg_for "$HP")" "origin:(0,0) "
check "8 Dell left of HP" contains "$(arg_for "$DELL")" "origin:(-2560,0) "
check "8 laptop right of HP" contains "$(arg_for "$LAPTOP")" "origin:(3440,484) "

# 9. displayplacer reports a screen disabled (asleep/locked): never apply
setup "$(LAPTOP_AT 0 0)" "$(HP_AT 1470 -484)" "$(DELL_AT 4910 -484)"
sed -i '' "s/\"id:$HP [^\"]*\"/\"id:$HP enabled:false\"/" "$FIXTURE_LIST"
zones <<EOF
$(fixed_desk)
arrange Work5-WEV bottom Work-Dell Work-HP-Ultrawide MacBook
EOF
run arrange
check "9 exit 0" same "$RC" 0
check "9 note on stderr" contains "$ERR" "reported disabled"
check "9 displayplacer not called" not_applied

# 10. yabai lists no screens (asleep/locked), under macOS bash 3.2
setup "$(LAPTOP_AT 0 0)"
echo "[]" > "$FIXTURE_DISPLAYS"
zones <<EOF
arrange Work5-WEV bottom Work-Dell Work-HP-Ultrawide MacBook
EOF
OUT="$(/bin/bash "$SNAP" arrange 2>"$WORK/err")"; RC=$?; ERR="$(cat "$WORK/err")"
check "10 exit 0" same "$RC" 0
check "10 note on stderr" contains "$ERR" "no screens"
check "10 displayplacer not called" not_applied

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
