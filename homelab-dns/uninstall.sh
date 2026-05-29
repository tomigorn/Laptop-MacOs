#!/usr/bin/env bash
# Remove the homelab-dns auto-switcher. Safe to re-run.
#
#   1. Unloads + deletes both LaunchDaemons (watcher + 5-min timer schedule)
#   2. Deletes both scripts from /usr/local/sbin
#   3. Reverts the Wi-Fi DNS to DHCP — but ONLY if it's still the one we set;
#      a DNS someone/something else configured is left untouched
#
# Must run as root:
#
#     sudo ./uninstall.sh
set -euo pipefail

LABEL="com.tmilata.homelab-dns"
TIMER_LABEL="com.tmilata.homelab-dns-timer"
BIN_DEST="/usr/local/sbin/homelab-dns.sh"
WATCH_DEST="/usr/local/sbin/homelab-dns-watch.sh"
PLIST_DEST="/Library/LaunchDaemons/${LABEL}.plist"
TIMER_PLIST_DEST="/Library/LaunchDaemons/${TIMER_LABEL}.plist"
DNS_SERVER="192.168.1.2"      # the only DNS this tool ever sets — see actor

step()  { echo; printf '\033[1m── %s\033[0m\n' "$*"; }
ok()    { printf '   \033[32m✓\033[0m  %s\n' "$*"; }
skip()  { printf '   \033[2m·\033[0m  %s\n' "$*"; }
info()  { printf '   %s\n' "$*"; }
die()   { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run with sudo: sudo ./uninstall.sh"

# ── 1. Daemons ───────────────────────────────────────────────────────────────
step "LaunchDaemons"
for pair in "${LABEL}|${PLIST_DEST}" "${TIMER_LABEL}|${TIMER_PLIST_DEST}"; do
    label=${pair%%|*}
    plist=${pair##*|}
    if launchctl print "system/${label}" >/dev/null 2>&1; then
        launchctl bootout system "${plist}" 2>/dev/null || true
        ok "unloaded ${label}"
    else
        skip "${label} not loaded"
    fi
    if [ -f "${plist}" ]; then
        rm -f "${plist}"
        ok "removed ${plist}"
    else
        skip "${plist} already gone"
    fi
done

# ── 2. Scripts ───────────────────────────────────────────────────────────────
step "Scripts"
for f in "${BIN_DEST}" "${WATCH_DEST}"; do
    if [ -f "${f}" ]; then
        rm -f "${f}"
        ok "removed ${f}"
    else
        skip "${f} already gone"
    fi
done

# ── 3. DNS: revert ONLY the services where it's still ours ───────────────────
# Same rule the actor uses, across every enabled service: undo only the DNS WE set
# (DNS_SERVER), restoring the pre-install state (DHCP). Any service already on DHCP,
# or carrying a resolver someone/something else set, is left completely untouched.
step "Resetting DNS"
services=$(networksetup -listallnetworkservices 2>/dev/null)
reverted=0
OLDIFS=$IFS
IFS='
'
for svc in ${services}; do
    case "${svc}" in 'An asterisk'*) continue ;; '*'*) continue ;; esac
    cur=$(networksetup -getdnsservers "${svc}" 2>/dev/null)
    if [ "${cur}" = "${DNS_SERVER}" ]; then
        networksetup -setdnsservers "${svc}" empty 2>/dev/null || true
        ok "[${svc}] was ours (${DNS_SERVER}) → reverted to DHCP"
        reverted=$((reverted + 1))
    fi
done
IFS=$OLDIFS
[ "${reverted}" -gt 0 ] || skip "no service was using our DNS — nothing to revert"

step "Done"
info "Log file left in place: /var/log/homelab-dns.log (remove manually if you want)"
