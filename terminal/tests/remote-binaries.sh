#!/opt/homebrew/bin/bash
# terminal/remote-binaries.sh against a stubbed curl serving fixture archives; asserts sha256 pinning and the per-arch stores. Also checks the real pin file.
#   terminal/tests/remote-binaries.sh
set -uo pipefail

TERM_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$TERM_DIR/remote-binaries.sh"
WORK="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/remote-binaries.XXXXXX")" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/fix" "$WORK/home" "$WORK/tmp"
export HOME="$WORK/home" TMPDIR="$WORK/tmp" FIX="$WORK/fix" CURL_LOG="$WORK/curl.log"
export PATH="$WORK/bin:$PATH" REMOTE_BINARIES_CONF="$WORK/pins.conf"

cat > "$WORK/bin/curl" <<'STUB'
#!/bin/sh
out=""; url=""
while [ $# -gt 0 ]; do
  case "$1" in -o) out="$2"; shift ;; -*) ;; *) url="$1" ;; esac
  shift
done
echo "$url" >> "$CURL_LOG"
src="$FIX/$(basename "$url")"
[ -f "$src" ] || exit 22
cp "$src" "$out"
STUB
chmod +x "$WORK/bin/curl"

# fixture <asset> <path in archive> <content> <tar flag>
fixture() {
  local d; d="$(mktemp -d "$WORK/src.XXXXXX")"
  mkdir -p "$d/$(dirname "$2")"; printf '%s\n' "$3" > "$d/$2"
  tar -c"$4"f "$FIX/$1" -C "$d" "$2"
  rm -rf "$d"
}
sha() { shasum -a 256 "$FIX/$1" | cut -d' ' -f1; }
fixture fish-1-linux-x86_64.tar.xz fish "fish v1" J
fixture atuin-x86_64.tar.gz atuin-x86_64/atuin "atuin v1" z
pins() {  # pins <fish sha> <atuin sha>
  printf '# comment\n'
  printf 'fish   fish-shell/fish-shell  1    x86_64  fish-1-linux-x86_64.tar.xz  fish               %s\n' "$1"
  printf 'atuin  atuinsh/atuin          v1   x86_64  atuin-x86_64.tar.gz         atuin-x86_64/atuin %s\n' "$2"
}
STORE="$HOME/.xxh/arch/x86_64"

fails=0
check() {  # check <name> <condition...>
  local name="$1"; shift
  if "$@"; then echo "PASS  $name"; else echo "FAIL  $name"; fails=$((fails + 1)); fi
}
contains() { [[ "$1" == *"$2"* ]]; }
eq() { [ "$1" = "$2" ]; }
clog() { [ -f "$CURL_LOG" ] && cat "$CURL_LOG" || true; }

# matching hashes: installed from the pinned tag
pins "$(sha fish-1-linux-x86_64.tar.xz)" "$(sha atuin-x86_64.tar.gz)" > "$REMOTE_BINARIES_CONF"
"$SCRIPT" > "$WORK/out" 2>&1; rc=$?
check "match: exit 0" eq "$rc" 0; [ "$rc" -eq 0 ] || cat "$WORK/out"
check "match: fish installed" eq "$(cat "$STORE/fish-portable/bin/fish" 2>/dev/null)" "fish v1"
check "match: fish.sh wrapper written" test -x "$STORE/fish-portable/bin/fish.sh"
check "match: atuin installed" eq "$(cat "$STORE/bin/atuin" 2>/dev/null)" "atuin v1"
check "match: atuin executable" test -x "$STORE/bin/atuin"
check "match: pinned tag url" contains "$(clog)" "https://github.com/atuinsh/atuin/releases/download/v1/atuin-x86_64.tar.gz"
check "match: never releases/latest" eq "$(clog | grep -c latest)" 0
check "match: temp files cleaned" test -z "$(ls -A "$TMPDIR")"

# wrong hash: fails closed, nothing extracted, download removed
rm -rf "$HOME/.xxh" "$CURL_LOG"
pins "$(sha fish-1-linux-x86_64.tar.xz)" "$(printf '0%.0s' {1..64})" > "$REMOTE_BINARIES_CONF"
"$SCRIPT" > "$WORK/out" 2>&1; rc=$?
check "mismatch: non-zero exit" test "$rc" -ne 0
check "mismatch: names the asset" contains "$(cat "$WORK/out")" "sha256 mismatch for atuin-x86_64.tar.gz"
check "mismatch: atuin not installed" test ! -e "$STORE/bin/atuin"
check "mismatch: download removed" test -z "$(ls -A "$TMPDIR")"

# malformed pin: refuses without a 64-hex sha256
rm -rf "$HOME/.xxh"
pins "$(sha fish-1-linux-x86_64.tar.xz)" "abc" > "$REMOTE_BINARIES_CONF"
"$SCRIPT" > "$WORK/out" 2>&1; rc=$?
check "bad pin: non-zero exit" test "$rc" -ne 0
check "bad pin: atuin not installed" test ! -e "$STORE/bin/atuin"

check "install.sh: no unpinned releases/latest downloads" eq "$(grep -c "releases/latest" "$TERM_DIR/install.sh")" 0
check "install.sh: stores built by remote-binaries.sh" contains "$(cat "$TERM_DIR/install.sh")" "remote-binaries.sh"

# the real pin file: every tool pinned with a 64-hex sha256 for both arches
real="$TERM_DIR/remote-binaries.conf"
for tool in fish starship atuin bat fastfetch; do
  for arch in x86_64 aarch64; do
    n="$(awk -v t="$tool" -v a="$arch" '!/^[[:space:]]*#/ && $1==t && $4==a && $7 ~ /^[0-9a-f]{64}$/ && NF==7' "$real" | wc -l | tr -d ' ')"
    check "pin file: $tool $arch has one sha256 row" eq "$n" 1
  done
done
check "pin file: one version per tool" eq "$(awk '!/^[[:space:]]*#/ && NF {print $1, $3}' "$real" | sort -u | wc -l | tr -d ' ')" 5

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
