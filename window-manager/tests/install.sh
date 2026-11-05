#!/opt/homebrew/bin/bash
# window-manager/install.sh on a temp copy with stubbed brew and build-launcher.sh; asserts the yabai/skhd tap.
#   window-manager/tests/install.sh
set -uo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/wm-install.XXXXXX")" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/app/config" "$WORK/home"
cp "$DIR/install.sh" "$WORK/app/install.sh"
for f in yabairc yabai-snap.sh keys.conf README.md zones.conf; do : > "$WORK/app/config/$f"; done
printf '#!/bin/sh\n' > "$WORK/app/build-launcher.sh"
cat > "$WORK/bin/brew" <<'STUB'
#!/bin/sh
echo "brew $*" >> "$LOG"
[ "$1" != list ] || exit 1
STUB
chmod +x "$WORK/bin/brew" "$WORK/app/build-launcher.sh"
export HOME="$WORK/home" XDG_CONFIG_HOME="$WORK/home/.config" LOG="$WORK/log"
export PATH="$WORK/bin:/usr/bin:/bin"

fails=0
check() {  # check <name> <condition...>
  local name="$1"; shift
  if "$@"; then echo "PASS  $name"; else echo "FAIL  $name"; fails=$((fails + 1)); fi
}
eq() { [ "$1" = "$2" ]; }
contains() { [[ "$1" == *"$2"* ]]; }
log() { [ -f "$LOG" ] && cat "$LOG" || true; }

/opt/homebrew/bin/bash "$WORK/app/install.sh" --skip-services > "$WORK/out" 2>&1
check "install.sh exits 0" eq 0 $?
check "yabai from asmvik/formulae" contains "$(log)" "brew install asmvik/formulae/yabai"
check "skhd from asmvik/formulae" contains "$(log)" "brew install asmvik/formulae/skhd"
check "displayplacer from core" contains "$(log)" "brew install displayplacer"
check "Homebrew's jq, even though macOS ships one" contains "$(log)" "brew install jq"
check "prints the bound shortcuts" contains "$(cat "$WORK/out")" "⌥⌘ ←/→"
check "prints no old shortcuts" test -z "$(grep '⌃⌥' "$WORK/out")"
check "launcher apps keep their quarantine flag" test -z "$(grep quarantine "$DIR/build-launcher.sh")"

old="koekei""shiya"
check "window-manager never names the old tap owner" test -z "$(grep -rl "$old" "$DIR" 2>/dev/null)"

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
