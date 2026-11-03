#!/opt/homebrew/bin/bash
# window-manager/launcher.sh with stubbed yabai-snap.sh and open: connected refresh, VS Code open, fallback.
#   window-manager/tests/launcher.sh
set -uo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)/launcher.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/wm-launcher.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/xdg/yabai"
export PATH="$WORK/bin:$PATH" XDG_CONFIG_HOME="$WORK/xdg" LOG="$WORK/log"

cat > "$WORK/xdg/yabai/yabai-snap.sh" <<'STUB'
#!/bin/sh
echo "snap $*" >> "$LOG"
exit "${SNAP_RC:-0}"
STUB
cat > "$WORK/bin/open" <<'STUB'
#!/bin/sh
echo "open $*" >> "$LOG"
case "$1" in -b) exit "${OPEN_B_RC:-0}" ;; esac
exit 0
STUB
chmod +x "$WORK/xdg/yabai/yabai-snap.sh" "$WORK/bin/open"

fails=0
check() {  # check <name> <condition...>
  local name="$1"; shift
  if "$@"; then echo "PASS  $name"; else echo "FAIL  $name"; fails=$((fails + 1)); fi
}
eq() { [ "$1" = "$2" ]; }
log() { [ -f "$LOG" ] && cat "$LOG" || true; }

rm -f "$LOG"
bash "$SRC"; rc=$?
check "happy path: refresh then open by bundle id" eq "$(log)" $'snap connected\nopen -b com.microsoft.VSCode '"$WORK/xdg/yabai"
check "happy path: exit 0" test "$rc" -eq 0

rm -f "$LOG"
OPEN_B_RC=1 bash "$SRC"
check "bundle id fails: falls back to app name" eq "$(log)" $'snap connected\nopen -b com.microsoft.VSCode '"$WORK/xdg/yabai"$'\nopen -a Visual Studio Code '"$WORK/xdg/yabai"

rm -f "$LOG"
SNAP_RC=1 bash "$SRC"; rc=$?
check "snap failure does not stop opening" eq "$(log)" $'snap connected\nopen -b com.microsoft.VSCode '"$WORK/xdg/yabai"
check "snap failure: exit 0" test "$rc" -eq 0

rm -f "$LOG"; rm "$WORK/xdg/yabai/yabai-snap.sh"
bash "$SRC"
check "missing yabai-snap.sh does not stop opening" eq "$(log)" "open -b com.microsoft.VSCode $WORK/xdg/yabai"

rm -f "$LOG"; mkdir -p "$WORK/home/.config/yabai"
env -u XDG_CONFIG_HOME HOME="$WORK/home" bash "$SRC"
check "no XDG_CONFIG_HOME: defaults to ~/.config/yabai" eq "$(log)" "open -b com.microsoft.VSCode $WORK/home/.config/yabai"

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
