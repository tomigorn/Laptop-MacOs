#!/opt/homebrew/bin/bash
# backdrop-wallpaper in a temp HOME with fixture photos; --no-apply keeps the real wallpaper untouched.
#   backdrop-carousel/tests/wallpaper.sh
set -uo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)/wallpaper.swift"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/wallpaper.XXXXXX")"
trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$WORK"' EXIT
BIN="$WORK/backdrop-wallpaper"
swiftc -O "$SRC" -o "$BIN" 2>"$WORK/build.log" || { cat "$WORK/build.log"; echo "build failed"; exit 1; }

export HOME="$WORK/home"
PHOTOS="$HOME/Pictures/BackdropCarousel"
CURRENT="$HOME/Pictures/BackdropCarousel Current"
STATE="$HOME/.local/state/backdrop-carousel"

fails=0
check() {  # check <name> <condition...>
  local name="$1"; shift
  if "$@"; then echo "PASS  $name"; else echo "FAIL  $name"; fails=$((fails + 1)); fi
}
eq() { [ "$1" = "$2" ]; }

photo() {  # photo <name> <w> <h>: a grey JPEG
  local ppm="$WORK/fixture.ppm"
  printf 'P6\n%s %s\n255\n' "$2" "$3" > "$ppm"
  head -c $(( $2 * $3 * 3 )) /dev/zero | tr '\0' '\200' >> "$ppm"
  sips -s format jpeg "$ppm" --out "$PHOTOS/$1" >/dev/null
}
fresh() { rm -rf "$HOME"; mkdir -p "$PHOTOS"; }
current_files() { find "$CURRENT" -type f 2>/dev/null | wc -l | tr -d ' '; }
current_file() { find "$CURRENT" -type f | head -1; }
size_of() { sips -g pixelWidth -g pixelHeight "$1" | awk '/pixelWidth/{w=$2} /pixelHeight/{h=$2} END{print w "x" h}'; }
format_of() { sips -g format "$1" | awk '/format/{print $2}'; }
pick() { "$BIN" --pick --no-apply "$@"; }

# 1. no photos
fresh
out="$(pick --screens 344x144 2>&1)"; rc=$?
check "no photos: exit 1" eq "$rc" 1
check "no photos: message" eq "$out" "ERROR: No photos to pick from"

# 2. one photo, scaled to cover the screen
fresh; photo a.jpg 800 600
out="$(pick --screens 344x144)"; rc=$?
check "pick: exit 0" eq "$rc" 0
check "pick: message" eq "$out" "Wallpaper: a.jpg (344x258)"
check "pick: one file in Current" eq "$(current_files)" 1
check "pick: size covers the screen" eq "$(size_of "$(current_file)")" "344x258"
check "pick: JPEG" eq "$(format_of "$(current_file)")" "jpeg"

# 3. never upscaled
fresh; photo a.jpg 800 600
out="$(pick --screens 4000x3000)"
check "no upscale: message" eq "$out" "Wallpaper: a.jpg (800x600)"
check "no upscale: size" eq "$(size_of "$(current_file)")" "800x600"

# 4. the largest need over all screens wins (portrait screen needs the height)
fresh; photo a.jpg 800 600
out="$(pick --screens 344x144,200x300)"
check "several screens: covers all" eq "$out" "Wallpaper: a.jpg (400x300)"

# 5. never the photo showing now; one file, new name every time; originals untouched
fresh; photo a.jpg 800 600; photo b.jpg 800 600
sum_before="$(md5 -q "$PHOTOS/a.jpg" "$PHOTOS/b.jpg")"
prev=""; prev_file=""; repeats=0; renamed=1; single=1
for _ in 1 2 3 4 5 6; do
  out="$(pick --screens 344x144)"
  [ "$out" = "$prev" ] && repeats=$((repeats + 1))
  [ "$(current_file)" = "$prev_file" ] && renamed=0
  [ "$(current_files)" = 1 ] || single=0
  prev="$out"; prev_file="$(current_file)"
done
check "two photos: never the same twice in a row" eq "$repeats" 0
check "two photos: new file name every pick" eq "$renamed" 1
check "two photos: always exactly one file" eq "$single" 1
check "originals untouched" eq "$(md5 -q "$PHOTOS/a.jpg" "$PHOTOS/b.jpg")" "$sum_before"

# 6. a single photo stays, but still gets a new file name
fresh; photo a.jpg 800 600
pick --screens 344x144 >/dev/null; first="$(current_file)"
out="$(pick --screens 344x144)"
check "one photo: stays" eq "$out" "Wallpaper: a.jpg (344x258)"
check "one photo: new file name" test "$(current_file)" != "$first"

# 7. usage
"$BIN" >/dev/null 2>&1; rc=$?
check "no arguments: exit 2" eq "$rc" 2
"$BIN" --watch --no-apply >/dev/null 2>&1; rc=$?
check "--watch without --interval: exit 2" eq "$rc" 2

# 8. --watch: picks at start when nothing is current, single instance via pid file
fresh; photo a.jpg 800 600; photo b.jpg 800 600
waitfor() { for _ in $(seq 50); do "$@" && return 0; sleep 0.1; done; return 1; }
one_file() { [ "$(current_files)" = 1 ]; }
pid_is() { [ "$(cat "$STATE/watch.pid" 2>/dev/null)" = "$1" ]; }
"$BIN" --watch --interval 3600 --no-apply --screens 344x144 >/dev/null 2>&1 &
first_pid=$!
check "watch: pid file written" waitfor test -s "$STATE/watch.pid"
check "watch: pid file holds its pid" eq "$(cat "$STATE/watch.pid" 2>/dev/null)" "$first_pid"
check "watch: picks at start" waitfor one_file
"$BIN" --watch --interval 3600 --no-apply --screens 344x144 >/dev/null 2>&1 &
second_pid=$!
check "watch: second start stops the first" waitfor bash -c "! kill -0 $first_pid 2>/dev/null"
check "watch: pid file holds the second" waitfor pid_is "$second_pid"
kill "$second_pid"; wait "$second_pid" 2>/dev/null
check "watch: pid file removed on exit" test ! -e "$STATE/watch.pid"

# 9. --watch: interval picks again
fresh; photo a.jpg 800 600; photo b.jpg 800 600
"$BIN" --watch --interval 1 --no-apply --ignore-lock --screens 344x144 >/dev/null 2>&1 &
pid=$!
waitfor one_file; start_file="$(current_file)"
check "watch: interval changes the photo" waitfor bash -c "[ \"\$(find '$CURRENT' -type f | head -1)\" != '$start_file' ]"
kill "$pid"; wait "$pid" 2>/dev/null

# 10. --rescale: same photo again, sized for the screens now
fresh; photo a.jpg 800 600; photo b.jpg 800 600
first="$(pick --screens 344x144)"
out="$("$BIN" --rescale --no-apply --screens 200x300)"
check "rescale: same photo, new size" eq "$out" "${first% (*} (400x300)"
check "rescale: one file" eq "$(current_files)" 1

# 11. --watch: RAM stays flat over many changes (each change runs in a child process)
fresh; photo a.jpg 3000 2000; photo b.jpg 3000 2000
"$BIN" --watch --interval 0.5 --no-apply --ignore-lock --screens 3000x2000 >/dev/null 2>&1 &
pid=$!
waitfor one_file; sleep 1
rss_start=$(ps -o rss= -p "$pid")
sleep 5
rss_end=$(ps -o rss= -p "$pid")
kill "$pid"; wait "$pid" 2>/dev/null
check "watch: RAM growth under 20 MB over ~10 changes ($(( (rss_end - rss_start) / 1024 )) MB)" test $(( rss_end - rss_start )) -lt 20480

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
