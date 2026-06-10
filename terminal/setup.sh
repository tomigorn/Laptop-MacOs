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
        | grep -vE 'sha256|\.sig|\.asc|-update' \
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

# ── 6. Per-architecture binary stores ────────────────────────────────────────
# One store per remote architecture; xxhc uploads the matching one on connect.
step "Per-architecture binary stores (uploaded to remote on connect)"

download_binary() {
    local dest=$1 repo=$2 pattern=$3 binary_in_archive=$4
    if [[ -f "$dest" ]]; then
        skip "$(basename "$dest") [$(basename "$(dirname "$(dirname "$dest")")")]"
        return
    fi
    mkdir -p "$(dirname "$dest")"
    info "Fetching $repo ($pattern)..."
    local url
    url=$(gh_latest_url "$repo" "$pattern")
    [[ -z "$url" ]] && die "Could not find download URL for $repo $pattern"
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
    ok "$dest"
}

# fish 4.x ships a single self-contained binary per arch (functions/completions
# embedded — no share/ tree). dest_dir is <store>/fish-portable/bin.
download_fish() {
    local dest_dir=$1 fish_arch=$2
    if [[ -f "$dest_dir/fish" ]]; then
        skip "fish [$fish_arch]"
    else
        mkdir -p "$dest_dir"
        info "Fetching fish-shell ($fish_arch)..."
        local url
        url=$(gh_latest_url "fish-shell/fish-shell" "linux-$fish_arch.tar.xz")
        [[ -z "$url" ]] && die "Could not find fish download URL for $fish_arch"
        local tmp
        tmp=$(mktemp -d)
        curl -fsSL "$url" | tar -xJf - -C "$tmp"
        mv "$tmp/fish" "$dest_dir/fish"
        chmod +x "$dest_dir/fish"
        rm -rf "$tmp"
        ok "fish [$fish_arch]"
    fi
    # TERMINFO wrapper that the xxh entrypoint launches (fish-portable/bin/fish.sh)
    cat > "$dest_dir/fish.sh" <<'WRAP'
#!/bin/sh
export TERMINFO_DIRS=/lib/terminfo:/etc/terminfo:/usr/share/terminfo:$TERMINFO_DIRS
CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"
$CURRENT_DIR/fish "$@"
WRAP
    chmod +x "$dest_dir/fish.sh"
}

build_arch_store() {
    local arch=$1 triple=$2 ff_label=$3
    local store=~/.xxh/arch/$arch
    info "── $arch ──"
    download_fish   "$store/fish-portable/bin" "$arch"
    download_binary "$store/bin/starship"  "starship/starship"        "$triple.tar.gz"         "starship"
    download_binary "$store/bin/atuin"     "atuinsh/atuin"            "atuin-$triple.tar.gz"   "atuin-$triple/atuin"
    download_binary "$store/bin/bat"       "sharkdp/bat"              "$triple.tar.gz"         "find:bat"
    download_binary "$store/bin/fastfetch" "fastfetch-cli/fastfetch"  "linux-$ff_label.tar.gz" "fastfetch-linux-$ff_label/usr/bin/fastfetch"
}

build_arch_store x86_64  "x86_64-unknown-linux-musl"  "amd64"
build_arch_store aarch64 "aarch64-unknown-linux-musl" "aarch64"

# ── 7. Stage default (x86_64) binaries in xxh build dir ──────────────────────
# xxhc swaps in the correct arch per connect (see xxhc.fish). This default keeps
# a bare `xxh <host>` (without xxhc) working on x86_64 remotes.
step "Stage default x86_64 binaries for xxh uploads"
build=~/.xxh/.xxh/shells/xxh-shell-fish/build
rm -rf "$build/fish-portable" "$build/bin"
cp -R ~/.xxh/arch/x86_64/fish-portable "$build/fish-portable"
cp -R ~/.xxh/arch/x86_64/bin "$build/bin"
ok "x86_64 store staged into build dir"

# ── Done ─────────────────────────────────────────────────────────────────────
echo
echo "All done. Open a new fish shell and connect with: xxhc <host>"
