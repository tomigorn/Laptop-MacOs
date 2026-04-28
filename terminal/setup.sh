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

gh_latest_url() {
    local repo=$1 pattern=$2
    curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
        | grep "browser_download_url" \
        | grep "$pattern" \
        | head -1 \
        | cut -d'"' -f4
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
step "Local tools (fish, starship, fzf, atuin, pipx)"
brew install fish starship atuin pipx
ok "brew packages installed"

# ── 3. xxh ───────────────────────────────────────────────────────────────────
step "xxh"
if pipx list | grep -q xxh-xxh; then
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
symlink "$SCRIPT_DIR/.config/fish/functions/xxhc.fish"  ~/.config/fish/functions/xxhc.fish
symlink "$SCRIPT_DIR/.xxh/ssh-wrapper.sh"               ~/.xxh/ssh-wrapper.sh
chmod +x ~/.xxh/ssh-wrapper.sh

# ── 5. Symlinks: xxh build dir ───────────────────────────────────────────────
step "Symlinks — xxh build dir"
# These make edits to the repo files instantly apply to what gets uploaded on connect
symlink "$SCRIPT_DIR/.xxh/xxh-config.fish"   ~/.xxh/.xxh/shells/xxh-shell-fish/build/xxh-config.fish
symlink "$SCRIPT_DIR/.config/starship.toml"  ~/.xxh/.xxh/shells/xxh-shell-fish/build/starship.toml

# ── 6. Linux static binaries ─────────────────────────────────────────────────
step "Linux static binaries (uploaded to remote on connect)"
mkdir -p ~/.xxh/bin

download_binary() {
    local name=$1 repo=$2 pattern=$3 binary_in_archive=$4
    local dest=~/.xxh/bin/$name
    if [[ -f "$dest" ]]; then
        skip "$name"
        return
    fi
    info "Fetching latest $name from $repo..."
    local url
    url=$(gh_latest_url "$repo" "$pattern")
    [[ -z "$url" ]] && die "Could not find download URL for $name"
    local tmp
    tmp=$(mktemp -d)
    curl -fsSL "$url" | tar -xz -C "$tmp"
    mv "$tmp/$binary_in_archive" "$dest"
    chmod +x "$dest"
    rm -rf "$tmp"
    ok "$name → ~/.xxh/bin/$name"
}

download_binary starship "starship-rs/starship"  "x86_64-unknown-linux-musl.tar.gz" "starship"
download_binary atuin    "atuinsh/atuin"          "x86_64-unknown-linux-musl.tar.gz" "atuin/atuin"

# ── 7. Stage starship binary in xxh build dir ────────────────────────────────
step "Stage starship binary for xxh uploads"
mkdir -p ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin
cp ~/.xxh/bin/starship ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/starship
chmod +x ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/starship
ok "starship binary staged"

# ── Done ─────────────────────────────────────────────────────────────────────
echo
echo "All done. Open a new fish shell and connect with: xxhc <host>"
