#!/opt/homebrew/bin/bash
# Links mac-outdated into ~/.local/bin. Safe to re-run.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

step()  { echo; printf '\033[1m── %s\033[0m\n' "$*"; }
ok()    { printf '   \033[32m✓\033[0m  %s\n' "$*"; }
info()  { printf '   %s\n' "$*"; }

symlink() {
    local src=$1 dst=$2
    mkdir -p "$(dirname "$dst")"
    ln -sf "$src" "$dst"
    ok "$(basename "$dst") → $src"
}

step "Symlinks — mac-outdated"
chmod +x "$SCRIPT_DIR/mac-outdated"
symlink "$SCRIPT_DIR/mac-outdated" ~/.local/bin/mac-outdated
symlink "$SCRIPT_DIR/completions/mac-outdated.fish" ~/.config/fish/completions/mac-outdated.fish

case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) info "$HOME/.local/bin is not on PATH: pipx ensurepath (terminal/install.sh does it)" ;;
esac

echo
echo "All done. Run: mac-outdated"
