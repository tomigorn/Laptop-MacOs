#!/usr/bin/env bash
# yabai + skhd window-manager setup for a new Mac. Safe to re-run.
#
#   1. Installs yabai, skhd, jq from Homebrew (only what's missing)
#   2. Symlinks the configs into ~/.config (yabairc, yabai-snap.sh, keys.conf)
#   3. Seeds ~/.config/yabai/zones.conf from the example (only if absent — the
#      live file is machine-specific and the script appends to it)
#   4. Starts / restarts the yabai + skhd LaunchAgents
#
# Flags:
#   --skip-services   don't start/restart services (useful for testing)
#
# NOTE: this setup does NOT use yabai's scripting addition, so SIP stays enabled.
# After a fresh install you must grant Accessibility to yabai and skhd once
# (System Settings → Privacy & Security → Accessibility), then re-run with --skip
# nothing, or just `yabai --restart-service && skhd --restart-service`.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CONFIG_SRC="$SCRIPT_DIR/config"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

step()  { echo; printf '\033[1m── %s\033[0m\n' "$*"; }
ok()    { printf '   \033[32m✓\033[0m  %s\n' "$*"; }
skip()  { printf '   \033[2m·\033[0m  %s (already done)\n' "$*"; }
info()  { printf '   %s\n' "$*"; }
warn()  { printf '   \033[33m!\033[0m  %s\n' "$*"; }
die()   { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

SKIP_SERVICES=0
for a in "$@"; do
    case "$a" in
        --skip-services) SKIP_SERVICES=1 ;;
        -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
        *) die "unknown flag: $a" ;;
    esac
done

# Back up a real file (not one of our symlinks) before replacing it.
backup_if_real() {
    local p=$1
    if [ -L "$p" ]; then
        rm -f "$p"
    elif [ -e "$p" ]; then
        mv "$p" "$p.bak.$(date +%Y%m%d%H%M%S)"
        warn "backed up existing $(basename "$p") -> $(basename "$p").bak.*"
    fi
}

link() {  # $1 = source, $2 = destination
    mkdir -p "$(dirname "$2")"
    backup_if_real "$2"
    ln -sf "$1" "$2"
    ok "$(basename "$2") → $1"
}

# ── 1. Homebrew packages ─────────────────────────────────────────────────────
step "Homebrew packages: yabai, skhd, jq"
command -v brew >/dev/null || die "Homebrew not found — install from https://brew.sh first"
missing=()
for p in yabai skhd jq; do command -v "$p" >/dev/null 2>&1 || missing+=("$p"); done
if [ "${#missing[@]}" -eq 0 ]; then
    skip "yabai, skhd, jq all present"
else
    for p in "${missing[@]}"; do
        case "$p" in
            yabai|skhd) brew install "koekeishiya/formulae/$p" ;;
            *)          brew install "$p" ;;
        esac
    done
    ok "installed: ${missing[*]}"
fi

# ── 2. Config symlinks ───────────────────────────────────────────────────────
step "Config files (symlinked from this repo)"
chmod +x "$CONFIG_SRC/yabai-snap.sh" "$CONFIG_SRC/yabairc"
link "$CONFIG_SRC/yabairc"        "$CONFIG_HOME/yabai/yabairc"
link "$CONFIG_SRC/yabai-snap.sh"  "$CONFIG_HOME/yabai/yabai-snap.sh"
link "$CONFIG_SRC/keys.conf"      "$CONFIG_HOME/yabai/keys.conf"
link "$CONFIG_SRC/README.md"      "$CONFIG_HOME/yabai/README.md"
# skhd only looks in ~/.config/skhd/skhdrc (or ~/.skhdrc); point it at keys.conf.
link "$CONFIG_HOME/yabai/keys.conf"  "$CONFIG_HOME/skhd/skhdrc"

# ── 3. zones.conf (machine-local, never overwritten) ─────────────────────────
step "zones.conf (your monitors + layouts)"
if [ -e "$CONFIG_HOME/yabai/zones.conf" ]; then
    skip "zones.conf exists — left untouched"
else
    cp "$CONFIG_SRC/zones.conf.example" "$CONFIG_HOME/yabai/zones.conf"
    ok "created zones.conf from example"
fi

# ── 4. Services ──────────────────────────────────────────────────────────────
step "yabai + skhd services"
if [ "$SKIP_SERVICES" -eq 1 ]; then
    skip "service start skipped (--skip-services)"
else
    yabai --restart-service 2>/dev/null || yabai --start-service
    skhd  --restart-service 2>/dev/null || skhd  --start-service
    sleep 1
    if pgrep -x yabai >/dev/null && pgrep -x skhd >/dev/null; then
        ok "yabai + skhd running"
    else
        warn "services not running yet — likely waiting on Accessibility permission"
        info "Grant it: System Settings → Privacy & Security → Accessibility"
        info "  add/enable  $(brew --prefix)/bin/yabai  and  $(brew --prefix)/bin/skhd"
        info "then: yabai --restart-service && skhd --restart-service"
    fi
fi

# ── 5. Spotlight launcher app ────────────────────────────────────────────────
step "Spotlight launcher: \"yabai window manager.app\""
"$SCRIPT_DIR/build-launcher.sh" | sed 's/^/   /'
ok "type 'yabai' in Spotlight to open the config folder in VS Code"

step "Done"
info "Shortcuts:  ⌃⌥ ←/→  walk window left/right (crosses displays)"
info "            ⌃⌥ ↑    fill the display"
info "Edit sizes: $CONFIG_HOME/yabai/zones.conf   (no restart needed)"
info "Spotlight:  type 'yabai' → opens this folder in VS Code"
