#!/bin/sh
# dock-net-diag.sh — capture wired-dock networking state while the internet is down.
#
# WHY: when the USB-C dock ethernet (en6) becomes the primary network service,
# the Mac (and therefore Claude Code, which needs the internet) goes offline, so
# the broken state cannot be observed live. This script dumps everything to a
# file. Run it WHILE the dock is active and internet is broken, then switch back
# to Wi-Fi and have Claude read the output file.
#
# USAGE (fish or any shell):
#     sh dock-net-diag.sh
# It prints the output path at the end. No sudo required.

IFACE="${1:-en6}"                       # dock ethernet interface (override: sh dock-net-diag.sh en7)
OUT="$HOME/dock-net-diag-$(date +%Y%m%d-%H%M%S).txt"
exec 3>&1 4>&2                          # keep the real terminal on fd 3/4
exec > "$OUT" 2>&1                      # everything below goes to the file

echo "###### dock-net-diag ($IFACE) ######"
date
echo

echo "===== 1. All hardware ports (incl. inactive/disabled) ====="
networksetup -listallhardwareports

echo
echo "===== 2. Network service order  ( (n)=active priority,  (*)=DISABLED ) ====="
networksetup -listnetworkserviceorder

echo
echo "===== 3. Global primary service (who owns the default route + DNS) ====="
echo 'show State:/Network/Global/IPv4' | scutil
echo '--- IPv6 ---'
echo 'show State:/Network/Global/IPv6' | scutil

echo
echo "===== 4. All interfaces (ifconfig -a) ====="
ifconfig -a

echo
echo "===== 5. Ethernet adapters (system_profiler) ====="
system_profiler SPEthernetDataType

echo
echo "===== 6. Default routes (v4 + v6) ====="
echo '--- route get default (v4) ---'
route -n get default
echo '--- route get -inet6 default (v6) ---'
route -n get -inet6 default
echo '--- netstat default entries ---'
netstat -rn | grep -E 'Destination|default'

echo
echo "===== 7. $IFACE address + DHCP lease (router / dns / subnet) ====="
echo "--- ifconfig $IFACE ---"
ifconfig "$IFACE"
echo "--- ipconfig getsummary $IFACE ---"
ipconfig getsummary "$IFACE" 2>/dev/null
echo "--- ipconfig getpacket $IFACE  (look for yiaddr / router / subnet_mask / domain_name_server) ---"
ipconfig getpacket "$IFACE" 2>/dev/null

echo
echo "===== 8. DNS resolver config (which servers, in what order) ====="
scutil --dns | sed -n '1,45p'

echo
echo "===== 9. Reachability — separates ROUTING from DNS ====="
GW=$(route -n get default 2>/dev/null | awk '/gateway/{print $2}')
echo "Default gateway detected: ${GW:-<none>}"
if [ -n "$GW" ]; then
  echo "--- arp for gateway (is it even on this L2 segment?) ---"
  arp -n "$GW"
  echo "--- ping gateway x3 ---"
  ping -c 3 -t 5 "$GW"
fi
echo "--- ping 1.1.1.1 x3  (raw IP: tests ROUTING/egress, NO DNS) ---"
ping -c 3 -t 5 1.1.1.1
echo "--- ping 9.9.9.9 x3  (second raw IP) ---"
ping -c 3 -t 5 9.9.9.9
echo "--- ping ethz.ch x3  (needs DNS to work) ---"
ping -c 3 -t 5 ethz.ch
echo "--- DNS lookup (dig, then nslookup fallback) ---"
dig +time=3 +tries=1 ethz.ch A 2>/dev/null || nslookup -timeout=3 ethz.ch
echo "--- traceroute toward 1.1.1.1 (shows WHERE packets die) ---"
traceroute -n -w 2 -q 1 -m 12 1.1.1.1

echo
echo "===== 10. 802.1X / EAP activity on $IFACE ? ====="
pgrep -fl eapolclient || echo "no eapolclient running"

echo
echo "###### END ######"

# Print the path to the real terminal (fd 3, saved before the redirect above).
printf '\nDONE. Saved diagnostics to:\n  %s\nNow re-enable Wi-Fi, then tell Claude:  read %s\n' "$OUT" "$OUT" 1>&3
