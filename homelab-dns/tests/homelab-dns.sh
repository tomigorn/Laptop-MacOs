#!/opt/homebrew/bin/bash
# homelab-dns.sh decisions and homelab-dns-watch.sh event filtering, on temp copies with stubbed system tools.
#   homelab-dns/tests/homelab-dns.sh
set -uo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
DNS_SRC="$DIR/homelab-dns.sh"
WATCH_SRC="$DIR/homelab-dns-watch.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/homelab-dns.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/state"

export PATH="$WORK/bin:$PATH"
export STATE="$WORK/state" CALLS="$WORK/calls.log"

cat > "$WORK/bin/route" <<'STUB'
#!/bin/sh
case "$*" in
  "-n get default") [ -f "$STATE/noroute" ] || printf '   gateway: 192.0.2.1\n interface: en0\n' ;;
  "-n monitor") [ -f "$STATE/events" ] && cat "$STATE/events" ;;
esac
exit 0
STUB
cat > "$WORK/bin/dig" <<'STUB'
#!/bin/sh
echo "dig $*" >> "$CALLS"
n=$(cat "$STATE/digcount" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" > "$STATE/digcount"
sed -n "${n}p" "$STATE/dig" 2>/dev/null
exit 0
STUB
cat > "$WORK/bin/sleep" <<'STUB'
#!/bin/sh
echo "sleep $*" >> "$CALLS"
STUB
cat > "$WORK/bin/networksetup" <<'STUB'
#!/bin/sh
case "$1" in
  -listallnetworkservices) echo "An asterisk (*) denotes that a network service is disabled."; cat "$STATE/services" ;;
  -getdnsservers)
    k=$(echo "$2" | tr / _)
    if [ -f "$STATE/dns/$k" ]; then cat "$STATE/dns/$k"; else echo "There aren't any DNS Servers set on $2."; fi ;;
  -setdnsservers)
    echo "set $2 $3" >> "$CALLS"
    k=$(echo "$2" | tr / _)
    if [ "$3" = empty ]; then rm -f "$STATE/dns/$k"; else mkdir -p "$STATE/dns"; echo "$3" > "$STATE/dns/$k"; fi ;;
esac
exit 0
STUB
cat > "$WORK/bin/date" <<'STUB'
#!/bin/sh
case "$1" in
  +%s) if [ -f "$STATE/clock" ]; then cat "$STATE/clock"; else /bin/date +%s; fi ;;
  *) /bin/date "$@" ;;
esac
STUB
chmod +x "$WORK/bin/"*

sed "s|^LOG=.*|LOG=\"$WORK/homelab-dns.log\"|" "$DNS_SRC" > "$WORK/homelab-dns.sh"
grep -q "^LOG=\"$WORK/homelab-dns.log\"" "$WORK/homelab-dns.sh" || { echo "FAIL  LOG substitution"; exit 1; }
sed "s|^ACTOR=\"[^\"]*\"|ACTOR=\"$WORK/actor.sh\"|" "$WATCH_SRC" > "$WORK/watch.sh"
grep -q "^ACTOR=\"$WORK/actor.sh\"" "$WORK/watch.sh" || { echo "FAIL  ACTOR substitution"; exit 1; }
chmod +x "$WORK/homelab-dns.sh" "$WORK/watch.sh"
LOG="$WORK/homelab-dns.log"

fails=0
check() {  # check <name> <condition...>
  local name="$1"; shift
  if "$@"; then echo "PASS  $name"; else echo "FAIL  $name"; fails=$((fails + 1)); fi
}
contains() { [[ "$1" == *"$2"* ]]; }
eq() { [ "$1" = "$2" ]; }
lacks() { [[ "$1" != *"$2"* ]]; }
logtxt() { [ -f "$LOG" ] && cat "$LOG" || true; }
calls() { [ -f "$CALLS" ] && cat "$CALLS" || true; }

# reset <dig answers...> : fresh state; services come from $SERVICES, preset DNS from $PRESET (name=value)
SERVICES=$'Wi-Fi\nUSB 10/100 LAN\n*Parked Dock'
PRESET=()
reset() {
  rm -rf "$STATE" "$CALLS" "$LOG" "$LOG.1"; mkdir -p "$STATE/dns"
  printf '%s\n' "$SERVICES" > "$STATE/services"
  printf '%s\n' "$@" > "$STATE/dig"
  local p; for p in ${PRESET[@]+"${PRESET[@]}"}; do printf '%s\n' "${p#*=}" > "$STATE/dns/$(echo "${p%%=*}" | tr / _)"; done
}
HOME_ANSWER=198.51.100.53

# 1. reachable: enabled services get the homelab DNS, disabled ones are skipped
PRESET=(); reset "$HOME_ANSWER"
"$WORK/homelab-dns.sh" boot
check "reachable: Wi-Fi set" contains "$(calls)" "set Wi-Fi 192.168.1.2"
check "reachable: second enabled service set" contains "$(calls)" "set USB 10/100 LAN 192.168.1.2"
check "reachable: disabled service untouched" lacks "$(calls)" "Parked Dock"
check "reachable: log line" contains "$(logtxt)" "boot  iface=en0 gw=192.0.2.1  homelab=reachable tries=1  changed=[Wi-Fi]set->192.168.1.2 [USB 10/100 LAN]set->192.168.1.2"
check "reachable: probe is TCP with short timeout" contains "$(calls)" "dig +tcp +time=2 +tries=1 +short @192.168.1.2 probe.homelab"
check "reachable: first try, no sleep" lacks "$(calls)" "sleep"

# 2. already ours: nothing changed, still logged for non-timer reasons
PRESET=("Wi-Fi=192.168.1.2" "USB 10/100 LAN=192.168.1.2"); reset "$HOME_ANSWER"
"$WORK/homelab-dns.sh" change
check "already ours: no set calls" lacks "$(calls)" "set "
check "already ours: logged changed=none" contains "$(logtxt)" "change  iface=en0 gw=192.0.2.1  homelab=reachable tries=1  changed=none"

# 3. unreachable after all tries: ours reverted everywhere (disabled too), foreign DNS left alone
PRESET=("Wi-Fi=192.168.1.2" "USB 10/100 LAN=10.0.0.1" "Parked Dock=192.168.1.2"); reset "" "" ""
"$WORK/homelab-dns.sh" change
check "unreachable: Wi-Fi reverted" contains "$(calls)" "set Wi-Fi empty"
check "unreachable: disabled service defused" contains "$(calls)" "set Parked Dock empty"
check "unreachable: foreign DNS untouched" lacks "$(calls)" "set USB 10/100 LAN"
check "unreachable: 3 probes" test "$(grep -c '^dig ' "$CALLS")" -eq 3
check "unreachable: 2 gaps of 2s" test "$(grep -c '^sleep 2$' "$CALLS")" -eq 2
check "unreachable: log line" contains "$(logtxt)" "change  iface=en0 gw=192.0.2.1  homelab=unreachable tries=3  changed=[Wi-Fi]revert->dhcp [Parked Dock]revert->dhcp"

# 4. flaky probe: success on try 2 counts as reachable
PRESET=(); reset "" "$HOME_ANSWER"
"$WORK/homelab-dns.sh" change
check "flaky: reachable on try 2" contains "$(logtxt)" "homelab=reachable tries=2"
check "flaky: one gap" test "$(grep -c '^sleep 2$' "$CALLS")" -eq 1

# 5. wrong answer (hijacking resolver) is not the homelab
PRESET=(); reset "203.0.113.9" "203.0.113.9" "203.0.113.9"
"$WORK/homelab-dns.sh" change
check "wrong answer: unreachable" contains "$(logtxt)" "homelab=unreachable tries=3  changed=none"

# 6. timer heartbeat is silent unless it changed something
PRESET=("Wi-Fi=192.168.1.2" "USB 10/100 LAN=192.168.1.2"); reset "$HOME_ANSWER"
"$WORK/homelab-dns.sh" timer
check "timer, nothing changed: no log" test -z "$(logtxt)"
PRESET=(); reset "$HOME_ANSWER"
"$WORK/homelab-dns.sh" timer
check "timer, changed: logged" contains "$(logtxt)" "timer  iface=en0"

# 7. default reason, missing route
PRESET=(); reset "$HOME_ANSWER"; touch "$STATE/noroute"
"$WORK/homelab-dns.sh"
check "default reason is manual" contains "$(logtxt)" "manual  iface=none gw=none"

# 8. log rotation at 64 KB
PRESET=(); reset "$HOME_ANSWER"
head -c 70000 /dev/zero | tr '\0' 'x' > "$LOG"
"$WORK/homelab-dns.sh" boot
check "rotation: old log moved to .1" test -s "$LOG.1"
check "rotation: new log is small" test "$(wc -c < "$LOG")" -lt 1000
PRESET=(); reset "$HOME_ANSWER"
head -c 100 /dev/zero | tr '\0' 'x' > "$LOG"
"$WORK/homelab-dns.sh" boot
check "no rotation below limit" test ! -e "$LOG.1"

# watcher: runs the actor at startup, then on route events only, coalescing bursts
cat > "$WORK/actor.sh" <<'STUB'
#!/bin/sh
echo "actor $1" >> "$CALLS"
STUB
chmod +x "$WORK/actor.sh"
rm -rf "$STATE" "$CALLS"; mkdir -p "$STATE"
echo 1000 > "$STATE/clock"
printf '%s\n' "RTM_GET: Report" "RTM_MISS: x" "RTM_LOSING: y" > "$STATE/events"
"$WORK/watch.sh"
check "watch: noise events ignored, only boot run" eq "$(calls)" "actor boot"

rm -f "$CALLS"
printf '%s\n' "RTM_ADD: a" "RTM_DELETE: b" "RTM_IFINFO: c" > "$STATE/events"
"$WORK/watch.sh"
check "watch: burst coalesced into one change run" eq "$(calls)" $'actor boot\nsleep 3\nactor change'

rm -f "$CALLS"
printf '%s\n' "RTM_NEWADDR: a" > "$STATE/events"
"$WORK/watch.sh"
check "watch: RTM_NEWADDR triggers a run" contains "$(calls)" "actor change"
printf '%s\n' "RTM_DELADDR: a" > "$STATE/events"; rm -f "$CALLS"
"$WORK/watch.sh"
check "watch: RTM_DELADDR triggers a run" contains "$(calls)" "actor change"

rm -f "$CALLS" "$WORK/actor.sh"
printf '%s\n' "RTM_ADD: a" > "$STATE/events"
"$WORK/watch.sh"
check "watch: missing actor is skipped (only the settle sleep)" eq "$(calls)" "sleep 3"

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
