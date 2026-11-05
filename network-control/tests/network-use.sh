#!/opt/homebrew/bin/bash
# NetworkUse decisions, compiled together with the real source.
#   network-control/tests/network-use.sh
set -uo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/network-use.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

cp "$DIR/tests/network-use-tests.swift" "$WORK/main.swift"
swiftc "$DIR/Control/NetworkUse.swift" "$WORK/main.swift" -o "$WORK/run" || { echo "FAIL  compile"; exit 1; }
"$WORK/run"
