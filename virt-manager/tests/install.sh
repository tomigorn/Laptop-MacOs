#!/opt/homebrew/bin/bash
# virt-manager/install.sh ends with its version, on a copy with brew, virsh and build.sh stubbed.
#   virt-manager/tests/install.sh
set -uo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/virt-install.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/vm" "$WORK/home"
cat > "$WORK/bin/brew" <<'STUB'
#!/bin/sh
case "$1" in
  --prefix) echo /opt/homebrew ;;
  list) echo "$3 1.0" ;;
  services) echo "libvirt started" ;;
esac
exit 0
STUB
printf '#!/bin/sh\nexit 0\n' > "$WORK/bin/virsh"
printf '#!/bin/sh\nexit 0\n' > "$WORK/vm/build.sh"
chmod +x "$WORK/bin/"* "$WORK/vm/build.sh"
sed "s|/opt/homebrew/bin/virsh|$WORK/bin/virsh|" "$DIR/install.sh" > "$WORK/vm/install.sh"
chmod +x "$WORK/vm/install.sh"
grep -q "$WORK/bin/virsh" "$WORK/vm/install.sh" || { echo "FAIL  virsh path substitution"; exit 1; }

fails=0
check() {  # check <name> <condition...>
  local name="$1"; shift
  if "$@"; then echo "PASS  $name"; else echo "FAIL  $name"; fails=$((fails + 1)); fi
}
run() { HOME="$WORK/home" PATH="$WORK/bin:$PATH" "$WORK/vm/install.sh" 2>&1 | tail -n 1; }

v="$(cat "$DIR/VERSION" 2>/dev/null)"
check "repo VERSION is X.Y.Z" eval '[[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]'
cp "$DIR/VERSION" "$WORK/vm/VERSION" 2>/dev/null
check "last line: version" [ "$(run)" = "virt-manager setup $v" ]
rm -f "$WORK/vm/VERSION"
check "no VERSION: ?" [ "$(run)" = "virt-manager setup ?" ]

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
