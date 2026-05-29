#!/bin/sh
# homelab-dns — point every network interface's DNS at the homelab resolver when
# (and only when) the homelab is actually reachable, otherwise fall back to DHCP.
#
# Why this exists: the ISP router's DHCP can't be changed to advertise the
# homelab DNS, and macOS has no per-SSID / per-network DNS setting (DNS is global
# per interface). So this script is run by a LaunchDaemon on every network change
# and flips the DNS on ALL enabled network services — Wi-Fi, Ethernet, USB /
# Thunderbolt adapters, … — based on a live probe, so whichever interface is (or
# becomes) active uses the right resolver. No SSID detection needed (SSID is
# locked behind Location Services on recent macOS anyway).
#
# Detection is self-validating: it asks the homelab DNS to resolve a name that
# ONLY the homelab DNS knows. A real answer means we're home or on the VPN.
set -u

REASON="${1:-manual}"         # why we ran: boot | change | timer | manual
DNS_SERVER="192.168.1.2"      # homelab DNS server
PROBE_NAME="probe.homelab"    # dedicated probe name (AdGuard DNS rewrite)
PROBE_EXPECT="198.51.100.53"  # sentinel A it MUST return — RFC 5737 TEST-NET-2,
                              # never a real host, so a wildcard/hijacking resolver
                              # on a foreign 192.168.1.x net can't match it by luck.
                              # Acts as a shared secret: "the homelab answered", not
                              # merely "something answered".
                              # NB: the set of network services is discovered at
                              # runtime via `networksetup -listallnetworkservices`,
                              # so no interface needs to be named here.
LOG="/var/log/homelab-dns.log"
LOG_MAX_BYTES=65536           # rotate at 64 KB; keeps current + one old = 128 KB max

# ── logging with one-file rollover ───────────────────────────────────────────
rotate_log() {
    [ -f "${LOG}" ] || return 0
    size=$(stat -f%z "${LOG}" 2>/dev/null || echo 0)
    [ "${size}" -gt "${LOG_MAX_BYTES}" ] && mv -f "${LOG}" "${LOG}.1"
}
log() {
    rotate_log
    printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "${LOG}" 2>/dev/null
}

# ── gather context (for the log line) ────────────────────────────────────────
gw=$(route -n get default 2>/dev/null | awk '/gateway:/{print $2}')
iface=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
[ -n "${gw}" ]    || gw="none"
[ -n "${iface}" ] || iface="none"

# Reachable only if the homelab DNS returns our EXACT sentinel answer (1s, single
# try). Matching the secret — not just "an IP" — rejects NXDOMAIN-hijacking or
# wildcard resolvers we might hit on a foreign 192.168.1.x network.
ans=$(dig +time=1 +tries=1 +short "@${DNS_SERVER}" "${PROBE_NAME}" 2>/dev/null | head -n1)
if [ "${ans}" = "${PROBE_EXPECT}" ]; then
    reachable=1; reach_str="reachable"
else
    reachable=0; reach_str="unreachable"
fi

# ── decide + act on every enabled network service ─────────────────────────────
# One global probe, applied to all interfaces. We only write DNS when it actually
# changes. When reachable we take over each service's DNS (that's the point of the
# tool); when unreachable we revert ONLY services still set to our DNS_SERVER —
# a resolver someone/something else configured is left untouched.
services=$(networksetup -listallnetworkservices 2>/dev/null)

changed=""                    # services we actually modified, for the log line
OLDIFS=$IFS
IFS='
'                             # split the service list on newlines only (names have spaces)
for svc in ${services}; do
    case "${svc}" in
        'An asterisk'*) continue ;;   # the header line
        '*'*)           continue ;;   # a disabled service (leading '*')
    esac

    cur=$(networksetup -getdnsservers "${svc}" 2>/dev/null)
    if [ "${reachable}" -eq 1 ]; then
        [ "${cur}" = "${DNS_SERVER}" ] && continue          # already ours
        networksetup -setdnsservers "${svc}" "${DNS_SERVER}" 2>/dev/null \
            && changed="${changed} [${svc}]set->${DNS_SERVER}"
    else
        [ "${cur}" = "${DNS_SERVER}" ] || continue          # not ours → leave alone
        networksetup -setdnsservers "${svc}" empty 2>/dev/null \
            && changed="${changed} [${svc}]revert->dhcp"
    fi
done
IFS=$OLDIFS

changed=${changed# }                                        # trim leading space
[ -n "${changed}" ] || changed="none"

# The 300s timer is a safety net for the watcher's one blind spot: it reacts only
# to route changes, so if the homelab DNS was down during the last change (e.g. Pi
# rebooting) we'd stay on DHCP until the *next* route change. The heartbeat re-probes
# regardless — but stays silent unless it actually changed something, so the log
# keeps showing real events, not 288 "nothing happened" lines a day.
if [ "${REASON}" = "timer" ] && [ "${changed}" = "none" ]; then
    exit 0
fi

log "${REASON}  iface=${iface} gw=${gw}  homelab=${reach_str}  changed=${changed}"
