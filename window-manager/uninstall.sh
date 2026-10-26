#!/usr/bin/env bash
# Remove the yabai + skhd window-manager setup. Safe to re-run.
#
#   1. Stops the yabai + skhd services
#   2. Removes the config symlinks (zones.conf stays in the repo) and connected.txt
#
# Flags:
#   --uninstall     also `brew uninstall` yabai, skhd, displayplacer (jq is left alone)
set -euo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

step()  { echo; printf '\033[1m── %s\033[0m\n' "$*"; }
ok()    { printf '   \033[32m✓\033[0m  %s\n' "$*"; }
info()  { printf '   %s\n' "$*"; }
warn()  { printf '   \033[33m!\033[0m  %s\n' "$*"; }

UNINSTALL=0
for a in "$@"; do
    case "$a" in
        --uninstall)   UNINSTALL=1 ;;
        -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
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
         "$CONFIG_HOME/yabai/zones.conf" \
         "$CONFIG_HOME/skhd/skhdrc"; do
    if [ -L "$f" ]; then rm -f "$f"; ok "removed $f"; fi
done

step "Remove Spotlight launchers"
for APP in "$HOME/Applications/yabai window manager.app" \
           "$HOME/Applications/yabai window manager - restart.app"; do
    if [ -e "$APP" ]; then rm -rf "$APP"; ok "removed $(basename "$APP")"; else info "no $(basename "$APP")"; fi
done

rm -f "$CONFIG_HOME/yabai/connected.txt"

if [ "$UNINSTALL" -eq 1 ]; then
    step "Uninstall packages"
    brew uninstall yabai skhd displayplacer 2>/dev/null && ok "removed yabai, skhd, displayplacer" || warn "brew uninstall skipped"
fi

step "Done"
