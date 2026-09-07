#!/usr/bin/env fish
# Live test: two overlapping xxhc sessions to one host must not break each other.
#
#   terminal/tests/concurrent-sessions.fish root6
#
# Needs a reachable host and takes ~90 s. Session A runs long; session B starts
# while A is up and finishes first, so A's later commands run both after B has
# connected and after B has torn down — the two moments that used to destroy A.

set -g fails 0

function check -a label ok
    if test "$ok" = ok
        echo "  PASS  $label"
    else
        echo "  FAIL  $label"
        set -g fails (math $fails + 1)
    end
end

set -l host $argv[1]
if test -z "$host"
    echo "usage: concurrent-sessions.fish <ssh-host>"
    exit 2
end

set -l tmp (mktemp -d)

echo "== two overlapping sessions against $host =="

fish -c "xxhc $host +hc 'echo A_EARLY; atuin history list | tail -1; sleep 45; echo A_LATE; atuin history list | tail -1; echo A_END'" >$tmp/A.log 2>&1 &
set -l apid $last_pid
sleep 25
fish -c "xxhc $host +hc 'echo B_ONLY; atuin history list | tail -1; echo B_END'" >$tmp/B.log 2>&1
wait $apid

echo "== assertions =="

# A must still have a working environment after B connected and after B exited.
if grep -q 'command not found' $tmp/A.log
    check "A keeps its binaries while B runs" broken
else
    check "A keeps its binaries while B runs" ok
end

grep -q A_LATE $tmp/A.log; and check "A reaches its late command" ok; or check "A reaches its late command" broken
grep -q A_END $tmp/A.log; and check "A exits cleanly" ok; or check "A exits cleanly" broken
grep -q B_END $tmp/B.log; and check "B exits cleanly" ok; or check "B exits cleanly" broken

# Neither session may lose its history.
grep -q "History from $host merged" $tmp/A.log; and check "A's history merged" ok; or check "A's history merged" broken
grep -q "History from $host merged" $tmp/B.log; and check "B's history merged" ok; or check "B's history merged" broken

# No trace left on the remote.
set -l leftover (ssh -o BatchMode=yes $host 'ls -d ~/.xxh ~/.xxh-* 2>/dev/null | tr "\n" " "')
if test -z "$leftover"
    check "no remote homes left behind" ok
else
    check "no remote homes left behind (found: $leftover)" broken
end

echo "== sweeper: a home whose owner is dead must be removed on the next connect =="
ssh -o BatchMode=yes $host 'mkdir -p ~/.xxh-99999999-1 && echo 99999999 > ~/.xxh-99999999-1/.owner-pid' >/dev/null 2>&1
fish -c "xxhc $host +hc 'echo SWEEP_RUN'" >$tmp/C.log 2>&1
set -l swept (ssh -o BatchMode=yes $host 'ls -d ~/.xxh-99999999-1 2>/dev/null')
if test -z "$swept"
    check "stale home swept" ok
else
    check "stale home swept" broken
    ssh -o BatchMode=yes $host 'rm -rf ~/.xxh-99999999-1' >/dev/null 2>&1
end

echo
if test $fails -eq 0
    echo "ALL PASS  (logs in $tmp)"
    exit 0
else
    echo "$fails FAILED  (logs in $tmp)"
    exit 1
end
