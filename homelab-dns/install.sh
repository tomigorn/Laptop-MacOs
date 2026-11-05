#!/usr/bin/env bash
# Install the homelab-dns auto-switcher. Safe to re-run.
#
#   1. Copies homelab-dns.sh + homelab-dns-watch.sh + net-priority.sh + homelab-dns-control.sh to /usr/local/sbin (root)
#   2. Installs the LaunchDaemons (watcher, timer, control) to /Library/LaunchDaemons
#   3. Creates /usr/local/var/homelab-dns, owned by you: the stop flag lives there
#   4. (Re)loads the daemons so they take effect immediately
#
# Must run as root, from your own account via sudo (it writes to /usr/local/sbin and /Library/LaunchDaemons
# and the daemon calls `networksetup`, which needs admin rights):
#
#     sudo ./install.sh
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
LABEL="com.tomigorn.homelab-dns"
TIMER_LABEL="com.tomigorn.homelab-dns-timer"
BIN_DEST="/usr/local/sbin/homelab-dns.sh"
WATCH_DEST="/usr/local/sbin/homelab-dns-watch.sh"
PRIORITY_DEST="/usr/local/sbin/net-priority.sh"
CONTROL_LABEL="com.tomigorn.homelab-dns-control"
CONTROL_DEST="/usr/local/sbin/homelab-dns-control.sh"
STATE_DIR="/usr/local/var/homelab-dns"
PLIST_DEST="/Library/LaunchDaemons/${LABEL}.plist"
TIMER_PLIST_DEST="/Library/LaunchDaemons/${TIMER_LABEL}.plist"
CONTROL_PLIST_DEST="/Library/LaunchDaemons/${CONTROL_LABEL}.plist"

step()  { echo; printf '\033[1m── %s\033[0m\n' "$*"; }
ok()    { printf '   \033[32m✓\033[0m  %s\n' "$*"; }
info()  { printf '   %s\n' "$*"; }
warn()  { printf '   \033[33m!\033[0m  %s\n' "$*"; }
die()   { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run with sudo: sudo ./install.sh"
[ -n "${SUDO_USER:-}" ] || die "run with sudo from your own account, the flag folder belongs to you"

# ── 1. Scripts ───────────────────────────────────────────────────────────────
step "Scripts -> /usr/local/sbin"
install -d -m 755 /usr/local/sbin
install -m 755 -o root -g wheel "${SCRIPT_DIR}/homelab-dns.sh"       "${BIN_DEST}"
install -m 755 -o root -g wheel "${SCRIPT_DIR}/homelab-dns-watch.sh" "${WATCH_DEST}"
install -m 755 -o root -g wheel "${SCRIPT_DIR}/net-priority.sh"      "${PRIORITY_DEST}"
install -m 755 -o root -g wheel "${SCRIPT_DIR}/homelab-dns-control.sh" "${CONTROL_DEST}"
ok "installed actor + watcher + network priority + control"

# ── 2. LaunchDaemons ─────────────────────────────────────────────────────────
step "LaunchDaemons -> /Library/LaunchDaemons"
install -m 644 -o root -g wheel "${SCRIPT_DIR}/${LABEL}.plist"       "${PLIST_DEST}"
install -m 644 -o root -g wheel "${SCRIPT_DIR}/${TIMER_LABEL}.plist" "${TIMER_PLIST_DEST}"
install -m 644 -o root -g wheel "${SCRIPT_DIR}/${CONTROL_LABEL}.plist" "${CONTROL_PLIST_DEST}"
ok "installed watcher + 5-min timer + control"

step "Flag folder -> ${STATE_DIR}"
install -d -m 755 -o "${SUDO_USER}" -g staff "${STATE_DIR}"
ok "${STATE_DIR} belongs to ${SUDO_USER}"

# ── 3. (Re)load ──────────────────────────────────────────────────────────────
step "Loading daemons"
launchctl bootout system "${PLIST_DEST}" 2>/dev/null || true
launchctl bootstrap system "${PLIST_DEST}"
launchctl enable "system/${LABEL}"
ok "watcher loaded — runs at boot and on every network change"

launchctl bootout system "${TIMER_PLIST_DEST}" 2>/dev/null || true
launchctl bootstrap system "${TIMER_PLIST_DEST}"
launchctl enable "system/${TIMER_LABEL}"
ok "timer loaded — re-checks every 5 min (silent unless it changes DNS)"

launchctl bootout system "${CONTROL_PLIST_DEST}" 2>/dev/null || true
launchctl bootstrap system "${CONTROL_PLIST_DEST}"
launchctl enable "system/${CONTROL_LABEL}"
ok "control loaded — Network Stop and Network Start take effect at once"

step "Done"
info "Live log:   tail -f /var/log/homelab-dns.log"
info "Current DNS: networksetup -getdnsservers Wi-Fi"
info "Kick it now: sudo launchctl kickstart -k system/${LABEL}"
