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
STUB
chmod +x "$WORK/bin/"* "$APP/remote-binaries.sh"

# local stand-in for github.com/xxh/xxh-shell-fish: pinned commit, then a newer one
UP="$WORK/upstream"
git init -q "$UP"
for f in entrypoint.sh xxh-config.fish build.sh; do echo "$f pinned" > "$UP/$f"; done
git -C "$UP" add -A && git -C "$UP" -c user.name=t -c user.email=t@example.com -c commit.gpgsign=false commit -qm pinned
PIN="$(git -C "$UP" rev-parse HEAD)"
echo newer > "$UP/entrypoint.sh"
git -C "$UP" -c user.name=t -c user.email=t@example.com -c commit.gpgsign=false commit -qam newer
NEWER="$(git -C "$UP" rev-parse HEAD)"
sed -i '' -e "s|^XXH_SHELL_FISH_REPO=.*|XXH_SHELL_FISH_REPO=$UP|" -e "s|^XXH_SHELL_FISH_COMMIT=.*|XXH_SHELL_FISH_COMMIT=$PIN|" "$APP/install.sh"
grep -q "^XXH_SHELL_FISH_COMMIT=$PIN" "$APP/install.sh" || { echo "FAIL  pin substitution"; exit 1; }
grep -q "^XXH_SHELL_FISH_REPO=$UP" "$APP/install.sh" || { echo "FAIL  repo substitution"; exit 1; }
PKG=.xxh/shells/xxh-shell-fish

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
check "default: stores built without refresh" eq "$(log | grep "^remote-binaries")" "remote-binaries "
check "plugin: default home at pinned commit" eq "$(git -C "$HOME/.xxh/$PKG" rev-parse HEAD 2>/dev/null)" "$PIN"
check "plugin: x86_64 home at pinned commit" eq "$(git -C "$HOME/.xxh-homes/x86_64/$PKG" rev-parse HEAD 2>/dev/null)" "$PIN"
check "plugin: aarch64 home at pinned commit" eq "$(git -C "$HOME/.xxh-homes/aarch64/$PKG" rev-parse HEAD 2>/dev/null)" "$PIN"
check "plugin: entrypoint staged from the pin" eq "$(cat "$HOME/.xxh-homes/aarch64/$PKG/build/entrypoint.sh" 2>/dev/null)" "entrypoint.sh pinned"
check "plugin: never via xxh +I (unpinned clone)" lacks "$(log)" "xxh +I"
check "default: arch homes staged" test -d "$HOME/.xxh-homes/aarch64/.xxh/shells/xxh-shell-fish/build/bin"

run --refresh-remote; rc=$?
check "--refresh-remote: exit 0" eq "$rc" 0
check "--refresh-remote: passes --refresh" contains "$(log)" "remote-binaries --refresh"

touch "$HOME/.xxh-homes/x86_64/$PKG/marker"
git -C "$HOME/.xxh-homes/aarch64/$PKG" -c advice.detachedHead=false checkout -q "$NEWER"
run; rc=$?
check "plugin rerun: exit 0" eq "$rc" 0
check "plugin rerun: pinned install kept" test -f "$HOME/.xxh-homes/x86_64/$PKG/marker"
check "plugin rerun: other commit reinstalled at pin" eq "$(git -C "$HOME/.xxh-homes/aarch64/$PKG" rev-parse HEAD)" "$PIN"

run --bogus; rc=$?
check "unknown flag: refused" test "$rc" -ne 0
check "unknown flag: nothing installed" lacks "$(log)" "brew"

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
