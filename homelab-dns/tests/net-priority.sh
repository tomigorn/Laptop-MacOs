#!/opt/homebrew/bin/bash
# net-priority.sh decisions on a temp copy with stubbed system tools.
#   homelab-dns/tests/net-priority.sh
set -uo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$DIR/net-priority.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/net-priority.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/state"

export PATH="$WORK/bin:$PATH"
export STATE="$WORK/state" CALLS="$WORK/calls.log"

cat > "$WORK/bin/networksetup" <<'STUB'
#!/bin/sh
case "$1" in
  -listnetworkserviceorder) cat "$STATE/order" ;;
  -ordernetworkservices) shift; printf 'order'  >> "$CALLS"; printf ' <%s>' "$@" >> "$CALLS"; echo >> "$CALLS" ;;
esac
STUB
cat > "$WORK/bin/ipconfig" <<'STUB'
#!/bin/sh
case "$1" in
  getifaddr) [ -f "$STATE/ip.$2" ] && cat "$STATE/ip.$2" || exit 1 ;;
  getoption) [ -f "$STATE/dns.$2" ] && cat "$STATE/dns.$2" || exit 1 ;;
esac
STUB
cat > "$WORK/bin/dig" <<'STUB'
#!/bin/sh
echo "dig $*" >> "$CALLS"
[ -f "$STATE/nodig" ] || echo 192.0.2.80
STUB
cat > "$WORK/bin/curl" <<'STUB'
#!/bin/sh
echo "curl $*" >> "$CALLS"
dev=""; url=""
while [ $# -gt 0 ]; do
  case "$1" in
    --interface) dev=$2; shift ;;
    http://*) url=$1 ;;
  esac
  shift
done
host=${url#http://}; host=${host%%/*}
if [ -f "$STATE/online.$dev.$host" ] || [ -f "$STATE/online.$dev" ]; then
  echo "NetworkManager is online"
elif [ -f "$STATE/portal.$dev" ]; then
  echo "<html>ETH login</html>"
else
  exit 7
fi
STUB
cat > "$WORK/bin/sleep" <<'STUB'
#!/bin/sh
echo "sleep $*" >> "$CALLS"
STUB
chmod +x "$WORK/bin/"*

sed -e "s|^LOG=.*|LOG=\"$WORK/net.log\"|" -e "s|^STOP_FLAG=.*|STOP_FLAG=\"$WORK/stopped\"|" "$SRC" > "$WORK/net-priority.sh"
grep -q "^LOG=\"$WORK/net.log\"" "$WORK/net-priority.sh" || { echo "FAIL  LOG substitution"; exit 1; }
grep -q "^STOP_FLAG=\"$WORK/stopped\"" "$WORK/net-priority.sh" || { echo "FAIL  STOP_FLAG substitution"; exit 1; }
chmod +x "$WORK/net-priority.sh"
LOG="$WORK/net.log"

fails=0
check() {  # check <name> <condition...>
  local name="$1"; shift
  if "$@"; then echo "PASS  $name"; else echo "FAIL  $name"; fails=$((fails + 1)); fi
}
contains() { [[ "$1" == *"$2"* ]]; }
lacks() { [[ "$1" != *"$2"* ]]; }
calls() { [ -f "$CALLS" ] && cat "$CALLS" || true; }
logtxt() { [ -f "$LOG" ] && cat "$LOG" || true; }

ETH_FIRST='An asterisk (*) denotes that a network service is disabled.
(1) USB LAN
(Hardware Port: USB 10/100/1000 LAN, Device: en5)

(2) Thunderbolt Bridge
(Hardware Port: Thunderbolt Bridge, Device: bridge0)

(3) Wi-Fi
(Hardware Port: Wi-Fi, Device: en0)

(4) fastpi
(Hardware Port: com.wireguard.macos, Device: )
'
WIFI_FIRST='An asterisk (*) denotes that a network service is disabled.
(1) Thunderbolt Bridge
(Hardware Port: Thunderbolt Bridge, Device: bridge0)

(2) Wi-Fi
(Hardware Port: Wi-Fi, Device: en0)

(3) USB LAN
(Hardware Port: USB 10/100/1000 LAN, Device: en5)

(4) fastpi
(Hardware Port: com.wireguard.macos, Device: )
'
TWO_DOCKS='An asterisk (*) denotes that a network service is disabled.
(*) Parked Dock
(Hardware Port: USB 10/100/1000 LAN, Device: en7)

(1) USB LAN
(Hardware Port: USB 10/100/1000 LAN, Device: en5)

(2) Wi-Fi
(Hardware Port: Wi-Fi, Device: en0)
'

reset() {  # reset <order text>
  rm -rf "$STATE" "$CALLS" "$LOG"; rm -f "$WORK/stopped"; mkdir -p "$STATE"
  printf '%s' "$1" > "$STATE/order"
  echo 10.0.0.5 > "$STATE/ip.en5"; echo 10.0.0.1 > "$STATE/dns.en5"
  echo 10.0.1.5 > "$STATE/ip.en0"; echo 10.0.1.1 > "$STATE/dns.en0"
}
run() { "$WORK/net-priority.sh" change; }

BELOW='order <Thunderbolt Bridge> <Wi-Fi> <USB LAN> <fastpi>'
ABOVE='order <USB LAN> <Thunderbolt Bridge> <Wi-Fi> <fastpi>'

# 1. Ethernet behind a login page, Wi-Fi works: Ethernet moves directly below Wi-Fi
reset "$ETH_FIRST"; touch "$STATE/portal.en5" "$STATE/online.en0"; run
check "portal + wifi ok: Ethernet below Wi-Fi" contains "$(calls)" "$BELOW"
check "portal + wifi ok: logged" contains "$(logtxt)" "change  priority  [USB LAN]=fail wifi=ok  changed=[USB LAN]below-wifi"

# 2. Ethernet blocked outright, Wi-Fi works: same
reset "$ETH_FIRST"; touch "$STATE/online.en0"; run
check "blocked + wifi ok: Ethernet below Wi-Fi" contains "$(calls)" "$BELOW"

# 3. already below Wi-Fi and still failing: no reorder
reset "$WIFI_FIRST"; touch "$STATE/portal.en5" "$STATE/online.en0"; run
check "already below: no reorder" lacks "$(calls)" "order"
check "already below: logged changed=none" contains "$(logtxt)" "changed=none"

# 4. both fail: nothing moves, a login page on Ethernet stays usable
reset "$ETH_FIRST"; touch "$STATE/portal.en5" "$STATE/portal.en0"; run
check "both fail: no reorder" lacks "$(calls)" "order"
check "both fail: logged" contains "$(logtxt)" "[USB LAN]=fail wifi=fail  changed=none"

# 5. Ethernet works and is below Wi-Fi: moves directly above Wi-Fi
reset "$WIFI_FIRST"; touch "$STATE/online.en5"; run
check "eth ok below wifi: moved above" contains "$(calls)" "order <Thunderbolt Bridge> <USB LAN> <Wi-Fi> <fastpi>"
check "eth ok below wifi: logged" contains "$(logtxt)" "[USB LAN]=ok wifi=unchecked  changed=[USB LAN]above-wifi"

# 6. Ethernet works and is above Wi-Fi: no reorder, Wi-Fi not probed
reset "$ETH_FIRST"; touch "$STATE/online.en5"; run
check "eth ok above wifi: no reorder" lacks "$(calls)" "order"
check "eth ok above wifi: Wi-Fi not probed" lacks "$(calls)" "--interface en0"

# 7. Ethernet has no address (unplugged): silent, nothing probed or moved
reset "$ETH_FIRST"; rm -f "$STATE/ip.en5"; run
check "no ethernet: no probes" lacks "$(calls)" "curl"
check "no ethernet: no reorder" lacks "$(calls)" "order"
check "no ethernet: no log" test -z "$(logtxt)"

# 8. backup sites: a connection works if any one of the three answers
reset "$ETH_FIRST"; touch "$STATE/online.en5.ping.archlinux.org"; run
check "first site down, second answers: works" lacks "$(calls)" "order"
reset "$ETH_FIRST"; touch "$STATE/online.en5.network-test.debian.org"; run
check "two sites down, third answers: works" lacks "$(calls)" "order"
check "sites tried in order: GNOME first" contains "$(calls | grep -m1 curl)" "nmcheck.gnome.org"

# 9. all sites fail: two rounds with one gap before believing it
reset "$ETH_FIRST"; touch "$STATE/portal.en5" "$STATE/online.en0"; run
check "failing connection: 6 attempts" test "$(grep -c -- '--interface en5' "$CALLS")" -eq 6
check "failing connection: one 2s gap" test "$(grep -c '^sleep 2$' "$CALLS")" -eq 1

# 10. each connection resolves names through its own DNS server, from its own address
reset "$ETH_FIRST"; touch "$STATE/portal.en5" "$STATE/online.en0"; run
check "own DNS: Ethernet" contains "$(calls)" "-b 10.0.0.5 @10.0.0.1 nmcheck.gnome.org"
check "own DNS: Wi-Fi" contains "$(calls)" "-b 10.0.1.5 @10.0.1.1 nmcheck.gnome.org"
check "own DNS: resolved address used" contains "$(calls)" "--resolve nmcheck.gnome.org:80:192.0.2.80"

# 11. a connection whose DNS answers nothing is not working
reset "$ETH_FIRST"; touch "$STATE/online.en5" "$STATE/nodig"; run
check "dead DNS: no web request" lacks "$(calls)" "curl"
check "dead DNS: logged as fail" contains "$(logtxt)" "[USB LAN]=fail"

# 12. no DNS server known for the connection: falls back to the system resolver
reset "$ETH_FIRST"; rm -f "$STATE/dns.en5"; touch "$STATE/online.en5"; run
check "no DHCP DNS: still probes" contains "$(calls)" "--interface en5"
check "no DHCP DNS: no reorder" lacks "$(calls)" "order"

# 13. disabled services are never probed, but keep their place in the order
reset "$TWO_DOCKS"; echo 10.0.0.9 > "$STATE/ip.en7"; touch "$STATE/portal.en5" "$STATE/online.en0"; run
check "disabled: not probed" lacks "$(calls)" "--interface en7"
check "disabled: stays in the order" contains "$(calls)" "order <Parked Dock> <Wi-Fi> <USB LAN>"

# 14. only Ethernet-like services count: the bridge is ignored even with an address
reset "$ETH_FIRST"; echo 169.254.0.1 > "$STATE/ip.bridge0"; touch "$STATE/online.en5"; run
check "bridge: not probed" lacks "$(calls)" "--interface bridge0"

# 15. Stop itself: no probes, Ethernet back directly above Wi-Fi, logged
reset "$WIFI_FIRST"; touch "$WORK/stopped"; "$WORK/net-priority.sh" control
check "stop: moved above Wi-Fi" contains "$(calls)" "order <Thunderbolt Bridge> <USB LAN> <Wi-Fi> <fastpi>"
check "stop: no probes" lacks "$(calls)" "curl"
check "stop: logged" contains "$(logtxt)" "control  priority  stopped  changed=[USB LAN]above-wifi"

# 16. Stop with Ethernet already above: no reorder, still logged
reset "$ETH_FIRST"; touch "$WORK/stopped"; "$WORK/net-priority.sh" control
check "stop, already above: no reorder" lacks "$(calls)" "order"
check "stop, already above: logged" contains "$(logtxt)" "control  priority  stopped  changed=none"

# 17. Stop reverts unplugged and disabled adapters too; bridge and VPN stay
PARKED_BELOW='An asterisk (*) denotes that a network service is disabled.
(1) Wi-Fi
(Hardware Port: Wi-Fi, Device: en0)

(*) Parked Dock
(Hardware Port: USB 10/100/1000 LAN, Device: en7)

(2) USB LAN
(Hardware Port: USB 10/100/1000 LAN, Device: en5)

(3) Thunderbolt Bridge
(Hardware Port: Thunderbolt Bridge, Device: bridge0)

(4) fastpi
(Hardware Port: com.wireguard.macos, Device: )
'
reset "$PARKED_BELOW"; rm -f "$STATE/ip.en5"; touch "$WORK/stopped"; "$WORK/net-priority.sh" control
check "stop: all en adapters above, bridge and VPN stay" contains "$(calls)" "order <Parked Dock> <USB LAN> <Wi-Fi> <Thunderbolt Bridge> <fastpi>"

# 18. stopped, any other run: hands off
for why in boot change manual; do
  reset "$WIFI_FIRST"; touch "$WORK/stopped"; touch "$STATE/online.en5"; "$WORK/net-priority.sh" "$why"
  check "stopped, $why: touches nothing" test -z "$(calls)"
  check "stopped, $why: no log" test -z "$(logtxt)"
done

# 19. Stop landing during the probes: the running job does not write the order
reset "$WIFI_FIRST"; touch "$STATE/online.en5"
cat > "$WORK/bin/curl" <<'STUB'
#!/bin/sh
echo "curl $*" >> "$CALLS"
touch "$STOPPED_AT"
echo "NetworkManager is online"
STUB
STOPPED_AT="$WORK/stopped" "$WORK/net-priority.sh" change
check "stop during probes: order not written" lacks "$(calls)" "order"

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
