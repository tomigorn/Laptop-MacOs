#!/usr/bin/env bash
# Remove the yabai + skhd window-manager setup. Safe to re-run.
#
#   1. Stops the yabai + skhd services
#   2. Removes the config symlinks (your zones.conf is kept by default)
#
# Flags:
#   --purge-zones   also delete ~/.config/yabai/zones.conf (your monitor list)
#   --uninstall     also `brew uninstall` yabai, skhd (jq is left alone)
set -euo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

step()  { echo; printf '\033[1m── %s\033[0m\n' "$*"; }
ok()    { printf '   \033[32m✓\033[0m  %s\n' "$*"; }
info()  { printf '   %s\n' "$*"; }
warn()  { printf '   \033[33m!\033[0m  %s\n' "$*"; }

PURGE_ZONES=0; UNINSTALL=0
for a in "$@"; do
    case "$a" in
        --purge-zones) PURGE_ZONES=1 ;;
        --uninstall)   UNINSTALL=1 ;;
        -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
        *) echo "unknown flag: $a" >&2; exit 1 ;;
    esac
done

step "Stop services"
yabai --stop-service 2>/dev/null && ok "yabai stopped" || info "yabai service not running"
skhd  --stop-service 2>/dev/null && ok "skhd stopped"  || info "skhd service not running"

step "Remove config symlinks"
for f in "$CONFIG_HOME/yabai/yabairc" \
         "$CONFIG_HOME/yabai/yabai-snap.sh" \
         "$CONFIG_HOME/yabai/keys.conf" \
         "$CONFIG_HOME/yabai/README.md" \
         "$CONFIG_HOME/skhd/skhdrc"; do
    if [ -L "$f" ]; then rm -f "$f"; ok "removed $f"; fi
done

step "Remove Spotlight launcher"
APP="$HOME/Applications/yabai window manager.app"
if [ -e "$APP" ]; then rm -rf "$APP"; ok "removed launcher app"; else info "no launcher app"; fi

step "zones.conf"
if [ "$PURGE_ZONES" -eq 1 ]; then
    rm -f "$CONFIG_HOME/yabai/zones.conf" && ok "deleted zones.conf"
else
    info "kept $CONFIG_HOME/yabai/zones.conf (use --purge-zones to delete)"
fi

if [ "$UNINSTALL" -eq 1 ]; then
    step "Uninstall packages"
    brew uninstall yabai skhd 2>/dev/null && ok "removed yabai + skhd" || warn "brew uninstall skipped"
fi

step "Done"
