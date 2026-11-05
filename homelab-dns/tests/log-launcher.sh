#!/opt/homebrew/bin/bash
# homelab-dns/log-launcher.sh with stubbed open: VS Code by bundle id, fallback by app name.
#   homelab-dns/tests/log-launcher.sh
set -uo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)/log-launcher.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/log-launcher.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
export PATH="$WORK/bin:$PATH" CALLS="$WORK/calls"

cat > "$WORK/bin/open" <<'STUB'
#!/bin/sh
echo "open $*" >> "$CALLS"
case "$1" in -b) exit "${OPEN_B_RC:-0}" ;; esac
exit 0
STUB
chmod +x "$WORK/bin/open"

fails=0
check() {  # check <name> <condition...>
  local name="$1"; shift
  if "$@"; then echo "PASS  $name"; else echo "FAIL  $name"; fails=$((fails + 1)); fi
}
eq() { [ "$1" = "$2" ]; }
calls() { [ -f "$CALLS" ] && cat "$CALLS" || true; }

rm -f "$CALLS"
bash "$SRC"; rc=$?
check "opens the log in VS Code by bundle id" eq "$(calls)" "open -b com.microsoft.VSCode /var/log/homelab-dns.log"
check "exit 0" test "$rc" -eq 0

rm -f "$CALLS"
OPEN_B_RC=1 bash "$SRC"
check "bundle id fails: falls back to app name" eq "$(calls)" $'open -b com.microsoft.VSCode /var/log/homelab-dns.log\nopen -a Visual Studio Code /var/log/homelab-dns.log'

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
