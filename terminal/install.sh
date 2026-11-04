#!/usr/bin/env bash
# Run once on a new Mac to set up the full terminal environment.
# Safe to re-run — existing files and installs are skipped.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

step()  { echo; printf '\033[1m── %s\033[0m\n' "$*"; }
ok()    { printf '   \033[32m✓\033[0m  %s\n' "$*"; }
skip()  { printf '   \033[2m·\033[0m  %s (already done)\n' "$*"; }
info()  { printf '   %s\n' "$*"; }
die()   { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

symlink() {
    local src=$1 dst=$2
    mkdir -p "$(dirname "$dst")"
    ln -sf "$src" "$dst"
    ok "$(basename "$dst") → $src"
}

# ── 1. Homebrew ───────────────────────────────────────────────────────────────
step "Homebrew"
if command -v brew &>/dev/null; then
    skip "brew"
else
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ok "brew installed"
fi

# ── 2. Local tools ────────────────────────────────────────────────────────────
step "Local tools (fish, starship, fastfetch, atuin, bat, pipx, zstd)"
brew install fish starship fastfetch atuin bat pipx zstd
ok "brew packages installed"

# ── 3. xxh ───────────────────────────────────────────────────────────────────
step "xxh"
pipx ensurepath --quiet
export PATH="$HOME/.local/bin:$PATH"
if pipx list 2>/dev/null | grep -q xxh-xxh; then
    skip "xxh-xxh"
else
    pipx install xxh-xxh
    ok "xxh installed"
fi

if [[ -d ~/.xxh/.xxh/shells/xxh-shell-fish ]]; then
    skip "xxh-shell-fish"
else
    xxh +I xxh-shell-fish
    ok "xxh-shell-fish installed"
fi

# ── 4. Symlinks: local config files ──────────────────────────────────────────
step "Symlinks — local config"
symlink "$SCRIPT_DIR/.config/xxh/config.xxhc"          ~/.config/xxh/config.xxhc
symlink "$SCRIPT_DIR/.config/starship.toml"             ~/.config/starship.toml
symlink "$SCRIPT_DIR/.config/fish/config.fish"          ~/.config/fish/config.fish
symlink "$SCRIPT_DIR/.config/fish/functions/xxhc.fish"          ~/.config/fish/functions/xxhc.fish
symlink "$SCRIPT_DIR/.config/fish/functions/fish_greeting.fish"  ~/.config/fish/functions/fish_greeting.fish
symlink "$SCRIPT_DIR/.config/fish/functions/clear-greet.fish"    ~/.config/fish/functions/clear-greet.fish
symlink "$SCRIPT_DIR/.xxh/ssh-wrapper.sh"               ~/.xxh/ssh-wrapper.sh
chmod +x ~/.xxh/ssh-wrapper.sh
symlink "$SCRIPT_DIR/.xxh/scp-wrapper.sh"               ~/.xxh/scp-wrapper.sh
chmod +x ~/.xxh/scp-wrapper.sh

# Stale links from earlier versions: clearc was renamed, ssh-why moved to ssh/install.sh
[ -L ~/.config/fish/functions/clearc.fish ] && rm ~/.config/fish/functions/clearc.fish
old_sshwhy=~/.config/fish/functions/ssh-why.fish
if [ -L "$old_sshwhy" ] && [[ "$(readlink "$old_sshwhy")" == "$SCRIPT_DIR"/* ]]; then
    rm "$old_sshwhy"
fi

# ── 5. Symlinks: xxh build dir ───────────────────────────────────────────────
step "Symlinks — xxh build dir"
# These make edits to the repo files instantly apply to what gets uploaded on connect
symlink "$SCRIPT_DIR/.xxh/xxh-config.fish"   ~/.xxh/.xxh/shells/xxh-shell-fish/build/xxh-config.fish
symlink "$SCRIPT_DIR/.config/starship.toml"  ~/.xxh/.xxh/shells/xxh-shell-fish/build/starship.toml

# ── 6. Per-architecture binary stores ────────────────────────────────────────
# One store per remote architecture; xxhc uploads the matching one on connect.
# Versions and sha256 are pinned in remote-binaries.conf.
step "Per-architecture binary stores (uploaded to remote on connect)"

"$SCRIPT_DIR/remote-binaries.sh"

# ── 7. Stage default (x86_64) binaries in xxh build dir ──────────────────────
# This keeps a bare `xxh <host>` (without xxhc) working on x86_64 remotes. `xxhc`
# itself uses the dedicated per-arch homes built in step 8, not this default.
step "Stage default x86_64 binaries for xxh uploads"
build=~/.xxh/.xxh/shells/xxh-shell-fish/build
rm -rf "$build/fish-portable" "$build/bin"
cp -R ~/.xxh/arch/x86_64/fish-portable "$build/fish-portable"
cp -R ~/.xxh/arch/x86_64/bin "$build/bin"
# macOS tags files with com.apple.provenance; scp-wrapper.sh tars the tree, and
# GNU tar on the remote prints "Ignoring unknown extended header keyword" for
# every tagged file. Harmless but noisy on every connect, so strip them here.
xattr -cr "$build" 2>/dev/null || true
ok "x86_64 store staged into build dir"

# ── 8. Per-architecture xxh homes ────────────────────────────────────────────
# Each home is a complete xxh local home with that arch's binaries pre-staged.
# `xxhc` points `+lh` at the matching home per connect, so concurrent connects to
# different-architecture hosts never share a build dir (no race), and there is no
# per-connect binary copy. Built once here; reused on every connect.
step "Per-architecture xxh homes (used by xxhc via +lh)"

build_arch_home() {
    local arch=$1
    local home=~/.xxh-homes/$arch
    local hbuild="$home/.xxh/shells/xxh-shell-fish/build"
    if [[ ! -d "$home/.xxh/shells/xxh-shell-fish" ]]; then
        info "Installing xxh-shell-fish into $home..."
        xxh +I xxh-shell-fish +lh "$home" >/dev/null
    fi
    # Same config symlinks as the default build dir (point at the repo).
    ln -sf "$SCRIPT_DIR/.xxh/xxh-config.fish"  "$hbuild/xxh-config.fish"
    ln -sf "$SCRIPT_DIR/.config/starship.toml" "$hbuild/starship.toml"
    # Stage this arch's binaries (idempotent — replaces any previous payload).
    rm -rf "$hbuild/fish-portable" "$hbuild/bin"
    cp -R ~/.xxh/arch/$arch/fish-portable "$hbuild/fish-portable"
    cp -R ~/.xxh/arch/$arch/bin           "$hbuild/bin"
    xattr -cr "$hbuild" 2>/dev/null || true   # see note in step 7
    ok "$arch home ready at $home"
}

build_arch_home x86_64
build_arch_home aarch64

# ── Done ─────────────────────────────────────────────────────────────────────
echo
echo "All done. Open a new fish shell and connect with: xxhc <host>"
