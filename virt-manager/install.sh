#!/usr/bin/env bash
# Full virt-manager setup for a new Mac. Safe to re-run.
#
#   1. Installs libvirt + virt-manager from Homebrew (homebrew/core)
#   2. Starts the libvirt service (LaunchAgent)
#   3. Verifies the fish XDG_DATA_DIRS line that lets virt-manager find its
#      GSettings schemas (set up by terminal/setup.sh; warns if missing)
#   4. Builds ~/Applications/Virt-Manager.app for Spotlight / Launchpad / dock
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

step()  { echo; printf '\033[1m── %s\033[0m\n' "$*"; }
ok()    { printf '   \033[32m✓\033[0m  %s\n' "$*"; }
skip()  { printf '   \033[2m·\033[0m  %s (already done)\n' "$*"; }
info()  { printf '   %s\n' "$*"; }
warn()  { printf '   \033[33m!\033[0m  %s\n' "$*"; }
die()   { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# ── 1. Homebrew ──────────────────────────────────────────────────────────────
step "Homebrew"
command -v brew >/dev/null || die "Homebrew not found — install from https://brew.sh first"
ok "brew present ($(brew --prefix))"

# ── 2. Packages ──────────────────────────────────────────────────────────────
step "Brew packages: libvirt, virt-manager"
# virt-manager lives in homebrew/core today — the arthurk/virt-manager tap
# referenced in older guides is no longer required.
brew install libvirt virt-manager
ok "libvirt $(brew list --versions libvirt | awk '{print $2}') + virt-manager $(brew list --versions virt-manager | awk '{print $2}')"

# ── 3. libvirt LaunchAgent ───────────────────────────────────────────────────
step "libvirt service"
if brew services list | awk '$1=="libvirt"{print $2}' | grep -qx started; then
    skip "libvirt already running"
else
    brew services start libvirt
    ok "libvirt service started"
fi

# Smoke test: confirm we can talk to qemu:///session
if /opt/homebrew/bin/virsh --connect qemu:///session uri >/dev/null 2>&1; then
    ok "virsh qemu:///session reachable"
else
    warn "virsh could not reach qemu:///session — give the service a few seconds and retry"
fi

# ── 4. Fish XDG_DATA_DIRS (GSettings schemas) ────────────────────────────────
step "Fish XDG_DATA_DIRS for GSettings schemas"
FISH_CONFIG="$HOME/.config/fish/config.fish"
NEEDLE='XDG_DATA_DIRS /opt/homebrew/share'
if [[ -f "$FISH_CONFIG" ]] && grep -qF "$NEEDLE" "$FISH_CONFIG"; then
    skip "XDG_DATA_DIRS line in $FISH_CONFIG"
else
    warn "Fish config does not export XDG_DATA_DIRS=/opt/homebrew/share."
    warn "Run terminal/setup.sh (which symlinks the repo's config.fish into ~/.config/fish/),"
    warn "or add this line yourself:"
    info "  set -gx --path XDG_DATA_DIRS /opt/homebrew/share \$XDG_DATA_DIRS"
fi

# ── 5. Virt-Manager.app for Spotlight / Launchpad / dock ─────────────────────
step "Virt-Manager.app (Spotlight-launchable wrapper)"
"$SCRIPT_DIR/build.sh"
ok ".app built at ~/Applications/Virt-Manager.app"

echo
echo "All done. Launch options:"
echo "  • Spotlight: type 'virt' → Enter"
echo "  • Launchpad / Finder: ~/Applications/Virt-Manager.app"
echo "  • Terminal (fish):    virt-manager"
