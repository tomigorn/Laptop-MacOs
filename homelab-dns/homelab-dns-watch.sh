#!/bin/sh
# homelab-dns-watch — long-running watcher that re-evaluates the network priority
# and the DNS only when the network PATH actually changes.
#
# Why not WatchPaths? Watching files like /etc/resolv.conf or the
# SystemConfiguration directory fires on every config rewrite — and VPN/DNS
# daemons rewrite those constantly even when the network hasn't changed, which
# made the daemon wake every few seconds.
#
# `route -n monitor` instead blocks with ZERO CPU until the routing table
# changes (Wi-Fi join/leave, VPN up/down, gateway change). On a stable network
# it produces no output, so this watcher sleeps indefinitely and never polls.
set -u

ACTOR="/usr/local/sbin/homelab-dns.sh"     # the DNS decide+act script
PRIORITY="/usr/local/sbin/net-priority.sh" # the Ethernet/Wi-Fi order script
SETTLE=3                                    # seconds to let routes/DHCP settle
MIN_GAP=4                                   # min seconds between evaluations

run() {
    [ -x "${PRIORITY}" ] && "${PRIORITY}" "$1"
    [ -x "${ACTOR}" ] && "${ACTOR}" "$1"
}

# Some networks emit route events non-stop; only default routes and addresses count as a change.
fingerprint() {
    netstat -rnf inet 2>/dev/null | awk '$1 == "default" { print $2, $4 }'
    ifconfig 2>/dev/null | awk '/^[a-z]/ { i = $1 } /inet / { print i, $2 }'
}

# Evaluate once at startup (covers boot and daemon (re)load).
run boot
state=$(fingerprint)

last=0
route -n monitor 2>/dev/null | while read -r line; do
    # React only to events that can change reachability; ignore the chatty
    # RTM_GET / RTM_MISS / RTM_LOSING noise.
    case "${line}" in
        *RTM_ADD*|*RTM_DELETE*|*RTM_IFINFO*|*RTM_NEWADDR*|*RTM_DELADDR*) ;;
        *) continue ;;
    esac

    now=$(date +%s)
    [ $((now - last)) -lt "${MIN_GAP}" ] && continue   # coalesce bursts

    sleep "${SETTLE}"     # let the new network settle before probing
    if [ "$(fingerprint)" != "${state}" ]; then
        run change
        state=$(fingerprint)
    fi
    last=$(date +%s)
done
