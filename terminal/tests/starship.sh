#!/opt/homebrew/bin/bash
# starship.toml: the local label shows on the Mac, hides over ssh, and does not depend on a fast fish start.
#   terminal/tests/starship.sh
set -uo pipefail

command -v starship >/dev/null 2>&1 || { echo "skip: starship not installed"; exit 0; }
export STARSHIP_CONFIG="$(cd "$(dirname "$0")/.." && pwd)/.config/starship.toml"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/starship.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"

fail=0
check() {  # check <name> <expected 0|1 label present> <output>
  if printf '%s' "$3" | grep -q 'local MacOS'; then got=1; else got=0; fi
  if [ "$got" = "$2" ]; then echo "ok    $1"; else echo "FAIL  $1"; printf '      %s\n' "$3"; fail=1; fi
}

check "label on the Mac" 1 "$(env -u SSH_CONNECTION STARSHIP_SHELL=fish starship module custom.local 2>&1)"
check "no label over ssh" 0 "$(SSH_CONNECTION='1 2 3 4' STARSHIP_SHELL=fish starship module custom.local 2>&1)"

# a busy Mac: fish takes 1 s to start, longer than starship's command timeout
printf '#!/bin/sh\nsleep 1\nexec %s "$@"\n' "$(command -v fish)" > "$WORK/bin/fish"
chmod +x "$WORK/bin/fish"
check "label with a slow fish" 1 "$(env -u SSH_CONNECTION PATH="$WORK/bin:$PATH" STARSHIP_SHELL=fish starship module custom.local 2>&1)"

exit "$fail"
