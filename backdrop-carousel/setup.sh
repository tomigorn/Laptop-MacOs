#!/bin/zsh
# Installs a symlink to sync.sh in ~/bin so the Shortcut can run it from a
# runner-friendly location (Control Center / menu bar background runner has
# trouble with deep nested paths).

set -e

SCRIPT_DIR="${0:A:h}"
SOURCE="$SCRIPT_DIR/sync.sh"
TARGET_DIR="$HOME/bin"
TARGET="$TARGET_DIR/backdrop-sync.sh"

mkdir -p "$TARGET_DIR"
ln -sf "$SOURCE" "$TARGET"

echo "Symlink installed:"
echo "  $TARGET -> $SOURCE"
echo
echo "Point the Shortcut's 'Run Shell Script' action at:"
echo "  $TARGET"
echo "and set the shell to /bin/zsh."
echo
echo "If running from Control Center still fails, grant Full Disk Access to"
echo "Shortcuts.app and Finder in System Settings > Privacy & Security, then"
echo "log out and back in."
