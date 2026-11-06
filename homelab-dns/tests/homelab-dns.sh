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
  -listallnetworkservices) [ -z "${STOP_ON_LIST:-}" ] || touch "$STOP_ON_LIST"; echo "An asterisk (*) denotes that a network service is disabled."; cat "$STATE/services" ;;
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
cat > "$WORK/bin/netstat" <<'STUB'
#!/bin/sh
n=$(cat "$STATE/netstatcount" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" > "$STATE/netstatcount"
[ -f "$STATE/stable" ] && n=0
printf 'default            192.0.2.%s         UGScg                 en0\n' "$n"
STUB
cat > "$WORK/bin/ifconfig" <<'STUB'
#!/bin/sh
printf 'en0: flags=8863\n\tinet 192.0.2.50 netmask 0xffffff00\n'
STUB
chmod +x "$WORK/bin/"*

sed -e "s|^LOG=.*|LOG=\"$WORK/homelab-dns.log\"|" -e "s|^STOP_FLAG=.*|STOP_FLAG=\"$WORK/stopped\"|" "$DNS_SRC" > "$WORK/homelab-dns.sh"
grep -q "^LOG=\"$WORK/homelab-dns.log\"" "$WORK/homelab-dns.sh" || { echo "FAIL  LOG substitution"; exit 1; }
grep -q "^STOP_FLAG=\"$WORK/stopped\"" "$WORK/homelab-dns.sh" || { echo "FAIL  STOP_FLAG substitution"; exit 1; }
sed -e "s|^ACTOR=\"[^\"]*\"|ACTOR=\"$WORK/actor.sh\"|" -e "s|^PRIORITY=\"[^\"]*\"|PRIORITY=\"$WORK/priority.sh\"|" "$WATCH_SRC" > "$WORK/watch.sh"
grep -q "^ACTOR=\"$WORK/actor.sh\"" "$WORK/watch.sh" || { echo "FAIL  ACTOR substitution"; exit 1; }
grep -q "^PRIORITY=\"$WORK/priority.sh\"" "$WORK/watch.sh" || { echo "FAIL  PRIORITY substitution"; exit 1; }
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
  rm -rf "$STATE" "$CALLS" "$LOG" "$LOG.1"; rm -f "$WORK/stopped"; mkdir -p "$STATE/dns"
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

# 9. stopped, run by Stop itself: no probe, ours reverted (disabled too), foreign left alone, logged
PRESET=("Wi-Fi=192.168.1.2" "USB 10/100 LAN=10.0.0.1" "Parked Dock=192.168.1.2"); reset "$HOME_ANSWER"; touch "$WORK/stopped"
"$WORK/homelab-dns.sh" control
check "stop: no probe" lacks "$(calls)" "dig "
check "stop: Wi-Fi reverted" contains "$(calls)" "set Wi-Fi empty"
check "stop: disabled service reverted" contains "$(calls)" "set Parked Dock empty"
check "stop: foreign DNS untouched" lacks "$(calls)" "set USB 10/100 LAN"
check "stop: log line" contains "$(logtxt)" "control  iface=en0 gw=192.0.2.1  homelab=stopped tries=0  changed=[Wi-Fi]revert->dhcp [Parked Dock]revert->dhcp"

# 10. stopped, any other run: hands off
for why in boot change timer manual; do
  PRESET=("Wi-Fi=192.168.1.2"); reset "$HOME_ANSWER"; touch "$WORK/stopped"
  "$WORK/homelab-dns.sh" "$why"
  check "stopped, $why: touches nothing" eq "$(calls)" ""
  check "stopped, $why: no log" test -z "$(logtxt)"
done

# 12. Start: no flag and reason control is a normal, logged evaluation
PRESET=(); reset "$HOME_ANSWER"
"$WORK/homelab-dns.sh" control
check "start: DNS set" contains "$(calls)" "set Wi-Fi 192.168.1.2"
check "start: logged" contains "$(logtxt)" "control  iface=en0 gw=192.0.2.1  homelab=reachable tries=1"

# 11. Stop landing during a probe: the running job does not write, does not revert, does not log
PRESET=("Wi-Fi=192.168.1.2"); reset "$HOME_ANSWER"
cat > "$WORK/bin/dig" <<'STUB'
#!/bin/sh
echo "dig $*" >> "$CALLS"
[ -z "${STOPPED_AT:-}" ] || touch "$STOPPED_AT"
echo 198.51.100.53
STUB
STOPPED_AT="$WORK/stopped" "$WORK/homelab-dns.sh" timer
check "stop during probe: no DNS written" lacks "$(calls)" "set "
check "stop during probe: no log" test -z "$(logtxt)"

# 13. Stop landing during the probe of a control run: reverted, never set, logged as stopped
PRESET=("Wi-Fi=192.168.1.2"); reset "$HOME_ANSWER"
STOPPED_AT="$WORK/stopped" "$WORK/homelab-dns.sh" control
check "control, stop during probe: reverted" contains "$(calls)" "set Wi-Fi empty"
check "control, stop during probe: never set" lacks "$(calls)" "set Wi-Fi 192.168.1.2"
check "control, stop during probe: logged stopped" contains "$(logtxt)" "homelab=stopped"

# 14. Stop landing while the services are listed: nothing is written
PRESET=(); reset "$HOME_ANSWER"
STOP_ON_LIST="$WORK/stopped" "$WORK/homelab-dns.sh" timer
check "stop during service list: no DNS written" lacks "$(calls)" "set "

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

# route event without a real change (same default routes and addresses): nothing runs
rm -f "$CALLS"; touch "$STATE/stable"
printf '%s\n' "RTM_IFINFO: a" > "$STATE/events"
"$WORK/watch.sh"
check "watch: event without a network change runs nothing" eq "$(calls)" $'actor boot\nsleep 3'
rm -f "$STATE/stable"

# the priority check runs before the DNS actor, at startup and on a real change
cat > "$WORK/priority.sh" <<'STUB'
#!/bin/sh
echo "priority $1" >> "$CALLS"
STUB
chmod +x "$WORK/priority.sh"
rm -f "$CALLS"
printf '%s\n' "RTM_ADD: a" > "$STATE/events"
"$WORK/watch.sh"
check "watch: priority check before actor" eq "$(calls)" $'priority boot\nactor boot\nsleep 3\npriority change\nactor change'
rm -f "$WORK/priority.sh"

rm -f "$CALLS" "$WORK/actor.sh"
printf '%s\n' "RTM_ADD: a" > "$STATE/events"
"$WORK/watch.sh"
check "watch: missing actor is skipped (only the settle sleep)" eq "$(calls)" "sleep 3"

# control script: priority first, then the actor, both with reason control
cat > "$WORK/actor.sh" <<'STUB'
#!/bin/sh
echo "actor $1" >> "$CALLS"
STUB
cat > "$WORK/priority.sh" <<'STUB'
#!/bin/sh
echo "priority $1" >> "$CALLS"
STUB
chmod +x "$WORK/actor.sh" "$WORK/priority.sh"
sed -e "s|^ACTOR=\"[^\"]*\"|ACTOR=\"$WORK/actor.sh\"|" -e "s|^PRIORITY=\"[^\"]*\"|PRIORITY=\"$WORK/priority.sh\"|" "$DIR/homelab-dns-control.sh" > "$WORK/control.sh"
chmod +x "$WORK/control.sh"
rm -f "$CALLS"
"$WORK/control.sh"
check "control: priority then actor" eq "$(calls)" $'priority control\nactor control'

# the control daemon watches the folder of the flag the scripts obey
flag="$(sed -n 's/^STOP_FLAG="\(.*\)"$/\1/p' "$DNS_SRC")"
check "scripts agree on the flag" eq "$flag" "$(sed -n 's/^STOP_FLAG="\(.*\)"$/\1/p' "$DIR/net-priority.sh")"
check "daemon watches the flag folder" eq "$(plutil -extract WatchPaths.0 raw "$DIR/com.tomigorn.homelab-dns-control.plist")" "$(dirname "$flag")"
check "daemon runs the control script" eq "$(plutil -extract ProgramArguments.0 raw "$DIR/com.tomigorn.homelab-dns-control.plist")" "/usr/local/sbin/homelab-dns-control.sh"

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
