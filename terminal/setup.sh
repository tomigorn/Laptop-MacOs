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
step "Local tools (fish, starship, fastfetch, atuin, bat, pipx)"
brew install fish starship fastfetch atuin bat pipx
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
    if [[ "$binary_in_archive" == "find:"* ]]; then
        # Some archives (e.g. bat) embed the version in the directory name.
        # Use find to locate the binary instead of a fixed path.
        local find_name=${binary_in_archive#find:}
        local found
        found=$(find "$tmp" -name "$find_name" -type f | head -1)
        [[ -z "$found" ]] && die "Could not find $find_name in archive"
        mv "$found" "$dest"
    else
        mv "$tmp/$binary_in_archive" "$dest"
    fi
    chmod +x "$dest"
    rm -rf "$tmp"
    ok "$name → ~/.xxh/bin/$name"
}

download_binary starship  "starship-rs/starship"     "x86_64-unknown-linux-musl.tar.gz" "starship"
download_binary atuin     "atuinsh/atuin"            "x86_64-unknown-linux-musl.tar.gz" "atuin-x86_64-unknown-linux-musl/atuin"
download_binary fastfetch "fastfetch-cli/fastfetch"  "linux-amd64.tar.gz"               "fastfetch-linux-amd64/usr/bin/fastfetch"
download_binary bat       "sharkdp/bat"              "x86_64-unknown-linux-musl.tar.gz" "find:bat"

# ── 7. Stage binaries in xxh build dir ───────────────────────────────────────
step "Stage binaries for xxh uploads"
mkdir -p ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin
cp ~/.xxh/bin/starship  ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/starship
cp ~/.xxh/bin/fastfetch ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/fastfetch
cp ~/.xxh/bin/atuin     ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/atuin
cp ~/.xxh/bin/bat       ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/bat
chmod +x ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/starship
chmod +x ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/fastfetch
chmod +x ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/atuin
chmod +x ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/bat
ok "starship, fastfetch, atuin, and bat staged"

# ── Done ─────────────────────────────────────────────────────────────────────
echo
echo "All done. Open a new fish shell and connect with: xxhc <host>"
