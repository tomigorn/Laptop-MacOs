#!/opt/homebrew/bin/bash
# virt-manager/launcher.sh environment setup and argument passthrough, on a copy exec'ing a stub.
#   virt-manager/tests/launcher.sh
set -uo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)/launcher.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/virt-launcher.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
cat > "$WORK/virt-manager" <<'STUB'
#!/bin/sh
echo "PATH=$PATH"
echo "XDG_DATA_DIRS=$XDG_DATA_DIRS"
for a in "$@"; do echo "ARG:$a"; done
STUB
chmod +x "$WORK/virt-manager"
sed "s|/opt/homebrew/bin/virt-manager|$WORK/virt-manager|" "$SRC" > "$WORK/launcher.sh"
chmod +x "$WORK/launcher.sh"
grep -q "exec $WORK/virt-manager" "$WORK/launcher.sh" || { echo "FAIL  exec path substitution"; exit 1; }

fails=0
check() {  # check <name> <condition...>
  local name="$1"; shift
  if "$@"; then echo "PASS  $name"; else echo "FAIL  $name"; fails=$((fails + 1)); fi
}
contains() { [[ "$1" == *"$2"* ]]; }

out="$(env -i PATH=/usr/bin:/bin "$WORK/launcher.sh" --connect "qemu:///session" "two words")"
check "PATH gets Homebrew bin and sbin first" contains "$out" "PATH=/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin"
check "XDG_DATA_DIRS gets Homebrew share" contains "$out" "XDG_DATA_DIRS=/opt/homebrew/share:"
check "args passed through" contains "$out" $'ARG:--connect\nARG:qemu:///session\nARG:two words'

out="$(env -i PATH=/usr/bin:/bin XDG_DATA_DIRS=/usr/share "$WORK/launcher.sh")"
check "existing XDG_DATA_DIRS kept after Homebrew share" contains "$out" "XDG_DATA_DIRS=/opt/homebrew/share:/usr/share"

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
