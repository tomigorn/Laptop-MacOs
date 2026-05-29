#!/usr/bin/env bash
# Install the homelab-dns auto-switcher. Safe to re-run.
#
#   1. Copies homelab-dns.sh + homelab-dns-watch.sh to /usr/local/sbin (root)
#   2. Installs the LaunchDaemon to /Library/LaunchDaemons
#   3. (Re)loads the daemon so it takes effect immediately
#
# Must run as root (it writes to /usr/local/sbin and /Library/LaunchDaemons
# and the daemon calls `networksetup`, which needs admin rights):
#
#     sudo ./install.sh
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
LABEL="com.tmilata.homelab-dns"
TIMER_LABEL="com.tmilata.homelab-dns-timer"
BIN_DEST="/usr/local/sbin/homelab-dns.sh"
WATCH_DEST="/usr/local/sbin/homelab-dns-watch.sh"
PLIST_DEST="/Library/LaunchDaemons/${LABEL}.plist"
TIMER_PLIST_DEST="/Library/LaunchDaemons/${TIMER_LABEL}.plist"

step()  { echo; printf '\033[1m── %s\033[0m\n' "$*"; }
ok()    { printf '   \033[32m✓\033[0m  %s\n' "$*"; }
info()  { printf '   %s\n' "$*"; }
warn()  { printf '   \033[33m!\033[0m  %s\n' "$*"; }
die()   { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run with sudo: sudo ./install.sh"

# ── 1. Scripts ───────────────────────────────────────────────────────────────
step "Scripts -> /usr/local/sbin"
install -d -m 755 /usr/local/sbin
install -m 755 -o root -g wheel "${SCRIPT_DIR}/homelab-dns.sh"       "${BIN_DEST}"
install -m 755 -o root -g wheel "${SCRIPT_DIR}/homelab-dns-watch.sh" "${WATCH_DEST}"
ok "installed actor + watcher"

# ── 2. LaunchDaemons ─────────────────────────────────────────────────────────
step "LaunchDaemons -> /Library/LaunchDaemons"
install -m 644 -o root -g wheel "${SCRIPT_DIR}/${LABEL}.plist"       "${PLIST_DEST}"
install -m 644 -o root -g wheel "${SCRIPT_DIR}/${TIMER_LABEL}.plist" "${TIMER_PLIST_DEST}"
ok "installed watcher + 5-min timer"

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

step "Done"
info "Live log:   tail -f /var/log/homelab-dns.log"
info "Current DNS: networksetup -getdnsservers Wi-Fi"
info "Kick it now: sudo launchctl kickstart -k system/${LABEL}"
