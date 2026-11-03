#!/opt/homebrew/bin/bash
# window-manager/make-icon.sh on a temp copy with stubbed swift, sips and iconutil; asserts args and output name.
#   window-manager/tests/make-icon.sh
set -uo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)/make-icon.sh"
WORK="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/make-icon.XXXXXX")" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/app"
cp "$SRC" "$WORK/app/make-icon.sh"
export PATH="$WORK/bin:$PATH" LOG="$WORK/log" TMPDIR="$WORK/tmp"
mkdir -p "$TMPDIR"

cat > "$WORK/bin/swift" <<'STUB'
#!/bin/sh
echo "swift $(basename "$1") $2 $(basename "$3")" >> "$LOG"
: > "$3"
STUB
cat > "$WORK/bin/sips" <<'STUB'
#!/bin/sh
echo "sips $1 $2 $3 $(basename "$4") $(basename "$6")" >> "$LOG"
: > "$6"
STUB
cat > "$WORK/bin/iconutil" <<'STUB'
#!/bin/sh
echo "iconutil $1 $2 $(basename "$3") $4 $(ls "$3" | wc -l | tr -d ' ') files" >> "$LOG"
: > "$5"
STUB
chmod +x "$WORK/bin/"*

fails=0
check() {  # check <name> <condition...>
  local name="$1"; shift
  if "$@"; then echo "PASS  $name"; else echo "FAIL  $name"; fails=$((fails + 1)); fi
}
contains() { [[ "$1" == *"$2"* ]]; }
eq() { [ "$1" = "$2" ]; }
log() { [ -f "$LOG" ] && cat "$LOG" || true; }

rm -f "$LOG"
out="$(bash "$WORK/app/make-icon.sh")"
check "default: output message" eq "$out" "wrote $WORK/app/AppIcon.icns (symbol: rectangle.split.3x1)"
check "default: icns written next to script" test -f "$WORK/app/AppIcon.icns"
check "default: swift gets default symbol" contains "$(log)" "swift mkicon.swift rectangle.split.3x1 icon.png"
check "iconset has 10 sizes" contains "$(log)" "iconutil -c icns AppIcon.iconset -o 10 files"
check "sips resizes to 16 first, 1024 last" eq "$(grep '^sips' "$LOG" | sed -n '1p;$p')" $'sips -z 16 16 icon.png icon_16x16.png\nsips -z 1024 1024 icon.png icon_512x512'"@"'2x.png'

rm -f "$LOG"
out="$(bash "$WORK/app/make-icon.sh" arrow.clockwise RestartIcon)"
check "custom: output message" eq "$out" "wrote $WORK/app/RestartIcon.icns (symbol: arrow.clockwise)"
check "custom: swift gets symbol" contains "$(log)" "swift mkicon.swift arrow.clockwise icon.png"
check "custom: icns named by 2nd arg" test -f "$WORK/app/RestartIcon.icns"
check "temp dir cleaned up" test -z "$(ls "$TMPDIR")"

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
