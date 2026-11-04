#!/opt/homebrew/bin/bash
# terminal/install.sh on a temp copy with stubbed brew, pipx, xxh and remote-binaries.sh; asserts flags and the xxh-shell-fish install.
#   terminal/tests/install.sh
set -uo pipefail

TERM_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/term-install.XXXXXX")" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT
APP="$WORK/app"
mkdir -p "$WORK/bin" "$WORK/home" "$APP/.xxh"
cp "$TERM_DIR/install.sh" "$APP/install.sh"
: > "$APP/.xxh/ssh-wrapper.sh"; : > "$APP/.xxh/scp-wrapper.sh"
export HOME="$WORK/home" LOG="$WORK/log"
export PATH="$WORK/bin:/usr/bin:/bin"

cat > "$APP/remote-binaries.sh" <<'STUB'
#!/bin/sh
echo "remote-binaries $*" >> "$LOG"
for a in x86_64 aarch64; do mkdir -p "$HOME/.xxh/arch/$a/bin" "$HOME/.xxh/arch/$a/fish-portable/bin"; done
STUB
cat > "$WORK/bin/brew" <<'STUB'
#!/bin/sh
echo "brew $*" >> "$LOG"
STUB
cat > "$WORK/bin/pipx" <<'STUB'
#!/bin/sh
[ "$1" = list ] && echo "package xxh-xxh"
exit 0
STUB
cat > "$WORK/bin/xxh" <<'STUB'
#!/bin/sh
echo "xxh $*" >> "$LOG"
home="$HOME/.xxh"
while [ $# -gt 0 ]; do [ "$1" = +lh ] && home="$2"; shift; done
mkdir -p "$home/.xxh/shells/xxh-shell-fish/build"
STUB
chmod +x "$WORK/bin/"* "$APP/remote-binaries.sh"

fails=0
check() {  # check <name> <condition...>
  local name="$1"; shift
  if "$@"; then echo "PASS  $name"; else echo "FAIL  $name"; fails=$((fails + 1)); fi
}
contains() { [[ "$1" == *"$2"* ]]; }
lacks() { [[ "$1" != *"$2"* ]]; }
eq() { [ "$1" = "$2" ]; }
log() { [ -f "$LOG" ] && cat "$LOG" || true; }
run() { rm -f "$LOG"; /opt/homebrew/bin/bash "$APP/install.sh" "$@" > "$WORK/out" 2>&1; }

run; rc=$?
check "default: exit 0" eq "$rc" 0; [ "$rc" -eq 0 ] || cat "$WORK/out"
check "default: stores built without refresh" contains "$(log)" $'remote-binaries \n'
check "default: arch homes staged" test -d "$HOME/.xxh-homes/aarch64/.xxh/shells/xxh-shell-fish/build/bin"

run --refresh-remote; rc=$?
check "--refresh-remote: exit 0" eq "$rc" 0
check "--refresh-remote: passes --refresh" contains "$(log)" "remote-binaries --refresh"

run --bogus; rc=$?
check "unknown flag: refused" test "$rc" -ne 0
check "unknown flag: nothing installed" lacks "$(log)" "brew"

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
