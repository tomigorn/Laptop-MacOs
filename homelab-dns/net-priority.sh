#!/bin/sh
# net-priority: keep Ethernet above Wi-Fi only while it reaches the internet. Run by homelab-dns-watch.sh on real network changes.
set -u

REASON="${1:-manual}"         # boot | change | control | manual
STOP_FLAG="/usr/local/var/homelab-dns/stopped"
LOG="/var/log/homelab-dns.log"
EXPECT="NetworkManager is online"
SITES="http://nmcheck.gnome.org/check_network_status.txt
http://ping.archlinux.org/nm-check.txt
http://network-test.debian.org/nm"
ROUNDS=2                      # rounds over all sites before a connection counts as failed
GAP=2                         # seconds between rounds

# Stopped means hands off; only the run triggered by Network Stop itself reverts.
stopped() { [ -e "${STOP_FLAG}" ]; }
if stopped && [ "${REASON}" != "control" ]; then exit 0; fi

# A captive network can hijack DNS, so each connection resolves through its own server.
try_site() {  # try_site <dev> <ip> <dns> <url>
    host=${4#http://}; host=${host%%/*}
    if [ -n "$3" ]; then
        addr=$(dig +short +time=2 +tries=1 -b "$2" "@$3" "${host}" A 2>/dev/null | grep -E '^[0-9.]+$' | tail -n 1)
        [ -n "${addr}" ] || return 1
        curl -4 -s --interface "$1" --max-time 3 --resolve "${host}:80:${addr}" "$4" 2>/dev/null | grep -q "${EXPECT}"
    else
        curl -4 -s --interface "$1" --max-time 3 "$4" 2>/dev/null | grep -q "${EXPECT}"
    fi
}

online() {  # online <dev>
    ip=$(ipconfig getifaddr "$1" 2>/dev/null)
    [ -n "${ip}" ] || return 1
    dns=$(ipconfig getoption "$1" domain_name_server 2>/dev/null)
    round=0
    while [ "${round}" -lt "${ROUNDS}" ]; do
        round=$((round + 1))
        for url in ${SITES}; do
            try_site "$1" "${ip}" "${dns}" "${url}" && return 0
        done
        [ "${round}" -lt "${ROUNDS}" ] && sleep "${GAP}"
    done
    return 1
}

wifi_state="unchecked"
wifi_online() {
    if [ "${wifi_state}" = "unchecked" ]; then
        if online "${wifi_dev}"; then wifi_state="ok"; else wifi_state="fail"; fi
    fi
    [ "${wifi_state}" = "ok" ]
}

position() { printf '%s\n' "${names}" | grep -nxF "$1" | cut -d: -f1; }

move() {  # move <service> above|below : place the service directly next to Wi-Fi
    names=$(printf '%s\n' "${names}" | awk -v s="$1" -v w="${wifi_svc}" -v m="$2" '
        $0 == s { next }
        $0 == w { if (m == "above") print s; print; if (m == "below") print s; next }
        { print }')
    changed="${changed} [$1]$2-wifi"
}

apply_order() {
    if [ -z "${changed}" ]; then
        changed="none"
    else
        OLDIFS=$IFS
        IFS='
'
        # shellcheck disable=SC2086
        networksetup -ordernetworkservices ${names} 2>/dev/null || changed=" order-failed"
        IFS=$OLDIFS
    fi
}

# One line per service: flag|device|hardware port|name
services=$(networksetup -listnetworkserviceorder 2>/dev/null | awk '
    /^\(\*\) /      { flag = "off"; name = substr($0, 5); next }
    /^\([0-9]+\) /  { flag = "on"; name = $0; sub(/^\([0-9]+\) /, "", name); next }
    /^\(Hardware Port: / {
        port = $0; sub(/^\(Hardware Port: /, "", port); sub(/, Device:.*/, "", port)
        dev = $0; sub(/.*Device: ?/, "", dev); sub(/\)$/, "", dev)
        print flag "|" dev "|" port "|" name
    }')
names=$(printf '%s\n' "${services}" | cut -d'|' -f4-)
wifi_line=$(printf '%s\n' "${services}" | awk -F'|' '$3 == "Wi-Fi" { print; exit }')
[ -n "${wifi_line}" ] || exit 0
wifi_dev=$(printf '%s\n' "${wifi_line}" | cut -d'|' -f2)
wifi_svc=$(printf '%s\n' "${wifi_line}" | cut -d'|' -f4-)

revert_order() {  # Stop: every en adapter directly above Wi-Fi, no probes
    changed=""
    names=$(printf '%s\n' "${services}" | cut -d'|' -f4-)
    while IFS='|' read -r flag dev port name; do
        [ "${name}" != "${wifi_svc}" ] || continue
        case "${dev}" in en[0-9]*) ;; *) continue ;; esac
        [ "$(position "${name}")" -gt "$(position "${wifi_svc}")" ] && move "${name}" above
    done <<EOF
${services}
EOF
    apply_order
    printf '%s  %s  priority  stopped  changed=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${REASON}" "${changed# }" >> "${LOG}" 2>/dev/null
    exit 0
}

report=""
changed=""
if stopped; then
    [ "${REASON}" = "control" ] || exit 0
    revert_order
fi

while IFS='|' read -r flag dev port name; do
    stopped && break
    [ "${flag}" = "on" ] && [ "${name}" != "${wifi_svc}" ] || continue
    case "${dev}" in en[0-9]*) ;; *) continue ;; esac
    [ -n "$(ipconfig getifaddr "${dev}" 2>/dev/null)" ] || continue

    if online "${dev}"; then
        report="${report} [${name}]=ok"
        [ "$(position "${name}")" -gt "$(position "${wifi_svc}")" ] && move "${name}" above
    else
        report="${report} [${name}]=fail"
        if wifi_online && [ "$(position "${name}")" -lt "$(position "${wifi_svc}")" ]; then
            move "${name}" below
        fi
    fi
done <<EOF
${services}
EOF

if stopped; then
    [ "${REASON}" = "control" ] || exit 0
    revert_order
fi

[ -n "${report}" ] || exit 0

apply_order

printf '%s  %s  priority %s wifi=%s  changed=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${REASON}" "${report}" "${wifi_state}" "${changed# }" >> "${LOG}" 2>/dev/null
