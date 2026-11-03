#!/opt/homebrew/bin/bash
# xxh ssh-wrapper.sh and scp-wrapper.sh against stubbed ssh/scp; asserts what they pass through.
#   terminal/tests/wrappers.sh
set -uo pipefail

XXH_DIR="$(cd "$(dirname "$0")/../.xxh" && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/wrappers.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/src/dir" "$WORK/home"
export HOME="$WORK/home" SSH_LOG="$WORK/ssh.log" SCP_LOG="$WORK/scp.log" TAR_OUT="$WORK/payload"
export PATH="$WORK/bin:$PATH"

cat > "$WORK/bin/ssh" <<'STUB'
#!/bin/sh
{ echo "CALL"; for a in "$@"; do printf 'ARG:%s\n' "$a"; done; } >> "$SSH_LOG"
case "$*" in
  *"command -v tar"*) [ -n "${STUB_PROBE_OUT:-}" ] && echo "$STUB_PROBE_OUT"; exit "${STUB_PROBE_RC:-0}" ;;
  *"mkdir -p"*) cat > "$TAR_OUT"; exit "${STUB_XFER_RC:-0}" ;;
  "-v "*) echo "debug1: client->server cipher: aes128-ctr MAC: x compression: ${STUB_COMP:-zlib@openssh.com}" >&2; exit 0 ;;
esac
exit 0
STUB
cat > "$WORK/bin/real-scp" <<'STUB'
#!/bin/sh
{ echo "CALL"; for a in "$@"; do printf 'ARG:%s\n' "$a"; done; } >> "$SCP_LOG"
STUB
chmod +x "$WORK/bin/ssh" "$WORK/bin/real-scp"

# scp wrapper copy with REAL_SCP pointed at the stub (never run the real scp)
sed "s|^REAL_SCP=.*|REAL_SCP=$WORK/bin/real-scp|" "$XXH_DIR/scp-wrapper.sh" > "$WORK/scp-wrapper.sh"
chmod +x "$WORK/scp-wrapper.sh"
grep -q "REAL_SCP=$WORK/bin/real-scp" "$WORK/scp-wrapper.sh" || { echo "FAIL  REAL_SCP substitution"; exit 1; }

echo hello > "$WORK/src/file.txt"; echo nested > "$WORK/src/dir/inner.txt"

fails=0
check() {  # check <name> <condition...>
  local name="$1"; shift
  if "$@"; then echo "PASS  $name"; else echo "FAIL  $name"; fails=$((fails + 1)); fi
}
contains() { [[ "$1" == *"$2"* ]]; }
lacks() { [[ "$1" != *"$2"* ]]; }
reset() { rm -f "$SSH_LOG" "$SCP_LOG" "$TAR_OUT"; unset STUB_PROBE_OUT STUB_PROBE_RC STUB_XFER_RC STUB_COMP; }
slog() { [ -f "$SSH_LOG" ] && cat "$SSH_LOG" || true; }
clog() { [ -f "$SCP_LOG" ] && cat "$SCP_LOG" || true; }
plain() { sed $'s/\033\\[[0-9;]*m//g'; }

# ssh-wrapper.sh
reset
"$XXH_DIR/ssh-wrapper.sh" -p 22 host1 true
out="$(slog)"
check "ssh-wrapper: disables multiplexing" contains "$out" $'ARG:-o\nARG:ControlMaster=no\nARG:-o\nARG:ControlPath=none'
check "ssh-wrapper: enables compression" contains "$out" $'ARG:Compression=yes'
check "ssh-wrapper: passes caller args after options" contains "$out" $'ARG:Compression=yes\nARG:-p\nARG:22\nARG:host1\nARG:true'

# scp-wrapper.sh: tar-pipe paths
reset
STUB_PROBE_OUT=gzip "$WORK/scp-wrapper.sh" -r -o ConnectTimeout=5 "$WORK/src/file.txt" "$WORK/src/dir" host2:/remote/dest/ 2> "$WORK/err"
rc=$?
err="$(plain < "$WORK/err")"
check "scp tar-pipe gzip: exit 0" test "$rc" -eq 0
check "scp tar-pipe gzip: reports path" contains "$err" "transfer: tar-pipe + gzip (remote has no zstd)"
check "scp tar-pipe gzip: real scp not used" test -z "$(clog)"
out="$(slog)"
check "scp tar-pipe: -o forwarded to probe and transfer" test "$(grep -c '^ARG:ConnectTimeout=5$' "$SSH_LOG")" -eq 2
check "scp tar-pipe: target host passed" contains "$out" $'ARG:host2'
check "scp tar-pipe: remote mkdir + untar into dest" contains "$out" "mkdir -p '/remote/dest/' && gzip -d -c | tar -xf - -C '/remote/dest/'"
list="$(gzip -dc "$TAR_OUT" | tar -tf - 2>/dev/null | sort | tr '\n' ' ')"
check "scp tar-pipe: payload has file and dir" contains "$list" "file.txt"
check "scp tar-pipe: payload has nested file" contains "$list" "dir/inner.txt"

reset
STUB_PROBE_OUT=zstd "$WORK/scp-wrapper.sh" "$WORK/src/file.txt" host3:/d/ 2> "$WORK/err"
err="$(plain < "$WORK/err")"
if command -v zstd >/dev/null 2>&1; then
  check "scp tar-pipe zstd: reports zstd" contains "$err" "tar-pipe + zstd (fastest)"
  check "scp tar-pipe zstd: remote decompresses with zstd" contains "$(slog)" "zstd -d -c | tar -xf - -C '/d/'"
else
  check "scp tar-pipe zstd: no local zstd -> gzip" contains "$err" "tar-pipe + gzip (no local zstd)"
fi

reset
STUB_PROBE_OUT=gzip "$WORK/scp-wrapper.sh" "$WORK/src/file.txt" "host4:/it's here/" 2> "$WORK/err"
check "scp: single quote in remote path escaped" contains "$(slog)" "mkdir -p '/it'\\''s here/'"

# scp-wrapper.sh: fallbacks to the real scp (original args, original order)
fallback_case() {  # name expected-note args...
  local name="$1" note="$2"; shift 2
  reset
  STUB_PROBE_OUT=gzip "$WORK/scp-wrapper.sh" "$@" 2> "$WORK/err"
  local c e; c="$(clog)"; e="$(plain < "$WORK/err")"
  check "scp fallback ($name): real scp called" contains "$c" "CALL"
  check "scp fallback ($name): original args kept" contains "$c" "$(printf 'ARG:%s\n' "$@")"
  check "scp fallback ($name): note" contains "$e" "$note"
}
fallback_case "no trailing slash" "transfer: scp + SSH compression (wrapper fell back)" "$WORK/src/file.txt" host5:/d/file
fallback_case "unmodelled option" "transfer: scp (wrapper fell back)" -P 2222 "$WORK/src/file.txt" host5:/d/
fallback_case "missing source" "transfer: scp + SSH compression (wrapper fell back)" "$WORK/nope" host5:/d/
fallback_case "local destination" "transfer: scp (wrapper fell back)" "$WORK/src/file.txt" "$WORK/src/dir/"
fallback_case "single operand" "transfer: scp (wrapper fell back)" "$WORK/src/file.txt"
fallback_case "empty remote path" "transfer: scp + SSH compression (wrapper fell back)" "$WORK/src/file.txt" host5:

reset
STUB_COMP=none "$WORK/scp-wrapper.sh" "$WORK/src/file.txt" host6:/d/file 2> "$WORK/err"
check "scp fallback: server refusing compression flagged" contains "$(plain < "$WORK/err")" "scp, UNCOMPRESSED (wrapper fell back; server refuses compression)"

reset
STUB_PROBE_RC=1 "$WORK/scp-wrapper.sh" "$WORK/src/file.txt" host7:/d/ 2> "$WORK/err"
check "scp fallback: remote without tar" contains "$(clog)" "CALL"
reset
STUB_PROBE_OUT=gzip STUB_XFER_RC=1 "$WORK/scp-wrapper.sh" "$WORK/src/file.txt" host8:/d/ 2> "$WORK/err"
check "scp fallback: failed pipeline" contains "$(clog)" "ARG:host8:/d/"
reset
STUB_PROBE_OUT=bogus "$WORK/scp-wrapper.sh" "$WORK/src/file.txt" host9:/d/ 2> "$WORK/err"
check "scp fallback: unknown probe answer" contains "$(clog)" "CALL"

reset
"$WORK/scp-wrapper.sh" -o 2> "$WORK/err"
check "scp fallback: -o without value" contains "$(clog)" "ARG:-o"

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
