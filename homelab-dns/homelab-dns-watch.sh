#!/bin/sh
# homelab-dns-watch — long-running watcher that re-evaluates the Wi-Fi DNS only
# when the network PATH actually changes.
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

ACTOR="/usr/local/sbin/homelab-dns.sh"   # the decide+act script
SETTLE=3                                  # seconds to let routes/DHCP settle
MIN_GAP=4                                 # min seconds between evaluations

run() { [ -x "${ACTOR}" ] && "${ACTOR}" "$1"; }

# Evaluate once at startup (covers boot and daemon (re)load).
run boot

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
    run change
    last=$(date +%s)
done
