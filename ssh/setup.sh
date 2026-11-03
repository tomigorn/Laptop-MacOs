#!/opt/homebrew/bin/bash
# Links the ssh-why fish function into ~/.config/fish/functions. Safe to re-run.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

step()  { echo; printf '\033[1m── %s\033[0m\n' "$*"; }
ok()    { printf '   \033[32m✓\033[0m  %s\n' "$*"; }

symlink() {
    local src=$1 dst=$2
    mkdir -p "$(dirname "$dst")"
    ln -sf "$src" "$dst"
    ok "$(basename "$dst") → $src"
}

step "Symlinks — ssh-why"
symlink "$SCRIPT_DIR/ssh-why.fish" ~/.config/fish/functions/ssh-why.fish

echo
echo "All done. Open a new fish shell and run: ssh-why <host>"
